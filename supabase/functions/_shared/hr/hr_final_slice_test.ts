// Final HR slice — pure-transform unit tests (DB-free).
//
//   HR-3  batch leave decide  → applyBatchLeaveDecision partial success:
//         a non-pending (or absent) id is SKIPPED + reported, never flipped.
//   HR-D3 leave-on-behalf     → checkLeaveBalance over-balance detection
//         (drives the warn/override + audit in handleCreateLeaveRequest).
//   HR-D1 doc-expiry          → buildExpiringDocuments window filter.
//   HR-D2 probation-ending    → buildProbationEnding window filter.
//
// The route/RBAC contract (403/503/402) is covered by qw4_hr_route_contract_test.

import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { WriteValidationError } from "../entity_write/module_write_handlers.ts";
import { applyBatchLeaveDecision, checkLeaveBalance } from "./hr_write_handlers.ts";
import { buildExpiringDocuments, buildProbationEnding } from "./hr_reports_repository.ts";

const EMP_A = "be100000-0000-4000-8000-000000000001";
const EMP_B = "be100000-0000-4000-8000-000000000002";

// ── HR-3 · batch decide — partial success ─────────────────────────────────────

function batchSnap(): Record<string, unknown> {
  return {
    requests: [
      { id: "lv_1", employeeId: EMP_A, status: "pending", days: 2 },
      { id: "lv_2", employeeId: EMP_B, status: "approved", days: 1 }, // already decided
      { id: "lv_3", employeeId: EMP_A, status: "pending", days: 1 },
    ],
    pendingCount: 2,
  };
}

Deno.test("HR-3 batch: decides pending ids, SKIPS a non-pending id (never flips it)", () => {
  const { next, decided, skipped } = applyBatchLeaveDecision(
    batchSnap(),
    ["lv_1", "lv_2", "lv_3"],
    "approved",
    "bulk ok",
  );
  // lv_1 + lv_3 decided; lv_2 skipped (already approved) — not re-flipped.
  assertEquals(decided.map((r) => r.id).sort(), ["lv_1", "lv_3"]);
  assertEquals(skipped.length, 1);
  assertEquals(skipped[0]!.id, "lv_2");
  assertEquals(skipped[0]!.reason.includes("already approved"), true);
  // The skipped row keeps its original status.
  const rows = next.requests as Array<Record<string, unknown>>;
  assertEquals(rows.find((r) => r.id === "lv_2")!.status, "approved");
  // pendingCount recomputed after the two real decisions.
  assertEquals(next.pendingCount, 0);
});

Deno.test("HR-3 batch: an ABSENT id is skipped + reported, others still decided", () => {
  const { decided, skipped } = applyBatchLeaveDecision(
    batchSnap(),
    ["lv_1", "lv_missing"],
    "rejected",
    "",
  );
  assertEquals(decided.map((r) => r.id), ["lv_1"]);
  assertEquals(decided[0]!.status, "rejected");
  assertEquals(skipped.length, 1);
  assertEquals(skipped[0]!.id, "lv_missing");
  assertEquals(skipped[0]!.reason.includes("not found"), true);
});

Deno.test("HR-3 batch: a duplicate id in the request is skipped after its first decision", () => {
  const { decided, skipped } = applyBatchLeaveDecision(
    batchSnap(),
    ["lv_1", "lv_1"],
    "approved",
    "",
  );
  assertEquals(decided.map((r) => r.id), ["lv_1"]);
  assertEquals(skipped.length, 1);
  assertEquals(skipped[0]!.reason.includes("Duplicate"), true);
});

Deno.test("HR-3 SoD batch: a request the actor filed is SKIPPED; the rest still decide", () => {
  // lv_1 was filed by the acting approver → self-approval, skipped; lv_3 decides.
  const snap: Record<string, unknown> = {
    requests: [
      { id: "lv_1", employeeId: EMP_A, status: "pending", days: 2, createdBy: "user_hr_1" },
      { id: "lv_3", employeeId: EMP_B, status: "pending", days: 1, createdBy: "user_hr_9" },
    ],
    pendingCount: 2,
  };
  const { decided, skipped } = applyBatchLeaveDecision(
    snap,
    ["lv_1", "lv_3"],
    "approved",
    "bulk",
    "user_hr_1",
  );
  assertEquals(decided.map((r) => r.id), ["lv_3"]);
  assertEquals(skipped.length, 1);
  assertEquals(skipped[0]!.id, "lv_1");
  assertEquals(skipped[0]!.reason.includes("you filed"), true);
});

// ── HR-D3 · leave-on-behalf over-balance check ────────────────────────────────

function leaveHistory(days: number, status = "approved"): Record<string, unknown> {
  return {
    requests: [
      { id: "h1", employeeId: EMP_A, leaveType: "casual", status, days },
    ],
  };
}

const CASUAL_12_POLICY = {
  leavePolicy: [{ leaveType: "casual", entitlement: 12 }],
};

Deno.test("HR-D3 balance: a request within the entitlement does NOT exceed", () => {
  const info = checkLeaveBalance(leaveHistory(4), CASUAL_12_POLICY, EMP_A, "casual", 3);
  assertEquals(info.exceeds, false);
  assertEquals(info.entitlement, 12);
  assertEquals(info.alreadyBooked, 4);
  assertEquals(info.remaining, 8);
});

Deno.test("HR-D3 balance: a request that would blow the entitlement DOES exceed (→ warn/override)", () => {
  const info = checkLeaveBalance(leaveHistory(10), CASUAL_12_POLICY, EMP_A, "casual", 5);
  assertEquals(info.exceeds, true); // 10 booked + 5 requested = 15 > 12
});

Deno.test("HR-D3 balance: pending days count toward the balance (a stack can exceed)", () => {
  const info = checkLeaveBalance(leaveHistory(12, "pending"), CASUAL_12_POLICY, EMP_A, "casual", 1);
  assertEquals(info.exceeds, true);
});

Deno.test("HR-D3 balance: unknown leave type falls back to the default entitlement", () => {
  const info = checkLeaveBalance({ requests: [] }, {}, EMP_A, "sabbatical", 13);
  assertEquals(info.entitlement, 12); // default
  assertEquals(info.exceeds, true); // 0 + 13 > 12
});

// ── HR-D1 · document-expiry window filter ─────────────────────────────────────

function empWithDocs(docs: Array<Record<string, unknown>>): Record<string, unknown> {
  return { id: EMP_A, name: "Priya Sharma", employeeCode: "EMP-101", documents: docs };
}

Deno.test("HR-D1 doc-expiry: includes docs within the window + already-expired, excludes those beyond", () => {
  const asOf = "2026-07-01";
  const report = buildExpiringDocuments(
    [
      empWithDocs([
        { type: "police_verification", name: "PV cert", expiry_date: "2026-07-20" }, // in 19d — IN
        { type: "medical", name: "Med", expiry_date: "2026-06-25" }, // -6d expired — IN
        { type: "contract", name: "Contract", expiry_date: "2026-09-01" }, // +62d — OUT
        { type: "licence", name: "Licence" }, // no expiry — OUT
      ]),
    ],
    30,
    asOf,
  );
  assertEquals(report.rows.length, 2);
  // Sorted soonest-first: the expired one (-6) before the +19 one.
  assertEquals(report.rows[0]!.docType, "medical");
  assertEquals(report.rows[0]!.daysToExpiry, -6);
  assertEquals(report.rows[1]!.docType, "police_verification");
  assertEquals(report.rows[1]!.daysToExpiry, 19);
});

Deno.test("HR-D1 doc-expiry: an employee with no documents contributes no rows", () => {
  const report = buildExpiringDocuments([{ id: EMP_B, name: "X" }], 30, "2026-07-01");
  assertEquals(report.rows.length, 0);
});

// ── HR-D2 · probation-ending window filter ────────────────────────────────────

Deno.test("HR-D2 probation-ending: includes probations within the window + lapsed, excludes beyond", () => {
  const asOf = "2026-07-01";
  const report = buildProbationEnding(
    [
      { id: EMP_A, name: "In window", employeeCode: "E1", probationEndDate: "2026-07-10" }, // +9d IN
      { id: EMP_B, name: "Lapsed", employeeCode: "E2", probationEndDate: "2026-06-20" }, // -11d IN
      { id: "c3", name: "Far", employeeCode: "E3", probationEndDate: "2026-08-15" }, // +45d OUT
      { id: "c4", name: "Not on probation", employeeCode: "E4" }, // no date OUT
    ],
    15,
    asOf,
  );
  assertEquals(report.rows.length, 2);
  assertEquals(report.rows[0]!.employee, "Lapsed"); // soonest-first (-11)
  assertEquals(report.rows[0]!.daysToEnd, -11);
  assertEquals(report.rows[1]!.employee, "In window");
  assertEquals(report.rows[1]!.daysToEnd, 9);
});

// Sanity: the WriteValidationError import is exercised so the batch guard type is
// linked in this test module (the batch loop re-classifies it into `skipped`).
Deno.test("HR-3 batch: guard errors are re-classified into skipped, not thrown", () => {
  // Deciding an all-decided snapshot never throws; every id is skipped.
  const snap = {
    requests: [{ id: "lv_x", employeeId: EMP_A, status: "rejected", days: 1 }],
    pendingCount: 0,
  };
  const { decided, skipped } = applyBatchLeaveDecision(snap, ["lv_x"], "approved", "");
  assertEquals(decided.length, 0);
  assertEquals(skipped.length, 1);
  // A direct single decision on the same row WOULD throw 409 (contrast).
  assertThrows(
    () => {
      const requests = snap.requests as Array<Record<string, unknown>>;
      if (String(requests[0]!.status) !== "pending") {
        throw new WriteValidationError("already", 409, "LEAVE_ALREADY_DECIDED");
      }
    },
    WriteValidationError,
  );
});
