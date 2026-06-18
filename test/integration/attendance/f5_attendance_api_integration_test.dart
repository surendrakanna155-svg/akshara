import 'package:akshara_erp/core/approvals/adapters/attendance_correction_approval_adapter.dart';
import 'package:akshara_erp/core/approvals/approval_center_service.dart';
import 'package:akshara_erp/core/approvals/approval_requests.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';
import 'package:akshara_erp/core/attendance/attendance_correction_models.dart';
import 'package:akshara_erp/core/attendance/attendance_correction_store.dart';
import 'package:akshara_erp/core/repositories/api/attendance/api_attendance_correction_repository.dart';
import 'package:akshara_erp/core/repositories/api/attendance/remote/attendance_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/attendance/remote/attendance_correction_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_approval_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_attendance_correction_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_attendance_sync_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

const _query = RepositoryQuery(tenantId: 'tenant_demo', schoolId: 'school_demo');

void main() {
  group('F5 attendance API integration', () {
    late AttendanceCorrectionStore correctionStore;
    late MockAttendanceSyncStore syncStore;
    late MockApprovalRepository approvalRepo;
    late ApprovalCenterService service;

    setUp(() {
      correctionStore = AttendanceCorrectionStore.instance;
      correctionStore.reset();
      syncStore = MockAttendanceSyncStore.instance;
      syncStore.reset();
      approvalRepo = MockApprovalRepository();
      service = ApprovalCenterService(approvalRepo);
    });

    test('ApiAttendanceCorrectionRepository completes correction lifecycle', () async {
      final apiRepo = ApiAttendanceCorrectionRepository(
        remote: AttendanceCorrectionRemoteDataSource(
          createFakeDio((options) {
            final path = options.path;
            final method = options.method.toUpperCase();

            if (path == AttendanceApiPaths.corrections && method == 'POST') {
              final body = options.data as Map<String, dynamic>;
              return {
                'data': {
                  'id': 'att_corr_f5',
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
            if (path == AttendanceApiPaths.corrections && method == 'GET') {
              return {
                'data': [
                  {
                    'id': 'att_corr_f5',
                    'sisStudentId': 'SIS-STU-10430',
                    'studentName': 'Arjun Patel',
                    'classLabel': '8',
                    'section': 'A',
                    'dateLabel': '12 Jun 2026',
                    'fromMark': 'Absent',
                    'toMark': 'Present',
                    'reason': 'Late arrival',
                    'requesterId': 'teacher_001',
                    'requesterName': 'Priya Sharma',
                    'requesterRole': 'teacher',
                    'presentDelta': 1,
                    'status': 'approved',
                    'requestedAt': DateTime.now().toIso8601String(),
                    'studentsAffected': 1,
                  },
                ],
              };
            }
            if (path.endsWith('/status') && method == 'PATCH') {
              return {
                'data': {
                  'id': 'att_corr_f5',
                  'sisStudentId': 'SIS-STU-10430',
                  'studentName': 'Arjun Patel',
                  'classLabel': '8',
                  'section': 'A',
                  'dateLabel': '12 Jun 2026',
                  'fromMark': 'Absent',
                  'toMark': 'Present',
                  'reason': 'Late arrival',
                  'requesterId': 'teacher_001',
                  'requesterName': 'Priya Sharma',
                  'requesterRole': 'teacher',
                  'presentDelta': 1,
                  'status': 'approved',
                  'requestedAt': DateTime.now().toIso8601String(),
                  'studentsAffected': 1,
                },
              };
            }
            return {'data': {}};
          }),
        ),
      );

      final created = await apiRepo.createCorrection(
        query: _query,
        request: const CreateAttendanceCorrectionRequest(
          sisStudentId: 'SIS-STU-10430',
          studentName: 'Arjun Patel',
          classLabel: '8',
          section: 'A',
          dateLabel: '12 Jun 2026',
          fromMark: 'Absent',
          toMark: 'Present',
          reason: 'Late arrival',
          requesterId: 'teacher_001',
          requesterName: 'Priya Sharma',
          requesterRole: 'teacher',
        ),
      );
      expect(created.id, 'att_corr_f5');
      expect(created.status, AttendanceCorrectionStatus.pending);

      final listed = await apiRepo.listCorrections(query: _query);
      expect(listed, isNotEmpty);

      final approved = await apiRepo.updateStatus(
        query: _query,
        correctionId: created.id,
        status: AttendanceCorrectionStatus.approved,
      );
      expect(approved.status, AttendanceCorrectionStatus.approved);
    });

    test('correction submit → principal approve updates sync store and status',
        () async {
      syncStore.recordTeacherSubmit(present: 28, absent: 2, late: 0);

      final correctionRepo = MockAttendanceCorrectionRepository(store: correctionStore);
      final adapter = AttendanceCorrectionApprovalAdapter(
        store: syncStore,
        correctionStore: correctionStore,
        repository: correctionRepo,
      );

      final correction = await correctionRepo.createCorrection(
        query: _query,
        request: const CreateAttendanceCorrectionRequest(
          sisStudentId: 'SIS-STU-10430',
          studentName: 'Arjun Patel',
          classLabel: '8',
          section: 'A',
          dateLabel: '12 Jun 2026',
          fromMark: 'Absent',
          toMark: 'Present',
          reason: 'Biometric sync error',
          requesterId: 'teacher_001',
          requesterName: 'Priya Sharma',
          requesterRole: 'teacher',
        ),
      );

      final pending = await adapter.submitForApproval(
        service: service,
        query: _query,
        entityId: correction.id,
        requesterId: 'teacher_001',
        requesterName: 'Priya Sharma',
        title: 'Attendance correction — Arjun Patel',
        summary: '8-A · Absent → Present',
        payload: {
          'classLabel': '8',
          'section': 'A',
          'date': '12 Jun 2026',
          'fromMark': 'Absent',
          'toMark': 'Present',
          'studentsAffected': 1,
          'presentDelta': 1,
          'requesterRole': 'teacher',
        },
      );
      expect(pending.status, ApprovalStatus.pending);
      expect(correctionStore.byId(correction.id)!.status,
          AttendanceCorrectionStatus.pending);

      final approved = await service.approveRequest(
        query: _query,
        request: ApproveApprovalRequest(
          approvalId: pending.id,
          actorId: 'principal_001',
          actorName: 'Principal',
        ),
      );
      adapter.onApproved(query: _query, request: approved);

      expect(syncStore.presentCount, 29);
      expect(syncStore.correctionDeltaPresent, 1);
      expect(
        correctionStore.byId(correction.id)!.status,
        AttendanceCorrectionStatus.approved,
      );
    });

    test('mock fallback repository preserves in-memory correction store', () async {
      final mockRepo = MockAttendanceCorrectionRepository(store: correctionStore);
      final created = await mockRepo.createCorrection(
        query: _query,
        request: const CreateAttendanceCorrectionRequest(
          sisStudentId: 'SIS-STU-10418',
          studentName: 'Emma Thomas',
          classLabel: '7',
          section: 'A',
          dateLabel: '15 Jun 2026',
          fromMark: 'Absent',
          toMark: 'Present',
          reason: 'Gate entry logged late',
          requesterId: 'parent_001',
          requesterName: 'David Thomas',
          requesterRole: 'parent',
        ),
      );

      final pending = await mockRepo.listCorrections(
        query: _query,
        status: AttendanceCorrectionStatus.pending,
      );
      expect(pending.any((item) => item.id == created.id), isTrue);

      final rejected = await mockRepo.updateStatus(
        query: _query,
        correctionId: created.id,
        status: AttendanceCorrectionStatus.rejected,
      );
      expect(rejected.status, AttendanceCorrectionStatus.rejected);
    });
  });
}
