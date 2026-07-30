import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/communication/parent_communication_models.dart';
import 'package:akshara_erp/core/communication/parent_communication_store.dart';
import 'package:akshara_erp/core/communication/teacher_parent_templates.dart';
import 'package:akshara_erp/core/i18n/content_localization.dart';
import 'package:akshara_erp/core/i18n/supported_languages.dart';
import 'package:akshara_erp/core/i18n/translation_service.dart';
import 'package:akshara_erp/core/repositories/mock/mock_canonical_student_registry.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/repositories/mock/mock_attendance_sync_store.dart';
import 'package:akshara_erp/core/teaching/teacher_assignment_registry.dart';
import 'package:akshara_erp/core/repositories/mock/mock_student_risk_fixtures.dart';

void main() {
  setUp(() {
    ParentCommunicationStore.instance.reset();
  });

  group('Parent communication inbox', () {
    test('send receive read acknowledge lifecycle', () async {
      final repo = MockParentRepository();
      const query = RepositoryQuery.demo;
      const childId = 'child_ravi';
      final studentId = MockCanonicalStudentRegistry.primaryMobileStudentId;

      final sendResult = ParentCommunicationStore.instance.send(
        request: ParentCommunicationSendRequest(
          sisStudentId: studentId,
          reason: ParentCommunicationReason.attendanceLow,
          tone: ParentCommunicationTone.polite,
          channels: {ParentCommunicationChannel.inApp},
        ),
        senderName: 'Priya Sharma',
      );

      var inbox = await repo.getCommunicationInbox(
        query: query,
        activeChildId: childId,
      );
      expect(inbox, hasLength(1));
      expect(inbox.first.id, sendResult.record.id);
      expect(inbox.first.isUnread, isTrue);
      expect(inbox.first.displayBody, isNotEmpty);

      await repo.markCommunicationRead(
        query: query,
        communicationId: sendResult.record.id,
      );
      inbox = await repo.getCommunicationInbox(query: query, activeChildId: childId);
      expect(inbox.first.deliveryStatus, ParentCommunicationDeliveryStatus.read);

      await repo.acknowledgeCommunication(
        query: query,
        communicationId: sendResult.record.id,
      );
      inbox = await repo.getCommunicationInbox(query: query, activeChildId: childId);
      expect(inbox.first.deliveryStatus,
          ParentCommunicationDeliveryStatus.acknowledged);
      expect(inbox.first.isUnread, isFalse);
    });
  });

  group('Translation rollout', () {
    test('notice translation uses dictionary not prefix stubs', () {
      const english = 'PTM scheduled for 15 June — please confirm your slot';
      final translated = TranslationService.instance.translate(
        englishText: english,
        target: AksharaLanguage.telugu,
      );
      expect(translated, isNot(english));
      expect(translated.contains('[TE]'), isFalse);
    });

    test('homework translation for parent payload', () async {
      final repo = MockParentRepository();
      ParentCommunicationStore.instance.setPreferredLanguage(
        sisStudentId: MockCanonicalStudentRegistry.primaryMobileStudentId,
        language: AksharaLanguage.telugu,
      );
      final homework = await repo.getHomework(query: RepositoryQuery.demo);
      expect(
        homework.items.first.title,
        isNot('Exercise 5.2 - Solve Q1 to Q8'),
      );
    });

    test('announcement translation via content localization', () {
      final localized = ContentLocalization.localize(
        'School holiday — Eid',
        AksharaLanguage.hindi,
      );
      expect(localized, isNot('School holiday — Eid'));
    });
  });

  group('HR/SIS teacher assignment resolution', () {
    test('class teacher resolution for grade 8 section A', () {
      final record = TeacherAssignmentRegistry.classTeacherForClass('8', 'A');
      expect(record?.teacherName, 'Priya Sharma');
      expect(record?.teacherId, TeacherAssignmentRegistry.priyaSharmaId);

      final context = TeacherAssignmentRegistry.resolveContext(
        teacherId: record!.teacherId,
        teacherName: record.teacherName,
      );
      expect(context.isClassTeacher, isTrue);
      expect(context.classTeacherClassLabel, '8-A');
    });

    test('subject teacher resolution and escalation eligibility', () {
      final context = TeacherAssignmentRegistry.resolveContext(
        teacherId: TeacherAssignmentRegistry.mrPatelId,
        teacherName: 'Mr. Patel',
        preferSubjectTeacherRole: true,
      );
      expect(context.isClassTeacher, isFalse);
      expect(context.primarySubject, 'Science');
      expect(context.teachingClassLabels, contains('8-A'));

      final student = MockCanonicalStudentRegistry.primaryMobileStudent;
      expect(context.teachesStudent(student), isTrue);
    });
  });

  group('Attendance sync risk integration', () {
    test('student risk snapshot uses MockAttendanceSyncStore percent', () {
      MockAttendanceSyncStore.instance.reset();
      MockAttendanceSyncStore.instance.recordTeacherSubmit(
        present: 18,
        absent: 2,
        late: 0,
      );

      final snap = MockStudentRiskFixtures.snapshotForStudent(
        MockCanonicalStudentRegistry.primaryMobileStudentId,
      );

      expect(snap.attendancePercent, 90);
    });
  });
}
