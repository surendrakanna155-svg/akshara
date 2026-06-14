import 'package:akshara_erp/core/repositories/mock/mock_hr_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_hr_write_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/education/education_models.dart';
import 'package:akshara_erp/features/education/education_provider.dart';
import 'package:akshara_erp/features/hr/hr_models.dart';
import 'package:akshara_erp/features/hr/hr_mutations_provider.dart';
import 'package:akshara_erp/features/hr/hr_requests.dart';
import 'package:akshara_erp/features/inventory/inventory_mutations_provider.dart';
import 'package:akshara_erp/features/inventory/intelligence/inventory_intelligence_models.dart';
import 'package:akshara_erp/features/transport/transport_models.dart';
import 'package:akshara_erp/features/transport/transport_mutations_provider.dart';
import 'package:akshara_erp/features/transport/transport_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

/// End-to-end mock workflow chain for Phase 1 completion modules (no UI).
void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  setUp(() {
    MockHrWriteStore.instance.reset();
  });

  const query = RepositoryQuery.demo;

  group('Phase 1 mock workflow integration', () {
    test('HR: process payroll run draft to processed', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(processHrPayrollRunProvider.notifier).execute(
            const ProcessHrPayrollRunRequest(runId: 'pay_run_2'),
          );

      final run = container.read(processHrPayrollRunProvider).value;
      expect(run?.status, HrPayrollStatus.processed);

      final repo = MockHrRepository();
      final payroll = await repo.getPayroll(query: query);
      expect(
        payroll.runs.firstWhere((r) => r.id == 'pay_run_2').status,
        HrPayrollStatus.processed,
      );
    });

    test('Inventory: record lifecycle event via mutation provider', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(recordAssetLifecycleEventProvider.notifier).execute(
            const RecordAssetLifecycleEventRequest(
              assetId: 'asset_qa',
              assetTag: 'INV-QA-999',
              eventType: AssetLifecycleEventType.purchase,
              notes: 'Integration test event',
            ),
          );

      expect(container.read(recordAssetLifecycleEventProvider).hasValue, isTrue);
      expect(
        container.read(recordAssetLifecycleEventProvider).value?.assetId,
        'asset_qa',
      );
    });

    test('Transport: create draft route then activate', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final route = await container
          .read(createTransportRouteProvider.notifier)
          .execute(const CreateTransportRouteRequest(name: 'Integration Route'));
      expect(route?.status, TransportRouteStatus.draft);

      final activated = await container
          .read(activateTransportRouteProvider.notifier)
          .execute(ActivateTransportRouteRequest(routeId: route!.id));

      expect(activated?.status, TransportRouteStatus.active);
    });

    test('Education: generate remark then publish with RBAC', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final remark = await container
          .read(educationMutationsProvider.notifier)
          .generateRemark(
            const GenerateReportRemarkRequest(
              studentId: 'student_int_1',
              academicYearLabel: '2025-26',
              remarkType: EduRemarkType.classTeacher,
              language: EduRemarkLanguage.english,
              inputs: ReportRemarkInputs(
                attendancePercent: 88,
                averageMarks: 72,
                strengths: ['discipline'],
                weaknesses: [],
                activities: [],
              ),
            ),
          );
      expect(remark.status, 'draft');

      final published = await container
          .read(educationMutationsProvider.notifier)
          .publishRemark(remark.id);
      expect(published.status, 'published');
    });
  });
}
