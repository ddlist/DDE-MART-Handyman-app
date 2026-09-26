// DDE-Mart handyman app — job moves + gate unit tests (original).

import 'package:dde_handyman/core/gate.dart';
import 'package:dde_handyman/features/jobs/worker_jobs.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
