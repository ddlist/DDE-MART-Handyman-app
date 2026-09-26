// DDE-Mart handyman app — my jobs (original).
//
// GET /worker/jobs (assigned to me), detail with timeline, machine moves:
// placed → accepted|rejected|cancelled, accepted → ongoing|cancelled,
// ongoing → completed.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';

class WorkerJob {
  WorkerJob({
    required this.id,
    required this.number,
    required this.customer,
    required this.total,
    required this.status,
  });

  factory WorkerJob.fromJson(Map<String, dynamic> json) => WorkerJob(
        id: json['id'] as int,
        number: '${json['number'] ?? ''}',
        customer: '${json['customer'] ?? ''}',
        total: (json['total'] as num?)?.toDouble() ?? 0,
        status: '${json['status']}',
      );

  final int id;
  final String number;
  final String customer;
  final double total;
  final String status;
}

/// Legal next moves per status (mirrors the backend machine).
List<String> nextMoves(String status) {
  return switch (status) {
    'placed' => ['accepted', 'rejected', 'cancelled'],
    'accepted' => ['ongoing', 'cancelled'],
    'ongoing' => ['completed'],
    _ => [],
  };
}

class WorkerJobsApi {
  WorkerJobsApi(this._dio);

  final Dio _dio;

  Future<List<WorkerJob>> jobs() async {
    final response = await _dio.get('/worker/jobs');
    return (((response.data as Map)['data'] as List?) ?? [])
        .map((e) => WorkerJob.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> job(int id) async {
    final response = await _dio.get('/worker/jobs/$id');
    return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
  }

  Future<void> transition({required int id, required String to}) async {
    await _dio.post('/worker/jobs/$id/transition', data: {'to': to});
  }
}

final workerJobsApiProvider = Provider<WorkerJobsApi>(
  (ref) => WorkerJobsApi(ref.watch(dioProvider)),
);

final workerJobsProvider = FutureProvider<List<WorkerJob>>((ref) async {
  return ref.watch(workerJobsApiProvider).jobs();
});

class WorkerJobsScreen extends ConsumerWidget {
  const WorkerJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(workerJobsProvider);

    return jobs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(apiMessage(e)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.invalidate(workerJobsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (rows) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(workerJobsProvider),
        child: rows.isEmpty
            ? const Center(child: Text('No jobs assigned.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final job in rows)
                    Card(
                      child: ListTile(
                        title: Text('${job.number} · ${job.customer}'),
                        subtitle: Text(
                          '${job.status} · ${job.total.toStringAsFixed(2)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/job/${job.id}'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class WorkerJobDetailScreen extends ConsumerStatefulWidget {
  const WorkerJobDetailScreen({super.key, required this.jobId});

  final int jobId;

  @override
  ConsumerState<WorkerJobDetailScreen> createState() =>
      _WorkerJobDetailScreenState();
}

class _WorkerJobDetailScreenState
    extends ConsumerState<WorkerJobDetailScreen> {
  bool _busy = false;

  Future<void> _move(String to) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(workerJobsApiProvider)
          .transition(id: widget.jobId, to: to);
      ref.invalidate(workerJobsProvider);
      if (mounted) setState(() {});
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.watch(workerJobsApiProvider).job(widget.jobId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final job = snapshot.data!;
          final status = '${job['status']}';
          final timeline = ((job['timeline'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${job['number'] ?? ''} · $status',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Customer: ${job['customer'] ?? '—'}'),
              Text('Address: ${job['address'] ?? '—'}'),
              Text('Total ${job['total']}'),
              if ('${job['notes'] ?? ''}'.isNotEmpty)
                Text('Notes: ${job['notes']}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final move in nextMoves(status))
                    FilledButton.tonal(
                      onPressed: _busy ? null : () => _move(move),
                      child: Text(move),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Timeline', style: Theme.of(context).textTheme.titleMedium),
              for (final entry in timeline)
                ListTile(
                  leading: const Icon(Icons.circle, size: 10),
                  title: Text('${entry['to'] ?? entry['to_status']}'),
                ),
            ],
          );
        },
      ),
    );
  }
}
