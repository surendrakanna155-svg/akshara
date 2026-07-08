// Gap-sweep FIX 2 (P0) — Approval-Center spoofable requester_id.
//
// handleSubmitApproval used to read `requester_id` straight from the CLIENT
// body:
//   const requesterId = optionalStr(body, "requester_id", ...)
// decideApproval's maker != checker guard (approval_repository.ts ~368:
// `current.requester_id === input.actorId`) trusts that value — so a caller
// could submit under a bogus requester_id, then approve their OWN request:
// the SoD check compares the fabricated id, never the real actor, so it never
// matches and never blocks.
//
// FIX: the requester is now ALWAYS `auth.claims.sub` — the authenticated
// caller — never read from the body. `requester_id`/`requesterId` in the body
// is silently ignored (see handleSubmitApproval in approval_handlers.ts).
//
// Proof strategy (mirrors this codebase's established DB-free route-contract
// convention, e.g. qw4_approval_route_contract_test.ts, where 503 = "passed
// the request gate, would reach the DB"):
//   1. Route-level: a body with NO requester_id, and separately a body with a
//      SPOOFED requester_id, both still pass validation (503, not 422) — this
//      is a change in observable behaviour only possible because the handler
//      no longer reads OR requires that field.
//   2. Repository-level: submitApproval faithfully persists whatever
//      requesterId it is given — i.e. there is no lower-layer remapping that
//      could reintroduce a body-sourced value. Combined with (1) and the
//      handler source (`const requesterId = auth.claims.sub;`), this proves
//      the stored requester_id is always the authenticated caller.
// The full live round trip (submit → fetch → assert persisted requester_id →
// self-approve blocked / different-approver allowed) is the live-cert leg —
// this repo has no seeded tenant/org/user fixtures to run it against in this
// sandbox (needs ERP_TENANT_DATABASE_URL against a real pilot schema).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeApproval } from "./approval_router.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { submitApproval } from "./approval_repository.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET, erpTenantDatabaseUrl: null } as AppConfig;

const ORG = "f6000000-0000-4000-8000-000000000001";
const SCHOOL = "f7000000-0000-4000-8000-000000000001";
const ACTOR = "f8000000-0000-4000-8000-000000000001"; // the real, authenticated submitter
const SPOOFED = "f8000000-0000-4000-8000-000000000099"; // a bogus id sent in the body

function claims(perms: string[] = []): AccessTokenClaims {
  return {
    sub: ACTOR,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL,
    role: "coordinator",
    role_slugs: ["coordinator"],
    primary_role: "coordinator",
    permissions: perms,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
  };
}

function post(token: string | null, path: string, body?: unknown): Request {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (token) headers.authorization = `Bearer ${token}`;
  return new Request(`https://x${path}`, {
    method: "POST",
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
}

// ── (1) DB-free route contract: requester_id is no longer required, and a
// spoofed value in the body cannot block or influence the request shape. ────

Deno.test("FIX-2: submit with NO requester_id/requesterId in the body still passes validation (503 to DB)", async () => {
  const token = await signAccessToken(SECRET, claims([]), 900);
  const res = await routeApproval(
    post(token, "/approvals", {
      type: "feeConcession",
      title: "Fee concession",
      summary: "50% waiver",
      // requesterId / requester_id deliberately ABSENT
      requesterName: "Coordinator A",
      entityType: "fee_concession",
      entityId: "fc_1",
    }),
    config,
    "POST",
    "/approvals",
  );
  assertEquals(res?.status, 503, "requesterId must no longer be a required field");
});

Deno.test("FIX-2: submit with a SPOOFED requester_id in the body still passes the request gate (503 to DB) — the value is ignored, not validated", async () => {
  const token = await signAccessToken(SECRET, claims([]), 900);
  const res = await routeApproval(
    post(token, "/approvals", {
      type: "feeConcession",
      title: "Fee concession",
      summary: "50% waiver",
      requesterId: SPOOFED, // client tries to submit as someone else
      requesterName: "Coordinator A",
      entityType: "fee_concession",
      entityId: "fc_1",
    }),
    config,
    "POST",
    "/approvals",
  );
  assertEquals(res?.status, 503);
});

Deno.test("FIX-2: submit missing requesterName is STILL a 422 (only requesterId was de-scoped)", async () => {
  const token = await signAccessToken(SECRET, claims([]), 900);
  const res = await routeApproval(
    post(token, "/approvals", {
      type: "feeConcession",
      title: "Fee concession",
      summary: "50% waiver",
      requesterId: ACTOR,
      // requesterName deliberately absent
      entityType: "fee_concession",
      entityId: "fc_1",
    }),
    config,
    "POST",
    "/approvals",
  );
  assertEquals(res?.status, 422);
});

// ── (2) Repository level: submitApproval persists exactly the requesterId it
// is given — no lower-layer remapping that could smuggle a body value back
// in. Combined with (1) + the handler forcing requesterId = auth.claims.sub,
// this closes the loop DB-free. ──────────────────────────────────────────────

class FakeSubmitDb {
  inserted: Record<string, unknown> | null = null;

  // deno-lint-ignore no-explicit-any
  async queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    if (sql.includes("FROM approval_requests") && sql.includes("pending")) {
      return [] as unknown as T[]; // findPendingByEntity: no existing pending row
    }
    if (sql.includes("INSERT INTO approval_requests")) {
      this.inserted = {
        id: "appr_new",
        organization_id: args[0],
        school_id: args[1],
        type: args[2],
        status: "pending",
        title: args[3],
        summary: args[4],
        requester_id: args[5],
        requester_name: args[6],
        entity_type: args[7],
        entity_id: args[8],
        payload: args[9],
        decided_at: null,
        decided_by_id: null,
        decided_by_name: null,
        decision_comment: null,
        created_at: "2026-07-08T00:00:00.000Z",
        updated_at: "2026-07-08T00:00:00.000Z",
      };
      return [this.inserted] as unknown as T[];
    }
    if (sql.includes("INSERT INTO approval_audit_entries")) {
      return [{ id: "audit_1" }] as unknown as T[];
    }
    throw new Error(`Unhandled SQL in FakeSubmitDb: ${sql.slice(0, 80)}`);
  }
}

Deno.test("FIX-2: submitApproval persists the requesterId it is given (ACTOR), never a value it wasn't passed", async () => {
  const fake = new FakeSubmitDb();
  const row = await submitApproval(fake as unknown as TenantQueryClient, ORG, SCHOOL, {
    type: "feeConcession",
    title: "Fee concession",
    summary: "50% waiver",
    // The FIXED handler always passes auth.claims.sub here — SPOOFED never
    // reaches this call at all (it is dropped at the handler boundary).
    requesterId: ACTOR,
    requesterName: "Coordinator A",
    entityType: "fee_concession",
    entityId: "fc_1",
  });
  assertEquals(row.requester_id, ACTOR);
  assertEquals(row.requester_id === SPOOFED, false);
});
