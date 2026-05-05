// tests
// ignore_for_file: prefer_const_constructors

import 'package:phoenix_socket_client/src/phoenix_message.dart';
import 'package:test/test.dart';

void main() {
  group('PhoenixMessage flags', () {
    PhoenixMessage make({
      required String event,
      Map<String, dynamic>? payload,
    }) => PhoenixMessage(
      topic: 'room:test',
      event: event,
      payload: payload ?? const {},
    );

    test('isReply true only for phx_reply', () {
      expect(make(event: PhoenixMessage.eventReply).isReply, isTrue);
      expect(make(event: 'custom').isReply, isFalse);
    });

    test('isError true only for phx_error', () {
      expect(make(event: PhoenixMessage.eventError).isError, isTrue);
    });

    test('isClose true only for phx_close', () {
      expect(make(event: PhoenixMessage.eventClose).isClose, isTrue);
    });

    test('isSystem true for phoenix topic', () {
      final msg = PhoenixMessage(
        topic: PhoenixMessage.topicPhoenix,
        event: 'heartbeat',
        payload: const {},
      );
      expect(msg.isSystem, isTrue);
    });

    test('isOkReply requires both isReply and status==ok', () {
      final ok = make(
        event: PhoenixMessage.eventReply,
        payload: {'status': 'ok', 'response': <String, dynamic>{}},
      );
      final err = make(
        event: PhoenixMessage.eventReply,
        payload: {'status': 'error', 'response': <String, dynamic>{}},
      );
      expect(ok.isOkReply, isTrue);
      expect(ok.isErrorReply, isFalse);
      expect(err.isErrorReply, isTrue);
      expect(err.isOkReply, isFalse);
    });

    test('replyResponse returns empty map when response absent', () {
      final msg = make(
        event: PhoenixMessage.eventReply,
        payload: {'status': 'ok'},
      );
      expect(msg.replyResponse, isEmpty);
    });
  });

  group('PhoenixMessage.copyWith', () {
    test('copies only specified fields', () {
      const original = PhoenixMessage(
        joinRef: 'j1',
        ref: 'r1',
        topic: 'room:a',
        event: 'ev',
        payload: {'k': 'v'},
      );
      final copy = original.copyWith(topic: 'room:b', ref: 'r2');
      expect(copy.topic, 'room:b');
      expect(copy.ref, 'r2');
      expect(copy.joinRef, 'j1');
      expect(copy.event, 'ev');
      expect(copy.payload, {'k': 'v'});
    });
  });
}
