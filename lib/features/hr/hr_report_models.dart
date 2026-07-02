/// HR reporting / export domain models (HR-1, HR-2, HR-4, HR-5, HR-6, HR-7).
///
/// These are plain, string-typed grid view-models: every field is what the
/// backend computes from the school's real rows, ready to feed the shared
/// XCT-1 export service (CSV + PDF). Kept separate from the interactive HR
/// domain models so the report layer stays decoupled from the module enums.
library;

// ---------------------------------------------------------------------------
// HR-1 — Salary register
// ---------------------------------------------------------------------------

class HrSalaryRegisterRow {
  const HrSalaryRegisterRow({
    required this.employeeId,
    required this.code,
    required this.name,
    required this.dept,
    required this.basicPay,
    required this.allowances,
    required this.deductions,
    required this.netPay,
  });

  final String employeeId;
  final String code;
  final String name;
  final String dept;
  final num basicPay;
  final num allowances;
  final num deductions;
  final num netPay;
}

class HrSalaryRegisterTotals {
  const HrSalaryRegisterTotals({
    required this.basicPay,
    required this.allowances,
    required this.deductions,
    required this.netPay,
  });

  final num basicPay;
  final num allowances;
  final num deductions;
  final num netPay;

  static const empty = HrSalaryRegisterTotals(
    basicPay: 0,
    allowances: 0,
    deductions: 0,
    netPay: 0,
  );
}

class HrSalaryRegister {
  const HrSalaryRegister({
    required this.runId,
    required this.period,
    required this.rows,
    required this.totals,
  });

  final String runId;
  final String period;
  final List<HrSalaryRegisterRow> rows;
  final HrSalaryRegisterTotals totals;

  bool get isEmpty => rows.isEmpty;
}

// ---------------------------------------------------------------------------
// HR-2 — Payslips
// ---------------------------------------------------------------------------

class HrPayslipLine {
  const HrPayslipLine({required this.label, required this.amount});

  final String label;
  final num amount;
}

class HrPayslip {
  const HrPayslip({
    required this.employeeId,
    required this.code,
    required this.name,
    required this.dept,
    required this.earnings,
    required this.deductionLines,
    required this.grossEarnings,
    required this.totalDeductions,
    required this.netPay,
  });

  final String employeeId;
  final String code;
  final String name;
  final String dept;
  final List<HrPayslipLine> earnings;
  final List<HrPayslipLine> deductionLines;
  final num grossEarnings;
  final num totalDeductions;
  final num netPay;
}

class HrPayslipBundle {
  const HrPayslipBundle({
    required this.runId,
    required this.period,
    required this.payslips,
  });

  final String runId;
  final String period;
  final List<HrPayslip> payslips;

  bool get isEmpty => payslips.isEmpty;
}

// ---------------------------------------------------------------------------
// HR-6 — Monthly attendance muster
// ---------------------------------------------------------------------------

/// Per-day muster status. Mirrors the backend single-char codes.
enum HrMusterStatus {
  present, // P
  late_, // L
  absent, // A
  nonWorking; // -

  String get code => switch (this) {
        HrMusterStatus.present => 'P',
        HrMusterStatus.late_ => 'L',
        HrMusterStatus.absent => 'A',
        HrMusterStatus.nonWorking => '-',
      };

  static HrMusterStatus fromCode(String code) => switch (code) {
        'P' => HrMusterStatus.present,
        'L' => HrMusterStatus.late_,
        'A' => HrMusterStatus.absent,
        _ => HrMusterStatus.nonWorking,
      };
}

class HrMusterRow {
  const HrMusterRow({
    required this.employeeId,
    required this.code,
    required this.name,
    required this.dept,
    required this.dailyStatus,
    required this.presentCount,
    required this.percent,
  });

  final String employeeId;
  final String code;
  final String name;
  final String dept;

  /// Index 0 == day 1 of the month.
  final List<HrMusterStatus> dailyStatus;
  final int presentCount;
  final int percent;
}

class HrAttendanceMuster {
  const HrAttendanceMuster({
    required this.month,
    required this.daysInMonth,
    required this.lateAfter,
    required this.holidayDays,
    required this.rows,
  });

  final String month; // YYYY-MM
  final int daysInMonth;
  final String lateAfter; // HH:MM cutoff
  final List<int> holidayDays;
  final List<HrMusterRow> rows;

  bool get isEmpty => rows.isEmpty;
}

// ---------------------------------------------------------------------------
// HR-4 — Leave-balance report
// ---------------------------------------------------------------------------

class HrLeaveBalanceCell {
  const HrLeaveBalanceCell({
    required this.leaveType,
    required this.available,
    required this.used,
    required this.remaining,
  });

  final String leaveType;
  final num available;
  final num used;
  final num remaining;
}

class HrLeaveBalanceRow {
  const HrLeaveBalanceRow({
    required this.employeeId,
    required this.code,
    required this.name,
    required this.dept,
    required this.balances,
  });

  final String employeeId;
  final String code;
  final String name;
  final String dept;
  final List<HrLeaveBalanceCell> balances;
}

class HrLeaveBalanceReport {
  const HrLeaveBalanceReport({required this.leaveTypes, required this.rows});

  final List<String> leaveTypes;
  final List<HrLeaveBalanceRow> rows;

  bool get isEmpty => rows.isEmpty;
}

// ---------------------------------------------------------------------------
// HR-5 — Headcount by department
// ---------------------------------------------------------------------------

class HrHeadcountRow {
  const HrHeadcountRow({required this.department, required this.count});

  final String department;
  final int count;
}

class HrHeadcountReport {
  const HrHeadcountReport({required this.rows, required this.total});

  final List<HrHeadcountRow> rows;
  final int total;

  bool get isEmpty => rows.isEmpty;
}

// ---------------------------------------------------------------------------
// HR-7 — Employee directory export
// ---------------------------------------------------------------------------

class HrDirectoryRow {
  const HrDirectoryRow({
    required this.employeeId,
    required this.code,
    required this.name,
    required this.dept,
    required this.designation,
    required this.phone,
    required this.joinDate,
    required this.status,
  });

  final String employeeId;
  final String code;
  final String name;
  final String dept;
  final String designation;
  final String phone;
  final String joinDate;
  final String status;
}

class HrEmployeeDirectory {
  const HrEmployeeDirectory({required this.rows});

  final List<HrDirectoryRow> rows;

  bool get isEmpty => rows.isEmpty;
}
