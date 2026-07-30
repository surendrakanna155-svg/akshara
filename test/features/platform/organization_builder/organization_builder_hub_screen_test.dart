import 'package:akshara_erp/core/repositories/interfaces/organization_builder_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/platform/organization_builder/organization_builder_hub_screen.dart';
import 'package:akshara_erp/features/platform/organization_builder/organization_builder_models.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

class _FakeOrganizationBuilderRepository
    implements OrganizationBuilderRepository {
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
      VerticalPack(
        id: 'pack_salon',
        type: VerticalPackType.salon,
        name: 'Salon',
        description: 'Salon pack',
        primaryEntities: ['Clients'],
        moduleSeeds: ['Appointments'],
        dashboardFocus: 'Revenue',
      ),
    ];
  }

  @override
  Future<List<InterviewDraft>> listInterviewDrafts({
    required RepositoryQuery query,
  }) async {
    return [
      InterviewDraft(
        id: 'draft_existing_1',
        packId: 'pack_salon',
        organizationName: 'Velora Downtown',
        currentStep: 3,
        answers: const {},
        recommendations: const [],
        status: InterviewDraftStatus.inProgress,
        createdAt: DateTime(2026, 6, 10),
        updatedAt: DateTime(2026, 6, 12),
      ),
    ];
  }

  @override
  Future<InterviewDraft> getInterviewDraft({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    return InterviewDraft(
      id: draftId,
      packId: 'pack_school',
      organizationName: 'Test School',
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
    return getInterviewDraft(query: query, draftId: draftId);
  }

  @override
  Future<ConfigPreview> generatePreview({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    return ConfigPreview(
      draftId: draftId,
      organizationName: 'Test School',
      packId: 'pack_school',
      modules: const [
        ConfigModuleItem(
          id: kUniversalEmployeeModuleId,
          name: 'Universal Employee',
          enabled: true,
          isNew: true,
        ),
      ],
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
      organizationName: 'Test School',
      status: ProvisioningJobStatus.running,
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
      organizationName: 'Test School',
      status: ProvisioningJobStatus.completed,
      steps: const [],
      startedAt: DateTime(2026, 6, 1),
      completedAt: DateTime(2026, 6, 1),
    );
  }
}

void main() {
  Future<void> pumpHub(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          organizationBuilderRepositoryProvider
              .overrideWithValue(_FakeOrganizationBuilderRepository()),
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
          home: const OrganizationBuilderHubScreen(),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('renders vertical packs and interview drafts', (tester) async {
    await pumpHub(tester);

    expect(find.byKey(QaTestKeys.organizationBuilderHubScreen), findsOneWidget);
    expect(find.text('Education'), findsOneWidget);
    // NIKSHA is education-only: the salon/hospital/restaurant packs are gated
    // out of the picker even when the repository returns them (hide-first).
    expect(find.text('Salon'), findsNothing);
    // Existing interview drafts are NOT gated — only the pack picker is — so a
    // previously-started (non-school) draft still surfaces in the drafts list.
    expect(find.text('Velora Downtown'), findsOneWidget);
    expect(find.byKey(QaTestKeys.organizationBuilderSchoolSetupLink), findsOneWidget);
  });
}
