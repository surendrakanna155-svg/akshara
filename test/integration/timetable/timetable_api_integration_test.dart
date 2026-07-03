import 'package:akshara_erp/core/repositories/api/timetable/api_timetable_repository.dart';
import 'package:akshara_erp/core/repositories/api/timetable/remote/timetable_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/timetable/remote/timetable_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_timetable_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/academics/timetable/timetable_models.dart';
import 'package:dio/dio.dart';
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

  group('Substitutions API integration', () {
    const date = '2026-07-03';
    const bundle = DailySubstitutionsBundle(
      date: date,
      substitutions: [
        TimetableSubstitution(
          id: 'sub_live_1',
          periodId: 'period_1',
          subDate: date,
          originalTeacherId: 'HR-EMP-101',
          substituteTeacherId: 'HR-EMP-102',
          reason: 'sick',
          dayOfWeek: 5,
          periodNumber: 2,
          subjectLabel: 'Science',
          roomLabel: 'Lab 1',
        ),
      ],
      onLeave: [TimetableTeacherOnLeave(teacherId: 'HR-EMP-101', reason: 'sick')],
    );

    test('listSubstitutions maps subs + server on-leave', () async {
      final dio = createFakeDio((options) {
        expect(options.path, TimetableApiPaths.substitutions);
        expect(options.queryParameters['date'], date);
        return _fixtures.dailySubstitutionsEnvelope(bundle);
      });
      final apiRepo = ApiTimetableRepository(remote: TimetableRemoteDataSource(dio));

      final result = await apiRepo.listSubstitutions(query: kQuery, date: date);
      expect(result.substitutions.single.substituteTeacherId, 'HR-EMP-102');
      expect(result.substitutions.single.periodNumber, 2);
      expect(result.onLeave.single.teacherId, 'HR-EMP-101');
    });

    test('createSubstitution posts and maps the created row', () async {
      const created = TimetableSubstitution(
        id: 'sub_live_9',
        periodId: 'period_1',
        subDate: date,
        originalTeacherId: 'HR-EMP-101',
        substituteTeacherId: 'HR-EMP-103',
        reason: 'leave',
      );
      final dio = createFakeDio((options) {
        expect(options.method, 'POST');
        expect(options.data['periodId'], 'period_1');
        expect(options.data['substituteTeacherId'], 'HR-EMP-103');
        return _fixtures.createSubstitutionEnvelope(created);
      });
      final apiRepo = ApiTimetableRepository(remote: TimetableRemoteDataSource(dio));

      final result = await apiRepo.createSubstitution(
        query: kQuery,
        request: const CreateSubstitutionRequest(
          periodId: 'period_1',
          subDate: date,
          substituteTeacherId: 'HR-EMP-103',
        ),
      );
      expect(result.id, 'sub_live_9');
      expect(result.substituteTeacherId, 'HR-EMP-103');
    });

    test('createSubstitution surfaces 409 SUBSTITUTE_BUSY as a typed exception',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.api/v1'));
      dio.interceptors.add(_RejectingInterceptor(
        statusCode: 409,
        body: _fixtures.errorEnvelope(
          'SUBSTITUTE_BUSY',
          'Substitute HR-EMP-103 is already teaching period 2 on $date',
        ),
      ));
      final apiRepo = ApiTimetableRepository(remote: TimetableRemoteDataSource(dio));

      expect(
        () => apiRepo.createSubstitution(
          query: kQuery,
          request: const CreateSubstitutionRequest(
            periodId: 'period_1',
            subDate: date,
            substituteTeacherId: 'HR-EMP-103',
          ),
        ),
        throwsA(isA<SubstituteBusyException>()),
      );
    });

    test('deleteSubstitution issues a DELETE to the id path', () async {
      var deleted = false;
      final dio = createFakeDio((options) {
        expect(options.method, 'DELETE');
        expect(options.path, TimetableApiPaths.substitution('sub_live_1'));
        deleted = true;
        return _fixtures.envelope({'substitution': {'id': 'sub_live_1'}});
      });
      final apiRepo = ApiTimetableRepository(remote: TimetableRemoteDataSource(dio));

      await apiRepo.deleteSubstitution(query: kQuery, id: 'sub_live_1');
      expect(deleted, isTrue);
    });
  });
}

/// Rejects every request with a canned non-2xx response so the api repo sees a
/// [DioException] carrying the backend error envelope (used for 409 cases).
class _RejectingInterceptor extends Interceptor {
  _RejectingInterceptor({required this.statusCode, required this.body});

  final int statusCode;
  final Map<String, dynamic> body;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.reject(
      DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: statusCode,
          data: body,
        ),
        type: DioExceptionType.badResponse,
      ),
    );
  }
}
