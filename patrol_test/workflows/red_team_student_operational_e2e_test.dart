import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'red-team: student report card journey',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await assertVisibleKey($, QaTestKeys.studentDashboardScreen);

      await tapStudentDashboardQuickAction($, 'report_card');
      await assertPatrolRoute($, RouteNames.studentReportCard);
      await assertVisibleKey($, QaTestKeys.studentReportCardScreen);
      await assertVisibleText($, 'Report Card');
      await assertVisibleText($, 'Term summary');

      await tapStudentHome($);
      await assertVisibleKey($, QaTestKeys.studentDashboardScreen);
    },
  );

  patrolTest(
    'red-team: student progress and AI guidance journey',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await assertVisibleKey($, QaTestKeys.studentDashboardScreen);

      await tapStudentDashboardQuickAction($, 'progress');
      await assertPatrolRoute($, RouteNames.studentProgress);
      await assertVisibleKey($, QaTestKeys.studentProgressScreen);
      await assertVisibleText($, 'My Progress');
      await assertVisibleText($, 'Subject progress');
      await assertVisibleText($, 'Ask AI tutor');

      await tapStudentHome($);
      await assertVisibleKey($, QaTestKeys.studentDashboardScreen);
    },
  );
}
