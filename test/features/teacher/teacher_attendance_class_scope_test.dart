import 'package:akshara_erp/core/repositories/mock/mock_teacher_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/teaching/teacher_assignment_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const query = RepositoryQuery.demo;
  final repo = MockTeacherRepository();

  test('class teacher sees only their own class for attendance', () async {
    final priya = TeacherAssignmentRegistry.resolveContext(
      teacherId: TeacherAssignmentRegistry.priyaSharmaId,
      teacherName: 'Priya Sharma',
    );
    final classes = await repo.getAttendanceClasses(
      query: query,
      teachingContext: priya,
    );
    expect(classes, isNotEmpty);
    expect(classes.every((c) => c.label == '8-A'), isTrue); // Priya = 8-A CT
  });

  test('a subject teacher who is not a class teacher gets no attendance classes',
      () async {
    final patel = TeacherAssignmentRegistry.resolveContext(
      teacherId: TeacherAssignmentRegistry.mrPatelId,
      teacherName: 'Mr. Patel',
    );
    final classes = await repo.getAttendanceClasses(
      query: query,
      teachingContext: patel,
    );
    expect(classes, isEmpty);
  });
}
