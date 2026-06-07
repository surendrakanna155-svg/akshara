import 'package:akshara_erp/features/hostel/hostel_models.dart';
import 'package:akshara_erp/features/hostel/hostel_providers.dart';
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

  group('Hostel providers', () {
    test('hostelDashboardProvider returns dashboard data', () async {      await container.read(hostelDashboardFutureProvider.future);

      final data = container.read(hostelDashboardProvider);

      expect(data, isNotNull);
      expect(data!.kpis, hasLength(6));
      expect(data.blockOccupancy, isNotEmpty);
    });

    test('hostelDashboardProvider returns null when loading', () async {
      container = createProviderTestContainer(
        overrides: [
          hostelDashboardLoadingProvider.overrideWith((ref) => true),
        ],
      );

      expect(container.read(hostelDashboardProvider), isNull);
    });

    test('hostelStudentsProvider returns SIS-linked students', () async {      await container.read(hostelStudentsFutureProvider.future);

      final students = container.read(hostelStudentsProvider);

      expect(students, isNotNull);
      expect(students!, hasLength(4));
      expect(students.first.sisStudentId, startsWith('SIS-STU-'));
    });

    test('hostelFilteredStudentsProvider filters residents', () async {
      container = createProviderTestContainer(
        overrides: [
          hostelStudentsFilterProvider.overrideWith((ref) => 1),
        ],
      );

      final filtered = container.read(hostelFilteredStudentsProvider);
      expect(
        filtered.every((s) => s.status == HostelStudentStatus.resident),
        isTrue,
      );
    });

    test('hostelRoomsProvider returns rooms', () async {      await container.read(hostelRoomsFutureProvider.future);

      final rooms = container.read(hostelRoomsProvider);

      expect(rooms, isNotNull);
      expect(rooms!, hasLength(5));
    });

    test('hostelFilteredRoomsProvider filters vacant rooms', () async {
      container = createProviderTestContainer(
        overrides: [
          hostelRoomsFilterProvider.overrideWith((ref) => 2),
        ],
      );

      final filtered = container.read(hostelFilteredRoomsProvider);
      expect(
        filtered.every((r) => r.status == HostelRoomStatus.vacant),
        isTrue,
      );
    });

    test('hostelAttendanceProvider returns attendance records', () async {      await container.read(hostelAttendanceFutureProvider.future);

      final records = container.read(hostelAttendanceProvider);

      expect(records, isNotNull);
      expect(records!, hasLength(4));
    });

    test('hostelFilteredAttendanceProvider filters absent', () async {
      container = createProviderTestContainer(
        overrides: [
          hostelAttendanceFilterProvider.overrideWith((ref) => 2),
        ],
      );

      final filtered = container.read(hostelFilteredAttendanceProvider);
      expect(
        filtered.every((r) => r.overallStatus == HostelAttendanceStatus.absent),
        isTrue,
      );
    });

    test('hostelLeaveProvider returns leave requests', () async {      await container.read(hostelLeaveFutureProvider.future);

      final requests = container.read(hostelLeaveProvider);

      expect(requests, isNotNull);
      expect(requests!, hasLength(4));
    });

    test('hostelFilteredLeaveProvider filters pending', () async {
      container = createProviderTestContainer(
        overrides: [
          hostelLeaveFilterProvider.overrideWith((ref) => 1),
        ],
      );

      final filtered = container.read(hostelFilteredLeaveProvider);
      expect(
        filtered.every((r) => r.status == HostelLeaveStatus.pending),
        isTrue,
      );
    });

    test('hostelMessProvider returns mess data', () async {      await container.read(hostelMessFutureProvider.future);

      final data = container.read(hostelMessProvider);

      expect(data, isNotNull);
      expect(data!.weeklyMenus, hasLength(4));
    });

    test('hostelVisitorsProvider returns visitor data', () async {      await container.read(hostelVisitorsFutureProvider.future);

      final data = container.read(hostelVisitorsProvider);

      expect(data, isNotNull);
      expect(data!.activeVisitors, hasLength(2));
    });

    test('hostelReportsProvider returns reports data', () async {      await container.read(hostelReportsFutureProvider.future);

      final data = container.read(hostelReportsProvider);

      expect(data, isNotNull);
      expect(data!.catalog, hasLength(6));
    });
  });
}
