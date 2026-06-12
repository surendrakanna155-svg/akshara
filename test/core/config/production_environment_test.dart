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

    test('staging disables demo auth by default (pilot hardened)', () {
      const env = Environment.staging;
      expect(env.disableDemoAuth, isTrue);
    });

    test('ENABLE_DEMO_AUTH opt-in re-enables testing mode', () {
      final env = Environment.staging.copyWith(disableDemoAuth: false);
      expect(env.disableDemoAuth, isFalse);
    });
  });
}
