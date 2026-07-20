// W4 (Owner #2 + #3) — repository + resolver coverage against a fake
// transport_fee_config / transport_fee_rate / transport_student_transport store.
// Proves the config→pure-engine resolution across all four models, school-choice
// switching, ₹0 own-transport/parent-pickup, per-student override precedence, and
// the legacy (null) fall-through.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  getFeeConfig,
  resolveTransportFee,
  upsertFeeConfig,
  upsertFeeRate,
  upsertStudentTransport,
} from "./transport_fee_config_repository.ts";

const ORG = "c1000000-0000-4000-8000-000000000001";
const SCHOOL = "c2000000-0000-4000-8000-000000000001";

/** In-memory store honouring the exact SQL the fee repository issues. */
class FakeFeeDb {
  config = new Map<string, Record<string, unknown>>();
  rates = new Map<string, Record<string, unknown>>();
  students = new Map<string, Record<string, unknown>>();

  private ck() {
    return `${ORG}|${SCHOOL}`;
  }

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    const s = sql.trim();
    // ── transport_fee_config ──
    if (s.startsWith("INSERT INTO transport_fee_config")) {
      const row = {
        fee_model: args[2],
        rate_per_km: args[3],
        distance_source: args[4],
        flat_amount: args[5],
        default_route_amount: args[6],
        default_stop_amount: args[7],
      };
      this.config.set(this.ck(), row);
      return Promise.resolve([row] as T[]);
    }
    if (s.includes("FROM transport_fee_config")) {
      const row = this.config.get(`${args[0]}|${args[1]}`);
      return Promise.resolve((row ? [row] : []) as T[]);
    }
    // ── transport_fee_rate ──
    if (s.startsWith("INSERT INTO transport_fee_rate")) {
      const row = { scope: args[2], entity_id: args[3], amount: args[4], distance_km: args[5] };
      this.rates.set(`${args[0]}|${args[1]}|${args[2]}|${args[3]}`, row);
      return Promise.resolve([row] as T[]);
    }
    if (s.includes("FROM transport_fee_rate")) {
      const row = this.rates.get(`${args[0]}|${args[1]}|${args[2]}|${args[3]}`);
      return Promise.resolve((row ? [row] : []) as T[]);
    }
    // ── transport_student_transport ──
    if (s.startsWith("INSERT INTO transport_student_transport")) {
      const row = { sis_student_id: args[2], requirement: args[3], fee_override: args[4] };
      this.students.set(`${args[0]}|${args[1]}|${args[2]}`, row);
      return Promise.resolve([row] as T[]);
    }
    if (s.includes("FROM transport_student_transport")) {
      const row = this.students.get(`${args[0]}|${args[1]}|${args[2]}`);
      return Promise.resolve((row ? [row] : []) as T[]);
    }
    return Promise.resolve([] as T[]);
  }
}

function db(mock: FakeFeeDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

// ── config read/write round-trip ──────────────────────────────────────────────

Deno.test("getFeeConfig returns null when the school has not chosen a model", async () => {
  const mock = new FakeFeeDb();
  assertEquals(await getFeeConfig(db(mock), ORG, SCHOOL), null);
});

Deno.test("upsertFeeConfig → getFeeConfig round-trips the chosen model + inputs", async () => {
  const mock = new FakeFeeDb();
  await upsertFeeConfig(db(mock), ORG, SCHOOL, {
    feeModel: "distance",
    ratePerKm: 12.5,
    distanceSource: "stop",
    flatAmount: null,
    defaultRouteAmount: null,
    defaultStopAmount: null,
  });
  const cfg = await getFeeConfig(db(mock), ORG, SCHOOL);
  assertEquals(cfg?.feeModel, "distance");
  assertEquals(cfg?.ratePerKm, 12.5);
  assertEquals(cfg?.distanceSource, "stop");
});

// ── resolve: each model (requirement 'bus', no override) ──────────────────────

async function seedFlat(mock: FakeFeeDb, amount: number) {
  await upsertFeeConfig(db(mock), ORG, SCHOOL, {
    feeModel: "flat",
    ratePerKm: null,
    distanceSource: "route",
    flatAmount: amount,
    defaultRouteAmount: null,
    defaultStopAmount: null,
  });
}

Deno.test("resolve flat model → the school-wide amount, billable", async () => {
  const mock = new FakeFeeDb();
  await seedFlat(mock, 5000);
  const r = await resolveTransportFee(db(mock), ORG, SCHOOL, { sisStudentId: "S1", routeId: "r1" });
  assertEquals(r?.amount, 5000);
  assertEquals(r?.model, "flat");
  assertEquals(r?.requirement, "bus");
  assertEquals(r?.overrideApplied, false);
  assertEquals(r?.billable, true);
});

Deno.test("resolve route model → per-route rate row, else the config default", async () => {
  const mock = new FakeFeeDb();
  await upsertFeeConfig(db(mock), ORG, SCHOOL, {
    feeModel: "route",
    ratePerKm: null,
    distanceSource: "route",
    flatAmount: null,
    defaultRouteAmount: 2500,
    defaultStopAmount: null,
  });
  // No rate row for r1 → falls back to the config default.
  const fallback = await resolveTransportFee(db(mock), ORG, SCHOOL, { sisStudentId: "S1", routeId: "r1" });
  assertEquals(fallback?.amount, 2500);
  // A per-route rate row wins over the default.
  await upsertFeeRate(db(mock), ORG, SCHOOL, { scope: "route", entityId: "r1", amount: 3200, distanceKm: null });
  const specific = await resolveTransportFee(db(mock), ORG, SCHOOL, { sisStudentId: "S1", routeId: "r1" });
  assertEquals(specific?.amount, 3200);
});

Deno.test("resolve stop model → per-stop rate row, keyed on the pickup stop", async () => {
  const mock = new FakeFeeDb();
  await upsertFeeConfig(db(mock), ORG, SCHOOL, {
    feeModel: "stop",
    ratePerKm: null,
    distanceSource: "route",
    flatAmount: null,
    defaultRouteAmount: null,
    defaultStopAmount: 1800,
  });
  await upsertFeeRate(db(mock), ORG, SCHOOL, { scope: "stop", entityId: "Lake View", amount: 2100, distanceKm: null });
  const r = await resolveTransportFee(db(mock), ORG, SCHOOL, {
    sisStudentId: "S1",
    routeId: "r1",
    pickupStop: "Lake View",
  });
  assertEquals(r?.amount, 2100);
});

Deno.test("resolve distance model (source=route) → rate × route distance; route entity fallback", async () => {
  const mock = new FakeFeeDb();
  await upsertFeeConfig(db(mock), ORG, SCHOOL, {
    feeModel: "distance",
    ratePerKm: 100,
    distanceSource: "route",
    flatAmount: null,
    defaultRouteAmount: null,
    defaultStopAmount: null,
  });
  // No rate row → uses the route entity's distance passed in (parsed upstream).
  const fromEntity = await resolveTransportFee(db(mock), ORG, SCHOOL, {
    sisStudentId: "S1",
    routeId: "r1",
    routeDistanceKm: 8,
  });
  assertEquals(fromEntity?.amount, 800);
  // A configured rate-row distance wins over the entity fallback.
  await upsertFeeRate(db(mock), ORG, SCHOOL, { scope: "route", entityId: "r1", amount: null, distanceKm: 11 });
  const fromRate = await resolveTransportFee(db(mock), ORG, SCHOOL, {
    sisStudentId: "S1",
    routeId: "r1",
    routeDistanceKm: 8,
  });
  assertEquals(fromRate?.amount, 1100);
});

Deno.test("resolve distance model (source=stop) → rate × stop distance", async () => {
  const mock = new FakeFeeDb();
  await upsertFeeConfig(db(mock), ORG, SCHOOL, {
    feeModel: "distance",
    ratePerKm: 50,
    distanceSource: "stop",
    flatAmount: null,
    defaultRouteAmount: null,
    defaultStopAmount: null,
  });
  await upsertFeeRate(db(mock), ORG, SCHOOL, { scope: "stop", entityId: "Market", amount: null, distanceKm: 6 });
  const r = await resolveTransportFee(db(mock), ORG, SCHOOL, {
    sisStudentId: "S1",
    routeId: "r1",
    pickupStop: "Market",
  });
  assertEquals(r?.amount, 300);
});

Deno.test("SCHOOL CHOICE: switching the config model re-prices the SAME student/route", async () => {
  const mock = new FakeFeeDb();
  await upsertFeeRate(db(mock), ORG, SCHOOL, { scope: "route", entityId: "r1", amount: 3000, distanceKm: 10 });
  // flat 5000 …
  await upsertFeeConfig(db(mock), ORG, SCHOOL, {
    feeModel: "flat",
    ratePerKm: 90,
    distanceSource: "route",
    flatAmount: 5000,
    defaultRouteAmount: null,
    defaultStopAmount: null,
  });
  const flat = await resolveTransportFee(db(mock), ORG, SCHOOL, { sisStudentId: "S1", routeId: "r1" });
  assertEquals(flat?.amount, 5000);
  // … switch to route → 3000 …
  await upsertFeeConfig(db(mock), ORG, SCHOOL, {
    feeModel: "route",
    ratePerKm: 90,
    distanceSource: "route",
    flatAmount: 5000,
    defaultRouteAmount: null,
    defaultStopAmount: null,
  });
  const route = await resolveTransportFee(db(mock), ORG, SCHOOL, { sisStudentId: "S1", routeId: "r1" });
  assertEquals(route?.amount, 3000);
  // … switch to distance → 90 × 10 = 900.
  await upsertFeeConfig(db(mock), ORG, SCHOOL, {
    feeModel: "distance",
    ratePerKm: 90,
    distanceSource: "route",
    flatAmount: 5000,
    defaultRouteAmount: null,
    defaultStopAmount: null,
  });
  const distance = await resolveTransportFee(db(mock), ORG, SCHOOL, { sisStudentId: "S1", routeId: "r1" });
  assertEquals(distance?.amount, 900);
});

// ── owner #3: requirement gating + override precedence ────────────────────────

Deno.test("own_transport → ₹0, NOT billable (even with a flat config)", async () => {
  const mock = new FakeFeeDb();
  await seedFlat(mock, 5000);
  await upsertStudentTransport(db(mock), ORG, SCHOOL, { sisStudentId: "S1", requirement: "own_transport", feeOverride: null });
  const r = await resolveTransportFee(db(mock), ORG, SCHOOL, { sisStudentId: "S1", routeId: "r1" });
  assertEquals(r?.amount, 0);
  assertEquals(r?.requirement, "own_transport");
  assertEquals(r?.billable, false);
});

Deno.test("parent_pickup → ₹0, NOT billable", async () => {
  const mock = new FakeFeeDb();
  await seedFlat(mock, 5000);
  await upsertStudentTransport(db(mock), ORG, SCHOOL, { sisStudentId: "S1", requirement: "parent_pickup", feeOverride: null });
  const r = await resolveTransportFee(db(mock), ORG, SCHOOL, { sisStudentId: "S1", routeId: "r1" });
  assertEquals(r?.amount, 0);
  assertEquals(r?.billable, false);
});

Deno.test("per-student override WINS over the computed model fee", async () => {
  const mock = new FakeFeeDb();
  await seedFlat(mock, 5000);
  await upsertStudentTransport(db(mock), ORG, SCHOOL, { sisStudentId: "S1", requirement: "bus", feeOverride: 3000 });
  const r = await resolveTransportFee(db(mock), ORG, SCHOOL, { sisStudentId: "S1", routeId: "r1" });
  assertEquals(r?.amount, 3000);
  assertEquals(r?.overrideApplied, true);
  assertEquals(r?.billable, true);
});

Deno.test("per-student override WINS over the ₹0 own-transport default (school bills a private-transport user)", async () => {
  const mock = new FakeFeeDb();
  await seedFlat(mock, 5000);
  await upsertStudentTransport(db(mock), ORG, SCHOOL, { sisStudentId: "S1", requirement: "own_transport", feeOverride: 800 });
  const r = await resolveTransportFee(db(mock), ORG, SCHOOL, { sisStudentId: "S1", routeId: "r1" });
  assertEquals(r?.amount, 800);
  assertEquals(r?.overrideApplied, true);
  assertEquals(r?.billable, true);
});

Deno.test("a ₹0 explicit override is honoured and gates billing off", async () => {
  const mock = new FakeFeeDb();
  await seedFlat(mock, 5000);
  await upsertStudentTransport(db(mock), ORG, SCHOOL, { sisStudentId: "S1", requirement: "bus", feeOverride: 0 });
  const r = await resolveTransportFee(db(mock), ORG, SCHOOL, { sisStudentId: "S1", routeId: "r1" });
  assertEquals(r?.amount, 0);
  assertEquals(r?.overrideApplied, true);
  assertEquals(r?.billable, false);
});

// ── legacy fall-through (backward compatibility) ──────────────────────────────

Deno.test("no config + no student row → resolveTransportFee returns null (legacy demand-raise unchanged)", async () => {
  const mock = new FakeFeeDb();
  const r = await resolveTransportFee(db(mock), ORG, SCHOOL, { sisStudentId: "S1", routeId: "r1" });
  assertEquals(r, null);
});

Deno.test("no config + plain 'bus' student row with no override → still null (nothing hybrid to say)", async () => {
  const mock = new FakeFeeDb();
  await upsertStudentTransport(db(mock), ORG, SCHOOL, { sisStudentId: "S1", requirement: "bus", feeOverride: null });
  const r = await resolveTransportFee(db(mock), ORG, SCHOOL, { sisStudentId: "S1", routeId: "r1" });
  assertEquals(r, null);
});

Deno.test("own_transport student with NO config still resolves (₹0 gate needs no model)", async () => {
  const mock = new FakeFeeDb();
  await upsertStudentTransport(db(mock), ORG, SCHOOL, { sisStudentId: "S1", requirement: "own_transport", feeOverride: null });
  const r = await resolveTransportFee(db(mock), ORG, SCHOOL, { sisStudentId: "S1", routeId: "r1" });
  assertEquals(r?.amount, 0);
  assertEquals(r?.billable, false);
  assertEquals(r?.model, null);
});
