import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../state/posts_controller.dart';
import 'widgets/post_card.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  @override
  Widget build(BuildContext context) {
    final postsState = ref.watch(feedPostsControllerProvider);

    return AppScaffold(
      title: 'Лента',
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(feedPostsControllerProvider.notifier).refreshPosts(),
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.neonCyan.withValues(alpha: 0.14),
                    AppTheme.neonPink.withValues(alpha: 0.08),
                  ],
                ),
                border: Border.all(
                  color: AppTheme.neonCyan.withValues(alpha: 0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FEED',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Посты людей, с которыми ты переписывался, и зарегистрированных контактов.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...postsState.when(
              data: (posts) {
                if (posts.isEmpty) {
                  return const [
                    Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text('Пока нет постов от контактов и диалогов'),
                      ),
                    ),
                  ];
                }
                return posts
                    .map(
                      (post) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: PostCard(
                          post: post,
                          onLikePressed: ref
                              .read(feedPostsControllerProvider.notifier)
                              .toggleLike,
                          onCommentCreated: (post, text) => ref
                              .read(feedPostsControllerProvider.notifier)
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
                  child: Text('Не удалось загрузить ленту: $error'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
