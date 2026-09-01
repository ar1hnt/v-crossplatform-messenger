import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/domain/user_profile.dart';
import '../data/search_repository.dart';

class SearchController extends AutoDisposeAsyncNotifier<List<UserProfile>> {
  @override
  Future<List<UserProfile>> build() async => const [];

  Future<void> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      state = const AsyncData([]);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(searchRepositoryProvider).searchUsers(normalized),
    );
  }
}

final searchControllerProvider =
    AutoDisposeAsyncNotifierProvider<SearchController, List<UserProfile>>(
      SearchController.new,
    );
