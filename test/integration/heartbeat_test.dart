@Tags(['integration'])
library;

import 'dart:async';

import 'package:socket_client/socket_client.dart';
import 'package:test/test.dart';

import '../helpers/server_guard.dart';
import '../helpers/test_client_factory.dart';

void main() {
  setUpAll(assertServerRunning);

  test('client stays connected through multiple heartbeat cycles', () async {
    final client = TestClientFactory.create(
      heartbeat: const HeartbeatConfig(interval: Duration(seconds: 1)),
    );
    await client.connect();

    // Let 3 heartbeat cycles pass
    await Future<void>.delayed(const Duration(seconds: 4));

    expect(client.state, SocketConnectionState.connected);

    await client.disconnect();
  });
}
