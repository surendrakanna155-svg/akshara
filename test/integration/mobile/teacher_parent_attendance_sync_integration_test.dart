import 'package:akshara_erp/core/repositories/mock/mock_attendance_sync_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_teacher_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_teacher_write_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:akshara_erp/features/teacher/teacher_requests.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Teacher → parent attendance sync (mock)', () {
    const query = RepositoryQuery.demo;
    const classId = 'class-8a-p1';
    late MockTeacherRepository teacher;
    late MockParentRepository parent;

    setUp(() {
      teacher = MockTeacherRepository();
      parent = MockParentRepository();
      MockTeacherWriteStore.instance.attendanceDrafts.clear();
      MockTeacherWriteStore.instance.submittedClasses.clear();
      MockAttendanceSyncStore.instance.reset();
    });

    test('submit updates parent attendance KPI', () async {
      final roster = (await teacher.getAttendanceStudentsByClass(query: query))[classId]!;
      final entries = [
        for (final student in roster)
          TeacherAttendanceMarkEntry(
            studentId: student.id,
            mark: StudentAttendanceMark.present,
          ),
      ];

      await teacher.submitClassAttendance(
        query: query,
        request: TeacherAttendanceSubmitRequest(classId: classId, entries: entries),
      );

      final month = await parent.getAttendance(
        query: query,
        month: DateTime(2026, 6, 1),
      );

      expect(month.kpi.attendancePercent, 100);
      expect(month.kpi.absentDays, 0);
    });
  });
}
