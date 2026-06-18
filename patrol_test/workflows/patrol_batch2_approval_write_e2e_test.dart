import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/approval_center_journey_helpers.dart';
import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';
import '../helpers/teacher_journey_helpers.dart';

const _examId = 'exam_math_8a';
const _lastOpenMarkId = 'exam_math_8a_06';

Future<void> _saveLastOpenExamMark(PatrolIntegrationTester $) async {
  final field = find.byKey(QaTestKeys.examAdminMarkField(_lastOpenMarkId));
  await $.tester.ensureVisible(field);
  await $.tester.enterText(field, '44');
  await $.tester.tap(find.byKey(QaTestKeys.examAdminMarkSaveButton(_lastOpenMarkId)));
  await $.pumpAndSettle(timeout: const Duration(seconds: 8));
}

Future<void> _submitExamForPrincipalApproval(PatrolIntegrationTester $) async {
  await tapByKey($, QaTestKeys.examAdminProcessResultsButton(_examId));
  await $.pumpAndSettle(timeout: const Duration(seconds: 8));
  await tapByKey($, QaTestKeys.examAdminVerifyCoordinatorButton(_examId));
  await $.pumpAndSettle(timeout: const Duration(seconds: 8));
  await tapByKey($, QaTestKeys.examAdminSubmitApprovalButton(_examId));
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await assertSnackBarText($, 'Submitted for principal approval');
}

Future<void> _tapFinanceAssignConcession(PatrolIntegrationTester $) async {
  await scrollModuleBody($, 'Scholarship catalog', times: 2);
  await scrollModuleBody($, 'Discount rules', times: 2);
  await scrollModuleBody($, 'Student assignments', times: 2);
  await $(QaTestKeys.financeAssignConcessionButton).scrollTo();
  await $(QaTestKeys.financeAssignConcessionButton).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 8));
}

/// Batch 02 — approval write paths (continuous QA program).
void main() {
  patrolTest(
    'batch2: exam submit for principal approval',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, RouteNames.examAdministrationMarksPath(_examId));
      await waitForLoadingToClear($);
      await _saveLastOpenExamMark($);
      await _submitExamForPrincipalApproval($);
    },
  );

  patrolTest(
    'batch2: principal approves seeded exam results',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, RouteNames.managementApprovals);
      await waitForLoadingToClear($);
      await scrollTap($, 'Pending');
      await tapByKey($, QaTestKeys.approvalTypeFilterAcademic);
      await approvePendingRequestWithTitle(
        $,
        'Publish Class 8-A Mathematics results',
      );
    },
  );

  patrolTest(
    'batch2: fee structure create submits for approval',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.finance);
      await goToErpRoute($, RouteNames.financeFeeStructures);
      await waitForLoadingToClear($);
      await scrollTap($, 'Create structure');
      await assertVisibleText($, 'Create fee structure');
      await tapByKey($, QaTestKeys.financeCreateFeeStructureSubmitButton);
      await $.pumpAndSettle(timeout: const Duration(seconds: 12));
      await assertSnackBarText($, 'submitted for principal approval');
    },
  );

  patrolTest(
    'batch2: finance concession assign submits for approval',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.finance);
      await goToErpRoute($, RouteNames.financeDiscounts);
      await waitForLoadingToClear($, timeout: const Duration(seconds: 45));
      await assertVisibleText($, 'Student assignments');
      await _tapFinanceAssignConcession($);
      await assertVisibleText($, 'Assign fee concession');
      await tapByKey($, QaTestKeys.financeAssignConcessionSubmitButton);
      await $.pumpAndSettle(timeout: const Duration(seconds: 12));
      await assertVisibleKey($, QaTestKeys.financeAssignConcessionSuccessSnackbar);
    },
  );

  patrolTest(
    'batch2: parent attendance correction submit',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await goToErpRoute($, RouteNames.parentAttendance);
      await waitForLoadingToClear($);
      await scrollTap($, '5 Jun');
      await tapByKey($, QaTestKeys.parentAttendanceCorrectionButton);
      await assertVisibleText($, 'Request attendance correction');
      await tapByKey($, QaTestKeys.parentAttendanceCorrectionSubmitButton);
      await $.pumpAndSettle(timeout: const Duration(seconds: 12));
      await assertVisibleKey(
        $,
        QaTestKeys.parentAttendanceCorrectionSuccessSnackbar,
      );
    },
  );

  patrolTest(
    'batch2: principal approves attendance correction inbox',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, RouteNames.managementApprovals);
      await waitForLoadingToClear($);
      await scrollTap($, 'Pending');
      await tapByKey($, QaTestKeys.approvalTypeFilterAttendance);
      await assertVisibleText($, 'Approval queue');
    },
  );

  patrolTest(
    'batch2: inventory PO draft create',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.inventory);
      await goToErpRoute($, RouteNames.inventoryProcurement);
      await waitForLoadingToClear($);
      await assertVisibleText($, 'Purchase orders');
      await tapByKey($, QaTestKeys.inventoryCreatePoButton);
      await $('Create draft PO').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 12));
      await assertVisibleKey($, QaTestKeys.inventoryPoSuccessSnackbar);
    },
  );

  patrolTest(
    'batch2: hr leave submit for approval',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.hrLeave);
      await waitForLoadingToClear($);
      await assertVisibleText($, 'Leave requests');
      await tapByKey($, QaTestKeys.hrCreateLeaveButton);
      await $('Submit').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 12));
      await assertVisibleKey($, QaTestKeys.hrLeaveSuccessSnackbar);
    },
  );

  patrolTest(
    'batch2: exam marks entry saves final open slot',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, RouteNames.examAdministrationMarksPath(_examId));
      await waitForLoadingToClear($);
      await assertVisibleKey($, QaTestKeys.examAdminMarkField(_lastOpenMarkId));
      await _saveLastOpenExamMark($);
      await assertVisibleKey($, QaTestKeys.examAdminProcessResultsButton(_examId));
    },
  );

  patrolTest(
    'batch2: finance fee structure create dialog',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.finance);
      await goToErpRoute($, RouteNames.financeFeeStructures);
      await waitForLoadingToClear($);
      await scrollTap($, 'Create structure');
      await assertVisibleText($, 'Create fee structure');
      await assertVisibleKey($, QaTestKeys.financeCreateFeeStructureSubmitButton);
    },
  );

  patrolTest(
    'batch2: finance concession assign dialog',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.finance);
      await goToErpRoute($, RouteNames.financeDiscounts);
      await waitForLoadingToClear($, timeout: const Duration(seconds: 45));
      await assertVisibleText($, 'Student assignments');
      await _tapFinanceAssignConcession($);
      await assertVisibleText($, 'Assign fee concession');
      await assertVisibleKey($, QaTestKeys.financeAssignConcessionSubmitButton);
    },
  );

  patrolTest(
    'batch2: management attendance corrections admin list',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, RouteNames.managementAttendanceCorrections);
      await waitForLoadingToClear($);
      await assertVisibleText($, 'Attendance corrections');
    },
  );

  patrolTest(
    'batch2: teacher attendance post-submit lock',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await tapBottomNav($, 'Classes');
      await submitClassAttendance($);
      await verifyAttendanceSubmissionPersists($);
    },
  );

  patrolTest(
    'batch2: principal approval center inventory filter',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await goToErpRoute($, RouteNames.managementApprovals);
      await waitForLoadingToClear($);
      await tapByKey($, QaTestKeys.approvalTypeFilterInventory);
      await assertVisibleText($, 'Approval queue');
    },
  );
}
