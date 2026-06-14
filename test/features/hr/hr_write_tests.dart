import 'package:akshara_erp/core/repositories/mock/mock_hr_write_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_hr_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/hr/hr_models.dart';
import 'package:akshara_erp/features/hr/hr_mutations_provider.dart';
import 'package:akshara_erp/features/hr/hr_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  setUp(() {
    MockHrWriteStore.instance.reset();
  });

  group('HR RBAC mutations', () {
    test('createHrLeave fails without manageHr permission', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createHrLeaveProvider.notifier).execute(
            const CreateHrLeaveRequest(
              employeeId: 'HR-EMP-102',
              employeeName: 'Mrs. Rao',
              department: HrDepartment.academics,
              leaveType: HrLeaveType.casual,
              fromDate: '2026-06-15',
              toDate: '2026-06-15',
              days: 1,
              reason: 'Test',
            ),
          );

      expect(container.read(createHrLeaveProvider).hasError, isTrue);
    });

    test('createHrLeave succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createHrLeaveProvider.notifier).execute(
            const CreateHrLeaveRequest(
              employeeId: 'HR-EMP-102',
              employeeName: 'Mrs. Rao',
              department: HrDepartment.academics,
              leaveType: HrLeaveType.casual,
              fromDate: '2026-06-15',
              toDate: '2026-06-15',
              days: 1,
              reason: 'Test',
            ),
          );

      expect(container.read(createHrLeaveProvider).hasValue, isTrue);
      expect(container.read(createHrLeaveProvider).value?.employeeName, 'Mrs. Rao');
    });

    test('processHrPayrollRun fails without manageHr permission', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(processHrPayrollRunProvider.notifier).execute(
            const ProcessHrPayrollRunRequest(runId: 'pay_run_2'),
          );

      expect(container.read(processHrPayrollRunProvider).hasError, isTrue);
    });

    test('processHrPayrollRun succeeds for superAdmin', () async {
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

      expect(container.read(processHrPayrollRunProvider).hasValue, isTrue);
      expect(
        container.read(processHrPayrollRunProvider).value?.status,
        HrPayrollStatus.processed,
      );
    });
  });

  group('HR mock payroll writes', () {
    test('processPayrollRun updates draft run status', () async {
      MockHrWriteStore.instance.reset();
      final repo = MockHrRepository();
      const query = RepositoryQuery.demo;

      final before = await repo.getPayroll(query: query);
      expect(
        before.runs.firstWhere((r) => r.id == 'pay_run_2').status,
        HrPayrollStatus.draft,
      );

      final processed = await repo.processPayrollRun(
        query: query,
        request: const ProcessHrPayrollRunRequest(runId: 'pay_run_2'),
      );
      expect(processed.status, HrPayrollStatus.processed);

      final after = await repo.getPayroll(query: query);
      expect(
        after.runs.firstWhere((r) => r.id == 'pay_run_2').status,
        HrPayrollStatus.processed,
      );
    });
  });
}
