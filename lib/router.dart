// DDE-Mart handyman app — shell, router + launch gate (original).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/api_client.dart';
import 'core/auth_store.dart';
import 'core/config.dart';
import 'core/gate.dart';
import 'features/account/more.dart';
import 'features/auth/worker_login_screen.dart';
import 'features/jobs/worker_jobs.dart';

final launchGateProvider = FutureProvider<GateDecision>((ref) async {
  final dio = ref.watch(dioProvider);
  final info = await PackageInfo.fromPlatform();

  try {
    final response = await dio.get('/app-config');
    final config = LaunchConfig.fromJson(
      Map<String, dynamic>.from((response.data as Map)['data'] as Map),
    );
    return gateStatus(
      current: info.version,
      minimum: config.minVersions[AppConfig.audience] ?? '1.0.0',
      maintenance: config.maintenance,
    );
  } on DioException {
    return GateDecision.ok;
  }
});

/// Bumps when auth or the launch gate changes so the router re-runs its
/// redirect without ever recreating the [GoRouter] itself. Recreating the
/// router mid-session swaps Navigator delegates under live pages and
/// corrupts the tree with duplicate keys.
final _routerRefreshProvider = Provider<ValueNotifier<int>>((ref) {
  final bump = ValueNotifier(0);
  ref.listen<AuthState>(authStoreProvider, (prev, next) {
    if (prev?.signedIn != next.signedIn) bump.value++;
  });
  ref.listen<AsyncValue<GateDecision>>(
      launchGateProvider, (prev, next) {
    if (prev?.valueOrNull != next.valueOrNull) bump.value++;
  });
  ref.onDispose(bump.dispose);
  return bump;
});

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/jobs',
    refreshListenable: ref.watch(_routerRefreshProvider),
    onException: (context, state, router) {
      router.go('/jobs');
    },
    redirect: (context, state) {
      final auth = ref.read(authStoreProvider);
      final gate = ref.read(launchGateProvider);
      final location = state.matchedLocation;

      if (gate.valueOrNull == GateDecision.maintenance && location != '/maintenance') {
        return '/maintenance';
      }
      if (gate.valueOrNull == GateDecision.updateRequired && location != '/update') {
        return '/update';
      }

      const public = ['/login', '/maintenance', '/update'];
      if (!auth.signedIn && !public.any(location.startsWith)) {
        return '/login';
      }
      if (auth.signedIn && (location == '/login' || location == '/')) {
        return '/jobs';
      }
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => WorkerShell(child: child),
        routes: [
          GoRoute(path: '/jobs', builder: (context, state) => const WorkerJobsScreen()),
          GoRoute(
            path: '/job/:id',
            builder: (context, state) => WorkerJobDetailScreen(
              jobId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/payouts',
            builder: (context, state) => const WorkerPayoutsScreen(),
          ),
          GoRoute(path: '/sos', builder: (context, state) => const WorkerSosScreen()),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const WorkerProfileScreen(),
          ),
        ],
      ),
      GoRoute(path: '/login', builder: (context, state) => const WorkerLoginScreen()),
      GoRoute(path: '/maintenance', builder: (context, state) => const MaintenanceScreen()),
      GoRoute(path: '/update', builder: (context, state) => const UpdateScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class WorkerShell extends StatelessWidget {
  const WorkerShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    var index = 0;
    if (location.startsWith('/payouts')) {
      index = 1;
    } else if (location.startsWith('/sos')) {
      index = 2;
    } else if (location.startsWith('/profile')) {
      index = 3;
    }

    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          switch (value) {
            case 0:
              context.go('/jobs');
            case 1:
              context.go('/payouts');
            case 2:
              context.go('/sos');
            case 3:
              context.go('/profile');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.handyman_outlined), label: 'Jobs'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'Payouts'),
          NavigationDestination(icon: Icon(Icons.sos_outlined), label: 'SOS'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_outlined, size: 64),
              const SizedBox(height: 16),
              const Text('DDE-Mart is under maintenance', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(launchGateProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.system_update_outlined, size: 64),
              SizedBox(height: 16),
              Text(
                'Please update DDE Handyman to continue.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
