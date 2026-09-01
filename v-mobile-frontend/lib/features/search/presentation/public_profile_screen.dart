import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../chats/data/chats_repository.dart';
import '../../auth/state/auth_controller.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../../posts/state/posts_controller.dart';
import '../data/search_repository.dart';

final publicProfileProvider = FutureProvider.autoDispose.family((
  ref,
  String userId,
) {
  return ref.watch(searchRepositoryProvider).getUserById(userId);
});

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(publicProfileProvider(userId));
    final postsState = ref.watch(userPostsControllerProvider(userId));
    final accessToken = ref
        .watch(authControllerProvider)
        .asData
        ?.value
        ?.accessToken;

    return AppScaffold(
      title: 'Профиль пользователя',
      body: profileState.when(
        data: (user) {
          final bioText = user.bio?.trim();

          return ListView(
            children: [
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.neonCyan.withValues(alpha: 0.24),
                      AppTheme.neonPink.withValues(alpha: 0.16),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: AppTheme.neonCyan.withValues(alpha: 0.24),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      UserAvatar(
                        fullName: user.fullName,
                        avatarFileId: user.avatarFileId,
                        avatarUrl: user.avatarUrl,
                        accessToken: accessToken,
                        radius: 38,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.presenceStatus,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.fullName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
              ),
              // const SizedBox(height: 20),
              // Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'О себе',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        bioText == null || bioText.isEmpty
                            ? 'Пользователь пока ничего не написал о себе.'
                            : bioText,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: bioText == null || bioText.isEmpty
                              ? AppTheme.textSecondary
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
                child: const Text('Написать сообщение'),
              ),
              const SizedBox(height: 24),
              Text('Посты', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...postsState.when(
                data: (posts) {
                  if (posts.isEmpty) {
                    return const [
                      Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: Text('Постов пока нет')),
                      ),
                    ];
                  }
                  return posts
                      .map(
                        (post) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: PostCard(
                            post: post,
                            authorName: user.fullName,
                            onLikePressed: ref
                                .read(
                                  userPostsControllerProvider(userId).notifier,
                                )
                                .toggleLike,
                            onCommentCreated: (post, text) => ref
                                .read(
                                  userPostsControllerProvider(userId).notifier,
                                )
                                .addComment(post: post, text: text),
                          ),
                        ),
                      )
                      .toList();
                },
                loading: () => const [
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ],
                error: (error, _) => [
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text('Не удалось загрузить посты: $error'),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Не удалось загрузить профиль: $error')),
      ),
    );
  }
}
