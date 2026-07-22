@TestOn('mac-os')
library;

import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_screen.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_my_attendance_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/persona_accents.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';
import 'golden_test_helpers.dart';

/// DS V2 Phase 4 — flagship goldens for the teacher-journey MODULE screens
/// (beyond the dashboard, which was migrated in Phase 3). Each is rendered under
/// the TEACHER persona theme (indigo accent) at a tall viewport, Light + Dark,
/// so the premium migration (persona canvas, signature rings, floating cards) is
/// captured while every metric, list and honest-state stays intact.
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
            accent: AksharaPersonaAccent.teacher,
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
    testWidgets('teacher attendance · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const TeacherAttendanceScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(TeacherAttendanceScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_teacher_attendance_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('teacher my attendance · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const TeacherMyAttendanceScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(TeacherMyAttendanceScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_teacher_my_attendance_${mode.label}', '390x1280'),
        ),
      );
    });
  }
}
