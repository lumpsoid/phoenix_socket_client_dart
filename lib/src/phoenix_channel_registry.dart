import 'dart:async';

import 'package:phoenix_socket_client/src/phoenix_channel.dart';
import 'package:phoenix_socket_client/src/phoenix_channel_state.dart';
import 'package:phoenix_socket_client/src/phoenix_message.dart';
import 'package:socket_client/socket_client.dart';

class PhoenixChannelRegistry {
  PhoenixChannelRegistry({
    required SocketClient<PhoenixMessage> client,
    required RefGenerator refGen,
  }) : _client = client,
       _refGen = refGen {
    _stateSub = client.stateStream.listen(_onStateChange);
  }

  final SocketClient<PhoenixMessage> _client;
  final RefGenerator _refGen;

  final Map<String, PhoenixChannel> _channels = {};
  StreamSubscription<SocketConnectionState>? _stateSub;
  bool _disposed = false;

  /// Returns an existing channel for [topic], or creates and registers a new
  /// one.
  ///
  /// [params] are only applied when a new channel is created; they are ignored
  /// if the channel already exists.
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
        refGen: _refGen,
        client: _client,
      ),
    );
  }

  /// Leaves [topic] on the server, disposes the local channel object,
  /// and removes it from the registry.
  ///
  /// Safe to call even if the channel is not currently joined — the
  /// underlying [PhoenixChannel.leave] call is a no-op in that case.
  Future<void> removeChannel(String topic) async {
    final ch = _channels.remove(topic);
    if (ch == null) return;

    try {
      await ch.leave();
    } finally {
      await ch.dispose();
    }
  }

  /// Disposes all registered channels without touching the underlying client.
  ///
  /// After this call the registry itself is unusable; create a new instance
  /// if you need to register channels again.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await _stateSub?.cancel();
    _stateSub = null;

    // Leave + dispose all channels concurrently.
    final topics = List<String>.from(_channels.keys);
    await Future.wait(topics.map(removeChannel));
  }

  Future<void> _onStateChange(SocketConnectionState state) async {
    if (state != SocketConnectionState.connected) return;

    for (final entry in _channels.entries) {
      final ch = entry.value;

      // Only rejoin channels that were previously joined or are in an error
      // state; skip ones that are intentionally closed or still joining.
      if (ch.state == PhoenixChannelState.joined ||
          ch.state == PhoenixChannelState.errored) {
        await ch.rejoin();
      }
    }
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('PhoenixChannelRegistry has been disposed');
    }
  }
}
