import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/ws_service.dart';
import '../../auth/state/auth_controller.dart';

class RealtimeController extends AutoDisposeAsyncNotifier<void> {
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  Future<void> build() async {
    final session = ref.read(authControllerProvider).asData?.value;
    if (session == null) {
      return;
    }

    final wsService = ref.read(wsServiceProvider);
    _subscription?.cancel();
    final stream = wsService.connect(session.accessToken);
    _subscription = stream.listen((event) {
      ref.read(realtimeEventProvider.notifier).state = event;
      if (event['event'] == 'presence.updated') {
        final data = event['data'] as Map<String, dynamic>;
        ref
            .read(authControllerProvider.notifier)
            .updatePresence(
              userId: data['user_id'] as String,
              status: data['status'] as String,
            );
      }
    });

    ref.onDispose(() async {
      await _subscription?.cancel();
      wsService.disconnect();
    });
  }
}

final realtimeEventProvider = StateProvider<Map<String, dynamic>?>(
  (ref) => null,
);

final realtimeControllerProvider =
    AutoDisposeAsyncNotifierProvider<RealtimeController, void>(
      RealtimeController.new,
    );
