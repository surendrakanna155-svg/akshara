import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/attendance/attendance_sync_bridge.dart';
import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/mock/mock_attendance_sync_store.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../communication/teacher_teaching_context_provider.dart';
import '../teacher_mutations_provider.dart';
import '../teacher_requests.dart';
import 'attendance_models.dart';

final teacherAttendanceClassProvider = StateProvider<String>(
  (ref) => 'class-8a-p1',
);

final teacherAttendanceLoadingProvider = StateProvider<bool>((ref) => false);
final teacherAttendanceErrorProvider = StateProvider<bool>((ref) => false);
final teacherAttendanceEmptyProvider = StateProvider<bool>((ref) => false);
final teacherAttendanceDraftSavedProvider = StateProvider<String?>((ref) => null);
final teacherAttendanceSubmittedProvider = StateProvider<bool>((ref) => false);

final attendanceSyncRevisionProvider = StateProvider<int>((ref) => 0);

final _attendanceSyncBridgeProvider = Provider<void>((ref) {
  onMockAttendanceSyncChanged = () {
    ref.read(attendanceSyncRevisionProvider.notifier).state =
        MockAttendanceSyncStore.revision;
  };
  ref.onDispose(() {
    if (onMockAttendanceSyncChanged != null) {
      onMockAttendanceSyncChanged = null;
    }
  });
});

final teacherAttendanceClassesFutureProvider =
    FutureProvider<List<TeacherAttendanceClass>>((ref) async {
  return ref.read(teacherRepositoryProvider).getAttendanceClasses(
        query: ref.watch(repositoryQueryProvider),
        teachingContext: ref.watch(resolvedTeacherTeachingContextProvider),
      );
});

final teacherAttendanceStudentsFutureProvider =
    FutureProvider<Map<String, List<TeacherAttendanceStudent>>>((ref) async {
  return ref.read(teacherRepositoryProvider).getAttendanceStudentsByClass(
        query: ref.watch(repositoryQueryProvider),
      );
});

final _teacherAttendanceStudentsProvider =
    StateProvider<Map<String, List<TeacherAttendanceStudent>>?>((ref) => null);

Map<String, List<TeacherAttendanceStudent>> _studentsMap(Ref ref) {
  final override = ref.watch(_teacherAttendanceStudentsProvider);
  if (override != null) return override;
  return ref.watch(teacherAttendanceStudentsFutureProvider).value ?? {};
}

final teacherAttendanceProvider = Provider<TeacherAttendanceData>((ref) {
  ref.watch(_attendanceSyncBridgeProvider);
  ref.watch(attendanceSyncRevisionProvider);
  if (ref.watch(teacherAttendanceEmptyProvider)) {
    return const TeacherAttendanceData(
      classes: [],
      students: [],
      selectedClassId: '',
      unreadNotifications: 1,
    );
  }

  final classId = ref.watch(teacherAttendanceClassProvider);
  final studentsMap = _studentsMap(ref);
  final students = studentsMap[classId] ?? const <TeacherAttendanceStudent>[];
  final classes = watchRepositoryFuture(
    ref,
    ref.watch(teacherAttendanceClassesFutureProvider),
    manualLoading: ref.watch(teacherAttendanceLoadingProvider),
    manualError: ref.watch(teacherAttendanceErrorProvider),
    manualEmpty: ref.watch(teacherAttendanceEmptyProvider),
  ) ??
      ref.watch(teacherAttendanceClassesFutureProvider).value ??
      const <TeacherAttendanceClass>[];

  return TeacherAttendanceData(
    classes: classes,
    students: students,
    selectedClassId: classId,
    unreadNotifications: 1,
    draftSavedAt: ref.watch(teacherAttendanceDraftSavedProvider),
    isSubmitted: ref.watch(teacherAttendanceSubmittedProvider) ||
        MockAttendanceSyncStore.instance.hasTeacherSubmission,
  );
});

void updateStudentMark(
  WidgetRef ref, {
  required String studentId,
  required StudentAttendanceMark mark,
}) {
  if (ref.read(teacherAttendanceProvider).isSubmitted) return;
  final classId = ref.read(teacherAttendanceClassProvider);
  final map = Map<String, List<TeacherAttendanceStudent>>.from(
    ref.read(_teacherAttendanceStudentsProvider) ??
        ref.read(teacherAttendanceStudentsFutureProvider).value ??
        {},
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
  if (ref.read(teacherAttendanceProvider).isSubmitted) return;
  final classId = ref.read(teacherAttendanceClassProvider);
  final map = Map<String, List<TeacherAttendanceStudent>>.from(
    ref.read(_teacherAttendanceStudentsProvider) ??
        ref.read(teacherAttendanceStudentsFutureProvider).value ??
        {},
  );
  final students = map[classId];
  if (students == null) return;
  map[classId] = [
    for (final student in students) student.copyWith(mark: mark),
  ];
  ref.read(_teacherAttendanceStudentsProvider.notifier).state = map;
}

/// Restore an in-progress attendance grid recovered from a local draft (Data
/// Reliability Platform §5): apply [marks] (studentId → mark) onto the current
/// roster for [classId] so the teacher resumes exactly where they left off.
void restoreAttendanceMarks(
  WidgetRef ref, {
  required String classId,
  required Map<String, StudentAttendanceMark> marks,
}) {
  if (ref.read(teacherAttendanceProvider).isSubmitted) return;
  final map = Map<String, List<TeacherAttendanceStudent>>.from(
    ref.read(_teacherAttendanceStudentsProvider) ??
        ref.read(teacherAttendanceStudentsFutureProvider).value ??
        {},
  );
  final students = map[classId];
  if (students == null) return;
  map[classId] = [
    for (final student in students)
      marks.containsKey(student.id)
          ? student.copyWith(mark: marks[student.id]!)
          : student,
  ];
  ref.read(_teacherAttendanceStudentsProvider.notifier).state = map;
}

Future<void> saveAttendanceDraft(WidgetRef ref) async {
  final classId = ref.read(teacherAttendanceClassProvider);
  final students = ref.read(teacherAttendanceProvider).students;
  final result = await ref
      .read(saveTeacherAttendanceDraftProvider.notifier)
      .execute(
        TeacherAttendanceDraftRequest(
          classId: classId,
          entries: [
            for (final student in students)
              TeacherAttendanceMarkEntry(
                studentId: student.id,
                mark: student.mark,
              ),
          ],
        ),
      );
  if (result != null) {
    ref.read(teacherAttendanceDraftSavedProvider.notifier).state =
        result.savedAtLabel;
  }
}

Future<bool> submitAttendance(WidgetRef ref) async {
  final data = ref.read(teacherAttendanceProvider);
  if (data.unmarkedCount > 0) return false;

  final result = await ref
      .read(submitTeacherClassAttendanceProvider.notifier)
      .execute(
        TeacherAttendanceSubmitRequest(
          classId: data.selectedClassId,
          entries: [
            for (final student in data.students)
              TeacherAttendanceMarkEntry(
                studentId: student.id,
                mark: student.mark,
              ),
          ],
        ),
      );

  if (result == null) return false;
  ref.read(teacherAttendanceSubmittedProvider.notifier).state = true;
  ref.read(teacherAttendanceDraftSavedProvider.notifier).state = null;
  return true;
}
