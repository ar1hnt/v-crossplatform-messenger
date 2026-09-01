import '../../profile/domain/user_profile.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final UserProfile user;

  factory AuthSession.fromAuthJson({
    required Map<String, dynamic> tokensJson,
    required UserProfile user,
  }) {
    return AuthSession(
      accessToken: tokensJson['access_token'] as String,
      refreshToken: tokensJson['refresh_token'] as String,
      user: user,
    );
  }

  AuthSession copyWith({UserProfile? user}) {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user ?? this.user,
    );
  }
}
