import 'package:akshara_erp/core/repositories/mock/mock_teacher_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_teacher_write_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:akshara_erp/features/teacher/teacher_requests.dart';
import 'package:flutter_test/flutter_test.dart';

/// Teacher attendance submit persistence (mock layer).
void main() {
  group('Teacher attendance E2E (mock repository)', () {
    const query = RepositoryQuery.demo;
    const classId = 'class-8a-p1';
    late MockTeacherRepository teacher;

    setUp(() {
      teacher = MockTeacherRepository();
      MockTeacherWriteStore.instance.attendanceDrafts.clear();
      MockTeacherWriteStore.instance.submittedClasses.clear();
    });

    test('submitClassAttendance marks class as submitted', () async {
      final studentsByClass =
          await teacher.getAttendanceStudentsByClass(query: query);
      final roster = studentsByClass[classId];
      expect(roster, isNotNull);
      expect(roster!, isNotEmpty);

      final entries = [
        for (final student in roster)
          TeacherAttendanceMarkEntry(
            studentId: student.id,
            mark: StudentAttendanceMark.present,
          ),
      ];

      final result = await teacher.submitClassAttendance(
        query: query,
        request: TeacherAttendanceSubmitRequest(
          classId: classId,
          entries: entries,
        ),
      );

      expect(result.classId, classId);
      expect(result.presentCount, entries.length);
      expect(
        MockTeacherWriteStore.instance.submittedClasses.contains(classId),
        isTrue,
      );
      expect(
        MockTeacherWriteStore.instance.attendanceDrafts[classId]?.length,
        entries.length,
      );
    });
  });
}
