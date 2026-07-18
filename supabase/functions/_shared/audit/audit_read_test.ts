// PRA-P1-53 (S2) — read route for the immutable audit trail.
//
// Proven here (DB-free):
//   1. REPOSITORY (mockDb seam): listAuditEvents lists newest-first with
//      LIMIT/OFFSET, caps pageSize at 100, and maps every filter (actor /
//      entityType / entityId / eventType / fromDate / toDate) to a WHERE
//      predicate + bound arg — the SQL never bypasses the tenant client.
//   2. ROUTE CONTRACT: GET /audit/events is 401 unauthenticated, 403 for a
//      non-holder of viewManagement, and 503 for a holder (reaches the tenant
//      DB, which is not configured in a unit test) — i.e. the permission gate
//      is the sole thing standing between a caller and the trail.
//
// Live RLS org/school row scoping + 200 happy-path = live-cert remainder.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { listAuditEvents } from "./audit_repository.ts";
import { routeAudit } from "./audit_router.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const ACTOR = "a3000000-0000-4000-8000-000000000001";

interface CapturedQuery {
  sql: string;
  args: unknown[];
}

class MockListAuditDb {
  countCalls: CapturedQuery[] = [];
  selectCalls: CapturedQuery[] = [];
  totalToReturn = 0;
  rowsToReturn: Array<Record<string, unknown>> = [];

  queryCount(sql: string, args: unknown[] = []): Promise<number> {
    this.countCalls.push({ sql, args });
    return Promise.resolve(this.totalToReturn);
  }

  queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    this.selectCalls.push({ sql, args });
    return Promise.resolve(this.rowsToReturn as T[]);
  }
}

function claims(perms: string[]): AccessTokenClaims {
  return {
    sub: ACTOR,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL_A,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: perms,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "test",
  };
}

// ── Repository: SELECT construction + filter → SQL mapping ──────────────────

Deno.test("PRA-P1-53: listAuditEvents lists newest-first, tenant-scoped, paginated", async () => {
  const mock = new MockListAuditDb();
  mock.totalToReturn = 42;
  mock.rowsToReturn = [{ id: "evt-1", event_type: "markUpdated" }];
  const db = mock as unknown as TenantQueryClient;

  const page = await listAuditEvents(db, claims([]), {}, { page: 2, pageSize: 20 });

  const select = mock.selectCalls[0];
  // Newest-first + bounded window.
  assertEquals(select.sql.includes("FROM audit_events"), true);
  assertEquals(select.sql.includes("ORDER BY created_at DESC"), true);
  assertEquals(select.sql.includes("LIMIT $2 OFFSET $3"), true);
  // Tenant predicate is always present (defense-in-depth beside RLS).
  assertEquals(select.sql.includes("organization_id = $1"), true);
  assertEquals(select.args[0], ORG);
  // page 2 @ 20/page → LIMIT 20 OFFSET 20.
  assertEquals(select.args[1], 20);
  assertEquals(select.args[2], 20);

  assertEquals(page.total, 42);
  assertEquals(page.page, 2);
  assertEquals(page.pageSize, 20);
  assertEquals(page.hasMore, true); // offset 20 + 1 row < 42
  assertEquals(page.items.length, 1);
});

Deno.test("PRA-P1-53: pageSize is capped at 100", async () => {
  const mock = new MockListAuditDb();
  const db = mock as unknown as TenantQueryClient;
  const page = await listAuditEvents(db, claims([]), {}, { page: 1, pageSize: 5000 });
  assertEquals(page.pageSize, 100);
  // LIMIT arg is the capped size.
  assertEquals(mock.selectCalls[0].args[1], 100);
});

Deno.test("PRA-P1-53: every filter maps to a WHERE predicate + bound arg", async () => {
  const mock = new MockListAuditDb();
  const db = mock as unknown as TenantQueryClient;
  await listAuditEvents(
    db,
    claims([]),
    {
      actor: ACTOR,
      entityType: "exam_mark",
      entityId: "mark-99",
      eventType: "markUpdated",
      fromDate: "2026-01-01T00:00:00Z",
      toDate: "2026-12-31T23:59:59Z",
    },
    { page: 1, pageSize: 25 },
  );

  const { sql, args } = mock.selectCalls[0];
  // Each filter contributes a predicate...
  assertEquals(sql.includes("user_id = $2::uuid"), true);
  assertEquals(sql.includes("entity_type = $3"), true);
  assertEquals(sql.includes("entity_id = $4"), true);
  assertEquals(sql.includes("event_type = $5"), true);
  assertEquals(sql.includes("created_at >= $6::timestamptz"), true);
  assertEquals(sql.includes("created_at <= $7::timestamptz"), true);
  // ...and its value is bound in order (after the org id at $1).
  assertEquals(args.slice(0, 7), [
    ORG,
    ACTOR,
    "exam_mark",
    "mark-99",
    "markUpdated",
    "2026-01-01T00:00:00Z",
    "2026-12-31T23:59:59Z",
  ]);
  // LIMIT/OFFSET follow the filter args.
  assertEquals(args[7], 25);
  assertEquals(args[8], 0);

  // The COUNT query filters identically (same predicates, no LIMIT/OFFSET).
  const count = mock.countCalls[0];
  assertEquals(count.sql.includes("user_id = $2::uuid"), true);
  assertEquals(count.sql.includes("created_at <= $7::timestamptz"), true);
  assertEquals(count.sql.includes("LIMIT"), false);
});

// ── Route contract: 401 / 403 / 503 permission gate ────────────────────────

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

async function get(path: string, perms: string[]): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const req = new Request(`https://x${path}`, {
    method: "GET",
    headers: { authorization: `Bearer ${token}` },
  });
  return routeAudit(req, config, "GET", path.split("?")[0]);
}

Deno.test("PRA-P1-53: GET /audit/events is 401 unauthenticated", async () => {
  const req = new Request("https://x/audit/events", { method: "GET" });
  const res = await routeAudit(req, config, "GET", "/audit/events");
  assertEquals(res?.status, 401);
});

Deno.test("PRA-P1-53: GET /audit/events is 403 without viewManagement", async () => {
  const res = await get("/audit/events", ["viewFinance", "viewAdminHub"]);
  assertEquals(res?.status, 403);
  const body = await res!.json();
  assertEquals(body.error.code, "FORBIDDEN");
  assertEquals(body.error.message.includes("viewManagement"), true);
});

Deno.test("PRA-P1-53: GET /audit/events passes the gate with viewManagement (503 → tenant DB)", async () => {
  // With the permission the request clears auth + RBAC and reaches
  // withTenantContext, which 503s because no tenant DB is configured in a unit
  // test. Proves the permission is the only gate before the read executes.
  const res = await get("/audit/events?actor=" + ACTOR + "&eventType=markUpdated", ["viewManagement"]);
  assertEquals(res?.status, 503);
});
