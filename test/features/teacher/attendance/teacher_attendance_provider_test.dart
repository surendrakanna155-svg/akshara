import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('teacherAttendance providers', () {
    test('teacherAttendanceProvider exposes mock roster for Priya Sharma', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(teacherAttendanceProvider);

      expect(data.classes, isNotEmpty);
      expect(data.students, isNotEmpty);
      expect(data.selectedClassId, 'class-8a-p1');
      expect(data.unmarkedCount, greaterThan(0));
    });

    test('teacherAttendanceClassProvider switches class roster', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(teacherAttendanceClassProvider.notifier).state =
          'class-9b-p3';
      final data = container.read(teacherAttendanceProvider);

      expect(data.selectedClassId, 'class-9b-p3');
      expect(data.students, isNotEmpty);
    });

    test('teacherAttendanceEmptyProvider clears classes and students', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(teacherAttendanceEmptyProvider.notifier).state = true;
      final data = container.read(teacherAttendanceProvider);

      expect(data.classes, isEmpty);
      expect(data.students, isEmpty);
    });

    test('draft and submit flags update attendance payload', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(teacherAttendanceDraftSavedProvider.notifier).state =
          'Saved 10:30';
      container.read(teacherAttendanceSubmittedProvider.notifier).state =
          true;

      final data = container.read(teacherAttendanceProvider);

      expect(data.draftSavedAt, 'Saved 10:30');
      expect(data.isSubmitted, isTrue);
    });

    test('attendance KPI counts derive from student marks', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(teacherAttendanceProvider);

      expect(data.presentCount + data.absentCount + data.lateCount, lessThanOrEqualTo(data.students.length));
      expect(
        data.students.any((s) => s.mark == StudentAttendanceMark.present),
        isTrue,
      );
    });
  });
}
