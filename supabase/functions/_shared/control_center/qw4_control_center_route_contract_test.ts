// QW4 · QA-B-019 / QA-B-050 / QA-B-058 — Control-center router ROUTE/RBAC/scope.
//
// DB-free route-contract proof for the platform control-center module (route map
// in control_center_router.ts → matchControlCenterRoute). For every registered
// route we assert routeControlCenter resolves it to a handler that passes its
// gate (→ 503 TENANT_DB_NOT_CONFIGURED / 422 write-validation, the DB-free
// "authorized" proxy) and that an UNREGISTERED /control-center/* path → 404
// NOT_FOUND (the router owns the prefix). A non-control-center path falls
// through (null).
//
// Gates were read directly from the handlers (never guessed):
//   • All read snapshots/lists (dashboard, schools, subscriptions, billing,
//     crm-pipeline, support-tickets, customer-success, white-label, analytics,
//     monitoring, roles, settings) → createControlCenterReadHandlers:
//       requirePermission("viewControlCenter") ?? requireOrgScope (scope must be
//       "organization").  [entity_read/control_center_read_handlers.ts:22,42]
//   • Writes (POST schools, POST crm-pipeline) → control_center_write_handlers:
//       requirePermission("manageControlCenter") ?? org-scope check.  [:36,38]
//   • Platform provider surfaces (providers / usage / features / vault) gate on
//     a platform permission ONLY (managePlatformProviders / viewPlatformUsage /
//     managePlatformFeatures / managePlatformVault) — see FINDING below.
//
// QA-B-050 (control-center requires superAdmin): the platform owner is the
// `superAdmin` role, which uniquely holds viewControlCenter/manageControlCenter
// AND operates at `organization` scope (lib/core/security/role_permissions.dart).
// There is no literal `role === "superAdmin"` check in the backend; the
// superAdmin-only guarantee is enforced by viewControlCenter perm + organization
// scope. We prove the DENY for a principal/schoolAdmin who HOLDS viewControlCenter
// but is at `school` scope (i.e. is NOT the platform superAdmin) → 403.
//
// QA-B-058 (per-module scope): a `scope:"school"` token is denied (403) on the
// org/platform control-center read+write surfaces, provable purely from the
// scope claim. The cross-org DATA-isolation leg (school B cannot READ school A's
// rows) needs live Postgres + RLS — that is the infra remainder (Partial).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims, AuthScope } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeControlCenter } from "./control_center_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

// superAdmin-equivalent claim: organization scope + the platform permissions.
function claims(
  perms: string[],
  over: Partial<AccessTokenClaims> = {},
): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: null,
    role: "superAdmin",
    role_slugs: ["superAdmin"],
    primary_role: "superAdmin",
    permissions: perms,
    permissions_version: 1,
    scope: "organization",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  };
}

async function call(
  method: string,
  path: string,
  perms: string[],
  over: Partial<AccessTokenClaims> = {},
  body?: unknown,
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms, over), 900);
  const req = new Request(`https://x${path}`, {
    method,
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return await routeControlCenter(req, config, method, path);
}

// ── 17 distinct registered routes (16 GET + 5 POST, sharing 4 paths) ──────────
// `passPerms` clears the gate for an organization-scope token (→ 503/422).
// `denPerms` lacks the slug → 403 (gate blocked).
interface RouteCase {
  method: string;
  path: string;
  passPerms: string[];
  denPerms: string[];
  body?: unknown;
}

const orgGate = (over: Partial<RouteCase>): RouteCase => ({
  method: "GET",
  path: over.path!,
  passPerms: ["viewControlCenter"],
  denPerms: ["viewAdminHub"],
  ...over,
});

const routes: RouteCase[] = [
  // org-scope + viewControlCenter read surfaces
  orgGate({ path: "/control-center/dashboard" }),
  orgGate({ path: "/control-center/schools" }),
  orgGate({ path: "/control-center/subscriptions" }),
  orgGate({ path: "/control-center/billing" }),
  orgGate({ path: "/control-center/crm-pipeline" }),
  orgGate({ path: "/control-center/support-tickets" }),
  orgGate({ path: "/control-center/customer-success" }),
  orgGate({ path: "/control-center/white-label" }),
  orgGate({ path: "/control-center/analytics" }),
  orgGate({ path: "/control-center/monitoring" }),
  orgGate({ path: "/control-center/roles" }),
  orgGate({ path: "/control-center/settings" }),
  // platform provider read surfaces (permission-only gate)
  { method: "GET", path: "/control-center/providers", passPerms: ["managePlatformProviders"], denPerms: ["viewControlCenter"] },
  { method: "GET", path: "/control-center/usage", passPerms: ["viewPlatformUsage"], denPerms: ["viewControlCenter"] },
  { method: "GET", path: "/control-center/features", passPerms: ["managePlatformFeatures"], denPerms: ["viewControlCenter"] },
  { method: "GET", path: "/control-center/vault/health", passPerms: ["managePlatformVault"], denPerms: ["viewControlCenter"] },
  // writes — POST/PUT
  { method: "POST", path: "/control-center/providers", passPerms: ["managePlatformProviders"], denPerms: ["viewControlCenter"], body: { providerCategory: "sms", providerName: "twilio" } },
  { method: "POST", path: "/control-center/features", passPerms: ["managePlatformFeatures"], denPerms: ["viewControlCenter"], body: { featureKey: "x", enabled: true } },
  { method: "POST", path: "/control-center/vault/rotate", passPerms: ["managePlatformVault"], denPerms: ["viewControlCenter"], body: { secretId: "s1" } },
  { method: "POST", path: "/control-center/schools", passPerms: ["manageControlCenter"], denPerms: ["viewControlCenter"], body: { name: "New School" } },
  { method: "POST", path: "/control-center/crm-pipeline", passPerms: ["manageControlCenter"], denPerms: ["viewControlCenter"], body: { name: "Lead" } },
];

Deno.test("QA-B-019: every registered control-center route resolves and enforces its permission gate", async () => {
  for (const r of routes) {
    const passRes = await call(r.method, r.path, r.passPerms, {}, r.body);
    const gatePassed = passRes?.status === 503 || passRes?.status === 422;
    assertEquals(
      gatePassed,
      true,
      `${r.method} ${r.path} with [${r.passPerms}] expected gate-passed (503/422) but got ${passRes?.status}`,
    );
    const denRes = await call(r.method, r.path, r.denPerms, {}, r.body);
    assertEquals(
      denRes?.status,
      403,
      `${r.method} ${r.path} with [${r.denPerms}] expected 403 but got ${denRes?.status}`,
    );
  }
});

Deno.test("QA-B-019: an unregistered control-center path returns 404 NOT_FOUND", async () => {
  const res = await call("GET", "/control-center/not-a-real-surface", ["viewControlCenter", "manageControlCenter"]);
  assertEquals(res?.status, 404);
  const env = await res!.json();
  assertEquals(env.error.code, "NOT_FOUND");
  assertEquals(env.data, null);
});

Deno.test("QA-B-019: a non-control-center path is not owned by the router (null)", async () => {
  const token = await signAccessToken(SECRET, claims(["viewControlCenter"]), 900);
  const req = new Request("https://x/finance/dashboard", {
    method: "GET",
    headers: { authorization: `Bearer ${token}` },
  });
  const res = await routeControlCenter(req, config, "GET", "/finance/dashboard");
  assertEquals(res, null);
});

Deno.test("QA-B-019: a DELETE on a registered control-center path is not registered (404)", async () => {
  const res = await call("DELETE", "/control-center/schools", ["manageControlCenter"]);
  assertEquals(res?.status, 404);
});

Deno.test("QA-B-019: an unauthenticated caller is rejected with 401", async () => {
  const req = new Request("https://x/control-center/dashboard", { method: "GET" });
  const res = await routeControlCenter(req, config, "GET", "/control-center/dashboard");
  assertEquals(res?.status, 401);
});

// ── QA-B-050: control-center requires the platform owner (superAdmin) ─────────
// The org-scoped surfaces are reachable ONLY by a viewControlCenter holder at
// organization scope (the superAdmin). A principal/schoolAdmin who HOLDS
// viewControlCenter but is at `school` scope (NOT the platform superAdmin) is
// denied — proving the deny works for a permission holder who is not the owner.

Deno.test("QA-B-050: a superAdmin (org scope + viewControlCenter) reaches control-center surfaces (503)", async () => {
  const res = await call("GET", "/control-center/dashboard", ["viewControlCenter"]);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-050: a school-scope principal holding viewControlCenter is DENIED (403) — not the superAdmin", async () => {
  // Same permission, but school scope + school_id → requireOrgScope rejects it.
  const res = await call("GET", "/control-center/dashboard", ["viewControlCenter"], {
    role: "principal", role_slugs: ["principal"], primary_role: "principal",
    scope: "school", school_id: "school-1",
  });
  assertEquals(res?.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-050: a caller without viewControlCenter is DENIED (403) even at organization scope", async () => {
  const res = await call("GET", "/control-center/dashboard", ["viewAdminHub"]);
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-050: the control-center WRITE surface also requires the platform-owner perm (manageControlCenter)", async () => {
  // A school-scope schoolAdmin with manageControlCenter is still denied by scope.
  const denied = await call("POST", "/control-center/schools", ["manageControlCenter"], {
    role: "schoolAdmin", role_slugs: ["schoolAdmin"], primary_role: "schoolAdmin",
    scope: "school", school_id: "school-1",
  }, { name: "X" });
  assertEquals(denied?.status, 403);
});

// ── QA-B-058: per-module scope — school-scope denied on org/platform surfaces ──
// Locally verifiable from the `scope` claim. The cross-org DATA-isolation leg
// (school B cannot READ school A's rows) is the infra remainder — see header.

Deno.test("QA-B-058: a school-scope token is denied (403) on EVERY org-scoped control-center read surface", async () => {
  const orgScopedReads = [
    "/control-center/dashboard",
    "/control-center/schools",
    "/control-center/subscriptions",
    "/control-center/billing",
    "/control-center/crm-pipeline",
    "/control-center/support-tickets",
    "/control-center/customer-success",
    "/control-center/white-label",
    "/control-center/analytics",
    "/control-center/monitoring",
    "/control-center/roles",
    "/control-center/settings",
  ];
  for (const path of orgScopedReads) {
    // Hand the school-scope token the org read permission so the ONLY thing that
    // can block it is the scope guard → proves scope (not perm) is the gate.
    const res = await call("GET", path, ["viewControlCenter"], {
      scope: "school", school_id: "school-1",
    });
    assertEquals(res?.status, 403, `${path} should deny a school-scope caller (scope guard)`);
  }
});

Deno.test("QA-B-058: a school-scope token is denied (403) on the org-scoped control-center WRITE surfaces", async () => {
  const writes: Array<[string, unknown]> = [
    ["/control-center/schools", { name: "X" }],
    ["/control-center/crm-pipeline", { name: "Lead" }],
  ];
  for (const [path, body] of writes) {
    const res = await call("POST", path, ["manageControlCenter"], {
      scope: "school", school_id: "school-1",
    }, body);
    assertEquals(res?.status, 403, `${path} write should deny a school-scope caller`);
  }
});
