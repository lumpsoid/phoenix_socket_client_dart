/// Phoenix wire format:
/// [join_ref, ref, topic, event, payload]
///
/// join_ref — ref of the Join push that opened this channel (null for system
/// msgs)
/// ref      — per-message correlation id (null for server-push events)
/// topic    — "phoenix" (system) or "room:lobby" (user channel)
/// event    — "phx_join", "phx_reply", "phx_error", "phx_close", or custom
/// payload  — arbitrary JSON object
class PhoenixMessage {
  const PhoenixMessage({
    required this.topic,
    required this.event,
    required this.payload,
    this.ref,
    this.joinRef,
  });

  final String? joinRef;
  final String? ref;
  final String topic;
  final String event;
  final Map<String, dynamic> payload;

  // System events
  static const String eventJoin = 'phx_join';
  static const String eventReply = 'phx_reply';
  static const String eventError = 'phx_error';
  static const String eventClose = 'phx_close';
  static const String eventLeave = 'phx_leave';
  static const String eventHeartbeat = 'heartbeat';

  static const String topicPhoenix = 'phoenix';

  bool get isReply => event == eventReply;
  bool get isError => event == eventError;
  bool get isClose => event == eventClose;
  bool get isSystem => topic == topicPhoenix;

  /// Status field from a phx_reply payload.
  String? get replyStatus => payload['status'] as String?;

  /// Response field from a phx_reply payload.
  Map<String, dynamic> get replyResponse =>
      (payload['response'] as Map<String, dynamic>?) ?? const {};

  bool get isOkReply => isReply && replyStatus == 'ok';
  bool get isErrorReply => isReply && replyStatus == 'error';

  PhoenixMessage copyWith({
    String? joinRef,
    String? ref,
    String? topic,
    String? event,
    Map<String, dynamic>? payload,
  }) => PhoenixMessage(
    joinRef: joinRef ?? this.joinRef,
    ref: ref ?? this.ref,
    topic: topic ?? this.topic,
    event: event ?? this.event,
    payload: payload ?? this.payload,
  );

  @override
  String toString() =>
      'PhoenixMessage(topic: $topic, event: $event, ref: $ref, '
      'joinRef: $joinRef)';
}
