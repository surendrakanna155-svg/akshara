import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: management dashboard KPI drills to finance and admissions',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.managementDashboard);
      await assertVisibleText($, 'Revenue (MTD)');

      await $(QaTestKeys.managementKpiDrillButton('revenue_mtd')).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleText($, 'Report catalog');

      await goToErpRoute($, RouteNames.managementDashboard);
      await $(QaTestKeys.managementKpiDrillButton('fee_defaulters')).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleText($, 'Defaulters list');

      await goToErpRoute($, RouteNames.managementDashboard);
      await $(QaTestKeys.managementKpiDrillButton('new_admissions')).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleText($, 'Funnel stages');
    },
  );

  patrolTest(
    'journey: management analytics KPI drills to attendance and academic intelligence',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.managementAnalytics);
      await assertVisibleText($, 'Attendance (MTD)');

      await $(QaTestKeys.managementKpiDrillButton('attendance')).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleText($, 'Student Success Intelligence');

      await goToErpRoute($, RouteNames.managementAcademics);
      await assertVisibleText($, 'Overall Pass %');

      await $(QaTestKeys.managementKpiDrillButton('pass_rate')).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleText($, 'Exam & Academic Intelligence');
    },
  );
}
