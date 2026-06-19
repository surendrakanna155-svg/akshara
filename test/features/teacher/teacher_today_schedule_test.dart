import 'package:akshara_erp/core/teaching/teacher_assignment_registry.dart';
import 'package:akshara_erp/core/timetable/mock_daily_timetable_store.dart';
import 'package:akshara_erp/features/teacher/communication/teacher_teaching_context_provider.dart';
import 'package:akshara_erp/features/teacher/timetable/teacher_today_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  setUp(MockDailyTimetableStore.instance.reset);

  test("a covering teacher sees the assigned class in today's schedule", () {
    // Priya on leave → Rao covers her 8-A Period 1 Maths.
    MockDailyTimetableStore.instance.setOnLeave('HR-EMP-101', true);
    MockDailyTimetableStore.instance.prepareToday();

    final container = createMobileProviderTestContainer(overrides: [
      teacherTeachingContextOverrideProvider.overrideWith(
        (ref) => TeacherAssignmentRegistry.resolveContext(
          teacherId: TeacherAssignmentRegistry.mrsRaoId, // HR-EMP-102
          teacherName: 'Mrs. Rao',
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final today = container.read(teacherTodayScheduleProvider);
    final covering = today.where((p) => p.isSubstitute).toList();
    expect(
      covering.any((p) => p.classLabel == '8-A' && p.subject == 'Mathematics'),
      isTrue,
    );
  });
}
