import 'package:phoenix_socket_client/src/phoenix_codec.dart';
import 'package:phoenix_socket_client/src/phoenix_message.dart';
import 'package:socket_client/socket_client.dart';

class PhoenixHeartbeatPingBuilder
    extends FrameHeartbeatPingBuilder<PhoenixMessage> {
  PhoenixHeartbeatPingBuilder({
    required PhoenixCodec codec,
    required RefGenerator refGen,
  }) : _refGen = refGen,
       super(codec: codec);

  final RefGenerator _refGen;

  @override
  PhoenixMessage getPingFrame() {
    return PhoenixMessage(
      ref: _refGen.next(),
      topic: PhoenixMessage.topicPhoenix,
      event: PhoenixMessage.eventHeartbeat,
      payload: const {},
    );
  }
}
