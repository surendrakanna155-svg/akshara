import 'package:akshara_erp/features/student_app/attendance/student_attendance_provider.dart';
import 'package:akshara_erp/features/student_app/attendance/student_attendance_screen.dart';
import 'package:akshara_erp/features/student_app/exams/exam_models.dart';
import 'package:akshara_erp/features/student_app/exams/student_exams_screen.dart';
import 'package:akshara_erp/features/student_app/homework/student_homework_provider.dart';
import 'package:akshara_erp/features/student_app/homework/student_homework_screen.dart';
import 'package:akshara_erp/features/student_app/notices/student_notices_provider.dart';
import 'package:akshara_erp/features/student_app/notices/student_notices_screen.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW7 · QA-C-002 — Student app *behaviour* certification (Batch 2).
///
/// Sits ON TOP of the existing Student widget coverage which already proves
/// rendering + the 4 async states per screen:
///   • test/features/student_app/student_module_screens_test.dart  (Attendance
///     loading, Homework empty, Notices error, Exams/Timetable/Profile render)
///   • test/features/student_app/student_navigation_pilot_test.dart (shell tab nav)
///   • test/features/student_app/student_attendance_sync_test.dart
///
/// This cert asserts that a representative interactive control performs its
/// expected action: the StudentExams SegmentedButton switches the visible
/// section (Upcoming ↔ Results), proving a real tab/segment toggle re-renders the
/// body — plus the canonical loading / error / empty / success states.
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
  group('QA-C-002 · Student app — clickable behaviour', () {
    testWidgets('Exams segment toggle switches the visible section',
        (tester) async {
      await _pump(tester, const StudentExamsScreen());

      // Default section is Upcoming: the segmented control is present and the
      // body shows the upcoming-exams content, NOT the results placeholder.
      expect(find.text('Exams'), findsOneWidget);
      final segmented = find.byType(SegmentedButton<StudentExamSection>);
      expect(segmented, findsOneWidget);
      // The Results section's placeholder is absent while Upcoming is active.
      expect(find.text('No exam results published yet.'), findsNothing);

      // Target the segment LABELS specifically — "Results"/"Upcoming" also appear
      // as KPI card subtitles, so scope the finders to inside the SegmentedButton.
      final resultsSegment =
          find.descendant(of: segmented, matching: find.text('Results'));
      final upcomingSegment =
          find.descendant(of: segmented, matching: find.text('Upcoming'));
      expect(resultsSegment, findsOneWidget);

      // Tap the Results segment → the body re-renders into the results section
      // (demo data has no published results yet → its empty state surfaces).
      await tester.tap(resultsSegment);
      await tester.pumpAndSettle();

      expect(find.text('No exam results published yet.'), findsOneWidget);

      // And switching back restores the Upcoming section (toggle is bidirectional).
      await tester.tap(upcomingSegment);
      await tester.pumpAndSettle();
      expect(find.text('No exam results published yet.'), findsNothing);
    });
  });

  group('QA-C-002 · Student app — canonical 4 states render', () {
    testWidgets('SUCCESS — attendance screen settles into its data path',
        (tester) async {
      await _pump(tester, const StudentAttendanceScreen());

      expect(find.text('Attendance'), findsOneWidget);
      expect(find.byType(AksharaLoadingState), findsNothing);
      expect(find.byType(AksharaErrorState), findsNothing);
    });

    testWidgets('LOADING — attendance screen shows AksharaLoadingState',
        (tester) async {
      await _pump(
        tester,
        const StudentAttendanceScreen(),
        overrides: [
          studentAttendanceLoadingProvider.overrideWith((ref) => true),
        ],
        settle: false,
      );

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('EMPTY — homework screen shows AksharaEmptyState',
        (tester) async {
      await _pump(
        tester,
        const StudentHomeworkScreen(),
        overrides: [studentHomeworkEmptyProvider.overrideWith((ref) => true)],
      );

      expect(find.byType(AksharaEmptyState), findsOneWidget);
    });

    testWidgets('ERROR — notices screen shows AksharaErrorState',
        (tester) async {
      await _pump(
        tester,
        const StudentNoticesScreen(),
        overrides: [studentNoticesErrorProvider.overrideWith((ref) => true)],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });
  });
}
