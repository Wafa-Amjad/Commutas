import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import 'api_interceptor.dart';

class RouteService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://commutas.onrender.com',
    headers: {'Content-Type': 'application/json'},
  ))..interceptors.add(ApiInterceptor());

  /// Fetch all available static routes. Requires JWT token.
  Future<List<Map<String, dynamic>>> fetchRoutes({required String token}) async {
    try {
      final response = await _dio.get(
        '/api/routes',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data is List) {
        return List<Map<String, dynamic>>.from(
          (response.data as List).map((item) => Map<String, dynamic>.from(item)),
        );
      }
      return [];
    } on DioException catch (e) {
      developer.log(
        'Fetch Routes Failed: ${e.response?.data?['detail'] ?? e.message}',
        name: 'RouteService',
      );
      return [];
    }
  }

  /// Save student's preferred route. Requires JWT token.
  Future<bool> savePreferredRoute({
    required String token,
    required String routeId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/student/preferred-route',
        data: {'route_id': routeId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      developer.log(
        'Save Preferred Route Failed: ${e.response?.data?['detail'] ?? e.message}',
        name: 'RouteService',
      );
      return false;
    }
  }

  /// Fetch all schedules configurations. Requires JWT token.
  Future<List<Map<String, dynamic>>> fetchSchedules({required String token}) async {
    try {
      final response = await _dio.get(
        '/api/schedules',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data is List) {
        return List<Map<String, dynamic>>.from(
          (response.data as List).map((item) => Map<String, dynamic>.from(item)),
        );
      }
      return [];
    } on DioException catch (e) {
      developer.log(
        'Fetch Schedules Failed: ${e.response?.data?['detail'] ?? e.message}',
        name: 'RouteService',
      );
      return [];
    }
  }
}
