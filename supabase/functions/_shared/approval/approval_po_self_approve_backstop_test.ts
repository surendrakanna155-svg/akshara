// Gap-sweep FIX 1 (P0) — Purchase-order maker-checker, Approval-Center leg.
//
// approvePurchaseOrder() (inventory_finance_repository.ts) gained a repo-level
// maker != checker guard (PurchaseOrderSelfApproveDeniedError) — see
// inventory_finance_repository_test.ts for the direct-route proof. This file
// proves the SAME guard is a working BACKSTOP inside the Approval-Center path
// (decideOne → orchestrateApprovalDecision → applyApprovalTypeHandler's
// "inventoryPo" case → approvePurchaseOrder), for the case where it fires
// independently of decideApproval's own requester_id check — e.g. the
// approval_requests.requester_id has drifted from the purchase_orders'
// own requested_by (a second, defense-in-depth identity of "who asked for
// this"). Without wiring this error into decideOne's outcome mapping, it would
// escape as an unmapped exception instead of a clean 403 (see
// approval_handlers.ts decideOne's catch block).
//
// The everyday case — the SAME requester_id on both the approval row and the
// PO — is already covered by approval_batch_decide_test.ts ("inventoryPo: the
// requester cannot approve their own PO").

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import type { ApprovalRequestRow } from "./approval_types.ts";
import { decideOne } from "./approval_handlers.ts";

const ORG = "f1000000-0000-4000-8000-000000000001";
const SCHOOL = "f2000000-0000-4000-8000-000000000001";
const APPROVAL_ID = "f3000000-0000-4000-8000-000000000001";
const PO_ID = "f4000000-0000-4000-8000-000000000001";
// The PO's OWN requested_by — this is who the repo-level guard protects.
const PO_REQUESTER = "f5000000-0000-4000-8000-000000000001";
// A different approver — decides successfully.
const CHECKER = "f5000000-0000-4000-8000-000000000002";
// The approval_requests row's OWN requester_id — deliberately a THIRD identity,
// so decideApproval's own requester_id === actorId check does not fire; only
// the inner PO-level guard can catch the PO_REQUESTER trying to decide.
const APPROVAL_REQUESTER = "f5000000-0000-4000-8000-000000000003";

function claims(sub: string): AccessTokenClaims {
  return {
    sub,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL,
    role: "storekeeper",
    role_slugs: ["storekeeper"],
    primary_role: "storekeeper",
    permissions: ["approvePurchaseOrder"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
  };
}

function approvalRow(): ApprovalRequestRow {
  return {
    id: APPROVAL_ID,
    organization_id: ORG,
    school_id: SCHOOL,
    type: "inventoryPo",
    status: "pending",
    title: "Approve PO-1001",
    summary: "PO-1001",
    requester_id: APPROVAL_REQUESTER,
    requester_name: "Approval submitter",
    entity_type: "purchase_order",
    entity_id: PO_ID,
    payload: {},
    decided_at: null,
    decided_by_id: null,
    decided_by_name: null,
    decision_comment: null,
    created_at: "2026-07-08T00:00:00.000Z",
    updated_at: "2026-07-08T00:00:00.000Z",
  };
}

class FakeDb {
  approval = approvalRow();
  po = {
    id: PO_ID,
    po_number: "PO-1001",
    vendor_id: "vendor-1",
    status: "draft",
    total_amount: 4000,
    currency: "INR",
    created_at: "2026-07-08T00:00:00.000Z",
    requested_by: PO_REQUESTER,
  };

  // deno-lint-ignore no-explicit-any
  async queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    if (sql.includes("SELECT * FROM approval_requests")) {
      return [{ ...this.approval }] as unknown as T[];
    }
    if (sql.includes("UPDATE approval_requests")) {
      this.approval = { ...this.approval, status: "approved" };
      return [{ ...this.approval }] as unknown as T[];
    }
    if (sql.includes("INSERT INTO approval_audit_entries")) {
      return [{ id: "audit_1" }] as unknown as T[];
    }
    if (sql.includes("FROM purchase_orders")) {
      return (this.po.id === args[0] ? [{ ...this.po }] : []) as unknown as T[];
    }
    if (sql.includes("UPDATE purchase_orders") && sql.includes("SET status = 'approved'")) {
      this.po = { ...this.po, status: "approved" };
      return [] as unknown as T[];
    }
    if (sql.includes("INSERT INTO finance_ap_commitments")) {
      return [{ id: "ap_1" }] as unknown as T[];
    }
    if (sql.includes("INSERT INTO inventory_finance_postings")) {
      return [{ id: "posting_1" }] as unknown as T[];
    }
    if (sql.includes("INSERT INTO procurement_finance_links")) {
      return [] as unknown as T[];
    }
    if (sql.includes("INSERT INTO approval_domain_effects")) {
      return [] as unknown as T[];
    }
    throw new Error(`Unhandled SQL in FakeDb: ${sql.slice(0, 80)}`);
  }
}

Deno.test("decideOne: inventoryPo backstop — PO's own requester deciding is denied (kind='denied'), nothing mutated", async () => {
  const fake = new FakeDb();
  const outcome = await decideOne(
    fake as unknown as TenantQueryClient,
    claims(PO_REQUESTER),
    ORG,
    SCHOOL,
    APPROVAL_ID,
    "approved",
    null,
    PO_REQUESTER, // actor === po.requested_by, but != approval.requester_id
    "PO requester",
  );
  assertEquals(outcome.kind, "denied");
  // The PO row itself is the money-critical invariant: approvePurchaseOrder's
  // guard runs BEFORE any UPDATE, so it is provably never mutated regardless
  // of transaction wrapping. (decideApproval's own UPDATE approval_requests
  // runs earlier in this same function and this DB-free fake has no
  // transaction/rollback semantics to model it — in the live system that
  // write is undone too, by the single BEGIN/COMMIT/ROLLBACK transaction
  // withTenantContext wraps around the whole decideOne call.)
  assertEquals(fake.po.status, "draft", "PO must stay draft on a blocked self-approve");
});

Deno.test("decideOne: inventoryPo backstop — a genuinely different approver succeeds", async () => {
  const fake = new FakeDb();
  const outcome = await decideOne(
    fake as unknown as TenantQueryClient,
    claims(CHECKER),
    ORG,
    SCHOOL,
    APPROVAL_ID,
    "approved",
    null,
    CHECKER,
    "Checker",
  );
  assertEquals(outcome.kind, "decided");
  assertEquals(fake.po.status, "approved");
  assertEquals(fake.approval.status, "approved");
});
