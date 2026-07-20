// W4 (Owner decisions #2 + #3, FINAL) — the PURE transport HYBRID fee engine.
//
// Zero I/O, zero DB, zero clock — a single deterministic function that turns
// (chosen model, resolved rate inputs, per-student override, requirement) into a
// payable rupee amount. Every branch is exhaustively unit-testable in isolation
// (see transport_fee_model_test.ts). The DB/config plumbing that RESOLVES the
// inputs for a real allocation lives in transport_fee_config_repository.ts; this
// file is deliberately free of it so the money math can never depend on I/O.
//
// Money unit: finance-standard NUMERIC rupees (the SAME unit as
// transport_expenses.amount / finance_invoices.total_amount) — never paise/minor.

/** The four hybrid pricing models a school may choose (owner #2). */
export type TransportFeeModel = "distance" | "route" | "stop" | "flat";

/** A student's transport requirement (owner #3). */
export type TransportRequirement = "bus" | "own_transport" | "parent_pickup";

export const TRANSPORT_FEE_MODELS: readonly TransportFeeModel[] = [
  "distance",
  "route",
  "stop",
  "flat",
];

export const TRANSPORT_REQUIREMENTS: readonly TransportRequirement[] = [
  "bus",
  "own_transport",
  "parent_pickup",
];

/** True iff `v` is one of the four supported fee models. */
export function isTransportFeeModel(v: unknown): v is TransportFeeModel {
  return typeof v === "string" && (TRANSPORT_FEE_MODELS as readonly string[]).includes(v);
}

/** True iff `v` is one of the three supported requirements. */
export function isTransportRequirement(v: unknown): v is TransportRequirement {
  return typeof v === "string" && (TRANSPORT_REQUIREMENTS as readonly string[]).includes(v);
}

/**
 * The rate inputs the four models need, all resolved to plain numbers (rupees /
 * km) BEFORE calling {@link computeTransportFee}. Each is optional/nullable so the
 * caller only fills the ones its chosen model consumes; a missing input for the
 * active model is treated as 0 (→ a ₹0 payable, never a throw or NaN).
 */
export interface TransportFeeInputs {
  /** distance model — rupees per km. */
  ratePerKm?: number | null;
  /** distance model — the student's billable distance in km (from stop or route). */
  distanceKm?: number | null;
  /** route model — the flat per-route amount. */
  routeAmount?: number | null;
  /** stop model — the flat per-stop amount. */
  stopAmount?: number | null;
  /** flat model — the single school-wide amount. */
  flatAmount?: number | null;
}

/** Coerce to a finite, non-negative number (NaN/Infinity/negative/absent → 0). */
function nonNegNum(v: number | null | undefined): number {
  if (v === null || v === undefined) return 0;
  const n = Number(v);
  if (!Number.isFinite(n) || n < 0) return 0;
  return n;
}

/** Round to 2 dp (paise) to kill floating-point drift from rate×distance. */
export function roundRupees(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/** True iff an override is PRESENT (a finite number). A present-but-negative
 * override is still "set" — the caller clamps it to ₹0 via nonNegNum, never
 * silently ignores it in favour of the school's model fee (an admin who set an
 * override, even a bad one, meant to override). Only null/undefined = no override. */
function isSetOverride(v: number | null | undefined): v is number {
  return v !== null && v !== undefined && Number.isFinite(Number(v));
}

/**
 * THE pure hybrid fee function. Returns the payable transport amount (rupees) for
 * one student, given the school's CHOSEN model, the resolved rate inputs, the
 * (nullable) per-student override, and the student's requirement.
 *
 * Precedence (owner #2 + #3), in order:
 *   1. An explicit per-student `studentOverride` WINS over EVERYTHING — the
 *      computed model fee AND the ₹0 own-transport/parent-pickup default. This is
 *      the owner #3 mandate: a school can bill or zero any single student by hand.
 *   2. No override, and requirement is own_transport / parent_pickup → ₹0 (a child
 *      who does not ride the bus owes no transport fee).
 *   3. No override, requirement 'bus' → compute off the school's chosen model:
 *        flat     → flatAmount
 *        route    → routeAmount
 *        stop     → stopAmount
 *        distance → ratePerKm × distanceKm
 *
 * All amounts are clamped non-negative and rounded to paise. A missing input for
 * the active model yields ₹0 (never NaN / never a throw).
 */
export function computeTransportFee(
  model: TransportFeeModel,
  inputs: TransportFeeInputs,
  studentOverride: number | null | undefined,
  requirement: TransportRequirement,
): number {
  // 1. Per-student override is absolute (owner #3).
  if (isSetOverride(studentOverride)) {
    return roundRupees(nonNegNum(studentOverride));
  }

  // 2. own_transport / parent_pickup ride for ₹0 by default (owner #3).
  if (requirement === "own_transport" || requirement === "parent_pickup") {
    return 0;
  }

  // 3. requirement === 'bus' → the school's chosen model (owner #2).
  switch (model) {
    case "flat":
      return roundRupees(nonNegNum(inputs.flatAmount));
    case "route":
      return roundRupees(nonNegNum(inputs.routeAmount));
    case "stop":
      return roundRupees(nonNegNum(inputs.stopAmount));
    case "distance":
      return roundRupees(nonNegNum(inputs.ratePerKm) * nonNegNum(inputs.distanceKm));
    default: {
      // Exhaustiveness guard — a new model must extend this switch, not slip
      // through as a silent ₹0.
      const _exhaustive: never = model;
      throw new Error(`Unknown transport fee model: ${String(_exhaustive)}`);
    }
  }
}

/**
 * Parse a route/stop distance that may be stored as a bare number OR a display
 * string like "12 km" / "12.5 KM" (the transport route entity stores
 * `distanceKm` as a display string). Returns null when no numeric distance can be
 * read, so the caller can fall back to a configured rate row.
 */
export function parseDistanceKm(raw: unknown): number | null {
  if (raw === null || raw === undefined) return null;
  if (typeof raw === "number") return Number.isFinite(raw) && raw >= 0 ? raw : null;
  const match = String(raw).match(/-?\d+(\.\d+)?/);
  if (!match) return null;
  const n = Number(match[0]);
  return Number.isFinite(n) && n >= 0 ? n : null;
}
