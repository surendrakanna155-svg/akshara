import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'auth: session restore returns authenticated user to dashboard',
    config: aksharaPatrolConfig(),
    ($) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // First launch — login
      var container = await pumpAksharaApp($, prefs: prefs);
      await waitForQaLogin($);
      await loginAsQaPersona($, QaLoginPersona.teacher);
      expect($("Today's Classes"), findsAtLeast(1));
      container.dispose();

      // Second launch — session should restore via SharedPreferences
      container = await pumpAksharaApp($, prefs: prefs);
      await $.pumpAndSettle(timeout: const Duration(seconds: 20));
      await $("Today's Classes").waitUntilVisible(
        timeout: const Duration(seconds: 25),
      );
      expect($('QA Automation Login'), findsNothing);
      await capturePatrolScreenshot($, 'auth_session_restore', subdir: 'auth');
      container.dispose();
    },
  );
}
