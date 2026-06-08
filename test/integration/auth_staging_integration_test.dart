import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/repositories/api/auth/remote/auth_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/api_envelope_dto.dart';

/// Optional smoke test against a live staging/local Supabase API router.
///
/// Run:
/// flutter test test/integration/auth_staging_integration_test.dart \
///   --dart-define=RUN_STAGING_AUTH_TEST=true \
///   --dart-define=API_BASE_URL=http://127.0.0.1:54321/functions/v1/api \
///   --dart-define=STAGING_TEST_PHONE=9876543210
void main() {
  const runStaging = bool.fromEnvironment('RUN_STAGING_AUTH_TEST');
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  const phone = String.fromEnvironment(
    'STAGING_TEST_PHONE',
    defaultValue: '9876543210',
  );

  if (!runStaging) {
    test('auth staging integration skipped without RUN_STAGING_AUTH_TEST', () {
      expect(true, isTrue);
    });
    return;
  }

  group('Auth staging integration', () {
    late Dio dio;
    late AuthRemoteDataSource remote;

    setUp(() {
      if (baseUrl.isEmpty) {
        fail('API_BASE_URL dart-define is required for staging integration test');
      }
      dio = Dio(BaseOptions(baseUrl: baseUrl));
      remote = AuthRemoteDataSource(dio);
    });

    test('health endpoint returns envelope', () async {
      final response = await dio.get<Map<String, dynamic>>('/health');
      final envelope = ApiEnvelopeDto.fromJson(response.data ?? {});
      expect(envelope.requireData()['status'], 'ok');
    });

    test('OTP login and verify flow', () async {
      final login = await remote.login(
        identifier: phone,
        identifierType: 'phone',
      );
      expect(login.raw['success'], isTrue);

      final otpMatch = RegExp(r'\b(\d{6})\b').firstMatch(
        login.raw['message'] as String? ?? '',
      );
      if (otpMatch == null) {
        fail(
          'Could not parse OTP from login message — enable AUTH_OTP_DEV_MODE on staging',
        );
      }

      final verify = await remote.verifyOtp(
        identifier: phone,
        otp: otpMatch.group(1)!,
        identifierType: 'phone',
      );
      expect(verify.raw['accessToken'], isNotEmpty);
      expect(verify.raw['refreshToken'], isNotEmpty);
      expect(verify.raw['user'], isA<Map<String, dynamic>>());
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
