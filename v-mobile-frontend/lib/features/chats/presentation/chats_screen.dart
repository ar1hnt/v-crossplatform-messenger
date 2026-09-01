import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/state/auth_controller.dart';
import '../state/chats_controller.dart';
import '../state/realtime_controller.dart';

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  ProviderSubscription<Map<String, dynamic>?>? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _realtimeSubscription = ref.listenManual(realtimeEventProvider, (
      previous,
      next,
    ) {
      if (next == null) {
        return;
      }
      if (next['event'] == 'message.created' ||
          next['event'] == 'presence.updated') {
        ref.read(chatsControllerProvider.notifier).refreshChats();
      }
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatsState = ref.watch(chatsControllerProvider);
    final accessToken = ref
        .watch(authControllerProvider)
        .asData
        ?.value
        ?.accessToken;

    return AppScaffold(
      title: 'Чаты',
      actions: [
        IconButton(
          onPressed: () => context.push('/search'),
          icon: const Icon(Icons.person_search_outlined),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(chatsControllerProvider.notifier).refreshChats(),
        child: chatsState.when(
          data: (chats) {
            if (chats.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Чатов пока нет')),
                ],
              );
            }
            return ListView.separated(
              itemCount: chats.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final chat = chats[index];
                final peer = chat.peerUser;
                final isOnline = peer?.presenceStatus == 'online';
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    onTap: () => context.push(
                      '/chats/${chat.id}?title=${Uri.encodeComponent(peer?.fullName ?? 'Диалог')}',
                      extra: peer,
                    ),
                    leading: UserAvatar(
                      fullName: peer?.fullName ?? 'Диалог',
                      avatarFileId: peer?.avatarFileId,
                      avatarUrl: peer?.avatarUrl,
                      accessToken: accessToken,
                      radius: 24,
                      isOnline: isOnline,
                      onTap: peer == null
                          ? null
                          : () => context.push('/users/${peer.id}'),
                    ),
                    title: Text(
                      peer?.fullName ?? 'Диалог',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    subtitle: Text(
                      chat.lastMessage?.text ?? 'Сообщений пока нет',
                    ),
                    trailing: Text(
                      chat.lastMessage?.createdAt
                              .toLocal()
                              .toString()
                              .substring(11, 16) ??
                          '',
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Не удалось загрузить чаты: $error')),
        ),
      ),
    );
  }
}
