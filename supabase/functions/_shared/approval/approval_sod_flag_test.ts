import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { approvalRequestToApi } from "./approval_mapper.ts";
import { isSelfApproveDeniedType } from "./approval_repository.ts";
import type { ApprovalRequestRow } from "./approval_types.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";

function row(overrides: Partial<ApprovalRequestRow> = {}): ApprovalRequestRow {
  return {
    id: "appr_1",
    organization_id: ORG,
    school_id: SCHOOL,
    type: "inventoryPo",
    status: "pending",
    title: "Purchase order",
    summary: "5 whiteboards — ₹12,000",
    requester_id: "user_maker",
    requester_name: "Maker",
    entity_type: "purchase_order",
    entity_id: "po_1",
    payload: {},
    decided_at: null,
    decided_by_id: null,
    decided_by_name: null,
    decision_comment: null,
    created_at: "2026-06-12T00:00:00.000Z",
    updated_at: "2026-06-12T00:00:00.000Z",
    ...overrides,
  };
}

/**
 * P2-UX-2 §2.3 — the Approval Center's maker-checker badge reads a SERVER-owned
 * `sodBlocked` flag. These tests pin the single rule (the type set + the derived
 * flag) so the client never has to re-derive it.
 */
Deno.test("isSelfApproveDeniedType covers exactly the value-gating types", () => {
  for (const t of ["inventoryPo", "feeConcession", "refund", "feeStructure"]) {
    assertEquals(isSelfApproveDeniedType(t), true, t);
  }
  for (const t of ["studentLeave", "staffLeave", "examResults", "admission"]) {
    assertEquals(isSelfApproveDeniedType(t), false, t);
  }
});

Deno.test("approvalRequestToApi emits sodBlocked when told to", () => {
  const api = approvalRequestToApi(row(), { sodBlocked: true });
  assertEquals(api.sodBlocked, true);
});

Deno.test("approvalRequestToApi defaults sodBlocked to false", () => {
  assertEquals(approvalRequestToApi(row()).sodBlocked, false);
  // A non-value type is never blocked, whatever the viewer.
  assertEquals(
    approvalRequestToApi(row({ type: "studentLeave" }), { sodBlocked: false })
      .sodBlocked,
    false,
  );
});
