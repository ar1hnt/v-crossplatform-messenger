import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../profile/domain/user_profile.dart';

class AuthRepository {
  const AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final SecureStorageService _storage;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final payload = response.data!;
      await _storage.saveTokens(
        accessToken: payload['access_token'] as String,
        refreshToken: payload['refresh_token'] as String,
      );
      return payload;
    } on DioException catch (error) {
      throw ApiException.fromDioError(
        error,
        fallbackMessage: 'Не удалось выполнить вход',
      );
    }
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'full_name': fullName,
          'phone': phone,
        },
      );
      final payload = response.data!;
      await _storage.saveTokens(
        accessToken: payload['access_token'] as String,
        refreshToken: payload['refresh_token'] as String,
      );
      return payload;
    } on DioException catch (error) {
      throw ApiException.fromDioError(
        error,
        fallbackMessage: 'Не удалось зарегистрироваться',
      );
    }
  }

  Future<UserProfile> fetchCurrentUser() async {
    final response = await _dio.get<Map<String, dynamic>>('/users/me');
    return UserProfile.fromJson(response.data!);
  }

  Future<void> logout() async {
    final refreshToken = await _storage.readRefreshToken();
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _dio.post<void>(
          '/auth/logout',
          options: Options(headers: {'Authorization': 'Bearer $refreshToken'}),
        );
      }
    } finally {
      await _storage.clear();
    }
  }

  Future<String?> readAccessToken() => _storage.readAccessToken();

  Future<String?> readRefreshToken() => _storage.readRefreshToken();
}
