import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_controller.dart';
import '../data/chats_repository.dart';
import '../domain/chat.dart';

class ChatsController extends AsyncNotifier<List<Chat>> {
  @override
  Future<List<Chat>> build() async {
    final session = ref.watch(authControllerProvider).asData?.value;
    if (session == null) {
      return [];
    }
    return ref.read(chatsRepositoryProvider).getChats();
  }

  Future<void> refreshChats() async {
    if (state.isLoading) {
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(chatsRepositoryProvider).getChats(),
    );
  }
}

final chatsControllerProvider =
    AsyncNotifierProvider<ChatsController, List<Chat>>(ChatsController.new);
