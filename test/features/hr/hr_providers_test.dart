import 'package:akshara_erp/features/hr/hr_models.dart';
import 'package:akshara_erp/features/hr/hr_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = createProviderTestContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('HR providers', () {
    test('hrDashboardProvider returns dashboard data', () async {
      await container.read(hrDashboardFutureProvider.future);
      final data = container.read(hrDashboardProvider);

      expect(data, isNotNull);
      expect(data!.kpis, hasLength(6));
      expect(data.pendingLeave, isNotEmpty);
    });

    test('hrDashboardProvider returns null when loading', () async {
      container.dispose();
      container = createProviderTestContainer(
        overrides: [
          hrDashboardLoadingProvider.overrideWith((ref) => true),
        ],
      );

      expect(container.read(hrDashboardProvider), isNull);
    });

    test('hrEmployeesProvider returns employees', () async {
      await container.read(hrEmployeesFutureProvider.future);
      final employees = container.read(hrEmployeesProvider);

      expect(employees, isNotNull);
      expect(employees!, hasLength(8));
    });

    test('hrFilteredEmployeesProvider filters teachers', () async {
      await container.read(hrEmployeesFutureProvider.future);
      container.dispose();
      container = createProviderTestContainer(
        overrides: [
          hrEmployeesFilterProvider.overrideWith((ref) => 3),
        ],
      );
      await container.read(hrEmployeesFutureProvider.future);

      final filtered = container.read(hrFilteredEmployeesProvider);
      expect(
        filtered.every((e) => e.role == HrEmployeeRole.teacher),
        isTrue,
      );
    });

    test('hrEmployeeDetailProvider returns profile for known id', () async {
      await container.read(
        hrEmployeeDetailFutureProvider('HR-EMP-101').future,
      );
      final detail = container.read(hrEmployeeDetailProvider('HR-EMP-101'));

      expect(detail, isNotNull);
      expect(detail!.employee.name, 'Priya Sharma');
      expect(detail.employee.teacherAppLinked, isTrue);
    });

    test('hrAttendanceProvider returns attendance data', () async {
      await container.read(hrAttendanceFutureProvider.future);
      final data = container.read(hrAttendanceProvider);

      expect(data, isNotNull);
      expect(data!.records, hasLength(6));
    });

    test('hrFilteredAttendanceProvider filters present', () async {
      await container.read(hrAttendanceFutureProvider.future);
      container.dispose();
      container = createProviderTestContainer(
        overrides: [
          hrAttendanceFilterProvider.overrideWith((ref) => 1),
        ],
      );
      await container.read(hrAttendanceFutureProvider.future);

      final filtered = container.read(hrFilteredAttendanceProvider);
      expect(
        filtered.every((r) => r.status == HrAttendanceStatus.present),
        isTrue,
      );
    });

    test('hrLeaveProvider returns leave data', () async {
      await container.read(hrLeaveFutureProvider.future);
      final data = container.read(hrLeaveProvider);

      expect(data, isNotNull);
      expect(data!.requests, hasLength(5));
    });

    test('hrPayrollProvider returns payroll data', () async {
      await container.read(hrPayrollFutureProvider.future);
      final data = container.read(hrPayrollProvider);

      expect(data, isNotNull);
      expect(data!.runs, hasLength(2));
      expect(data.entries, hasLength(4));
    });

    test('hrRecruitmentProvider returns recruitment data', () async {
      await container.read(hrRecruitmentFutureProvider.future);
      final data = container.read(hrRecruitmentProvider);

      expect(data, isNotNull);
      expect(data!.candidates, hasLength(5));
    });

    test('hrPerformanceProvider returns performance data', () async {
      await container.read(hrPerformanceFutureProvider.future);
      final data = container.read(hrPerformanceProvider);

      expect(data, isNotNull);
      expect(data!.reviews, hasLength(4));
    });

    test('hrSettingsProvider returns settings sections', () async {
      await container.read(hrSettingsFutureProvider.future);
      final data = container.read(hrSettingsProvider);

      expect(data, isNotNull);
      expect(data!.sections.length, greaterThan(3));
    });
  });
}
