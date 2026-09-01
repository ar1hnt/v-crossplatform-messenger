import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';

class WsService {
  WebSocketChannel? _channel;

  Stream<Map<String, dynamic>> connect(String token) {
    _channel?.sink.close();
    _channel = WebSocketChannel.connect(
      Uri.parse('${AppConfig.webSocketUrl}?token=$token'),
    );
    return _channel!.stream.map((event) {
      if (event is String) {
        return jsonDecode(event) as Map<String, dynamic>;
      }
      return <String, dynamic>{};
    });
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}

final wsServiceProvider = Provider<WsService>((ref) => WsService());
