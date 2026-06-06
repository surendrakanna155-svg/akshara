import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'attendance_models.dart';

final teacherAttendanceClassProvider = StateProvider<String>(
  (ref) => 'class-8a-p1',
);

final teacherAttendanceLoadingProvider = StateProvider<bool>((ref) => false);
final teacherAttendanceErrorProvider = StateProvider<bool>((ref) => false);
final teacherAttendanceEmptyProvider = StateProvider<bool>((ref) => false);
final teacherAttendanceDraftSavedProvider = StateProvider<String?>((ref) => null);
final teacherAttendanceSubmittedProvider = StateProvider<bool>((ref) => false);

final _teacherAttendanceStudentsProvider =
    StateProvider<Map<String, List<TeacherAttendanceStudent>>>(
  (ref) => _mockStudentsByClass(),
);

final teacherAttendanceProvider = Provider<TeacherAttendanceData>((ref) {
  if (ref.watch(teacherAttendanceEmptyProvider)) {
    return const TeacherAttendanceData(
      classes: [],
      students: [],
      selectedClassId: '',
      unreadNotifications: 1,
    );
  }

  final classId = ref.watch(teacherAttendanceClassProvider);
  final studentsMap = ref.watch(_teacherAttendanceStudentsProvider);
  final students = studentsMap[classId] ?? const <TeacherAttendanceStudent>[];

  return TeacherAttendanceData(
    classes: _mockClasses(),
    students: students,
    selectedClassId: classId,
    unreadNotifications: 1,
    draftSavedAt: ref.watch(teacherAttendanceDraftSavedProvider),
    isSubmitted: ref.watch(teacherAttendanceSubmittedProvider),
  );
});

List<TeacherAttendanceClass> _mockClasses() {
  return const [
    TeacherAttendanceClass(
      id: 'class-8a-p1',
      label: '8-A',
      subject: 'Mathematics',
      periodLabel: 'Period 1',
      studentCount: 38,
      isPending: true,
    ),
    TeacherAttendanceClass(
      id: 'class-9b-p3',
      label: '9-B',
      subject: 'Mathematics',
      periodLabel: 'Period 3',
      studentCount: 36,
      isPending: false,
    ),
    TeacherAttendanceClass(
      id: 'class-8a-p5',
      label: '8-A',
      subject: 'Mathematics',
      periodLabel: 'Period 5',
      studentCount: 38,
      isPending: true,
    ),
  ];
}

Map<String, List<TeacherAttendanceStudent>> _mockStudentsByClass() {
  const students8a = [
    TeacherAttendanceStudent(id: 's1', name: 'Ravi Kumar', rollNo: '01', mark: StudentAttendanceMark.present),
    TeacherAttendanceStudent(id: 's2', name: 'Ananya Rao', rollNo: '02', mark: StudentAttendanceMark.present),
    TeacherAttendanceStudent(id: 's3', name: 'Karthik Menon', rollNo: '03', mark: StudentAttendanceMark.late),
    TeacherAttendanceStudent(id: 's4', name: 'Priya Nair', rollNo: '04', mark: StudentAttendanceMark.absent),
    TeacherAttendanceStudent(id: 's5', name: 'Arjun Das', rollNo: '05', mark: StudentAttendanceMark.unmarked),
    TeacherAttendanceStudent(id: 's6', name: 'Meera Iyer', rollNo: '06', mark: StudentAttendanceMark.unmarked),
  ];
  return {
    'class-8a-p1': students8a,
    'class-9b-p3': students8a,
    'class-8a-p5': students8a,
  };
}

void updateStudentMark(
  WidgetRef ref, {
  required String studentId,
  required StudentAttendanceMark mark,
}) {
  final classId = ref.read(teacherAttendanceClassProvider);
  final map = Map<String, List<TeacherAttendanceStudent>>.from(
    ref.read(_teacherAttendanceStudentsProvider),
  );
  final students = map[classId];
  if (students == null) return;
  map[classId] = [
    for (final student in students)
      student.id == studentId ? student.copyWith(mark: mark) : student,
  ];
  ref.read(_teacherAttendanceStudentsProvider.notifier).state = map;
}

void applyBulkMark(WidgetRef ref, StudentAttendanceMark mark) {
  final classId = ref.read(teacherAttendanceClassProvider);
  final map = Map<String, List<TeacherAttendanceStudent>>.from(
    ref.read(_teacherAttendanceStudentsProvider),
  );
  final students = map[classId];
  if (students == null) return;
  map[classId] = [
    for (final student in students) student.copyWith(mark: mark),
  ];
  ref.read(_teacherAttendanceStudentsProvider.notifier).state = map;
}

void saveAttendanceDraft(WidgetRef ref) {
  ref.read(teacherAttendanceDraftSavedProvider.notifier).state =
      'Saved ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
}

bool submitAttendance(WidgetRef ref) {
  final data = ref.read(teacherAttendanceProvider);
  if (data.unmarkedCount > 0) return false;
  ref.read(teacherAttendanceSubmittedProvider.notifier).state = true;
  ref.read(teacherAttendanceDraftSavedProvider.notifier).state = null;
  return true;
}
