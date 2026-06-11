import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { computeFinanceCopilotFromSeed } from "./finance_intelligence_service.ts";

Deno.test("computeFinanceCopilotFromSeed returns forecast and alerts", () => {
  const snapshot = computeFinanceCopilotFromSeed();
  assertEquals(snapshot.feeCollectionForecast > 0, true);
  assertEquals(snapshot.collectionTrend.length >= 1, true);
  assertEquals(snapshot.riskAlerts.length >= 1, true);
});
