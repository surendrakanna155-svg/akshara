// Unit tests for the HR reporting PURE transforms (DB-free): salary-register
// totals (HR-1), payslip breakdown (HR-2), muster status inference present/late/
// absent + holidays (HR-6), leave balances (HR-4), headcount grouping (HR-5).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildHeadcount,
  buildLeaveBalanceReport,
  buildPayslips,
  buildSalaryRegister,
  daysInMonth,
  inferMuster,
  type CheckInEvent,
  type MusterEmployee,
} from "./hr_reports_repository.ts";

// --- HR-1 salary register ---------------------------------------------------

Deno.test("HR-1: salary register maps entries and sums column totals", () => {
  const payroll = {
    runs: [{ id: "run-1", period: "June 2026" }],
    entries: [
      { employeeId: "e1", employeeCode: "EMP-1", employeeName: "A", department: "academics", basicPay: 40000, allowances: 5000, deductions: 3000, netPay: 42000 },
      { employeeId: "e2", employeeCode: "EMP-2", employeeName: "B", department: "finance", basicPay: 30000, allowances: 2000, deductions: 1000, netPay: 31000 },
    ],
  };
  const reg = buildSalaryRegister(payroll, "run-1");
  assertEquals(reg.period, "June 2026");
  assertEquals(reg.rows.length, 2);
  assertEquals(reg.rows[0]!.code, "EMP-1");
  assertEquals(reg.totals, { basicPay: 70000, allowances: 7000, deductions: 4000, netPay: 73000 });
});

Deno.test("HR-1: register filters entries to the requested run when tagged", () => {
  const payroll = {
    runs: [{ id: "run-1", period: "May" }, { id: "run-2", period: "June" }],
    entries: [
      { runId: "run-1", employeeId: "e1", basicPay: 100, allowances: 0, deductions: 0, netPay: 100 },
      { runId: "run-2", employeeId: "e2", basicPay: 200, allowances: 0, deductions: 0, netPay: 200 },
    ],
  };
  assertEquals(buildSalaryRegister(payroll, "run-1").totals.netPay, 100);
  assertEquals(buildSalaryRegister(payroll, "run-2").totals.netPay, 200);
});

Deno.test("HR-1: register handles numeric-string JSONB and empty snapshot", () => {
  const payroll = {
    runs: [{ id: "run-1" }],
    entries: [{ employeeId: "e1", basicPay: "45000", allowances: "8500", deductions: "4200", netPay: "49300" }],
  };
  assertEquals(buildSalaryRegister(payroll, "run-1").totals.netPay, 49300);
  const empty = buildSalaryRegister({}, "run-x");
  assertEquals(empty.rows.length, 0);
  assertEquals(empty.totals.netPay, 0);
});

// --- HR-2 payslips ----------------------------------------------------------

Deno.test("HR-2: payslip splits earnings vs deductions and nets", () => {
  const payroll = {
    runs: [{ id: "run-1", period: "June" }],
    entries: [{ employeeId: "e1", employeeName: "A", basicPay: 40000, allowances: 5000, deductions: 3000, netPay: 42000 }],
  };
  const bundle = buildPayslips(payroll, "run-1");
  assertEquals(bundle.payslips.length, 1);
  const slip = bundle.payslips[0]!;
  assertEquals(slip.grossEarnings, 45000);
  assertEquals(slip.totalDeductions, 3000);
  assertEquals(slip.netPay, 42000);
  assertEquals(slip.earnings.map((l) => l.label), ["Basic pay", "Allowances"]);
});

// --- HR-6 muster status inference -------------------------------------------

const EMP: MusterEmployee[] = [
  { id: "e1", userId: "u1", code: "EMP-1", name: "Alice", dept: "academics" },
  { id: "e2", userId: "u2", code: "EMP-2", name: "Bob", dept: "transport" },
];

function checkIn(userId: string, iso: string): CheckInEvent {
  return { userId, employeeRef: "", eventType: "check_in", eventTime: iso };
}

Deno.test("HR-6: daysInMonth is correct incl. leap February", () => {
  assertEquals(daysInMonth("2026-06"), 30);
  assertEquals(daysInMonth("2026-02"), 28);
  assertEquals(daysInMonth("2024-02"), 29);
  assertEquals(daysInMonth("2026-01"), 31);
});

Deno.test("HR-6: present when checked-in before cutoff, late when after (09:15 default)", () => {
  const events = [
    checkIn("u1", "2026-06-01T08:00:00+00:00"), // day 1 present
    checkIn("u1", "2026-06-02T09:30:00+00:00"), // day 2 late (after 09:15)
    checkIn("u2", "2026-06-01T09:15:00+00:00"), // day 1 exactly at cutoff => present
  ];
  const muster = inferMuster("2026-06", EMP, events, {});
  assertEquals(muster.lateAfter, "09:15");
  const alice = muster.rows.find((r) => r.employeeId === "e1")!;
  assertEquals(alice.dailyStatus[0], "P");
  assertEquals(alice.dailyStatus[1], "L");
  // no check-in on remaining working days => Absent
  assertEquals(alice.dailyStatus[2], "A");
  const bob = muster.rows.find((r) => r.employeeId === "e2")!;
  assertEquals(bob.dailyStatus[0], "P"); // exactly at cutoff is NOT late
});

Deno.test("HR-6: earliest check-in of the day decides late/present", () => {
  const events = [
    checkIn("u1", "2026-06-01T10:00:00+00:00"), // later
    checkIn("u1", "2026-06-01T08:30:00+00:00"), // earlier -> wins -> present
  ];
  const muster = inferMuster("2026-06", [EMP[0]!], events, {});
  assertEquals(muster.rows[0]!.dailyStatus[0], "P");
});

Deno.test("HR-6: absent when no check-in on a working day; percent over working days", () => {
  // Alice checks in on 2 of 30 days => present 2, percent 7 (2/30).
  const events = [
    checkIn("u1", "2026-06-01T08:00:00+00:00"),
    checkIn("u1", "2026-06-15T08:00:00+00:00"),
  ];
  const muster = inferMuster("2026-06", [EMP[0]!], events, {});
  const alice = muster.rows[0]!;
  assertEquals(alice.presentCount, 2);
  assertEquals(alice.percent, Math.round((2 / 30) * 100)); // 7
  assertEquals(alice.dailyStatus.filter((s) => s === "A").length, 28);
});

Deno.test("HR-6: holidays are non-working '-' and excluded from the % denominator", () => {
  // Mark days 6, 7 as holidays; Alice present only on day 1.
  const events = [checkIn("u1", "2026-06-01T08:00:00+00:00")];
  const muster = inferMuster("2026-06", [EMP[0]!], events, { holidayDays: [6, 7] });
  assertEquals(muster.holidayDays, [6, 7]);
  const alice = muster.rows[0]!;
  assertEquals(alice.dailyStatus[5], "-"); // day 6
  assertEquals(alice.dailyStatus[6], "-"); // day 7
  // working days = 30 - 2 = 28, present 1 => percent = round(1/28*100) = 4
  assertEquals(alice.presentCount, 1);
  assertEquals(alice.percent, Math.round((1 / 28) * 100));
});

Deno.test("HR-6: employeeRef fallback attributes a ledger row without user_id", () => {
  const events: CheckInEvent[] = [
    { userId: "", employeeRef: "EMP-1", eventType: "check_in", eventTime: "2026-06-01T08:00:00+00:00" },
  ];
  const muster = inferMuster("2026-06", [EMP[0]!], events, {});
  assertEquals(muster.rows[0]!.dailyStatus[0], "P");
});

Deno.test("HR-6: check_out events never mark presence", () => {
  const events: CheckInEvent[] = [
    { userId: "u1", employeeRef: "", eventType: "check_out", eventTime: "2026-06-01T15:00:00+00:00" },
  ];
  const muster = inferMuster("2026-06", [EMP[0]!], events, {});
  assertEquals(muster.rows[0]!.dailyStatus[0], "A");
});

Deno.test("HR-6: custom lateAfter cutoff is honoured", () => {
  const events = [checkIn("u1", "2026-06-01T08:30:00+00:00")];
  const strict = inferMuster("2026-06", [EMP[0]!], events, { lateAfter: "08:00" });
  assertEquals(strict.rows[0]!.dailyStatus[0], "L"); // 08:30 > 08:00
});

// --- HR-4 leave balances ----------------------------------------------------

Deno.test("HR-4: leave balances compute used/remaining from approved requests only", () => {
  const leave = {
    requests: [
      { employeeId: "e1", leaveType: "casual", days: 3, status: "approved" },
      { employeeId: "e1", leaveType: "casual", days: 2, status: "pending" }, // ignored
      { employeeId: "e1", leaveType: "sick", days: 4, status: "approved" },
    ],
  };
  const report = buildLeaveBalanceReport(leave, EMP);
  assertEquals(report.leaveTypes, ["casual", "sick", "earned"]);
  const alice = report.rows.find((r) => r.employeeId === "e1")!;
  const casual = alice.balances.find((b) => b.leaveType === "casual")!;
  assertEquals(casual.available, 12);
  assertEquals(casual.used, 3); // pending excluded
  assertEquals(casual.remaining, 9);
  const sick = alice.balances.find((b) => b.leaveType === "sick")!;
  assertEquals(sick.remaining, 8);
  // Bob has no leave => full remaining
  const bob = report.rows.find((r) => r.employeeId === "e2")!;
  assertEquals(bob.balances.every((b) => b.used === 0 && b.remaining === b.available), true);
});

Deno.test("HR-4: remaining is clamped at 0 when over-used", () => {
  const leave = { requests: [{ employeeId: "e1", leaveType: "casual", days: 20, status: "approved" }] };
  const report = buildLeaveBalanceReport(leave, [EMP[0]!]);
  const casual = report.rows[0]!.balances.find((b) => b.leaveType === "casual")!;
  assertEquals(casual.remaining, 0);
});

// --- HR-5 headcount ---------------------------------------------------------

Deno.test("HR-5: headcount counts only active employees, grouped + sorted desc", () => {
  const employees = [
    { status: "active", department: "academics" },
    { status: "active", department: "academics" },
    { status: "active", department: "transport" },
    { status: "inactive", department: "academics" }, // excluded
    { status: "on_leave", department: "finance" }, // excluded
    { status: "active", department: "" }, // Unassigned
  ];
  const report = buildHeadcount(employees);
  assertEquals(report.total, 4);
  assertEquals(report.rows[0], { department: "academics", count: 2 });
  const depts = report.rows.map((r) => r.department);
  assertEquals(depts.includes("Unassigned"), true);
  assertEquals(depts.includes("transport"), true);
});

Deno.test("HR-5: empty employee list yields zero total and no rows", () => {
  const report = buildHeadcount([]);
  assertEquals(report.total, 0);
  assertEquals(report.rows.length, 0);
});
