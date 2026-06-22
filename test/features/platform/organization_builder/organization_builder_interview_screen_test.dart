import 'package:akshara_erp/core/repositories/interfaces/organization_builder_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/platform/organization_builder/organization_builder_interview_screen.dart';
import 'package:akshara_erp/features/platform/organization_builder/organization_builder_models.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

class _FakeInterviewRepository implements OrganizationBuilderRepository {
  int savedSteps = 0;

  @override
  Future<List<VerticalPack>> listVerticalPacks({
    required RepositoryQuery query,
  }) async {
    return const [
      VerticalPack(
        id: 'pack_school',
        type: VerticalPackType.school,
        name: 'Education',
        description: 'School pack',
        primaryEntities: ['Students'],
        moduleSeeds: ['SIS'],
        dashboardFocus: 'Attendance',
      ),
    ];
  }

  @override
  Future<List<InterviewDraft>> listInterviewDrafts({
    required RepositoryQuery query,
  }) async {
    return const [];
  }

  @override
  Future<InterviewDraft> getInterviewDraft({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    return InterviewDraft(
      id: draftId,
      packId: 'pack_school',
      organizationName: '',
      currentStep: 0,
      answers: const {},
      recommendations: const [],
      status: InterviewDraftStatus.inProgress,
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );
  }

  @override
  Future<InterviewDraft> saveInterviewStep({
    required RepositoryQuery query,
    required String draftId,
    required int stepIndex,
    required Map<String, String> answers,
  }) async {
    savedSteps++;
    return InterviewDraft(
      id: draftId,
      packId: 'pack_school',
      organizationName: answers['identity_name'] ?? '',
      currentStep: stepIndex + 1,
      answers: answers,
      recommendations: const [],
      status: InterviewDraftStatus.inProgress,
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );
  }

  @override
  Future<ConfigPreview> generatePreview({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    return ConfigPreview(
      draftId: draftId,
      organizationName: 'Akshara Test',
      packId: 'pack_school',
      modules: const [],
      roles: const [],
      widgets: const [],
      workflows: const [],
      generatedAt: DateTime(2026, 6, 1),
    );
  }

  @override
  Future<ProvisioningJob> startProvisioning({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    return ProvisioningJob(
      id: 'job_test',
      draftId: draftId,
      organizationName: 'Akshara Test',
      status: ProvisioningJobStatus.pending,
      steps: const [],
      startedAt: DateTime(2026, 6, 1),
    );
  }

  @override
  Future<ProvisioningJob> getProvisioningJob({
    required RepositoryQuery query,
    required String jobId,
  }) async {
    return ProvisioningJob(
      id: jobId,
      draftId: 'draft_test',
      organizationName: 'Akshara Test',
      status: ProvisioningJobStatus.completed,
      steps: const [],
      startedAt: DateTime(2026, 6, 1),
    );
  }
}

void main() {
  late _FakeInterviewRepository fakeRepo;

  Future<void> pumpInterview(WidgetTester tester) async {
    fakeRepo = _FakeInterviewRepository();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          organizationBuilderRepositoryProvider.overrideWithValue(fakeRepo),
          repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
          rbacServiceProvider.overrideWithValue(
            RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
          ),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const OrganizationBuilderInterviewScreen(
            draftId: 'draft_widget_test',
            packId: 'pack_school',
          ),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('advances interview steps with fixed bottom actions', (
    tester,
  ) async {
    await pumpInterview(tester);

    expect(
      find.byKey(QaTestKeys.organizationBuilderInterviewScreen),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(QaTestKeys.organizationBuilderInterviewNameField),
      'Akshara North Campus',
    );
    await tester.tap(
      find.byKey(QaTestKeys.organizationBuilderInterviewContinueButton),
    );
    await tester.pumpAndSettle();

    expect(fakeRepo.savedSteps, 1);
    expect(find.text('Scale'), findsWidgets);
  });
}
