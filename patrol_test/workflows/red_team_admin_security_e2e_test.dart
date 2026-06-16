import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'red-team: super admin admin hub loads module cards',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await assertVisibleKey($, QaTestKeys.adminHubScreen);
      await assertVisibleText($, 'Admin Hub');
      await assertVisibleText(
        $,
        'Jump to an ERP module you are authorized to access.',
      );
      await assertVisibleKey($, QaTestKeys.adminHubModuleCard('Finance'));
      await assertVisibleKey($, QaTestKeys.adminHubModuleCard('Admissions'));
    },
  );

  patrolTest(
    'red-team: super admin control center access succeeds',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'controlCenter',
        workflowAnchor: 'ERP module adoption',
      );
      await assertPatrolRoute($, RouteNames.controlCenterDashboard);
    },
  );

  patrolTest(
    'red-team: principal control center guard blocks access',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, RouteNames.controlCenterDashboard);
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
      await assertVisibleKey($, QaTestKeys.accessDeniedScreen);
      await assertVisibleText($, 'Access Denied');
    },
  );
}
