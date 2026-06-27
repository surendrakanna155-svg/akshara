import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { computeInventoryCopilotFromSeed } from "./inventory_intelligence_service.ts";

Deno.test("computeInventoryCopilotFromSeed returns forecast and alerts", () => {
  const snapshot = computeInventoryCopilotFromSeed();
  assertEquals(snapshot.stockForecastUnits > 0, true);
  assertEquals(snapshot.stockTrend.length >= 1, true);
  assertEquals(snapshot.riskAlerts.length >= 1, true);
  assertEquals(snapshot.reorderRecommendations.length >= 1, true);
});

// MJ-L7 / INVEN-6: GET intelligence reads must be side-effect-free.
// Nothing in the repo SELECTs from inventory_intelligence_snapshots, so the
// compute-on-read GET handlers must NOT INSERT a snapshot row or emit a
// mutation audit. Only the explicit write handlers (record lifecycle event,
// advance procurement workflow) may write/audit.
const handlerSource = await Deno.readTextFile(
  new URL("./inventory_intelligence_handlers.ts", import.meta.url),
);

const GET_HANDLERS = [
  "handleInventoryCopilot",
  "handleAssetLifecycle",
  "handleProcurementWorkflow",
] as const;

function handlerBlock(name: string): string {
  const start = handlerSource.indexOf(`export async function ${name}`);
  assertEquals(start >= 0, true, `handler ${name} not found`);
  const next = handlerSource.indexOf("export async function ", start + 1);
  return handlerSource.slice(start, next === -1 ? undefined : next);
}

Deno.test("GET intelligence handlers never INSERT a snapshot row", () => {
  for (const name of GET_HANDLERS) {
    const block = handlerBlock(name);
    assertEquals(
      block.includes("INSERT INTO inventory_intelligence_snapshots"),
      false,
      `${name} must not INSERT a snapshot on read`,
    );
  }
});

Deno.test("GET intelligence handlers never emit a mutation audit on read", () => {
  for (const name of GET_HANDLERS) {
    const block = handlerBlock(name);
    assertEquals(
      block.includes("emitMutationAudit"),
      false,
      `${name} must not emit a mutation audit on read`,
    );
  }
});

Deno.test("write intelligence handlers still emit a mutation audit", () => {
  for (const name of ["handleRecordAssetLifecycleEvent", "handleAdvanceProcurementWorkflow"]) {
    const block = handlerBlock(name);
    assertEquals(
      block.includes("emitMutationAudit"),
      true,
      `${name} must still audit its write`,
    );
  }
});
