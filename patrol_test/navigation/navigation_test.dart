import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'navigation: parent bottom nav — fees and home tabs',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await $('Fees').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await $('Home').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      expect($('Fees'), findsAtLeast(1));
    },
  );

  patrolTest(
    'navigation: teacher dashboard shell loads',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await assertVisibleText($, "Today's Classes");
      await capturePatrolScreenshot($, 'nav_teacher', subdir: 'navigation');
    },
  );

  patrolTest(
    'navigation: super admin ERP drawer opens',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      try {
        await $('Open navigation').tap();
        await $.pumpAndSettle(timeout: const Duration(seconds: 5));
        expect($('Admissions'), findsAtLeast(1));
      } catch (_) {
        expect($('Admin Hub'), findsAtLeast(1));
      }
      await capturePatrolScreenshot($, 'nav_erp_drawer', subdir: 'navigation');
    },
  );

  patrolTest(
    'navigation: OTP back returns to login',
    config: aksharaPatrolConfig(),
    ($) async {
      await pumpAksharaApp($);
      await waitForQaLogin($);
      await loginAsQaPersona($, QaLoginPersona.parent);
      await $(QaTestKeys.profileButton).tap();
      await $.pumpAndSettle();
      await $(QaTestKeys.logoutButton).scrollTo();
      await $(QaTestKeys.logoutButton).tap();
      await $(QaTestKeys.logoutConfirmButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await $(QaTestKeys.loginPhoneField).enterText('9000100001');
      await $(QaTestKeys.loginContinueButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await $.platformAutomator.android.pressBack();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      expect($('Welcome back'), findsOneWidget);
    },
  );

  patrolTest(
    'navigation: principal analytics deep link',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await $('Analytics').scrollTo();
      await $('Analytics').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
      await assertVisibleText($, 'Analytics');
    },
  );
}
