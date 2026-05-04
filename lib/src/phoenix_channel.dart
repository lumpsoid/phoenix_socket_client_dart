import 'dart:async';

import 'package:callback_observable/callback_observable.dart';
import 'package:phoenix_socket_client/src/phoenix_channel_state.dart';
import 'package:phoenix_socket_client/src/phoenix_message.dart';
import 'package:phoenix_socket_client/src/phoenix_socket_client.dart';
import 'package:socket_client/socket_client.dart';

/// Represents a single Phoenix channel topic (e.g. `"room:lobby"`).
///
/// Obtained via [PhoenixSocket.channel], never constructed directly.
///
/// ```dart
/// final channel = socket.channel(
///   'room:lobby',
///   params: {'token': 'abc123'},
/// );
///
/// channel.stateStream.listen((s) => print(s));
/// channel.onEvents((msg) => print(msg.payload));
///
/// await channel.join();
/// await channel.push('shout', payload: {'body': 'hello'});
/// await channel.leave();
/// ```
class PhoenixChannel {
  PhoenixChannel._({
    required this.topic,
    required Map<String, dynamic> params,
    required String Function() nextRef,
    required SocketClient<PhoenixMessage> socketClient,
    required void Function(PhoenixMessage msg) emit,
    required Future<PhoenixMessage> Function(
      PhoenixMessage msg, {
      Duration timeout,
    })
    request,
    Observable<PhoenixMessage>? observable,
    SocketLogger? logger,
  }) : _params = params,
       _nextRef = nextRef,
       _emit = emit,
       _request = request,
       _observable = observable ?? TombstoneObservable<PhoenixMessage>(),
       _logger = logger ?? SocketLogger(tag: 'Channel[$topic]') {
    // Fan in all frames to this channel's own stream.
    _routerSub = socketClient.allFrames
        .where((m) => m.topic == topic)
        .listen(_onMessage);
  }

  factory PhoenixChannel.create({
    required String topic,
    required Map<String, dynamic> params,
    required SocketClient<PhoenixMessage> socketClient,
    required void Function(PhoenixMessage msg) emit,
    required Future<PhoenixMessage> Function(
      PhoenixMessage msg, {
      Duration timeout,
    })
    request,
    required String Function() nextRef,
    Observable<PhoenixMessage>? observable,
    SocketLogger? logger,
  }) => PhoenixChannel._(
    topic: topic,
    socketClient: socketClient,
    params: params,
    emit: emit,
    request: request,
    nextRef: nextRef,
    observable: observable,
    logger: logger,
  );

  /// Current channel topic name.
  final String topic;
  final Map<String, dynamic> _params;
  final void Function(PhoenixMessage msg) _emit;
  final Future<PhoenixMessage> Function(PhoenixMessage msg, {Duration timeout})
  _request;
  final String Function() _nextRef;
  final SocketLogger _logger;
  final Observable<PhoenixMessage> _observable;

  PhoenixChannelState _state = PhoenixChannelState.closed;
  String? _joinRef;

  StreamSubscription<PhoenixMessage>? _routerSub;

  final _stateController = StreamController<ChannelStateChange>.broadcast();

  PhoenixChannelState get state => _state;
  bool get isJoined => _state == PhoenixChannelState.joined;

  /// Emits [ChannelStateChange] on every state transition.
  Stream<ChannelStateChange> get stateStream => _stateController.stream;

  void addListener(void Function(PhoenixMessage) onEvent) =>
      _observable.addListener(onEvent);

  void removeListener(void Function(PhoenixMessage) onEvent) =>
      _observable.removeListener(onEvent);

  /// Join the channel, optionally re-using [_params] supplied at construction.
  ///
  /// Resolves when the server acknowledges with `phx_reply{ok}`.
  /// Throws [PhoenixChannelException] on `phx_reply{error}` or timeout.
  Future<Map<String, dynamic>> join({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_state == PhoenixChannelState.joined) {
      _logger.warn('Already joined — skipping duplicate join');
      return const {};
    }

    _transitionTo(PhoenixChannelState.joining);
    _joinRef = _nextRef();

    final joinMsg = PhoenixMessage(
      joinRef: _joinRef,
      ref: _joinRef, // ref == joinRef for the join push itself
      topic: topic,
      event: PhoenixMessage.eventJoin,
      payload: _params,
    );

    try {
      final reply = await _request(
        joinMsg,
        timeout: timeout,
      );

      if (reply.isErrorReply) {
        _transitionTo(PhoenixChannelState.errored, error: reply.replyResponse);
        throw PhoenixChannelException(
          'Join rejected by server',
          topic: topic,
          payload: reply.replyResponse,
        );
      }

      _transitionTo(PhoenixChannelState.joined);
      _logger.info('Joined');
      return reply.replyResponse;
    } on PhoenixChannelException {
      rethrow;
    } on Exception catch (e) {
      _transitionTo(PhoenixChannelState.errored);
      throw PhoenixChannelException('Join failed: $e', topic: topic);
    }
  }

  /// Push a custom event to the channel and await the server's `phx_reply`.
  ///
  /// Resolves with the reply's `response` payload on `ok`,
  /// throws [PhoenixChannelException] on `error` or timeout.
  Future<Map<String, dynamic>> push(
    String event, {
    Map<String, dynamic> payload = const {},
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _assertJoined();

    final ref = _nextRef();
    final msg = PhoenixMessage(
      joinRef: _joinRef,
      ref: ref,
      topic: topic,
      event: event,
      payload: payload,
    );

    final reply = await _request(
      msg,
      timeout: timeout,
    );

    if (reply.isErrorReply) {
      throw PhoenixChannelException(
        'Push "$event" rejected',
        topic: topic,
        payload: reply.replyResponse,
      );
    }

    return reply.replyResponse;
  }

  /// Send a fire-and-forget event — no reply tracking.
  void emit(String event, {Map<String, dynamic> payload = const {}}) {
    _assertJoined();
    _emit(
      PhoenixMessage(
        joinRef: _joinRef,
        topic: topic,
        event: event,
        payload: payload,
      ),
    );
  }

  /// Leave the channel gracefully.
  ///
  /// Sends `phx_leave` and awaits the server acknowledgement.
  Future<void> leave({Duration timeout = const Duration(seconds: 5)}) async {
    if (_state == PhoenixChannelState.closed) return;

    final ref = _nextRef();
    final msg = PhoenixMessage(
      joinRef: _joinRef,
      ref: ref,
      topic: topic,
      event: PhoenixMessage.eventLeave,
      payload: const {},
    );

    try {
      await _request(msg, timeout: timeout);
    } on Exception catch (e) {
      _logger.warn('Leave reply not received: $e — forcing close');
    } finally {
      _transitionTo(PhoenixChannelState.closed);
      _joinRef = null;
      _logger.info('Left');
    }
  }

  /// Re-join after a transport reconnect. Called by [PhoenixSocket].
  Future<void> rejoin({Duration timeout = const Duration(seconds: 10)}) async {
    _transitionTo(PhoenixChannelState.rejoining);
    _logger.info('Re-joining after reconnect');
    await join(timeout: timeout);
  }

  void _onMessage(PhoenixMessage msg) {
    switch (msg.event) {
      case PhoenixMessage.eventError:
        _logger.warn('Channel error: ${msg.payload}');
        _transitionTo(PhoenixChannelState.errored, error: msg.payload);

      case PhoenixMessage.eventClose:
        _logger.info('Channel closed by server');
        _transitionTo(PhoenixChannelState.closed);
        _joinRef = null;

      // phx_reply is consumed by PendingRequests inside the router.
      // We still fan it out in case callers listen on router.allFrames.
      case PhoenixMessage.eventReply:
        _fanOut(msg);

      default:
        _fanOut(msg);
    }
  }

  void _fanOut(PhoenixMessage msg) => _observable.notify(msg);

  void _transitionTo(PhoenixChannelState next, {Map<String, dynamic>? error}) {
    if (_state == next) return;
    final change = ChannelStateChange(
      previous: _state,
      current: next,
      error: error,
    );
    _logger.info('State: ${_state.name} → ${next.name}');
    _state = next;
    _stateController.add(change);
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
    _observable.dispose();
    _logger.info('Disposed');
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
