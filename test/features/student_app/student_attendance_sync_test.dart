import 'package:akshara_erp/core/repositories/mock/mock_attendance_sync_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_student_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const query = RepositoryQuery.demo;
  final june = DateTime(2026, 6);

  setUp(() => MockAttendanceSyncStore.instance.reset());

  test("student attendance reflects the teacher's submission", () async {
    final repo = MockStudentRepository();

    // No submission yet → static sample.
    final before = await repo.getAttendance(query: query, month: june);

    // Teacher marks the class: 17 present, 3 absent → 85%.
    MockAttendanceSyncStore.instance
        .recordTeacherSubmit(present: 17, absent: 3, late: 0);

    final after = await repo.getAttendance(query: query, month: june);
    expect(after.kpi.attendancePercent, 85); // 17 / 20
    expect(after.kpi.absentDays, 3);
    expect(after.kpi.attendancePercent, isNot(before.kpi.attendancePercent));
  });
}
