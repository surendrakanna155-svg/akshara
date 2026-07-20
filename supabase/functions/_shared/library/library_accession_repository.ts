// PRA-P1-41 (Owner decision #11, FINAL) — per-copy accession register.
//
// Each physical copy of a catalogued title gets a UNIQUE, GAPLESS accession
// number allocated from library_accession_counters — the SAME never-reused,
// concurrency-safe counter shape as the SIS TC serial (allocateTcSerial /
// school_tc_counters) and the PSID counter. The DO UPDATE row lock serializes
// concurrent allocations, so two simultaneous registrations can NEVER be handed
// the same number, and the UNIQUE(org, school, accession_no) constraint is the
// final integrity guard. This is deliberately NOT a race-prone MAX(accession_no)+1.
//
// The register row (library_accession_register) is the copy's identity: which
// title it belongs to (catalog ref + denormalized isbn/title snapshot), when it
// was acquired, its cost, and its status (active | lost | withdrawn). A copy is
// WITHDRAWN, never deleted — the accession record is permanent.

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  WriteNotFoundError,
  WriteValidationError,
} from "../entity_write/module_write_handlers.ts";

/** Zero-pad width for the display accession code (ACC-000001). */
const ACCESSION_PAD = 6;

/** The three valid register statuses (mirrors the DB CHECK constraint). */
export const ACCESSION_STATUSES = ["active", "lost", "withdrawn"] as const;
export type AccessionStatus = (typeof ACCESSION_STATUSES)[number];

/**
 * Allowed status transitions. A copy is registered `active`; it may then be
 * marked `lost` (from active) or `withdrawn` (from active OR a previously-lost
 * copy that is now formally struck off the register). `withdrawn` is terminal.
 * The DB write guards on exactly this from-set (WHERE status = ANY(...)) so a
 * second transition of an already-terminal copy matches 0 rows and is rejected
 * — the same throw-on-0-rows guard the money-integrity writes use.
 */
export const ACCESSION_TRANSITIONS: Record<"lost" | "withdrawn", AccessionStatus[]> = {
  lost: ["active"],
  withdrawn: ["active", "lost"],
};

/** A register row as returned to the API layer. */
export interface AccessionRow {
  id: string;
  accession_no: number;
  catalog_id: string;
  isbn: string | null;
  title: string | null;
  acquired_date: string;
  cost: string;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface RegisterCopyInput {
  catalogId: string;
  isbn?: string | null;
  title?: string | null;
  acquiredDate?: string | null;
  cost?: number;
}

/** The formatted display code for an accession number (e.g. 1 -> "ACC-000001"). */
export function formatAccessionCode(accessionNo: number): string {
  return `ACC-${String(accessionNo).padStart(ACCESSION_PAD, "0")}`;
}

/**
 * Parse a lookup path parameter into an accession number. Accepts the bare
 * integer ("42") or the formatted code ("ACC-000042", "acc-42") by pulling the
 * trailing digits. Returns null when no positive integer can be read.
 */
export function parseAccessionNo(raw: string): number | null {
  const digits = raw.replace(/[^0-9]/g, "");
  if (digits.length === 0) return null;
  const n = parseInt(digits, 10);
  return Number.isFinite(n) && n > 0 ? n : null;
}

/**
 * Atomically allocate the next accession number for a library and return it.
 * Mirrors allocateTcSerial / allocatePublicStudentId EXACTLY: the INSERT ... ON
 * CONFLICT DO UPDATE lands next_seq = 2 on the FIRST allocation (RETURNING
 * next_seq - 1 = 1) and, on conflict, bumps next_seq by one and RETURNS the
 * pre-bump value. The DO UPDATE row lock serializes concurrent allocations for
 * the same (org, school) — every number DISTINCT, GAPLESS, never reused.
 */
export async function allocateAccessionNo(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<number> {
  const rows = await db.queryObject<{ allocated: number }>(
    `INSERT INTO library_accession_counters (organization_id, school_id, next_seq)
     VALUES ($1, $2, 2)
     ON CONFLICT (organization_id, school_id) DO UPDATE
       SET next_seq = library_accession_counters.next_seq + 1
     RETURNING (library_accession_counters.next_seq - 1) AS allocated`,
    [organizationId, schoolId],
  );
  const allocated = rows[0]?.allocated;
  // throw-on-0-rows: the counter MUST return a value; a missing row means the
  // allocation did not land, so we refuse rather than silently reuse/skip.
  if (allocated == null) {
    throw new Error(
      `Accession number allocation returned no counter value for school ${schoolId}`,
    );
  }
  return Number(allocated);
}

/**
 * Register a new physical copy: allocate the next gapless accession number, then
 * INSERT the register row. Runs inside the caller's tenant transaction, so the
 * counter bump and the register INSERT commit or roll back together — a failed
 * INSERT never burns a number. The UNIQUE(org, school, accession_no) constraint
 * is the final guard against a duplicate number.
 */
export async function registerCopy(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: RegisterCopyInput,
): Promise<AccessionRow> {
  const catalogId = input.catalogId?.trim();
  if (!catalogId) {
    throw new WriteValidationError("catalogId is required to accession a copy");
  }
  const cost = typeof input.cost === "number" && Number.isFinite(input.cost)
    ? input.cost
    : 0;
  if (cost < 0) {
    throw new WriteValidationError("cost cannot be negative");
  }

  const accessionNo = await allocateAccessionNo(db, organizationId, schoolId);

  const rows = await db.queryObject<AccessionRow>(
    `INSERT INTO library_accession_register (
       organization_id, school_id, accession_no, catalog_id, isbn, title,
       acquired_date, cost, status
     ) VALUES (
       $1, $2, $3, $4, $5, $6,
       COALESCE($7::date, timezone('utc', now())::date), $8, 'active'
     )
     RETURNING id, accession_no, catalog_id, isbn, title,
               acquired_date::text AS acquired_date, cost::text AS cost,
               status, created_at::text AS created_at, updated_at::text AS updated_at`,
    [
      organizationId,
      schoolId,
      accessionNo,
      catalogId,
      input.isbn ?? null,
      input.title ?? null,
      input.acquiredDate ?? null,
      cost,
    ],
  );
  const row = rows[0];
  if (!row) {
    throw new Error("Failed to insert the accession register row");
  }
  return row;
}

export interface ListRegisterOptions {
  status?: string;
  catalogId?: string;
  isbn?: string;
  limit?: number;
}

/**
 * The accession register for a library, newest-accession first (highest number).
 * Optionally filtered by status (active/lost/withdrawn), catalog title, or isbn.
 */
export async function listRegister(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  options: ListRegisterOptions = {},
): Promise<AccessionRow[]> {
  const args: unknown[] = [organizationId, schoolId];
  const filters: string[] = [];
  if (options.status) {
    args.push(options.status);
    filters.push(`AND status = $${args.length}`);
  }
  if (options.catalogId) {
    args.push(options.catalogId);
    filters.push(`AND catalog_id = $${args.length}`);
  }
  if (options.isbn) {
    args.push(options.isbn);
    filters.push(`AND isbn = $${args.length}`);
  }
  const limit = Math.min(1000, Math.max(1, options.limit ?? 500));
  return await db.queryObject<AccessionRow>(
    `SELECT id, accession_no, catalog_id, isbn, title,
            acquired_date::text AS acquired_date, cost::text AS cost,
            status, created_at::text AS created_at, updated_at::text AS updated_at
       FROM library_accession_register
      WHERE organization_id = $1 AND school_id = $2
      ${filters.join("\n      ")}
      ORDER BY accession_no DESC
      LIMIT ${limit}`,
    args,
  );
}

/** Look up a single copy by its accession NUMBER (the library-unique key). */
export async function findByAccessionNo(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  accessionNo: number,
): Promise<AccessionRow | null> {
  const rows = await db.queryObject<AccessionRow>(
    `SELECT id, accession_no, catalog_id, isbn, title,
            acquired_date::text AS acquired_date, cost::text AS cost,
            status, created_at::text AS created_at, updated_at::text AS updated_at
       FROM library_accession_register
      WHERE organization_id = $1 AND school_id = $2 AND accession_no = $3`,
    [organizationId, schoolId, accessionNo],
  );
  return rows[0] ?? null;
}

/** Look up a single copy by its register row id. */
export async function findById(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
): Promise<AccessionRow | null> {
  const rows = await db.queryObject<AccessionRow>(
    `SELECT id, accession_no, catalog_id, isbn, title,
            acquired_date::text AS acquired_date, cost::text AS cost,
            status, created_at::text AS created_at, updated_at::text AS updated_at
       FROM library_accession_register
      WHERE organization_id = $1 AND school_id = $2 AND id = $3::uuid`,
    [organizationId, schoolId, id],
  );
  return rows[0] ?? null;
}

/**
 * Transition a copy's status to `lost` or `withdrawn`. The UPDATE is guarded on
 * the allowed from-status set (WHERE status = ANY(...)) so it is atomic and
 * idempotent-safe: a copy already in a terminal / incompatible status matches 0
 * rows. On 0 rows we classify the failure — 404 when the copy does not exist,
 * else a 409 conflict naming the current status — so a concurrent transition can
 * never double-apply. Mirrors the `AND status = '<pre>'` money-integrity guard.
 */
export async function transitionCopyStatus(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
  toStatus: string,
): Promise<AccessionRow> {
  if (toStatus !== "lost" && toStatus !== "withdrawn") {
    throw new WriteValidationError(
      "status must be one of: lost, withdrawn",
    );
  }
  const allowedFrom = ACCESSION_TRANSITIONS[toStatus];

  const rows = await db.queryObject<AccessionRow>(
    `UPDATE library_accession_register
        SET status = $4
      WHERE organization_id = $1 AND school_id = $2 AND id = $3::uuid
        AND status = ANY($5)
      RETURNING id, accession_no, catalog_id, isbn, title,
                acquired_date::text AS acquired_date, cost::text AS cost,
                status, created_at::text AS created_at, updated_at::text AS updated_at`,
    [organizationId, schoolId, id, toStatus, allowedFrom],
  );
  const updated = rows[0];
  if (updated) return updated;

  // 0 rows — classify: absent copy (404) vs. an incompatible current status (409).
  const existing = await findById(db, organizationId, schoolId, id);
  if (!existing) {
    throw new WriteNotFoundError(`Accession copy not found: ${id}`);
  }
  throw new WriteValidationError(
    `Cannot mark copy ${existing.status === toStatus ? "already " : ""}` +
      `${toStatus}: copy is currently '${existing.status}'`,
    409,
    "ACCESSION_STATUS_CONFLICT",
  );
}

/** Map a register row to the client DTO (adds the formatted display code). */
export function accessionRowToApi(row: AccessionRow): Record<string, unknown> {
  return {
    id: row.id,
    accessionNo: row.accession_no,
    accessionCode: formatAccessionCode(row.accession_no),
    catalogId: row.catalog_id,
    isbn: row.isbn ?? "",
    title: row.title ?? "",
    acquiredDate: row.acquired_date,
    cost: Number(row.cost),
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
