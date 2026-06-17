import 'package:akshara_erp/core/approvals/adapters/exam_results_approval_adapter.dart';
import 'package:akshara_erp/core/approvals/approval_center_service.dart';
import 'package:akshara_erp/core/approvals/approval_request_type.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';
import 'package:akshara_erp/core/errors/api_failure.dart';
import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_approval_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_canonical_student_registry.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

const _query = RepositoryQuery(tenantId: 'tenant_demo', schoolId: 'school_demo');

void main() {
  group('ExamResultsApprovalAdapter — M-D3', () {
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

    Future<void> completeAllMarks(String examId) async {
      for (final mark in store.marksForExam(examId)) {
        if (mark.marksObtained == null) {
          store.recordMark(
            markEntryId: mark.id,
            marksObtained: 35,
          );
        }
      }
    }

    test('submit builds examResults approval with exam_session entity', () async {
      await completeAllMarks('exam_math_8a');

      final approval = await adapter.submitForApproval(
        service: service,
        query: _query,
        examId: 'exam_math_8a',
        requesterId: 'teacher_001',
        requesterName: 'Priya Sharma',
      );

      expect(approval.type, ApprovalRequestType.examResults);
      expect(approval.entityType, ExamResultsApprovalAdapter.entityType);
      expect(approval.entityId, 'exam_math_8a');
      expect(approval.status, ApprovalStatus.pending);
      expect(approval.payload['subject'], 'Mathematics');
    });

    test('submit blocked when marks incomplete', () async {
      expect(
        () => adapter.submitForApproval(
          service: service,
          query: _query,
          examId: 'exam_math_8a',
          requesterId: 'teacher_001',
          requesterName: 'Priya Sharma',
        ),
        throwsA(isA<ApiFailureException>()),
      );
    });

    test('submit deduplicates pending request for same exam', () async {
      await completeAllMarks('exam_math_8a');

      final first = await adapter.submitForApproval(
        service: service,
        query: _query,
        examId: 'exam_math_8a',
        requesterId: 'teacher_001',
        requesterName: 'Priya Sharma',
      );
      final second = await adapter.submitForApproval(
        service: service,
        query: _query,
        examId: 'exam_math_8a',
        requesterId: 'teacher_001',
        requesterName: 'Priya Sharma',
      );

      expect(first.id, second.id);
    });

    test('onApproved publishes results to store', () async {
      await completeAllMarks('exam_math_8a');
      store.processResults('exam_math_8a');

      final approval = await adapter.submitForApproval(
        service: service,
        query: _query,
        examId: 'exam_math_8a',
        requesterId: 'teacher_001',
        requesterName: 'Priya Sharma',
      );

      adapter.onApproved(query: _query, request: approval);

      expect(
        store.examById('exam_math_8a')!.phase,
        ExamLifecyclePhase.published,
      );
      expect(
        store.resultsForStudent(
          MockCanonicalStudentRegistry.primaryMobileStudentId,
        ),
        isNotEmpty,
      );
    });

    test('onRejected records comment and keeps exam unpublished', () async {
      await completeAllMarks('exam_math_8a');
      final approval = await adapter.submitForApproval(
        service: service,
        query: _query,
        examId: 'exam_math_8a',
        requesterId: 'teacher_001',
        requesterName: 'Priya Sharma',
      );

      adapter.onRejected(
        query: _query,
        request: approval,
        comment: 'Please verify absentee marks.',
      );

      expect(
        store.examById('exam_math_8a')!.phase,
        ExamLifecyclePhase.processed,
      );
      expect(
        store.rejectionCommentFor('exam_math_8a'),
        'Please verify absentee marks.',
      );
      expect(store.resultsForStudent(
        MockCanonicalStudentRegistry.primaryMobileStudentId,
      ), isEmpty);
    });

    test('enrichDetail includes marks completion', () async {
      await completeAllMarks('exam_math_8a');
      final approval = await adapter.submitForApproval(
        service: service,
        query: _query,
        examId: 'exam_math_8a',
        requesterId: 'teacher_001',
        requesterName: 'Priya Sharma',
      );

      final detail = adapter.enrichDetail(approval);
      expect(detail['Class'], '8-A');
      expect(detail['Subject'], 'Mathematics');
      expect(detail['Marks completion'], contains('/'));
    });
  });
}
