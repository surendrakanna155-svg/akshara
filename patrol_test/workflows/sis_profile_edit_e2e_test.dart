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
      await $(QaTestKeys.sisRegistryStudentRow('Arjun Patel')).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await $(QaTestKeys.sisEditProfileButton).scrollTo().tap();
      await $(QaTestKeys.sisEditProfileSaveButton).tap();
      await assertVisibleText($, 'Student profile updated');

      await $(QaTestKeys.sisUploadDocumentButton).scrollTo().tap();
      await $(QaTestKeys.sisUploadDocumentSubmitButton).tap();
      await assertVisibleKey($, QaTestKeys.sisDocumentUploadSuccessSnackbar);
    },
  );
}
