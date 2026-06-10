import 'package:akshara_erp/core/repositories/api/timetable/api_timetable_repository.dart';
import 'package:akshara_erp/core/repositories/api/timetable/remote/timetable_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/timetable/remote/timetable_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_timetable_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/timetable/timetable_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';

const kQuery = RepositoryQuery.demo;
final _fixtures = TimetableFixtureBuilder();

void main() {
  group('Timetable API integration', () {
    late MockTimetableRepository mockRepo;
    late ApiTimetableRepository apiRepo;

    setUp(() async {
      mockRepo = MockTimetableRepository();
      final summary = await mockRepo.getSummary(
        query: kQuery,
        academicYearId: 'mock-year-current',
      );
      final entries = await mockRepo.getTimetables(query: kQuery);
      final workload = await mockRepo.getWorkload(
        query: kQuery,
        academicYearId: 'mock-year-current',
      );

      final dio = createFakeDio((options) {
        if (options.path == TimetableApiPaths.summary) {
          return _fixtures.summaryEnvelope(summary);
        }
        if (options.path == TimetableApiPaths.timetables && options.method == 'GET') {
          return _fixtures.entriesEnvelope(entries);
        }
        if (options.path == TimetableApiPaths.workload) {
          return _fixtures.workloadEnvelope(workload);
        }
        throw UnsupportedError('Unhandled ${options.method} ${options.path}');
      });

      apiRepo = ApiTimetableRepository(
        remote: TimetableRemoteDataSource(dio),
      );
    });

    test('getSummary returns mapped summary', () async {
      final mockData = await mockRepo.getSummary(
        query: kQuery,
        academicYearId: 'mock-year-current',
      );
      final apiData = await apiRepo.getSummary(
        query: kQuery,
        academicYearId: 'mock-year-current',
      );
      expect(apiData.totalTimetables, mockData.totalTimetables);
    });

    test('getTimetables returns mapped entries', () async {
      final mockData = await mockRepo.getTimetables(query: kQuery);
      final apiData = await apiRepo.getTimetables(query: kQuery);
      expect(apiData.length, mockData.length);
    });

    test('getWorkload returns mapped workload', () async {
      final mockData = await mockRepo.getWorkload(
        query: kQuery,
        academicYearId: 'mock-year-current',
      );
      final apiData = await apiRepo.getWorkload(
        query: kQuery,
        academicYearId: 'mock-year-current',
      );
      expect(apiData.first.periodCount, mockData.first.periodCount);
    });
  });
}
