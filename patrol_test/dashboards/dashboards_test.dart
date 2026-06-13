import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  for (final persona in kAllQaPersonas) {
    patrolTest(
      'dashboard: ${persona.buttonLabel} dashboard renders',
      config: aksharaPatrolConfig(),
      ($) async {
        await bootstrapAndLogin($, persona);
        await assertVisibleText(
          $,
          persona.dashboardAnchor,
          timeout: const Duration(seconds: 25),
        );
        await capturePatrolScreenshot(
          $,
          'dashboard_${persona.name}',
          subdir: 'dashboards',
        );
      },
    );
  }

  patrolTest(
    'dashboard: intelligence hub opens from principal overview',
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
