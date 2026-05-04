import 'package:socket_client/socket_client.dart';

class PhoenixConnectionConfig extends ConnectionConfig {
  PhoenixConnectionConfig({
    required String url,
    super.headers,
    super.protocols,
    super.connectTimeout,
    String vsn = defaultVsn,
  }) : super(url: _appendVsn(url, vsn));

  static const defaultVsn = '2.0.0';

  static String _appendVsn(String url, String vsn) {
    final uri = Uri.parse(url);
    return uri
        .replace(
          queryParameters: {...uri.queryParameters, 'vsn': vsn},
        )
        .toString();
  }
}
