import 'package:phoenix_socket_client/src/phoenix_connection_config.dart';
import 'package:test/test.dart';

void main() {
  group('PhoenixConnectionConfig', () {
    test('appends default vsn=2.0.0 to URL', () {
      final config = PhoenixConnectionConfig(
        url: 'ws://localhost:4000/socket/websocket',
      );
      expect(config.url, contains('vsn=2.0.0'));
    });

    test('appends custom vsn to URL', () {
      final config = PhoenixConnectionConfig(
        url: 'ws://localhost:4000/socket/websocket',
        vsn: '1.0.0',
      );
      expect(config.url, contains('vsn=1.0.0'));
    });

    test('preserves existing query parameters', () {
      final config = PhoenixConnectionConfig(
        url: 'ws://localhost:4000/socket/websocket?token=abc',
      );
      expect(config.url, contains('token=abc'));
      expect(config.url, contains('vsn=2.0.0'));
    });

    test('overwrites vsn if already present in URL', () {
      final config = PhoenixConnectionConfig(
        url: 'ws://localhost:4000/socket/websocket?vsn=old',
        // test
        // ignore: avoid_redundant_argument_values
        vsn: '2.0.0',
      );
      expect(config.url, contains('vsn=2.0.0'));
      expect(config.url, isNot(contains('vsn=old')));
    });
  });
}
