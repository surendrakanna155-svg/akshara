import 'package:akshara_erp/features/hostel/attendance/hostel_attendance_screen.dart';
import 'package:akshara_erp/features/hostel/dashboard/hostel_dashboard_screen.dart';
import 'package:akshara_erp/features/hostel/leave/hostel_leave_screen.dart';
import 'package:akshara_erp/features/hostel/mess/hostel_mess_screen.dart';
import 'package:akshara_erp/features/hostel/reports/hostel_reports_screen.dart';
import 'package:akshara_erp/features/hostel/rooms/hostel_rooms_screen.dart';
import 'package:akshara_erp/features/hostel/students/hostel_students_screen.dart';
import 'package:akshara_erp/features/hostel/visitors/hostel_visitors_screen.dart';
import 'package:akshara_erp/features/hostel/hostel_providers.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../test_helpers.dart';

void useViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> pumpHostelScreen(
  WidgetTester tester,
  Widget screen, {
  Size viewport = const Size(1440, 900),
  List<Override> overrides = const [],
}) async {
  useViewport(tester, viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('Hostel screens — desktop', () {
    testWidgets('HostelDashboardScreen renders KPIs', (tester) async {
      await pumpHostelScreen(tester, const HostelDashboardScreen());

      expect(find.text('Occupancy'), findsOneWidget);
      expect(find.text('Block occupancy'), findsOneWidget);
    });

    testWidgets('HostelDashboardScreen shows loading state', (tester) async {
      useViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            hostelDashboardLoadingProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const HostelDashboardScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('HostelStudentsScreen renders SIS-linked residents', (
      tester,
    ) async {
      await pumpHostelScreen(tester, const HostelStudentsScreen());

      expect(find.text('Hostel residents'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);
    });

    testWidgets('HostelRoomsScreen renders room catalog', (tester) async {
      await pumpHostelScreen(tester, const HostelRoomsScreen());

      expect(find.text('Room catalog'), findsOneWidget);
      expect(find.text('A-204'), findsOneWidget);
    });

    testWidgets('HostelAttendanceScreen renders roster', (tester) async {
      await pumpHostelScreen(tester, const HostelAttendanceScreen());

      expect(find.text('Hostel attendance roster'), findsOneWidget);
      expect(find.text('Emma Thomas'), findsOneWidget);
    });

    testWidgets('HostelLeaveScreen renders leave requests', (tester) async {
      await pumpHostelScreen(tester, const HostelLeaveScreen());

      expect(find.text('Leave requests'), findsOneWidget);
      expect(find.text('Ananya Reddy'), findsOneWidget);
    });

    testWidgets('HostelMessScreen renders weekly menu', (tester) async {
      await pumpHostelScreen(tester, const HostelMessScreen());

      expect(find.text('Weekly menu'), findsOneWidget);
      expect(find.text('Breakfast'), findsAtLeastNWidgets(1));
    });

    testWidgets('HostelVisitorsScreen renders active visitors', (
      tester,
    ) async {
      await pumpHostelScreen(tester, const HostelVisitorsScreen());

      expect(find.text('Active visitors'), findsOneWidget);
      expect(find.text('Vikram Patel'), findsOneWidget);
    });

    testWidgets('HostelReportsScreen renders report catalog', (tester) async {
      await pumpHostelScreen(tester, const HostelReportsScreen());

      expect(find.text('Report catalog'), findsOneWidget);
      expect(find.text('Occupancy report'), findsOneWidget);
    });

    testWidgets('HostelStudentsScreen shows error state', (tester) async {
      await pumpHostelScreen(
        tester,
        const HostelStudentsScreen(),
        overrides: [
          hostelStudentsErrorProvider.overrideWith((ref) => true),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });
  });
}
