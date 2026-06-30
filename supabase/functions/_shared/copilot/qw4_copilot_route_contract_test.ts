// QW4 · QA-B-029, QA-B-041 — AI Copilot ROUTE contract + RBAC gate (DB-free).
//
// Proven without a live Postgres (QW1 pattern): the 4 primary copilot routes
// match routeCopilot, an unregistered /copilot path 404s, and POST
// /copilot/sessions is denied for a non-holder (403) yet, with the runAiCopilot
// gate + the assistant's required view permission, passes through to the
// unconfigured DB (503). Read routes gate on viewAiCopilot, writes on runAiCopilot.
//
// QA-B-041 — the RBAC GATE is asserted here (403 when the persona lacks
// run/view copilot permission). The OTHER leg — "AI output is server-bounded by
// persona, no cross-child/tenant leak in the generated answer" — is enforced
// live via loadCopilotContext + org/school RLS inside withTenantContext and can
// only be proven against a real Postgres; recorded as the infra remainder.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeCopilot } from "./copilot_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "principal", role_slugs: ["principal"], primary_role: "principal",
    permissions: perms, permissions_version: 1, scope: "school",
    school_group_id: null, student_id: null, child_ids: [], session_id: "s1", ...over,
  };
}

async function raw(
  method: string, path: string, perms: string[], body?: unknown,
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const init: RequestInit = {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
  };
  if (body !== undefined) init.body = JSON.stringify(body);
  return await routeCopilot(new Request(`https://x${path}`, init), config, method, path);
}

async function call(
  method: string, path: string, perms: string[], body?: unknown,
): Promise<Response> {
  const res = await raw(method, path, perms, body);
  if (res === null) throw new Error(`routeCopilot returned null for ${method} ${path}`);
  return res;
}

Deno.test("QA-B-029: the 4 primary copilot routes match the router", async () => {
  // GET reads gate on viewAiCopilot → reach unconfigured DB (or pure response).
  // /copilot/assistants is a pure in-memory list → 200 once the view gate passes.
  assertEquals((await call("GET", "/copilot/assistants", ["viewAiCopilot"])).status, 200);
  // /copilot/suggestions requires a valid ?assistant param → 422 once gated (matched).
  assertEquals((await call("GET", "/copilot/suggestions", ["viewAiCopilot"])).status, 422);
  // /copilot/sessions GET reaches the unconfigured tenant DB → 503.
  assertEquals((await call("GET", "/copilot/sessions", ["viewAiCopilot"])).status, 503);
  // /copilot/sessions POST: runAiCopilot + the assistant's view perm → 503.
  const created = await call("POST", "/copilot/sessions", ["runAiCopilot", "viewAdmissions"], {
    assistantType: "admissions",
  });
  assertEquals(created.status, 503);
});

Deno.test("QA-B-029: an unregistered copilot path returns 404 NOT_FOUND", async () => {
  const res = await call("GET", "/copilot/nope", ["viewAiCopilot"]);
  assertEquals(res.status, 404);
  const env = await res.json();
  assertEquals(env.error.code, "NOT_FOUND");
});

Deno.test("QA-B-029: a non-/copilot path returns null (no match)", async () => {
  assertEquals(await raw("GET", "/analytics/dashboard", ["viewAiCopilot"]), null);
});

Deno.test("QA-B-029: POST /copilot/sessions is denied for a non-holder (403 FORBIDDEN)", async () => {
  const res = await call("POST", "/copilot/sessions", ["viewInventory"], { assistantType: "admissions" });
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-029: POST /copilot/sessions rejects an unknown assistantType (422) before the DB", async () => {
  const res = await call("POST", "/copilot/sessions", ["runAiCopilot", "viewAdmissions"], {
    assistantType: "not-a-real-assistant",
  });
  assertEquals(res.status, 422);
});

// ─── QA-B-041 — copilot RBAC gate (locally verifiable leg) ──────────────────────
Deno.test("QA-B-041: read routes require viewAiCopilot (403 without it)", async () => {
  const res = await call("GET", "/copilot/sessions", ["someOtherPerm"]);
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-041: POST /copilot/sessions requires runAiCopilot (viewAiCopilot alone is not enough)", async () => {
  // A read-only copilot user (viewAiCopilot, no runAiCopilot) cannot create a
  // session — the write gate is runAiCopilot, distinct from the view gate.
  const res = await call("POST", "/copilot/sessions", ["viewAiCopilot", "viewAdmissions"], {
    assistantType: "admissions",
  });
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-041: send-message route requires runAiCopilot (403 without it)", async () => {
  // POST /copilot/sessions/:id/messages — write gate is runAiCopilot.
  const res = await call(
    "POST",
    "/copilot/sessions/11111111-1111-1111-1111-111111111111/messages",
    ["viewAiCopilot"],
    { content: "hello" },
  );
  assertEquals(res.status, 403);
});

Deno.test("QA-B-041: an unauthenticated caller is rejected (401) on a copilot route", async () => {
  const res = await routeCopilot(
    new Request("https://x/copilot/sessions", { method: "GET" }),
    config, "GET", "/copilot/sessions",
  );
  assertEquals(res?.status, 401);
});
