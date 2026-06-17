import 'package:akshara_erp/core/approvals/adapters/exam_results_approval_adapter.dart';
import 'package:akshara_erp/core/approvals/approval_center_service.dart';
import 'package:akshara_erp/core/approvals/approval_requests.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';
import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_approval_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_teacher_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/teacher/teacher_requests.dart';
import 'package:flutter_test/flutter_test.dart';

const _query = RepositoryQuery(tenantId: 'tenant_demo', schoolId: 'school_demo');

void main() {
  group('Exam publish approval integration — M-D3', () {
    late ExamAdministrationStore store;
    late MockApprovalRepository approvalRepo;
    late ApprovalCenterService service;
    late ExamResultsApprovalAdapter adapter;
    late MockTeacherRepository teacherRepo;
    late MockParentRepository parentRepo;

    setUp(() {
      store = ExamAdministrationStore.instance;
      store.reset();
      approvalRepo = MockApprovalRepository();
      service = ApprovalCenterService(approvalRepo);
      adapter = ExamResultsApprovalAdapter(store: store);
      teacherRepo = MockTeacherRepository();
      parentRepo = MockParentRepository();
    });

    Future<void> completeMarks(String examId) async {
      for (final mark in store.marksForExam(examId)) {
        if (mark.marksObtained == null) {
          await teacherRepo.updateExamMark(
            query: _query,
            request: TeacherExamMarkUpdateRequest(
              markEntryId: mark.id,
              marksObtained: 38,
            ),
          );
        }
      }
    }

    test('teacher submit → principal approve → parent sees published results',
        () async {
      await completeMarks('exam_math_8a');

      final beforeParent = await parentRepo.getExams(query: _query);
      expect(beforeParent.examResults, isEmpty);

      final pending = await adapter.submitForApproval(
        service: service,
        query: _query,
        examId: 'exam_math_8a',
        requesterId: 'teacher_001',
        requesterName: 'Priya Sharma',
      );
      expect(pending.status, ApprovalStatus.pending);
      expect(store.examById('exam_math_8a')!.phase, ExamLifecyclePhase.processed);

      final midParent = await parentRepo.getExams(query: _query);
      expect(midParent.examResults, isEmpty);

      final approved = await service.approveRequest(
        query: _query,
        request: ApproveApprovalRequest(
          approvalId: pending.id,
          actorId: 'principal_001',
          actorName: 'Principal',
        ),
      );
      adapter.onApproved(query: _query, request: approved);

      final afterParent = await parentRepo.getExams(query: _query);
      expect(afterParent.examResults, isNotEmpty);
      expect(
        store.examById('exam_math_8a')!.phase,
        ExamLifecyclePhase.published,
      );
    });

    test('reject keeps parent results empty and stores teacher-visible comment',
        () async {
      await completeMarks('exam_math_8a');

      final pending = await adapter.submitForApproval(
        service: service,
        query: _query,
        examId: 'exam_math_8a',
        requesterId: 'teacher_001',
        requesterName: 'Priya Sharma',
      );

      final rejected = await service.rejectRequest(
        query: _query,
        request: RejectApprovalRequest(
          approvalId: pending.id,
          actorId: 'principal_001',
          actorName: 'Principal',
          comment: 'Recheck absent codes for roll 06.',
        ),
      );
      adapter.onRejected(
        query: _query,
        request: rejected,
        comment: 'Recheck absent codes for roll 06.',
      );

      final parentData = await parentRepo.getExams(query: _query);
      expect(parentData.examResults, isEmpty);
      expect(
        store.rejectionCommentFor('exam_math_8a'),
        'Recheck absent codes for roll 06.',
      );
      expect(
        store.examById('exam_math_8a')!.phase,
        isNot(ExamLifecyclePhase.published),
      );
    });
  });
}
