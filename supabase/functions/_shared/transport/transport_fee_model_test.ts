// W4 (Owner #2 + #3) — PURE hybrid fee engine coverage. Zero I/O: every branch of
// computeTransportFee + parseDistanceKm exercised directly.

import { assertEquals, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  computeTransportFee,
  isTransportFeeModel,
  isTransportRequirement,
  parseDistanceKm,
  roundRupees,
  type TransportFeeInputs,
  type TransportFeeModel,
} from "./transport_fee_model.ts";

const FULL: TransportFeeInputs = {
  ratePerKm: 10,
  distanceKm: 12,
  routeAmount: 4000,
  stopAmount: 3000,
  flatAmount: 5000,
};

// ── each model bills off its own input (requirement 'bus', no override) ──────

Deno.test("flat model bills the single school-wide amount", () => {
  assertEquals(computeTransportFee("flat", FULL, null, "bus"), 5000);
});

Deno.test("route model bills the per-route amount", () => {
  assertEquals(computeTransportFee("route", FULL, null, "bus"), 4000);
});

Deno.test("stop model bills the per-stop amount", () => {
  assertEquals(computeTransportFee("stop", FULL, null, "bus"), 3000);
});

Deno.test("distance model bills rate-per-km × distance", () => {
  assertEquals(computeTransportFee("distance", FULL, null, "bus"), 120);
  // Fractional rate × distance is rounded to paise (no float drift).
  assertEquals(
    computeTransportFee("distance", { ratePerKm: 7.3, distanceKm: 12.5 }, null, "bus"),
    91.25,
  );
});

Deno.test("SCHOOL CHOICE: same inputs, different chosen model → different fee", () => {
  const models: TransportFeeModel[] = ["flat", "route", "stop", "distance"];
  const results = models.map((m) => computeTransportFee(m, FULL, null, "bus"));
  assertEquals(results, [5000, 4000, 3000, 120]);
});

// ── owner #3: own_transport / parent_pickup default to ₹0 ─────────────────────

Deno.test("own_transport rides for ₹0 regardless of model/inputs (no override)", () => {
  for (const m of ["flat", "route", "stop", "distance"] as TransportFeeModel[]) {
    assertEquals(computeTransportFee(m, FULL, null, "own_transport"), 0);
  }
});

Deno.test("parent_pickup rides for ₹0 regardless of model/inputs (no override)", () => {
  for (const m of ["flat", "route", "stop", "distance"] as TransportFeeModel[]) {
    assertEquals(computeTransportFee(m, FULL, null, "parent_pickup"), 0);
  }
});

// ── owner #3: explicit per-student override WINS over everything ──────────────

Deno.test("override wins over the computed model fee (bus)", () => {
  assertEquals(computeTransportFee("flat", FULL, 3000, "bus"), 3000);
  assertEquals(computeTransportFee("distance", FULL, 999, "bus"), 999);
});

Deno.test("override wins over the ₹0 own-transport/parent-pickup default", () => {
  assertEquals(computeTransportFee("flat", FULL, 800, "own_transport"), 800);
  assertEquals(computeTransportFee("route", FULL, 1200, "parent_pickup"), 1200);
});

Deno.test("an explicit ₹0 override is honoured (0 is a real override, not 'absent')", () => {
  assertEquals(computeTransportFee("flat", FULL, 0, "bus"), 0);
});

// ── defensive: missing / bad inputs never NaN or throw ───────────────────────

Deno.test("a missing input for the active model yields ₹0 (never NaN)", () => {
  assertEquals(computeTransportFee("flat", {}, null, "bus"), 0);
  assertEquals(computeTransportFee("distance", { ratePerKm: 10 }, null, "bus"), 0);
  assertEquals(computeTransportFee("route", {}, null, "bus"), 0);
});

Deno.test("negative inputs and overrides are clamped to ₹0", () => {
  assertEquals(computeTransportFee("flat", { flatAmount: -500 }, null, "bus"), 0);
  assertEquals(computeTransportFee("distance", { ratePerKm: -1, distanceKm: 10 }, null, "bus"), 0);
  assertEquals(computeTransportFee("flat", FULL, -100, "bus"), 0);
});

Deno.test("an unknown model throws (exhaustiveness guard, not a silent ₹0)", () => {
  assertThrows(
    () => computeTransportFee("weekly" as unknown as TransportFeeModel, FULL, null, "bus"),
    Error,
    "Unknown transport fee model",
  );
});

// ── helpers ───────────────────────────────────────────────────────────────────

Deno.test("roundRupees rounds to paise", () => {
  assertEquals(roundRupees(91.255), 91.26);
  assertEquals(roundRupees(120), 120);
});

Deno.test("parseDistanceKm reads bare numbers and display strings", () => {
  assertEquals(parseDistanceKm("12 km"), 12);
  assertEquals(parseDistanceKm("12.5 KM"), 12.5);
  assertEquals(parseDistanceKm(8), 8);
  assertEquals(parseDistanceKm("0 km"), 0);
  assertEquals(parseDistanceKm(null), null);
  assertEquals(parseDistanceKm(undefined), null);
  assertEquals(parseDistanceKm("no digits"), null);
  assertEquals(parseDistanceKm("-3 km"), null); // negative → not a valid distance
});

Deno.test("model / requirement type guards", () => {
  assertEquals(isTransportFeeModel("flat"), true);
  assertEquals(isTransportFeeModel("weekly"), false);
  assertEquals(isTransportRequirement("own_transport"), true);
  assertEquals(isTransportRequirement("carpool"), false);
});
