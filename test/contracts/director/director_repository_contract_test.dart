import 'package:akshara_erp/core/repositories/api/director/api_director_repository.dart';
import 'package:akshara_erp/core/repositories/api/director/remote/director_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/director_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_director_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/ai/ai_inference_pipeline.dart';
import 'package:akshara_erp/core/ai/ai_inference_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

const _kQuery = RepositoryQuery.demo;

/// A pipeline that always fails so the mock director summary falls back to its
/// deterministic brief (no network in unit tests).
class _NoopPipeline implements AiInferencePipeline {
  @override
  Future<AiInferenceResponse> complete(AiInferenceRequest request) async {
    throw StateError('no AI in tests');
  }

  @override
  Stream<AiInferenceStreamChunk> stream(AiInferenceRequest request) async* {
    throw StateError('no AI in tests');
  }
}

MockDirectorRepository _mock() =>
    MockDirectorRepository(pipeline: _NoopPipeline());

void main() {
  group('Director repository contract (DIR-1/2 + DIR-D1)', () {
    test('mock and api both implement DirectorRepository', () {
      expect(_mock(), isA<DirectorRepository>());
      expect(
        ApiDirectorRepository(remote: DirectorRemoteDataSource(_dioFor({}))),
        isA<DirectorRepository>(),
      );
    });

    test('DirectorSchoolRow carries additive billed/collected/outstanding',
        () async {
      final rows = await _mock().getMultiSchoolOverview(query: _kQuery);
      expect(rows, isNotEmpty);
      for (final r in rows) {
        // Money fields are present and internally consistent.
        expect(r.billedInr, greaterThanOrEqualTo(r.collectedInr));
        expect(r.outstandingInr, r.billedInr - r.collectedInr);
      }
    });

    test('getCollectionReport totals equal the sum of the school rows',
        () async {
      final report = await _mock().getCollectionReport(query: _kQuery);
      expect(report.schools, isNotEmpty);

      final billed =
          report.schools.fold<int>(0, (sum, s) => sum + s.billedInr);
      final collected =
          report.schools.fold<int>(0, (sum, s) => sum + s.collectedInr);
      final outstanding =
          report.schools.fold<int>(0, (sum, s) => sum + s.outstandingInr);

      expect(report.totals.billedInr, billed);
      expect(report.totals.collectedInr, collected);
      expect(report.totals.outstandingInr, outstanding);
      expect(
        report.totals.feeCollectionPercent,
        billed > 0 ? ((collected / billed) * 100).round() : 0,
      );
    });

    test('getSchoolSnapshot returns aggregates for a known school', () async {
      final rows = await _mock().getMultiSchoolOverview(query: _kQuery);
      final target = rows.first;
      final snapshot = await _mock()
          .getSchoolSnapshot(query: _kQuery, schoolId: target.schoolId);

      expect(snapshot.schoolId, target.schoolId);
      expect(snapshot.schoolName, target.schoolName);
      expect(snapshot.feeCollectionPercent, target.feeCollectionPercent);
      expect(snapshot.billedInr, target.billedInr);
      expect(snapshot.attendancePercent, inInclusiveRange(0, 100));
      expect(snapshot.academicPassPercent, inInclusiveRange(0, 100));
    });

    test('api getCollectionReport parses the { schools, totals } envelope',
        () async {
      final dio = _dioFor({
        '/director/collections': {
          'data': {
            'schools': [
              {
                'schoolId': 'S1',
                'name': 'North',
                'feeCollectionPercent': 90,
                'billedInr': 1000,
                'collectedInr': 900,
                'outstandingInr': 100,
              },
            ],
            'totals': {
              'billedInr': 1000,
              'collectedInr': 900,
              'outstandingInr': 100,
              'feeCollectionPercent': 90,
            },
          },
        },
      });
      final api = ApiDirectorRepository(remote: DirectorRemoteDataSource(dio));
      final report = await api.getCollectionReport(query: _kQuery);

      expect(report.schools.single.name, 'North');
      expect(report.schools.single.outstandingInr, 100);
      expect(report.totals.feeCollectionPercent, 90);
    });

    test('api getSchoolSnapshot hits /director/schools/{id}/snapshot', () async {
      RequestOptions? seen;
      final dio = createFakeDio((options) {
        seen = options;
        return {
          'data': {
            'schoolId': 'S7',
            'schoolName': 'East',
            'location': 'Warangal',
            'students': 100,
            'attendancePercent': 88,
            'feeCollectionPercent': 80,
            'billedInr': 500,
            'collectedInr': 400,
            'outstandingInr': 100,
            'admissions': {
              'inquiries': 40,
              'applications': 20,
              'enrolled': 10,
              'conversionPercent': 25,
            },
            'academic': {'passPercent': 75, 'gradedEntries': 600},
            'healthScore': 78,
            'status': 'onTrack',
          },
        };
      });
      final api = ApiDirectorRepository(remote: DirectorRemoteDataSource(dio));
      final snapshot =
          await api.getSchoolSnapshot(query: _kQuery, schoolId: 'S7');

      expect(seen?.path, '/director/schools/S7/snapshot');
      expect(snapshot.schoolName, 'East');
      expect(snapshot.admissionsConversionPercent, 25);
      expect(snapshot.academicGradedEntries, 600);
    });
  });
}

// Small helper: resolves each request path to its canned envelope (else empty).
Dio _dioFor(Map<String, Map<String, dynamic>> byPath) {
  return createFakeDio((options) => byPath[options.path] ?? {'data': {}});
}
