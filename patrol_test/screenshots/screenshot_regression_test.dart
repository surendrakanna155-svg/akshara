import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

/// Baseline screenshot regression markers for dashboards and key forms.
void main() {
  final regressionTargets = <(QaLoginPersona, String)>[
    (QaLoginPersona.principal, 'regression_principal'),
    (QaLoginPersona.teacher, 'regression_teacher'),
    (QaLoginPersona.parent, 'regression_parent'),
    (QaLoginPersona.student, 'regression_student'),
    (QaLoginPersona.finance, 'regression_finance'),
    (QaLoginPersona.inventory, 'regression_inventory'),
    (QaLoginPersona.superAdmin, 'regression_super_admin'),
  ];

  for (final (persona, slug) in regressionTargets) {
    patrolTest(
      'screenshot regression: ${persona.buttonLabel} dashboard',
      config: aksharaPatrolConfig(),
      ($) async {
        await bootstrapAndLogin($, persona);
        await capturePatrolScreenshot($, slug, subdir: 'regression/baseline');
      },
    );
  }

  patrolTest(
    'screenshot regression: QA login screen',
    config: aksharaPatrolConfig(),
    ($) async {
      await pumpAksharaApp($);
      await waitForQaLogin($);
      await capturePatrolScreenshot($, 'regression_qa_login', subdir: 'regression/baseline');
    },
  );
}
