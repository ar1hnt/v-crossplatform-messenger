import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_controller.dart';
import '../data/posts_repository.dart';
import '../domain/post.dart';

class PostsController extends AsyncNotifier<List<Post>> {
  @override
  Future<List<Post>> build() async {
    final session = ref.watch(authControllerProvider).asData?.value;
    if (session == null) {
      return [];
    }
    return ref.read(postsRepositoryProvider).getUserPosts(session.user.id);
  }

  Future<void> refreshPosts() async {
    if (state.isLoading) {
      return;
    }
    state = const AsyncLoading();
    final session = ref.read(authControllerProvider).asData?.value;
    if (session == null) {
      state = const AsyncData([]);
      return;
    }
    state = await AsyncValue.guard(
      () => ref.read(postsRepositoryProvider).getUserPosts(session.user.id),
    );
  }

  Future<void> createPost(String text) async {
    final session = ref.read(authControllerProvider).asData?.value;
    if (session == null) {
      return;
    }

    final createdPost = await ref
        .read(postsRepositoryProvider)
        .createPost(text);
    if (createdPost.authorId != session.user.id) {
      await refreshPosts();
      return;
    }

    final currentPosts = state.asData?.value ?? [];
    state = AsyncData([createdPost, ...currentPosts]);
  }

  Future<void> toggleLike(Post post) async {
    await _togglePostLike(post);
  }

  Future<PostComment> addComment({
    required Post post,
    required String text,
  }) async {
    return _addPostComment(post: post, text: text);
  }

  Future<void> _togglePostLike(Post post) async {
    if (post.isLiked) {
      await ref.read(postsRepositoryProvider).unlikePost(post.id);
      _replacePost(
        post.copyWith(
          isLiked: false,
          likesCount: post.likesCount > 0 ? post.likesCount - 1 : 0,
        ),
      );
      return;
    }

    await ref.read(postsRepositoryProvider).likePost(post.id);
    _replacePost(post.copyWith(isLiked: true, likesCount: post.likesCount + 1));
  }

  Future<PostComment> _addPostComment({
    required Post post,
    required String text,
  }) async {
    final comment = await ref
        .read(postsRepositoryProvider)
        .createComment(postId: post.id, text: text);
    _replacePost(post.copyWith(commentsCount: post.commentsCount + 1));
    return comment;
  }

  void _replacePost(Post updatedPost) {
    final currentPosts = state.asData?.value ?? [];
    state = AsyncData(
      currentPosts
          .map((post) => post.id == updatedPost.id ? updatedPost : post)
          .toList(),
    );
  }
}

final postsControllerProvider =
    AsyncNotifierProvider<PostsController, List<Post>>(PostsController.new);

class FeedPostsController extends AsyncNotifier<List<Post>> {
  @override
  Future<List<Post>> build() async {
    final session = ref.watch(authControllerProvider).asData?.value;
    if (session == null) {
      return [];
    }
    return ref.read(postsRepositoryProvider).getFeedPosts();
  }

  Future<void> refreshPosts() async {
    if (state.isLoading) {
      return;
    }
    state = const AsyncLoading();
    final session = ref.read(authControllerProvider).asData?.value;
    if (session == null) {
      state = const AsyncData([]);
      return;
    }
    state = await AsyncValue.guard(
      () => ref.read(postsRepositoryProvider).getFeedPosts(),
    );
  }

  Future<void> toggleLike(Post post) async {
    if (post.isLiked) {
      await ref.read(postsRepositoryProvider).unlikePost(post.id);
      _replacePost(
        post.copyWith(
          isLiked: false,
          likesCount: post.likesCount > 0 ? post.likesCount - 1 : 0,
        ),
      );
      return;
    }

    await ref.read(postsRepositoryProvider).likePost(post.id);
    _replacePost(post.copyWith(isLiked: true, likesCount: post.likesCount + 1));
  }

  Future<PostComment> addComment({
    required Post post,
    required String text,
  }) async {
    final comment = await ref
        .read(postsRepositoryProvider)
        .createComment(postId: post.id, text: text);
    _replacePost(post.copyWith(commentsCount: post.commentsCount + 1));
    return comment;
  }

  void _replacePost(Post updatedPost) {
    final currentPosts = state.asData?.value ?? [];
    state = AsyncData(
      currentPosts
          .map((post) => post.id == updatedPost.id ? updatedPost : post)
          .toList(),
    );
  }
}

final feedPostsControllerProvider =
    AsyncNotifierProvider<FeedPostsController, List<Post>>(
      FeedPostsController.new,
    );

class UserPostsController extends FamilyAsyncNotifier<List<Post>, String> {
  late String _userId;

  @override
  Future<List<Post>> build(String arg) async {
    _userId = arg;
    ref.watch(authControllerProvider);
    return ref.read(postsRepositoryProvider).getUserPosts(arg);
  }

  Future<void> refreshPosts() async {
    if (state.isLoading) {
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(postsRepositoryProvider).getUserPosts(_userId),
    );
  }

  Future<void> toggleLike(Post post) async {
    if (post.isLiked) {
      await ref.read(postsRepositoryProvider).unlikePost(post.id);
      _replacePost(
        post.copyWith(
          isLiked: false,
          likesCount: post.likesCount > 0 ? post.likesCount - 1 : 0,
        ),
      );
      return;
    }

    await ref.read(postsRepositoryProvider).likePost(post.id);
    _replacePost(post.copyWith(isLiked: true, likesCount: post.likesCount + 1));
  }

  Future<PostComment> addComment({
    required Post post,
    required String text,
  }) async {
    final comment = await ref
        .read(postsRepositoryProvider)
        .createComment(postId: post.id, text: text);
    _replacePost(post.copyWith(commentsCount: post.commentsCount + 1));
    return comment;
  }

  void _replacePost(Post updatedPost) {
    final currentPosts = state.asData?.value ?? [];
    state = AsyncData(
      currentPosts
          .map((post) => post.id == updatedPost.id ? updatedPost : post)
          .toList(),
    );
  }
}

final userPostsControllerProvider =
    AsyncNotifierProvider.family<UserPostsController, List<Post>, String>(
      UserPostsController.new,
    );
