// Wave 1 — approval-decision domain persistence (DB-free spy).
//
// GAP FIXED: in API mode the Approval Center is authoritative and the client
// adapter's onApproved side-effect is SKIPPED, so the BACKEND must persist the
// domain change. Previously `applyApprovalTypeHandler` only recorded an audit
// effect for staffLeave / studentLeave / inventoryPo — the leave row stayed
// "pending" and the PO stayed "draft" forever. These tests prove the handler now
// issues the real domain write (captured by a spy TenantQueryClient), in addition
// to the audit effect. The actual persisted row after a live decision is the
// Track-B live leg (needs ERP_TENANT_DATABASE_URL / RLS).

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { applyApprovalTypeHandler } from "./approval_type_handlers.ts";
import { flipLeaveDecision } from "./leave_decision_effect.ts";
import type { ApprovalRequestRow } from "./approval_types.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const ACTOR = "d1000000-0000-4000-8000-000000000002";

function approval(overrides: Partial<ApprovalRequestRow> = {}): ApprovalRequestRow {
  return {
    id: "appr_1",
    organization_id: ORG,
    school_id: SCHOOL,
    type: "studentLeave",
    status: "pending",
    title: "Leave",
    summary: "8A",
    requester_id: "req_1",
    requester_name: "Requester",
    entity_type: "leave",
    entity_id: "leave_1",
    payload: {},
    decided_at: null,
    decided_by_id: null,
    decided_by_name: null,
    decision_comment: null,
    created_at: "2026-07-01T00:00:00.000Z",
    updated_at: "2026-07-01T00:00:00.000Z",
    ...overrides,
  };
}

interface SpyOpts {
  mobileHit?: boolean; // UPDATE mobile_leave_requests returns a row
  snapshotLeaveId?: string; // lockSnapshot returns a snapshot holding this leave id
  poStatus?: string | null; // getPurchaseOrder result status (null = absent)
}

class SpyDb {
  readonly queries: { sql: string; args: unknown[] }[] = [];
  constructor(private readonly opts: SpyOpts = {}) {}

  queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    this.queries.push({ sql, args });
    if (sql.includes("UPDATE mobile_leave_requests")) {
      return Promise.resolve((this.opts.mobileHit ? [{ id: args[2] }] : []) as unknown as T[]);
    }
    if (sql.includes("FROM hr_entities") && sql.includes("FOR UPDATE")) {
      const id = this.opts.snapshotLeaveId;
      const payload = id ? { requests: [{ id, status: "pending" }], pendingCount: 1 } : null;
      return Promise.resolve((payload ? [{ payload }] : []) as unknown as T[]);
    }
    if (sql.includes("FROM purchase_orders")) {
      if (this.opts.poStatus == null) return Promise.resolve([] as T[]);
      return Promise.resolve([{
        id: args[0],
        po_number: "PO-1",
        vendor_id: "v1",
        status: this.opts.poStatus,
        total_amount: 1000,
        currency: "INR",
        created_at: "2026-07-01T00:00:00Z",
      }] as unknown as T[]);
    }
    // AP-commitment / posting inserts, snapshot replace/insert, domain-effect insert.
    return Promise.resolve([{ id: "gen_1", payload: {} }] as unknown as T[]);
  }

  captured(substr: string) {
    return this.queries.filter((q) => q.sql.includes(substr));
  }
}

const db = (spy: SpyDb): TenantQueryClient => spy as unknown as TenantQueryClient;

Deno.test("flipLeaveDecision: mobile_leave_requests hit flips by id with the new status", async () => {
  const spy = new SpyDb({ mobileHit: true });
  const r = await flipLeaveDecision(db(spy), ORG, SCHOOL, "leave_9", "approved");
  assertEquals(r, { updated: true, store: "mobile" });
  const upd = spy.captured("UPDATE mobile_leave_requests");
  assertEquals(upd.length, 1);
  assertEquals(upd[0].args[3], "approved");
  // no snapshot lookup once mobile matched
  assertEquals(spy.captured("FROM hr_entities").length, 0);
});

Deno.test("flipLeaveDecision: mobile miss falls through to the HR snapshot_leave store", async () => {
  const spy = new SpyDb({ mobileHit: false, snapshotLeaveId: "leave_1" });
  const r = await flipLeaveDecision(db(spy), ORG, SCHOOL, "leave_1", "rejected", "no docs");
  assertEquals(r.updated, true);
  assertEquals(r.store, "hr_snapshot");
  assert(spy.captured("FROM hr_entities").length >= 1, "snapshot store must be consulted");
});

Deno.test("flipLeaveDecision: id absent everywhere reports not-updated", async () => {
  const spy = new SpyDb({ mobileHit: false });
  const r = await flipLeaveDecision(db(spy), ORG, SCHOOL, "nope", "approved");
  assertEquals(r.updated, false);
  assertEquals(r.store, "none");
});

Deno.test("applyApprovalTypeHandler studentLeave approve → flips the leave row (not audit-only)", async () => {
  const spy = new SpyDb({ mobileHit: true });
  const payload = await applyApprovalTypeHandler(
    db(spy),
    ORG,
    SCHOOL,
    approval({ type: "studentLeave", entity_id: "leave_1" }),
    "approved",
    "ok",
    ACTOR,
  );
  assertEquals(payload.leaveRowUpdated, true);
  assertEquals(payload.leaveStore, "mobile");
  // proves it is no longer audit-only: a real leave-table write happened
  assertEquals(spy.captured("UPDATE mobile_leave_requests").length, 1);
});

Deno.test("applyApprovalTypeHandler staffLeave reject → flips snapshot leave + records effect", async () => {
  const spy = new SpyDb({ mobileHit: false, snapshotLeaveId: "leave_7" });
  const payload = await applyApprovalTypeHandler(
    db(spy),
    ORG,
    SCHOOL,
    approval({ type: "staffLeave", entity_id: "leave_7" }),
    "rejected",
    "insufficient",
    ACTOR,
  );
  assertEquals(payload.leaveStatus, "rejected");
  assertEquals(payload.leaveRowUpdated, true);
  assert(spy.captured("FROM hr_entities").length >= 1);
});

Deno.test("applyApprovalTypeHandler inventoryPo approve → flips purchase_orders to approved (finance-integrated)", async () => {
  const spy = new SpyDb({ poStatus: "draft" });
  const payload = await applyApprovalTypeHandler(
    db(spy),
    ORG,
    SCHOOL,
    approval({ type: "inventoryPo", entity_type: "purchase_order", entity_id: "po_1" }),
    "approved",
    undefined,
    ACTOR,
  );
  assertEquals(payload.poRowUpdated, true);
  assertEquals(payload.financeIntegrated, true);
  const upd = spy.captured("UPDATE purchase_orders");
  assertEquals(upd.length, 1);
  assert(upd[0].sql.includes("status = 'approved'"));
});

Deno.test("applyApprovalTypeHandler inventoryPo reject → flips purchase_orders to rejected (no finance posting)", async () => {
  const spy = new SpyDb({ poStatus: "draft" });
  const payload = await applyApprovalTypeHandler(
    db(spy),
    ORG,
    SCHOOL,
    approval({ type: "inventoryPo", entity_type: "purchase_order", entity_id: "po_1" }),
    "rejected",
    undefined,
    ACTOR,
  );
  assertEquals(payload.poRowUpdated, true);
  const upd = spy.captured("UPDATE purchase_orders");
  assertEquals(upd.length, 1);
  assert(upd[0].sql.includes("status = 'rejected'"));
  // reject must NOT create an AP commitment
  assertEquals(spy.captured("finance_ap_commitments").length, 0);
});

Deno.test("applyApprovalTypeHandler inventoryPo approve on a non-draft PO → audit-kept, row not re-applied", async () => {
  const spy = new SpyDb({ poStatus: "approved" }); // already decided
  const payload = await applyApprovalTypeHandler(
    db(spy),
    ORG,
    SCHOOL,
    approval({ type: "inventoryPo", entity_type: "purchase_order", entity_id: "po_1" }),
    "approved",
    undefined,
    ACTOR,
  );
  assertEquals(payload.poRowUpdated, false);
  assert(typeof payload.poNote === "string");
});

Deno.test("applyApprovalTypeHandler always records the domain effect (audit) alongside the row write", async () => {
  const spy = new SpyDb({ mobileHit: true });
  await applyApprovalTypeHandler(
    db(spy),
    ORG,
    SCHOOL,
    approval({ type: "studentLeave", entity_id: "leave_1" }),
    "approved",
    "ok",
    ACTOR,
  );
  assertEquals(spy.captured("INSERT INTO approval_domain_effects").length, 1);
});
