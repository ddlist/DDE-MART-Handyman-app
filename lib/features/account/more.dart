// DDE-Mart handyman app — payouts, SOS + profile.
//
// GET|POST /worker/payouts, POST /worker/sos (GPS fill when available),
// GET /worker/me + POST /worker/logout.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import '../../core/nav.dart';
import '../../core/permissions.dart';
import '../../core/push.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
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
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(workerPayoutsProvider),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GradientHeader(
            title: 'Payouts',
            subtitle: 'Request earnings, track history',
            icon: Icons.payments_outlined,
            trailing: IconButton(
              icon: const Icon(Icons.refresh_outlined, color: Colors.white),
              onPressed: () => ref.invalidate(workerPayoutsProvider),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SleekCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Request payout',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Minimum 1.00 — arrives via your chosen method.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amount,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixIcon: Icon(Icons.currency_rupee_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _method,
                        items: [
                          for (final m in _methods)
                            DropdownMenuItem(value: m, child: Text(m)),
                        ],
                        onChanged: (value) =>
                            setState(() => _method = value ?? _methods.first),
                        decoration: const InputDecoration(
                          labelText: 'Method',
                          prefixIcon: Icon(Icons.account_balance_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  final amount =
                                      double.tryParse(_amount.text.trim()) ?? 0;
                                  if (amount < 1) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Enter an amount of at least 1.')),
                                    );
                                    return;
                                  }
                                  setState(() => _busy = true);
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  try {
                                    await ref
                                        .read(workerPayoutsApiProvider)
                                        .request(
                                            amount: amount, method: _method);
                                    ref.invalidate(workerPayoutsProvider);
                                    messenger.showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Payout requested.')),
                                    );
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                          content: Text(apiMessage(e))),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _busy = false);
                                    }
                                  }
                                },
                          child: Text(_busy ? 'Sending…' : 'Request'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('History',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                payouts.when(
                  loading: () => const ShimmerList(rows: 2),
                  error: (e, _) => ErrorRetry(
                    error: e,
                    onRetry: () => ref.invalidate(workerPayoutsProvider),
                  ),
                  data: (rows) {
                    if (rows.isEmpty) {
                      return const SleekCard(
                        child: EmptyState(
                          message: 'No payouts yet. Request one above.',
                          icon: Icons.payments_outlined,
                        ),
                      );
                    }
                    return SleekCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          for (var i = 0; i < rows.length; i++) ...[
                            BillRow(row: rows[i]),
                            if (i != rows.length - 1)
                              Divider(
                                height: 1,
                                color: scheme.outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
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
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        GradientHeader(
          title: 'Emergency SOS',
          subtitle: 'Sends your location to DDE-Mart safety staff.',
          icon: Icons.sos_outlined,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              SleekCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.location_on_outlined,
                              color: scheme.onErrorContainer),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Your location',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall),
                              Text(
                                'Auto-fill with GPS or enter manually.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.my_location_outlined),
                        label: const Text('Fill from GPS'),
                        onPressed: _busy
                            ? null
                            : () async {
                                final ok = await ref
                                    .read(permissionServiceProvider)
                                    .ensure(
                                        context, AppPermission.location);
                                if (!ok) return;
                                if (!await Geolocator
                                    .isLocationServiceEnabled()) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Location services are off. Enable GPS.')),
                                    );
                                  }
                                  return;
                                }
                                try {
                                  final position = await Geolocator
                                      .getCurrentPosition();
                                  _lat.text = '${position.latitude}';
                                  _lng.text = '${position.longitude}';
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Could not fix location.')),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lat,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        prefixIcon: Icon(Icons.explore_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lng,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        prefixIcon: Icon(Icons.explore_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  ),
                  onPressed: _busy
                      ? null
                      : () async {
                          final lat =
                              double.tryParse(_lat.text.trim());
                          final lng =
                              double.tryParse(_lng.text.trim());
                          if (lat == null || lng == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Enter valid coordinates.')),
                            );
                            return;
                          }
                          setState(() => _busy = true);
                          final messenger =
                              ScaffoldMessenger.of(context);
                          try {
                            await ref
                                .read(workerPayoutsApiProvider)
                                .sos(
                                  latitude: lat,
                                  longitude: lng,
                                );
                            messenger.showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'SOS sent. Help is on the way.')),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                  content: Text(apiMessage(e))),
                            );
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  child: Text(_busy ? 'Sending…' : 'SEND SOS'),
                ),
              ),
            ],
          ),
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
    final themeMode = ref.watch(themeModeProvider);
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<Map<String, dynamic>>(
      future: ref.watch(workerAuthApiProvider).me(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: const [
              GradientHeader(title: 'Profile', subtitle: 'Loading…'),
              Padding(
                padding: EdgeInsets.all(16),
                child: ShimmerList(rows: 3),
              ),
            ],
          );
        }
        final me = snapshot.data;
        final name = '${me?['name'] ?? auth.name ?? 'Handyman'}';
        final initial =
            name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 44),
              decoration: BoxDecoration(
                gradient: DdeHandymanTheme.headerGradient(context),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(DdeHandymanTheme.radiusSheet),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          initial,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          Text(
                            '${me?['phone'] ?? auth.phone ?? ''}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white
                                      .withValues(alpha: 0.85),
                                ),
                          ),
                          const SizedBox(height: 6),
                          // Avatar/photo uploads: worker API has no
                          // POST /worker/uploads endpoint — photos stay as-is.
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(
                                  DdeHandymanTheme.radiusPill),
                              border: Border.all(
                                  color: Colors.white
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_outlined,
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${me?['status'] ?? 'active'}'
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                    if (snapshot.hasError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SleekCard(
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: scheme.error),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(
                                      apiMessage(snapshot.error!))),
                            ],
                          ),
                        ),
                      ),
                    SleekCard(
                      onTap: () => context.safePush('/jobs'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient:
                                DdeHandymanTheme.accentGradient(
                                    context),
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: const Icon(
                              Icons.handyman_outlined,
                              color: Colors.white),
                        ),
                        title: const Text('My jobs'),
                        subtitle: const Text(
                            'Queue, details and history'),
                        trailing: Icon(Icons.chevron_right,
                            color: scheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SleekCard(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text('Appearance',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall),
                          const SizedBox(height: 10),
                          SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(
                                  value: ThemeMode.system,
                                  label: Text('Auto')),
                              ButtonSegment(
                                  value: ThemeMode.light,
                                  label: Text('Light')),
                              ButtonSegment(
                                  value: ThemeMode.dark,
                                  label: Text('Dark')),
                            ],
                            selected: {themeMode},
                            onSelectionChanged: (set) => ref
                                .read(themeModeProvider.notifier)
                                .set(set.first),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: () async {
                          final confirm =
                              await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Sign out?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(
                                      context, false),
                                  child: const Text('Stay'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(
                                      context, true),
                                  child: const Text('Sign out'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true || !context.mounted) {
                            return;
                          }
                          try {
                            await ref
                                .read(workerAuthApiProvider)
                                .logout();
                          } finally {
                            await ref
                                .read(pushServiceProvider)
                                .unregister();
                            await ref
                                .read(authStoreProvider.notifier)
                                .signOut();
                            if (context.mounted) context.go('/login');
                          }
                        },
                        child: const Text('Sign out'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, info) => Center(
                        child: Text(
                          (info.data?.version ?? '').isEmpty
                              ? ''
                              : 'v${info.data!.version}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
