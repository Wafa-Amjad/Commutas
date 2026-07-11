import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import 'api_interceptor.dart';

class AuthService {
  static const String serverAddress = 'https://commutas.onrender.com';
  final Dio _dio = Dio(BaseOptions(
    baseUrl: serverAddress,
    headers: {'Content-Type': 'application/json'},
  ))..interceptors.add(ApiInterceptor());

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

  // 2b. VEHICLE LOGIN METHOD
  Future<Map<String, dynamic>?> loginVehicle({
    required String registrationNo,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/vehicles/login', data: {
        'registration_no': registrationNo,
        'password': password,
      });

      if (response.statusCode == 200) {
        return response.data; // Contains access_token and vehicle profile data
      }
      return null;
    } on DioException catch (e) {
      developer.log('Vehicle Login Failed: ${e.response?.data?['detail'] ?? e.message}', name: 'AuthService');
      rethrow;
    }
  }

  // 2c. GET VEHICLE PROFILE METHOD
  Future<Map<String, dynamic>?> getVehicleProfile({
    required String token,
  }) async {
    try {
      final response = await _dio.get(
        '/vehicles/profile',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return response.data; // Contains vehicle profile data
      }
      return null;
    } on DioException catch (e) {
      developer.log('Get Vehicle Profile Failed: ${e.response?.data?['detail'] ?? e.message}', name: 'AuthService');
      rethrow;
    }
  }

  // 3. PASSWORD RESET METHOD
  Future<Map<String, dynamic>?> resetPassword({
    required String regNo,
    required String portalPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post('/auth/reset-password', data: {
        'reg_no': regNo,
        'portal_password': portalPassword,
        'new_password': newPassword,
      });

      if (response.statusCode == 200) {
        return response.data; // Contains success message detail
      }
      return null;
    } on DioException catch (e) {
      developer.log('Reset Password Failed: ${e.response?.data['detail'] ?? e.message}', name: 'AuthService');
      rethrow;
    }
  }

  // 4. UPLOAD AVATAR METHOD
  Future<String?> uploadAvatar({
    required String token,
    required List<int> imageBytes,
    required String fileName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          imageBytes,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '/auth/avatar',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data['avatar_url'] as String?;
      }
      return null;
    } on DioException catch (e) {
      developer.log(
        'Upload Avatar Failed: ${e.response?.data?['detail'] ?? e.message}',
        name: 'AuthService',
      );
      rethrow;
    }
  }

  // 5. GENERATE TEMPORARY PAYMENT TOKEN (fare amount is server-controlled)
  Future<Map<String, dynamic>?> generatePaymentToken({
    required String token,
  }) async {
    try {
      final response = await _dio.post(
        '/api/wallet/generate-payment-token',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 201) {
        return response.data; // Contains token_id and expires_at
      }
      return null;
    } on DioException catch (e) {
      developer.log('Generate Payment Token Failed: ${e.response?.data?['detail'] ?? e.message}', name: 'AuthService');
      rethrow;
    }
  }

  Future<bool> deleteAvatar({required String token}) async {
    try {
      final response = await _dio.delete(
        '/auth/avatar',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      developer.log(
        'Delete Avatar Failed: ${e.response?.data?['detail'] ?? e.message}',
        name: 'AuthService',
      );
      return false;
    }
  }

  // 6. GET VEHICLE ASSIGNED ROUTE SCHEDULES
  Future<List<dynamic>> getAssignedSchedules({required String token}) async {
    try {
      final response = await _dio.get(
        '/vehicles/assigned-schedules',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } on DioException catch (e) {
      developer.log('Get Assigned Schedules Failed: ${e.response?.data?['detail'] ?? e.message}', name: 'AuthService');
      rethrow;
    }
  }

  // 7. START VEHICLE BOARDING SESSION
  Future<Map<String, dynamic>?> startVehicleSession({
    required String token,
    required String routeScheduleId,
  }) async {
    try {
      final response = await _dio.post(
        '/vehicles/session/start',
        data: {'route_schedule_id': routeScheduleId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 201) {
        return response.data; // Contains session_id, vehicle_no, route_schedule_id, status
      }
      return null;
    } on DioException catch (e) {
      developer.log('Start Vehicle Session Failed: ${e.response?.data?['detail'] ?? e.message}', name: 'AuthService');
      rethrow;
    }
  }

  // 8. START VEHICLE TRIP (DEPARTURE)
  Future<bool> startVehicleTrip({
    required String token,
    required String sessionId,
  }) async {
    try {
      final response = await _dio.post(
        '/vehicles/session/start-trip',
        data: {'session_id': sessionId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      developer.log('Start Vehicle Trip Failed: ${e.response?.data?['detail'] ?? e.message}', name: 'AuthService');
      rethrow;
    }
  }

  // 9. END VEHICLE TRIP
  Future<bool> endVehicleTrip({
    required String token,
    required String sessionId,
  }) async {
    try {
      final response = await _dio.post(
        '/vehicles/session/end',
        data: {'session_id': sessionId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      developer.log('End Vehicle Trip Failed: ${e.response?.data?['detail'] ?? e.message}', name: 'AuthService');
      rethrow;
    }
  }

  // 10. COLLECT VEHICLE FARE FROM STUDENT TOKEN
  Future<Map<String, dynamic>?> collectVehicleFare({
    required String token,
    required String sessionId,
    required String tokenId,
  }) async {
    try {
      final response = await _dio.post(
        '/vehicles/session/fare-collect',
        data: {
          'session_id': sessionId,
          'token_id': tokenId,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } on DioException catch (e) {
      developer.log('Collect Vehicle Fare Failed: ${e.response?.data?['detail'] ?? e.message}', name: 'AuthService');
      return null;
    }
  }

  // 11. GET VEHICLE SESSION STATUS
  Future<Map<String, dynamic>?> getVehicleSession({
    required String token,
    required String sessionId,
  }) async {
    try {
      final response = await _dio.get(
        '/vehicles/session/$sessionId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        return response.data; // Contains status, route_schedule_id, etc.
      }
      return null;
    } on DioException catch (e) {
      developer.log('Get Vehicle Session Failed: ${e.response?.data?['detail'] ?? e.message}', name: 'AuthService');
      rethrow;
    }
  }

  // 12. GET STUDENT PAYMENT TOKEN STATUS
  Future<Map<String, dynamic>?> getPaymentTokenStatus({
    required String token,
    required String tokenId,
  }) async {
    try {
      final response = await _dio.get(
        '/api/wallet/payment-token/$tokenId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      developer.log('Get Payment Token Status Failed: ${e.response?.data?['detail'] ?? e.message}', name: 'AuthService');
      return null;
    }
  }

  // 13. GET STUDENT PROFILE
  Future<Map<String, dynamic>?> getStudentProfile({
    required String token,
  }) async {
    try {
      final response = await _dio.get(
        '/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      developer.log('Get Student Profile Failed: ${e.response?.data?['detail'] ?? e.message}', name: 'AuthService');
      return null;
    }
  }
}


