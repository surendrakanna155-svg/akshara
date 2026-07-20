// W4 (Owner decisions #2 + #3) — DB layer for the HYBRID transport fee model.
//
// Reads/writes the three config tables from migration 20260900000027 —
//   transport_fee_config          (per-school chosen model + rate inputs),
//   transport_fee_rate            (per-route/per-stop amount + distance),
//   transport_student_transport   (per-student requirement + fee override),
// and RESOLVES them, through the pure engine in transport_fee_model.ts, into the
// payable amount for a single allocation. All money is finance-standard NUMERIC
// rupees (NUMERIC arrives as a string over the wire → parsed here).

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  computeTransportFee,
  isTransportFeeModel,
  isTransportRequirement,
  parseDistanceKm,
  type TransportFeeInputs,
  type TransportFeeModel,
  type TransportRequirement,
} from "./transport_fee_model.ts";

// ── Row shapes ────────────────────────────────────────────────────────────────

export interface TransportFeeConfig {
  feeModel: TransportFeeModel;
  ratePerKm: number | null;
  distanceSource: "route" | "stop";
  flatAmount: number | null;
  defaultRouteAmount: number | null;
  defaultStopAmount: number | null;
}

export interface TransportFeeRate {
  scope: "route" | "stop";
  entityId: string;
  amount: number | null;
  distanceKm: number | null;
}

export interface StudentTransport {
  sisStudentId: string;
  requirement: TransportRequirement;
  feeOverride: number | null;
}

/** NUMERIC (string|number|null) → number|null, never NaN. */
function num(v: unknown): number | null {
  if (v === null || v === undefined || v === "") return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

// ── Reads ─────────────────────────────────────────────────────────────────────

export async function getFeeConfig(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<TransportFeeConfig | null> {
  const rows = await db.queryObject<{
    fee_model: string;
    rate_per_km: string | null;
    distance_source: string;
    flat_amount: string | null;
    default_route_amount: string | null;
    default_stop_amount: string | null;
  }>(
    `SELECT fee_model, rate_per_km, distance_source, flat_amount,
            default_route_amount, default_stop_amount
       FROM transport_fee_config
      WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );
  const row = rows[0];
  if (!row || !isTransportFeeModel(row.fee_model)) return null;
  return {
    feeModel: row.fee_model,
    ratePerKm: num(row.rate_per_km),
    distanceSource: row.distance_source === "stop" ? "stop" : "route",
    flatAmount: num(row.flat_amount),
    defaultRouteAmount: num(row.default_route_amount),
    defaultStopAmount: num(row.default_stop_amount),
  };
}

export async function getFeeRate(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  scope: "route" | "stop",
  entityId: string,
): Promise<TransportFeeRate | null> {
  if (!entityId) return null;
  const rows = await db.queryObject<{
    scope: string;
    entity_id: string;
    amount: string | null;
    distance_km: string | null;
  }>(
    `SELECT scope, entity_id, amount, distance_km
       FROM transport_fee_rate
      WHERE organization_id = $1 AND school_id = $2 AND scope = $3 AND entity_id = $4`,
    [organizationId, schoolId, scope, entityId],
  );
  const row = rows[0];
  if (!row) return null;
  return {
    scope: row.scope === "stop" ? "stop" : "route",
    entityId: row.entity_id,
    amount: num(row.amount),
    distanceKm: num(row.distance_km),
  };
}

export async function getStudentTransport(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  sisStudentId: string,
): Promise<StudentTransport | null> {
  if (!sisStudentId) return null;
  const rows = await db.queryObject<{
    sis_student_id: string;
    requirement: string;
    fee_override: string | null;
  }>(
    `SELECT sis_student_id, requirement, fee_override
       FROM transport_student_transport
      WHERE organization_id = $1 AND school_id = $2 AND sis_student_id = $3`,
    [organizationId, schoolId, sisStudentId],
  );
  const row = rows[0];
  if (!row) return null;
  return {
    sisStudentId: row.sis_student_id,
    requirement: isTransportRequirement(row.requirement) ? row.requirement : "bus",
    feeOverride: num(row.fee_override),
  };
}

// ── Writes (upsert — config is edited in place, never duplicated) ─────────────

export async function upsertFeeConfig(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: TransportFeeConfig & { updatedBy?: string | null },
): Promise<TransportFeeConfig> {
  const rows = await db.queryObject<{
    fee_model: string;
    rate_per_km: string | null;
    distance_source: string;
    flat_amount: string | null;
    default_route_amount: string | null;
    default_stop_amount: string | null;
  }>(
    `INSERT INTO transport_fee_config (
       organization_id, school_id, fee_model, rate_per_km, distance_source,
       flat_amount, default_route_amount, default_stop_amount, updated_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     ON CONFLICT (organization_id, school_id) DO UPDATE SET
       fee_model = EXCLUDED.fee_model,
       rate_per_km = EXCLUDED.rate_per_km,
       distance_source = EXCLUDED.distance_source,
       flat_amount = EXCLUDED.flat_amount,
       default_route_amount = EXCLUDED.default_route_amount,
       default_stop_amount = EXCLUDED.default_stop_amount,
       updated_by = EXCLUDED.updated_by
     RETURNING fee_model, rate_per_km, distance_source, flat_amount,
               default_route_amount, default_stop_amount`,
    [
      organizationId,
      schoolId,
      input.feeModel,
      input.ratePerKm,
      input.distanceSource,
      input.flatAmount,
      input.defaultRouteAmount,
      input.defaultStopAmount,
      input.updatedBy ?? null,
    ],
  );
  const row = rows[0]!;
  return {
    feeModel: isTransportFeeModel(row.fee_model) ? row.fee_model : input.feeModel,
    ratePerKm: num(row.rate_per_km),
    distanceSource: row.distance_source === "stop" ? "stop" : "route",
    flatAmount: num(row.flat_amount),
    defaultRouteAmount: num(row.default_route_amount),
    defaultStopAmount: num(row.default_stop_amount),
  };
}

export async function upsertFeeRate(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: TransportFeeRate & { updatedBy?: string | null },
): Promise<TransportFeeRate> {
  const rows = await db.queryObject<{
    scope: string;
    entity_id: string;
    amount: string | null;
    distance_km: string | null;
  }>(
    `INSERT INTO transport_fee_rate (
       organization_id, school_id, scope, entity_id, amount, distance_km, updated_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7)
     ON CONFLICT (organization_id, school_id, scope, entity_id) DO UPDATE SET
       amount = EXCLUDED.amount,
       distance_km = EXCLUDED.distance_km,
       updated_by = EXCLUDED.updated_by
     RETURNING scope, entity_id, amount, distance_km`,
    [
      organizationId,
      schoolId,
      input.scope,
      input.entityId,
      input.amount,
      input.distanceKm,
      input.updatedBy ?? null,
    ],
  );
  const row = rows[0]!;
  return {
    scope: row.scope === "stop" ? "stop" : "route",
    entityId: row.entity_id,
    amount: num(row.amount),
    distanceKm: num(row.distance_km),
  };
}

export async function upsertStudentTransport(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: StudentTransport & { updatedBy?: string | null },
): Promise<StudentTransport> {
  const rows = await db.queryObject<{
    sis_student_id: string;
    requirement: string;
    fee_override: string | null;
  }>(
    `INSERT INTO transport_student_transport (
       organization_id, school_id, sis_student_id, requirement, fee_override, updated_by
     ) VALUES ($1, $2, $3, $4, $5, $6)
     ON CONFLICT (organization_id, school_id, sis_student_id) DO UPDATE SET
       requirement = EXCLUDED.requirement,
       fee_override = EXCLUDED.fee_override,
       updated_by = EXCLUDED.updated_by
     RETURNING sis_student_id, requirement, fee_override`,
    [
      organizationId,
      schoolId,
      input.sisStudentId,
      input.requirement,
      input.feeOverride,
      input.updatedBy ?? null,
    ],
  );
  const row = rows[0]!;
  return {
    sisStudentId: row.sis_student_id,
    requirement: isTransportRequirement(row.requirement) ? row.requirement : "bus",
    feeOverride: num(row.fee_override),
  };
}

// ── Resolve: config + student + rate → the payable amount for one allocation ──

export interface ResolvedTransportFee {
  /** The payable transport amount in rupees (already override/requirement/model-resolved). */
  amount: number;
  /** The school's chosen model (null when no fee-config exists — override/requirement only). */
  model: TransportFeeModel | null;
  /** The student's requirement (defaults 'bus' when no per-student row exists). */
  requirement: TransportRequirement;
  /** True when an explicit per-student override drove the amount. */
  overrideApplied: boolean;
  /** True when a Finance demand SHOULD be raised (amount > 0). ₹0 → false = ride free. */
  billable: boolean;
}

export interface ResolveFeeParams {
  sisStudentId: string;
  routeId?: string | null;
  pickupStop?: string | null;
  /** Fallback route distance (parsed from the route entity's `distanceKm`). */
  routeDistanceKm?: number | null;
}

/**
 * Resolve the payable transport fee for one allocation.
 *
 * Returns `null` when the school has NO fee-config AND the student has NO
 * requirement/override row that changes the outcome — i.e. nothing hybrid applies,
 * so the caller keeps its legacy demand-raise behaviour UNCHANGED (fully
 * backward-compatible). Otherwise returns the resolved amount + why.
 *
 * When it returns non-null:
 *   • an explicit per-student override → that amount (owner #3, wins over all);
 *   • own_transport / parent_pickup with no override → ₹0, billable=false;
 *   • requirement 'bus' with a fee-config → the chosen model's computed amount.
 */
export async function resolveTransportFee(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  params: ResolveFeeParams,
): Promise<ResolvedTransportFee | null> {
  const [config, student] = await Promise.all([
    getFeeConfig(db, organizationId, schoolId),
    getStudentTransport(db, organizationId, schoolId, params.sisStudentId),
  ]);

  const requirement: TransportRequirement = student?.requirement ?? "bus";
  const override = student?.feeOverride ?? null;

  // Nothing hybrid to say: no override, plain 'bus' student, and the school never
  // chose a model → let the caller bill exactly as it did before.
  if (override === null && requirement === "bus" && config === null) {
    return null;
  }

  // Resolve the model inputs only when we actually need them (a plain 'bus'
  // student with a config). An override or a non-bus requirement short-circuits
  // the model entirely, so we never touch the rate table for those.
  let inputs: TransportFeeInputs = {};
  if (override === null && requirement === "bus" && config !== null) {
    inputs = await resolveModelInputs(db, organizationId, schoolId, config, params);
  }

  const amount = computeTransportFee(
    config?.feeModel ?? "flat",
    inputs,
    override,
    requirement,
  );

  return {
    amount,
    model: config?.feeModel ?? null,
    requirement,
    overrideApplied: override !== null,
    billable: amount > 0,
  };
}

/** Build the pure engine's inputs from the config + per-route/per-stop rate rows. */
async function resolveModelInputs(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  config: TransportFeeConfig,
  params: ResolveFeeParams,
): Promise<TransportFeeInputs> {
  const routeId = params.routeId ?? "";
  const pickupStop = params.pickupStop ?? "";

  const [routeRate, stopRate] = await Promise.all([
    routeId ? getFeeRate(db, organizationId, schoolId, "route", routeId) : Promise.resolve(null),
    pickupStop ? getFeeRate(db, organizationId, schoolId, "stop", pickupStop) : Promise.resolve(null),
  ]);

  // Distance comes from the stop or the route per the config's distance_source;
  // a fee_rate.distance_km wins, else the route entity's own distanceKm.
  const distanceKm = config.distanceSource === "stop"
    ? (stopRate?.distanceKm ?? null)
    : (routeRate?.distanceKm ?? params.routeDistanceKm ?? null);

  return {
    ratePerKm: config.ratePerKm,
    distanceKm,
    routeAmount: routeRate?.amount ?? config.defaultRouteAmount,
    stopAmount: stopRate?.amount ?? config.defaultStopAmount,
    flatAmount: config.flatAmount,
  };
}
