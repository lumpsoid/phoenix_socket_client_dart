@Tags(['integration'])
library;

import 'dart:async';

import 'package:phoenix_socket_client/src/phoenix_channel.dart';
import 'package:phoenix_socket_client/src/phoenix_client.dart';
import 'package:test/test.dart';

import '../helpers/server_guard.dart';
import '../helpers/test_client_factory.dart';

void main() {
  late PhoenixClient client;
  late PhoenixChannel channel;

  setUpAll(assertServerRunning);

  setUp(() async {
    client = TestClientFactory.create();
    await client.connect();
    channel = TestClientFactory.makeChannel(client, 'ok:push_tests');
    await channel.join();
  });

  tearDown(() => client.disconnect());

  group('push with reply', () {
    test('event:ok echoes payload back', () async {
      final reply = await channel.push('event:ok', payload: {'key': 'value'});
      expect(reply, containsPair('echo', {'key': 'value'}));
    });

    test('event:ok with empty payload returns echo of empty map', () async {
      final reply = await channel.push('event:ok', payload: {});
      expect(reply, containsPair('echo', {}));
    });

    test('event:error throws PhoenixChannelException', () async {
      await expectLater(
        channel.push('event:error'),
        throwsA(
          isA<PhoenixChannelException>().having(
            (e) => e.payload,
            'payload',
            containsPair('reason', 'something_wrong'),
          ),
        ),
      );
    });

    test('push on non-joined channel throws StateError', () async {
      final unjoined = TestClientFactory.makeChannel(client, 'ok:not_joined');
      expect(() => unjoined.push('event:ok'), throwsA(isA<StateError>()));
    });
  });

  group('push without reply (noreply)', () {
    test(
      'event:no_reply completes after timeout with no server reply',
      () async {
        // The server sends no phx_reply for this event — the push should
        // eventually time out. We verify it times out rather than hanging.
        await expectLater(
          channel.push('event:no_reply', timeout: const Duration(seconds: 2)),
          throwsA(isA<Exception>()),
        );
      },
    );
  });

  group('emit (fire and forget)', () {
    test('emit does not throw when joined', () {
      expect(
        () => channel.emit('event:no_reply', payload: {'fire': 'forget'}),
        returnsNormally,
      );
    });

    test('emit throws StateError when not joined', () {
      final unjoined = TestClientFactory.makeChannel(client, 'ok:unjoined');
      expect(
        () => unjoined.emit('event:ok'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('server push', () {
    test('event:server_push delivers message on messages stream', () async {
      final messageCompleter = Completer<Map<String, dynamic>>();
      channel.messages.listen((msg) {
        if (msg.event == 'server:event') {
          messageCompleter.complete(msg.payload);
        }
      });

      channel.emit('event:server_push');

      final payload = await messageCompleter.future.timeout(
        const Duration(seconds: 5),
      );

      expect(payload, containsPair('message', 'pushed from server'));
    });
  });
}
