// DDE-Mart handyman app — my jobs (original).
//
// GET /worker/jobs (assigned to me), detail with timeline, machine moves:
// placed → accepted|rejected|cancelled, accepted → ongoing|cancelled,
// ongoing → completed.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

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

  /// Public stories feed (GET /stories) for the jobs-tab rail.
  Future<List<Map<String, dynamic>>> fetchStories() async {
    final response = await _dio.get('/stories');
    return (((response.data as Map)['data'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}

final workerJobsApiProvider = Provider<WorkerJobsApi>(
  (ref) => WorkerJobsApi(ref.watch(dioProvider)),
);

final workerJobsProvider = FutureProvider<List<WorkerJob>>((ref) async {
  return ref.watch(workerJobsApiProvider).jobs();
});

final workerStoriesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(workerJobsApiProvider).fetchStories();
});

class WorkerJobsScreen extends ConsumerWidget {
  const WorkerJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(workerJobsProvider);
    final stories = ref.watch(workerStoriesProvider);

    return jobs.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          GradientHeader(title: 'My jobs', subtitle: 'Loading your queue…'),
          SizedBox(height: 16),
          ShimmerList(rows: 3),
        ],
      ),
      error: (e, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const GradientHeader(
              title: 'My jobs', subtitle: 'Something went wrong'),
          const SizedBox(height: 16),
          ErrorRetry(
              error: e, onRetry: () => ref.invalidate(workerJobsProvider)),
        ],
      ),
      data: (rows) {
        final active =
            rows.where((j) => nextMoves(j.status).isNotEmpty).length;
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(workerJobsProvider);
            ref.invalidate(workerStoriesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              GradientHeader(
                title: 'My jobs',
                subtitle:
                    '${rows.length} assigned · $active need action',
                trailing: IconButton(
                  icon: const Icon(Icons.refresh_outlined,
                      color: Colors.white),
                  onPressed: () {
                    ref.invalidate(workerJobsProvider);
                    ref.invalidate(workerStoriesProvider);
                  },
                ),
              ),
              stories.when(
                data: (items) => StoryStrip(stories: items),
                loading: () => const SizedBox(height: 8),
                error: (_, _) => const SizedBox.shrink(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: rows.isEmpty
                    ? const EmptyState(
                        message: 'No jobs assigned. New jobs pop up here.',
                        icon: Icons.handyman_outlined,
                      )
                    : Column(
                        children: [
                          for (final job in rows) ...[
                            SleekCard(
                              onTap: () =>
                                  context.safePush('/job/${job.id}'),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${job.number} · ${job.customer}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                      ),
                                      StatusChip(status: job.status),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.payments_outlined,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Total ${job.total.toStringAsFixed(2)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 20,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
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
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.watch(workerJobsApiProvider).job(widget.jobId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: const [
                GradientHeader(title: 'Job', subtitle: 'Loading details…'),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: ShimmerList(rows: 3),
                ),
              ],
            );
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const GradientHeader(
                    title: 'Job', subtitle: 'Could not load job'),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ErrorRetry(
                    error: snapshot.error!,
                    onRetry: () => setState(() {}),
                  ),
                ),
              ],
            );
          }
          final job = snapshot.data!;
          final status = '${job['status']}';
          final timeline = ((job['timeline'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final scheme = Theme.of(context).colorScheme;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(workerJobsProvider);
              if (mounted) setState(() {});
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.fromLTRB(20, 28, 20, 44),
                  decoration: BoxDecoration(
                    gradient:
                        DdeHandymanTheme.headerGradient(context),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(
                          DdeHandymanTheme.radiusSheet),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white),
                              onPressed: () =>
                                  context.safePush('/jobs'),
                            ),
                            Expanded(
                              child: Text(
                                '${job['number'] ?? 'Job #${job['id']}'}',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(
                                    DdeHandymanTheme.radiusPill),
                                border: Border.all(
                                    color: Colors.white.withValues(
                                        alpha: 0.35)),
                              ),
                              child: Text(
                                status
                                    .replaceAll('_', ' ')
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.payments_outlined,
                                color: Colors.white70, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Total ${job['total'] ?? ''} · ${job['customer'] ?? 'Customer'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(
                                        alpha: 0.9),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Transform.translate(
                    offset: const Offset(0, -20),
                    child: Column(
                      children: [
                        SleekCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: DdeHandymanTheme
                                    .accentGradient(context),
                                borderRadius:
                                    BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                  Icons.person_outline,
                                  color: Colors.white),
                            ),
                            title: Text(
                                '${job['customer'] ?? 'Customer'}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall),
                            subtitle: Text(
                              '${job['address'] ?? 'No address on file'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ),
                        if ('${job['notes'] ?? ''}'.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SleekCard(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.note_outlined,
                                  color: scheme.primary),
                              title: const Text('Notes'),
                              subtitle:
                                  Text('${job['notes']}'),
                            ),
                          ),
                        ],
                        if (nextMoves(status).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SleekCard(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('Next step',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final move
                                        in nextMoves(status))
                                      FilledButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _move(move),
                                        child: Text(_busy
                                            ? 'Working…'
                                            : move),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (timeline.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SleekCard(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('History',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 12),
                                TimelineDots(entries: timeline),
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          SleekCard(
                            child: Row(
                              children: [
                                Icon(Icons.history_outlined,
                                    color: scheme.onSurfaceVariant),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No history yet — moves will appear here.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: scheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          );
        },
      ),
    );
  }
}
