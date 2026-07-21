import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_provider.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_screen.dart';
import 'package:akshara_erp/features/teacher/homework/teacher_homework_provider.dart';
import 'package:akshara_erp/features/teacher/homework/teacher_homework_screen.dart';
import 'package:akshara_erp/features/teacher/leave/teacher_leave_provider.dart';
import 'package:akshara_erp/features/teacher/leave/teacher_leave_screen.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW7 · QA-C-003 — Teacher app *behaviour* certification (Batch 2).
///
/// Sits ON TOP of the existing Teacher widget coverage which already proves
/// rendering + the 4 async states per screen:
///   • test/features/teacher/teacher_module_screens_test.dart   (Attendance
///     loading, Homework empty, Leave error, Exams/Messages/Conversation render)
///   • test/features/teacher/teacher_attendance_class_scope_test.dart
///   • test/features/teacher/teacher_marks_submit_test.dart   (marks write loop)
///   • test/features/teacher/teacher_today_schedule_test.dart
///
/// This cert asserts that representative interactive controls perform their
/// expected action: the "All present" bulk-mark clears the unmarked count and
/// FLIPS the submit CTA from disabled→enabled (a real roster state change), and
/// the roster search field narrows the list — plus the canonical 4 states.
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  if (settle) {
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  group('QA-C-003 · Teacher app — clickable behaviour', () {
    testWidgets('"All present" marks the roster and enables the submit CTA',
        (tester) async {
      await _pump(tester, const TeacherAttendanceScreen());

      // Before: the roster has unmarked students → the submit CTA shows the
      // outstanding count and is therefore NOT a plain "Submit".
      expect(find.text('All present'), findsOneWidget);
      expect(find.textContaining('unmarked'), findsOneWidget);
      final submitBefore = tester.widget<FilledButton>(
        find.byKey(QaTestKeys.teacherAttendanceSubmitButton),
      );
      expect(submitBefore.onPressed, isNull); // disabled while any are unmarked

      // Tap "All present" → because some rows are already marked, F-080's
      // destructive-bulk guard first asks to confirm the overwrite; confirming
      // then marks every student present.
      await tester.tap(find.text('All present'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Overwrite'));
      await tester.pumpAndSettle();

      // After: no students remain unmarked, the CTA reads "Submit" and is enabled.
      expect(find.textContaining('unmarked'), findsNothing);
      expect(find.text('Submit'), findsOneWidget);
      final submitAfter = tester.widget<FilledButton>(
        find.byKey(QaTestKeys.teacherAttendanceSubmitButton),
      );
      expect(submitAfter.onPressed, isNotNull); // now actionable
    });

    testWidgets('roster search field narrows the visible list',
        (tester) async {
      await _pump(tester, const TeacherAttendanceScreen());

      // A no-match query collapses the roster to its empty affordance.
      await tester.enterText(
        find.byKey(QaTestKeys.teacherAttendanceSearchField),
        'zzz-no-such-student',
      );
      await tester.pumpAndSettle();

      // The search applied — the roster narrowed to nothing matchable.
      expect(
        find.textContaining('No students'),
        findsOneWidget,
      );
    });
  });

  group('QA-C-003 · Teacher app — canonical 4 states render', () {
    testWidgets('SUCCESS — attendance screen settles into its data path',
        (tester) async {
      await _pump(tester, const TeacherAttendanceScreen());

      expect(find.text('Mark Attendance'), findsOneWidget);
      expect(find.byType(AksharaLoadingState), findsNothing);
      expect(find.byType(AksharaErrorState), findsNothing);
    });

    testWidgets('LOADING — attendance screen shows AksharaLoadingState',
        (tester) async {
      await _pump(
        tester,
        const TeacherAttendanceScreen(),
        overrides: [
          teacherAttendanceLoadingProvider.overrideWith((ref) => true),
        ],
        settle: false,
      );

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('EMPTY — homework screen shows AksharaEmptyState',
        (tester) async {
      await _pump(
        tester,
        const TeacherHomeworkScreen(),
        overrides: [teacherHomeworkEmptyProvider.overrideWith((ref) => true)],
      );

      expect(find.byType(AksharaEmptyState), findsOneWidget);
    });

    testWidgets('ERROR — leave screen shows AksharaErrorState',
        (tester) async {
      await _pump(
        tester,
        const TeacherLeaveScreen(),
        overrides: [teacherLeaveErrorProvider.overrideWith((ref) => true)],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });
  });
}
