import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { computeInventoryCopilotFromSeed } from "./inventory_intelligence_service.ts";

Deno.test("computeInventoryCopilotFromSeed returns forecast and alerts", () => {
  const snapshot = computeInventoryCopilotFromSeed();
  assertEquals(snapshot.stockForecastUnits > 0, true);
  assertEquals(snapshot.stockTrend.length >= 1, true);
  assertEquals(snapshot.riskAlerts.length >= 1, true);
  assertEquals(snapshot.reorderRecommendations.length >= 1, true);
});
