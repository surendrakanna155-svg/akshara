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
    Object? capturedPreviewBody;

    Dio testDioFactory() {
      return createFakeDio((options) {
        if (options.path == AcademicOperationsApiPaths.previewTransition) {
          capturedPreviewBody = options.data;
        }
        // PRA-P0-14: fakes mirror the REAL backend contract — suggestions under
        // `data.items` with `sourceClassName/targetClassName/keepSection/action`;
        // preview/execute/get wrap the row under `data.job` with the affected
        // students under `previewReport.rows`; executed jobs report `promotedCount`
        // and status `completed`.
        if (options.path == AcademicOperationsApiPaths.suggestMappings) {
          return {
            'data': {
              'items': [
                {
                  'sourceClassName': '7',
                  'targetClassName': '8',
                  'keepSection': true,
                  'action': 'promote',
                },
              ],
            },
          };
        }
        if (options.path == AcademicOperationsApiPaths.previewTransition) {
          final rows = [
            {
              'studentId': 'SIS-STU-10418',
              'studentName': 'Emma Thomas',
              'enrollmentId': 'ENR-1',
              'sourceClassName': '7',
              'sourceSectionName': 'A',
              'targetClassName': '8',
              'targetSectionName': 'A',
              'status': 'promote',
              'errors': <String>[],
            },
          ];
          return {
            'data': {
              'job': {
                'id': 'TRN-1',
                'sourceYearId': 'YR-2026',
                'targetYearId': 'YR-2027',
                'status': 'previewed',
                'createdAt': DateTime.now().toIso8601String(),
                'classMapping': [
                  {
                    'sourceClassName': '7',
                    'targetClassName': '8',
                    'keepSection': true,
                    'action': 'promote',
                  },
                ],
                'previewReport': {
                  'rows': rows,
                  'summary': {
                    'promote': 1,
                    'graduate': 0,
                    'skip': 0,
                    'invalid': 0,
                    'total': 1,
                  },
                },
                'promotedCount': 0,
                'skippedCount': 0,
                'failedCount': 0,
              },
              'preview': rows,
            },
          };
        }
        if (options.path.endsWith('/execute')) {
          return {
            'data': {
              'job': {
                'id': 'TRN-1',
                'status': 'completed',
                'promotedCount': 1,
                'skippedCount': 0,
                'failedCount': 0,
                'executedAt': DateTime.now().toIso8601String(),
              },
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

      // PRA-P0-14: the preview request must round-trip the mapping under the
      // backend `classMapping` key with backend field names (`sourceClassName`
      // / `action`), not the old `mappings` / `sourceClassLabel` shape.
      final body = capturedPreviewBody! as Map<String, dynamic>;
      expect(body.containsKey('classMapping'), isTrue);
      expect(body.containsKey('mappings'), isFalse);
      final sentMapping = (body['classMapping'] as List).first as Map;
      expect(sentMapping['sourceClassName'], '7');
      expect(sentMapping['action'], 'promote');
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
