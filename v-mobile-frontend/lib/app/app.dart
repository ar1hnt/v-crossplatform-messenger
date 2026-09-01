import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/state/auth_controller.dart';
import '../features/chats/state/realtime_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class VMessengerApp extends ConsumerWidget {
  const VMessengerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final authSession = ref.watch(authControllerProvider).asData?.value;

    if (authSession != null) {
      ref.watch(realtimeControllerProvider);
    }

    return MaterialApp.router(
      title: 'NEOCHAT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
