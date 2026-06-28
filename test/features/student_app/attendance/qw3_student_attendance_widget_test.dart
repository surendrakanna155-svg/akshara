import 'package:akshara_erp/features/parent/attendance/attendance_calendar.dart';
import 'package:akshara_erp/features/parent/attendance/attendance_kpi_strip.dart';
import 'package:akshara_erp/features/student_app/attendance/student_attendance_provider.dart';
import 'package:akshara_erp/features/student_app/attendance/student_attendance_screen.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

/// QW3 · QA-F-044 — Student monthly attendance screen render + loading/error.
/// `student_attendance_screen.dart` (ST-02) was never widget-pumped. Demo data
/// drives the KPI strip + (fixed 36px) calendar; the loading and error states
/// are forced through the screen's own state providers.

Future<void> _pump(
  WidgetTester tester, {
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const StudentAttendanceScreen(),
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
  group('QA-F-044 · StudentAttendanceScreen', () {
    testWidgets('renders the month selector, KPI strip and calendar',
        (tester) async {
      await _pump(tester);

      expect(find.text('Attendance'), findsOneWidget);
      expect(find.byType(AttendanceKpiStrip), findsOneWidget);
      expect(find.byType(AttendanceCalendar), findsOneWidget);
      expect(find.text('Attendance history'), findsOneWidget);
    });

    testWidgets('shows the loading state when forced', (tester) async {
      await _pump(
        tester,
        overrides: [
          studentAttendanceLoadingProvider.overrideWith((ref) => true),
        ],
        settle: false,
      );

      expect(find.byType(AksharaLoadingState), findsOneWidget);
      expect(find.byType(AttendanceCalendar), findsNothing);
    });

    testWidgets('shows the error state with a retry when forced',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          studentAttendanceErrorProvider.overrideWith((ref) => true),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
      expect(
        find.text('Unable to load your attendance right now.'),
        findsOneWidget,
      );
      expect(find.byType(AttendanceCalendar), findsNothing);
    });
  });
}
