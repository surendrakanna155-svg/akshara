import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/approval_center_journey_helpers.dart';
import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

Future<void> _assignFinanceConcession(PatrolIntegrationTester $) async {
  await scrollModuleBody($, 'Scholarship catalog', times: 2);
  await scrollModuleBody($, 'Discount rules', times: 2);
  await scrollModuleBody($, 'Student assignments', times: 2);
  await $(QaTestKeys.financeAssignConcessionButton).scrollTo();
  await $(QaTestKeys.financeAssignConcessionButton).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 8));
  await assertVisibleText($, 'Assign fee concession');
  await tapByKey($, QaTestKeys.financeAssignConcessionSubmitButton);
  await $.pumpAndSettle(timeout: const Duration(seconds: 12));
  await assertVisibleKey($, QaTestKeys.financeAssignConcessionSuccessSnackbar);
}

Future<void> _submitParentAttendanceCorrection(PatrolIntegrationTester $) async {
  await scrollTap($, '5 Jun');
  await tapByKey($, QaTestKeys.parentAttendanceCorrectionButton);
  await assertVisibleText($, 'Request attendance correction');
  await tapByKey($, QaTestKeys.parentAttendanceCorrectionSubmitButton);
  await $.pumpAndSettle(timeout: const Duration(seconds: 12));
  await assertVisibleKey(
    $,
    QaTestKeys.parentAttendanceCorrectionSuccessSnackbar,
  );
}

Future<void> _createInventoryPoDraft(PatrolIntegrationTester $) async {
  await tapByKey($, QaTestKeys.inventoryCreatePoButton);
  await $('Create draft PO').tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 12));
  await assertVisibleKey($, QaTestKeys.inventoryPoSuccessSnackbar);
}

/// Batch 02b — cross-persona approval chains (continuous QA program).
void main() {
  patrolTest(
    'batch2b: finance concession assign then principal approves',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.finance);
      await goToErpRoute($, RouteNames.financeDiscounts);
      await waitForLoadingToClear($, timeout: const Duration(seconds: 45));
      await assertVisibleText($, 'Student assignments');
      await _assignFinanceConcession($);

      await openPrincipalApprovalCenter(
        $,
        categoryFilterKey: QaTestKeys.approvalTypeFilterFinance,
        switchFromCurrentPersona: true,
      );
      await approvePendingRequestWithTitle($, 'Fee concession — Arjun Patel');
    },
  );

  patrolTest(
    'batch2b: parent attendance correction then principal approves',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await goToErpRoute($, RouteNames.parentAttendance);
      await waitForLoadingToClear($);
      await _submitParentAttendanceCorrection($);

      await openPrincipalApprovalCenter(
        $,
        categoryFilterKey: QaTestKeys.approvalTypeFilterAttendance,
        switchFromCurrentPersona: true,
      );
      await approvePendingRequestWithTitle(
        $,
        'Attendance correction — Ravi Kumar',
      );
    },
  );

  patrolTest(
    'batch2b: inventory PO draft then principal approves',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.inventory);
      await goToErpRoute($, RouteNames.inventoryProcurement);
      await waitForLoadingToClear($);
      await assertVisibleText($, 'Purchase orders');
      await _createInventoryPoDraft($);

      await openPrincipalApprovalCenter(
        $,
        categoryFilterKey: QaTestKeys.approvalTypeFilterInventory,
        switchFromCurrentPersona: true,
      );
      await approvePendingRequestWithTitle($, 'Approve PO —');
    },
  );

  patrolTest(
    'batch2b: exam publish approval then parent sees results',
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

      await switchQaPersona($, QaLoginPersona.parent);
      await goToErpRoute($, RouteNames.parentExams);
      await waitForLoadingToClear($);
      await scrollTap($, 'Results');
      await assertVisibleText($, 'Unit Test — Mathematics');
    },
  );
}
