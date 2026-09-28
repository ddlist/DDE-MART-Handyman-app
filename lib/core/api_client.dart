// DDE-Mart handyman app — HTTP layer (original).
//
// Dio client for the DDE-Mart API v1 worker surfaces
// (see admin-panel/docs/api-v1.md, Worker section).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_store.dart';
import 'config.dart';
import 'session.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => 'ApiException($status): $message';
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await ref.read(authStoreProvider.notifier).token();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        final response = error.response;
        if (response != null &&
            shouldForceSignOut(
              status: response.statusCode,
              path: error.requestOptions.path,
            )) {
          // Fire-and-forget: the router gate picks up the signed-out state
          // and routes to sign-in; the original error still reaches the UI.
          ref.read(authStoreProvider.notifier).signOut();
        }
        if (response != null) {
          final data = response.data;
          final message = data is Map && data['message'] is String
              ? data['message'] as String
              : 'Request failed (${response.statusCode}).';
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: response,
              error: ApiException(message, status: response.statusCode),
            ),
          );
          return;
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});

String apiMessage(Object error) {
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).message;
  }
  return 'Something went wrong. Please try again.';
}

/// Admin-uploaded brand logo URL (from app-config branding), if set.
final brandLogoProvider = StateProvider<String?>((ref) => null);

/// Resolves a relative storage path against the API host.
String? resolveAsset(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http://') ||
      path.startsWith('https://') ||
      path.startsWith('//')) {
    return path;
  }
  final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
  final clean = path.replaceAll(RegExp(r'^/+(storage/)?'), '');
  return '$base/storage/$clean';
}

class LaunchConfig {
  LaunchConfig({
    required this.maintenance,
    required this.minVersions,
    required this.supportEmail,
    required this.supportPhone,
    this.brandLogo,
  });

  factory LaunchConfig.fromJson(Map<String, dynamic> json) {
    final min = (json['min_versions'] as Map?) ?? {};
    final support = (json['support'] as Map?) ?? {};
    final branding = (json['branding'] as Map?) ?? {};
    final logo = branding['logo'];
    return LaunchConfig(
      maintenance: json['maintenance'] == true,
      minVersions: {
        for (final audience in ['customer', 'driver', 'vendor', 'provider', 'worker'])
          audience: '${min[audience] ?? '1.0.0'}',
      },
      supportEmail: '${support['email'] ?? ''}',
      supportPhone: '${support['phone'] ?? ''}',
      brandLogo: logo is String && logo.isNotEmpty ? logo : null,
    );
  }

  final bool maintenance;
  final Map<String, String> minVersions;
  final String supportEmail;
  final String supportPhone;
  final String? brandLogo;
}
