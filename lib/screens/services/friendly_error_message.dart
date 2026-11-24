import 'package:dio/dio.dart';

/// Converts technical request failures into concise messages suitable for users.
/// Logging can continue to use the original exception for diagnostics.
String friendlyErrorMessage(
  Object error, {
  String fallback = 'This request could not be completed. Please try again.',
  String connectionMessage =
      'Connection unavailable. Please check your internet connection and try again.',
}) {
  if (error is DioException) {
    final technicalMessage = error.toString().toLowerCase();
    final isConnectionFailure = error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        technicalMessage.contains('failed host lookup') ||
        technicalMessage.contains('socket failed host lookup');

    if (isConnectionFailure) {
      return connectionMessage;
    }

    final detail = error.response?.data is Map
        ? error.response?.data['detail']
        : null;
    if (detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }

    return fallback;
  }

  final message = error.toString().replaceFirst('Exception:', '').trim();
  if (message.isEmpty || message.toLowerCase().startsWith('dioexception')) {
    return fallback;
  }

  return message;
}
