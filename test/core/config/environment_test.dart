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

  group('Environment.guardForRelease (SEC-1 fail-closed)', () {
    test('non-release builds pass the resolved env through unchanged', () {
      // debug/profile/tests: no guard, dev env allowed as-is.
      final result = Environment.guardForRelease(
        Environment.development,
        isRelease: false,
        rawAppEnv: 'development',
      );
      expect(result.name, EnvironmentName.development);
      expect(identical(result, Environment.development), isTrue);
    });

    test('release with non-production APP_ENV throws (development)', () {
      expect(
        () => Environment.guardForRelease(
          Environment.development,
          isRelease: true,
          rawAppEnv: 'development',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('release with staging APP_ENV throws', () {
      expect(
        () => Environment.guardForRelease(
          Environment.staging,
          isRelease: true,
          rawAppEnv: 'staging',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('release production with API mode OFF throws (no mock fallback)', () {
      // production const defaults enableApiMode:false — a release must set
      // ENABLE_API_MODE=true or it is refused (closes the SEC-9 mock path).
      expect(
        Environment.production.enableApiMode,
        isFalse,
        reason: 'guards against mock auth in a release build',
      );
      expect(
        () => Environment.guardForRelease(
          Environment.production,
          isRelease: true,
          rawAppEnv: 'production',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('release production with API mode ON is allowed and forces demo/QA off',
        () {
      final live = Environment.production.copyWith(
        enableApiMode: true,
        // even if defines somehow re-enabled these, the guard must strip them.
        disableDemoAuth: false,
        enableQaLogin: true,
      );
      final result = Environment.guardForRelease(
        live,
        isRelease: true,
        rawAppEnv: 'production',
      );
      expect(result.name, EnvironmentName.production);
      expect(result.enableApiMode, isTrue);
      expect(result.disableDemoAuth, isTrue);
      expect(result.enableQaLogin, isFalse);
    });
  });
}
