import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'performance: cold launch to QA login under 20s',
    config: aksharaPatrolConfig(),
    ($) async {
      final stopwatch = Stopwatch()..start();
      await pumpAksharaApp($);
      await waitForQaLogin($);
      stopwatch.stop();
      expect(
        stopwatch.elapsed.inSeconds,
        lessThan(20),
        reason: 'Splash + session resolve should complete quickly',
      );
    },
  );

  patrolTest(
    'performance: QA login to dashboard under 15s',
    config: aksharaPatrolConfig(),
    ($) async {
      await pumpAksharaApp($);
      await waitForQaLogin($);
      final stopwatch = Stopwatch()..start();
      await loginAsQaPersona($, QaLoginPersona.principal);
      stopwatch.stop();
      expect(stopwatch.elapsed.inSeconds, lessThan(15));
    },
  );

  patrolTest(
    'performance: parent dashboard settle under 10s',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      final stopwatch = Stopwatch()..start();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      stopwatch.stop();
      expect(stopwatch.elapsed.inSeconds, lessThan(10));
    },
  );

  patrolTest(
    'performance: finance dashboard KPI render',
    config: aksharaPatrolConfig(),
    ($) async {
      final stopwatch = Stopwatch()..start();
      await bootstrapAndLogin($, QaLoginPersona.finance);
      stopwatch.stop();
      expect(stopwatch.elapsed.inSeconds, lessThan(20));
      expect($('Fee Collected (MTD)'), findsAtLeast(1));
    },
  );
}
