import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/push/push_registration_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../profile/data/profile_repository.dart';
import '../data/auth_repository.dart';
import '../domain/auth_session.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  );
});

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final repository = ref.read(authRepositoryProvider);
    final accessToken = await repository.readAccessToken();
    final refreshToken = await repository.readRefreshToken();

    if (accessToken == null || refreshToken == null) {
      return null;
    }

    try {
      final user = await repository.fetchCurrentUser();
      await _registerPushDevice();
      return AuthSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
      );
    } catch (_) {
      await repository.logout();
      return null;
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      final tokens = await repository.login(email: email, password: password);
      final user = await repository.fetchCurrentUser();
      await _registerPushDevice();
      return AuthSession.fromAuthJson(tokensJson: tokens, user: user);
    });
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      final tokens = await repository.register(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      final user = await repository.fetchCurrentUser();
      await _registerPushDevice();
      return AuthSession.fromAuthJson(tokensJson: tokens, user: user);
    });
  }

  Future<void> updateProfile({
    required String fullName,
    required String? phone,
    required String? bio,
    String? avatarFileId,
  }) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    final updatedUser = await ref
        .read(profileRepositoryProvider)
        .updateMe(
          fullName: fullName,
          phone: phone,
          bio: bio,
          avatarFileId: avatarFileId,
        );
    state = AsyncData(current.copyWith(user: updatedUser));
  }

  Future<void> logout() async {
    try {
      await _unregisterPushDevice();
      await ref.read(authRepositoryProvider).logout();
    } finally {
      state = const AsyncData(null);
    }
  }

  void updatePresence({required String userId, required String status}) {
    final current = state.asData?.value;
    if (current == null || current.user.id != userId) {
      return;
    }
    state = AsyncData(
      current.copyWith(user: current.user.copyWith(presenceStatus: status)),
    );
  }

  Future<void> _registerPushDevice() async {
    try {
      await ref.read(pushRegistrationServiceProvider).registerCurrentDevice();
    } catch (_) {
      // Push registration must not block auth.
    }
  }

  Future<void> _unregisterPushDevice() async {
    try {
      await ref.read(pushRegistrationServiceProvider).unregisterCurrentDevice();
    } catch (_) {
      // Push unregister must not block logout.
    }
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);
