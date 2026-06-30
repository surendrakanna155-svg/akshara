// QW4 · QA-B-037 — Dynamic Widget Platform ROUTE contract + RBAC (DB-free).
//
// Proven without a live Postgres (QW1 pattern): the widget-platform routes match
// routeWidgetPlatform (an unregistered /widgets path 404s), reads gate on
// viewDynamicWidgets, and the two role-layout writes — PUT /widgets/layouts/:role
// (UPDATE-first/INSERT-fallback) and POST /widgets/layouts/:role/reset (rewrite to
// pack default, no DELETE) — are denied for a non-holder (403) yet, with
// manageDynamicWidgets, reach the unconfigured tenant DB (503). The actual
// upsert/override-clear persistence (erp_tenant has no DELETE grant) is the
// live-cert remainder.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeWidgetPlatform } from "./widget_platform_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "schoolAdmin", role_slugs: ["schoolAdmin"], primary_role: "schoolAdmin",
    permissions: perms, permissions_version: 1, scope: "school",
    school_group_id: null, student_id: null, child_ids: [], session_id: "s1", ...over,
  };
}

async function raw(
  method: string, pathWithQuery: string, perms: string[], body?: unknown,
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const init: RequestInit = {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
  };
  if (body !== undefined) init.body = JSON.stringify(body);
  // The dispatcher (routePath) strips the query before matching — mirror that.
  const path = pathWithQuery.split("?")[0];
  return await routeWidgetPlatform(new Request(`https://x${pathWithQuery}`, init), config, method, path);
}

async function call(
  method: string, pathWithQuery: string, perms: string[], body?: unknown,
): Promise<Response> {
  const res = await raw(method, pathWithQuery, perms, body);
  if (res === null) throw new Error(`routeWidgetPlatform returned null for ${method} ${pathWithQuery}`);
  return res;
}

const VIEW = ["viewDynamicWidgets"];
const MANAGE = ["manageDynamicWidgets"];
const ROLE = "/widgets/layouts/teacher";

Deno.test("QA-B-037: the 7 widget-platform routes match the router", async () => {
  // Reads (viewDynamicWidgets). data-sources is a pure in-memory list → 200.
  assertEquals((await call("GET", "/widgets/data-sources", VIEW)).status, 200);
  // registry / dashboard layout / role layout / versions / data → reach DB → 503.
  assertEquals((await call("GET", "/widgets/registry", VIEW)).status, 503);
  assertEquals((await call("GET", "/widgets/dashboard/layout", VIEW)).status, 503);
  assertEquals((await call("GET", "/widgets/layouts/versions", VIEW)).status, 503);
  assertEquals((await call("GET", ROLE, VIEW)).status, 503);
  assertEquals((await call("GET", "/widgets/data?widgetId=w1", VIEW)).status, 503);
  // Writes (manageDynamicWidgets) with valid bodies → 503.
  assertEquals((await call("PUT", ROLE, MANAGE, { layout: { widgets: [] } })).status, 503);
});

Deno.test("QA-B-037: an unregistered widgets path returns 404 NOT_FOUND", async () => {
  const res = await call("GET", "/widgets/nope/extra/more", VIEW);
  assertEquals(res.status, 404);
  const env = await res.json();
  assertEquals(env.error.code, "NOT_FOUND");
});

Deno.test("QA-B-037: a non-/widgets path returns null (no match)", async () => {
  assertEquals(await raw("GET", "/analytics/dashboard", VIEW), null);
});

// ─── layout save (PUT /widgets/layouts/:role) ───────────────────────────────────
Deno.test("QA-B-037: layout save is denied for a non-holder (403 FORBIDDEN)", async () => {
  const res = await call("PUT", ROLE, VIEW, { layout: { widgets: [] } });
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-037: layout save passes the gate for a holder and reaches the DB (503)", async () => {
  // Proves the UPDATE-first/INSERT-fallback handler is reached past the gate.
  const res = await call("PUT", ROLE, MANAGE, { layout: { widgets: [] } });
  assertEquals(res.status, 503);
});

Deno.test("QA-B-037: layout save rejects a body without a widgets array (422) before the DB", async () => {
  const res = await call("PUT", ROLE, MANAGE, { layout: {} });
  assertEquals(res.status, 422);
});

// ─── layout reset (POST /widgets/layouts/:role/reset) ───────────────────────────
Deno.test("QA-B-037: layout reset is denied for a non-holder (403 FORBIDDEN)", async () => {
  const res = await call("POST", `${ROLE}/reset`, VIEW, {});
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-037: layout reset passes the gate for a holder and reaches the DB (503)", async () => {
  // Proves the override-clear (rewrite to pack default, no DELETE) handler is reached.
  const res = await call("POST", `${ROLE}/reset`, MANAGE, {});
  assertEquals(res.status, 503);
});

Deno.test("QA-B-037: an unauthenticated caller is rejected (401) on a widgets route", async () => {
  const res = await routeWidgetPlatform(
    new Request("https://x/widgets/registry", { method: "GET" }),
    config, "GET", "/widgets/registry",
  );
  assertEquals(res?.status, 401);
});
