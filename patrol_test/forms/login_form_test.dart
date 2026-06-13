import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/auth_provider.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

Future<void> _goToLoginScreen(PatrolIntegrationTester $) async {
  await pumpAksharaApp($);
  await waitForQaLogin($);
  await loginAsQaPersona($, QaLoginPersona.parent);
  await $('Parent profile').tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await $(QaTestKeys.logoutButton).scrollTo();
  await $(QaTestKeys.logoutButton).tap();
  await $(QaTestKeys.logoutConfirmButton).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
}

void main() {
  patrolTest(
    'forms: login validation message for invalid phone',
    config: aksharaPatrolConfig(),
    ($) async {
      await _goToLoginScreen($);
      await $(QaTestKeys.loginPhoneField).enterText('123');
      await $(QaTestKeys.loginContinueButton).tap();
      await $.pumpAndSettle();
      expect($('Enter a valid 10-digit number'), findsOneWidget);
      await capturePatrolScreenshot($, 'form_invalid_phone', subdir: 'forms');
    },
  );

  patrolTest(
    'forms: login accepts valid phone and shows OTP screen',
    config: aksharaPatrolConfig(),
    ($) async {
      await _goToLoginScreen($);
      await $(QaTestKeys.loginPhoneField).enterText('9000100001');
      await $(QaTestKeys.loginContinueButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      expect($('Verify OTP'), findsOneWidget);
      await capturePatrolScreenshot($, 'form_otp_screen', subdir: 'forms');
    },
  );

  patrolTest(
    'forms: OTP rejects invalid input',
    config: aksharaPatrolConfig(),
    ($) async {
      await _goToLoginScreen($);
      await $(QaTestKeys.loginPhoneField).enterText('9000100001');
      await $(QaTestKeys.loginContinueButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await $(QaTestKeys.otpField).enterText('000000');
      await $(QaTestKeys.otpVerifyButton).tap();
      await $.pumpAndSettle();
      expect($('Invalid OTP'), findsOneWidget);
    },
  );

  patrolTest(
    'forms: OTP accepts valid mock code',
    config: aksharaPatrolConfig(),
    ($) async {
      await _goToLoginScreen($);
      await $(QaTestKeys.loginPhoneField).enterText('9000100001');
      await $(QaTestKeys.loginContinueButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await $(QaTestKeys.otpField).enterText(kMockValidOtp);
      await $(QaTestKeys.otpVerifyButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
      expect($('Fees'), findsAtLeast(1));
    },
  );
}
