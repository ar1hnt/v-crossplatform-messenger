import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../../../core/network/api_client.dart';
import '../domain/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

class ProfileRepository {
  const ProfileRepository(this._dio);

  final Dio _dio;

  Future<UserProfile> updateMe({
    required String fullName,
    required String? phone,
    required String? bio,
    String? avatarFileId,
  }) async {
    final data = <String, dynamic>{
      'full_name': fullName,
      'phone': phone,
      'bio': bio,
    };
    if (avatarFileId != null) {
      data['avatar_file_id'] = avatarFileId;
    }
    final response = await _dio.patch<Map<String, dynamic>>(
      '/users/me',
      data: data,
    );
    return UserProfile.fromJson(response.data!);
  }

  Future<String> uploadAvatar(String path) async {
    final mimeType = lookupMimeType(path) ?? 'image/jpeg';
    final response = await _dio.post<Map<String, dynamic>>(
      '/files/upload',
      data: FormData.fromMap({
        'kind': 'avatar',
        'file': await MultipartFile.fromFile(
          path,
          contentType: MediaType.parse(mimeType),
        ),
      }),
    );
    return response.data!['id'] as String;
  }
}
