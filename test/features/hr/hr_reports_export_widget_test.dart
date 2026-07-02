import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/hr/attendance/hr_attendance_screen.dart';
import 'package:akshara_erp/features/hr/employees/hr_employees_screen.dart';
import 'package:akshara_erp/features/hr/hr_report_models.dart';
import 'package:akshara_erp/features/hr/payroll/hr_payroll_screen.dart';
import 'package:akshara_erp/features/hr/reports/hr_report_exporters.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// HR reporting / export widget + mapping tests. The export service is faked so
/// the platform `printing` plugin (sharePdf) is never driven; each grid call is
/// recorded so we can assert the export path fired.
class _FakeExportService extends AksharaReportExportService {
  const _FakeExportService(this.calls);

  final List<String> calls;

  @override
  Future<void> shareGridCsv({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    calls.add('csv:$filename:${rows.length}');
  }

  @override
  Future<void> shareGridPdf({
    required String filename,
    required String reportTitle,
    required String moduleLabel,
    required List<String> headers,
    required List<List<String>> rows,
    String? generatedAtLabel,
    int? rightAlignFrom,
  }) async {
    calls.add('pdf:$filename:${rows.length}');
  }
}

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  List<String> calls,
) async {
  _desktop(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        aksharaReportExportServiceProvider
            .overrideWithValue(_FakeExportService(calls)),
      ]),
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
  group('HR reports — payroll (HR-1 register + HR-2 payslips)', () {
    testWidgets('renders salary register + payslip export buttons',
        (tester) async {
      await _pump(tester, const HrPayrollScreen(), []);
      expect(
        find.byKey(QaTestKeys.hrSalaryRegisterExportButton),
        findsOneWidget,
      );
      expect(find.byKey(QaTestKeys.hrPayslipsExportButton), findsOneWidget);
    });

    testWidgets('tapping salary register PDF fires the grid export + feedback',
        (tester) async {
      final calls = <String>[];
      await _pump(tester, const HrPayrollScreen(), calls);

      final button = find.byKey(QaTestKeys.hrSalaryRegisterExportButton);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(calls.any((c) => c.startsWith('pdf:salary_register')), isTrue);
      expect(
        find.byKey(QaTestKeys.hrReportExportSuccessSnackbar),
        findsOneWidget,
      );
    });

    testWidgets('tapping payslips PDF fires the bundle export', (tester) async {
      final calls = <String>[];
      await _pump(tester, const HrPayrollScreen(), calls);

      final button = find.byKey(QaTestKeys.hrPayslipsExportButton);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(calls.any((c) => c.startsWith('pdf:payslips')), isTrue);
    });
  });

  group('HR reports — attendance muster (HR-6)', () {
    testWidgets('renders the muster export bar + fires the grid export',
        (tester) async {
      final calls = <String>[];
      await _pump(tester, const HrAttendanceScreen(), calls);

      expect(find.textContaining('Monthly muster'), findsOneWidget);
      final button = find.byKey(QaTestKeys.hrMusterExportButton);
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(calls.any((c) => c.startsWith('pdf:attendance_muster')), isTrue);
    });
  });

  group('HR reports — employee directory (HR-7)', () {
    testWidgets('renders directory export + fires the grid export',
        (tester) async {
      final calls = <String>[];
      await _pump(tester, const HrEmployeesScreen(), calls);

      final button = find.byKey(QaTestKeys.hrDirectoryExportButton);
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(calls.any((c) => c.startsWith('pdf:employee_directory')), isTrue);
    });
  });

  group('HrReportExporters — grid mapping', () {
    const register = HrSalaryRegister(
      runId: 'run-1',
      period: 'June 2026',
      rows: [
        HrSalaryRegisterRow(
          employeeId: 'e1',
          code: 'EMP-1',
          name: 'Alice',
          dept: 'academics',
          basicPay: 40000,
          allowances: 5000,
          deductions: 3000,
          netPay: 42000,
        ),
      ],
      totals: HrSalaryRegisterTotals(
        basicPay: 40000,
        allowances: 5000,
        deductions: 3000,
        netPay: 42000,
      ),
    );

    test('salary register rows end with a TOTAL row carrying the column sums',
        () {
      final rows = HrReportExporters.salaryRegisterRows(register);
      // one data row + one totals row
      expect(rows.length, 2);
      expect(rows.last.first, 'TOTAL');
      expect(rows.last.last, '42000');
    });

    test('headcount rows end with a TOTAL row', () {
      const report = HrHeadcountReport(
        rows: [
          HrHeadcountRow(department: 'academics', count: 3),
          HrHeadcountRow(department: 'transport', count: 1),
        ],
        total: 4,
      );
      final rows = HrReportExporters.headcountRows(report);
      expect(rows.length, 3);
      expect(rows.last, ['TOTAL', '4']);
    });

    test('muster headers include one column per day plus Present + %', () {
      const muster = HrAttendanceMuster(
        month: '2026-06',
        daysInMonth: 30,
        lateAfter: '09:15',
        holidayDays: [],
        rows: [],
      );
      final headers = HrReportExporters.musterHeaders(muster);
      // Code, Name, Department + 30 days + Present + %
      expect(headers.length, 3 + 30 + 2);
      expect(headers.first, 'Code');
      expect(headers.last, '%');
    });

    test('leave-balance headers expand to 3 columns per leave type', () {
      const report = HrLeaveBalanceReport(
        leaveTypes: ['casual', 'sick'],
        rows: [],
      );
      final headers = HrReportExporters.leaveBalanceHeaders(report);
      // Code, Name, Department + (2 types × 3)
      expect(headers.length, 3 + 2 * 3);
    });
  });
}
