// DDE-Mart handyman app — payouts, SOS + profile (original).
//
// GET|POST /worker/payouts, POST /worker/sos (GPS fill when available),
// GET /worker/me + POST /worker/logout.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import '../../core/push.dart';
import '../auth/worker_auth_api.dart';

class WorkerPayoutsApi {
  WorkerPayoutsApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> list() async {
    final response = await _dio.get('/worker/payouts');
    return (((response.data as Map)['data'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> request({required double amount, required String method}) async {
    await _dio.post('/worker/payouts', data: {
      'amount': amount,
      'method': method,
    });
  }

  Future<void> sos({required double latitude, required double longitude}) async {
    await _dio.post('/worker/sos', data: {
      'latitude': latitude,
      'longitude': longitude,
    });
  }
}

final workerPayoutsApiProvider = Provider<WorkerPayoutsApi>(
  (ref) => WorkerPayoutsApi(ref.watch(dioProvider)),
);

final workerPayoutsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(workerPayoutsApiProvider).list();
});

const _methods = ['bank', 'paypal', 'stripe', 'razorpay', 'flutterwave', 'cash'];

class WorkerPayoutsScreen extends ConsumerStatefulWidget {
  const WorkerPayoutsScreen({super.key});

  @override
  ConsumerState<WorkerPayoutsScreen> createState() =>
      _WorkerPayoutsScreenState();
}

class _WorkerPayoutsScreenState extends ConsumerState<WorkerPayoutsScreen> {
  final _amount = TextEditingController();
  String _method = _methods.first;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payouts = ref.watch(workerPayoutsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Request payout', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _method,
          items: [
            for (final m in _methods) DropdownMenuItem(value: m, child: Text(m)),
          ],
          onChanged: (value) => setState(() => _method = value ?? _methods.first),
          decoration: const InputDecoration(labelText: 'Method'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  final amount = double.tryParse(_amount.text.trim()) ?? 0;
                  if (amount < 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter an amount of at least 1.')),
                    );
                    return;
                  }
                  setState(() => _busy = true);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref
                        .read(workerPayoutsApiProvider)
                        .request(amount: amount, method: _method);
                    ref.invalidate(workerPayoutsProvider);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Payout requested.')),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(apiMessage(e))),
                    );
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(_busy ? 'Sending…' : 'Request'),
        ),
        const SizedBox(height: 16),
        Text('History', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        payouts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(apiMessage(e)),
          data: (rows) => Column(
            children: [
              if (rows.isEmpty) const Text('No payouts yet.'),
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text('${row['amount']} · ${row['method']}'),
                    trailing: Text('${row['status']}'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class WorkerSosScreen extends ConsumerStatefulWidget {
  const WorkerSosScreen({super.key});

  @override
  ConsumerState<WorkerSosScreen> createState() => _WorkerSosScreenState();
}

class _WorkerSosScreenState extends ConsumerState<WorkerSosScreen> {
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Emergency SOS. Sends your location to DDE-Mart safety staff.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lat,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(labelText: 'Latitude'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lng,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(labelText: 'Longitude'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _busy
              ? null
              : () async {
                  final lat = double.tryParse(_lat.text.trim());
                  final lng = double.tryParse(_lng.text.trim());
                  if (lat == null || lng == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter valid coordinates.')),
                    );
                    return;
                  }
                  setState(() => _busy = true);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref.read(workerPayoutsApiProvider).sos(
                          latitude: lat,
                          longitude: lng,
                        );
                    messenger.showSnackBar(
                      const SnackBar(content: Text('SOS sent. Help is on the way.')),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(apiMessage(e))),
                    );
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(_busy ? 'Sending…' : 'SEND SOS'),
        ),
      ],
    );
  }
}

class WorkerProfileScreen extends ConsumerWidget {
  const WorkerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStoreProvider);

    return FutureBuilder<Map<String, dynamic>>(
      future: ref.watch(workerAuthApiProvider).me(),
      builder: (context, snapshot) {
        final me = snapshot.data;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${me?['name'] ?? auth.name ?? ''}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (snapshot.hasError) Text(apiMessage(snapshot.error!)),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () async {
                try {
                  await ref.read(workerAuthApiProvider).logout();
                } finally {
                  await ref.read(pushServiceProvider).unregister();
                  await ref.read(authStoreProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                }
              },
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );
  }
}
