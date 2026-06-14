import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: ERP floating dock expands and opens context-aware copilot',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.managementDashboard);
      await assertVisibleText($, 'Revenue (MTD)');

      await $(QaTestKeys.copilotFloatingDockFab).waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );
      await $(QaTestKeys.copilotFloatingDockFab).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await assertVisibleKey($, QaTestKeys.copilotFloatingDockPanel);
      await assertVisibleKey($, QaTestKeys.copilotFloatingDockContextSummary);

      await $(QaTestKeys.copilotFloatingDockOpenButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await assertVisibleKey($, QaTestKeys.copilotContextBanner);
      await assertVisibleText($, 'Owner Dashboard');
    },
  );

  patrolTest(
    'journey: teacher persona assistant shell shows context banner',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await goToErpRoute($, RouteNames.teacherDashboard);

      await $(QaTestKeys.copilotFloatingDockFab).waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );
      await $(QaTestKeys.copilotFloatingDockFab).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await $(QaTestKeys.copilotFloatingDockOpenButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await assertVisibleKey($, QaTestKeys.copilotPersonaContextBanner);
      await assertVisibleText($, 'Teacher Assistant');
      await assertVisibleText($, 'Weak students');

      await $(QaTestKeys.copilotPersonaPromptChip(
        'Which students missed homework this week?',
      )).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await assertVisibleKey($, QaTestKeys.copilotPersonaReplyPanel);
    },
  );
}
