import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { formatInr, withLiveFuelKpi } from "./transport_handlers.ts";

// ─── formatInr ───────────────────────────────────────────────────────────────

Deno.test("Batch 8: formatInr uses the dashboard's compact ₹K/₹L style", () => {
  assertEquals(formatInr(0), "₹0");
  assertEquals(formatInr(840), "₹840");
  assertEquals(formatInr(84000), "₹84K");
  assertEquals(formatInr(125000), "₹1.3L");
});

// ─── withLiveFuelKpi (the mock-kill) ─────────────────────────────────────────

const dashboardSeed = () => ({
  aiInsight: "x",
  kpis: [
    { id: "active_buses", value: "12", label: "Active Buses" },
    { id: "fuel", value: "₹84K", label: "Fuel Cost (MTD)", detail: "Finance integration placeholder" },
  ],
});

Deno.test("Batch 8: a recorded fuel spend REPLACES the static ₹84K placeholder", () => {
  const out = withLiveFuelKpi(dashboardSeed(), 53200) as { kpis: Array<Record<string, unknown>> };
  const fuel = out.kpis.find((k) => k.id === "fuel")!;
  assertEquals(fuel.value, "₹53K");
  assertEquals(fuel.detail, "Live from transport expense ledger (MTD)");
  // the placeholder string is gone
  assert(fuel.detail !== "Finance integration placeholder");
});

Deno.test("Batch 8: with NO fuel recorded the KPI reads ₹0 / honest label (never fake ₹84K)", () => {
  const out = withLiveFuelKpi(dashboardSeed(), 0) as { kpis: Array<Record<string, unknown>> };
  const fuel = out.kpis.find((k) => k.id === "fuel")!;
  assertEquals(fuel.value, "₹0");
  assertEquals(fuel.detail, "No fuel expense recorded (MTD)");
});

Deno.test("Batch 8: non-fuel KPIs pass through untouched", () => {
  const out = withLiveFuelKpi(dashboardSeed(), 1000) as { kpis: Array<Record<string, unknown>> };
  const buses = out.kpis.find((k) => k.id === "active_buses")!;
  assertEquals(buses.value, "12");
});

Deno.test("Batch 8: an empty-state snapshot ({}) is returned unchanged", () => {
  assertEquals(withLiveFuelKpi({}, 5000), {});
});

Deno.test("Batch 8: a snapshot without a kpis array is returned unchanged", () => {
  const snap = { aiInsight: "x" };
  assertEquals(withLiveFuelKpi(snap, 5000), snap);
});
