import { assert, assertEquals } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import { computeEconomics, getAiEconomics } from "./ai_economics_service.ts";

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
  );
  assertEquals(econ.spendMicros, 350);
  assertEquals(econ.modelCalls, 4); // ok(3) + refused(1)
  assertEquals(econ.fallbacks, 3); // no_key(2) + timeout(1)
  assertEquals(econ.callsBySurface, { copilot: 5, director_summary: 2 });
  assertEquals(econ.cacheHits, 10);
  assertEquals(econ.tokensSaved, 800);
  assertEquals(econ.spendCapMicros, 1_000_000);
  assertEquals(econ.cacheHitRatio, 10 / 14); // hits / (hits + model calls)
});

Deno.test("computeEconomics has a 0 hit ratio with no activity", () => {
  const econ = computeEconomics("m", [], [], { entries: 0, hits: 0, tokensSaved: 0 }, 0);
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
      // resolveAiConfig platform_provider_configs lookup → no panel row → env
      return Promise.resolve([]);
    },
    // deno-lint-ignore no-explicit-any
  } as any as TenantQueryClient;
}

Deno.test("getAiEconomics wires the three aggregates and coerces bigints", async () => {
  for (const k of ["AI_MONTHLY_SPEND_CAP_MICROS"]) Deno.env.delete(k);
  const econ = await getAiEconomics(fakeDb(), { organizationId: "org-1", schoolId: "sch-1" });
  assertEquals(econ.modelCalls, 2);
  assertEquals(econ.spendMicros, 200);
  assertEquals(econ.cacheHits, 6);
  assertEquals(econ.tokensSaved, 400);
  assert(econ.monthStart.endsWith("Z"));
});
