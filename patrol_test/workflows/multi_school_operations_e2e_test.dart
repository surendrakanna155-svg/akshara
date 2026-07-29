import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: multi-school operations activate and onboarding',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.multiSchoolPortfolio);

      await assertVisibleKey($, QaTestKeys.multiSchoolPortfolioScreen);
      await $(QaTestKeys.multiSchoolDismissAlertButton('msa_alert_1'))
          .scrollTo()
          .tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey($, QaTestKeys.multiSchoolAlertDismissedSnackbar);

      await $(QaTestKeys.multiSchoolOnboardingCta).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey($, QaTestKeys.multiSchoolOnboardingWizardScreen);

      await $(QaTestKeys.multiSchoolOnboardingSchoolNameField)
          .enterText('NIKSHA North Campus');
      await $(QaTestKeys.multiSchoolOnboardingContactNameField)
          .enterText('Admin User');
      await $(QaTestKeys.multiSchoolOnboardingContactEmailField)
          .enterText('admin@akshara.edu');
      await $('Continue').tap();
      await $('Continue').tap();
      await $(QaTestKeys.multiSchoolOnboardingSubmitButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey(
          $, QaTestKeys.multiSchoolOnboardingCompletedSnackbar);
    },
  );
}
