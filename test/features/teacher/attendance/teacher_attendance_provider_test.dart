import 'package:akshara_erp/core/repositories/mock/mock_attendance_sync_store.dart';
import 'package:akshara_erp/core/teaching/teacher_assignment_registry.dart';
import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_provider.dart';
import 'package:akshara_erp/features/teacher/communication/teacher_teaching_context_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

// Pin the class teacher (Priya = 8-A) so attendance-class scoping is deterministic.
final _priyaContext = teacherTeachingContextOverrideProvider.overrideWith(
  (ref) => TeacherAssignmentRegistry.resolveContext(
    teacherId: TeacherAssignmentRegistry.priyaSharmaId,
    teacherName: 'Priya Sharma',
  ),
);

ProviderContainer _container() =>
    createMobileProviderTestContainer(overrides: [_priyaContext]);

Future<void> _awaitTeacherAttendance(ProviderContainer container) async {
  await container.read(teacherAttendanceClassesFutureProvider.future);
  await container.read(teacherAttendanceStudentsFutureProvider.future);
}

void main() {
  group('teacherAttendance providers', () {
    test('teacherAttendanceProvider exposes mock roster for Priya Sharma', () async {
      final container = _container();
      addTearDown(container.dispose);

      await _awaitTeacherAttendance(container);
      final data = container.read(teacherAttendanceProvider);

      expect(data.classes, isNotEmpty);
      expect(data.students, isNotEmpty);
      expect(data.selectedClassId, 'class-8a-p1');
      expect(data.unmarkedCount, greaterThan(0));
    });

    test('teacherAttendanceClassProvider switches class roster', () async {
      final container = _container();
      addTearDown(container.dispose);

      await _awaitTeacherAttendance(container);
      container.read(teacherAttendanceClassProvider.notifier).state =
          'class-9b-p3';
      final data = container.read(teacherAttendanceProvider);

      expect(data.selectedClassId, 'class-9b-p3');
      expect(data.students, isNotEmpty);
    });

    test('teacherAttendanceEmptyProvider clears classes and students', () async {
      final container = _container();
      addTearDown(container.dispose);

      container.read(teacherAttendanceEmptyProvider.notifier).state = true;
      final data = container.read(teacherAttendanceProvider);

      expect(data.classes, isEmpty);
      expect(data.students, isEmpty);
    });

    test('draft and submit flags update attendance payload', () async {
      final container = _container();
      addTearDown(container.dispose);

      await _awaitTeacherAttendance(container);
      container.read(teacherAttendanceDraftSavedProvider.notifier).state =
          'Saved 10:30';
      container.read(teacherAttendanceSubmittedProvider.notifier).state =
          true;

      final data = container.read(teacherAttendanceProvider);

      expect(data.draftSavedAt, 'Saved 10:30');
      expect(data.isSubmitted, isTrue);
    });

    test('attendance KPI counts derive from student marks', () async {
      final container = _container();
      addTearDown(container.dispose);

      await _awaitTeacherAttendance(container);
      final data = container.read(teacherAttendanceProvider);

      expect(data.presentCount + data.absentCount + data.lateCount, lessThanOrEqualTo(data.students.length));
      expect(
        data.students.any((s) => s.mark == StudentAttendanceMark.present),
        isTrue,
      );
    });

    test('isSubmitted reflects teacher submission in sync store', () async {
      MockAttendanceSyncStore.instance.reset();
      final container = _container();
      addTearDown(() {
        MockAttendanceSyncStore.instance.reset();
        container.dispose();
      });

      await _awaitTeacherAttendance(container);
      expect(container.read(teacherAttendanceProvider).isSubmitted, isFalse);

      MockAttendanceSyncStore.instance.recordTeacherSubmit(
        present: 10,
        absent: 2,
        late: 1,
      );
      expect(container.read(teacherAttendanceProvider).isSubmitted, isTrue);
    });
  });
}
