import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';

void main() {
  patrolTest(
    'smoke: app launches and QA login screen renders',
    config: aksharaPatrolConfig(),
    ($) async {
      await pumpAksharaApp($);
      await waitForQaLogin($);
      expect($(QaTestKeys.qaLoginScreen), findsOneWidget);
      expect($('QA Automation Login'), findsOneWidget);
      expect($('Principal'), findsOneWidget);
      await capturePatrolScreenshot($, 'smoke_qa_login', subdir: 'smoke');
    },
  );

  patrolTest(
    'smoke: tap widget and enter text on login screen',
    config: aksharaPatrolConfig(),
    ($) async {
      await pumpAksharaApp($);
      await waitForQaLogin($);
      await $('Teacher').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
      expect($("Today's Classes"), findsAtLeast(1));
      await capturePatrolScreenshot($, 'smoke_teacher_dashboard', subdir: 'smoke');
    },
  );
}
