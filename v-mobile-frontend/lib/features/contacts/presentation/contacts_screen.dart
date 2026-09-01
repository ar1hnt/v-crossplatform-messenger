import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/state/auth_controller.dart';
import '../../chats/data/chats_repository.dart';
import '../state/contacts_controller.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsState = ref.watch(contactsControllerProvider);
    final accessToken = ref
        .watch(authControllerProvider)
        .asData
        ?.value
        ?.accessToken;

    return AppScaffold(
      title: 'Контакты',
      actions: [
        IconButton(
          onPressed: () => context.push('/search'),
          icon: const Icon(Icons.person_search_outlined),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed: () =>
                ref.read(contactsControllerProvider.notifier).syncContacts(),
            icon: const Icon(Icons.sync),
            label: const Text('Синхронизировать телефонную книгу'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: contactsState.when(
              data: (matches) {
                if (matches.isEmpty) {
                  return const Center(child: Text('Совпадений пока нет'));
                }
                return ListView.separated(
                  itemCount: matches.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = matches[index];
                    final matchedUser = item.matchedUser;
                    return Card(
                      child: ListTile(
                        onTap: matchedUser == null
                            ? null
                            : () => context.push('/users/${matchedUser.id}'),
                        leading: matchedUser == null
                            ? UserAvatar(fullName: item.contactName, radius: 22)
                            : UserAvatar(
                                fullName: matchedUser.fullName,
                                avatarFileId: matchedUser.avatarFileId,
                                avatarUrl: matchedUser.avatarUrl,
                                accessToken: accessToken,
                                radius: 22,
                                isOnline:
                                    matchedUser.presenceStatus == 'online',
                              ),
                        title: Text(item.contactName),
                        subtitle: Text(
                          matchedUser?.fullName ?? item.phoneNumber,
                        ),
                        trailing: matchedUser == null
                            ? const Text('не зарегистрирован')
                            : FilledButton(
                                onPressed: () async {
                                  final chat = await ref
                                      .read(chatsRepositoryProvider)
                                      .createOrGetPrivateChat(matchedUser.id);
                                  if (context.mounted) {
                                    context.push(
                                      '/chats/${chat.id}?title=${Uri.encodeComponent(matchedUser.fullName)}',
                                      extra: matchedUser,
                                    );
                                  }
                                },
                                child: const Text('Написать'),
                              ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Ошибка синхронизации: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
