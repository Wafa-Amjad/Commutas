import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_interceptor.dart';
import 'auth_service.dart';

class NotificationService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthService.serverAddress,
    headers: {'Content-Type': 'application/json'},
  ))..interceptors.add(ApiInterceptor());

  /// Registers the device token with the backend server.
  /// Requires the student's JWT access token.
  Future<bool> registerDeviceToken({
    required String jwtToken,
    required String deviceToken,
  }) async {
    try {
      final response = await _dio.post(
        '/api/notifications/register-token',
        data: {'device_token': deviceToken},
        options: Options(headers: {'Authorization': 'Bearer $jwtToken'}),
      );

      if (response.statusCode == 200) {
        developer.log('Device token registered successfully: $deviceToken', name: 'NotificationService');
        return true;
      }
      return false;
    } on DioException catch (e) {
      developer.log(
        'Failed to register device token: ${e.response?.data?['detail'] ?? e.message}',
        name: 'NotificationService',
      );
      return false;
    }
  }

  /// Automatically registers a device token.
  /// Requests notification permissions and retrieves the real Firebase token.
  /// Safely falls back to the mock token if Firebase setup fails or lacks config.
  Future<void> autoRegisterToken(String jwtToken) async {
    try {
      final messaging = FirebaseMessaging.instance;
      
      // Request user notifications permission
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Attempt to retrieve real FCM token
      final String? fcmToken = await messaging.getToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        developer.log('Fetched FCM Token: $fcmToken', name: 'NotificationService');
        await registerDeviceToken(jwtToken: jwtToken, deviceToken: fcmToken);
      } else {
        developer.log('FCM Token is null or empty. Fallback to mock token.', name: 'NotificationService');
        const String mockToken = "mock_device_token_FA23_BCS_065";
        await registerDeviceToken(jwtToken: jwtToken, deviceToken: mockToken);
      }
    } catch (e) {
      developer.log('Error retrieving FCM token ($e). Fallback to mock token.', name: 'NotificationService');
      const String mockToken = "mock_device_token_FA23_BCS_065";
      await registerDeviceToken(jwtToken: jwtToken, deviceToken: mockToken);
    }
  }
}
