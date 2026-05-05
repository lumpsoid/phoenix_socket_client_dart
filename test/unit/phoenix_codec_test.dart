// tests
// ignore_for_file: prefer_const_constructors

import 'package:phoenix_socket_client/src/phoenix_codec.dart';
import 'package:phoenix_socket_client/src/phoenix_message.dart';
import 'package:socket_client/socket_client.dart';
import 'package:test/test.dart';

void main() {
  const codec = PhoenixCodec();

  group('PhoenixCodec.decode', () {
    test('decodes a full message with all fields', () {
      const raw = '["1","2","room:lobby","shout",{"body":"hi"}]';
      final msg = codec.decode(raw);

      expect(msg.joinRef, '1');
      expect(msg.ref, '2');
      expect(msg.topic, 'room:lobby');
      expect(msg.event, 'shout');
      expect(msg.payload, {'body': 'hi'});
    });

    test('decodes null join_ref and ref', () {
      const raw = '[null,null,"phoenix","heartbeat",{}]';
      final msg = codec.decode(raw);

      expect(msg.joinRef, isNull);
      expect(msg.ref, isNull);
    });

    test('decodes phx_reply with nested response', () {
      const raw =
          '["1","2","room:lobby","phx_reply",{"status":"ok","response":'
          '{"status":"joined"}}]';
      final msg = codec.decode(raw);

      expect(msg.isReply, isTrue);
      expect(msg.isOkReply, isTrue);
      expect(msg.replyStatus, 'ok');
      expect(msg.replyResponse, {'status': 'joined'});
    });

    test('decodes phx_reply with error status', () {
      const raw =
          '["1","2","room:lobby","phx_reply",{"status":"error","response":'
          '{"reason":"unauthorized"}}]';
      final msg = codec.decode(raw);

      expect(msg.isErrorReply, isTrue);
      expect(msg.replyResponse, {'reason': 'unauthorized'});
    });

    test('throws FrameDecodeException on invalid JSON', () {
      expect(
        () => codec.decode('not json'),
        throwsA(isA<FrameDecodeException>()),
      );
    });

    test('throws FrameDecodeException when array length != 5', () {
      expect(
        () => codec.decode('["1","2","topic","event"]'),
        throwsA(isA<FrameDecodeException>()),
      );
    });

    test('throws FrameDecodeException when payload is not an object', () {
      expect(
        () => codec.decode('["1","2","topic","event","string_payload"]'),
        throwsA(isA<FrameDecodeException>()),
      );
    });
  });

  group('PhoenixCodec.encode', () {
    test('encodes message to JSON array', () {
      final msg = PhoenixMessage(
        joinRef: '1',
        ref: '2',
        topic: 'room:lobby',
        event: 'shout',
        payload: {'body': 'hi'},
      );

      expect(codec.encode(msg), '["1","2","room:lobby","shout",{"body":"hi"}]');
    });

    test('encodes null refs as JSON null', () {
      final msg = PhoenixMessage(
        topic: 'phoenix',
        event: 'heartbeat',
        payload: const {},
      );

      expect(codec.encode(msg), '[null,null,"phoenix","heartbeat",{}]');
    });
  });

  group('PhoenixCodec correlation', () {
    test('correlationId returns ref of request frame', () {
      final msg = PhoenixMessage(
        ref: '42',
        topic: 'room:lobby',
        event: 'shout',
        payload: const {},
      );
      expect(codec.correlationId(msg), '42');
    });

    test('correlationId returns null when ref is null', () {
      final msg = PhoenixMessage(
        topic: 'room:lobby',
        event: 'server:push',
        payload: const {},
      );
      expect(codec.correlationId(msg), isNull);
    });

    test('replyCorrelationId returns ref for phx_reply', () {
      final msg = PhoenixMessage(
        ref: '42',
        topic: 'room:lobby',
        event: PhoenixMessage.eventReply,
        payload: {'status': 'ok', 'response': <String, dynamic>{}},
      );
      expect(codec.replyCorrelationId(msg), '42');
    });

    test('replyCorrelationId returns null for non-reply events', () {
      final msg = PhoenixMessage(
        ref: '42',
        topic: 'room:lobby',
        event: 'shout',
        payload: const {},
      );
      expect(codec.replyCorrelationId(msg), isNull);
    });
  });
}
