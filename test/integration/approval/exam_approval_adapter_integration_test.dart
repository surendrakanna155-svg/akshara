import 'package:akshara_erp/core/approvals/adapters/exam_results_approval_adapter.dart';
import 'package:akshara_erp/core/approvals/approval_center_service.dart';
import 'package:akshara_erp/core/approvals/approval_requests.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';
import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_approval_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

const _query = RepositoryQuery(tenantId: 'tenant_demo', schoolId: 'school_demo');

void main() {
  group('Exam approval adapter integration — M-D3', () {
    late ExamAdministrationStore store;
    late MockApprovalRepository repository;
    late ApprovalCenterService service;
    late ExamResultsApprovalAdapter adapter;

    setUp(() {
      store = ExamAdministrationStore.instance;
      store.reset();
      repository = MockApprovalRepository();
      service = ApprovalCenterService(repository);
      adapter = ExamResultsApprovalAdapter(store: store);
    });

    Future<void> completeMarks(String examId) async {
      for (final mark in store.marksForExam(examId)) {
        if (mark.marksObtained == null) {
          store.recordMark(markEntryId: mark.id, marksObtained: 36);
        }
      }
    }

    test('submit → approve → adapter publishes exam session', () async {
      await completeMarks('exam_math_8a');
      store.processResults('exam_math_8a');
      store.markCoordinatorVerified('exam_math_8a', verifiedBy: 'Coordinator');

      final pending = await adapter.submitForApproval(
        service: service,
        query: _query,
        examId: 'exam_math_8a',
        requesterId: 'teacher_001',
        requesterName: 'Priya Sharma',
      );
      expect(pending.status, ApprovalStatus.pending);

      final approved = await service.approveRequest(
        query: _query,
        request: ApproveApprovalRequest(
          approvalId: pending.id,
          actorId: 'principal_001',
          actorName: 'Principal',
        ),
      );
      adapter.onApproved(query: _query, request: approved);

      expect(
        store.examById('exam_math_8a')!.phase,
        ExamLifecyclePhase.published,
      );
      expect(store.hasPublishedResults, isTrue);
    });

    test('reject keeps exam unpublished and stores principal comment', () async {
      await completeMarks('exam_math_8a');
      store.processResults('exam_math_8a');
      store.markCoordinatorVerified('exam_math_8a', verifiedBy: 'Coordinator');

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
          comment: 'Recheck absent codes before resubmitting.',
        ),
      );
      adapter.onRejected(
        query: _query,
        request: rejected,
        comment: 'Recheck absent codes before resubmitting.',
      );

      expect(store.hasPublishedResults, isFalse);
      expect(
        store.rejectionCommentFor('exam_math_8a'),
        'Recheck absent codes before resubmitting.',
      );
      expect(store.isCoordinatorVerified('exam_math_8a'), isFalse);
    });

    test('blocks principal submission until coordinator verifies', () async {
      await completeMarks('exam_math_8a');
      store.processResults('exam_math_8a');

      expect(
        () => adapter.submitForApproval(
          service: service,
          query: _query,
          examId: 'exam_math_8a',
          requesterId: 'teacher_001',
          requesterName: 'Priya Sharma',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('teacher verify → coordinator verify → principal approve chain', () async {
      await completeMarks('exam_math_8a');
      store.processResults('exam_math_8a');
      expect(store.examById('exam_math_8a')!.phase, ExamLifecyclePhase.processed);

      store.markCoordinatorVerified('exam_math_8a', verifiedBy: 'Vice Principal');
      expect(store.isCoordinatorVerified('exam_math_8a'), isTrue);

      final pending = await adapter.submitForApproval(
        service: service,
        query: _query,
        examId: 'exam_math_8a',
        requesterId: 'teacher_001',
        requesterName: 'Priya Sharma',
      );

      final approved = await service.approveRequest(
        query: _query,
        request: ApproveApprovalRequest(
          approvalId: pending.id,
          actorId: 'principal_001',
          actorName: 'Principal',
        ),
      );
      adapter.onApproved(query: _query, request: approved);

      expect(
        store.examById('exam_math_8a')!.phase,
        ExamLifecyclePhase.published,
      );
    });
  });
}
