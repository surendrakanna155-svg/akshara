@TestOn('mac-os')
library;

import 'package:akshara_erp/features/parent/attendance/parent_attendance_screen.dart';
import 'package:akshara_erp/features/parent/exams/parent_exams_screen.dart';
import 'package:akshara_erp/features/parent/fees/fees_provider.dart';
import 'package:akshara_erp/features/parent/fees/parent_fees_screen.dart';
import 'package:akshara_erp/features/parent/homework/parent_homework_screen.dart';
import 'package:akshara_erp/features/parent/messages/parent_messages_screen.dart';
import 'package:akshara_erp/features/parent/receipts/parent_receipts_screen.dart';
import 'package:akshara_erp/features/parent/timetable/parent_timetable_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/persona_accents.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';
import 'golden_test_helpers.dart';

/// DS V2 Phase 3 — flagship goldens for the parent-journey MODULE screens
/// (beyond the dashboard). Each is rendered under the parent persona theme at a
/// tall viewport, Light + Dark, so the premium migration (persona canvas,
/// signature rings, floating cards) is captured while every money display and
/// pay flow stays intact.
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
            accent: AksharaPersonaAccent.parent,
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
    testWidgets('parent fees · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const ParentFeesScreen(),
        dark: mode.dark,
        overrides: [
          parentFeesProvider.overrideWithValue(ParentFeesData.mock()),
        ],
      );
      await expectLater(
        find.byType(ParentFeesScreen),
        matchesGoldenFile(
          goldenFileName('ds_v2_flagship_parent_fees_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('parent receipts · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const ParentReceiptsScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(ParentReceiptsScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_parent_receipts_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('parent attendance · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const ParentAttendanceScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(ParentAttendanceScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_parent_attendance_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('parent homework · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const ParentHomeworkScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(ParentHomeworkScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_parent_homework_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('parent exams · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const ParentExamsScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(ParentExamsScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_parent_exams_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('parent timetable · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const ParentTimetableScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(ParentTimetableScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_parent_timetable_${mode.label}', '390x1280'),
        ),
      );
    });

    testWidgets('parent messages · ${mode.label}', (tester) async {
      await pump(
        tester,
        screen: const ParentMessagesScreen(),
        dark: mode.dark,
      );
      await expectLater(
        find.byType(ParentMessagesScreen),
        matchesGoldenFile(
          goldenFileName(
              'ds_v2_flagship_parent_messages_${mode.label}', '390x1280'),
        ),
      );
    });

    // NOTE: ParentAcademicReportScreen has no golden — its printable-report
    // provider stays in a loading LinearProgressIndicator that never settles
    // (pumpAndSettle would time out). It's covered by parent_academics_screens
    // widget tests; the canvas wrap is verified there + by analyze.
  }
}
