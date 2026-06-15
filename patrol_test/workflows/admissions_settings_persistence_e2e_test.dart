import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: admissions settings save',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'admissions',
        subNavLabel: 'Settings',
        workflowAnchor: 'Lead stages',
      );

      await tapBodyText($, 'Save settings', scrollAnchor: 'Lead stages');
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleText($, 'Admissions settings saved');
    },
  );
}
