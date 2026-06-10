import 'package:akshara_erp/core/repositories/api/timetable/api_timetable_repository.dart';
import 'package:akshara_erp/core/repositories/api/timetable/dto/timetable_dto.dart';
import 'package:akshara_erp/core/repositories/api/timetable/mapper/timetable_mapper.dart';
import 'package:akshara_erp/core/repositories/api/timetable/remote/timetable_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/timetable_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_timetable_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
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
  });
}
