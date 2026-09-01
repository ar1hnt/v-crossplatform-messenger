import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  factory ApiException.fromDioError(
    DioException error, {
    String fallbackMessage = 'Не удалось выполнить запрос',
  }) {
    final data = error.response?.data;

    if (data is Map<String, dynamic>) {
      final apiError = data['error'];
      if (apiError is Map<String, dynamic>) {
        final message = apiError['message'];
        if (message is String && message.trim().isNotEmpty) {
          return ApiException(message.trim());
        }
      }

      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return ApiException(detail.trim());
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('Сервер слишком долго не отвечает');
      case DioExceptionType.connectionError:
        return const ApiException('Не удалось подключиться к серверу');
      default:
        final message = error.message;
        if (message != null && message.trim().isNotEmpty) {
          return ApiException(message.trim());
        }
        return ApiException(fallbackMessage);
    }
  }

  @override
  String toString() => message;
}
