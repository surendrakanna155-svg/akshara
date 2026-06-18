import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';
import '../helpers/teacher_journey_helpers.dart';

/// Batch 01 — P0 depth expansion (continuous QA program).
///
/// Extends pilot closure with approval filters, audit register, attendance
/// locks, S360 tabs, and SIS export. Reuses helpers — no duplicate journeys.
void main() {
  patrolTest(
    'batch1: finance audit register export',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.finance);
      await goToErpRoute($, RouteNames.financeReports);
      await waitForLoadingToClear($);
      await assertVisibleText($, 'Report catalog');
      await scrollModuleBody($, 'Audit register');
      await assertVisibleKey($, QaTestKeys.financeAuditRegisterExportButton);
    },
  );

  patrolTest(
    'batch1: finance reports excel export button',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.finance);
      await goToErpRoute($, RouteNames.financeReports);
      await waitForLoadingToClear($);
      await scrollModuleBody($, 'Export Excel');
      await assertVisibleKey($, QaTestKeys.financeReportExportExcelButton);
    },
  );

  patrolTest(
    'batch1: approval center leave filter',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, RouteNames.managementApprovals);
      await waitForLoadingToClear($);
      await assertVisibleKey($, QaTestKeys.approvalCenterScreen);
      await tapByKey($, QaTestKeys.approvalTypeFilterLeave);
    },
  );

  patrolTest(
    'batch1: approval center attendance filter',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, RouteNames.managementApprovals);
      await waitForLoadingToClear($);
      await tapByKey($, QaTestKeys.approvalTypeFilterAttendance);
      await assertVisibleKey($, QaTestKeys.approvalCenterScreen);
    },
  );

  patrolTest(
    'batch1: approval center finance filter',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, RouteNames.managementApprovals);
      await waitForLoadingToClear($);
      await tapByKey($, QaTestKeys.approvalTypeFilterFinance);
      await assertVisibleKey($, QaTestKeys.approvalCenterScreen);
    },
  );

  patrolTest(
    'batch1: parent attendance correction dialog',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await goToErpRoute($, RouteNames.parentAttendance);
      await waitForLoadingToClear($);
      await scrollTap($, '5 Jun');
      await tapByKey($, QaTestKeys.parentAttendanceCorrectionButton);
      await assertVisibleText($, 'Request attendance correction');
    },
  );

  patrolTest(
    'batch1: teacher attendance post-submit lock',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await tapBottomNav($, 'Classes');
      await submitClassAttendance($);
      await verifyAttendanceSubmissionPersists($);
    },
  );

  patrolTest(
    'batch1: exam administration create dialog',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, RouteNames.examAdministration);
      await waitForLoadingToClear($);
      await tapByKey($, QaTestKeys.examAdminCreateButton);
      await assertVisibleText($, 'Create exam');
    },
  );

  patrolTest(
    'batch1: SIS registry export button',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, RouteNames.sisStudents);
      await waitForLoadingToClear($);
      await assertVisibleKey($, QaTestKeys.sisRegistryExportButton);
    },
  );

  patrolTest(
    'batch1: principal command center',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, RouteNames.principalCommand);
      await waitForLoadingToClear($);
      await assertVisibleText($, 'Principal Command Center');
    },
  );

  patrolTest(
    'batch1: student 360 attendance tab',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, '${RouteNames.student360}/SIS-STU-10418');
      await waitForLoadingToClear($);
      await assertVisibleKey($, QaTestKeys.student360TabBar);
      await scrollTap($, 'Attendance');
      await assertVisibleText($, 'Attendance');
    },
  );

  patrolTest(
    'batch1: management dashboard principal overview',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, RouteNames.managementDashboard);
      await waitForLoadingToClear($);
      await assertVisibleText($, 'Principal overview');
      await assertVisibleKey($, QaTestKeys.managementDashboardExportButton);
    },
  );
}
