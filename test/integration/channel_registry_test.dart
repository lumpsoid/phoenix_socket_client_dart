@Tags(['integration'])
library;

import 'package:phoenix_socket_client/src/phoenix_channel_registry.dart';
import 'package:phoenix_socket_client/src/phoenix_channel_state.dart';
import 'package:phoenix_socket_client/src/phoenix_client.dart';
import 'package:test/test.dart';

import '../helpers/server_guard.dart';
import '../helpers/test_client_factory.dart';

void main() {
  late PhoenixClient client;
  late PhoenixChannelRegistry registry;

  setUpAll(assertServerRunning);

  setUp(() async {
    client = TestClientFactory.create();
    registry = TestClientFactory.makeRegistry(client);
    await client.connect();
  });

  tearDown(() async {
    await registry.dispose();
    await client.disconnect();
  });

  group('channel()', () {
    test('creates and returns a channel for a topic', () {
      final ch = registry.channel('ok:reg_test');
      expect(ch, isNotNull);
      expect(ch.topic, 'ok:reg_test');
    });

    test('returns the same channel instance for the same topic', () {
      final a = registry.channel('ok:same');
      final b = registry.channel('ok:same');
      expect(identical(a, b), isTrue);
    });

    test('creates distinct channel instances for different topics', () {
      final a = registry.channel('ok:alpha');
      final b = registry.channel('ok:beta');
      expect(identical(a, b), isFalse);
    });

    test('throws StateError after dispose', () async {
      await registry.dispose();
      expect(
        () => registry.channel('ok:after_dispose'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('removeChannel()', () {
    test('leaves and removes a joined channel', () async {
      final ch = registry.channel('ok:remove_test');
      await ch.join();
      expect(ch.isJoined, isTrue);

      await registry.removeChannel('ok:remove_test');

      expect(ch.state, PhoenixChannelState.closed);
      // A subsequent call to channel() creates a fresh instance
      final fresh = registry.channel('ok:remove_test');
      expect(identical(fresh, ch), isFalse);
    });

    test('removeChannel is safe for unknown topics', () async {
      await expectLater(
        registry.removeChannel('ok:nonexistent'),
        completes,
      );
    });
  });

  group('auto-rejoin on reconnect', () {
    test('rejoins joined channels after reconnect', () async {
      final ch = registry.channel('ok:rejoin_test');
      await ch.join();
      expect(ch.isJoined, isTrue);

      // Force a disconnect/reconnect cycle
      await client.disconnect();
      await client.connect();

      // Allow rejoin logic to run
      await Future<void>.delayed(const Duration(seconds: 2));

      expect(ch.isJoined, isTrue);
    });

    test('does not rejoin closed channels after reconnect', () async {
      final ch = registry.channel('ok:no_rejoin');
      await ch.join();
      await ch.leave();
      expect(ch.state, PhoenixChannelState.closed);

      await client.disconnect();
      await client.connect();
      await Future<void>.delayed(const Duration(seconds: 1));

      // Should remain closed — was intentionally left
      expect(ch.state, PhoenixChannelState.closed);
    });
  });

  group('dispose()', () {
    test('leaves all channels on dispose', () async {
      final a = registry.channel('ok:disp_a');
      final b = registry.channel('ok:disp_b');
      await a.join();
      await b.join();

      await registry.dispose();

      expect(a.state, PhoenixChannelState.closed);
      expect(b.state, PhoenixChannelState.closed);
    });

    test('double dispose is safe', () async {
      await registry.dispose();
      await expectLater(registry.dispose(), completes);
    });
  });
}
