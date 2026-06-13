import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  for (final persona in kAllQaPersonas) {
    patrolTest(
      'auth: QA login routes ${persona.buttonLabel} to dashboard',
      config: aksharaPatrolConfig(),
      ($) async {
        await bootstrapAndLogin($, persona);
        expect($(persona.dashboardAnchor), findsAtLeast(1));
        await capturePatrolScreenshot(
          $,
          'auth_${persona.name}_dashboard',
          subdir: 'auth',
        );
      },
    );
  }

  patrolTest(
    'auth: QA login mode screen is available in QA builds',
    config: aksharaPatrolConfig(),
    ($) async {
      await pumpAksharaApp($);
      await waitForQaLogin($);
      expect($(QaTestKeys.qaLoginScreen), findsOneWidget);
      expect($('QA Automation Login'), findsOneWidget);
      expect($('Principal'), findsOneWidget);
    },
  );
}
