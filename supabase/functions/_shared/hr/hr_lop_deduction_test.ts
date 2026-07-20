// PRA-P1-36 — loss-of-pay (LOP) automation in payroll generation.
//
// Money-critical. Payroll generation used to compute each line from the salary
// structure ONLY, ignoring absence. These tests prove (DB-free) that
// generatePayrollRun now reads the REAL attendance + approved-unpaid-leave
// snapshots and folds an itemised LOP deduction into `deductions`, keeping the
// money-safety invariant netPay === basic + allowances − deductions intact.

import { assertEquals } from "jsr:@std/assert@1";
import {
  countLopDays,
  generatePayrollRun,
  validatePayrollEntries,
} from "./hr_write_handlers.ts";

const PERIOD = "2026-07";

function structure(over: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    employeeId: "e1",
    employeeCode: "EMP-1",
    employeeName: "Asha",
    department: "academics",
    basicPay: 30000, // per-day (÷30) = 1000
    allowances: 6000,
    deductions: 0,
    ...over,
  };
}

// ── countLopDays ─────────────────────────────────────────────────────────────

Deno.test("LOP: counts 'absent' attendance days in the period for the employee", () => {
  const attendance = {
    records: [
      { employeeId: "e1", date: "2026-07-03", status: "absent" },
      { employeeId: "e1", date: "2026-07-04", status: "absent" },
      { employeeId: "e1", date: "2026-07-05", status: "present" }, // ignored
      { employeeId: "e2", date: "2026-07-06", status: "absent" }, // other employee
      { employeeId: "e1", date: "2026-08-01", status: "absent" }, // other month
    ],
  };
  assertEquals(countLopDays("e1", PERIOD, attendance, {}), 2);
});

Deno.test("LOP: counts APPROVED unpaid-leave days, ignores paid leave", () => {
  const leave = {
    requests: [
      { employeeId: "e1", leaveType: "unpaid", status: "approved", fromDate: "2026-07-10", days: 3 },
      { employeeId: "e1", leaveType: "casual", status: "approved", fromDate: "2026-07-12", days: 2 }, // paid → ignored
      { employeeId: "e1", leaveType: "lwp", status: "pending", fromDate: "2026-07-15", days: 1 }, // not approved → ignored
    ],
  };
  assertEquals(countLopDays("e1", PERIOD, {}, leave), 3);
});

Deno.test("LOP: absence + approved unpaid leave are summed", () => {
  const attendance = { records: [{ employeeId: "e1", date: "2026-07-02", status: "absent" }] };
  const leave = {
    requests: [
      { employeeId: "e1", leaveType: "loss_of_pay", status: "approved", fromDate: "2026-07-20", days: 2 },
    ],
  };
  assertEquals(countLopDays("e1", PERIOD, attendance, leave), 3);
});

Deno.test("LOP: no attendance/leave snapshots → 0 LOP days (backwards compatible)", () => {
  assertEquals(countLopDays("e1", PERIOD, {}, {}), 0);
});

// ── generatePayrollRun folds LOP into deductions ─────────────────────────────

Deno.test("LOP: generatePayrollRun subtracts lopDays × (basic/payableDays), invariant intact", () => {
  const snap = { structures: [structure()] };
  const attendance = {
    records: [
      { employeeId: "e1", date: "2026-07-03", status: "absent" },
      { employeeId: "e1", date: "2026-07-04", status: "absent" },
    ],
  };
  const { entries } = generatePayrollRun(snap, { runId: "r", period: PERIOD, attendance });
  const e = entries[0]!;
  // 2 LOP days × (30000 / 30) = 2000.
  assertEquals(e.lopDays, 2);
  assertEquals(e.lopAmount, 2000);
  assertEquals(e.structuralDeductions, 0);
  assertEquals(e.deductions, 2000); // structural (0) + LOP (2000)
  assertEquals(e.netPay, 30000 + 6000 - 2000); // 34000
  // The folded entry still satisfies the processor's money-safety guards.
  validatePayrollEntries(entries as Array<Record<string, unknown>>);
});

Deno.test("LOP: structural deductions and LOP are folded together into `deductions`", () => {
  const snap = { structures: [structure({ deductions: 1500 })] };
  const attendance = { records: [{ employeeId: "e1", date: "2026-07-03", status: "absent" }] };
  const { entries } = generatePayrollRun(snap, { runId: "r", period: PERIOD, attendance });
  const e = entries[0]!;
  assertEquals(e.lopAmount, 1000); // 1 day × 1000/day
  assertEquals(e.structuralDeductions, 1500);
  assertEquals(e.deductions, 2500);
  assertEquals(e.netPay, 30000 + 6000 - 2500); // 33500
  validatePayrollEntries(entries as Array<Record<string, unknown>>);
});

Deno.test("LOP: a custom payableDays changes the per-day rate", () => {
  const snap = { structures: [structure({ basicPay: 26000 })] };
  const attendance = { records: [{ employeeId: "e1", date: "2026-07-03", status: "absent" }] };
  const { entries } = generatePayrollRun(snap, { runId: "r", period: PERIOD, attendance, payableDays: 26 });
  // 1 day × (26000 / 26) = 1000.
  assertEquals(entries[0]!.lopAmount, 1000);
});

Deno.test("LOP: deduction is clamped so net take-home never goes negative", () => {
  // Absent every day of a 30-day period → raw LOP (30 × 1000 = 30000) would wipe
  // basic; net must floor at 0 (= allowances - allowances), never negative.
  const snap = { structures: [structure({ basicPay: 30000, allowances: 0, deductions: 0 })] };
  const records = Array.from({ length: 30 }, (_, i) => ({
    employeeId: "e1",
    date: `2026-07-${String(i + 1).padStart(2, "0")}`,
    status: "absent",
  }));
  const { entries } = generatePayrollRun(snap, { runId: "r", period: PERIOD, attendance: { records } });
  const e = entries[0]!;
  assertEquals(e.netPay as number >= 0, true);
  assertEquals(e.lopAmount, 30000); // clamped to basic+allowances-structural = 30000
  assertEquals(e.netPay, 0);
  validatePayrollEntries(entries as Array<Record<string, unknown>>);
});

Deno.test("LOP: with no attendance/leave, generation matches the pre-P1-36 result", () => {
  const snap = { structures: [structure({ deductions: 2000 })] };
  const { entries } = generatePayrollRun(snap, { runId: "r", period: PERIOD });
  const e = entries[0]!;
  assertEquals(e.lopDays, 0);
  assertEquals(e.lopAmount, 0);
  assertEquals(e.deductions, 2000);
  assertEquals(e.netPay, 30000 + 6000 - 2000); // 34000
});
