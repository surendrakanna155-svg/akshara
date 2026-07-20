import { assert, assertEquals } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  computeAiTrust,
  computeEconomics,
  getAiEconomics,
} from "./ai_economics_service.ts";

Deno.test("computeAiTrust re-frames economics as the governance lens (WEB-006)", () => {
  const econ = computeEconomics(
    "2026-07-01T00:00:00.000Z",
    [
      { outcome: "ok", n: 3, cost: 300 },
      { outcome: "refused", n: 1, cost: 50 },
      { outcome: "fallback_no_key", n: 2, cost: 0 },
      { outcome: "fallback_guard", n: 1, cost: 0 },
      { outcome: "fallback_rate_user", n: 1, cost: 0 },
      { outcome: "fallback_spend_cap", n: 1, cost: 0 },
    ],
    [{ surface: "copilot", n: 9 }],
    { entries: 2, hits: 6, tokensSaved: 120 },
    /*spendCapMicros*/ 0,
    /*lifetimeModelCalls*/ 4,
  );
  const trust = computeAiTrust(econ);
  assertEquals(trust.providerCalls, 4); // ok + refused
  assertEquals(trust.governedFallbacks, 5); // no_key + guard + rate_user + spend_cap ... = 2+1+1+1
  assertEquals(trust.governedCalls, 9);
  assertEquals(trust.refusedCount, 1);
  assertEquals(trust.guardrailTrips, 1);
  assertEquals(trust.rateLimitedCount, 1);
  assertEquals(trust.spendCapFallbacks, 1);
  assertEquals(trust.noKeyFallbacks, 2);
  assertEquals(trust.cacheHits, 6);
  assert(Math.abs(trust.fallbackRatio - 5 / 9) < 1e-9);
});

Deno.test("computeAiTrust reports honest zeros for an idle tenant", () => {
  const econ = computeEconomics(
    "2026-07-01T00:00:00.000Z",
    [],
    [],
    { entries: 0, hits: 0, tokensSaved: 0 },
    0,
    0,
  );
  const trust = computeAiTrust(econ);
  assertEquals(trust.governedCalls, 0);
  assertEquals(trust.fallbackRatio, 0);
  assertEquals(trust.cacheHitRatio, 0);
  assertEquals(trust.refusedCount, 0);
});

Deno.test("computeEconomics aggregates spend, model calls, fallbacks and hit ratio", () => {
  const econ = computeEconomics(
    "2026-07-01T00:00:00.000Z",
    [
      { outcome: "ok", n: 3, cost: 300 },
      { outcome: "refused", n: 1, cost: 50 },
      { outcome: "fallback_no_key", n: 2, cost: 0 },
      { outcome: "fallback_timeout", n: 1, cost: 0 },
    ],
    [{ surface: "copilot", n: 5 }, { surface: "director_summary", n: 2 }],
    { entries: 4, hits: 10, tokensSaved: 800 },
    1_000_000,
    30, // lifetime model calls (for the window-consistent ratio)
  );
  assertEquals(econ.spendMicros, 350);
  assertEquals(econ.modelCalls, 4); // ok(3) + refused(1), month-to-date
  assertEquals(econ.fallbacks, 3); // no_key(2) + timeout(1)
  assertEquals(econ.callsBySurface, { copilot: 5, director_summary: 2 });
  assertEquals(econ.cacheHits, 10);
  assertEquals(econ.tokensSaved, 800);
  assertEquals(econ.spendCapMicros, 1_000_000);
  assertEquals(econ.cacheHitRatio, 10 / 40); // lifetime hits / (hits + lifetime model calls)
});

Deno.test("computeEconomics flags the 80% warn and 100% cap (F8)", () => {
  const base = { entries: 0, hits: 0, tokensSaved: 0 };
  const at80 = computeEconomics("m", [{ outcome: "ok", n: 1, cost: 800 }], [], base, 1000, 1);
  assertEquals(at80.atSpendWarn, true);
  assertEquals(at80.atSpendCap, false);
  assertEquals(at80.spendWarnRatio, 0.8);
  const atCap = computeEconomics("m", [{ outcome: "ok", n: 1, cost: 1000 }], [], base, 1000, 1);
  assertEquals(atCap.atSpendWarn, true);
  assertEquals(atCap.atSpendCap, true);
  // No cap configured → never warns.
  const noCap = computeEconomics("m", [{ outcome: "ok", n: 1, cost: 9e9 }], [], base, 0, 1);
  assertEquals(noCap.atSpendWarn, false);
  assertEquals(noCap.atSpendCap, false);
});

Deno.test("computeEconomics has a 0 hit ratio with no activity", () => {
  const econ = computeEconomics("m", [], [], { entries: 0, hits: 0, tokensSaved: 0 }, 0, 0);
  assertEquals(econ.cacheHitRatio, 0);
  assertEquals(econ.modelCalls, 0);
});

function fakeDb(): TenantQueryClient {
  return {
    queryObject: (sql: string) => {
      if (sql.includes("GROUP BY outcome")) {
        return Promise.resolve([{ outcome: "ok", n: 2, cost: "200" }]);
      }
      if (sql.includes("GROUP BY surface")) {
        return Promise.resolve([{ surface: "copilot", n: 2 }]);
      }
      if (sql.includes("FROM ai_response_cache")) {
        return Promise.resolve([{ entries: 1, hits: "6", saved: "400" }]);
      }
      // lifetime model-call count for the ratio denominator (F6).
      if (sql.includes("outcome IN ('ok', 'refused')")) {
        return Promise.resolve([{ n: 4 }]);
      }
      // resolveAiConfig platform_provider_configs lookup → no panel row → env
      return Promise.resolve([]);
    },
    // deno-lint-ignore no-explicit-any
  } as any as TenantQueryClient;
}

Deno.test("getAiEconomics wires the aggregates, coerces bigints, and computes a window-consistent ratio", async () => {
  for (const k of ["AI_MONTHLY_SPEND_CAP_MICROS"]) Deno.env.delete(k);
  const econ = await getAiEconomics(fakeDb(), { organizationId: "org-1", schoolId: "sch-1" });
  assertEquals(econ.modelCalls, 2); // month-to-date
  assertEquals(econ.spendMicros, 200);
  assertEquals(econ.cacheHits, 6);
  assertEquals(econ.tokensSaved, 400); // Σ(tokens_saved × hit_count)
  assertEquals(econ.cacheHitRatio, 6 / 10); // lifetime hits(6) / (hits + lifetime calls(4))
  assert(econ.monthStart.endsWith("Z"));
});
