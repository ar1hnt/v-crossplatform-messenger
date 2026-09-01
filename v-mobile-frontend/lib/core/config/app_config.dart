import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class AppConfig {
  static const _definedHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );
  static const _definedPort = String.fromEnvironment(
    'API_PORT',
    defaultValue: '8000',
  );

  static String get host {
    if (_definedHost.isNotEmpty) {
      return _definedHost;
    }
    if (kIsWeb) {
      return 'localhost';
    }
    if (Platform.isAndroid) {
      // Android-эмулятор обращается к хост-машине через 10.0.2.2.
      return '10.0.2.2';
    }
    // Для iPhone/реального iPad нужно передавать IP компьютера через --dart-define=API_HOST=...
    return 'localhost';
  }

  static String get port => _definedPort;

  static String get apiBaseUrl => 'http://$host:$port/api/v1';

  static String get webSocketUrl => 'ws://$host:$port/ws';
}
