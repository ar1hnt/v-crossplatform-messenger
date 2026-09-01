import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

final pushRegistrationServiceProvider = Provider<PushRegistrationService>((
  ref,
) {
  return PushRegistrationService(ref.watch(apiClientProvider));
});

class PushRegistrationService {
  PushRegistrationService(this._dio);

  final Dio _dio;
  bool _isListeningForTokenRefresh = false;

  Future<void> registerCurrentDevice() async {
    if (kIsWeb) {
      return;
    }

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Push permission denied');
      return;
    }

    await _waitForApnsTokenIfNeeded(messaging);
    final token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('FCM token is empty; push device was not registered');
      return;
    }

    await _registerToken(token);
    if (!_isListeningForTokenRefresh) {
      _isListeningForTokenRefresh = true;
      messaging.onTokenRefresh.listen((token) async {
        try {
          await _registerToken(token);
        } catch (error) {
          debugPrint('Failed to refresh FCM token on backend: $error');
        }
      });
    }
  }

  Future<void> unregisterCurrentDevice() async {
    if (kIsWeb) {
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    await _dio.delete<void>(
      '/push/devices',
      queryParameters: {'push_token': token},
    );
  }

  Future<void> _registerToken(String token) async {
    await _dio.post<void>(
      '/push/devices',
      data: {
        'device_id': token.length <= 255 ? token : token.substring(0, 255),
        'push_token': token,
        'platform': defaultTargetPlatform.name,
      },
    );
    debugPrint('FCM token registered on backend');
  }

  Future<void> _waitForApnsTokenIfNeeded(FirebaseMessaging messaging) async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }

    for (var attempt = 0; attempt < 10; attempt += 1) {
      final apnsToken = await messaging.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    debugPrint('APNs token is not ready yet; FCM token may be unavailable');
  }
}
