/// Phoenix implementation of [SocketClient]
library;

import 'package:socket_client/socket_client.dart' show SocketClient;

export 'package:socket_client/socket_client.dart'
    show
        ConnectionConfigProvider,
        ConstantConfigProvider,
        FrameCodec,
        FrameDecodeException,
        IntervalFramedHeartbeat,
        MonotonicRefGenerator,
        RefGenerator,
        SocketClient,
        SocketHeartbeat,
        SwappableConfigProvider;

export 'src/phoenix_channel.dart';
export 'src/phoenix_channel_state.dart';
export 'src/phoenix_client.dart';
export 'src/phoenix_codec.dart';
export 'src/phoenix_connection_config.dart';
export 'src/phoenix_heartbeat_ping_builder.dart';
export 'src/phoenix_message.dart';
export 'src/phoenix_presence.dart';
