import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/chat.dart';
import '../domain/message.dart';

final chatsRepositoryProvider = Provider<ChatsRepository>((ref) {
  return ChatsRepository(ref.watch(apiClientProvider));
});

class ChatsRepository {
  const ChatsRepository(this._dio);

  final Dio _dio;

  Future<List<Chat>> getChats() async {
    final response = await _dio.get<List<dynamic>>('/chats');
    return (response.data ?? [])
        .map((item) => Chat.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Chat> createOrGetPrivateChat(String userId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chats/private/$userId',
    );
    return Chat.fromJson(response.data!);
  }

  Future<List<Message>> getMessages(String chatId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/chats/$chatId/messages',
    );
    final items = response.data?['items'] as List<dynamic>? ?? [];
    return items
        .map((item) => Message.fromJson(item as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
  }

  Future<Message> sendTextMessage({
    required String chatId,
    required String text,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/chats/$chatId/messages',
        data: {'message_type': 'text', 'text': text},
      );
      return Message.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDioError(
        error,
        fallbackMessage: 'Не удалось отправить сообщение',
      );
    }
  }

  Future<Message> sendMediaMessage({
    required String chatId,
    required String path,
    String? text,
  }) async {
    final mimeType = lookupMimeType(path) ?? 'application/octet-stream';
    if (!mimeType.startsWith('image/') && !mimeType.startsWith('video/')) {
      throw const ApiException('Можно отправлять только фото и видео');
    }

    try {
      final uploadResponse = await _dio.post<Map<String, dynamic>>(
        '/files/upload',
        data: FormData.fromMap({
          'kind': 'message_attachment',
          'file': await MultipartFile.fromFile(
            path,
            contentType: MediaType.parse(mimeType),
          ),
        }),
      );
      final fileId = uploadResponse.data?['id'] as String?;
      if (fileId == null || fileId.isEmpty) {
        throw const ApiException('Не удалось загрузить файл');
      }

      final normalizedText = text?.trim();
      final response = await _dio.post<Map<String, dynamic>>(
        '/chats/$chatId/messages',
        data: {
          'message_type': normalizedText == null || normalizedText.isEmpty
              ? 'file'
              : 'text_file',
          'text': normalizedText,
          'file_id': fileId,
        },
      );
      return Message.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDioError(
        error,
        fallbackMessage: 'Не удалось отправить медиафайл',
      );
    }
  }

  Future<void> markRead(String chatId) async {
    await _dio.post<void>('/chats/$chatId/messages/read');
  }
}
