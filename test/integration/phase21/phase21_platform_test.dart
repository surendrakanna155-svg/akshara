import 'package:akshara_erp/core/repositories/mock/mock_school_completion_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_timetable_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/academics/timetable/timetable_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 21 platform hardening (mock)', () {
    const query = RepositoryQuery.demo;

    test('parent activation dashboard metrics', () async {
      final repo = MockSchoolCompletionRepository();
      final stats = await repo.getParentActivationDashboard(query: query);
      expect(stats.activationRate, greaterThan(0));
      expect(stats.dailyActiveParents, greaterThan(0));
      expect(stats.monthlyActiveParents, greaterThan(0));
    });

    test('room allocation returns lab assignments', () async {
      final repo = MockSchoolCompletionRepository();
      final result = await repo.allocateRooms(query: query, academicYearId: 'year_1');
      expect(result.labAssignments, greaterThan(0));
    });

    test('timetable period move updates slot', () async {
      final repo = MockTimetableRepository();
      const periodId = 'period_tt_mock_2_1';
      final moved = await repo.movePeriod(
        query: query,
        request: const MoveTimetablePeriodRequest(
          periodId: periodId,
          targetDayOfWeek: 2,
          targetPeriodNumber: 3,
        ),
      );
      expect(moved.dayOfWeek, 2);
      expect(moved.periodNumber, 3);
    });
  });
}
