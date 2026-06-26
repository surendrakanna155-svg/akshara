import 'package:akshara_erp/core/repositories/interfaces/organization_builder_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/platform/organization_builder/organization_builder_models.dart';
import 'package:akshara_erp/features/platform/organization_builder/organization_provisioning_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

/// Fake repo that returns whatever terminal job it is constructed with, so the
/// provisioning screen's poll timer cancels on the first frame.
class _JobRepository implements OrganizationBuilderRepository {
  _JobRepository(this.job);

  final ProvisioningJob job;

  @override
  Future<ProvisioningJob> getProvisioningJob({
    required RepositoryQuery query,
    required String jobId,
  }) async {
    return job;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

ProvisioningJob _job(
  ProvisioningJobStatus status,
  List<ProvisioningStep> steps,
) {
  return ProvisioningJob(
    id: 'job_test',
    draftId: 'draft_test',
    organizationName: 'Acme Trust',
    status: status,
    steps: steps,
    startedAt: DateTime(2026, 6, 26),
    completedAt: DateTime(2026, 6, 26),
  );
}

void main() {
  Future<void> pump(WidgetTester tester, ProvisioningJob job) async {
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
              .overrideWithValue(_JobRepository(job)),
          repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const OrganizationProvisioningScreen(jobId: 'job_test'),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('completed job shows success terminal state', (tester) async {
    await pump(
      tester,
      _job(ProvisioningJobStatus.completed, const [
        ProvisioningStep(
          id: 'step_org',
          label: 'Create organization',
          status: ProvisioningStepStatus.completed,
        ),
      ]),
    );

    expect(
      find.byKey(QaTestKeys.organizationBuilderProvisioningCompleted),
      findsOneWidget,
    );
    expect(
      find.byKey(QaTestKeys.organizationBuilderProvisioningFailed),
      findsNothing,
    );
    expect(find.text('Organization provisioned successfully.'), findsOneWidget);
  });

  testWidgets('failed job shows distinct failed terminal state with the error',
      (tester) async {
    await pump(
      tester,
      _job(ProvisioningJobStatus.failed, const [
        ProvisioningStep(
          id: 'step_org',
          label: 'Create organization',
          status: ProvisioningStepStatus.skipped,
        ),
        ProvisioningStep(
          id: 'step_branch',
          label: 'Create branch',
          status: ProvisioningStepStatus.failed,
          error: 'duplicate key value violates unique constraint',
        ),
        ProvisioningStep(
          id: 'step_roles',
          label: 'Seed roles',
          status: ProvisioningStepStatus.pending,
        ),
      ]),
    );

    // The success copy must NOT appear on a failed job.
    expect(
      find.byKey(QaTestKeys.organizationBuilderProvisioningCompleted),
      findsNothing,
    );
    expect(find.text('Organization provisioned successfully.'), findsNothing);

    // A distinct failed terminal state surfaces the failing step + error.
    expect(
      find.byKey(QaTestKeys.organizationBuilderProvisioningFailed),
      findsOneWidget,
    );
    expect(find.text('Provisioning failed.'), findsOneWidget);
    expect(
      find.textContaining('duplicate key value violates unique constraint'),
      findsOneWidget,
    );
  });
}
