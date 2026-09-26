// DDE-Mart handyman app — workforce auth API (original).
//
// OTP-only login with role=worker. Mirrors POST /api/v1/work/auth/*.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class WorkerAuthApi {
  WorkerAuthApi(this._dio);

  final Dio _dio;

  Future<String?> otpRequest(String phone) async {
    final response = await _dio.post(
      '/work/auth/otp/request',
      data: {'phone': phone, 'role': 'worker'},
    );
    final data = (response.data as Map)['data'] as Map;
    return data['debug_code'] as String?;
  }

  Future<Map<String, dynamic>> otpVerify({
    required String phone,
    required String code,
  }) async {
    final response = await _dio.post(
      '/work/auth/otp/verify',
      data: {'phone': phone, 'role': 'worker', 'code': code},
    );
    return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
  }

  Future<void> logout() async {
    await _dio.post('/worker/logout');
  }

  Future<Map<String, dynamic>> me() async {
    final response = await _dio.get('/worker/me');
    return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
  }
}

final workerAuthApiProvider = Provider<WorkerAuthApi>(
  (ref) => WorkerAuthApi(ref.watch(dioProvider)),
);
