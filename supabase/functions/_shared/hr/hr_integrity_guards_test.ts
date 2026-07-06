// HR integrity guards — payroll money-safety + leave decision immutability.
//
// Money-critical. These tests exercise the PURE guard transforms that the write
// handlers apply inside their snapshot mutators, so the exact HTTP status + error
// code a client receives is asserted DB-free (no live Postgres). The handlers
// re-throw whatever these transforms throw, and WriteValidationError.status /
// .code are the values written straight onto the error envelope by runWrite.
//
//   FEATURE 1 — payroll run integrity (gap a + b)
//     • re-processing a 'processed' run → 409 PAYROLL_RUN_ALREADY_PROCESSED
//     • netPay != basicPay + allowances - deductions → 422 PAYROLL_ENTRY_INVALID
//     • netPay < 0 → 422 PAYROLL_ENTRY_INVALID
//     • same employee twice in one run → 422 PAYROLL_ENTRY_INVALID
//   FEATURE 2 — leave decision immutability (gap c)
//     • deciding a non-'pending' request → 409 LEAVE_ALREADY_DECIDED
//
// The route/RBAC contract (403/503/402) is covered by qw4_hr_route_contract_test.

import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { WriteValidationError } from "../entity_write/module_write_handlers.ts";
import {
  applyLeaveDecision,
  applyPayrollRun,
  validatePayrollEntries,
} from "./hr_write_handlers.ts";

const EMP_A = "be100000-0000-4000-8000-000000000001";
const EMP_B = "be100000-0000-4000-8000-000000000002";

function entry(over: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: "entry_1",
    employeeId: EMP_A,
    employeeName: "Priya Sharma",
    basicPay: 45000,
    allowances: 8000,
    deductions: 5000,
    netPay: 48000, // 45000 + 8000 - 5000
    status: "processed",
    ...over,
  };
}

// ── FEATURE 1 (a): re-process rejected ────────────────────────────────────────

Deno.test("payroll: processing a fresh run succeeds and marks it processed", () => {
  const snap = {
    runs: [{ id: "pay_1", period: "May 2026", status: "pending" }],
    entries: [entry()],
  };
  const { next, processedRun } = applyPayrollRun(snap, "pay_1", "2026-06-01");
  assertEquals(processedRun.status, "processed");
  assertEquals(processedRun.processedOn, "2026-06-01");
  const runs = next.runs as Array<Record<string, unknown>>;
  assertEquals(runs[0]?.status, "processed");
});

Deno.test("payroll: an absent run is appended on first process", () => {
  const { next, processedRun } = applyPayrollRun({ runs: [], entries: [] }, "pay_new", "2026-07-01");
  assertEquals(processedRun.id, "pay_new");
  assertEquals((next.runs as unknown[]).length, 1);
});

Deno.test("payroll: RE-PROCESSING a processed run is rejected → 409 PAYROLL_RUN_ALREADY_PROCESSED", () => {
  const snap = {
    runs: [{ id: "pay_1", status: "processed", processedOn: "2026-06-01" }],
    entries: [entry()],
  };
  const err = assertThrows(
    () => applyPayrollRun(snap, "pay_1", "2026-07-01"),
    WriteValidationError,
  );
  assertEquals(err.status, 409);
  assertEquals(err.code, "PAYROLL_RUN_ALREADY_PROCESSED");
});

Deno.test("payroll: re-process guard does NOT mutate — no silent overwrite / double-pay", () => {
  const original = {
    runs: [{ id: "pay_1", status: "processed", processedOn: "2026-06-01" }],
    entries: [entry()],
  };
  const snapshot = structuredClone(original);
  assertThrows(() => applyPayrollRun(snapshot, "pay_1", "2026-07-01"));
  // The handler discards the mutator's return on throw and keeps `current`; the
  // input object itself is never written in place.
  assertEquals(snapshot, original);
});

// ── FEATURE 1 (b): per-entry validation ───────────────────────────────────────

Deno.test("payroll: valid entries pass validation", () => {
  validatePayrollEntries([entry(), entry({ id: "entry_2", employeeId: EMP_B })]);
});

Deno.test("payroll: rounding within 1 unit is tolerated", () => {
  // 45000 + 8000 - 5000 = 48000; netPay 48001 is within the 1-unit tolerance.
  validatePayrollEntries([entry({ netPay: 48001 })]);
});

Deno.test("payroll: netPay != basic + allowances - deductions is rejected → 422 PAYROLL_ENTRY_INVALID", () => {
  const err = assertThrows(
    () => validatePayrollEntries([entry({ netPay: 60000 })]), // should be 48000
    WriteValidationError,
  );
  assertEquals(err.status, 422);
  assertEquals(err.code, "PAYROLL_ENTRY_INVALID");
  // Names the offending employee.
  assertEquals(err.message.includes(EMP_A), true);
});

Deno.test("payroll: a NEGATIVE netPay is rejected → 422 (never pay a negative net)", () => {
  // Make the arithmetic internally consistent so the ONLY failing invariant is
  // netPay >= 0: 0 + 0 - 5000 = -5000.
  const err = assertThrows(
    () => validatePayrollEntries([entry({ basicPay: 0, allowances: 0, deductions: 5000, netPay: -5000 })]),
    WriteValidationError,
  );
  assertEquals(err.status, 422);
  assertEquals(err.code, "PAYROLL_ENTRY_INVALID");
  assertEquals(err.message.includes("negative"), true);
});

Deno.test("payroll: the SAME employee twice in one run is rejected → 422 (per-run per-employee uniqueness)", () => {
  const err = assertThrows(
    () => validatePayrollEntries([entry(), entry({ id: "entry_dup" })]), // both EMP_A
    WriteValidationError,
  );
  assertEquals(err.status, 422);
  assertEquals(err.code, "PAYROLL_ENTRY_INVALID");
  assertEquals(err.message.includes("more than once"), true);
});

Deno.test("payroll: an invalid entry blocks the whole run (applyPayrollRun surfaces the 422)", () => {
  const snap = {
    runs: [{ id: "pay_1", status: "pending" }],
    entries: [entry({ netPay: 99999 })],
  };
  const err = assertThrows(() => applyPayrollRun(snap, "pay_1", "2026-06-01"), WriteValidationError);
  assertEquals(err.status, 422);
  assertEquals(err.code, "PAYROLL_ENTRY_INVALID");
});

// ── FEATURE 2: leave decision immutability ────────────────────────────────────

function leaveSnap(status: string): Record<string, unknown> {
  return {
    requests: [
      { id: "lv_1", employeeId: EMP_A, status, days: 3 },
      { id: "lv_2", employeeId: EMP_B, status: "pending", days: 1 },
    ],
    pendingCount: status === "pending" ? 2 : 1,
  };
}

Deno.test("leave: deciding a pending request succeeds and recomputes pendingCount", () => {
  const { next, updated } = applyLeaveDecision(leaveSnap("pending"), "lv_1", "approved", "ok");
  assertEquals(updated.status, "approved");
  assertEquals(updated.decisionComment, "ok");
  assertEquals(next.pendingCount, 1); // lv_2 remains pending
});

Deno.test("leave: deciding an unknown request → 404 (WriteNotFoundError)", () => {
  // WriteNotFoundError is not a WriteValidationError; assert by name.
  const err = assertThrows(() => applyLeaveDecision(leaveSnap("pending"), "lv_missing", "approved", ""));
  assertEquals((err as Error).name, "WriteNotFoundError");
});

Deno.test("leave: re-approving an APPROVED request is rejected → 409 LEAVE_ALREADY_DECIDED", () => {
  const err = assertThrows(
    () => applyLeaveDecision(leaveSnap("approved"), "lv_1", "approved", ""),
    WriteValidationError,
  );
  assertEquals(err.status, 409);
  assertEquals(err.code, "LEAVE_ALREADY_DECIDED");
});

Deno.test("leave: flipping an APPROVED request to rejected is rejected → 409 LEAVE_ALREADY_DECIDED", () => {
  const err = assertThrows(
    () => applyLeaveDecision(leaveSnap("approved"), "lv_1", "rejected", ""),
    WriteValidationError,
  );
  assertEquals(err.status, 409);
  assertEquals(err.code, "LEAVE_ALREADY_DECIDED");
});

Deno.test("leave: re-deciding a REJECTED request is rejected → 409 LEAVE_ALREADY_DECIDED", () => {
  const err = assertThrows(
    () => applyLeaveDecision(leaveSnap("rejected"), "lv_1", "approved", ""),
    WriteValidationError,
  );
  assertEquals(err.status, 409);
  assertEquals(err.code, "LEAVE_ALREADY_DECIDED");
});

// HR-3 SoD — a snapshot whose pending request records who filed it (`createdBy`).
function leaveSnapFiledBy(filedBy: string): Record<string, unknown> {
  return {
    requests: [
      { id: "lv_1", employeeId: EMP_A, status: "pending", days: 3, createdBy: filedBy },
    ],
    pendingCount: 1,
  };
}

Deno.test("leave SoD: the actor who FILED a request cannot approve it → 403 LEAVE_SELF_APPROVE_DENIED", () => {
  const err = assertThrows(
    () => applyLeaveDecision(leaveSnapFiledBy("user_hr_1"), "lv_1", "approved", "", "user_hr_1"),
    WriteValidationError,
  );
  assertEquals(err.status, 403);
  assertEquals(err.code, "LEAVE_SELF_APPROVE_DENIED");
});

Deno.test("leave SoD: the actor who filed a request cannot REJECT it either → 403", () => {
  const err = assertThrows(
    () => applyLeaveDecision(leaveSnapFiledBy("user_hr_1"), "lv_1", "rejected", "", "user_hr_1"),
    WriteValidationError,
  );
  assertEquals(err.status, 403);
  assertEquals(err.code, "LEAVE_SELF_APPROVE_DENIED");
});

Deno.test("leave SoD: a DIFFERENT approver may decide a request someone else filed", () => {
  const { updated } = applyLeaveDecision(
    leaveSnapFiledBy("user_hr_1"),
    "lv_1",
    "approved",
    "ok",
    "user_hr_2",
  );
  assertEquals(updated.status, "approved");
});

Deno.test("leave SoD: with no actor (legacy/unset) the self-approve guard does not fire", () => {
  const { updated } = applyLeaveDecision(leaveSnapFiledBy("user_hr_1"), "lv_1", "approved", "ok");
  assertEquals(updated.status, "approved");
});
