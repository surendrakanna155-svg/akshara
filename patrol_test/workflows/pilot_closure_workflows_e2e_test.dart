import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';
import '../helpers/teacher_journey_helpers.dart';

/// Final pilot closure — executable journeys for certification gate (Agent B).
void main() {
  patrolTest(
    'pilot: exam administration list',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, RouteNames.examAdministration);
      await waitForLoadingToClear($);
      await assertVisibleText($, 'Exam Administration');
      await assertVisibleKey($, QaTestKeys.examAdminCreateButton);
    },
  );

  patrolTest(
    'pilot: exam marks entry',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute(
        $,
        RouteNames.examAdministrationMarksPath('exam_math_8a'),
      );
      await waitForLoadingToClear($);
      await assertVisibleText($, 'Marks entry');
      await assertVisibleKey($, QaTestKeys.examMarksExportButton('exam_math_8a'));
    },
  );

  patrolTest(
    'pilot: principal approval center academic inbox',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, RouteNames.managementApprovals);
      await waitForLoadingToClear($);
      await assertVisibleKey($, QaTestKeys.approvalCenterScreen);
      await tapByKey($, QaTestKeys.approvalTypeFilterAcademic);
    },
  );

  patrolTest(
    'pilot: teacher attendance correction request',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await tapBottomNav($, 'Classes');
      await submitClassAttendance($);
      await scrollTap($, 'Request correction');
      await assertVisibleText($, 'Request attendance correction');
    },
  );

  patrolTest(
    'pilot: management attendance corrections admin',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, RouteNames.managementAttendanceCorrections);
      await waitForLoadingToClear($);
      await assertVisibleText($, 'Attendance corrections');
    },
  );

  patrolTest(
    'pilot: parent leave application',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await goToErpRoute($, RouteNames.parentLeave);
      await waitForLoadingToClear($);
      await assertVisibleText($, 'Leave Requests');
    },
  );

  patrolTest(
    'pilot: finance concession discounts',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.finance);
      await goToErpRoute($, RouteNames.financeDiscounts);
      await waitForLoadingToClear($);
      await assertVisibleText($, 'Discounts');
    },
  );

  patrolTest(
    'pilot: finance refunds approval redirect',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.finance);
      await goToErpRoute($, RouteNames.financeRefunds);
      await waitForLoadingToClear($);
      await assertVisibleText($, 'Refunds');
      await scrollTap($, 'Kavya Iyer');
      await assertVisibleKey($, QaTestKeys.openApprovalCenterButton);
    },
  );

  patrolTest(
    'pilot: student 360 dossier navigation',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, '${RouteNames.student360}/SIS-STU-10418');
      await waitForLoadingToClear($);
      await assertVisibleText($, 'Student 360');
      await assertVisibleKey($, QaTestKeys.student360TabBar);
      await assertVisibleKey($, QaTestKeys.student360ExportButton);
    },
  );
}
