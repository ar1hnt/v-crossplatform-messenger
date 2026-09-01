class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.bio,
    required this.presenceStatus,
    this.avatarFileId,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? bio;
  final String presenceStatus;
  final String? avatarFileId;
  final String? avatarUrl;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar'] as Map<String, dynamic>?;
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      bio: json['bio'] as String?,
      presenceStatus: json['presence_status'] as String? ?? 'offline',
      avatarFileId: avatar?['id'] as String?,
      avatarUrl: avatar?['url'] as String?,
    );
  }

  UserProfile copyWith({
    String? fullName,
    String? phone,
    String? bio,
    String? presenceStatus,
    String? avatarFileId,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      presenceStatus: presenceStatus ?? this.presenceStatus,
      avatarFileId: avatarFileId ?? this.avatarFileId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
