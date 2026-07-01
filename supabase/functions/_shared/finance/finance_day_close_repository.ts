import type { TenantQueryClient } from "../tenant_db.ts";

// FIN-D1 — day-close lock persistence. A "closed" day blocks any collection (or
// cancellation) dated on/before the LATEST closed date for the school. Additive:
// nothing here touches the collection/invoice money path.

export interface FinanceDayCloseRow {
  id: string;
  organization_id: string;
  school_id: string;
  close_date: string;
  status: "open" | "closed";
  closed_by: string | null;
  closed_at: string;
  reopened_by: string | null;
  reopened_at: string | null;
}

export class DayCloseNotFoundError extends Error {
  constructor(date: string) {
    super(`No closed day found for date: ${date}`);
    this.name = "DayCloseNotFoundError";
  }
}

/**
 * The latest `close_date` that is currently `status = 'closed'` for the school,
 * or null when the school has never closed a day. Any collection dated on/before
 * this date is locked.
 */
export async function latestClosedDate(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<string | null> {
  const rows = await db.queryObject<{ close_date: string }>(
    `SELECT close_date FROM finance_day_close
     WHERE organization_id = $1 AND school_id = $2 AND status = 'closed'
     ORDER BY close_date DESC
     LIMIT 1`,
    [organizationId, schoolId],
  );
  return rows[0]?.close_date ?? null;
}

/**
 * True when `collectionDate` (YYYY-MM-DD) falls on or before the latest closed
 * date — i.e. entering/cancelling money on that date is forbidden. Used as the
 * pre-write guard by createCollection + cancelCollection.
 */
export async function isDateLocked(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  collectionDate: string,
): Promise<boolean> {
  const latest = await latestClosedDate(db, organizationId, schoolId);
  if (!latest) return false;
  // Both are YYYY-MM-DD ISO date strings so lexical compare == chronological.
  return collectionDate.slice(0, 10) <= latest.slice(0, 10);
}

/** Close a given date for the school (idempotent re-close reopens→closed). */
export async function closeDay(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  closeDate: string,
  closedBy: string,
): Promise<FinanceDayCloseRow> {
  const rows = await db.queryObject<FinanceDayCloseRow>(
    `INSERT INTO finance_day_close (
       organization_id, school_id, close_date, status, closed_by, closed_at
     ) VALUES ($1, $2, $3, 'closed', $4, timezone('utc', now()))
     ON CONFLICT (organization_id, school_id, close_date) DO UPDATE
       SET status = 'closed',
           closed_by = EXCLUDED.closed_by,
           closed_at = timezone('utc', now()),
           reopened_by = NULL,
           reopened_at = NULL
     RETURNING *`,
    [organizationId, schoolId, closeDate, closedBy],
  );
  return rows[0]!;
}

/** Reopen a closed date. Returns null when no closed row exists for the date. */
export async function reopenDay(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  closeDate: string,
  reopenedBy: string,
): Promise<FinanceDayCloseRow | null> {
  const rows = await db.queryObject<FinanceDayCloseRow>(
    `UPDATE finance_day_close SET
       status = 'open',
       reopened_by = $4,
       reopened_at = timezone('utc', now())
     WHERE organization_id = $1 AND school_id = $2 AND close_date = $3
       AND status = 'closed'
     RETURNING *`,
    [organizationId, schoolId, closeDate, reopenedBy],
  );
  return rows[0] ?? null;
}

/** List day-close rows for the school, optionally bounded by [from, to]. */
export async function listDayClose(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  from?: string,
  to?: string,
): Promise<FinanceDayCloseRow[]> {
  const params: unknown[] = [organizationId, schoolId];
  let where = "organization_id = $1 AND school_id = $2";
  if (from) {
    params.push(from);
    where += ` AND close_date >= $${params.length}`;
  }
  if (to) {
    params.push(to);
    where += ` AND close_date <= $${params.length}`;
  }
  return await db.queryObject<FinanceDayCloseRow>(
    `SELECT * FROM finance_day_close
     WHERE ${where}
     ORDER BY close_date DESC`,
    params,
  );
}
