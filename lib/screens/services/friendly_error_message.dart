import 'package:dio/dio.dart';

/// Converts technical request failures into concise messages suitable for users.
/// Logging can continue to use the original exception for diagnostics.
String friendlyErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
  String connectionMessage =
      'We couldn\'t reach Commutas right now. Check your connection and try again.',
  String? unauthorizedMessage,
}) {
  if (error is DioException) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Commutas is taking longer than usual to respond. Check your connection and try again.';
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.unknown) {
      return connectionMessage;
    }

    final statusCode = error.response?.statusCode;
    if (statusCode == 401) {
      return unauthorizedMessage ??
          'Your session has expired. Please sign in again.';
    }
    if (statusCode == 403) {
      return 'You do not have permission to complete this request.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'The service is temporarily unavailable. Please try again shortly.';
    }

    return fallback;
  }

  return fallback;
}
