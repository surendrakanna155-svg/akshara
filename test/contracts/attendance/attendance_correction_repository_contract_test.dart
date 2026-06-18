import 'package:akshara_erp/core/attendance/attendance_correction_models.dart';
import 'package:akshara_erp/core/attendance/attendance_correction_store.dart';
import 'package:akshara_erp/core/repositories/api/attendance/api_attendance_correction_repository.dart';
import 'package:akshara_erp/core/repositories/api/attendance/remote/attendance_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/attendance/remote/attendance_correction_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_attendance_correction_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

void main() {
  const query = RepositoryQuery.demo;

  setUp(() {
    AttendanceCorrectionStore.instance.reset();
  });

  group('Attendance correction repository contract', () {
    final repo = MockAttendanceCorrectionRepository();

    test('create → list → updateStatus', () async {
      final created = await repo.createCorrection(
        query: query,
        request: const CreateAttendanceCorrectionRequest(
          sisStudentId: 'SIS-STU-10430',
          studentName: 'Arjun Patel',
          classLabel: '10',
          section: 'A',
          dateLabel: '12 Jun 2026',
          fromMark: 'Absent',
          toMark: 'Present',
          reason: 'Biometric sync error',
          requesterId: 'teacher_1',
          requesterName: 'Ms. Rao',
          requesterRole: 'teacher',
        ),
      );

      expect(created.status, AttendanceCorrectionStatus.pending);
      expect(created.id, startsWith('att_corr_'));

      final listed = await repo.listCorrections(query: query);
      expect(listed, hasLength(1));
      expect(listed.first.id, created.id);

      final fetched = await repo.getCorrection(
        query: query,
        correctionId: created.id,
      );
      expect(fetched?.studentName, 'Arjun Patel');

      final approved = await repo.updateStatus(
        query: query,
        correctionId: created.id,
        status: AttendanceCorrectionStatus.approved,
      );
      expect(approved.status, AttendanceCorrectionStatus.approved);

      final pendingOnly = await repo.listCorrections(
        query: query,
        status: AttendanceCorrectionStatus.pending,
      );
      expect(pendingOnly, isEmpty);
    });

    test('API fake-Dio create → list → updateStatus parity', () async {
      final remote = AttendanceCorrectionRemoteDataSource(
        createFakeDio((options) {
          if (options.path == AttendanceApiPaths.corrections &&
              options.method.toUpperCase() == 'POST') {
            final body = options.data as Map<String, dynamic>;
            return {
              'data': {
                'id': 'att_corr_api_1',
                'sisStudentId': body['sisStudentId'],
                'studentName': body['studentName'],
                'classLabel': body['classLabel'],
                'section': body['section'],
                'dateLabel': body['dateLabel'],
                'fromMark': body['fromMark'],
                'toMark': body['toMark'],
                'reason': body['reason'],
                'requesterId': body['requesterId'],
                'requesterName': body['requesterName'],
                'requesterRole': body['requesterRole'],
                'presentDelta': body['presentDelta'],
                'status': 'pending',
                'requestedAt': DateTime.now().toIso8601String(),
                'studentsAffected': 1,
              },
            };
          }
          if (options.path == AttendanceApiPaths.corrections &&
              options.method.toUpperCase() == 'GET') {
            return {
              'data': [
                {
                  'id': 'att_corr_api_1',
                  'sisStudentId': 'SIS-STU-10430',
                  'studentName': 'Arjun Patel',
                  'classLabel': '10',
                  'section': 'A',
                  'dateLabel': '12 Jun 2026',
                  'fromMark': 'Absent',
                  'toMark': 'Present',
                  'reason': 'Biometric sync error',
                  'requesterId': 'teacher_1',
                  'requesterName': 'Ms. Rao',
                  'requesterRole': 'teacher',
                  'presentDelta': 1,
                  'status': 'approved',
                  'requestedAt': DateTime.now().toIso8601String(),
                  'studentsAffected': 1,
                },
              ],
            };
          }
          if (options.path.endsWith('/status') &&
              options.method.toUpperCase() == 'PATCH') {
            final body = options.data as Map<String, dynamic>;
            return {
              'data': {
                'id': 'att_corr_api_1',
                'sisStudentId': 'SIS-STU-10430',
                'studentName': 'Arjun Patel',
                'classLabel': '10',
                'section': 'A',
                'dateLabel': '12 Jun 2026',
                'fromMark': 'Absent',
                'toMark': 'Present',
                'reason': 'Biometric sync error',
                'requesterId': 'teacher_1',
                'requesterName': 'Ms. Rao',
                'requesterRole': 'teacher',
                'presentDelta': 1,
                'status': body['status'],
                'requestedAt': DateTime.now().toIso8601String(),
                'studentsAffected': 1,
              },
            };
          }
          return {'data': {}};
        }),
      );
      final apiRepo = ApiAttendanceCorrectionRepository(remote: remote);

      final created = await apiRepo.createCorrection(
        query: query,
        request: const CreateAttendanceCorrectionRequest(
          sisStudentId: 'SIS-STU-10430',
          studentName: 'Arjun Patel',
          classLabel: '10',
          section: 'A',
          dateLabel: '12 Jun 2026',
          fromMark: 'Absent',
          toMark: 'Present',
          reason: 'Biometric sync error',
          requesterId: 'teacher_1',
          requesterName: 'Ms. Rao',
          requesterRole: 'teacher',
        ),
      );
      expect(created.id, 'att_corr_api_1');

      final listed = await apiRepo.listCorrections(query: query);
      expect(listed, isNotEmpty);

      final approved = await apiRepo.updateStatus(
        query: query,
        correctionId: created.id,
        status: AttendanceCorrectionStatus.approved,
      );
      expect(approved.status, AttendanceCorrectionStatus.approved);
    });
  });
}
