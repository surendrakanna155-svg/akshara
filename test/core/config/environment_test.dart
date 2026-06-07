import 'package:akshara_erp/core/config/environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Environment', () {
    test('development has local API base URL', () {
      expect(Environment.development.apiBaseUrl, contains('localhost'));
      expect(Environment.development.enableApiMode, isFalse);
      expect(Environment.development.enableLogging, isTrue);
    });

    test('production disables logging', () {
      expect(Environment.production.enableLogging, isFalse);
      expect(Environment.production.apiBaseUrl, isNot(contains('example')));
    });

    test('staging uses staging host', () {
      expect(
        Environment.staging.apiBaseUrl,
        contains('staging-api.aksharaerp.com'),
      );
    });
  });
}
