// Adaptive AI — P3-AI-3 / A5: atomic gateway quota reservations.
//
// Closes the gateway's check-then-act TOCTOU race (audit P1-3 deferred tail):
// the request pipeline runs inside ONE transaction, so anything it writes is
// invisible to concurrent requests until commit — window-count checks against
// ai_call_log therefore raced for the whole provider round-trip (up to 20s)
// and every limit could be overshot by N-1 under an N-request burst.
//
// The fix: BEFORE the provider call, reserve on a DEDICATED short-lived
// connection that commits immediately, so the reservation is visible to every
// concurrent request within milliseconds. Inside that tiny transaction an
// advisory xact lock (per org+school bucket) serializes competing reservations
// and a single INSERT..SELECT admits the call only if
//   committed ai_call_log window counts + live pending reservations + this call
// stay inside every limit. After the provider call the caller finalizes on its
// OWN request transaction: `consume` in the same transaction that appends the
// ai_call_log row (the pair swaps atomically — each call counted exactly once
// at every instant) or `release` when no cost was incurred.
//
// Crash safety: a reservation abandoned by a rolled-back request stays
// 'pending' but stops counting after PENDING_TTL_MS and is swept by the next
// reservation's cleanup — self-healing in the conservative (over-blocking)
// direction, never the uncapped one.
//
// The pool here is deliberately SEPARATE from tenant_db's request pool: a
// request holds its own connection while it reserves, so borrowing a second
// connection from the same exhausted pool could self-deadlock under load.

import { Pool } from "https://deno.land/x/postgres@v0.19.3/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { type AiTenantScope, RATE_WINDOW_OUTCOME_FILTER } from "./ai_call_log_repository.ts";

/** Structurally identical to model_gateway's GatewayLimits (kept local to
 * avoid an import cycle; 0 = unlimited, matching decideGateway). */
export interface ReservationLimits {
  userCallsPerHour: number;
  schoolCallsPerDay: number;
  monthlySpendCapMicros: number;
}

export type ReserveDenyReason = "rate_user" | "rate_school" | "spend_cap";

export type ReserveResult =
  | { allow: true; reservationId: string }
  | { allow: false; reason: ReserveDenyReason };

export interface ReserveArgs {
  scope: AiTenantScope;
  userId: string | null;
  surface: string;
  estimatedCostMicros: number;
  limits: ReservationLimits;
  now: Date;
}

/** A pending reservation older than this no longer counts against limits —
 * it can only be an abandoned row (crash/rollback); the gateway finalizes
 * well inside its 20s provider timeout. */
export const PENDING_TTL_MS = 120_000;

/** Minimal exec seam so the reservation transaction body is unit-testable. */
export interface ReservationExec {
  queryObject<T>(sql: string, args?: unknown[]): Promise<T[]>;
}

const RESERVATION_POOL_SIZE = 3;
let _pool: Pool | null = null;
let _poolUrl: string | null = null;

function reservationPool(url: string): Pool {
  if (_pool && _poolUrl === url) return _pool;
  if (_pool) {
    const stale = _pool;
    _pool = null;
    stale.end().catch(() => {});
  }
  _pool = new Pool(url, RESERVATION_POOL_SIZE, /* lazy */ true);
  _poolUrl = url;
  return _pool;
}

/** Thrown when the reservation infrastructure is not configured/reachable —
 * the gateway catches this and falls back to the legacy window-count check
 * (availability over strictness; the failure is logged loudly). */
export class ReservationsUnavailableError extends Error {
  constructor(cause: string) {
    super(`AI call reservations unavailable: ${cause}`);
  }
}

function isoBefore(now: Date, ms: number): string {
  return new Date(now.getTime() - ms).toISOString();
}

/** UTC calendar-month start — the spend-cap window shared with the gateway. */
export function monthStartIso(now: Date): string {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)).toISOString();
}

/** The transaction body: opportunistic sweep, then the atomic admit-or-deny
 * INSERT..SELECT, then (only on deny) one SELECT to name the failed gate in
 * decideGateway's order (user → school → spend). MUST run inside a transaction
 * that already holds the per-bucket advisory lock. */
export async function runReservation(
  exec: ReservationExec,
  args: ReserveArgs,
): Promise<ReserveResult> {
  const { scope, userId, surface, estimatedCostMicros, limits, now } = args;
  const since1h = isoBefore(now, 3_600_000);
  const since24h = isoBefore(now, 24 * 3_600_000);
  const monthStart = monthStartIso(now);
  const pendingSince = isoBefore(now, PENDING_TTL_MS);

  // Sweep: expired pending rows and finalized rows past their debug window.
  await exec.queryObject(
    `DELETE FROM ai_call_reservations
      WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2
        AND ((status = 'pending' AND created_at < now() - interval '10 minutes')
          OR (status <> 'pending' AND created_at < now() - interval '1 hour'))`,
    [scope.organizationId, scope.schoolId],
  );

  const inserted = await exec.queryObject<{ id: string }>(
    `INSERT INTO ai_call_reservations (
       organization_id, school_id, user_id, surface, estimated_cost_micros
     )
     SELECT $1::uuid, $2::uuid, $3::uuid, $4, $5::bigint
      WHERE ($6::int <= 0 OR $3::uuid IS NULL OR (
              (SELECT count(*) FROM ai_call_log
                WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2
                  AND user_id = $3 AND created_at >= $9
                  AND ${RATE_WINDOW_OUTCOME_FILTER})
            + (SELECT count(*) FROM ai_call_reservations
                WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2
                  AND user_id = $3 AND status = 'pending' AND created_at >= $12)
            ) < $6::int)
        AND ($7::int <= 0 OR (
              (SELECT count(*) FROM ai_call_log
                WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2
                  AND created_at >= $10
                  AND ${RATE_WINDOW_OUTCOME_FILTER})
            + (SELECT count(*) FROM ai_call_reservations
                WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2
                  AND status = 'pending' AND created_at >= $12)
            ) < $7::int)
        AND ($8::bigint <= 0 OR (
              (SELECT coalesce(sum(estimated_cost_micros), 0) FROM ai_call_log
                WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2
                  AND created_at >= $11)
            + (SELECT coalesce(sum(estimated_cost_micros), 0) FROM ai_call_reservations
                WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2
                  AND status = 'pending' AND created_at >= $12)
            ) + $5::bigint <= $8::bigint)
     RETURNING id`,
    [
      scope.organizationId,
      scope.schoolId,
      userId,
      surface,
      Math.max(0, Math.trunc(estimatedCostMicros)),
      Math.trunc(limits.userCallsPerHour),
      Math.trunc(limits.schoolCallsPerDay),
      Math.trunc(limits.monthlySpendCapMicros),
      since1h,
      since24h,
      monthStart,
      pendingSince,
    ],
  );
  const id = inserted[0]?.id;
  if (id) return { allow: true, reservationId: id };

  // Denied — name the gate, in the same order decideGateway uses.
  const rows = await exec.queryObject<{
    user_calls: number;
    school_calls: number;
    month_spend: string | number;
  }>(
    `SELECT
       ((SELECT count(*) FROM ai_call_log
          WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2
            AND user_id = $3 AND created_at >= $4 AND ${RATE_WINDOW_OUTCOME_FILTER})
      + (SELECT count(*) FROM ai_call_reservations
          WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2
            AND user_id = $3 AND status = 'pending' AND created_at >= $7))::int AS user_calls,
       ((SELECT count(*) FROM ai_call_log
          WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2
            AND created_at >= $5 AND ${RATE_WINDOW_OUTCOME_FILTER})
      + (SELECT count(*) FROM ai_call_reservations
          WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2
            AND status = 'pending' AND created_at >= $7))::int AS school_calls,
       ((SELECT coalesce(sum(estimated_cost_micros), 0) FROM ai_call_log
          WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2
            AND created_at >= $6)
      + (SELECT coalesce(sum(estimated_cost_micros), 0) FROM ai_call_reservations
          WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2
            AND status = 'pending' AND created_at >= $7))::bigint AS month_spend`,
    [
      scope.organizationId,
      scope.schoolId,
      userId,
      since1h,
      since24h,
      monthStart,
      pendingSince,
    ],
  );
  const usage = rows[0];
  const userCalls = Number(usage?.user_calls ?? 0);
  const schoolCalls = Number(usage?.school_calls ?? 0);
  const monthSpend = Number(usage?.month_spend ?? 0);
  if (limits.userCallsPerHour > 0 && userId !== null && userCalls >= limits.userCallsPerHour) {
    return { allow: false, reason: "rate_user" };
  }
  if (limits.schoolCallsPerDay > 0 && schoolCalls >= limits.schoolCallsPerDay) {
    return { allow: false, reason: "rate_school" };
  }
  return { allow: false, reason: "spend_cap" };
}

/** Zero UUID for the accounting context's user slot when the calling surface
 * has no user (set_request_context rejects a NULL user id; no policy on the
 * accounting tables reads app.user_id). */
const ACCOUNTING_USER = "00000000-0000-0000-0000-000000000000";

/** Reserve on the dedicated immediate-commit connection. Throws
 * {@link ReservationsUnavailableError} when unconfigured/unreachable — the
 * gateway degrades to its legacy window-count check and logs the failure. */
export async function reserveOutOfBand(args: ReserveArgs): Promise<ReserveResult> {
  const url = Deno.env.get("ERP_TENANT_DATABASE_URL");
  if (!url) throw new ReservationsUnavailableError("ERP_TENANT_DATABASE_URL not set");

  let client;
  try {
    client = await reservationPool(url).connect();
  } catch (err) {
    throw new ReservationsUnavailableError(String(err));
  }
  try {
    await client.queryObject`BEGIN`;
    try {
      // Accounting context: the org wall for RLS plus the bucket for the
      // ai_call_log_tenant_scope read policy (migration 20260869) — a school
      // bucket reads as a school session, the org bucket (school NULL) reads
      // as an organization session.
      await client.queryObject(
        `SELECT app.set_request_context($1::uuid, $2, $3::uuid, $4::uuid, NULL, NULL, NULL)`,
        [
          args.scope.organizationId,
          args.scope.schoolId === null ? "organization" : "school",
          args.userId ?? ACCOUNTING_USER,
          args.scope.schoolId,
        ],
      );
      // A waiter here holds a pool connection; bound the wait so a hot bucket
      // degrades to the legacy check instead of starving the 3-slot pool.
      await client.queryObject(`SET LOCAL lock_timeout = '2s'`);
      // Serialize competing reservations for this bucket; released on COMMIT.
      await client.queryObject(
        `SELECT pg_advisory_xact_lock(hashtextextended($1 || ':' || coalesce($2, 'org'), 42))`,
        [args.scope.organizationId, args.scope.schoolId],
      );
      const exec: ReservationExec = {
        queryObject: async <T>(sql: string, sqlArgs: unknown[] = []) =>
          (await client!.queryObject<T>(sql, sqlArgs)).rows,
      };
      const result = await runReservation(exec, args);
      await client.queryObject`COMMIT`;
      return result;
    } catch (err) {
      await client.queryObject`ROLLBACK`;
      throw new ReservationsUnavailableError(String(err));
    }
  } finally {
    client.release();
  }
}

/** Finalize on the CALLER's request transaction so the reservation flips in
 * the same commit that appends the ai_call_log row (exactly-once accounting).
 * The actual cost replaces the estimate for post-hoc debuggability. */
export async function consumeReservation(
  db: TenantQueryClient,
  reservationId: string,
  actualCostMicros: number,
): Promise<void> {
  await db.queryObject(
    `UPDATE ai_call_reservations
        SET status = 'consumed', estimated_cost_micros = $2
      WHERE id = $1 AND status = 'pending'`,
    [reservationId, Math.max(0, Math.trunc(actualCostMicros))],
  );
}

/** Release a reservation whose call incurred no cost (timeout/transport error
 * before tokens were billed). */
export async function releaseReservation(
  db: TenantQueryClient,
  reservationId: string,
): Promise<void> {
  await db.queryObject(
    `UPDATE ai_call_reservations
        SET status = 'released'
      WHERE id = $1 AND status = 'pending'`,
    [reservationId],
  );
}
