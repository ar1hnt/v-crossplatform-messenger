import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/state/auth_controller.dart';
import '../../features/chats/presentation/chat_detail_screen.dart';
import '../../features/chats/presentation/chats_screen.dart';
import '../../features/contacts/presentation/contacts_screen.dart';
import '../../features/posts/presentation/feed_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/common/presentation/navigation_shell.dart';
import '../../features/common/presentation/splash_screen.dart';
import '../../features/search/presentation/public_profile_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/profile/domain/user_profile.dart';

final _routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier();
  ref.listen(authControllerProvider, (previous, next) {
    notifier.refresh();
  });
  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(_routerRefreshProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isLoading = authState.isLoading;
      final isAuthenticated = authState.asData?.value != null;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isSplash = state.matchedLocation == '/splash';

      if (isLoading && !isSplash) {
        return '/splash';
      }
      if (!isLoading && isSplash) {
        return isAuthenticated ? '/feed' : '/login';
      }
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }
      if (isAuthenticated && isAuthRoute) {
        return '/feed';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/feed',
        builder: (context, state) => const NavigationShell(
          currentLocation: '/feed',
          child: FeedScreen(),
        ),
      ),
      GoRoute(
        path: '/chats',
        builder: (context, state) => const NavigationShell(
          currentLocation: '/chats',
          child: ChatsScreen(),
        ),
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const NavigationShell(
          currentLocation: '/contacts',
          child: ContactsScreen(),
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const NavigationShell(
          currentLocation: '/profile',
          child: ProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/users/:userId',
        builder: (context, state) =>
            PublicProfileScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/chats/:chatId',
        builder: (context, state) => ChatDetailScreen(
          chatId: state.pathParameters['chatId']!,
          title: state.uri.queryParameters['title'] ?? 'Диалог',
          peer: state.extra is UserProfile ? state.extra! as UserProfile : null,
        ),
      ),
    ],
  );
});

class RouterRefreshNotifier extends ChangeNotifier {
  void refresh() {
    notifyListeners();
  }
}
