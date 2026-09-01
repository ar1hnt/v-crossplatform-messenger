import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../profile/domain/user_profile.dart';
import '../../data/posts_repository.dart';
import '../../domain/post.dart';

class PostCard extends ConsumerStatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onLikePressed,
    required this.onCommentCreated,
    this.authorName,
  });

  final Post post;
  final String? authorName;
  final Future<void> Function(Post post) onLikePressed;
  final Future<PostComment> Function(Post post, String text) onCommentCreated;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  final _commentController = TextEditingController();
  bool _isCommenting = false;
  bool _isLoadingComments = false;
  String? _commentsError;
  List<PostComment>? _comments;

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _isCommenting = false;
      _isLoadingComments = false;
      _commentsError = null;
      _comments = null;
      _commentController.clear();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authorName =
        widget.authorName ?? widget.post.author?.fullName ?? 'Пользователь';
    final author = widget.post.author;
    final accessToken = ref
        .watch(authControllerProvider)
        .asData
        ?.value
        ?.accessToken;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(
                  fullName: authorName,
                  avatarFileId: author?.avatarFileId,
                  avatarUrl: author?.avatarUrl,
                  accessToken: accessToken,
                  radius: 22,
                  isOnline: author?.presenceStatus == 'online',
                  onTap: author == null ? null : () => _openProfile(author),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: author == null ? null : () => _openProfile(author),
                    borderRadius: BorderRadius.circular(6),
                    child: Text(
                      authorName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                Text(
                  widget.post.createdAt.toLocal().toString().substring(0, 16),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'POST // ${widget.post.id.substring(0, 8).toUpperCase()}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.neonLime,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.post.text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                IconButton(
                  tooltip: widget.post.isLiked ? 'Убрать лайк' : 'Лайк',
                  onPressed: () => widget.onLikePressed(widget.post),
                  icon: Icon(
                    widget.post.isLiked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: widget.post.isLiked
                        ? AppTheme.neonPink
                        : AppTheme.textSecondary,
                  ),
                ),
                Text('${widget.post.likesCount}'),
                const SizedBox(width: 18),
                IconButton(
                  tooltip: 'Комментарии',
                  onPressed: () {
                    final nextValue = !_isCommenting;
                    setState(() => _isCommenting = nextValue);
                    if (nextValue && _comments == null) {
                      _loadComments();
                    }
                  },
                  icon: const Icon(Icons.mode_comment_outlined),
                ),
                Text('${widget.post.commentsCount}'),
              ],
            ),
            if (_isCommenting) ...[
              const SizedBox(height: 12),
              _buildComments(context),
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Написать комментарий',
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () async {
                    final text = _commentController.text.trim();
                    if (text.isEmpty) {
                      return;
                    }
                    final comment = await widget.onCommentCreated(
                      widget.post,
                      text,
                    );
                    _commentController.clear();
                    if (mounted) {
                      setState(() {
                        _comments = [...?_comments, comment];
                        _commentsError = null;
                      });
                    }
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Отправить'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoadingComments = true;
      _commentsError = null;
    });

    try {
      final comments = await ref
          .read(postsRepositoryProvider)
          .getComments(widget.post.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _commentsError = 'Не удалось загрузить комментарии: $error';
        _isLoadingComments = false;
      });
    }
  }

  Widget _buildComments(BuildContext context) {
    final accessToken = ref
        .watch(authControllerProvider)
        .asData
        ?.value
        ?.accessToken;

    if (_isLoadingComments) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_commentsError != null) {
      return Text(
        _commentsError!,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final comments = _comments ?? const <PostComment>[];
    if (comments.isEmpty) {
      return Text(
        'Комментариев пока нет',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
      );
    }

    return Column(
      children: comments
          .map(
            (comment) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.panelStrong.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.neonPink.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        UserAvatar(
                          fullName: comment.author?.fullName ?? 'Пользователь',
                          avatarFileId: comment.author?.avatarFileId,
                          avatarUrl: comment.author?.avatarUrl,
                          accessToken: accessToken,
                          radius: 16,
                          isOnline: comment.author?.presenceStatus == 'online',
                          onTap: comment.author == null
                              ? null
                              : () => _openProfile(comment.author!),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: comment.author == null
                                ? null
                                : () => _openProfile(comment.author!),
                            borderRadius: BorderRadius.circular(6),
                            child: Text(
                              comment.author?.fullName ?? 'Пользователь',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: AppTheme.textPrimary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment.text,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  void _openProfile(UserProfile user) {
    final currentUserId = ref
        .read(authControllerProvider)
        .asData
        ?.value
        ?.user
        .id;
    if (currentUserId == user.id) {
      context.push('/profile');
      return;
    }
    context.push('/users/${user.id}');
  }
}
