import '../../../core/reports/akshara_report_export_service.dart';
import '../hr_report_models.dart';

/// Turns the HR report view-models into the shared XCT-1 grid shape (headers +
/// string rows) and drives CSV / PDF exports through [AksharaReportExportService].
/// Every HR report rides the same grid primitive — no report invents its own
/// CSV/PDF layout.
class HrReportExporters {
  const HrReportExporters(this._service);

  final AksharaReportExportService _service;

  static String _money(num value) => value.toStringAsFixed(0);

  // --- HR-1 salary register --------------------------------------------------

  static const List<String> salaryRegisterHeaders = [
    'Code',
    'Name',
    'Department',
    'Basic',
    'Allowances',
    'Deductions',
    'Net pay',
  ];

  static List<List<String>> salaryRegisterRows(HrSalaryRegister register) {
    return [
      for (final r in register.rows)
        [
          r.code,
          r.name,
          r.dept,
          _money(r.basicPay),
          _money(r.allowances),
          _money(r.deductions),
          _money(r.netPay),
        ],
      [
        'TOTAL',
        '',
        '',
        _money(register.totals.basicPay),
        _money(register.totals.allowances),
        _money(register.totals.deductions),
        _money(register.totals.netPay),
      ],
    ];
  }

  Future<void> shareSalaryRegisterCsv(HrSalaryRegister register) {
    return _service.shareGridCsv(
      filename: 'salary_register_${register.runId}',
      headers: salaryRegisterHeaders,
      rows: salaryRegisterRows(register),
    );
  }

  Future<void> shareSalaryRegisterPdf(HrSalaryRegister register) {
    return _service.shareGridPdf(
      filename: 'salary_register_${register.runId}',
      reportTitle: 'Salary register',
      moduleLabel: 'HR · Payroll · ${register.period}',
      headers: salaryRegisterHeaders,
      rows: salaryRegisterRows(register),
      generatedAtLabel: DateTime.now().toIso8601String(),
      rightAlignFrom: 3,
    );
  }

  // --- HR-2 payslips ---------------------------------------------------------
  // One-row-per-employee summary CSV/PDF plus the full multi-page bundle.

  static const List<String> payslipHeaders = [
    'Code',
    'Name',
    'Department',
    'Gross earnings',
    'Deductions',
    'Net pay',
  ];

  static List<List<String>> payslipRows(HrPayslipBundle bundle) {
    return [
      for (final p in bundle.payslips)
        [
          p.code,
          p.name,
          p.dept,
          _money(p.grossEarnings),
          _money(p.totalDeductions),
          _money(p.netPay),
        ],
    ];
  }

  Future<void> sharePayslipsCsv(HrPayslipBundle bundle) {
    return _service.shareGridCsv(
      filename: 'payslips_${bundle.runId}',
      headers: payslipHeaders,
      rows: payslipRows(bundle),
    );
  }

  /// Builds the all-in-one payslip bundle PDF — one section per employee (earnings
  /// / deductions breakdown + net), rendered as a single grid table so it prints
  /// as one document.
  Future<void> sharePayslipsBundlePdf(HrPayslipBundle bundle) {
    final rows = <List<String>>[];
    for (final p in bundle.payslips) {
      rows.add([p.code, p.name, p.dept, 'Earnings', '', '']);
      for (final e in p.earnings) {
        rows.add(['', '', '', e.label, _money(e.amount), '']);
      }
      for (final d in p.deductionLines) {
        rows.add(['', '', '', d.label, '', _money(d.amount)]);
      }
      rows.add(['', '', '', 'Net pay', '', _money(p.netPay)]);
    }
    return _service.shareGridPdf(
      filename: 'payslips_${bundle.runId}',
      reportTitle: 'Payslips',
      moduleLabel: 'HR · Payroll · ${bundle.period}',
      headers: const ['Code', 'Name', 'Department', 'Line', 'Earning', 'Deduction'],
      rows: rows,
      generatedAtLabel: DateTime.now().toIso8601String(),
      rightAlignFrom: 4,
    );
  }

  // --- HR-6 attendance muster ------------------------------------------------

  static List<String> musterHeaders(HrAttendanceMuster muster) {
    return [
      'Code',
      'Name',
      'Department',
      for (var d = 1; d <= muster.daysInMonth; d++) '$d',
      'Present',
      '%',
    ];
  }

  static List<List<String>> musterRows(HrAttendanceMuster muster) {
    return [
      for (final r in muster.rows)
        [
          r.code,
          r.name,
          r.dept,
          for (final s in r.dailyStatus) s.code,
          '${r.presentCount}',
          '${r.percent}',
        ],
    ];
  }

  Future<void> shareMusterCsv(HrAttendanceMuster muster) {
    return _service.shareGridCsv(
      filename: 'attendance_muster_${muster.month}',
      headers: musterHeaders(muster),
      rows: musterRows(muster),
    );
  }

  Future<void> shareMusterPdf(HrAttendanceMuster muster) {
    return _service.shareGridPdf(
      filename: 'attendance_muster_${muster.month}',
      reportTitle: 'Monthly attendance muster',
      moduleLabel:
          'HR · Attendance · ${muster.month} · Late after ${muster.lateAfter}',
      headers: musterHeaders(muster),
      rows: musterRows(muster),
      generatedAtLabel: DateTime.now().toIso8601String(),
    );
  }

  // --- HR-4 leave balances ---------------------------------------------------

  static List<String> leaveBalanceHeaders(HrLeaveBalanceReport report) {
    return [
      'Code',
      'Name',
      'Department',
      for (final t in report.leaveTypes) ...['$t avail', '$t used', '$t rem'],
    ];
  }

  static List<List<String>> leaveBalanceRows(HrLeaveBalanceReport report) {
    return [
      for (final r in report.rows)
        [
          r.code,
          r.name,
          r.dept,
          for (final b in r.balances) ...[
            _money(b.available),
            _money(b.used),
            _money(b.remaining),
          ],
        ],
    ];
  }

  Future<void> shareLeaveBalancesCsv(HrLeaveBalanceReport report) {
    return _service.shareGridCsv(
      filename: 'leave_balances',
      headers: leaveBalanceHeaders(report),
      rows: leaveBalanceRows(report),
    );
  }

  Future<void> shareLeaveBalancesPdf(HrLeaveBalanceReport report) {
    return _service.shareGridPdf(
      filename: 'leave_balances',
      reportTitle: 'Leave balances',
      moduleLabel: 'HR · Leave',
      headers: leaveBalanceHeaders(report),
      rows: leaveBalanceRows(report),
      generatedAtLabel: DateTime.now().toIso8601String(),
      rightAlignFrom: 3,
    );
  }

  // --- HR-5 headcount --------------------------------------------------------

  static const List<String> headcountHeaders = ['Department', 'Headcount'];

  static List<List<String>> headcountRows(HrHeadcountReport report) {
    return [
      for (final r in report.rows) [r.department, '${r.count}'],
      ['TOTAL', '${report.total}'],
    ];
  }

  Future<void> shareHeadcountCsv(HrHeadcountReport report) {
    return _service.shareGridCsv(
      filename: 'headcount_by_department',
      headers: headcountHeaders,
      rows: headcountRows(report),
    );
  }

  Future<void> shareHeadcountPdf(HrHeadcountReport report) {
    return _service.shareGridPdf(
      filename: 'headcount_by_department',
      reportTitle: 'Headcount by department',
      moduleLabel: 'HR · Reports',
      headers: headcountHeaders,
      rows: headcountRows(report),
      generatedAtLabel: DateTime.now().toIso8601String(),
      rightAlignFrom: 1,
    );
  }

  // --- HR-7 employee directory -----------------------------------------------

  static const List<String> directoryHeaders = [
    'Code',
    'Name',
    'Department',
    'Designation',
    'Phone',
    'Join date',
    'Status',
  ];

  static List<List<String>> directoryRows(HrEmployeeDirectory directory) {
    return [
      for (final r in directory.rows)
        [r.code, r.name, r.dept, r.designation, r.phone, r.joinDate, r.status],
    ];
  }

  Future<void> shareDirectoryCsv(HrEmployeeDirectory directory) {
    return _service.shareGridCsv(
      filename: 'employee_directory',
      headers: directoryHeaders,
      rows: directoryRows(directory),
    );
  }

  Future<void> shareDirectoryPdf(HrEmployeeDirectory directory) {
    return _service.shareGridPdf(
      filename: 'employee_directory',
      reportTitle: 'Employee directory',
      moduleLabel: 'HR · Employees',
      headers: directoryHeaders,
      rows: directoryRows(directory),
      generatedAtLabel: DateTime.now().toIso8601String(),
    );
  }
}
