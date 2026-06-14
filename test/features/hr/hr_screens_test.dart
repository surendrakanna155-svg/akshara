import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/hr/attendance/hr_attendance_screen.dart';
import 'package:akshara_erp/features/hr/dashboard/hr_dashboard_screen.dart';
import 'package:akshara_erp/features/hr/employees/hr_employee_profile_screen.dart';
import 'package:akshara_erp/features/hr/employees/hr_employees_screen.dart';
import 'package:akshara_erp/features/hr/leave/hr_leave_screen.dart';
import 'package:akshara_erp/features/hr/payroll/hr_payroll_screen.dart';
import 'package:akshara_erp/features/hr/performance/hr_performance_screen.dart';
import 'package:akshara_erp/features/hr/recruitment/hr_recruitment_screen.dart';
import 'package:akshara_erp/features/hr/settings/hr_settings_screen.dart';
import 'package:akshara_erp/features/hr/hr_providers.dart';
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

Future<void> pumpHrScreen(
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
  group('HR screens — desktop', () {
    testWidgets('HrDashboardScreen renders KPIs', (tester) async {
      await pumpHrScreen(tester, const HrDashboardScreen());

      expect(find.text('Total Employees'), findsOneWidget);
      expect(find.text('Pending leave queue'), findsOneWidget);
    });

    testWidgets('HrDashboardScreen shows loading state', (tester) async {
      useViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            hrDashboardLoadingProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const HrDashboardScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('HrEmployeesScreen renders employee directory', (
      tester,
    ) async {
      await pumpHrScreen(tester, const HrEmployeesScreen());

      expect(find.text('Employee directory'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsAtLeastNWidgets(1));
      expect(find.byKey(QaTestKeys.hrCreateEmployeeButton), findsOneWidget);
    });

    testWidgets('HrEmployeeProfileScreen renders profile', (tester) async {
      await pumpHrScreen(
        tester,
        const HrEmployeeProfileScreen(employeeId: 'HR-EMP-101'),
      );

      expect(find.text('Priya Sharma'), findsAtLeastNWidgets(1));
      expect(find.text('Mathematics Teacher'), findsOneWidget);
    });

    testWidgets('HrAttendanceScreen renders attendance', (tester) async {
      await pumpHrScreen(tester, const HrAttendanceScreen());

      expect(find.text('Staff attendance'), findsOneWidget);
      expect(find.text('Mrs. Rao'), findsOneWidget);
    });

    testWidgets('HrLeaveScreen renders leave requests', (tester) async {
      await pumpHrScreen(tester, const HrLeaveScreen());

      expect(find.text('Leave requests'), findsOneWidget);
      expect(find.text('Sunita Nair'), findsOneWidget);
      expect(find.byKey(QaTestKeys.hrCreateLeaveButton), findsOneWidget);
    });

    testWidgets('HrLeaveScreen create button visible on mobile width', (
      tester,
    ) async {
      await pumpHrScreen(
        tester,
        const HrLeaveScreen(),
        viewport: const Size(390, 844),
      );

      expect(find.byKey(QaTestKeys.hrCreateLeaveButton), findsOneWidget);
    });

    testWidgets('HrPayrollScreen renders payroll', (tester) async {
      await pumpHrScreen(tester, const HrPayrollScreen());

      expect(find.text('Payroll runs'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.byKey(QaTestKeys.hrProcessPayrollButton), findsOneWidget);
      expect(find.byKey(QaTestKeys.hrPayrollExportPdfButton), findsOneWidget);
    });

    testWidgets('HrRecruitmentScreen renders pipeline', (tester) async {
      await pumpHrScreen(tester, const HrRecruitmentScreen());

      expect(find.text('Recruitment pipeline'), findsOneWidget);
      expect(find.text('Deepa Krishnan'), findsOneWidget);
    });

    testWidgets('HrPerformanceScreen renders reviews', (tester) async {
      await pumpHrScreen(tester, const HrPerformanceScreen());

      expect(find.text('Performance reviews'), findsOneWidget);
      expect(find.text('Mrs. Rao'), findsOneWidget);
    });

    testWidgets('HrSettingsScreen renders settings', (tester) async {
      await pumpHrScreen(tester, const HrSettingsScreen());

      expect(find.text('HR settings'), findsOneWidget);
      expect(find.text('Attendance & verification'), findsOneWidget);
    });
  });

  group('HR screens — error state', () {
    testWidgets('HrEmployeesScreen shows error state', (tester) async {
      await pumpHrScreen(
        tester,
        const HrEmployeesScreen(),
        overrides: [
          hrEmployeesErrorProvider.overrideWith((ref) => true),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });
  });
}
