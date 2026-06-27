import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../login_signup_screen.dart';
import 'dart:developer' as developer;

class ApiInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      developer.log('401 Unauthorized caught by interceptor. Logging out.', name: 'ApiInterceptor');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('session_active', false);
        await prefs.remove('session_name');
        await prefs.remove('session_reg_no');
        await prefs.remove('session_role');
        await prefs.remove('session_token');

        // Navigate to LoginSignupScreen using the global key
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginSignupScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        developer.log('Error during logout redirect: $e', name: 'ApiInterceptor');
      }
    }
    super.onError(err, handler);
  }
}
