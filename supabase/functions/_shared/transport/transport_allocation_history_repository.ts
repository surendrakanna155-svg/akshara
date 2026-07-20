// W4 — Transport assignment history (Owner decision #5): effective-dated
// (Valid-From / Valid-To) allocation timeline. NEVER overwrite a historical
// assignment — a change CLOSEs the currently-open period (stamps valid_to once)
// and INSERTs a fresh open period, so the full route/stop history survives and
// the allocation open on ANY past date can be reconstructed.
//
// Backing store: the dedicated transport_allocation_history table
// (migration 20260900000021), NOT the opaque transport_entities allocation
// payload — real typed valid_from/valid_to columns give clean as-of range
// queries + a proper index, and a PARTIAL UNIQUE INDEX on the open period
// (WHERE valid_to IS NULL) is the DB-level terminal-write guard against a
// concurrent double-open.

import type { TenantQueryClient } from "../tenant_db.ts";
import { WriteValidationError } from "../entity_write/module_write_handlers.ts";

const TABLE = "transport_allocation_history";

// Postgres unique_violation SQLSTATE. The open-period partial unique index
// (transport_allocation_history_open_uniq) raises this when a racing concurrent
// re-assignment tries to open a SECOND open period for the same allocation.
// Defined locally (not imported from transport_write_handlers.ts) to keep this
// repository free of a circular dependency — the write handlers import IT.
const PG_UNIQUE_VIOLATION = "23505";

function isUniqueViolation(error: unknown): boolean {
  if (typeof error !== "object" || error === null) return false;
  const code = (error as { code?: unknown; fields?: { code?: unknown } }).code ??
    (error as { fields?: { code?: unknown } }).fields?.code;
  return code === PG_UNIQUE_VIOLATION;
}

/** Raised when a concurrent re-assignment already opened a new period for this
 * allocation — the racing loser is rejected rather than persist two open
 * periods. Extends WriteValidationError(409) so runWrite surfaces a clean 409
 * CONFLICT to the client (a retry re-reads the now-current allocation), with no
 * per-handler mapping. */
export class AllocationHistoryConflictError extends WriteValidationError {
  constructor(public readonly allocationId: string) {
    super(
      `Concurrent transport re-assignment for allocation ${allocationId}; retry`,
      409,
      "TRANSPORT_REASSIGN_CONFLICT",
    );
    this.name = "AllocationHistoryConflictError";
  }
}

/** One immutable assignment-period row. `validTo === null` ⇒ currently open. */
export interface AllocationHistoryRecord {
  id: string;
  allocationId: string;
  sisStudentId: string | null;
  routeId: string | null;
  pickupStop: string | null;
  dropStop: string | null;
  shift: string | null;
  payload: Record<string, unknown>;
  validFrom: string;
  validTo: string | null;
}

/** The material assignment captured when a period opens. */
export interface AllocationAssignmentSnapshot {
  sisStudentId?: string | null;
  routeId?: string | null;
  pickupStop?: string | null;
  dropStop?: string | null;
  shift?: string | null;
  /** Full allocation payload snapshot preserved verbatim for this period. */
  payload?: Record<string, unknown>;
}

interface HistoryRow {
  id: string;
  allocation_id: string;
  sis_student_id: string | null;
  route_id: string | null;
  pickup_stop: string | null;
  drop_stop: string | null;
  shift: string | null;
  payload: Record<string, unknown>;
  valid_from: string;
  valid_to: string | null;
}

const SELECT_COLUMNS =
  `id, allocation_id, sis_student_id, route_id, pickup_stop, drop_stop, shift, payload, valid_from, valid_to`;

function mapRow(row: HistoryRow): AllocationHistoryRecord {
  return {
    id: row.id,
    allocationId: row.allocation_id,
    sisStudentId: row.sis_student_id ?? null,
    routeId: row.route_id ?? null,
    pickupStop: row.pickup_stop ?? null,
    dropStop: row.drop_stop ?? null,
    shift: row.shift ?? null,
    payload: row.payload ?? {},
    validFrom: row.valid_from,
    validTo: row.valid_to ?? null,
  };
}

/** Normalize a nullable/optional string field for comparison (null ≡ ""). */
function norm(v: string | null | undefined): string {
  return v == null ? "" : String(v);
}

/** True when an already-open period already reflects this exact assignment
 * (same route + stops + shift) — so recording it again is a no-op, not a new
 * period (avoids polluting the timeline with identical adjacent rows on an
 * idempotent re-assign of the SAME route). */
function sameAssignment(
  current: AllocationHistoryRecord,
  snapshot: AllocationAssignmentSnapshot,
): boolean {
  return norm(current.routeId) === norm(snapshot.routeId) &&
    norm(current.pickupStop) === norm(snapshot.pickupStop) &&
    norm(current.dropStop) === norm(snapshot.dropStop) &&
    norm(current.shift) === norm(snapshot.shift);
}

/**
 * Read (and lock) the currently-open period for an allocation, or null when the
 * timeline has no open period (first-ever assignment, or already stopped).
 * FOR UPDATE serializes concurrent recorders on the same allocation so the
 * close-then-insert below is not interleaved.
 */
async function findOpenPeriod(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  allocationId: string,
): Promise<AllocationHistoryRecord | null> {
  const rows = await db.queryObject<HistoryRow>(
    `SELECT ${SELECT_COLUMNS}
     FROM ${TABLE}
     WHERE organization_id = $1
       AND school_id = $2
       AND allocation_id = $3
       AND valid_to IS NULL
     FOR UPDATE`,
    [organizationId, schoolId, allocationId],
  );
  return rows[0] ? mapRow(rows[0]) : null;
}

/**
 * Record an assignment change for `allocationId` on the effective-dated timeline
 * (Owner decision #5): CLOSE the currently-open period (valid_to = changeDate)
 * and INSERT a fresh open period (valid_to = NULL). Never overwrites a historical
 * period. Returns `{ changed:false }` (a no-op) when the open period already
 * reflects this exact route/stop/shift.
 *
 * Concurrency: the open-period partial unique index
 * (transport_allocation_history_open_uniq) is the terminal-write guard — a racing
 * re-assignment that already opened a new period makes THIS insert raise 23505,
 * which we catch inside a SAVEPOINT (keeping the surrounding withTenantContext
 * transaction alive) and reject as {@link AllocationHistoryConflictError} rather
 * than persist two open periods. Mirrors the money-race backstop
 * insertDemandIdempotent.
 */
export async function recordAllocationChange(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  allocationId: string,
  snapshot: AllocationAssignmentSnapshot,
  options: { changeDate: string; changedBy: string | null },
): Promise<{ record: AllocationHistoryRecord; changed: boolean }> {
  const current = await findOpenPeriod(db, organizationId, schoolId, allocationId);

  if (current && sameAssignment(current, snapshot)) {
    // Idempotent re-assign to the SAME route/stop — the open period already
    // records it; do not churn the timeline.
    return { record: current, changed: false };
  }

  // Close the prior open period AT the change instant. The `valid_to IS NULL`
  // predicate is the temporal guard: a concurrent writer that already closed it
  // updates 0 rows here (and its own new open period is caught below).
  if (current) {
    await db.queryObject(
      `UPDATE ${TABLE}
         SET valid_to = $4
       WHERE organization_id = $1
         AND school_id = $2
         AND allocation_id = $3
         AND valid_to IS NULL`,
      [organizationId, schoolId, allocationId, options.changeDate],
    );
  }

  const id = crypto.randomUUID();
  await db.queryObject(`SAVEPOINT transport_alloc_history_open`);
  try {
    const inserted = await db.queryObject<HistoryRow>(
      `INSERT INTO ${TABLE}
         (id, organization_id, school_id, allocation_id, sis_student_id,
          route_id, pickup_stop, drop_stop, shift, payload, valid_from, valid_to, changed_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, $11, NULL, $12)
       RETURNING ${SELECT_COLUMNS}`,
      [
        id,
        organizationId,
        schoolId,
        allocationId,
        snapshot.sisStudentId ?? null,
        snapshot.routeId ?? null,
        snapshot.pickupStop ?? null,
        snapshot.dropStop ?? null,
        snapshot.shift ?? null,
        JSON.stringify(snapshot.payload ?? {}),
        options.changeDate,
        options.changedBy,
      ],
    );
    await db.queryObject(`RELEASE SAVEPOINT transport_alloc_history_open`);
    return { record: mapRow(inserted[0]!), changed: true };
  } catch (error) {
    if (!isUniqueViolation(error)) throw error;
    // A racing concurrent re-assignment already opened a new period — reject the
    // double-open. The surrounding transaction stays alive via the savepoint.
    await db.queryObject(`ROLLBACK TO SAVEPOINT transport_alloc_history_open`);
    throw new AllocationHistoryConflictError(allocationId);
  }
}

/**
 * Close the currently-open period for an allocation without opening a new one —
 * the student stops riding, so the timeline simply ends. Idempotent: returns the
 * closed record, or null when there was no open period. Stamps valid_to once
 * (never rewrites the historical snapshot).
 */
export async function closeOpenAllocation(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  allocationId: string,
  closedAt: string,
): Promise<AllocationHistoryRecord | null> {
  const rows = await db.queryObject<HistoryRow>(
    `UPDATE ${TABLE}
       SET valid_to = $4
     WHERE organization_id = $1
       AND school_id = $2
       AND allocation_id = $3
       AND valid_to IS NULL
     RETURNING ${SELECT_COLUMNS}`,
    [organizationId, schoolId, allocationId, closedAt],
  );
  return rows[0] ? mapRow(rows[0]) : null;
}

/**
 * Reconstruct the allocation period OPEN on `asOf` for one allocation:
 * valid_from <= asOf AND (valid_to IS NULL OR valid_to > asOf). Returns null when
 * the allocation had no active period on that date. `asOf` is an ISO date or
 * datetime; a bare date resolves to the start of that day.
 */
export async function getAllocationAsOf(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  allocationId: string,
  asOf: string,
): Promise<AllocationHistoryRecord | null> {
  const rows = await db.queryObject<HistoryRow>(
    `SELECT ${SELECT_COLUMNS}
     FROM ${TABLE}
     WHERE organization_id = $1
       AND school_id = $2
       AND allocation_id = $3
       AND valid_from <= $4
       AND (valid_to IS NULL OR valid_to > $4)
     ORDER BY valid_from DESC
     LIMIT 1`,
    [organizationId, schoolId, allocationId, asOf],
  );
  return rows[0] ? mapRow(rows[0]) : null;
}

/** Full chronological timeline for one allocation (oldest period first). */
export async function listAllocationTimeline(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  allocationId: string,
): Promise<AllocationHistoryRecord[]> {
  const rows = await db.queryObject<HistoryRow>(
    `SELECT ${SELECT_COLUMNS}
     FROM ${TABLE}
     WHERE organization_id = $1
       AND school_id = $2
       AND allocation_id = $3
     ORDER BY valid_from ASC, created_at ASC`,
    [organizationId, schoolId, allocationId],
  );
  return rows.map(mapRow);
}

/**
 * Reconstruct which allocation a STUDENT rode on `asOf` (per-student as-of read).
 * Returns the period open on that date across all of the student's allocations,
 * or null.
 */
export async function getStudentAllocationAsOf(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  sisStudentId: string,
  asOf: string,
): Promise<AllocationHistoryRecord | null> {
  const rows = await db.queryObject<HistoryRow>(
    `SELECT ${SELECT_COLUMNS}
     FROM ${TABLE}
     WHERE organization_id = $1
       AND school_id = $2
       AND sis_student_id = $3
       AND valid_from <= $4
       AND (valid_to IS NULL OR valid_to > $4)
     ORDER BY valid_from DESC
     LIMIT 1`,
    [organizationId, schoolId, sisStudentId, asOf],
  );
  return rows[0] ? mapRow(rows[0]) : null;
}

/** Full chronological transport-assignment timeline for one student. */
export async function listStudentAllocationTimeline(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  sisStudentId: string,
): Promise<AllocationHistoryRecord[]> {
  const rows = await db.queryObject<HistoryRow>(
    `SELECT ${SELECT_COLUMNS}
     FROM ${TABLE}
     WHERE organization_id = $1
       AND school_id = $2
       AND sis_student_id = $3
     ORDER BY valid_from ASC, created_at ASC`,
    [organizationId, schoolId, sisStudentId],
  );
  return rows.map(mapRow);
}
