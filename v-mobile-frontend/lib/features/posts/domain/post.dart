import '../../profile/domain/user_profile.dart';

class Post {
  const Post({
    required this.id,
    required this.authorId,
    required this.author,
    required this.text,
    required this.createdAt,
    required this.likesCount,
    required this.commentsCount,
    required this.isLiked,
  });

  final String id;
  final String authorId;
  final UserProfile? author;
  final String text;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      author: json['author'] != null
          ? UserProfile.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
    );
  }

  Post copyWith({int? likesCount, int? commentsCount, bool? isLiked}) {
    return Post(
      id: id,
      authorId: authorId,
      author: author,
      text: text,
      createdAt: createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.author,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final UserProfile? author;
  final String text;
  final DateTime createdAt;

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      authorId: json['author_id'] as String,
      author: json['author'] != null
          ? UserProfile.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
