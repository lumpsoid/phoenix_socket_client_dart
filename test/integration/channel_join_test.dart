@Tags(['integration'])
library;

import 'package:phoenix_socket_client/phoenix_socket_client.dart';
import 'package:test/test.dart';

import '../helpers/server_guard.dart';
import '../helpers/test_client_factory.dart';

void main() {
  late PhoenixClient client;

  setUpAll(assertServerRunning);

  setUp(() => client = TestClientFactory.create());
  tearDown(() => client.disconnect());

  group('ok: channel join', () {
    test('joins successfully and returns server response', () async {
      await client.connect();
      final channel = TestClientFactory.makeChannel(client, 'ok:lobby');

      final reply = await channel.join();

      expect(channel.state, PhoenixChannelState.joined);
      expect(reply, containsPair('status', 'joined'));
    });

    test('join transitions through joining → joined states', () async {
      await client.connect();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final channel = TestClientFactory.makeChannel(client, 'ok:lobby');

      final states = <PhoenixChannelState>[];
      channel.stateStream.listen((c) => states.add(c.current));

      await channel.join();

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        states,
        containsAllInOrder([
          PhoenixChannelState.joining,
          PhoenixChannelState.joined,
        ]),
      );
    });

    test('isJoined is true after successful join', () async {
      await client.connect();
      final channel = TestClientFactory.makeChannel(client, 'ok:room');
      await channel.join();
      expect(channel.isJoined, isTrue);
    });

    test('calling join() again when already joined is a no-op', () async {
      await client.connect();
      final channel = TestClientFactory.makeChannel(client, 'ok:noop');
      await channel.join();
      // Second join should return immediately without error
      await expectLater(channel.join(), completes);
      expect(channel.isJoined, isTrue);
    });
  });

  group('reject: channel join', () {
    test('join throws PhoenixChannelException for forbidden topic', () async {
      await client.connect();
      final channel = TestClientFactory.makeChannel(client, 'reject:forbidden');

      await expectLater(
        channel.join(),
        throwsA(
          isA<PhoenixChannelException>().having(
            (e) => e.payload,
            'payload',
            containsPair('reason', 'forbidden'),
          ),
        ),
      );
    });

    test('join transitions to errored state on rejection', () async {
      await client.connect();
      final channel = TestClientFactory.makeChannel(client, 'reject:room');

      final states = <PhoenixChannelState>[];
      channel.stateStream.listen((c) => states.add(c.current));

      await expectLater(
        channel.join(),
        throwsA(isA<PhoenixChannelException>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(states, contains(PhoenixChannelState.errored));
    });

    test('rejected join includes server reason in exception payload', () async {
      await client.connect();
      final channel = TestClientFactory.makeChannel(client, 'reject:anywhere');

      try {
        await channel.join();
        fail('Expected PhoenixChannelException');
      } on PhoenixChannelException catch (e) {
        expect(e.payload, containsPair('reason', 'unauthorized'));
        expect(e.topic, 'reject:anywhere');
      }
    });
  });

  group('error: channel crash on join', () {
    test('join times out or throws when server crashes on join', () async {
      await client.connect();
      final channel = TestClientFactory.makeChannel(
        client,
        'error:crash',
        timeout: const Duration(seconds: 3),
      );

      await expectLater(
        channel.join(timeout: const Duration(seconds: 3)),
        throwsA(isA<Exception>()),
      );
    });
  });
}
