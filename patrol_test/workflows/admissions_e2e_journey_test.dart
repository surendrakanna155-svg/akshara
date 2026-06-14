import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/admissions_journey_helpers.dart';
import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

/// Full ERP admission business journey (mock mode):
/// Lead → Application → Enrollment → Approval → SIS conversion → Registry.
void main() {
  patrolTest(
    'journey: admissions lead to SIS registry E2E',
    config: aksharaPatrolConfig(),
    ($) async {
      const parentName = 'Patrol E2E Parent';
      const phone = '9876501234';
      final studentName = uniqueE2eStudentName();

      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await openErpDrawer($);
      await $(QaTestKeys.erpNavModule('admissions')).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));

      // 1. Lead
      await tapModuleSubNav($, 'admissions', 'Leads');
      await createLeadViaDialog(
        $,
        parentName: parentName,
        studentName: studentName,
        phone: phone,
      );

      // 2. Application (linked to last lead)
      await tapModuleSubNav($, 'admissions', 'Applications');
      await createAndSubmitApplication($);

      // 3. Enrollment
      await tapModuleSubNav($, 'admissions', 'Enrollment');
      await completeEnrollmentWizard($);

      // 4. Approval
      await tapModuleSubNav($, 'admissions', 'Approval');
      await approveEnrollmentForStudent($, studentName);

      // 5. SIS conversion
      await openErpDrawer($);
      await $(QaTestKeys.erpNavModule('sis')).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
      await tapModuleSubNav($, 'sis', 'Admissions Conversion');
      await convertEnrollmentForStudent($, studentName);

      // 6. Registry verification
      await tapModuleSubNav($, 'sis', 'Student Registry');
      await verifyStudentInRegistry($, studentName);

      // 7. Finance handoff verification (linked candidate)
      await openErpDrawer($);
      await $(QaTestKeys.erpNavModule('finance')).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
      await tapModuleSubNav($, 'finance', 'Fee Assignment');
      await verifyStudentInFeeHandoffQueue($, studentName);
    },
  );
}
