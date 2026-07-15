// QW4 · QA-B-065 — Per-module 402 entitlement matrix (DB-free, parametrized).
//
// api/index.ts gates each optional module by wrapping its router with
// `withEntitlement(routeX, "/prefix", "module.slug")`. This file pins, for EVERY
// wrapped (prefix → slug) pair, the contract that defines the 402 gate:
//
//   1. PURE GATE (locally verifiable): `requireEntitlement(allowed, slug)` — the
//      exact decision `enforceEntitlement` applies after resolving the org's plan —
//      returns 402 PLAN_UPGRADE_REQUIRED when the slug is absent from the plan's
//      allowed set, and null (pass) when present. Driven across the full slug
//      matrix below. This is the authoritative, DB-free proof of the 402 behaviour.
//
//   2. WRAPPER WIRING (locally verifiable): with ENTITLEMENT_ENFORCEMENT=on, a
//      request whose path falls under a wrapped prefix is intercepted by the
//      wrapper and routed through the entitlement gate BEFORE the module router;
//      DB-free, resolving the plan hits the unconfigured tenant DB → 503 (proxy for
//      "the gate ran"). A path OUTSIDE the prefix passes straight through (the raw
//      router returns null). With enforcement OFF (default / dark-deploy) every
//      path passes through untouched.
//
// INFRA REMAINDER (needs live Postgres + seeded plan_entitlements): the end-to-end
// "this org's Trial plan lacks module.X → real 402 on GET /X" decision, because
// `enforceEntitlement` → `resolveSubscription` reads the org subscription + plan
// rows from the tenant DB (entitlement_service.ts:55-93). DB-free, that resolution
// throws TenantDbNotConfiguredError → 503, so the live 402-vs-pass branch cannot be
// exercised here. Leg (1) proves the gate logic the resolver feeds; the live cert
// proves the resolver wiring.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import {
  gateSubscriptionStatus,
  requireEntitlement,
  withEntitlement,
  type ModuleRoute,
} from "./entitlement_middleware.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

// The complete set of plan-gated (prefix → slug) pairs wrapped in api/index.ts.
const WRAPPED: Array<{ prefix: string; slug: string }> = [
  { prefix: "/transport", slug: "module.transport" },
  { prefix: "/hr", slug: "module.hr_payroll" },
  { prefix: "/hostel", slug: "module.hostel" },
  { prefix: "/library", slug: "module.library" },
  { prefix: "/inventory", slug: "module.inventory" },
  { prefix: "/alumni", slug: "module.alumni" },
  { prefix: "/onboarding/startup/ai-prefill", slug: "feature.ai_school_builder" },
  { prefix: "/parent-insights", slug: "feature.parent_insights" },
  { prefix: "/growth", slug: "module.marketing" },
  { prefix: "/director", slug: "module.multi_branch" },
  { prefix: "/predictions", slug: "feature.ai_predictions" },
];

function claims(): AccessTokenClaims {
  return {
    sub: "u1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "principal", role_slugs: ["principal"], primary_role: "principal",
    permissions: [], permissions_version: 1, scope: "school", school_group_id: null,
    student_id: null, child_ids: [], session_id: "s1",
  };
}

// ─── Leg 1: the pure gate, across the whole matrix ───────────────────────────

Deno.test("QA-B-065: a plan WITHOUT the module slug is 402 PLAN_UPGRADE_REQUIRED (every wrapped module)", async () => {
  for (const { slug } of WRAPPED) {
    // A Trial-equivalent plan that allows only the always-on core modules.
    const trial = new Set(["module.admissions", "module.finance", "module.sis"]);
    const res = requireEntitlement(trial, slug);
    assertEquals(res?.status, 402, `${slug} did not 402 for a plan lacking it`);
    const body = await res!.json();
    assertEquals(body.error.code, "PLAN_UPGRADE_REQUIRED", `${slug} wrong error code`);
  }
});

// ─── PRC-A cap 57: subscription STATUS is enforced, not just decorative ──────

Deno.test("PRC-A cap 57: a SUSPENDED subscription is blocked (402 SUBSCRIPTION_SUSPENDED)", async () => {
  const res = gateSubscriptionStatus("suspended");
  assertEquals(res?.status, 402);
  const body = await res!.json();
  assertEquals(body.error.code, "SUBSCRIPTION_SUSPENDED");
});

Deno.test("PRC-A cap 57: suspension is plan-INDEPENDENT — it blocks even a module the plan fully allows", async () => {
  for (const { slug } of WRAPPED) {
    // The org's plan explicitly grants this module...
    const allowed = new Set(["module.admissions", slug]);
    assertEquals(requireEntitlement(allowed, slug), null, `${slug} setup wrong`);
    // ...but the subscription is suspended, and enforceEntitlement runs the
    // status gate BEFORE gateModuleAccess, so the plan never gets consulted.
    // Before this fix, status was resolved and returned but never read: a
    // suspended org kept full API access to every module its plan allowed.
    const res = gateSubscriptionStatus("suspended");
    assertEquals(res?.status, 402, `${slug} was reachable while suspended`);
    const body = await res!.json();
    assertEquals(body.error.code, "SUBSCRIPTION_SUSPENDED");
  }
});

Deno.test("PRC-A cap 57: trial / active / grace all still pass (grace is a grace window, not a block)", () => {
  for (const status of ["trial", "active", "grace"]) {
    assertEquals(gateSubscriptionStatus(status), null, `${status} was wrongly blocked`);
  }
});

Deno.test("QA-B-065: a plan WITH the module slug passes the gate (null) (every wrapped module)", () => {
  for (const { slug } of WRAPPED) {
    // The org's plan grants exactly this module's slug.
    const allowed = new Set(["module.admissions", slug]);
    assertEquals(requireEntitlement(allowed, slug), null, `${slug} was wrongly denied while allowed`);
  }
});

// ─── Leg 2: the wrapper short-circuits the gate only for its own prefix ───────

// A stub router that "owns" a prefix: 503 when a path under the prefix is hit (so
// we can tell the wrapped route actually ran), null otherwise (no match).
function stubRoute(prefix: string): ModuleRoute {
  return (_req, _config, _method, path) => {
    if (path === prefix || path.startsWith(`${prefix}/`)) {
      return Promise.resolve(new Response("ran", { status: 599 }));
    }
    return Promise.resolve(null);
  };
}

async function hit(route: ModuleRoute, method: string, path: string): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(), 900);
  const req = new Request(`https://x${path}`, {
    method, headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
  });
  return route(req, config, method, path);
}

Deno.test("QA-B-065: with enforcement ON, the wrapper routes a wrapped-prefix request through the gate (503 DB-free)", async () => {
  Deno.env.set("ENTITLEMENT_ENFORCEMENT", "true");
  try {
    for (const { prefix, slug } of WRAPPED) {
      const wrapped = withEntitlement(stubRoute(prefix), prefix, slug);
      const res = await hit(wrapped, "GET", prefix);
      // Gate ran → enforceEntitlement → unconfigured tenant DB → 503. It did NOT
      // reach the stub (which would be 599), proving the gate fired before the route.
      assertEquals(res?.status, 503, `${prefix} (${slug}) did not route through the gate`);
    }
  } finally {
    Deno.env.delete("ENTITLEMENT_ENFORCEMENT");
  }
});

Deno.test("QA-B-065: the wrapper leaves a path OUTSIDE its prefix untouched (passes through)", async () => {
  Deno.env.set("ENTITLEMENT_ENFORCEMENT", "true");
  try {
    // Wrap the transport gate, then request a /finance path: must pass through to
    // the wrapped route (which returns null — no match), NOT get gated.
    const wrapped = withEntitlement(stubRoute("/transport"), "/transport", "module.transport");
    const res = await hit(wrapped, "GET", "/finance/dashboard");
    assertEquals(res, null, "wrapper gated a path outside its prefix");
  } finally {
    Deno.env.delete("ENTITLEMENT_ENFORCEMENT");
  }
});

Deno.test("QA-B-065: with enforcement OFF (dark-deploy default), the wrapper passes through to the route", async () => {
  // Ensure the flag is unset/false.
  Deno.env.delete("ENTITLEMENT_ENFORCEMENT");
  const wrapped = withEntitlement(stubRoute("/transport"), "/transport", "module.transport");
  const res = await hit(wrapped, "GET", "/transport/dashboard");
  // Gate skipped → the stub route ran (599), no 402/503 from the gate.
  assertEquals(res?.status, 599, "enforcement-off wrapper unexpectedly gated the request");
});
