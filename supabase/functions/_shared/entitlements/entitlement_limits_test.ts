import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { evaluateCreateLimit, withinSlab } from "./entitlement_limits.ts";
import { entitlementEnforcementEnabled } from "./entitlement_enforcement.ts";

// ─── withinSlab math (slab + grace) ──────────────────────────────────────────
Deno.test("withinSlab: unlimited (null) always allows", () => {
  assertEquals(withinSlab(10_000, null, 0), true);
});

Deno.test("withinSlab: Trial 100 + 10% grace = 110 ceiling", () => {
  assertEquals(withinSlab(109, 100, 10), true); // 110th allowed
  assertEquals(withinSlab(110, 100, 10), false); // 111th blocked
});

Deno.test("withinSlab: Standard 500 no grace", () => {
  assertEquals(withinSlab(499, 500, 0), true);
  assertEquals(withinSlab(500, 500, 0), false);
});

Deno.test("withinSlab: exactly at slab still allows one more within grace", () => {
  // 500 current, 500 slab, 10% grace → ceiling 550 → 501st allowed.
  assertEquals(withinSlab(500, 500, 10), true);
  assertEquals(withinSlab(550, 500, 10), false);
});

// ─── evaluateCreateLimit — full gate policy (suspension + slab) ───────────────
// PRC-A cap 57: grace/suspension is now READ by the gate, not just stored.
Deno.test("evaluateCreateLimit: SUSPENDED blocks regardless of slab (cap 57)", () => {
  // Well under a generous limit, yet suspended → blocked with reason 'suspended'.
  assertEquals(evaluateCreateLimit("suspended", 1, 1000, 10), {
    allow: false,
    reason: "suspended",
  });
  // Suspended blocks even an unlimited plan.
  assertEquals(evaluateCreateLimit("suspended", 0, null, 0), {
    allow: false,
    reason: "suspended",
  });
});

Deno.test("evaluateCreateLimit: active within slab allows", () => {
  assertEquals(evaluateCreateLimit("active", 499, 500, 0), { allow: true });
});

Deno.test("evaluateCreateLimit: active at slab blocks with reason 'slab'", () => {
  assertEquals(evaluateCreateLimit("active", 500, 500, 0), {
    allow: false,
    reason: "slab",
  });
});

Deno.test("evaluateCreateLimit: GRACE keeps operating through the grace buffer (cap 57)", () => {
  // Past-due but in grace: the 10% buffer widens the ceiling → still allowed,
  // NOT hard-blocked. Only 'suspended' hard-blocks.
  assertEquals(evaluateCreateLimit("grace", 500, 500, 10), { allow: true });
  // ...until even the grace ceiling is exhausted → slab, not suspended.
  assertEquals(evaluateCreateLimit("grace", 550, 500, 10), {
    allow: false,
    reason: "slab",
  });
});

Deno.test("evaluateCreateLimit: trial + unlimited always allows", () => {
  assertEquals(evaluateCreateLimit("trial", 10_000, null, 0), { allow: true });
});

// ─── Enforcement master switch ───────────────────────────────────────────────
Deno.test("enforcement is OFF by default (deploy-dark safe)", () => {
  // No env set in the test runner → disabled.
  assertEquals(entitlementEnforcementEnabled(), false);
});
