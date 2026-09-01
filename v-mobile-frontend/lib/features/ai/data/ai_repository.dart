import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref.watch(apiClientProvider));
});

class AiRepository {
  const AiRepository(this._dio);

  final Dio _dio;

  Future<String> suggestMessage({
    required String chatId,
    String? instruction,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai/chats/$chatId/suggest-message',
        data: {'tone': 'дружелюбный, естественный', 'instruction': instruction},
      );
      return response.data?['text'] as String? ?? '';
    } on DioException catch (error) {
      throw AiGenerationException(_readErrorMessage(error));
    }
  }

  Future<String> suggestPost({required String topicOrDraft}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai/posts/suggest',
        data: {
          'draft': topicOrDraft,
          'tone': 'живой, современный, без лишнего пафоса',
        },
      );
      return response.data?['text'] as String? ?? '';
    } on DioException catch (error) {
      throw AiGenerationException(_readErrorMessage(error));
    }
  }

  String _readErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final apiError = data['error'];
      if (apiError is Map<String, dynamic>) {
        final message = apiError['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    }
    return error.message ?? 'Не удалось обратиться к AI-сервису';
  }
}

class AiGenerationException implements Exception {
  const AiGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}
