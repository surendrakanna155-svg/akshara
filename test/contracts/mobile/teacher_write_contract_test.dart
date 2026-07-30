import 'package:akshara_erp/core/repositories/api/teacher/dto/teacher_write_request_dto.dart';
import 'package:akshara_erp/core/repositories/interfaces/teacher_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_teacher_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:akshara_erp/features/teacher/leave/leave_models.dart';
import 'package:akshara_erp/features/teacher/teacher_requests.dart';
import 'package:flutter_test/flutter_test.dart';

const kQuery = RepositoryQuery.demo;

void main() {
  group('Teacher write DTO serialization', () {
    test('attendance draft request serializes class and entries', () {
      final json = TeacherAttendanceDraftRequestDto.fromDomain(
        const TeacherAttendanceDraftRequest(
          classId: 'class-8a-p1',
          entries: [
            TeacherAttendanceMarkEntry(
              studentId: 's1',
              mark: StudentAttendanceMark.present,
            ),
          ],
        ),
      ).toJson();
      expect(json['class_id'], 'class-8a-p1');
      expect((json['entries'] as List).first['mark'], 'present');
    });

    test('homework create request serializes due_date (HWK-1) in snake_case', () {
      final json = TeacherHomeworkCreateRequestDto.fromDomain(
        const TeacherHomeworkCreateRequest(
          classLabel: '8-A',
          subject: 'Mathematics',
          title: 'Algebra worksheet',
          dueDate: '2026-07-10',
        ),
      ).toJson();
      expect(json['class_label'], '8-A');
      expect(json['subject'], 'Mathematics');
      expect(json['title'], 'Algebra worksheet');
      expect(json['due_date'], '2026-07-10');
      // No explicit label → omitted so the backend derives it from due_date.
      expect(json.containsKey('due_label'), isFalse);
      // No student name → whole-class delivery (key omitted).
      expect(json.containsKey('student_name'), isFalse);
      // PRA-P1-30 — no attachment uploaded → storage path key omitted.
      expect(json.containsKey('attachment_storage_path'), isFalse);
    });

    test('PRA-P1-30 homework create serializes attachment_storage_path when set',
        () {
      final json = TeacherHomeworkCreateRequestDto.fromDomain(
        const TeacherHomeworkCreateRequest(
          classLabel: '8-A',
          subject: 'Mathematics',
          title: 'Algebra worksheet',
          dueDate: '2026-07-10',
          attachmentName: 'worksheet.pdf',
          attachmentStoragePath: 'org/school/teacher-1/uuid_worksheet.pdf',
        ),
      ).toJson();
      expect(json['attachment_name'], 'worksheet.pdf');
      expect(json['attachment_storage_path'],
          'org/school/teacher-1/uuid_worksheet.pdf');
    });

    test('homework create request keeps an explicit due_label + student_name', () {
      final json = TeacherHomeworkCreateRequestDto.fromDomain(
        const TeacherHomeworkCreateRequest(
          classLabel: '8-A',
          subject: 'Mathematics',
          title: 'Algebra worksheet',
          dueDate: '2026-07-10',
          dueLabel: 'Due 10 Jul 2026',
          studentName: 'Asha Rao',
        ),
      ).toJson();
      expect(json['due_date'], '2026-07-10');
      expect(json['due_label'], 'Due 10 Jul 2026');
      expect(json['student_name'], 'Asha Rao');
    });

    test('homework review request serializes grade and comment', () {
      final json = TeacherHomeworkReviewRequestDto.fromDomain(
        const TeacherHomeworkReviewRequest(
          submissionId: 'sub_1',
          grade: 'A',
          comment: 'Well done',
        ),
      ).toJson();
      expect(json['grade'], 'A');
      expect(json['comment'], 'Well done');
    });

    test('leave submit request serializes type label', () {
      final json = TeacherLeaveSubmitRequestDto.fromDomain(
        const TeacherLeaveSubmitRequest(
          typeLabel: 'Casual leave',
          fromDateLabel: '18 Jun 2026',
          toDateLabel: '18 Jun 2026',
          reason: 'Personal appointment.',
        ),
      ).toJson();
      expect(json['type_label'], 'Casual leave');
    });
  });

  group('Mock teacher write repository', () {
    late MockTeacherRepository repo;

    setUp(() {
      repo = MockTeacherRepository();
    });

    test('implements all write methods on TeacherRepository', () {
      expect(repo, isA<TeacherRepository>());
    });

    test('submitLeaveRequest returns persisted leave in getLeaveHistory', () async {
      final created = await repo.submitLeaveRequest(
        query: kQuery,
        request: const TeacherLeaveSubmitRequest(
          typeLabel: 'Casual leave',
          fromDateLabel: '18 Jun 2026',
          toDateLabel: '18 Jun 2026',
          reason: 'Personal appointment in the afternoon.',
        ),
      );
      final history = await repo.getLeaveHistory(query: kQuery);
      expect(history.any((item) => item.id == created.id), isTrue);
      expect(created.status, TeacherLeaveStatus.pending);
    });

    test('saveAttendanceDraft updates students returned by getAttendanceStudentsByClass',
        () async {
      await repo.saveAttendanceDraft(
        query: kQuery,
        request: const TeacherAttendanceDraftRequest(
          classId: 'class-8a-p1',
          entries: [
            TeacherAttendanceMarkEntry(
              studentId: 's5',
              mark: StudentAttendanceMark.present,
            ),
          ],
        ),
      );
      final students = await repo.getAttendanceStudentsByClass(query: kQuery);
      final row = students['class-8a-p1']!.firstWhere((s) => s.id == 's5');
      expect(row.mark, StudentAttendanceMark.present);
    });

    test('updateExamMark persists mark in getExamMarks', () async {
      final updated = await repo.updateExamMark(
        query: kQuery,
        request: const TeacherExamMarkUpdateRequest(
          markEntryId: 'exam_math_8a_03',
          marksObtained: 40,
        ),
      );
      final marks = await repo.getExamMarks(query: kQuery);
      expect(updated.marksObtained, 40);
      expect(
        marks.firstWhere((m) => m.id == 'exam_math_8a_03').marksObtained,
        40,
      );
    });
  });
}
