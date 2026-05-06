import 'package:phoenix_socket_client/src/phoenix_channel.dart';
import 'package:phoenix_socket_client/src/phoenix_channel_registry.dart';
import 'package:phoenix_socket_client/src/phoenix_client.dart';
import 'package:phoenix_socket_client/src/phoenix_connection_config.dart';
import 'package:socket_client/socket_client.dart';

const kPhoenixTestUrl = 'ws://localhost:4000/socket/websocket';

/// Shared factory for creating test clients and channels.
///
/// Centralises configuration so tests stay focused on behaviour.
abstract final class TestClientFactory {
  static PhoenixClient create({String? url, HeartbeatConfig? heartbeat}) {
    final refGen = SequentialRefGenerator();
    return PhoenixClient(
      config: ConstantConfigProvider(
        PhoenixConnectionConfig(url: url ?? kPhoenixTestUrl),
      ),
      refGen: refGen,
      heartbeatConfig: heartbeat ?? const HeartbeatConfig(),
    );
  }

  static PhoenixChannel makeChannel(
    PhoenixClient client,
    String topic, {
    Map<String, dynamic> params = const {},
    Duration? timeout,
  }) {
    final refGen = SequentialRefGenerator();
    return PhoenixChannel.create(
      topic: topic,
      params: params,
      refGen: refGen,
      client: client,
    );
  }

  static PhoenixChannelRegistry makeRegistry(PhoenixClient client) {
    final refGen = SequentialRefGenerator();
    return PhoenixChannelRegistry(client: client, refGen: refGen);
  }
}

/// Simple incrementing ref generator for tests.
class SequentialRefGenerator implements RefGenerator {
  int _counter = 0;

  @override
  String next() => '${++_counter}';

  @override
  void reset() => _counter = 0;
}
