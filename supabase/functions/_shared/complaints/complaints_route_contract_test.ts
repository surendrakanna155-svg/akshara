// PRC-A Batch 2 — complaints route/RBAC contract (DB-free): 401 unauthenticated,
// 403 without the right permission or scope, 422 for validation failures that
// must be rejected BEFORE any DB work, and 503 (authorized, DB-off) once the
// request reaches the tenant-DB layer. Mirrors the established DB-free
// contract-test pattern (clearance_waiver_route_contract_test.ts): with no
// supabaseUrl/erpTenantDatabaseUrl configured, `assertSessionValid` short-
// circuits to a no-op and `withTenantContext` throws
// TenantDbNotConfiguredError -> 503, letting the whole auth/RBAC/validation
// gate be proven without a live database. "Parent sees only their own" and
// the full transition table are proven at the repository layer
// (complaints_repository_test.ts); this proves the gate split + who reaches
// the DB layer.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeComplaints } from "./complaints_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(
  perms: string[],
  scope: "school" | "parent" | "student" = "school",
  sub = "u1",
): AccessTokenClaims {
  return {
    sub,
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: perms,
    permissions_version: 1,
    scope,
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
  };
}

async function call(
  method: string,
  path: string,
  perms: string[] | null,
  body?: unknown,
  scope: "school" | "parent" | "student" = "school",
  sub = "u1",
): Promise<Response | null> {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (perms !== null) {
    headers.authorization = `Bearer ${await signAccessToken(SECRET, claims(perms, scope, sub), 900)}`;
  }
  const req = new Request(`https://x${path}`, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  return routeComplaints(req, config, method, path);
}

const validRaise = { category: "facilities", title: "Broken fan", description: "Room 4B" };

// ── router prefix / not-found ───────────────────────────────────────────

Deno.test("routeComplaints: a non-/complaints path returns null (not ours)", async () => {
  const res = await routeComplaints(new Request("https://x/sis/students"), config, "GET", "/sis/students");
  assertEquals(res, null);
});

Deno.test("routeComplaints: an unmatched /complaints/* path returns null (central dispatcher 404s)", async () => {
  const res = await call("DELETE", "/complaints/abc", ["manageComplaints"]);
  assertEquals(res, null);
});

// ── raise ────────────────────────────────────────────────────────────────

Deno.test("raise: 401 unauthenticated", async () => {
  const res = await call("POST", "/complaints", null, validRaise);
  assertEquals(res?.status, 401);
});

Deno.test("raise: 403 without raiseComplaint", async () => {
  const res = await call("POST", "/complaints", ["manageComplaints"], validRaise);
  // manageComplaints alone does not grant raiseComplaint.
  assertEquals(res?.status, 403);
});

Deno.test("raise: authorized (raiseComplaint) reaches the DB layer -> 503 when DB-off", async () => {
  const res = await call("POST", "/complaints", ["raiseComplaint"], validRaise);
  assertEquals(res?.status, 503);
});

Deno.test("raise: a PARENT with raiseComplaint also reaches the DB layer (parents may raise)", async () => {
  const res = await call("POST", "/complaints", ["raiseComplaint"], validRaise, "parent");
  assertEquals(res?.status, 503);
});

Deno.test("raise: an invalid category 422s BEFORE any DB work", async () => {
  const res = await call("POST", "/complaints", ["raiseComplaint"], {
    category: "not-a-real-category",
    title: "Broken fan",
  });
  assertEquals(res?.status, 422);
});

Deno.test("raise: a too-short title 422s BEFORE any DB work", async () => {
  const res = await call("POST", "/complaints", ["raiseComplaint"], {
    category: "facilities",
    title: "x",
  });
  assertEquals(res?.status, 422);
});

Deno.test("raise: an invalid severity 422s", async () => {
  const res = await call("POST", "/complaints", ["raiseComplaint"], {
    category: "facilities",
    title: "Broken fan",
    severity: "urgent-ish",
  });
  assertEquals(res?.status, 422);
});

// ── list ─────────────────────────────────────────────────────────────────

Deno.test("list: 401 unauthenticated", async () => {
  const res = await call("GET", "/complaints", null);
  assertEquals(res?.status, 401);
});

Deno.test("list: 403 with none of raiseComplaint/manageComplaints/viewComplaintsPrincipal", async () => {
  const res = await call("GET", "/complaints", ["viewFinance"]);
  assertEquals(res?.status, 403);
});

Deno.test("list: any one of the three view-eligible permissions reaches the DB layer", async () => {
  for (const perm of ["raiseComplaint", "manageComplaints", "viewComplaintsPrincipal"]) {
    const res = await call("GET", "/complaints", [perm]);
    assertEquals(res?.status, 503, `${perm} should reach the DB layer`);
  }
});

Deno.test("list: a parent with raiseComplaint reaches the DB layer (own-only enforced downstream)", async () => {
  const res = await call("GET", "/complaints", ["raiseComplaint"], undefined, "parent");
  assertEquals(res?.status, 503);
});

// ── detail ───────────────────────────────────────────────────────────────

Deno.test("detail: 403 without any complaints permission", async () => {
  const res = await call("GET", "/complaints/c1", []);
  assertEquals(res?.status, 403);
});

Deno.test("detail: authorized reaches the DB layer", async () => {
  const res = await call("GET", "/complaints/c1", ["manageComplaints"]);
  assertEquals(res?.status, 503);
});

// ── assign ───────────────────────────────────────────────────────────────

Deno.test("assign: 403 without manageComplaints (raiseComplaint alone is not enough)", async () => {
  const res = await call("POST", "/complaints/c1/assign", ["raiseComplaint"], { assignedTo: "u2" });
  assertEquals(res?.status, 403);
});

Deno.test("assign: 422 without assignedTo, BEFORE any DB work", async () => {
  const res = await call("POST", "/complaints/c1/assign", ["manageComplaints"], {});
  assertEquals(res?.status, 422);
});

Deno.test("assign: authorized + valid body reaches the DB layer", async () => {
  const res = await call("POST", "/complaints/c1/assign", ["manageComplaints"], { assignedTo: "u2" });
  assertEquals(res?.status, 503);
});

// ── status ───────────────────────────────────────────────────────────────

Deno.test("status: a school-scope caller with NO complaints permission still reaches the DB layer — the assignee-or-manage decision is made INSIDE the transaction (it must read assigned_to first; a plain staff member with no complaints slug can legitimately be the assignee)", async () => {
  const res = await call("POST", "/complaints/c1/status", [], { status: "in_progress" });
  assertEquals(res?.status, 503);
});

Deno.test("status: 422 for an unknown status value, BEFORE any DB work", async () => {
  const res = await call("POST", "/complaints/c1/status", ["manageComplaints"], { status: "vaporized" });
  assertEquals(res?.status, 422);
});

Deno.test("status: manageComplaints reaches the DB layer (assignee-or-manage check happens inside the txn)", async () => {
  const res = await call("POST", "/complaints/c1/status", ["manageComplaints"], { status: "in_progress" });
  assertEquals(res?.status, 503);
});

Deno.test("status: a parent scope session is rejected — requires a school-scoped session", async () => {
  const res = await call(
    "POST",
    "/complaints/c1/status",
    ["manageComplaints"],
    { status: "in_progress" },
    "parent",
  );
  assertEquals(res?.status, 403);
});

// ── comment ──────────────────────────────────────────────────────────────

Deno.test("comment: 403 without any complaints permission", async () => {
  const res = await call("POST", "/complaints/c1/comment", [], { note: "hello" });
  assertEquals(res?.status, 403);
});

Deno.test("comment: 422 without a note", async () => {
  const res = await call("POST", "/complaints/c1/comment", ["manageComplaints"], {});
  assertEquals(res?.status, 422);
});

Deno.test("comment: a raiser-only parent reaches the DB layer to comment on their own", async () => {
  const res = await call(
    "POST",
    "/complaints/c1/comment",
    ["raiseComplaint"],
    { note: "any update?" },
    "parent",
  );
  assertEquals(res?.status, 503);
});

// ── vendor ───────────────────────────────────────────────────────────────

Deno.test("vendor: 403 without manageComplaints", async () => {
  const res = await call("POST", "/complaints/c1/vendor", ["raiseComplaint"], { vendorId: "v1" });
  assertEquals(res?.status, 403);
});

Deno.test("vendor: 422 without vendorId", async () => {
  const res = await call("POST", "/complaints/c1/vendor", ["manageComplaints"], {});
  assertEquals(res?.status, 422);
});

Deno.test("vendor: 422 for a negative repairCost, BEFORE any DB work", async () => {
  const res = await call("POST", "/complaints/c1/vendor", ["manageComplaints"], {
    vendorId: "v1",
    repairCost: -50,
  });
  assertEquals(res?.status, 422);
});

Deno.test("vendor: authorized + valid body reaches the DB layer", async () => {
  const res = await call("POST", "/complaints/c1/vendor", ["manageComplaints"], {
    vendorId: "v1",
    repairCost: 1200,
  });
  assertEquals(res?.status, 503);
});

// ── photo ────────────────────────────────────────────────────────────────

Deno.test("photo: 422 without a filename", async () => {
  const res = await call("POST", "/complaints/c1/photo", ["raiseComplaint"], {});
  assertEquals(res?.status, 422);
});

Deno.test("photo: 422 for a disallowed extension (e.g. .exe)", async () => {
  const res = await call("POST", "/complaints/c1/photo", ["raiseComplaint"], {
    filename: "payload.exe",
    contentType: "application/octet-stream",
  });
  assertEquals(res?.status, 422);
});

Deno.test("photo: a valid image filename reaches the DB layer", async () => {
  const res = await call("POST", "/complaints/c1/photo", ["raiseComplaint"], {
    filename: "fan.jpg",
    contentType: "image/jpeg",
    sizeBytes: 2048,
  });
  assertEquals(res?.status, 503);
});
