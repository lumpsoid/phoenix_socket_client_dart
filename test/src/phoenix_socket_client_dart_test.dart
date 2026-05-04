// Not required for test files
// ignore_for_file: prefer_const_constructors
import 'package:test/test.dart';

void main() {
  group('PhoenixSocketClientDart', () {
    test('can be instantiated', () {
      expect(PhoenixSocketClient(), isNotNull);
    });
  });
}

class PhoenixSocketClient {}
