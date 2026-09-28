// DDE-Mart handyman app — job moves + gate + stories unit tests.

import 'package:dde_handyman/core/api_client.dart';
import 'package:dde_handyman/core/gate.dart';
import 'package:dde_handyman/features/jobs/worker_jobs.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Dio _storiesDio(List<Map<String, dynamic>> rows) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/stories') {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'data': rows},
            ),
          );
          return;
        }
        handler.next(options);
      },
    ),
  );
  return dio;
}

void main() {
  group('gateStatus', () {
    test('maintenance wins', () {
      expect(
        gateStatus(current: '9.9.9', minimum: '1.0.0', maintenance: true),
        GateDecision.maintenance,
      );
    });

    test('older app requires update, equal passes', () {
      expect(
        gateStatus(current: '1.0.0', minimum: '2.0.0', maintenance: false),
        GateDecision.updateRequired,
      );
      expect(
        gateStatus(current: '2.0.0', minimum: '2.0.0', maintenance: false),
        GateDecision.ok,
      );
    });
  });

  group('nextMoves', () {
    test('placed branches', () {
      expect(nextMoves('placed'), ['accepted', 'rejected', 'cancelled']);
    });

    test('accepted and ongoing advance', () {
      expect(nextMoves('accepted'), ['ongoing', 'cancelled']);
      expect(nextMoves('ongoing'), ['completed']);
    });

    test('terminal and unknown rest', () {
      expect(nextMoves('completed'), isEmpty);
      expect(nextMoves('cancelled'), isEmpty);
      expect(nextMoves('bogus'), isEmpty);
    });
  });

  group('fetchStories', () {
    test('parses public GET /stories feed', () async {
      final api = WorkerJobsApi(_storiesDio([
        {
          'id': 1,
          'store': {'id': 2, 'name': 'Salon'},
          'video_url': 'https://cdn.test/v.mp4',
          'thumbnail': 'https://cdn.test/t.jpg',
        },
        {
          'id': 2,
          'store': {'id': 3, 'name': 'Spa'},
          'video_url': 'https://cdn.test/v2.mp4',
          'thumbnail': null,
        },
      ]));
      final stories = await api.fetchStories();
      expect(stories, hasLength(2));
      expect(stories.first['id'], 1);
      expect(
          (stories.first['store'] as Map)['name'], 'Salon');
      expect(stories.last['video_url'], 'https://cdn.test/v2.mp4');
    });

    test('empty feed yields empty rail', () async {
      final api = WorkerJobsApi(_storiesDio([]));
      expect(await api.fetchStories(), isEmpty);
    });
  });

  group('branding', () {
    test('logo parsed from app-config branding', () {
      final config = LaunchConfig.fromJson({
        'maintenance': false,
        'min_versions': {},
        'support': {},
        'branding': {'logo': '/storage/logos/worker.png'},
      });
      expect(config.brandLogo, '/storage/logos/worker.png');
    });

    test('missing branding degrades to null', () {
      final config = LaunchConfig.fromJson({'maintenance': false});
      expect(config.brandLogo, isNull);
    });

    test('resolveAsset builds absolute storage URL', () {
      expect(
        resolveAsset('/storage/logos/worker.png'),
        endsWith('/storage/logos/worker.png'),
      );
      expect(resolveAsset('logos/worker.png'),
          endsWith('/storage/logos/worker.png'));
      expect(resolveAsset(null), isNull);
      expect(resolveAsset('https://cdn.test/l.png'), 'https://cdn.test/l.png');
    });
  });
}
