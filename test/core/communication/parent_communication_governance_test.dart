import 'package:akshara_erp/core/communication/parent_communication_governance.dart';
import 'package:akshara_erp/core/communication/parent_communication_models.dart';
import 'package:akshara_erp/core/communication/teacher_parent_templates.dart';
import 'package:akshara_erp/core/communication/subject_teacher_concern_store.dart';
import 'package:akshara_erp/core/communication/teacher_student_risk_service.dart';
import 'package:akshara_erp/core/repositories/mock/mock_canonical_student_registry.dart';
import 'package:akshara_erp/core/repositories/mock/mock_teacher_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/teacher/teacher_requests.dart';
import 'package:flutter_test/flutter_test.dart';

const _query = RepositoryQuery(tenantId: 'tenant_demo', schoolId: 'school_demo');

void main() {
  setUp(() {
    SubjectTeacherConcernStore.instance.reset();
  });

  group('ParentCommunicationGovernance', () {
    final classTeacher = TeacherTeachingContext.demoClassTeacher();
    final subjectTeacher = TeacherTeachingContext.demoSubjectTeacher();
    final student = MockCanonicalStudentRegistry.primaryMobileStudent;

    test('class teacher can send parent communication for own class', () {
      expect(
        ParentCommunicationGovernance.canSendParentCommunication(
          classTeacher,
          student,
        ),
        isTrue,
      );
    });

    test('subject teacher cannot send parent communication directly', () {
      expect(
        ParentCommunicationGovernance.canSendParentCommunication(
          subjectTeacher,
          student,
        ),
        isFalse,
      );
    });

    test('subject teacher can flag concern for taught class', () {
      expect(
        ParentCommunicationGovernance.canFlagConcern(subjectTeacher, student),
        isTrue,
      );
    });
  });

  group('Escalation flow', () {
    final repo = MockTeacherRepository();
    final classTeacher = TeacherTeachingContext.demoClassTeacher();
    final subjectTeacher = TeacherTeachingContext.demoSubjectTeacher();
    final student = MockCanonicalStudentRegistry.primaryMobileStudent;

    test('subject teacher flag → class teacher send with audit trail', () async {
      final flag = await repo.flagSubjectConcern(
        query: _query,
        request: const TeacherSubjectConcernFlagRequest(
          sisStudentId: MockCanonicalStudentRegistry.primaryMobileStudentId,
          category: SubjectConcernCategory.lowMarks,
          observation: 'Unit test score below 40%.',
        ),
        teachingContext: subjectTeacher,
      );
      expect(flag.concern.isPending, isTrue);
      expect(flag.concern.auditTrail, isNotEmpty);

      await expectLater(
        repo.sendParentCommunication(
          query: _query,
          request: TeacherParentCommunicationSendRequest(
            sisStudentId: student.sisStudentId,
            reason: SubjectConcernCategory.lowMarks.suggestedReason,
            tone: ParentCommunicationTone.encouragement,
            channels: {ParentCommunicationChannel.inApp},
            sourceConcernId: flag.concern.id,
          ),
          teachingContext: subjectTeacher,
        ),
        throwsA(isA<ParentCommunicationGovernanceException>()),
      );

      final send = await repo.sendParentCommunication(
        query: _query,
        request: TeacherParentCommunicationSendRequest(
          sisStudentId: student.sisStudentId,
          reason: SubjectConcernCategory.lowMarks.suggestedReason,
          tone: ParentCommunicationTone.encouragement,
          channels: {ParentCommunicationChannel.inApp},
          sourceConcernId: flag.concern.id,
        ),
        teachingContext: classTeacher,
      );
      expect(send.record.sourceConcernId, flag.concern.id);

      final resolved = SubjectTeacherConcernStore.instance.byId(flag.concern.id);
      expect(resolved?.status, SubjectConcernStatus.sentToParent);
      expect(resolved?.auditTrail.length, greaterThan(1));
    });
  });

  group('Student risk identification', () {
    test('class teacher attention list identifies at-risk students', () {
      final items = TeacherStudentRiskService.attentionForClass(
        TeacherTeachingContext.demoClassTeacher(),
      );
      expect(items, isNotEmpty);
      expect(items.first.sisStudentId, isNotEmpty);
      expect(items.first.suggestedReason, isNotNull);
    });

    test('student 360 snapshot includes required domains', () {
      final snap = TeacherStudentRiskService.snapshotForStudent(
        MockCanonicalStudentRegistry.primaryMobileStudentId,
      );
      expect(snap.attendancePercent, greaterThan(0));
      expect(snap.subjectPerformance, isNotEmpty);
      expect(snap.homeworkCompletionPercent, greaterThan(0));
      expect(snap.feePendingLabel, isNotEmpty);
    });
  });
}
