// PRC-A Batch 2 (caps 136-148) — Certificate Request Desk repository.
//
// This is a thin request/approval-linkage layer in front of the ALREADY
// CERTIFIED SIS issuance engine (sis_certificates_repository.ts). It never
// reimplements issuance — it only tracks the lifecycle of a REQUEST
// (pending -> approved/rejected -> issued/blocked_dues, or -> cancelled)
// and links it to the F2 approval framework row that decided it.
//
// Every terminal write here is a status-GUARDED UPDATE (`AND status = '<pre>'`)
// with a 0-rows-affected -> throw. This project has a known recurring defect
// class — a terminal state-write with no status guard allowing a concurrent
// double-apply — and this module deliberately never reproduces it: a
// concurrent cancel-vs-decide race, or a double-decide, always has exactly
// one winner; the loser's guarded UPDATE affects 0 rows and throws, rolling
// back its enclosing transaction.

import type { TenantQueryClient } from "../tenant_db.ts";

/** Mirrors CertificateType in sis_certificates_repository.ts (bonafide/study/
 * conduct/transfer/fee) — kept as an explicit local list (rather than
 * importing the SIS type) because this module's DB CHECK constraint is the
 * source of truth for what a REQUEST may carry, and duplicating the five
 * literals here keeps the migration and this file trivially diffable against
 * each other. */
export const CERTIFICATE_REQUEST_TYPES = [
  "bonafide",
  "study",
  "conduct",
  "transfer",
  "fee",
] as const;
export type CertificateRequestType = (typeof CERTIFICATE_REQUEST_TYPES)[number];

export const CERTIFICATE_REQUEST_STATUSES = [
  "pending",
  "approved",
  "rejected",
  "issued",
  "blocked_dues",
  "cancelled",
] as const;
export type CertificateRequestStatus = (typeof CERTIFICATE_REQUEST_STATUSES)[number];

export class InvalidCertificateRequestTypeError extends Error {
  constructor(type: string) {
    super(
      `Invalid certificate request type: ${type}. Expected one of ${
        CERTIFICATE_REQUEST_TYPES.join(", ")
      }.`,
    );
    this.name = "InvalidCertificateRequestTypeError";
  }
}

export class CertificateRequestNotFoundError extends Error {
  constructor(public readonly requestId: string) {
    super(`Certificate request not found: ${requestId}`);
    this.name = "CertificateRequestNotFoundError";
  }
}

export class CertificateRequestForbiddenError extends Error {
  constructor(public readonly requestId: string) {
    super(`You may only cancel a certificate request you raised`);
    this.name = "CertificateRequestForbiddenError";
  }
}

/**
 * Thrown when a guarded terminal UPDATE (`AND status = '<expected>'`) affects
 * 0 rows: the request is no longer in the expected status — already decided,
 * cancelled, or issued by a concurrent caller. This is the single guard that
 * makes a concurrent double-decide / cancel-vs-decide race safe: the loser
 * always lands here and its enclosing transaction rolls back, never a
 * double-write.
 */
export class CertificateRequestStateError extends Error {
  constructor(
    public readonly requestId: string,
    public readonly expectedStatus: string,
  ) {
    super(
      `Certificate request ${requestId} is not ${expectedStatus} (already decided or changed concurrently)`,
    );
    this.name = "CertificateRequestStateError";
  }
}

/** Thrown on a duplicate OPEN (pending/approved) request for the same
 * student+type — the DB partial unique index (uq_sis_certificate_requests_open)
 * is the authoritative guard; this just gives it a clean error type. */
export class DuplicateCertificateRequestError extends Error {
  constructor(
    public readonly studentId: string,
    public readonly certificateType: string,
  ) {
    super(
      `An open ${certificateType} certificate request already exists for this student`,
    );
    this.name = "DuplicateCertificateRequestError";
  }
}

export interface CertificateRequestScope {
  organizationId: string;
  schoolId: string;
}

export interface CertificateRequestRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  certificate_type: string;
  purpose: string | null;
  status: string;
  requested_by: string;
  requested_by_role: string | null;
  approval_request_id: string | null;
  issued_certificate_id: string | null;
  issue_note: string | null;
  decided_at: string | null;
  created_at: string;
  updated_at: string;
}

const COLUMNS = `id, organization_id, school_id, student_id, certificate_type, purpose,
  status, requested_by, requested_by_role, approval_request_id, issued_certificate_id,
  issue_note, decided_at::text AS decided_at, created_at::text AS created_at,
  updated_at::text AS updated_at`;

export function assertCertificateRequestType(type: string): CertificateRequestType {
  if ((CERTIFICATE_REQUEST_TYPES as readonly string[]).includes(type)) {
    return type as CertificateRequestType;
  }
  throw new InvalidCertificateRequestTypeError(type);
}

function isUniqueViolation(error: unknown, indexName: string): boolean {
  const msg = error instanceof Error ? error.message : String(error);
  return msg.includes(indexName) || msg.includes("duplicate key");
}

/** Raise a PENDING certificate request. Does NOT submit the F2 approval —
 * that is the handler's job (in the same transaction), so the caller controls
 * ordering (create request -> submit approval -> link approval_request_id). */
export async function createCertificateRequest(
  db: TenantQueryClient,
  scope: CertificateRequestScope,
  input: {
    studentId: string;
    certificateType: string;
    purpose?: string | null;
    requestedBy: string;
    requestedByRole?: string | null;
  },
): Promise<CertificateRequestRow> {
  const type = assertCertificateRequestType(input.certificateType);
  try {
    const rows = await db.queryObject<CertificateRequestRow>(
      `INSERT INTO sis_certificate_requests (
         organization_id, school_id, student_id, certificate_type, purpose,
         status, requested_by, requested_by_role
       ) VALUES ($1, $2, $3::uuid, $4, $5, 'pending', $6::uuid, $7)
       RETURNING ${COLUMNS}`,
      [
        scope.organizationId,
        scope.schoolId,
        input.studentId,
        type,
        input.purpose?.trim() || null,
        input.requestedBy,
        input.requestedByRole ?? null,
      ],
    );
    return rows[0]!;
  } catch (error) {
    if (isUniqueViolation(error, "uq_sis_certificate_requests_open")) {
      throw new DuplicateCertificateRequestError(input.studentId, type);
    }
    throw error;
  }
}

export interface CertificateRequestListFilter {
  status?: string;
  /** Restricts the list to these student ids (parent scope: their linked
   * children). RLS also enforces this at the DB layer; this is a belt-and-
   * braces app-level filter, and lets a parent's list be scoped in one query
   * without depending solely on RLS. */
  studentIds?: string[];
}

export async function listCertificateRequests(
  db: TenantQueryClient,
  scope: CertificateRequestScope,
  filter: CertificateRequestListFilter = {},
): Promise<CertificateRequestRow[]> {
  if (filter.studentIds && filter.studentIds.length === 0) {
    return [];
  }
  const clauses = ["organization_id = $1", "school_id = $2"];
  const args: unknown[] = [scope.organizationId, scope.schoolId];
  let idx = 3;
  if (filter.status) {
    clauses.push(`status = $${idx++}`);
    args.push(filter.status);
  }
  if (filter.studentIds) {
    clauses.push(`student_id = ANY($${idx++}::uuid[])`);
    args.push(filter.studentIds);
  }
  return await db.queryObject<CertificateRequestRow>(
    `SELECT ${COLUMNS} FROM sis_certificate_requests
      WHERE ${clauses.join(" AND ")}
      ORDER BY created_at DESC`,
    args,
  );
}

export async function getCertificateRequestById(
  db: TenantQueryClient,
  scope: CertificateRequestScope,
  id: string,
): Promise<CertificateRequestRow | null> {
  const rows = await db.queryObject<CertificateRequestRow>(
    `SELECT ${COLUMNS} FROM sis_certificate_requests
      WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3`,
    [id, scope.organizationId, scope.schoolId],
  );
  return rows[0] ?? null;
}

/** Stamps the F2 approval_requests id the raise transaction just created onto
 * the request row. Unguarded (no status precondition) — this always runs
 * immediately after createCertificateRequest, in the same transaction, before
 * any decision can possibly land. */
export async function linkApprovalRequest(
  db: TenantQueryClient,
  scope: CertificateRequestScope,
  id: string,
  approvalRequestId: string,
): Promise<void> {
  await db.queryObject(
    `UPDATE sis_certificate_requests
        SET approval_request_id = $4, updated_at = timezone('utc', now())
      WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3`,
    [id, scope.organizationId, scope.schoolId, approvalRequestId],
  );
}

/** Guarded pending -> cancelled. Throws CertificateRequestStateError (never
 * silently no-ops) if the request is no longer pending — including when it
 * was decided concurrently by the approval flow. */
export async function cancelCertificateRequest(
  db: TenantQueryClient,
  scope: CertificateRequestScope,
  id: string,
): Promise<CertificateRequestRow> {
  const rows = await db.queryObject<CertificateRequestRow>(
    `UPDATE sis_certificate_requests
        SET status = 'cancelled', decided_at = timezone('utc', now()), updated_at = timezone('utc', now())
      WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3 AND status = 'pending'
      RETURNING ${COLUMNS}`,
    [id, scope.organizationId, scope.schoolId],
  );
  const row = rows[0];
  if (!row) throw new CertificateRequestStateError(id, "pending");
  return row;
}

/** Guarded pending -> rejected, with the decision comment (if any) recorded
 * as issue_note. Used by the approval-effect (applyCertificateRequestDecision). */
export async function markRequestRejected(
  db: TenantQueryClient,
  scope: CertificateRequestScope,
  id: string,
  note: string | null,
): Promise<CertificateRequestRow> {
  const rows = await db.queryObject<CertificateRequestRow>(
    `UPDATE sis_certificate_requests
        SET status = 'rejected', issue_note = $4, decided_at = timezone('utc', now()), updated_at = timezone('utc', now())
      WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3 AND status = 'pending'
      RETURNING ${COLUMNS}`,
    [id, scope.organizationId, scope.schoolId, note],
  );
  const row = rows[0];
  if (!row) throw new CertificateRequestStateError(id, "pending");
  return row;
}

/** Guarded pending -> issued, stamping the SIS issuance register row id. */
export async function markRequestIssued(
  db: TenantQueryClient,
  scope: CertificateRequestScope,
  id: string,
  issuedCertificateId: string,
): Promise<CertificateRequestRow> {
  const rows = await db.queryObject<CertificateRequestRow>(
    `UPDATE sis_certificate_requests
        SET status = 'issued', issued_certificate_id = $4, decided_at = timezone('utc', now()), updated_at = timezone('utc', now())
      WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3 AND status = 'pending'
      RETURNING ${COLUMNS}`,
    [id, scope.organizationId, scope.schoolId, issuedCertificateId],
  );
  const row = rows[0];
  if (!row) throw new CertificateRequestStateError(id, "pending");
  return row;
}

/** Guarded pending -> blocked_dues (approved but the SIS engine could not
 * issue — no-dues gate, or a student-state error). Records why in issue_note
 * so the approval decision still lands honestly instead of rolling back. */
export async function markRequestBlockedDues(
  db: TenantQueryClient,
  scope: CertificateRequestScope,
  id: string,
  note: string,
): Promise<CertificateRequestRow> {
  const rows = await db.queryObject<CertificateRequestRow>(
    `UPDATE sis_certificate_requests
        SET status = 'blocked_dues', issue_note = $4, decided_at = timezone('utc', now()), updated_at = timezone('utc', now())
      WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3 AND status = 'pending'
      RETURNING ${COLUMNS}`,
    [id, scope.organizationId, scope.schoolId, note],
  );
  const row = rows[0];
  if (!row) throw new CertificateRequestStateError(id, "pending");
  return row;
}
