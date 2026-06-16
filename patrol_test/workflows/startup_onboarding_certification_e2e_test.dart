import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/onboarding/startup_onboarding_provision_store.dart';
import 'package:akshara_erp/core/onboarding/tenant_onboarding_store.dart';
import 'package:akshara_erp/core/tenant/tenant_context.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/features/onboarding/unified_onboarding_models.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  final demoTenantId = TenantContext.demo.tenantId;

  Future<void> resetOnboardingState() async {
    TenantOnboardingStore.instance.reset(demoTenantId);
    StartupOnboardingProvisionStore.instance.reset(demoTenantId);
  }

  Future<void> waitForOnboardingReady(PatrolIntegrationTester $) async {
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));
    await assertVisibleText($, 'School setup · School Profile');
  }

  Future<void> fillSchoolProfile(PatrolIntegrationTester $) async {
    await enterLabeledField($, 'School name', 'Patrol Certification School');
    await enterLabeledField($, 'Address', '42 QA Automation Road');
    await enterLabeledField($, 'Contact phone', '9876500001');
    await enterLabeledField($, 'Contact email', 'admin@patrol-cert.test');
    await $.pumpAndSettle(timeout: const Duration(seconds: 5));
  }

  Future<void> tapContinue(PatrolIntegrationTester $) async {
    await tapByKey($, QaTestKeys.unifiedOnboardingContinueButton);
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  }

  patrolTest(
    'certification: startup onboarding completes go-live with provisioning',
    config: aksharaPatrolConfig(),
    ($) async {
      await resetOnboardingState();
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.unifiedOnboarding);
      await assertVisibleKey($, QaTestKeys.unifiedOnboardingScreen);
      await waitForOnboardingReady($);

      await fillSchoolProfile($);
      for (var step = 0; step < 7; step++) {
        await tapContinue($);
      }

      await assertVisibleText($, 'School setup · Review');
      await tapByKey($, QaTestKeys.unifiedOnboardingGoLiveButton);
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));

      await assertVisibleKey($, QaTestKeys.unifiedOnboardingGoLiveSuccess);
      await assertVisibleText($, 'School is live. All admins see this configuration.');
      await assertVisibleKey($, QaTestKeys.unifiedOnboardingProvisionSummary);

      final provision = StartupOnboardingProvisionStore.instance.read(demoTenantId);
      expect(provision, isNotNull);
      expect(provision!.provisioned, isTrue);
      expect(provision.classCount, greaterThan(0));
      expect(provision.sectionCount, greaterThan(0));
      expect(provision.feeStructureCount, greaterThan(0));
    },
  );

  patrolTest(
    'certification: startup onboarding resumes after logout without data loss',
    config: aksharaPatrolConfig(),
    ($) async {
      await resetOnboardingState();
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.unifiedOnboarding);
      await waitForOnboardingReady($);
      await fillSchoolProfile($);
      await tapContinue($); // curriculum
      await tapContinue($); // academic structure
      await tapContinue($); // fees
      await tapContinue($); // branding
      await assertVisibleText($, 'School setup · Branding');

      await goToErpRoute($, RouteNames.admin);
      await assertVisibleKey($, QaTestKeys.adminHubScreen);
      await $(QaTestKeys.profileButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await tapByKey($, QaTestKeys.logoutButton, scrollFirst: false);
      await $(QaTestKeys.logoutConfirmButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      expect($(QaTestKeys.qaLoginScreen), findsOneWidget);

      await loginAsQaPersona($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.unifiedOnboarding);
      await assertVisibleText($, 'School setup · Branding');
      final resumed = TenantOnboardingStore.instance.load(demoTenantId);
      expect(resumed.schoolName, 'Patrol Certification School');
      expect(resumed.currentStep, UnifiedOnboardingStep.branding);
    },
  );
}
