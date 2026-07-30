import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { formatInr, withLiveFuelKpi, withLiveFuelTrend } from "./transport_handlers.ts";
import { computeOccupancy } from "./transport_read_repository.ts";

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

// ─── slice 2: computeOccupancy ───────────────────────────────────────────────

Deno.test("Batch 8 s2: occupancy derives utilization + unassigned from real counts", () => {
  const m = computeOccupancy(100, 80, 85);
  assertEquals(m.totalCapacity, 100);
  assertEquals(m.allocatedSeats, 80);
  assertEquals(m.utilizationPercent, 80);
  assertEquals(m.unassignedStudents, 5);
  assertEquals(m.source, "live");
});

Deno.test("Batch 8 s2: zero fleet capacity never divides by zero (0%)", () => {
  const m = computeOccupancy(0, 0, 0);
  assertEquals(m.utilizationPercent, 0);
  assertEquals(m.unassignedStudents, 0);
});

Deno.test("Batch 8 s2: unassigned is never negative (more seats than route students)", () => {
  const m = computeOccupancy(100, 90, 40);
  assertEquals(m.unassignedStudents, 0);
});

// ─── slice 2: withLiveFuelTrend (the fuelTrend mock-kill) ────────────────────

Deno.test("Batch 8 s2: live fuel trend replaces the static fuelTrend, keeps other sections", () => {
  const snap = {
    catalog: [{ id: "rpt" }],
    fuelTrend: [{ label: "Jan", amountLakhs: 7.2, targetLakhs: 7.0 }],
  };
  const trend = [{ label: "Jul 2026", amountLakhs: 0.05, targetLakhs: null as null }];
  const out = withLiveFuelTrend(snap, trend) as Record<string, unknown>;
  assertEquals(out.fuelTrend, trend);
  assertEquals(out.catalog, snap.catalog);
});

Deno.test("Batch 8 s2: an empty-state reports snapshot passes through", () => {
  assertEquals(withLiveFuelTrend({}, []), { fuelTrend: [] });
});
