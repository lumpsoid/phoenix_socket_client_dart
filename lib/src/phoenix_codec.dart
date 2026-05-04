import 'dart:convert';

import 'package:phoenix_socket_client/src/phoenix_message.dart';
import 'package:socket_client/socket_client.dart';

/// Encodes/decodes the Phoenix v2 array wire format.
///
/// Wire format (JSON array):
/// ```json
/// [join_ref, ref, topic, event, payload]
/// ["1",      "2", "room:lobby", "shout", {"body": "hi"}]
/// ```
///
/// Both `join_ref` and `ref` may be JSON `null`.
class PhoenixCodec implements FrameCodec<PhoenixMessage> {
  const PhoenixCodec();

  @override
  PhoenixMessage decode(String raw) {
    final List<dynamic> parts;
    try {
      parts = json.decode(raw) as List<dynamic>;
    } on FormatException catch (e) {
      throw FrameDecodeException(
        'Phoenix frame is not valid JSON',
        raw: raw,
        cause: e,
      );
    }

    if (parts.length != 5) {
      throw FrameDecodeException(
        'Phoenix frame must have exactly 5 elements, got ${parts.length}',
        raw: raw,
      );
    }

    final payload = parts[4];
    if (payload is! Map<String, dynamic>) {
      throw FrameDecodeException(
        'Phoenix frame payload must be a JSON object, '
        'got ${payload.runtimeType}',
        raw: raw,
      );
    }

    return PhoenixMessage(
      joinRef: parts[0] as String?,
      ref: parts[1] as String?,
      topic: parts[2] as String,
      event: parts[3] as String,
      payload: payload,
    );
  }

  @override
  String encode(PhoenixMessage frame) => json.encode([
    frame.joinRef,
    frame.ref,
    frame.topic,
    frame.event,
    frame.payload,
  ]);

  /// The [PhoenixMessage.ref] of an outbound request frame — used to correlate
  /// the reply.
  ///
  /// Phoenix echoes `ref` back in the `phx_reply` event, so we key on that.
  @override
  String? correlationId(PhoenixMessage frame) => frame.ref;

  /// The ref this reply is responding to.
  ///
  /// A `phx_reply` carries the original request's `ref` in its own `ref`
  /// field. Non-reply frames return `null`.
  @override
  String? replyCorrelationId(PhoenixMessage frame) =>
      frame.isReply ? frame.ref : null;
}
