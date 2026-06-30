// QW4 · QA-B-035 — Onboarding ROUTE contract + ai-prefill entitlement (DB-free).
//
// Proven without a live Postgres (QW1 pattern): the registered /onboarding routes
// match routeOnboarding, an unregistered /onboarding path 404s, RBAC fires
// (viewOnboarding/manageOnboarding), and — critically — the AI School Builder
// entitlement (feature.ai_school_builder) gates the /onboarding/startup/ai-prefill
// route ONLY. Per index.ts:116 that single route is wrapped with
// withEntitlement(routeOnboarding, "/onboarding/startup/ai-prefill",
// "feature.ai_school_builder"); the rest of /onboarding is the open, certified
// onboarding foundation.
//
// The 402 is applied by the WRAPPER, not the raw router; and DB-free,
// enforceEntitlement resolves the plan through withTenantContext which throws
// TenantDbNotConfigured (503). So the 402 contract is proven against the pure,
// side-effect-free requireEntitlement gate (as the QW4 spec prescribes), and the
// router-level facts (ai-prefill needs manageOnboarding; the rest never 402) are
// proven against routeOnboarding directly. The live plan→402 wiring is covered by
// the entitlement service tests + the live cert.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeOnboarding } from "./onboarding_router.ts";
import { requireEntitlement } from "../entitlements/entitlement_middleware.ts";

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
  method: string, path: string, perms: string[], body?: unknown,
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const init: RequestInit = {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
  };
  if (body !== undefined) init.body = JSON.stringify(body);
  return await routeOnboarding(new Request(`https://x${path}`, init), config, method, path);
}

async function call(
  method: string, path: string, perms: string[], body?: unknown,
): Promise<Response> {
  const res = await raw(method, path, perms, body);
  if (res === null) throw new Error(`routeOnboarding returned null for ${method} ${path}`);
  return res;
}

// 11 representative registered onboarding routes (method + path).
const VIEW = ["viewOnboarding"];
const MANAGE = ["manageOnboarding"];

Deno.test("QA-B-035: the registered onboarding routes match the router", async () => {
  // Read routes (viewOnboarding) → reach unconfigured DB → 503.
  assertEquals((await call("GET", "/onboarding/dashboard", VIEW)).status, 503);
  assertEquals((await call("GET", "/onboarding/startup", VIEW)).status, 503);
  assertEquals((await call("GET", "/onboarding/imports", VIEW)).status, 503);
  assertEquals((await call("GET", "/onboarding/invites", VIEW)).status, 503);
  assertEquals((await call("GET", "/onboarding/imports/job-1", VIEW)).status, 503);
  // Write routes (manageOnboarding). Some validate body first → 422 (matched).
  assertEquals((await call("PUT", "/onboarding/startup", MANAGE, { foo: 1 })).status, 503);
  assertEquals((await call("POST", "/onboarding/startup/go-live", MANAGE)).status, 503);
  assertEquals((await call("POST", "/onboarding/students/generate", MANAGE, {
    academicYear: "2026", classes: [{ name: "I", sections: ["A"], count: 1 }],
  })).status, 503);
  assertEquals((await call("POST", "/onboarding/invites", MANAGE, {
    inviteType: "teacher", recipientPhone: "+910000000000", recipientLabel: "T",
  })).status, 503);
  assertEquals((await call("POST", "/onboarding/imports/job-1/commit", MANAGE)).status, 503);
  // The AI-prefill route itself matches and is manageOnboarding-gated → 503 for a holder.
  assertEquals((await call("POST", "/onboarding/startup/ai-prefill", MANAGE, { schoolName: "X" })).status, 503);
});

Deno.test("QA-B-035: an unregistered onboarding path returns 404 NOT_FOUND", async () => {
  const res = await call("GET", "/onboarding/nope", VIEW);
  assertEquals(res.status, 404);
  const env = await res.json();
  assertEquals(env.error.code, "NOT_FOUND");
});

Deno.test("QA-B-035: a non-/onboarding path returns null (no match)", async () => {
  assertEquals(await raw("GET", "/analytics/dashboard", VIEW), null);
});

Deno.test("QA-B-035: onboarding RBAC — a write route is denied without manageOnboarding (403)", async () => {
  const res = await call("POST", "/onboarding/startup/go-live", VIEW);
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-035: ai-prefill requires manageOnboarding (403 for a view-only caller)", async () => {
  const res = await call("POST", "/onboarding/startup/ai-prefill", VIEW, { schoolName: "X" });
  assertEquals(res.status, 403);
});

// ─── entitlement: feature.ai_school_builder gates ai-prefill ONLY ───────────────
Deno.test("QA-B-035: feature.ai_school_builder is REQUIRED — pure gate 402 when the plan omits it", async () => {
  // Plan that does NOT include the AI School Builder feature.
  const allowed = new Set<string>(["module.core", "feature.parent_insights"]);
  const denied = requireEntitlement(allowed, "feature.ai_school_builder");
  assertEquals(denied?.status, 402);
  const env = await denied!.json();
  assertEquals(env.error.code, "PLAN_UPGRADE_REQUIRED");
});

Deno.test("QA-B-035: feature.ai_school_builder present — pure gate allows (null)", async () => {
  const allowed = new Set<string>(["feature.ai_school_builder"]);
  assertEquals(requireEntitlement(allowed, "feature.ai_school_builder"), null);
});

Deno.test("QA-B-035: the raw onboarding router never emits a 402 (entitlement lives in the wrapper)", async () => {
  // The rest of /onboarding is open: no onboarding route 402s on its own. ai-prefill
  // included — the raw router only enforces RBAC; the 402 is the wrapper's job.
  for (
    const [method, path, perms, body] of [
      ["GET", "/onboarding/dashboard", VIEW, undefined],
      ["POST", "/onboarding/startup/ai-prefill", MANAGE, { schoolName: "X" }],
      ["POST", "/onboarding/students/generate", MANAGE, {
        academicYear: "2026", classes: [{ name: "I", sections: ["A"], count: 1 }],
      }],
    ] as Array<[string, string, string[], unknown]>
  ) {
    const res = await call(method, path, perms, body);
    if (res.status === 402) {
      throw new Error(`raw onboarding router unexpectedly 402'd ${method} ${path}`);
    }
  }
});
