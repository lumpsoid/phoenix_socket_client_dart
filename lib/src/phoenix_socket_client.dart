import 'dart:async';

import 'package:phoenix_socket_client/src/phoenix_channel.dart';
import 'package:phoenix_socket_client/src/phoenix_channel_state.dart';
import 'package:phoenix_socket_client/src/phoenix_codec.dart';
import 'package:phoenix_socket_client/src/phoenix_connection_config.dart';
import 'package:phoenix_socket_client/src/phoenix_heartbeat_ping_builder.dart';
import 'package:phoenix_socket_client/src/phoenix_message.dart';
import 'package:socket_client/socket_client.dart';

/// Phoenix WebSocket client facade.
///
/// Manages the underlying [SocketClient], heartbeats, and per-topic
/// [PhoenixChannel]s. Channels are automatically re-joined after transport
/// reconnects.
///
/// ## Quick start
///
/// ```dart
/// final socket = PhoenixSocket(
///   uri: Uri.https('api.example.com', '/socket/websocket', {
///     'token': 'user-jwt',
///     'vsn':   '2.0.0',
///   }),
/// );
///
/// await socket.connect();
///
/// final lobby = socket.channel('room:lobby', params: {'color': 'blue'});
/// await lobby.join();
///
/// lobby.on('new_msg').listen((msg) => print(msg.payload['body']));
/// lobby.push('new_msg', payload: {'body': 'hello!'});
/// ```
class PhoenixSocket {
  PhoenixSocket({
    required PhoenixConnectionConfig config,
    required RefGenerator refGen,
    PhoenixCodec codec = const PhoenixCodec(),
    SocketClient<PhoenixMessage>? client,
    SocketLogger? logger,
  }) : _client =
           client ??
           SocketClient<PhoenixMessage>(
             config: config,
             codec: codec,
             heartbeat: IntervalFramedHeartbeat(
               pingBuilder: PhoenixHeartbeatPingBuilder(
                 codec: codec,
                 refGen: refGen,
               ),
               config: const HeartbeatConfig(),
             ),
             logger: logger,
           ),
       _logger = logger ?? const SocketLogger(tag: 'PhoenixSocket'),
       _refGen = refGen {
    _client.stateStream.listen(_onStateChange);
  }

  final SocketLogger _logger;
  final RefGenerator _refGen;

  late final SocketClient<PhoenixMessage> _client;

  /// All currently registered channels, keyed by topic.
  final _channels = <String, PhoenixChannel>{};

  bool _disposed = false;

  SocketConnectionState get state => _client.state;
  bool get isConnected => _client.isConnected;

  Stream<SocketConnectionState> get stateStream => _client.stateStream;
  Stream<SocketError> get errors => _client.errors;

  /// All decoded inbound Phoenix messages (useful for debugging).
  Stream<PhoenixMessage> get allMessages => _client.allFrames;

  /// Connect the underlying WebSocket transport.
  Future<void> connect() async {
    _assertNotDisposed();
    await _client.connect();
  }

  /// Disconnect and release all channels.
  Future<void> disconnect() => _client.disconnect();

  /// Obtain a [PhoenixChannel] for [topic].
  ///
  /// If a channel for [topic] already exists it is returned as-is;
  /// [params] is only applied on the first call.
  ///
  /// ```dart
  /// final ch = socket.channel(
  ///   'room:lobby',
  ///   params: {'token': 'abc'},
  /// );
  /// ```
  PhoenixChannel channel(
    String topic, {
    Map<String, dynamic> params = const {},
  }) {
    _assertNotDisposed();
    return _channels.putIfAbsent(
      topic,
      () => PhoenixChannel.create(
        topic: topic,
        params: params,
        socketClient: _client,
        emit: _client.emit,
        request: _client.request,
        nextRef: _refGen.next,
        logger: _logger,
      ),
    );
  }

  /// Remove and dispose the channel for [topic].
  ///
  /// Calls [PhoenixChannel.leave] first if the channel is currently joined.
  Future<void> removeChannel(String topic) async {
    final ch = _channels.remove(topic);
    if (ch == null) return;
    if (ch.isJoined) await ch.leave();
    await ch.dispose();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    // Leave and dispose all channels in parallel.
    await Future.wait(
      _channels.values.map((ch) async {
        if (ch.isJoined) {
          try {
            await ch.leave();
          } on Exception catch (_) {}
        }
        await ch.dispose();
      }),
    );
    _channels.clear();

    await _client.dispose();
    _logger.info('PhoenixSocket disposed');
  }

  Future<void> _onStateChange(SocketConnectionState state) async {
    if (state != SocketConnectionState.connected) return;

    // Re-join every channel that was previously joined.
    final joined = _channels.values
        .where(
          (ch) =>
              ch.state == PhoenixChannelState.joined ||
              ch.state == PhoenixChannelState.rejoining,
        )
        .toList();

    if (joined.isEmpty) return;

    _logger.info('Reconnected — re-joining ${joined.length} channel(s)');
    await Future.wait(joined.map((ch) => ch.rejoin()));
  }

  void _assertNotDisposed() {
    if (_disposed) throw StateError('PhoenixSocket has been disposed');
  }
}
