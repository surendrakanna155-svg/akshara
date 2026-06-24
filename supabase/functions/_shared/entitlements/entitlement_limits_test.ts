import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { withinSlab } from "./entitlement_limits.ts";
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

// ─── Enforcement master switch ───────────────────────────────────────────────
Deno.test("enforcement is OFF by default (deploy-dark safe)", () => {
  // No env set in the test runner → disabled.
  assertEquals(entitlementEnforcementEnabled(), false);
});
