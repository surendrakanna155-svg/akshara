import 'package:akshara_erp/core/approvals/adapters/exam_results_approval_adapter.dart';
import 'package:akshara_erp/core/approvals/approval_center_service.dart';
import 'package:akshara_erp/core/approvals/approval_requests.dart';
import 'package:akshara_erp/core/approvals/approval_request_type.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';
import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_approval_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_canonical_student_registry.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_student_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_teacher_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/teacher/teacher_requests.dart';
import 'package:flutter_test/flutter_test.dart';

const _query = RepositoryQuery(tenantId: 'tenant_demo', schoolId: 'school_demo');

void main() {
  setUp(() {
    ExamAdministrationStore.instance.reset();
  });

  group('Exam administration chain', () {
    test('marks entry does not expose results until publish', () async {
      final teacherRepo = MockTeacherRepository();
      final studentRepo = MockStudentRepository();
      final parentRepo = MockParentRepository();
      final student = MockCanonicalStudentRegistry.primaryMobileStudent;

      final beforeStudent = await studentRepo.getExams(query: _query);
      final beforeParent = await parentRepo.getExams(query: _query);
      expect(beforeStudent.examResults, isEmpty);
      expect(beforeParent.examResults, isEmpty);
      expect(beforeStudent.upcomingExams, isNotEmpty);
      expect(beforeParent.upcomingExams, isNotEmpty);

      await teacherRepo.updateExamMark(
        query: _query,
        request: const TeacherExamMarkUpdateRequest(
          markEntryId: 'exam_math_8a_01',
          marksObtained: 44,
        ),
      );

      final midStudent = await studentRepo.getExams(query: _query);
      expect(midStudent.examResults, isEmpty);

      final publish = await teacherRepo.publishExamResults(
        query: _query,
        request: const TeacherExamPublishRequest(examId: 'exam_math_8a'),
      );
      expect(publish.publishedCount, greaterThan(0));

      final afterStudent = await studentRepo.getExams(query: _query);
      final afterParent = await parentRepo.getExams(query: _query);

      expect(afterStudent.examResults, isNotEmpty);
      expect(afterParent.examResults, isNotEmpty);

      final studentResult = afterStudent.examResults.firstWhere(
        (r) => r.id == 'exam_math_8a_01',
      );
      final parentResult = afterParent.examResults.firstWhere(
        (r) => r.id == 'exam_math_8a_01',
      );
      expect(studentResult.scoreObtained, 44);
      expect(parentResult.scoreObtained, 44);
      expect(studentResult.grade, parentResult.grade);
    });

    test('parent and student see identical published payloads', () async {
      final teacherRepo = MockTeacherRepository();
      final studentRepo = MockStudentRepository();
      final parentRepo = MockParentRepository();

      await teacherRepo.publishExamResults(
        query: _query,
        request: const TeacherExamPublishRequest(examId: 'exam_math_8a'),
      );

      final studentData = await studentRepo.getExams(query: _query);
      final parentData = await parentRepo.getExams(query: _query);

      expect(studentData.examResults.length, parentData.examResults.length);
      for (var i = 0; i < studentData.examResults.length; i++) {
        final s = studentData.examResults[i];
        final p = parentData.examResults[i];
        expect(s.id, p.id);
        expect(s.scoreObtained, p.scoreObtained);
        expect(s.maxScore, p.maxScore);
        expect(s.grade, p.grade);
      }
    });

    test('approval gate blocks parent visibility until principal approves',
        () async {
      final store = ExamAdministrationStore.instance;
      final teacherRepo = MockTeacherRepository();
      final parentRepo = MockParentRepository();
      final approvalRepo = MockApprovalRepository();
      final service = ApprovalCenterService(approvalRepo);
      final adapter = ExamResultsApprovalAdapter(store: store);

      await teacherRepo.updateExamMark(
        query: _query,
        request: const TeacherExamMarkUpdateRequest(
          markEntryId: 'exam_math_8a_06',
          marksObtained: 44,
        ),
      );

      final pending = await adapter.submitForApproval(
        service: service,
        query: _query,
        examId: 'exam_math_8a',
        requesterId: 'teacher_001',
        requesterName: 'Priya Sharma',
      );
      expect(pending.type, ApprovalRequestType.examResults);
      expect(pending.status, ApprovalStatus.pending);

      final gatedParent = await parentRepo.getExams(query: _query);
      expect(gatedParent.examResults, isEmpty);

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
    });
  });
}
