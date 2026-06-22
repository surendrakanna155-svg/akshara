import 'package:akshara_erp/core/repositories/interfaces/multi_school_operations_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/platform/multi_school/multi_school_models.dart';
import 'package:akshara_erp/features/platform/multi_school/school_onboarding_wizard_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

class _FakeWizardRepository implements MultiSchoolOperationsRepository {
  @override
  Future<SchoolOnboardingDraft> createOnboardingDraft({
    required RepositoryQuery query,
    required SchoolOnboardingDraft draft,
  }) async {
    return draft;
  }

  @override
  Future<SchoolLifecycleRecord> submitOnboarding({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    return SchoolLifecycleRecord(
      schoolId: 'sch_new',
      schoolName: 'New School',
      status: SchoolLifecycleStatus.active,
      planName: 'Growth',
      region: 'India',
      healthScore: const SchoolHealthScore(
        schoolId: 'sch_new',
        score: 70,
        band: 'Healthy',
        factors: ['onboarded'],
      ),
      studentsCount: 600,
      staffCount: 60,
      updatedAt: DateTime(2026, 6, 1),
    );
  }

  @override
  Future<SchoolLifecycleRecord> activateSchool({
    required RepositoryQuery query,
    required String schoolId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PortfolioAction> completeAction({
    required RepositoryQuery query,
    required String actionId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SchoolLifecycleRecord> deactivateSchool({
    required RepositoryQuery query,
    required String schoolId,
    String? reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> dismissAlert({
    required RepositoryQuery query,
    required String alertId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SchoolPortfolioDashboard> getPortfolioDashboard({
    required RepositoryQuery query,
  }) async {
    return const SchoolPortfolioDashboard(
      kpis: [],
      alerts: [],
      schools: [],
      pendingActions: [],
    );
  }

  @override
  Future<SchoolHealthScore> getSchoolHealth({
    required RepositoryQuery query,
    required String schoolId,
  }) async {
    return SchoolHealthScore(
      schoolId: schoolId,
      score: 70,
      band: 'Healthy',
      factors: const ['onboarded'],
    );
  }

  @override
  Future<List<PortfolioAlert>> listAlerts({required RepositoryQuery query}) async {
    return const [];
  }

  @override
  Future<List<PortfolioAction>> listPendingActions({
    required RepositoryQuery query,
  }) async {
    return const [];
  }

  @override
  Future<List<SchoolLifecycleRecord>> listSchools({
    required RepositoryQuery query,
    SchoolLifecycleStatus? status,
  }) async {
    return const [];
  }
}

void main() {
  testWidgets('completes onboarding wizard', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          multiSchoolOperationsRepositoryProvider
              .overrideWithValue(_FakeWizardRepository()),
          repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const Scaffold(
            body: SchoolOnboardingWizardScreen(),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(QaTestKeys.multiSchoolOnboardingSchoolNameField),
      'Akshara East',
    );
    await tester.enterText(
      find.byKey(QaTestKeys.multiSchoolOnboardingContactNameField),
      'Priya',
    );
    await tester.enterText(
      find.byKey(QaTestKeys.multiSchoolOnboardingContactEmailField),
      'priya@akshara.edu',
    );
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(QaTestKeys.multiSchoolOnboardingContinueButton),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(QaTestKeys.multiSchoolOnboardingContinueButton),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(QaTestKeys.multiSchoolOnboardingSubmitButton));
    await tester.pump();
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();

    expect(
      find.byKey(QaTestKeys.multiSchoolOnboardingCompletedSnackbar),
      findsOneWidget,
    );
  });
}
