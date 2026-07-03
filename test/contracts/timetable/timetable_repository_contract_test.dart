import 'package:akshara_erp/core/repositories/api/timetable/api_timetable_repository.dart';
import 'package:akshara_erp/core/repositories/api/timetable/dto/timetable_dto.dart';
import 'package:akshara_erp/core/repositories/api/timetable/mapper/timetable_mapper.dart';
import 'package:akshara_erp/core/repositories/api/timetable/remote/timetable_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/timetable_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_timetable_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/academics/timetable/timetable_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'timetable_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
final _fixtures = TimetableFixtureBuilder();
const _mapper = TimetableMapper();

void main() {
  group('Timetable repository contract', () {
    late MockTimetableRepository mockRepo;
    late ApiTimetableRepository apiRepo;

    setUp(() {
      mockRepo = MockTimetableRepository();
      apiRepo = ApiTimetableRepository(
        remote: TimetableRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement TimetableRepository', () {
      expect(mockRepo, isA<TimetableRepository>());
      expect(apiRepo, isA<TimetableRepository>());
    });

    test('summary DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getSummary(
        query: kQuery,
        academicYearId: 'mock-year-current',
      );
      final mapped = _mapper.toSummary(
        TimetableSummaryDto.fromJson(_fixtures.summaryEnvelope(mockData)['data'] as Map<String, dynamic>),
      );
      expect(mapped.totalTimetables, mockData.totalTimetables);
      expect(mapped.conflictCount, mockData.conflictCount);
    });

    test('entry DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getTimetables(query: kQuery);
      final mapped = _mapper.toEntry(
        TimetableEntryDto.fromJson(
          (_fixtures.entriesEnvelope(mockData)['data'] as Map<String, dynamic>)['items']
              .first as Map<String, dynamic>,
        ),
      );
      expect(mapped.id, mockData.first.id);
      expect(mapped.status, mockData.first.status);
    });

    test('workload DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getWorkload(
        query: kQuery,
        academicYearId: 'mock-year-current',
      );
      final mapped = _mapper.toWorkload(
        TeacherWorkloadDto.fromJson(
          (_fixtures.workloadEnvelope(mockData)['data'] as Map<String, dynamic>)['items']
              .first as Map<String, dynamic>,
        ),
      );
      expect(mapped.teacherName, mockData.first.teacherName);
      expect(mapped.isOverloaded, mockData.first.isOverloaded);
    });

    test('workload-rollup DTO mapping matches mock output (gap #9)', () async {
      final mockData = await mockRepo.getWorkloadRollup(
        query: kQuery,
        academicYearId: 'mock-year-current',
      );
      final data = _fixtures.workloadRollupEnvelope(mockData)['data']
          as Map<String, dynamic>;
      final mapped = _mapper.toWorkloadRollup(WorkloadRollupDto.fromJson(data));

      // Per-teacher rows: names, populated sections/subjects, status all survive.
      expect(mapped.teachers, hasLength(mockData.teachers.length));
      final over = mapped.teachers.firstWhere((t) => t.status == TeacherWorkloadStatus.over);
      expect(over.teacherName, 'Staging Teacher A');
      expect(over.isOverloaded, isTrue);
      expect(over.periodCount, 28);
      expect(over.sections, isNotEmpty);
      expect(over.subjectIds, isNotEmpty);
      expect(
        mapped.teachers.any((t) => t.status == TeacherWorkloadStatus.under),
        isTrue,
      );
      expect(
        mapped.teachers.any((t) => t.status == TeacherWorkloadStatus.balanced),
        isTrue,
      );

      // Summary aggregate round-trips including the fractional average.
      expect(mapped.summary.totalTeachers, mockData.summary.totalTeachers);
      expect(mapped.summary.overloaded, mockData.summary.overloaded);
      expect(mapped.summary.underloaded, mockData.summary.underloaded);
      expect(mapped.summary.balanced, mockData.summary.balanced);
      expect(mapped.summary.avgPeriods, mockData.summary.avgPeriods);
    });

    test('mock and api implement getWorkloadRollup (gap #9)', () {
      expect(mockRepo.getWorkloadRollup, isA<Function>());
      expect(apiRepo.getWorkloadRollup, isA<Function>());
    });

    test('mock and api implement the substitution methods', () {
      expect(mockRepo.listSubstitutions, isA<Function>());
      expect(apiRepo.listSubstitutions, isA<Function>());
      expect(mockRepo.createSubstitution, isA<Function>());
      expect(apiRepo.createSubstitution, isA<Function>());
      expect(mockRepo.deleteSubstitution, isA<Function>());
      expect(apiRepo.deleteSubstitution, isA<Function>());
    });

    test('daily-substitutions DTO tolerates the camelCase list shape', () {
      const bundle = DailySubstitutionsBundle(
        date: '2026-07-03',
        substitutions: [
          TimetableSubstitution(
            id: 'sub_1',
            periodId: 'period_x',
            subDate: '2026-07-03',
            originalTeacherId: 'HR-EMP-101',
            substituteTeacherId: 'HR-EMP-102',
            reason: 'sick',
            dayOfWeek: 5,
            periodNumber: 2,
            subjectLabel: 'Science',
            roomLabel: 'Lab 1',
          ),
        ],
        onLeave: [TimetableTeacherOnLeave(teacherId: 'HR-EMP-101')],
      );
      final data = _fixtures.dailySubstitutionsEnvelope(bundle)['data']
          as Map<String, dynamic>;
      final mapped = _mapper.toDailyBundle(DailySubstitutionsDto.fromJson(data));
      expect(mapped.date, '2026-07-03');
      expect(mapped.substitutions.single.periodNumber, 2);
      expect(mapped.substitutions.single.substituteTeacherId, 'HR-EMP-102');
      expect(mapped.onLeave.single.teacherId, 'HR-EMP-101');
    });

    test('create-substitution DTO tolerates the snake_case row shape', () {
      const created = TimetableSubstitution(
        id: 'sub_9',
        periodId: 'period_y',
        subDate: '2026-07-03',
        originalTeacherId: 'HR-EMP-101',
        substituteTeacherId: 'HR-EMP-103',
        reason: 'leave',
      );
      final row = (_fixtures.createSubstitutionEnvelope(created)['data']
          as Map<String, dynamic>)['substitution'] as Map<String, dynamic>;
      final mapped = _mapper.toSubstitution(TimetableSubstitutionDto.fromJson(row));
      expect(mapped.id, 'sub_9');
      expect(mapped.periodId, 'period_y');
      expect(mapped.substituteTeacherId, 'HR-EMP-103');
    });

    test('mock create/list/delete round-trips a substitution', () async {
      final created = await mockRepo.createSubstitution(
        query: kQuery,
        request: const CreateSubstitutionRequest(
          periodId: 'period_tt_mock_1_1',
          subDate: '2026-07-03',
          substituteTeacherId: 'sub-teacher-1',
        ),
      );
      final listed = await mockRepo.listSubstitutions(
        query: kQuery,
        date: '2026-07-03',
      );
      expect(listed.substitutions.map((s) => s.id), contains(created.id));

      await mockRepo.deleteSubstitution(query: kQuery, id: created.id);
      final afterDelete = await mockRepo.listSubstitutions(
        query: kQuery,
        date: '2026-07-03',
      );
      expect(afterDelete.substitutions.map((s) => s.id), isNot(contains(created.id)));
    });
  });
}
