import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: sis profile edit and upload document',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'sis');
      await tapModuleSubNav($, 'sis', 'Student Registry');
      await tapByKey($, QaTestKeys.sisRegistryStudentRow('Arjun Patel'));
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await tapByKey($, QaTestKeys.sisEditProfileButton);
      await tapByKey($, QaTestKeys.sisEditProfileSaveButton, scrollFirst: false);
      await assertVisibleText($, 'Student profile updated');

      await tapByKey($, QaTestKeys.sisUploadDocumentButton);
      await tapByKey($, QaTestKeys.sisUploadDocumentSubmitButton, scrollFirst: false);
      await assertVisibleKey($, QaTestKeys.sisDocumentUploadSuccessSnackbar);
    },
  );
}
