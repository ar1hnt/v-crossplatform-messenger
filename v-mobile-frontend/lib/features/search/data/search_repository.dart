import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../profile/domain/user_profile.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(apiClientProvider));
});

class SearchRepository {
  const SearchRepository(this._dio);

  final Dio _dio;

  Future<List<UserProfile>> searchUsers(String query) async {
    final response = await _dio.get<List<dynamic>>(
      '/users/search',
      queryParameters: {'q': query},
    );
    return (response.data ?? [])
        .map((item) => UserProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<UserProfile> getUserById(String userId) async {
    final response = await _dio.get<Map<String, dynamic>>('/users/$userId');
    return UserProfile.fromJson(response.data!);
  }
}
