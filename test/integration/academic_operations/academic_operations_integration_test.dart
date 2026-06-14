import 'package:akshara_erp/core/repositories/api/academic_operations/academic_operations_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/academic_operations/api_academic_operations_repository.dart';
import 'package:akshara_erp/core/repositories/api/academic_operations/remote/academic_operations_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/sis/academic_operations/academic_operations_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

const _query = RepositoryQuery.demo;

void main() {
  group('Academic operations API integration', () {
    Dio testDioFactory() {
      return createFakeDio((options) {
        if (options.path == AcademicOperationsApiPaths.suggestMappings) {
          return {
            'data': {
              'mappings': [
                {
                  'sourceClassLabel': '7',
                  'sourceSection': 'A',
                  'targetClassLabel': '8',
                  'targetSection': 'A',
                  'includeStudents': true,
                },
              ],
            },
          };
        }
        if (options.path == AcademicOperationsApiPaths.previewTransition) {
          return {
            'data': {
              'id': 'TRN-1',
              'sourceYearId': '2026–27',
              'targetYearId': '2027–28',
              'status': 'previewed',
              'createdAt': DateTime.now().toIso8601String(),
              'mappingRules': [
                {
                  'sourceClassLabel': '7',
                  'sourceSection': 'A',
                  'targetClassLabel': '8',
                  'targetSection': 'A',
                  'includeStudents': true,
                },
              ],
              'previewRows': [
                {
                  'studentId': 'SIS-STU-10418',
                  'studentName': 'Emma Thomas',
                  'admissionNumber': 'ADM-2026-0135',
                  'fromClassLabel': '7',
                  'fromSection': 'A',
                  'toClassLabel': '8',
                  'toSection': 'A',
                  'reason': 'Year transition',
                },
              ],
            },
          };
        }
        if (options.path.endsWith('/execute')) {
          return {
            'data': {
              'jobId': 'TRN-1',
              'executedCount': 1,
              'skippedCount': 0,
              'executedAt': DateTime.now().toIso8601String(),
            },
          };
        }
        if (options.path == AcademicOperationsApiPaths.previewReshuffle) {
          return {
            'data': {
              'id': 'RESHUFFLE-1',
              'classLabel': '7',
              'academicYear': '2026–27',
              'strategy': 'alphabetical',
              'previewRows': [
                {
                  'studentId': 'SIS-STU-10418',
                  'studentName': 'Emma Thomas',
                  'admissionNumber': 'ADM-2026-0135',
                  'fromClassLabel': '7',
                  'fromSection': 'A',
                  'toClassLabel': '7',
                  'toSection': 'B',
                  'reason': 'Reshuffle strategy: alphabetical',
                },
              ],
            },
          };
        }
        return {'data': {}};
      });
    }

    test('api repository maps transition preview + execute', () async {
      final repository = ApiAcademicOperationsRepository(
        remote: AcademicOperationsRemoteDataSource(testDioFactory()),
      );
      final mappings = await repository.suggestClassMappings(
        query: _query,
        sourceYearId: '2026–27',
        targetYearId: '2027–28',
      );
      expect(mappings, hasLength(1));

      final preview = await repository.previewYearTransition(
        query: _query,
        sourceYearId: '2026–27',
        targetYearId: '2027–28',
        mappings: mappings,
      );
      expect(preview.status, AcademicTransitionJobStatus.previewed);
      expect(preview.previewRows, isNotEmpty);

      final report = await repository.executeYearTransition(
        query: _query,
        jobId: preview.id,
      );
      expect(report.executedCount, 1);
    });

    test('api repository maps reshuffle preview', () async {
      final repository = ApiAcademicOperationsRepository(
        remote: AcademicOperationsRemoteDataSource(testDioFactory()),
      );
      final plan = await repository.previewStudentReshuffle(
        query: _query,
        classLabel: '7',
        academicYear: '2026–27',
        strategy: 'alphabetical',
      );
      expect(plan.previewRows.first.toSection, 'B');
    });
  });
}
