import 'dart:io';

Future<void> assertServerRunning({int port = 4000}) async {
  final client = HttpClient();
  try {
    final req = await client
        .get('localhost', port, '/health')
        .timeout(const Duration(seconds: 2));
    final res = await req.close();
    if (res.statusCode != 200) throw StateError('bad status');
  } on Exception catch (_) {
    throw StateError(
      'Phoenix test server is not running.\n'
      'Start it with: ./scripts/run_integration_tests.sh',
    );
  } finally {
    client.close();
  }
}
