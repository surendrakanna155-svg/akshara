import type { TenantQueryClient } from "../tenant_db.ts";
import {
  clampPageSize,
  offsetFor,
  type PaginationResult,
} from "../academic/academic_pagination.ts";

export interface AttendanceSessionRow {
  id: string;
  organization_id: string;
  school_id: string;
  class_label: string;
  session_date: string;
  taken_by: string;
  status: string;
  created_at: string;
  updated_at: string;
  record_count?: number;
}

export function attendanceSessionToApi(
  row: AttendanceSessionRow,
): Record<string, unknown> {
  return {
    id: row.id,
    classLabel: row.class_label,
    sessionDate: row.session_date,
    takenBy: row.taken_by,
    status: row.status,
    recordCount: row.record_count ?? 0,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export class AttendanceSessionNotFoundError extends Error {
  constructor(id: string) {
    super(`Attendance session not found: ${id}`);
    this.name = "AttendanceSessionNotFoundError";
  }
}

/**
 * ICA-C3 (P1, perf): bound listAttendanceSessions.
 *
 * Previously this returned EVERY session for the school with no LIMIT and no
 * date filter — the LEFT JOIN + GROUP BY scanned the entire, ever-growing
 * session history on every call, so the read got slower every school day. It
 * now:
 *   1. Paginates (page / pageSize) with pageSize hard-capped at 100 via the
 *      shared clampPageSize — the same convention as the generic
 *      entity_read_store / academic_pagination path.
 *   2. Applies a trailing date window (default 90 days, override up to 366)
 *      so a default request can never scan the full historical table; the
 *      COUNT is bounded to the window too.
 *
 * The (organization_id, school_id, session_date DESC) index
 * (idx_attendance_sessions_school_date) serves both the window predicate and
 * the ORDER BY. The audit note confirmed existing indexes blunt the
 * attendance_records join, so once the driving set is bounded by the window +
 * LIMIT the LEFT JOIN + GROUP BY record_count is acceptable.
 */
export const DEFAULT_SESSIONS_PAGE_SIZE = 50;
export const DEFAULT_SESSIONS_WINDOW_DAYS = 90;
export const MAX_SESSIONS_WINDOW_DAYS = 366;

export interface ListAttendanceSessionsOptions {
  page?: number;
  pageSize?: number;
  /** Trailing look-back window in days. Bounded to 1..366; default 90. */
  windowDays?: number;
}

/** Bound windowDays to a sane, index-friendly range (default 90, max 366). */
export function clampSessionsWindowDays(windowDays: number | undefined): number {
  if (windowDays === undefined || !Number.isFinite(windowDays)) {
    return DEFAULT_SESSIONS_WINDOW_DAYS;
  }
  return Math.min(
    Math.max(Math.trunc(windowDays), 1),
    MAX_SESSIONS_WINDOW_DAYS,
  );
}

export async function listAttendanceSessions(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  options: ListAttendanceSessionsOptions = {},
): Promise<PaginationResult<AttendanceSessionRow>> {
  const pageSize = clampPageSize(options.pageSize ?? DEFAULT_SESSIONS_PAGE_SIZE);
  const page = Math.max(1, Math.trunc(options.page ?? 1));
  const offset = offsetFor(page, pageSize);
  const windowDays = clampSessionsWindowDays(options.windowDays);

  // Total sessions INSIDE the window — bounded, never the whole table. Uses the
  // same window predicate as the page query so `total` stays consistent.
  const countRows = await db.queryObject<{ total: string }>(
    `SELECT count(*)::text AS total
       FROM attendance_sessions s
      WHERE s.organization_id = $1 AND s.school_id = $2
        AND s.session_date >= (CURRENT_DATE - $3::int)`,
    [organizationId, schoolId, windowDays],
  );
  const total = parseInt(countRows[0]?.total ?? "0", 10);

  const rows = await db.queryObject<AttendanceSessionRow>(
    `SELECT s.*, count(ar.id)::int AS record_count
       FROM attendance_sessions s
       LEFT JOIN attendance_records ar ON ar.session_id = s.id
      WHERE s.organization_id = $1 AND s.school_id = $2
        AND s.session_date >= (CURRENT_DATE - $3::int)
      GROUP BY s.id
      ORDER BY s.session_date DESC, s.updated_at DESC
      LIMIT $4 OFFSET $5`,
    [organizationId, schoolId, windowDays, pageSize, offset],
  );

  return {
    items: rows,
    total,
    page,
    pageSize,
    hasMore: offset + rows.length < total,
  };
}

export async function getAttendanceSession(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  sessionId: string,
): Promise<AttendanceSessionRow | null> {
  const rows = await db.queryObject<AttendanceSessionRow>(
    `SELECT s.*, count(ar.id)::int AS record_count
     FROM attendance_sessions s
     LEFT JOIN attendance_records ar ON ar.session_id = s.id
     WHERE s.organization_id = $1 AND s.school_id = $2 AND s.id = $3::uuid
     GROUP BY s.id`,
    [organizationId, schoolId, sessionId],
  );
  return rows[0] ?? null;
}
