import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

part 'websocket_client.dart';

class WebSocketService extends GetxService {
  final Map<String, WebSocketClient> _clients = {};

  Future<WebSocketClient> connect({
    required String name,
    String? url,
    MessageListener? listener,
    bool force = false,
  }) async {
    if (_clients.containsKey(name) &&
        _clients[name]!.status.value == WsStatus.connected) {
      return _clients[name]!._addListener(listener);
    }

    url ??= _webSocketUrl(name);
    final client = WebSocketClient(name: name, url: url)._addListener(listener);
    _clients[name] = client;
    await client._connect();
    return client;
  }

  /// Builds the WebSocket endpoint for [name] from the configured backend base.
  ///
  /// The base address already carries a scheme (`http`/`https`), so it has to be
  /// rewritten instead of being prefixed with `ws://`.
  String _webSocketUrl(String name) {
    final base = Uri.parse(ApiClient().baseAddress);
    return base
        .replace(
          scheme: base.scheme == 'https' ? 'wss' : 'ws',
          path: '/ws/$name',
        )
        .toString();
  }

  Future<void> send(String name, String message) async {
    final client = _clients[name];
    if (client != null) {
      client.send(message);
    } else {
      printInfo(info: 'ws[$name] want to send, but not connected');
    }
  }

  Future<void> close(
    String name, {
    int code = WebSocketStatus.normalClosure,
    String reason = 'normal close',
    bool reconnect = false,
  }) async {
    final client = _clients[name];
    if (client != null) {
      await client._close(code, reason, reconnect: reconnect);
      _clients.remove(name);
    }
    printInfo(info: 'ws[$name] closed');
  }

  Future<void> closeAll() async {
    // 先取出快照并清空注册表，再逐个关闭。若直接遍历 _clients 边关边等：
    // 关闭期间可能有新的 connect（例如预览面板正按新地址重连）往表里写，
    // 会抛 ConcurrentModificationError 把调用方（切换后端地址前的状态重置）
    // 整条流程带断；而末尾再 clear 又会把那些新建的连接一起抹掉，连接还开着
    // 却再也关不掉。
    final clients = _clients.values.toList();
    _clients.clear();
    for (final client in clients) {
      await client._close(WebSocketStatus.normalClosure, 'global close');
    }
    printInfo(info: 'ws all closed');
  }

  void removeAllListeners(String name) {
    final client = _clients[name];
    if (client != null) {
      client._listeners.clear();
    }
    printInfo(info: 'ws[$name] listeners removed');
  }
}
