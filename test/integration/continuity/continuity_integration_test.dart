import 'package:akshara_erp/core/repositories/api/continuity/api_continuity_repository.dart';
import 'package:akshara_erp/core/repositories/api/continuity/continuity_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/continuity/remote/continuity_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

const _query = RepositoryQuery.demo;

void main() {
  group('Continuity API integration', () {
    Dio testDioFactory() {
      return createFakeDio((options) {
        if (options.path == ContinuityApiPaths.preview) {
          return {
            'data': {
              'id': 'CONT_PLAN_1',
              'studentId': 'SIS-STU-10418',
              'fromClass': '7',
              'fromSection': 'A',
              'toClass': '8',
              'toSection': 'A',
              'academicYear': '2026-27',
              'status': 'previewed',
              'createdAt': DateTime.now().toIso8601String(),
              'teacherImpact': {
                'fromTeacherId': 'T-1',
                'toTeacherId': 'T-2',
                'studentIds': ['SIS-STU-10418'],
                'threadCount': 3,
              },
              'timetableImpact': {
                'studentId': 'SIS-STU-10418',
                'fromSection': 'A',
                'toSection': 'A',
                'slotIds': ['slot-1'],
              },
              'parentCommunicationImpact': {
                'studentId': 'SIS-STU-10418',
                'parentIds': ['P-1'],
                'threadIds': ['thread-1'],
              },
              'notificationImpact': {
                'studentId': 'SIS-STU-10418',
                'notificationIds': ['N-1'],
                'recipientIds': ['P-1'],
              },
              'assignmentImpact': {
                'studentId': 'SIS-STU-10418',
                'assignmentIds': ['HW-1'],
                'migratedCount': 1,
              },
              'messageOwnershipImpact': {
                'fromTeacherId': 'T-1',
                'toTeacherId': 'T-2',
                'transferredThreadIds': ['thread-1'],
              },
            },
          };
        }
        if (options.path == ContinuityApiPaths.execute('CONT_PLAN_1')) {
          return {
            'data': {
              'migrationId': 'CONT_MIG_1',
              'planId': 'CONT_PLAN_1',
              'status': 'executed',
              'migratedAreas': [
                'teacher',
                'timetable',
                'parentCommunication',
              ],
              'executedAt': DateTime.now().toIso8601String(),
            },
          };
        }
        if (options.path == ContinuityApiPaths.auditTrail('CONT_PLAN_1')) {
          return {
            'items': [
              {
                'id': 'AUDIT_1',
                'migrationId': 'CONT_PLAN_1',
                'area': 'teacher',
                'action': 'transferred',
                'timestamp': DateTime.now().toIso8601String(),
                'metadata': {'threads': '1'},
              },
            ],
          };
        }
        if (options.path == ContinuityApiPaths.messageOwnership) {
          return {
            'data': {
              'fromTeacherId': 'T-1',
              'toTeacherId': 'T-2',
              'transferredThreadIds': ['thread-1'],
            },
          };
        }
        return {'data': {}};
      });
    }

    test('preview + execute continuity maps response', () async {
      final repository = ApiContinuityRepository(
        remote: ContinuityRemoteDataSource(testDioFactory()),
      );
      final plan = await repository.previewContinuityMigration(
        query: _query,
        studentId: 'SIS-STU-10418',
        fromClass: '7',
        fromSection: 'A',
        toClass: '8',
        toSection: 'A',
        academicYear: '2026-27',
      );
      expect(plan.status.name, 'previewed');
      final result = await repository.executeContinuityMigration(
        query: _query,
        planId: plan.id,
      );
      expect(result.status.name, 'executed');
    });
  });
}
