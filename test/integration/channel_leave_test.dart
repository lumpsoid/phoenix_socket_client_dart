@Tags(['integration'])
library;

import 'package:phoenix_socket_client/src/phoenix_channel_state.dart';
import 'package:phoenix_socket_client/src/phoenix_client.dart';
import 'package:test/test.dart';

import '../helpers/server_guard.dart';
import '../helpers/test_client_factory.dart';

void main() {
  late PhoenixClient client;

  setUpAll(assertServerRunning);

  setUp(() async {
    client = TestClientFactory.create();
    await client.connect();
  });

  tearDown(() => client.disconnect());

  group('leave', () {
    test('leave transitions channel to closed state', () async {
      final channel = TestClientFactory.makeChannel(client, 'ok:leave_test');
      await channel.join();

      final states = <PhoenixChannelState>[];
      channel.stateStream.listen((c) => states.add(c.current));

      await channel.leave();

      expect(channel.state, PhoenixChannelState.closed);
      expect(channel.isJoined, isFalse);
    });

    test('leave on already-closed channel is a no-op', () async {
      final channel = TestClientFactory.makeChannel(client, 'ok:leave_noop');
      // Never joined — state is already closed
      await expectLater(channel.leave(), completes);
    });

    test('cannot push after leaving', () async {
      final channel = TestClientFactory.makeChannel(client, 'ok:leave_push');
      await channel.join();
      await channel.leave();

      expect(
        () => channel.push('event:ok'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
