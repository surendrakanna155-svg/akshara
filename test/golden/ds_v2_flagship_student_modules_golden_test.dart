@TestOn('mac-os')
library;

import 'package:akshara_erp/features/student_app/attendance/student_attendance_screen.dart';
import 'package:akshara_erp/features/student_app/exams/student_exams_screen.dart';
import 'package:akshara_erp/features/student_app/homework/student_homework_screen.dart';
import 'package:akshara_erp/features/student_app/notices/student_notices_screen.dart';
import 'package:akshara_erp/features/student_app/profile/student_profile_screen.dart';
import 'package:akshara_erp/features/student_app/timetable/student_timetable_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/persona_accents.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';
import 'golden_test_helpers.dart';

/// DS V2 Phase 4 — flagship goldens for the student-journey MODULE screens
/// (beyond the dashboard). Each is rendered under the STUDENT persona theme
/// (emerald accent) at a tall viewport, Light + Dark, so the premium migration
/// (persona canvas, signature rings, floating cards) is captured while every
/// metric, list and honest-state stays intact.
void main() {
  const tall = Size(390, 1280);

  Future<void> pump(
    WidgetTester tester, {
    required Widget screen,
    required bool dark,
    List<Override> overrides = const [],
  }) async {
    suppressGoldenOverflowErrors();
    useGoldenViewport(tester, tall);
    await tester.pumpWidget(
      ProviderScope(
        overrides: erpWidgetTestOverrides(overrides),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AksharaAppTheme.persona(
            brightness: dark ? Brightness.dark : Brightness.light,
            accent: AksharaPersonaAccent.student,
          ),
          home: screen,
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  }

  for (final mode in const [
    (label: 'light', dark: false),
    (label: 'dark', dark: true),
  ]) {
    testWidgets('student attendance · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const StudentAttendanceScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(StudentAttendanceScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_student_attendance_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('student homework · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const StudentHomeworkScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(StudentHomeworkScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_student_homework_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('student exams · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const StudentExamsScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(StudentExamsScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_student_exams_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('student timetable · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const StudentTimetableScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(StudentTimetableScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_student_timetable_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('student notices · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const StudentNoticesScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(StudentNoticesScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_student_notices_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('student profile · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const StudentProfileScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(StudentProfileScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_student_profile_${mode.label}', '390x1280'),
        ),
      );
    });
  }
}
