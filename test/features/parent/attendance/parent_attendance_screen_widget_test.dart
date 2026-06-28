import 'package:akshara_erp/features/parent/attendance/attendance_calendar.dart';
import 'package:akshara_erp/features/parent/attendance/attendance_kpi_strip.dart';
import 'package:akshara_erp/features/parent/attendance/parent_attendance_provider.dart';
import 'package:akshara_erp/features/parent/attendance/parent_attendance_screen.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

/// QW1 · QA-F-012 — Parent attendance screen render + loading/error states.
/// `parent_attendance_screen.dart` (124 lines) was 0% lcov / never pumped.
Future<void> _pump(
  WidgetTester tester, {
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  // NOTE: rendered at a 412-wide phone (Pixel) rather than the shared 428
  // helper. At exactly 428 (largeMobileMinWidth) the calendar switches to 52px
  // cells and overflows its fixed 360px card by ~12px on 6-week months — a
  // tracked P2 responsive boundary bug (QA-F-012 finding → QW3/QW6 golden/
  // responsive sweep). At 412 the 48px cells fit, so render is asserted cleanly.
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const ParentAttendanceScreen(),
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
  group('QA-F-012 · ParentAttendanceScreen', () {
    testWidgets('renders the KPI strip + calendar', (tester) async {
      await _pump(tester);

      expect(find.text('Attendance'), findsOneWidget);
      expect(find.byType(AttendanceKpiStrip), findsOneWidget);
      expect(find.byType(AttendanceCalendar), findsOneWidget);
    });

    testWidgets('shows the loading state when forced', (tester) async {
      await _pump(
        tester,
        overrides: [
          parentAttendanceLoadingProvider.overrideWith((ref) => true),
        ],
        settle: false,
      );

      expect(find.byType(AksharaLoadingState), findsOneWidget);
      expect(find.byType(AttendanceCalendar), findsNothing);
    });

    testWidgets('shows the error state when forced', (tester) async {
      await _pump(
        tester,
        overrides: [
          parentAttendanceErrorProvider.overrideWith((ref) => true),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
      expect(find.text('Unable to load attendance right now.'), findsOneWidget);
    });
  });
}
