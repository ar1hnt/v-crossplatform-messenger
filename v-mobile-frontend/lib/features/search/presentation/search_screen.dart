import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/state/auth_controller.dart';
import '../../chats/data/chats_repository.dart';
import '../state/search_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_queueSearch);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_queueSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _queueSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      ref
          .read(searchControllerProvider.notifier)
          .search(_searchController.text);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final resultsState = ref.watch(searchControllerProvider);
    final currentUserId = ref
        .watch(authControllerProvider)
        .asData
        ?.value
        ?.user
        .id;
    final accessToken = ref
        .watch(authControllerProvider)
        .asData
        ?.value
        ?.accessToken;

    return AppScaffold(
      title: 'Поиск друзей',
      body: Column(
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) =>
                ref.read(searchControllerProvider.notifier).search(value),
            decoration: InputDecoration(
              hintText: 'Введите ФИО или часть имени',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Очистить',
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: resultsState.when(
              data: (users) {
                final filteredUsers = users
                    .where((user) => user.id != currentUserId)
                    .toList();
                if (_searchController.text.trim().isEmpty) {
                  return const Center(
                    child: Text('Начни вводить ФИО, чтобы найти пользователя'),
                  );
                }
                if (filteredUsers.isEmpty) {
                  return const Center(child: Text('Ничего не найдено'));
                }
                return ListView.separated(
                  itemCount: filteredUsers.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('/users/${user.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  UserAvatar(
                                    fullName: user.fullName,
                                    avatarFileId: user.avatarFileId,
                                    avatarUrl: user.avatarUrl,
                                    accessToken: accessToken,
                                    radius: 26,
                                    isOnline: user.presenceStatus == 'online',
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.fullName,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(user.email),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(user.bio ?? 'Без описания'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  OutlinedButton(
                                    onPressed: () =>
                                        context.push('/users/${user.id}'),
                                    child: const Text('Профиль'),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton(
                                    onPressed: () async {
                                      final chat = await ref
                                          .read(chatsRepositoryProvider)
                                          .createOrGetPrivateChat(user.id);
                                      if (context.mounted) {
                                        context.push(
                                          '/chats/${chat.id}?title=${Uri.encodeComponent(user.fullName)}',
                                          extra: user,
                                        );
                                      }
                                    },
                                    child: const Text('Написать'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Не удалось выполнить поиск: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
