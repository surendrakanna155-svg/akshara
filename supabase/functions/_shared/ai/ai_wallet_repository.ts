// PRC-A Batch 3 — AI credit wallet: balance projection + grant path (caps 37–43).
//
// The wallet owns NO counter of its own. Balance is a projection over rows that
// already exist:
//
//   available = SUM(ai_credit_entries.units)                  -- granted
//             - SUM(ai_call_log.credits_debited)               -- committed
//             - SUM(pending ai_call_reservations.credits_reserved)  -- in flight
//
// The in-flight term is what makes this safe under concurrency WITHOUT a lock of
// its own: `ai_call_reservations` already admits atomically under a
// pg_advisory_xact_lock and settles through a status-guarded write, so a pending
// hold is visible to every concurrent admit the instant it commits. Reusing it
// means the wallet cannot double-consume, and abandoned holds are swept by the
// existing 2-minute PENDING_TTL rather than by anything new here.
//
// Units are integer credits, never currency (owner decision #3). Every write
// boundary truncates, mirroring the ai_* domain's existing BIGINT micro-unit
// convention.

import type { TenantQueryClient } from "../tenant_db.ts";
import type { AiTenantScope } from "./ai_call_log_repository.ts";

/** Deliberately integer. A credit is a product unit, not money. */
export interface AiWalletBalance {
  /** Everything ever granted (top-ups + adjustments + expiries, signed). */
  grantedUnits: number;
  /** Committed debits from calls already served. */
  debitedUnits: number;
  /** Units held by in-flight (pending) reservations. */
  reservedUnits: number;
  /** granted - debited - reserved. MAY be negative — see the note below. */
  availableUnits: number;
  /**
   * Units of the most recent `top_up`. The denominator for the low-balance
   * signal — see walletHealth() for why neither lifetime grants nor
   * granted-minus-debited works.
   */
  lastTopUpUnits: number;
}

/**
 * A balance can legitimately go NEGATIVE and that is not a bug to clamp away:
 * an admin may write a corrective `adjustment` (cap 43) that exceeds what is
 * left, or credits may expire while calls are in flight. Clamping to 0 would
 * silently forgive the difference and let the next top-up start from a false
 * zero. The admit gate refuses at `available < required`, which already covers
 * the enforcement need, so the ledger stays arithmetically honest.
 */
export async function readWalletBalance(
  db: TenantQueryClient,
  scope: AiTenantScope,
): Promise<AiWalletBalance> {
  const rows = await db.queryObject<{
    granted: string | number;
    debited: string | number;
    reserved: string | number;
    last_top_up: string | number;
  }>(
    `SELECT
       (SELECT coalesce(sum(units), 0) FROM ai_credit_entries
         WHERE organization_id = $1) AS granted,
       (SELECT coalesce(sum(credits_debited), 0) FROM ai_call_log
         WHERE organization_id = $1) AS debited,
       (SELECT coalesce(sum(credits_reserved), 0) FROM ai_call_reservations
         WHERE organization_id = $1 AND status = 'pending') AS reserved,
       (SELECT coalesce(units, 0) FROM ai_credit_entries
         WHERE organization_id = $1 AND entry_type = 'top_up'
         ORDER BY created_at DESC LIMIT 1) AS last_top_up`,
    [scope.organizationId],
  );
  const row = rows[0];
  const granted = toUnits(row?.granted);
  const debited = toUnits(row?.debited);
  const reserved = toUnits(row?.reserved);
  return {
    grantedUnits: granted,
    debitedUnits: debited,
    reservedUnits: reserved,
    availableUnits: granted - debited - reserved,
    lastTopUpUnits: toUnits(row?.last_top_up),
  };
}

export interface GrantCreditsInput {
  entryType: "top_up" | "adjustment" | "expiry";
  units: number;
  reason: string;
  actorId: string | null;
  externalRef?: string | null;
}

export class InvalidCreditGrantError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "InvalidCreditGrantError";
  }
}

/**
 * Writes one signed ledger row. There is no UPDATE path by design — reversing a
 * mistake means a compensating row, so the trail survives.
 *
 * The sign rules are enforced BOTH here (a clear 422 for the caller) and by
 * `ai_credit_entries_units_sign_check` in the DB (the real guarantee, which also
 * binds anything that bypasses this function).
 */
export async function grantCredits(
  db: TenantQueryClient,
  scope: AiTenantScope,
  input: GrantCreditsInput,
): Promise<{ id: string; units: number }> {
  const units = Math.trunc(input.units);
  if (!Number.isFinite(units) || units === 0) {
    throw new InvalidCreditGrantError("units must be a non-zero integer");
  }
  if (input.entryType === "top_up" && units <= 0) {
    throw new InvalidCreditGrantError("a top_up must add credit (units > 0)");
  }
  if (input.entryType === "expiry" && units >= 0) {
    throw new InvalidCreditGrantError("an expiry must remove credit (units < 0)");
  }
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO ai_credit_entries
       (organization_id, entry_type, units, reason, actor_id, external_ref)
     VALUES ($1, $2, $3::bigint, $4, $5::uuid, $6)
     RETURNING id`,
    [
      scope.organizationId,
      input.entryType,
      units,
      input.reason ?? "",
      input.actorId,
      input.externalRef ?? null,
    ],
  );
  return { id: rows[0]!.id, units };
}

export interface AiCreditEntryRow {
  id: string;
  entry_type: string;
  units: number;
  reason: string;
  actor_id: string | null;
  external_ref: string | null;
  created_at: string;
}

/** The org's credit ledger, newest first — the audit surface for caps 41/43. */
export async function listCreditEntries(
  db: TenantQueryClient,
  scope: AiTenantScope,
  limit = 100,
): Promise<AiCreditEntryRow[]> {
  return await db.queryObject<AiCreditEntryRow>(
    `SELECT id, entry_type, units, reason, actor_id, external_ref, created_at
       FROM ai_credit_entries
      WHERE organization_id = $1
      ORDER BY created_at DESC
      LIMIT $2`,
    [scope.organizationId, Math.max(1, Math.min(500, Math.trunc(limit)))],
  );
}

/**
 * Low-balance signal (cap 40). Pure + deterministic so it is testable without a
 * DB and cannot drift between the panel and the alert dispatcher.
 *
 * A RATIO, not a hardcoded unit count: "50 credits left" means nothing without
 * knowing whether the school bought 100 or 100,000.
 *
 * The denominator is the LAST TOP-UP, which took two wrong turns to find:
 *   • `granted - debited` is degenerate — with no reservations that IS
 *     `available`, so the test collapses to `available <= available * 0.1`,
 *     which is only ever true at zero. The alert would never fire.
 *   • lifetime `granted` is wrong in the opposite direction — an org that tops
 *     up every month for years accumulates a huge lifetime figure, so 10% of it
 *     exceeds any single purchase and the org looks "low" forever, including the
 *     instant after it pays.
 * "You have used 90% of what you last bought" is the statement a school can act
 * on, and it holds however long they have been a customer.
 */
export const WALLET_LOW_BALANCE_RATIO = 0.1;

export type WalletHealth = "healthy" | "low" | "empty";

export function walletHealth(balance: AiWalletBalance): WalletHealth {
  if (balance.availableUnits <= 0) return "empty";
  // Fall back to lifetime grants when the org has never had a top_up (credited
  // only by adjustment, e.g. a migrated or comped account) — the best signal
  // available rather than no signal.
  const ceiling = balance.lastTopUpUnits > 0
    ? balance.lastTopUpUnits
    : balance.grantedUnits;
  if (ceiling <= 0) return "empty";
  return balance.availableUnits <= Math.ceil(ceiling * WALLET_LOW_BALANCE_RATIO)
    ? "low"
    : "healthy";
}

function toUnits(v: string | number | undefined): number {
  if (v == null) return 0;
  const n = typeof v === "number" ? v : Number.parseInt(String(v), 10);
  return Number.isFinite(n) ? Math.trunc(n) : 0;
}
