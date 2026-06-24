import 'package:dio/dio.dart';
import 'dart:developer' as developer;

class AuthService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://commutas-server-production.up.railway.app',
    headers: {'Content-Type': 'application/json'},
  ));

  // 1. SIGN UP / REGISTER METHOD
  Future<Map<String, dynamic>?> registerStudent({
    required String regNo,
    required String portalPassword,
    required String appPassword,
  }) async {
    try {
      final response = await _dio.post('/auth/register', data: {
        'reg_no': regNo,
        'portal_password': portalPassword,
        'app_password': appPassword,
      });
      
      if (response.statusCode == 201) {
        return response.data; // Isme access_token aur student data hoga
      }
      return null;
    } on DioException catch (e) {
      developer.log('Sign Up Failed: ${e.response?.data['detail'] ?? e.message}', name: 'AuthService');
      rethrow;
    }
  }

  // 2. LOGIN METHOD
  Future<Map<String, dynamic>?> loginStudent({
    required String regNo,
    required String appPassword,
  }) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'reg_no': regNo,
        'app_password': appPassword,
      });

      if (response.statusCode == 200) {
        return response.data; // Isme access_token aur student data hoga
      }
      return null;
    } on DioException catch (e) {
      developer.log('Login Failed: ${e.response?.data['detail'] ?? e.message}', name: 'AuthService');
      rethrow;
    }
  }
}
