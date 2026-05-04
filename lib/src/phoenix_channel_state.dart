enum PhoenixChannelState {
  /// Initial / after leave.
  closed,

  /// phx_join has been sent, awaiting phx_reply.
  joining,

  /// phx_reply{ok} received.
  joined,

  /// Attempting to re-join after transport reconnect.
  rejoining,

  /// An unrecoverable error was received from the server.
  errored,
}

class ChannelStateChange {
  const ChannelStateChange({
    required this.previous,
    required this.current,
    this.error,
  });

  final PhoenixChannelState previous;
  final PhoenixChannelState current;

  /// Server-supplied error payload,
  /// if [current] == [PhoenixChannelState.errored].
  final Map<String, dynamic>? error;

  @override
  String toString() =>
      'ChannelStateChange(${previous.name} → ${current.name}'
      '${error != null ? ", error: $error" : ""})';
}
