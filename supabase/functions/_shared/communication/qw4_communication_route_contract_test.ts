// QW4 · QA-B-017 / QA-B-018 — Communication router ROUTE/RBAC contract.
//
// DB-free route-contract proof for the communication module (route map in
// communication_router.ts → matchCommunicationRoute). For every registered
// route we assert routeCommunication resolves it to a handler that passes its
// gate (→ 503 TENANT_DB_NOT_CONFIGURED, the DB-free "authorized" proxy, or 422
// when a write trips body validation after the gate but before the DB), and
// that an UNREGISTERED in-prefix path → 404 NOT_FOUND while an OUT-of-prefix
// path falls through (null) so the dispatcher can try the next router.
//
// The gate for each route was read directly from communication_handlers.ts:
//   • templates list           GET  /communications/templates        → viewCommunications
//   • template create          POST /communications/templates        → sendBroadcast
//   • template update          PUT  /communications/templates/{id}    → sendBroadcast
//   • broadcast history        GET  /communications/broadcasts/history→ sendBroadcast
//   • broadcast send           POST /communications/broadcasts        → sendBroadcast   (QA-B-018)
//   • process queue            POST /communications/notifications/process-queue → manageCommunications
//   • delivery metrics         GET  /communications/delivery/metrics  → viewAdminHub
//   • delivery webhook         POST /communications/delivery/webhook  → HMAC signature (no JWT)
//   • parent/student/teacher notification + message + device-token routes → SCOPE gate
//     (scope "parent" | "student" | "school"), not a permission slug.
//
// FINDING (slug correction): the QW4 spec text for QA-B-018 said broadcast send
// requires `manageCommunication`. The handler actually gates on `sendBroadcast`
// (communication_handlers.ts:286). The spec instructs "never guess slugs — read
// the handler", so the contract here asserts the REAL slug, `sendBroadcast`.
//
// Live/RLS remainder (covered by the live cert): real 200 payloads, queued
// deliveries actually sent, and per-tenant/per-parent row isolation.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims, AuthScope } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeCommunication } from "./communication_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(
  perms: string[],
  over: Partial<AccessTokenClaims> = {},
): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "principal",
    role_slugs: ["principal"],
    primary_role: "principal",
    permissions: perms,
    permissions_version: 1,
    scope: "school",
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
  scope: AuthScope = "school",
  body?: unknown,
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms, { scope }), 900);
  const req = new Request(`https://x${path}`, {
    method,
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return await routeCommunication(req, config, method, path);
}

// ── 19 registered routes: assert each resolves + passes its own gate ──────────
// `pass` = perms + scope that should clear the gate (→ 503 or, for writes with
// no body, 422). `den` = perms + scope that should be denied (→ 403).
interface RouteCase {
  method: string;
  path: string;
  pass: { perms: string[]; scope: AuthScope; body?: unknown };
  den: { perms: string[]; scope: AuthScope };
}

const routes: RouteCase[] = [
  // ── permission-gated communications.* routes ────────────────────────────────
  {
    method: "GET", path: "/communications/templates",
    pass: { perms: ["viewCommunications"], scope: "school" },
    den: { perms: ["viewAdminHub"], scope: "school" },
  },
  {
    method: "POST", path: "/communications/templates",
    pass: { perms: ["sendBroadcast"], scope: "school", body: { name: "t", channel: "sms", body: "hi" } },
    den: { perms: ["viewCommunications"], scope: "school" },
  },
  {
    method: "PUT", path: "/communications/templates/tmpl-1",
    pass: { perms: ["sendBroadcast"], scope: "school", body: { body: "hi" } },
    den: { perms: ["viewCommunications"], scope: "school" },
  },
  {
    method: "GET", path: "/communications/broadcasts/history",
    pass: { perms: ["sendBroadcast"], scope: "school" },
    den: { perms: ["viewCommunications"], scope: "school" },
  },
  {
    method: "POST", path: "/communications/broadcasts",
    pass: { perms: ["sendBroadcast"], scope: "school", body: { audience: "all", title: "x", body: "y" } },
    den: { perms: ["viewCommunications"], scope: "school" },
  },
  {
    method: "POST", path: "/communications/notifications/process-queue",
    pass: { perms: ["manageCommunications"], scope: "school" },
    den: { perms: ["sendBroadcast"], scope: "school" },
  },
  {
    method: "GET", path: "/communications/delivery/metrics",
    pass: { perms: ["viewAdminHub"], scope: "school" },
    den: { perms: ["viewCommunications"], scope: "school" },
  },
  // ── scope-gated parent.* routes (scope must be "parent") ────────────────────
  {
    method: "GET", path: "/parent/notifications",
    pass: { perms: [], scope: "parent" },
    den: { perms: [], scope: "school" },
  },
  {
    method: "POST", path: "/parent/notifications/mark-read",
    pass: { perms: [], scope: "parent", body: { notification_id: "n1" } },
    den: { perms: [], scope: "organization" },
  },
  {
    method: "POST", path: "/parent/notifications/mark-all-read",
    pass: { perms: [], scope: "parent" },
    den: { perms: [], scope: "organization" },
  },
  {
    method: "POST", path: "/parent/device-tokens/register",
    pass: { perms: [], scope: "parent", body: { token: "tok" } },
    den: { perms: [], scope: "organization" },
  },
  {
    method: "POST", path: "/parent/device-tokens/unregister",
    pass: { perms: [], scope: "parent", body: { token: "tok" } },
    den: { perms: [], scope: "organization" },
  },
  {
    method: "GET", path: "/parent/messages/threads",
    pass: { perms: [], scope: "parent" },
    den: { perms: [], scope: "school" },
  },
  {
    method: "POST", path: "/parent/messages/send",
    pass: { perms: [], scope: "parent", body: { body: "hi" } },
    den: { perms: [], scope: "school" },
  },
  // ── scope-gated student.* routes (scope must be "student") ──────────────────
  {
    method: "GET", path: "/student/notifications",
    pass: { perms: [], scope: "student" },
    den: { perms: [], scope: "school" },
  },
  {
    method: "POST", path: "/student/notifications/mark-read",
    pass: { perms: [], scope: "student", body: { notification_id: "n1" } },
    den: { perms: [], scope: "organization" },
  },
  {
    method: "POST", path: "/student/device-tokens/register",
    pass: { perms: [], scope: "student", body: { token: "tok" } },
    den: { perms: [], scope: "organization" },
  },
  // ── scope-gated teacher.* routes (scope must be "school") ───────────────────
  {
    method: "GET", path: "/teacher/messages/threads",
    pass: { perms: [], scope: "school" },
    den: { perms: [], scope: "parent" },
  },
  {
    method: "POST", path: "/teacher/messages/send",
    pass: { perms: [], scope: "school", body: { body: "hi" } },
    den: { perms: [], scope: "parent" },
  },
];

Deno.test("QA-B-017: every registered communication route resolves and enforces its gate (perm or scope)", async () => {
  assertEquals(routes.length, 19, "expected exactly 19 registered communication routes under test");
  for (const r of routes) {
    const passRes = await call(r.method, r.path, r.pass.perms, r.pass.scope, r.pass.body);
    const gatePassed = passRes?.status === 503 || passRes?.status === 422;
    assertEquals(
      gatePassed,
      true,
      `${r.method} ${r.path} with allowed creds expected gate-passed (503/422) but got ${passRes?.status}`,
    );
    const denRes = await call(r.method, r.path, r.den.perms, r.den.scope);
    assertEquals(
      denRes?.status,
      403,
      `${r.method} ${r.path} with denied creds expected 403 but got ${denRes?.status}`,
    );
  }
});

Deno.test("QA-B-017: an unregistered in-prefix communication path returns 404 NOT_FOUND", async () => {
  const res = await call("GET", "/communications/does-not-exist", ["viewCommunications"], "school");
  assertEquals(res?.status, 404);
  const env = await res!.json();
  assertEquals(env.error.code, "NOT_FOUND");
  assertEquals(env.data, null);
});

Deno.test("QA-B-017: a wrong-method on a registered path returns 404 NOT_FOUND", async () => {
  // /communications/broadcasts is POST-only; a GET is not registered → 404.
  const res = await call("GET", "/communications/broadcasts", ["sendBroadcast"], "school");
  assertEquals(res?.status, 404);
});

Deno.test("QA-B-017: an out-of-prefix path is not owned by the communication router (null)", async () => {
  const token = await signAccessToken(SECRET, claims(["viewCommunications"]), 900);
  const req = new Request("https://x/finance/dashboard", {
    method: "GET",
    headers: { authorization: `Bearer ${token}` },
  });
  const res = await routeCommunication(req, config, "GET", "/finance/dashboard");
  assertEquals(res, null);
});

Deno.test("QA-B-017: an unauthenticated caller on a JWT-gated route is rejected with 401", async () => {
  const req = new Request("https://x/communications/templates", { method: "GET" });
  const res = await routeCommunication(req, config, "GET", "/communications/templates");
  assertEquals(res?.status, 401);
});

// ── QA-B-018: broadcast send RBAC (real slug = sendBroadcast) ─────────────────

Deno.test("QA-B-018: POST /communications/broadcasts is denied without the broadcast slug (403)", async () => {
  // A token that can view communications but NOT send broadcasts is rejected.
  const res = await call("POST", "/communications/broadcasts", ["viewCommunications"], "school", {
    audience: "all", title: "Holiday", body: "School closed tomorrow",
  });
  assertEquals(res?.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-018: POST /communications/broadcasts passes the gate WITH sendBroadcast (reaches DB, 503)", async () => {
  const res = await call("POST", "/communications/broadcasts", ["sendBroadcast"], "school", {
    audience: "all", title: "Holiday", body: "School closed tomorrow",
  });
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-018: POST /communications/broadcasts rejects a missing body (422) before the DB", async () => {
  const token = await signAccessToken(SECRET, claims(["sendBroadcast"]), 900);
  const req = new Request("https://x/communications/broadcasts", {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    // no body
  });
  const res = await routeCommunication(req, config, "POST", "/communications/broadcasts");
  assertEquals(res?.status, 422);
});
