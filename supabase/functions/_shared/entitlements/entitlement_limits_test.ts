import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { evaluateCreateLimit, evaluateSmsQuota, withinSlab } from "./entitlement_limits.ts";
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

// ─── W4 · evaluateSmsQuota — monthly SMS cap decision (owner decision #1) ─────
// SMS is a HARD monthly count (no grace buffer, unlike the slabs): allowed while
// strictly below the cap, blocked at/over it. The limit is config-driven (from
// the plan) — these assertions never encode a specific plan number.
Deno.test("evaluateSmsQuota: unlimited plan (null cap) always allows", () => {
  assertEquals(evaluateSmsQuota("active", 10_000, null), { allow: true });
});

Deno.test("evaluateSmsQuota: below the cap allows, AT the cap blocks with reason 'quota'", () => {
  // last send under the cap is allowed...
  assertEquals(evaluateSmsQuota("active", 999, 1000), { allow: true });
  // ...the send that would reach the cap is the boundary: current==limit blocks.
  assertEquals(evaluateSmsQuota("active", 1000, 1000), { allow: false, reason: "quota" });
  // over the cap stays blocked.
  assertEquals(evaluateSmsQuota("active", 1500, 1000), { allow: false, reason: "quota" });
});

Deno.test("evaluateSmsQuota: cap of 0 blocks every send", () => {
  assertEquals(evaluateSmsQuota("active", 0, 0), { allow: false, reason: "quota" });
});

Deno.test("evaluateSmsQuota: SUSPENDED blocks regardless of count (even unlimited plan)", () => {
  assertEquals(evaluateSmsQuota("suspended", 0, 1000), { allow: false, reason: "suspended" });
  assertEquals(evaluateSmsQuota("suspended", 0, null), { allow: false, reason: "suspended" });
});

Deno.test("evaluateSmsQuota: trial / grace within cap still send", () => {
  assertEquals(evaluateSmsQuota("trial", 5, 1000), { allow: true });
  assertEquals(evaluateSmsQuota("grace", 5, 1000), { allow: true });
});

// The cap is READ from the plan, not encoded in the gate: the SAME count flips
// allow↔block purely by changing the cap argument.
Deno.test("evaluateSmsQuota: the SAME usage is allowed or blocked purely by the (config-driven) cap", () => {
  assertEquals(evaluateSmsQuota("active", 500, 1000), { allow: true }); // room under a 1000 cap
  assertEquals(evaluateSmsQuota("active", 500, 500), { allow: false, reason: "quota" }); // at a 500 cap
  assertEquals(evaluateSmsQuota("active", 500, null), { allow: true }); // unlimited
});

// ─── Enforcement master switch ───────────────────────────────────────────────
Deno.test("enforcement is OFF by default (deploy-dark safe)", () => {
  // No env set in the test runner → disabled.
  assertEquals(entitlementEnforcementEnabled(), false);
});
