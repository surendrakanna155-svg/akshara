import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: admissions reports export',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'admissions',
        subNavLabel: 'Reports',
        workflowAnchor: 'Conversion funnel',
      );
      await scrollTap($, 'Export');
      await assertSnackBarText(
        $,
        'Export queued — download will start shortly.',
      );
    },
  );
}
