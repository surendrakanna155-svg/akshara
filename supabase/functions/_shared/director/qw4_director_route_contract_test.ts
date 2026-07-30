// QW4 · QA-B-027, QA-B-059 — Director portal ROUTE contract (DB-free).
//
// Proven here without a live Postgres (see the QW1 pattern in
// finance_collections_route_contract_test.ts): every registered /director path
// matches the router (no 404), an unregistered /director path 404s, and the two
// JSON writes (POST /director/metric-inputs, POST /director/summary) are denied
// for a non-holder (403 FORBIDDEN) yet pass the gate for a holder and reach the
// (unconfigured) tenant DB (503 = "authorized" DB-free proxy).
//
// QA-B-059 — org-scope deny leg: a SCHOOL-scope token (scope:"school") is denied
// (403) the org portfolio, provable from the `scope` claim alone via
// requireOrgScope. The cross-org DATA leg (org B token cannot READ org A's rows)
// can only be proven against live Postgres + the additive org-scope RLS policies
// (director_handlers.ts:6-8) — recorded as the infra remainder.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeDirector } from "./director_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

// Director is an org-level feature: tokens carry an organization scope.
function claims(perms: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u1", tenant_id: "org-1", organization_id: "org-1", school_id: null,
    role: "director", role_slugs: ["director"], primary_role: "director",
    permissions: perms, permissions_version: 1, scope: "organization",
    school_group_id: null, student_id: null, child_ids: [], session_id: "s1", ...over,
  };
}

async function raw(
  method: string, path: string, perms: string[], body?: unknown,
  over: Partial<AccessTokenClaims> = {},
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms, over), 900);
  const init: RequestInit = {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
  };
  if (body !== undefined) init.body = JSON.stringify(body);
  const req = new Request(`https://x${path}`, init);
  return await routeDirector(req, config, method, path);
}

async function call(
  method: string, path: string, perms: string[], body?: unknown,
  over: Partial<AccessTokenClaims> = {},
): Promise<Response> {
  const res = await raw(method, path, perms, body, over);
  if (res === null) throw new Error(`routeDirector returned null for ${method} ${path}`);
  return res;
}

// The registered director GET aggregates (incl. DIR-2 /director/collections).
const GET_ROUTES = [
  "/director/dashboard", "/director/schools", "/director/collections",
  "/director/portfolio", "/director/revenue",
  "/director/growth", "/director/marketing", "/director/admissions", "/director/compliance",
  "/director/reports", "/director/metric-inputs",
];

Deno.test("QA-B-027: all director routes match the router (never 404 NOT_FOUND)", async () => {
  // GET aggregates: holder reaches the unconfigured DB → 503 (matched, authorized).
  for (const path of GET_ROUTES) {
    const res = await call("GET", path, ["viewDirectorPortal"]);
    assertEquals(res.status, 503, `${path} should match + authorize, got ${res.status}`);
  }
  // The two JSON-write POSTs (summary needs viewDirectorPortal, metric-inputs needs manage).
  const summary = await call("POST", "/director/summary", ["viewDirectorPortal"], { focusArea: "dashboard" });
  assertEquals(summary.status, 503);
  const metric = await call("POST", "/director/metric-inputs", ["manageDirectorPortal"], {
    schoolId: "school-1", periodMonth: "2026-06",
  });
  assertEquals(metric.status, 503);
});

Deno.test("QA-B-027: an unregistered director POST path returns null (central dispatcher 404s)", async () => {
  // An unhandled method/path under the /director prefix (e.g. an unregistered
  // POST) is an in-prefix no-match, so the router returns null and the central
  // dispatcher owns the route-level 404.
  const res = await raw("POST", "/director/does-not-exist", ["viewDirectorPortal"], {});
  assertEquals(res, null);
});

Deno.test("QA-B-027: an unregistered director GET path returns null (→ 404 at dispatch)", async () => {
  // GET dispatch is table-driven: an unregistered GET key yields null, which the
  // central api dispatcher turns into a 404. Documents the exact router contract.
  const res = await raw("GET", "/director/does-not-exist", ["viewDirectorPortal"]);
  assertEquals(res, null);
});

Deno.test("QA-B-027: a non-/director path returns null (no match, → 404 at dispatch)", async () => {
  const token = await signAccessToken(SECRET, claims(["viewDirectorPortal"]), 900);
  const req = new Request("https://x/analytics/dashboard", {
    method: "GET", headers: { authorization: `Bearer ${token}` },
  });
  const res = await routeDirector(req, config, "GET", "/analytics/dashboard");
  assertEquals(res, null);
});

Deno.test("QA-B-027: POST /director/metric-inputs is denied for a non-holder (403 FORBIDDEN)", async () => {
  const res = await call("POST", "/director/metric-inputs", ["viewDirectorPortal"], {
    schoolId: "school-1", periodMonth: "2026-06",
  });
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-027: POST /director/metric-inputs passes the gate for a holder (503 DB-free)", async () => {
  const res = await call("POST", "/director/metric-inputs", ["manageDirectorPortal"], {
    schoolId: "school-1", periodMonth: "2026-06",
  });
  assertEquals(res.status, 503);
});

Deno.test("QA-B-027: POST /director/metric-inputs rejects a missing periodMonth (422) before the DB", async () => {
  const res = await call("POST", "/director/metric-inputs", ["manageDirectorPortal"], {
    schoolId: "school-1",
  });
  assertEquals(res.status, 422);
});

Deno.test("QA-B-027: POST /director/summary is denied for a non-holder (403 FORBIDDEN)", async () => {
  const res = await call("POST", "/director/summary", ["viewInventory"], { focusArea: "dashboard" });
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-027: POST /director/summary passes the gate for a holder (503 DB-free)", async () => {
  const res = await call("POST", "/director/summary", ["viewDirectorPortal"], { focusArea: "dashboard" });
  assertEquals(res.status, 503);
});

// ─── DIR-2 — consolidated collections route contract ────────────────────────
Deno.test("DIR-2: GET /director/collections denies a non-holder (403 FORBIDDEN)", async () => {
  const res = await call("GET", "/director/collections", ["viewInventory"]);
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("DIR-2: GET /director/collections passes the gate for a holder (503 DB-free)", async () => {
  const res = await call("GET", "/director/collections", ["viewDirectorPortal"]);
  assertEquals(res.status, 503);
});

Deno.test("DIR-2: a school-scope token is denied (403) the consolidated collections", async () => {
  const res = await call("GET", "/director/collections", ["viewDirectorPortal"], undefined, {
    scope: "school", school_id: "school-1",
  });
  assertEquals(res.status, 403);
});

// ─── DIR-D1 — per-school drill-down snapshot route contract ──────────────────
const SNAPSHOT = "/director/schools/school-1/snapshot";

Deno.test("DIR-D1: snapshot route matches the router (parameterized GET, never 404)", async () => {
  // Holder reaches the unconfigured DB → 503 (matched + authorized). Proves the
  // SNAPSHOT_RE matcher runs before the static GET table (no 404/null).
  const res = await call("GET", SNAPSHOT, ["viewDirectorPortal"]);
  assertEquals(res.status, 503);
});

Deno.test("DIR-D1: snapshot is denied for a non-holder (403 FORBIDDEN)", async () => {
  const res = await call("GET", SNAPSHOT, ["viewInventory"]);
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("DIR-D1: a school-scope token is denied (403) the snapshot", async () => {
  // Same viewDirectorPortal permission, scope:"school" → requireOrgScope 403.
  const res = await call("GET", SNAPSHOT, ["viewDirectorPortal"], undefined, {
    scope: "school", school_id: "school-1",
  });
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

// ─── QA-B-059 — org-scope deny leg (locally verifiable) ─────────────────────────
Deno.test("QA-B-059: a school-scope token is denied (403) the org portfolio", async () => {
  // Same viewDirectorPortal permission, but scope:"school" → requireOrgScope 403.
  const res = await call("GET", "/director/portfolio", ["viewDirectorPortal"], undefined, {
    scope: "school", school_id: "school-1",
  });
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-059: a school-scope token is denied (403) the org dashboard too", async () => {
  const res = await call("GET", "/director/dashboard", ["viewDirectorPortal"], undefined, {
    scope: "school", school_id: "school-1",
  });
  assertEquals(res.status, 403);
});

Deno.test("QA-B-059: an organization-scope holder passes the org-scope gate (503 DB-free)", async () => {
  // Control: identical permission, scope:"organization" → gate passes, reaches DB.
  const res = await call("GET", "/director/portfolio", ["viewDirectorPortal"], undefined, {
    scope: "organization",
  });
  assertEquals(res.status, 503);
});
