import 'package:akshara_erp/core/config/environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Production environment profile', () {
    test('production disables demo auth and requires TLS', () {
      const env = Environment.production;
      expect(env.disableDemoAuth, isTrue);
      expect(env.requireAuthentication, isTrue);
      expect(env.requireTls, isTrue);
      expect(env.enableLogging, isFalse);
    });

    test('staging allows demo auth until API mode enabled', () {
      const env = Environment.staging;
      expect(env.disableDemoAuth, isFalse);
    });
  });
}
