@TestOn('mac-os')
library;

import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_screen.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_my_attendance_screen.dart';
import 'package:akshara_erp/features/teacher/communication/teacher_parent_communication_screen.dart';
import 'package:akshara_erp/features/teacher/exams/teacher_exams_screen.dart';
import 'package:akshara_erp/features/teacher/homework/teacher_homework_create_screen.dart';
import 'package:akshara_erp/features/teacher/homework/teacher_homework_history_screen.dart';
import 'package:akshara_erp/features/teacher/homework/teacher_homework_screen.dart';
import 'package:akshara_erp/features/teacher/leave/teacher_leave_screen.dart';
import 'package:akshara_erp/features/teacher/leave_approvals/teacher_leave_approvals_screen.dart';
import 'package:akshara_erp/features/teacher/messages/teacher_messages_screen.dart';
import 'package:akshara_erp/features/teacher/profile/teacher_profile_screen.dart';
import 'package:akshara_erp/features/teacher/settings/teacher_settings_screen.dart';
import 'package:akshara_erp/features/teacher/student_risk/teacher_student_risk_screen.dart';
import 'package:akshara_erp/features/teacher/timetable/teacher_timetable_screen.dart';
import 'package:akshara_erp/features/teacher/timetable/teacher_today_screen.dart';
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

    testWidgets('teacher homework review · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const TeacherHomeworkScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(TeacherHomeworkScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_teacher_homework_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('teacher homework create · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const TeacherHomeworkCreateScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(TeacherHomeworkCreateScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_teacher_homework_create_${mode.label}',
              '390x1280'),
        ),
      );
    });

    testWidgets('teacher homework history · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const TeacherHomeworkHistoryScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(TeacherHomeworkHistoryScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_teacher_homework_history_${mode.label}',
              '390x1280'),
        ),
      );
    });

    testWidgets('teacher exams · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const TeacherExamsScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(TeacherExamsScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_teacher_exams_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('teacher timetable · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const TeacherTimetableScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(TeacherTimetableScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_teacher_timetable_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('teacher today · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const TeacherTodayScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(TeacherTodayScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_teacher_today_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('teacher leave · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const TeacherLeaveScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(TeacherLeaveScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_teacher_leave_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('teacher leave approvals · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const TeacherLeaveApprovalsScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(TeacherLeaveApprovalsScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_teacher_leave_approvals_${mode.label}',
              '390x1280'),
        ),
      );
    });

    testWidgets('teacher parent communication · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const TeacherParentCommunicationScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(TeacherParentCommunicationScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_teacher_communication_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('teacher messages · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const TeacherMessagesScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(TeacherMessagesScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_teacher_messages_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('teacher student risk · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const TeacherStudentRiskScreen(sisStudentId: 'SIS-STU-10421'),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(TeacherStudentRiskScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_teacher_student_risk_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('teacher profile · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const TeacherProfileScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(TeacherProfileScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_teacher_profile_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('teacher settings · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const TeacherSettingsScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(TeacherSettingsScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_teacher_settings_${mode.label}', '390x1280'),
        ),
      );
    });
  }
}
