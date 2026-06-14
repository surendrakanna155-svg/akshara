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

    test('createHrEmployee fails without manageHr permission', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createHrEmployeeProvider.notifier).execute(
            const CreateHrEmployeeRequest(
              name: 'QA Staff',
              employeeCode: 'EMP-900',
              department: HrDepartment.administration,
              role: HrEmployeeRole.staff,
              designation: 'Office Assistant',
              email: 'qa@akshara.edu',
              phone: '+91 90000 11122',
            ),
          );

      expect(container.read(createHrEmployeeProvider).hasError, isTrue);
    });

    test('createHrEmployee succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createHrEmployeeProvider.notifier).execute(
            const CreateHrEmployeeRequest(
              name: 'QA Staff',
              employeeCode: 'EMP-900',
              department: HrDepartment.administration,
              role: HrEmployeeRole.staff,
              designation: 'Office Assistant',
              email: 'qa@akshara.edu',
              phone: '+91 90000 11122',
            ),
          );

      expect(container.read(createHrEmployeeProvider).hasValue, isTrue);
      expect(
        container.read(createHrEmployeeProvider).value?.employeeCode,
        'EMP-900',
      );
    });

    test('updateHrEmployee fails without manageHr permission', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(updateHrEmployeeProvider.notifier).execute(
            const UpdateHrEmployeeRequest(
              employeeId: 'HR-EMP-102',
              name: 'Mrs. Rao Updated',
              designation: 'English Teacher',
              phone: '+91 98765 43211',
              department: HrDepartment.academics,
            ),
          );

      expect(container.read(updateHrEmployeeProvider).hasError, isTrue);
    });

    test('setHrEmployeeStatus fails without manageHr permission', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(setHrEmployeeStatusProvider.notifier).execute(
            const SetHrEmployeeStatusRequest(
              employeeId: 'HR-EMP-102',
              status: HrEmployeeStatus.inactive,
            ),
          );

      expect(container.read(setHrEmployeeStatusProvider).hasError, isTrue);
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

  group('HR mock employee writes', () {
    test('createEmployee adds probation employee to registry', () async {
      MockHrWriteStore.instance.reset();
      final repo = MockHrRepository();
      const query = RepositoryQuery.demo;

      final before = await repo.getEmployees(query: query);
      final created = await repo.createEmployee(
        query: query,
        request: const CreateHrEmployeeRequest(
          name: 'QA Staff',
          employeeCode: 'EMP-900',
          department: HrDepartment.administration,
          role: HrEmployeeRole.staff,
          designation: 'Office Assistant',
          email: 'qa@akshara.edu',
          phone: '+91 90000 11122',
        ),
      );

      expect(created.status, HrEmployeeStatus.probation);
      final after = await repo.getEmployees(query: query);
      expect(after.items.length, before.items.length + 1);
      expect(after.items.first.employeeCode, 'EMP-900');
    });

    test('updateEmployee updates profile fields', () async {
      MockHrWriteStore.instance.reset();
      final repo = MockHrRepository();
      const query = RepositoryQuery.demo;

      final updated = await repo.updateEmployee(
        query: query,
        request: const UpdateHrEmployeeRequest(
          employeeId: 'HR-EMP-102',
          name: 'Mrs. Rao Updated',
          designation: 'Senior English Teacher',
          phone: '+91 90000 00000',
          department: HrDepartment.academics,
        ),
      );

      expect(updated.name, 'Mrs. Rao Updated');
      expect(updated.designation, 'Senior English Teacher');

      final detail = await repo.getEmployeeDetail(
        query: query,
        employeeId: 'HR-EMP-102',
      );
      expect(detail?.employee.name, 'Mrs. Rao Updated');
    });

    test('setEmployeeStatus toggles active and inactive', () async {
      MockHrWriteStore.instance.reset();
      final repo = MockHrRepository();
      const query = RepositoryQuery.demo;

      final deactivated = await repo.setEmployeeStatus(
        query: query,
        request: const SetHrEmployeeStatusRequest(
          employeeId: 'HR-EMP-102',
          status: HrEmployeeStatus.inactive,
        ),
      );
      expect(deactivated.status, HrEmployeeStatus.inactive);

      final reactivated = await repo.setEmployeeStatus(
        query: query,
        request: const SetHrEmployeeStatusRequest(
          employeeId: 'HR-EMP-102',
          status: HrEmployeeStatus.active,
        ),
      );
      expect(reactivated.status, HrEmployeeStatus.active);
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
