import 'package:phoenix_socket_client/src/phoenix_codec.dart';
import 'package:phoenix_socket_client/src/phoenix_heartbeat_ping_builder.dart';
import 'package:phoenix_socket_client/src/phoenix_message.dart';
import 'package:socket_client/socket_client.dart';

/// {templatestart phoenix_client}
/// Phoenix WebSocket implementation of [SocketClient]
/// {templatend phoenix_client}
class PhoenixClient extends DefaultSocketClient<PhoenixMessage> {
  /// {macro phoenix_client}
  PhoenixClient({
    required super.config,
    required RefGenerator refGen,
    HeartbeatConfig heartbeatConfig = const HeartbeatConfig(),
    super.codec = const PhoenixCodec(),
    super.backoff,
    super.logger,
  }) : super(
         heartbeat: IntervalFramedHeartbeat(
           pingBuilder: PhoenixHeartbeatPingBuilder(
             codec: codec,
             refGen: refGen,
           ),
           config: heartbeatConfig,
         ),
       );
}
