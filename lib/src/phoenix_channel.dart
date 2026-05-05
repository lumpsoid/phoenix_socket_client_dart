import 'dart:async';

import 'package:phoenix_socket_client/src/phoenix_channel_state.dart';
import 'package:phoenix_socket_client/src/phoenix_message.dart';
import 'package:socket_client/socket_client.dart';

/// Represents a single Phoenix channel topic (e.g. `"room:lobby"`).
class PhoenixChannel {
  PhoenixChannel._({
    required this.topic,
    required Map<String, dynamic> params,
    required RefGenerator refGen,
    required SocketClient<PhoenixMessage> client,
  }) : _params = params,
       _refGen = refGen,
       _client = client {
    _routerSub = client.allFrames
        .where((m) => m.topic == topic)
        .listen(_onMessage);
  }

  factory PhoenixChannel.create({
    required String topic,
    required Map<String, dynamic> params,
    required RefGenerator refGen,
    required SocketClient<PhoenixMessage> client,
  }) => PhoenixChannel._(
    topic: topic,
    params: params,
    refGen: refGen,
    client: client,
  );

  /// Current channel topic
  final String topic;
  final Map<String, dynamic> _params;
  final RefGenerator _refGen;
  final SocketClient<PhoenixMessage> _client;

  PhoenixChannelState _state = PhoenixChannelState.closed;
  String? _joinRef;

  StreamSubscription<PhoenixMessage>? _routerSub;

  final _stateController = StreamController<ChannelStateChange>.broadcast();
  final _messageController = StreamController<PhoenixMessage>.broadcast();

  PhoenixChannelState get state => _state;
  bool get isJoined => _state == PhoenixChannelState.joined;

  /// State transitions — joined, errored, closed, rejoining, etc.
  Stream<ChannelStateChange> get stateStream => _stateController.stream;

  /// All inbound messages for this topic, excluding protocol frames
  /// (phx_reply, phx_error, phx_close are handled internally).
  Stream<PhoenixMessage> get messages => _messageController.stream;

  /// All inbound messages for this topic.
  Stream<PhoenixMessage> get allFrames =>
      _client.allFrames.where((f) => f.topic == topic);

  Future<Map<String, dynamic>> join({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_state == PhoenixChannelState.joined) return const {};

    _transitionTo(PhoenixChannelState.joining);
    _joinRef = _refGen.next();

    final joinMsg = PhoenixMessage(
      joinRef: _joinRef,
      ref: _joinRef,
      topic: topic,
      event: PhoenixMessage.eventJoin,
      payload: _params,
    );

    try {
      final reply = await _client.request(joinMsg, timeout: timeout);

      if (reply.isErrorReply) {
        _transitionTo(PhoenixChannelState.errored, error: reply.replyResponse);
        throw PhoenixChannelException(
          'Join rejected by server',
          topic: topic,
          payload: reply.replyResponse,
        );
      }

      _transitionTo(PhoenixChannelState.joined);
      return reply.replyResponse;
    } on PhoenixChannelException {
      rethrow;
    } on Exception catch (e) {
      _transitionTo(PhoenixChannelState.errored);
      throw PhoenixChannelException('Join failed: $e', topic: topic);
    }
  }

  Future<Map<String, dynamic>> push(
    String event, {
    Map<String, dynamic> payload = const {},
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _assertJoined();

    final msg = PhoenixMessage(
      joinRef: _joinRef,
      ref: _refGen.next(),
      topic: topic,
      event: event,
      payload: payload,
    );

    final reply = await _client.request(msg, timeout: timeout);

    if (reply.isErrorReply) {
      throw PhoenixChannelException(
        'Push "$event" rejected',
        topic: topic,
        payload: reply.replyResponse,
      );
    }

    return reply.replyResponse;
  }

  void emit(String event, {Map<String, dynamic> payload = const {}}) {
    _assertJoined();
    _client.emit(
      PhoenixMessage(
        joinRef: _joinRef,
        topic: topic,
        event: event,
        payload: payload,
      ),
    );
  }

  Future<void> leave({Duration timeout = const Duration(seconds: 5)}) async {
    if (_state == PhoenixChannelState.closed) return;

    try {
      await _client.request(
        PhoenixMessage(
          joinRef: _joinRef,
          ref: _refGen.next(),
          topic: topic,
          event: PhoenixMessage.eventLeave,
          payload: const {},
        ),
        timeout: timeout,
      );
    } finally {
      _transitionTo(PhoenixChannelState.closed);
      _joinRef = null;
    }
  }

  Future<void> rejoin({Duration timeout = const Duration(seconds: 10)}) async {
    _transitionTo(PhoenixChannelState.rejoining);
    await join(timeout: timeout);
  }

  void _onMessage(PhoenixMessage msg) {
    switch (msg.event) {
      case PhoenixMessage.eventError:
        _transitionTo(PhoenixChannelState.errored, error: msg.payload);
      case PhoenixMessage.eventClose:
        _transitionTo(PhoenixChannelState.closed);
        _joinRef = null;
      case PhoenixMessage.eventReply:
        // Already resolved by PendingRequests. Not forwarded to messages
        // stream — consumers who need raw replies use client.allFrames.
        break;
      default:
        _messageController.add(msg);
    }
  }

  void _transitionTo(PhoenixChannelState next, {Map<String, dynamic>? error}) {
    if (_state == next) return;
    _state = next;
    _stateController.add(
      ChannelStateChange(
        previous: _state,
        current: next,
        error: error,
      ),
    );
  }

  void _assertJoined() {
    if (!isJoined) {
      throw StateError(
        'Channel "$topic" is not joined (state: ${_state.name}). '
        'Call join() first.',
      );
    }
  }

  Future<void> dispose() async {
    await _routerSub?.cancel();
    await _stateController.close();
    await _messageController.close();
  }
}

class PhoenixChannelException implements Exception {
  const PhoenixChannelException(
    this.message, {
    required this.topic,
    this.payload,
  });

  final String message;
  final String topic;
  final Map<String, dynamic>? payload;

  @override
  String toString() =>
      'PhoenixChannelException[$topic]: $message'
      '${payload != null ? " payload=$payload" : ""}';
}
