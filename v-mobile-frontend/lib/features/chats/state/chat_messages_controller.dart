import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chats_repository.dart';
import '../domain/message.dart';

class ChatMessagesController
    extends FamilyAsyncNotifier<List<Message>, String> {
  late String _chatId;
  final Map<String, Message> _pendingMessages = {};

  @override
  Future<List<Message>> build(String arg) async {
    _chatId = arg;
    final messages = await ref.read(chatsRepositoryProvider).getMessages(arg);
    await ref.read(chatsRepositoryProvider).markRead(arg);
    return _mergeMessages(messages, _pendingMessages.values);
  }

  Future<void> sendTextMessage(String text) async {
    final message = await ref
        .read(chatsRepositoryProvider)
        .sendTextMessage(chatId: _chatId, text: text);
    addIncomingMessage(message);
  }

  Future<void> sendMediaMessage({required String path, String? text}) async {
    final message = await ref
        .read(chatsRepositoryProvider)
        .sendMediaMessage(chatId: _chatId, path: path, text: text);
    addIncomingMessage(message);
  }

  void addIncomingMessage(Message message) {
    final current = state.asData?.value ?? [];
    if (current.any((item) => item.id == message.id)) {
      return;
    }
    _pendingMessages[message.id] = message;
    state = AsyncData(_mergeMessages(current, [message]));
  }

  void markCurrentChatRead() {
    final current = state.asData?.value ?? [];
    state = AsyncData(
      current.map((item) => item.copyWith(readAt: DateTime.now())).toList(),
    );
  }

  List<Message> _mergeMessages(
    Iterable<Message> current,
    Iterable<Message> incoming,
  ) {
    final byId = <String, Message>{};
    for (final message in current) {
      byId[message.id] = message;
    }
    for (final message in incoming) {
      byId[message.id] = message;
    }
    return byId.values.toList()
      ..sort((first, second) => first.createdAt.compareTo(second.createdAt));
  }
}

final chatMessagesControllerProvider =
    AsyncNotifierProvider.family<ChatMessagesController, List<Message>, String>(
      ChatMessagesController.new,
    );
