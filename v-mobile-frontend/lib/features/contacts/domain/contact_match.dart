import '../../profile/domain/user_profile.dart';

class ContactMatch {
  const ContactMatch({
    required this.id,
    required this.contactName,
    required this.phoneNumber,
    this.matchedUser,
  });

  final String id;
  final String contactName;
  final String phoneNumber;
  final UserProfile? matchedUser;

  factory ContactMatch.fromJson(Map<String, dynamic> json) {
    return ContactMatch(
      id: json['id'] as String,
      contactName: json['contact_name'] as String,
      phoneNumber: json['phone_number'] as String,
      matchedUser: json['matched_user'] != null
          ? UserProfile.fromJson(json['matched_user'] as Map<String, dynamic>)
          : null,
    );
  }
}
