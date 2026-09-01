import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/post.dart';

final postsRepositoryProvider = Provider<PostsRepository>((ref) {
  return PostsRepository(ref.watch(apiClientProvider));
});

class PostsRepository {
  const PostsRepository(this._dio);

  final Dio _dio;

  Future<List<Post>> getUserPosts(String userId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/posts/users/$userId',
    );
    final items = response.data?['items'] as List<dynamic>? ?? [];
    return items
        .map((item) => Post.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Post>> getFeedPosts() async {
    final response = await _dio.get<Map<String, dynamic>>('/posts/feed');
    final items = response.data?['items'] as List<dynamic>? ?? [];
    return items
        .map((item) => Post.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Post> createPost(String text) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/posts',
      data: {'text': text, 'attachment_ids': const <String>[]},
    );
    return Post.fromJson(response.data!);
  }

  Future<void> likePost(String postId) async {
    await _dio.post<void>('/posts/$postId/likes');
  }

  Future<void> unlikePost(String postId) async {
    await _dio.delete<void>('/posts/$postId/likes');
  }

  Future<List<PostComment>> getComments(String postId) async {
    final response = await _dio.get<List<dynamic>>('/posts/$postId/comments');
    return (response.data ?? [])
        .map((item) => PostComment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<PostComment> createComment({
    required String postId,
    required String text,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/posts/$postId/comments',
      data: {'text': text},
    );
    return PostComment.fromJson(response.data!);
  }
}
