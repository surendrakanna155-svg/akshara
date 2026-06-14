import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: growth campaigns admin actions',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpModuleRoute(
        $,
        QaLoginPersona.superAdmin,
        RouteNames.growthPlatform,
        screenKey: QaTestKeys.growthPlatformScreen,
        workflowAnchor: 'Admissions Growth',
      );

      await assertVisibleText($, 'Campaigns');
      await $('Campaigns').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await $(QaTestKeys.growthCreateCampaignButton).scrollTo().tap();
      await $(QaTestKeys.growthCampaignNameField).enterText('Monsoon Drive');
      await $(QaTestKeys.growthCampaignChannelField).enterText('facebook');
      await $(QaTestKeys.growthCampaignBudgetField).enterText('18000');
      await $(QaTestKeys.growthCampaignAudienceField).enterText('grade_1_parents');
      await $(QaTestKeys.growthCampaignCreateSubmitButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await $('Inquiries').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await $(QaTestKeys.growthConvertInquiryButton('inq_1')).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleText($, 'lead lead_inq_1');
    },
  );
}
