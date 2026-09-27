// DDE-Mart handyman app — session guard tests (original).

import 'package:dde_handyman/core/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('401 outside auth signs out', () {
    expect(shouldForceSignOut(status: 401, path: '/worker/jobs'), true);
    expect(shouldForceSignOut(status: 401, path: '/worker/me'), true);
  });

  test('401 on auth endpoints keeps the session', () {
    expect(
        shouldForceSignOut(
            status: 401, path: '/work/auth/otp/verify'),
        false);
    expect(
        shouldForceSignOut(status: 401, path: '/auth/login'), false);
  });

  test('non-401 never signs out', () {
    expect(
        shouldForceSignOut(status: 422, path: '/worker/jobs'), false);
    expect(shouldForceSignOut(status: 500, path: '/worker/jobs'),
        false);
    expect(
        shouldForceSignOut(status: null, path: '/worker/me'), false);
  });
}
