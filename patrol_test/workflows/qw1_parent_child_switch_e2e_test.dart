import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

/// QW1 · QA-J-003 — Parent switches the active child in a multi-child household
/// and the dashboard reloads to the second child's data. The QA parent persona
/// carries two linked children (Ravi Kumar 8-A, Priya Kumar 5-B); switching to
/// Priya must re-key the dashboard future so the greeting (data-derived, not the
/// chip) flips to "Priya's Day at a Glance".

void main() {
  patrolTest(
    'qw1-j003: parent switches active child → dashboard reloads to child B',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await assertVisibleKey($, QaTestKeys.parentDashboardScreen);

      // Lands on the first child (Ravi): the data-derived greeting proves it.
      await assertVisibleText($, "Ravi's Day at a Glance");

      // Open the app-bar child switcher and pick the second child (Priya).
      await tapByKey($, QaTestKeys.parentChildSelectorChip);
      await assertVisibleText($, 'Switch child');
      await tapByKey($, QaTestKeys.parentChildSwitcherOption('child-priya'));

      // The dashboard future re-keyed to Priya: greeting + chip both reflect her.
      await assertVisibleKey($, QaTestKeys.parentDashboardScreen);
      await assertVisibleText($, "Priya's Day at a Glance");
      await assertVisibleText($, 'Priya Kumar');
    },
  );
}
