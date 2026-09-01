import '../../profile/domain/user_profile.dart';
import 'message.dart';

class Chat {
  const Chat({
    required this.id,
    required this.createdById,
    required this.peerUser,
    required this.lastMessage,
  });

  final String id;
  final String createdById;
  final UserProfile? peerUser;
  final Message? lastMessage;

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'] as String,
      createdById: json['created_by_id'] as String,
      peerUser: json['peer_user'] != null
          ? UserProfile.fromJson(json['peer_user'] as Map<String, dynamic>)
          : null,
      lastMessage: json['last_message'] != null
          ? Message.fromJson(json['last_message'] as Map<String, dynamic>)
          : null,
    );
  }
}
