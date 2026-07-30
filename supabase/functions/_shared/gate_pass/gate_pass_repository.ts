// PRC-A Batch 2 — Gate Pass / Early Pickup repository.
//
// A gate pass moves pending -> approved|rejected (via the F2 approval
// framework; see applyGatePassDecision, invoked by the orchestrator's
// approval_type_handlers.ts) -> used|expired|cancelled. The single-use
// OTP/QR credential is minted on approval (see applyGatePassDecision) and
// consumed by a status-guarded terminal UPDATE in verifyGatePassCredential —
// the same "guarded terminal write, throw-on-0-rows" discipline this project
// uses for money (see finance_fee_reductions_repository.ts) applies here to a
// child-safety control: a concurrent double-verify must not let two people
// collect the same child.

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  computeCredentialExpiry,
  generateGatePassOtp,
  generateGatePassQrToken,
  hashGatePassSecret,
  timingSafeEqualHex,
} from "./gate_pass_crypto.ts";
import { enqueueNotificationRequested, processDeliveryQueue } from "../communication/notification_service.ts";

export const GATE_PASS_TYPES = ["early_pickup", "late_arrival", "authorized_exit"] as const;
export type GatePassType = (typeof GATE_PASS_TYPES)[number];

export const GATE_PASS_STATUSES = [
  "pending",
  "approved",
  "rejected",
  "used",
  "expired",
  "cancelled",
] as const;
export type GatePassStatus = (typeof GATE_PASS_STATUSES)[number];

export interface GatePassRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  pass_type: string;
  reason: string;
  requested_by: string;
  pickup_person_name: string;
  pickup_person_relation: string;
  pickup_person_phone: string;
  scheduled_at: string;
  status: string;
  approval_request_id: string | null;
  otp_hash: string | null;
  qr_token_hash: string | null;
  credential_expires_at: string | null;
  verified_by: string | null;
  verified_at: string | null;
  verification_note: string | null;
  created_at: string;
  updated_at: string;
}

/** All business-rule failures other than verification (which uses a deliberately
 * generic error — see {@link GatePassVerificationFailedError}). Carries a `code`
 * + HTTP `status` so handlers can translate it without a big if/else chain
 * (mirrors ClearanceWaiverError). */
export class GatePassError extends Error {
  readonly code: string;
  readonly status: number;
  constructor(code: string, message: string, status = 422) {
    super(message);
    this.name = "GatePassError";
    this.code = code;
    this.status = status;
  }
}

export class GatePassNotFoundError extends GatePassError {
  constructor(id: string) {
    super("NOT_FOUND", `Gate pass not found: ${id}`, 404);
    this.name = "GatePassNotFoundError";
  }
}

export class GatePassInvalidStateError extends GatePassError {
  constructor(public readonly gatePassId: string, action: string) {
    super(
      "INVALID_STATE",
      `Cannot ${action} gate pass ${gatePassId} — it is not in the expected state`,
      409,
    );
    this.name = "GatePassInvalidStateError";
  }
}

/**
 * Deliberately opaque: verification failure NEVER distinguishes "no such pass"
 * from "wrong status" / "expired" / "already used" / "wrong code" in what is
 * exposed to the caller (only `reason` is set, for server-side logs/tests) —
 * a security-sensitive gate endpoint must not let a prober learn whether a
 * given id is a real pending pickup.
 */
export class GatePassVerificationFailedError extends Error {
  constructor(public readonly reason: string) {
    super("Gate pass verification failed");
    this.name = "GatePassVerificationFailedError";
  }
}

// ── API mapping (redaction) ─────────────────────────────────────────────────

/**
 * Lazy expiry: an `approved` pass whose `credential_expires_at` has passed is
 * DISPLAYED as `expired` (never a misleading `approved`), without a physical
 * status UPDATE — the hard gate against actually using a stale credential
 * lives in {@link verifyGatePassCredential}, which re-checks the same
 * condition against the real column regardless of what a caller last saw.
 */
export function effectiveGatePassStatus(row: GatePassRow, now: Date = new Date()): string {
  if (
    row.status === "approved" &&
    row.credential_expires_at &&
    new Date(row.credential_expires_at).getTime() < now.getTime()
  ) {
    return "expired";
  }
  return row.status;
}

/** Never includes `otp_hash` / `qr_token_hash` — only a `hasCredential` boolean. */
export function gatePassToApi(row: GatePassRow, now: Date = new Date()): Record<string, unknown> {
  return {
    id: row.id,
    studentId: row.student_id,
    passType: row.pass_type,
    reason: row.reason,
    requestedBy: row.requested_by,
    pickupPersonName: row.pickup_person_name,
    pickupPersonRelation: row.pickup_person_relation,
    pickupPersonPhone: row.pickup_person_phone,
    scheduledAt: row.scheduled_at,
    status: effectiveGatePassStatus(row, now),
    rawStatus: row.status,
    approvalRequestId: row.approval_request_id,
    hasCredential: row.otp_hash != null || row.qr_token_hash != null,
    credentialExpiresAt: row.credential_expires_at,
    verifiedBy: row.verified_by,
    verifiedAt: row.verified_at,
    verificationNote: row.verification_note,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

// ── Guards ───────────────────────────────────────────────────────────────────

export async function studentExistsInSchool(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
): Promise<boolean> {
  const rows = await db.queryObject<{ id: string }>(
    `SELECT id FROM students WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [studentId, organizationId, schoolId],
  );
  return rows.length > 0;
}

export async function parentOwnsStudent(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  parentUserId: string,
  studentId: string,
): Promise<boolean> {
  const rows = await db.queryObject<{ id: string }>(
    `SELECT id FROM student_guardians
     WHERE organization_id = $1 AND school_id = $2 AND student_id = $3
       AND guardian_user_id = $4 AND status = 'active'`,
    [organizationId, schoolId, studentId, parentUserId],
  );
  return rows.length > 0;
}

async function primaryGuardianUserId(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
): Promise<string | null> {
  const rows = await db.queryObject<{ guardian_user_id: string }>(
    `SELECT guardian_user_id FROM student_guardians
     WHERE organization_id = $1 AND school_id = $2 AND student_id = $3 AND status = 'active'
     ORDER BY is_primary DESC, created_at ASC
     LIMIT 1`,
    [organizationId, schoolId, studentId],
  );
  return rows[0]?.guardian_user_id ?? null;
}

// ── Create ───────────────────────────────────────────────────────────────────

export interface CreateGatePassInput {
  studentId: string;
  passType: GatePassType;
  reason: string;
  requestedBy: string;
  pickupPersonName: string;
  pickupPersonRelation: string;
  pickupPersonPhone: string;
  scheduledAt: string; // ISO
}

export async function createGatePass(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateGatePassInput,
): Promise<GatePassRow> {
  try {
    const rows = await db.queryObject<GatePassRow>(
      `INSERT INTO gate_passes (
         organization_id, school_id, student_id, pass_type, reason, requested_by,
         pickup_person_name, pickup_person_relation, pickup_person_phone,
         scheduled_at, status
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'pending')
       RETURNING *`,
      [
        organizationId,
        schoolId,
        input.studentId,
        input.passType,
        input.reason,
        input.requestedBy,
        input.pickupPersonName,
        input.pickupPersonRelation,
        input.pickupPersonPhone,
        input.scheduledAt,
      ],
    );
    return rows[0]!;
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    if (msg.includes("uq_gate_passes_open_slot") || msg.includes("duplicate key")) {
      throw new GatePassError(
        "DUPLICATE_OPEN_SLOT",
        "A pending or approved gate pass already exists for this student at this scheduled time",
        409,
      );
    }
    throw error;
  }
}

/** Back-fills `approval_request_id` right after the F2 approval is submitted
 * (same transaction as {@link createGatePass}). */
export async function linkApprovalRequest(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  gatePassId: string,
  approvalRequestId: string,
): Promise<GatePassRow> {
  const rows = await db.queryObject<GatePassRow>(
    `UPDATE gate_passes SET approval_request_id = $4, updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
     RETURNING *`,
    [gatePassId, organizationId, schoolId, approvalRequestId],
  );
  return rows[0]!;
}

// ── Read ─────────────────────────────────────────────────────────────────────

export async function getGatePassForStaff(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
): Promise<GatePassRow | null> {
  const rows = await db.queryObject<GatePassRow>(
    `SELECT * FROM gate_passes WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [id, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

/** Restricted to the caller's own children (guardian join) — defense in depth
 * alongside the parent-scope RLS SELECT policy on `gate_passes`. */
export async function getGatePassForParent(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  parentUserId: string,
  id: string,
): Promise<GatePassRow | null> {
  const rows = await db.queryObject<GatePassRow>(
    `SELECT gp.* FROM gate_passes gp
     WHERE gp.id = $1 AND gp.organization_id = $2 AND gp.school_id = $3
       AND gp.student_id IN (
         SELECT sg.student_id FROM student_guardians sg
         WHERE sg.guardian_user_id = $4 AND sg.status = 'active' AND sg.school_id = $3
       )`,
    [id, organizationId, schoolId, parentUserId],
  );
  return rows[0] ?? null;
}

export async function listGatePassesForSchool(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  status?: string,
): Promise<GatePassRow[]> {
  if (status) {
    return await db.queryObject<GatePassRow>(
      `SELECT * FROM gate_passes
       WHERE organization_id = $1 AND school_id = $2 AND status = $3
       ORDER BY scheduled_at DESC`,
      [organizationId, schoolId, status],
    );
  }
  return await db.queryObject<GatePassRow>(
    `SELECT * FROM gate_passes
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY scheduled_at DESC`,
    [organizationId, schoolId],
  );
}

/** Restricted to the caller's own children (guardian subquery) — defense in
 * depth alongside the parent-scope RLS SELECT policy. */
export async function listGatePassesForParent(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  parentUserId: string,
  status?: string,
): Promise<GatePassRow[]> {
  const ownedClause = `gp.student_id IN (
    SELECT sg.student_id FROM student_guardians sg
    WHERE sg.guardian_user_id = $3 AND sg.status = 'active' AND sg.school_id = $2
  )`;
  if (status) {
    return await db.queryObject<GatePassRow>(
      `SELECT gp.* FROM gate_passes gp
       WHERE gp.organization_id = $1 AND gp.school_id = $2 AND ${ownedClause} AND gp.status = $4
       ORDER BY gp.scheduled_at DESC`,
      [organizationId, schoolId, parentUserId, status],
    );
  }
  return await db.queryObject<GatePassRow>(
    `SELECT gp.* FROM gate_passes gp
     WHERE gp.organization_id = $1 AND gp.school_id = $2 AND ${ownedClause}
     ORDER BY gp.scheduled_at DESC`,
    [organizationId, schoolId, parentUserId],
  );
}

// ── Cancel ───────────────────────────────────────────────────────────────────

/**
 * Cancels a still-open (pending/approved) pass. Guarded so only the original
 * requester OR someone holding `approveGatePass` may cancel, and only while
 * the pass hasn't already reached a terminal state — a single UPDATE that
 * both checks and claims, so a concurrent cancel/verify/decide can't race it.
 */
export async function cancelGatePass(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
  actorId: string,
  actorCanApprove: boolean,
): Promise<GatePassRow> {
  const rows = await db.queryObject<GatePassRow>(
    `UPDATE gate_passes
     SET status = 'cancelled', updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
       AND status IN ('pending', 'approved')
       AND (requested_by = $4 OR $5 = true)
     RETURNING *`,
    [id, organizationId, schoolId, actorId, actorCanApprove],
  );
  const row = rows[0];
  if (!row) {
    throw new GatePassError(
      "CANCEL_FAILED",
      "Gate pass not found, already decided/used, or you may not cancel it",
      409,
    );
  }
  return row;
}

// ── Approve / reject (F2 approval effect) ───────────────────────────────────

export interface GatePassDecisionResult {
  gatePassStatus: "approved" | "rejected";
  credentialIssued: boolean;
  otpDispatched?: boolean;
  expiresAt?: string;
}

/**
 * The exported effect the orchestrator's `approval_type_handlers.ts` wires as
 * `case "gatePass":`. `comment` is accepted for signature parity with the
 * other F2 effect handlers (the decision comment is already durably captured
 * in `approval_audit_entries` by the approval framework itself) but is not
 * otherwise used here.
 *
 * `rejected` — guarded status UPDATE only.
 * `approved` — mints a single-use OTP + QR token (crypto.getRandomValues),
 * persists ONLY their SHA-256 hashes + a `credential_expires_at` (see
 * {@link computeCredentialExpiry} — `scheduled_at + GATE_PASS_CREDENTIAL_TTL_HOURS`),
 * flips status via a guarded UPDATE, then best-effort dispatches the
 * PLAINTEXT OTP to the primary guardian via the communication service. The
 * plaintext NEVER appears in the returned payload — that payload is persisted
 * verbatim into `approval_domain_effects` (an audit table).
 */
export async function applyGatePassDecision(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  gatePassId: string,
  action: "approved" | "rejected",
  actorId: string,
  comment?: string | null,
): Promise<Record<string, unknown>> {
  void actorId;
  void comment;

  if (action === "rejected") {
    const rows = await db.queryObject<GatePassRow>(
      `UPDATE gate_passes SET status = 'rejected', updated_at = timezone('utc', now())
       WHERE id = $1 AND organization_id = $2 AND school_id = $3 AND status = 'pending'
       RETURNING *`,
      [gatePassId, organizationId, schoolId],
    );
    if (!rows[0]) throw new GatePassInvalidStateError(gatePassId, "reject");
    const result: GatePassDecisionResult = { gatePassStatus: "rejected", credentialIssued: false };
    return result as unknown as Record<string, unknown>;
  }

  const pendingRows = await db.queryObject<GatePassRow>(
    `SELECT * FROM gate_passes
     WHERE id = $1 AND organization_id = $2 AND school_id = $3 AND status = 'pending'`,
    [gatePassId, organizationId, schoolId],
  );
  const pending = pendingRows[0];
  if (!pending) throw new GatePassInvalidStateError(gatePassId, "approve");

  const otp = generateGatePassOtp();
  const qrToken = generateGatePassQrToken();
  const otpHash = await hashGatePassSecret(otp);
  const qrTokenHash = await hashGatePassSecret(qrToken);
  const expiresAt = computeCredentialExpiry(new Date(pending.scheduled_at));

  const approvedRows = await db.queryObject<GatePassRow>(
    `UPDATE gate_passes
     SET status = 'approved', otp_hash = $4, qr_token_hash = $5,
         credential_expires_at = $6, updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3 AND status = 'pending'
     RETURNING *`,
    [gatePassId, organizationId, schoolId, otpHash, qrTokenHash, expiresAt.toISOString()],
  );
  const approved = approvedRows[0];
  if (!approved) throw new GatePassInvalidStateError(gatePassId, "approve");

  // Best-effort dispatch — the credential is already durably minted; a comms
  // outage must not undo the approval or surface the plaintext to the caller.
  let otpDispatched = false;
  try {
    const recipientUserId = await primaryGuardianUserId(
      db,
      organizationId,
      schoolId,
      approved.student_id,
    );
    if (recipientUserId) {
      await enqueueNotificationRequested(
        db,
        organizationId,
        schoolId,
        recipientUserId,
        "Gate pass approved",
        `Your gate pass OTP is ${otp}. Present it (or the QR code in the app) at the school gate. ` +
          `Valid until ${expiresAt.toISOString()}.`,
        "gate_pass",
      );
      await processDeliveryQueue(db, organizationId);
      otpDispatched = true;
    }
  } catch {
    otpDispatched = false;
  }

  const result: GatePassDecisionResult = {
    gatePassStatus: "approved",
    credentialIssued: true,
    otpDispatched,
    expiresAt: expiresAt.toISOString(),
  };
  return result as unknown as Record<string, unknown>;
}

// ── Verify (the gate check) ──────────────────────────────────────────────────

/**
 * Validates ALL of: pass is `approved`, a credential exists, it has not
 * expired, and the presented secret hashes to either the stored OTP or QR
 * hash (constant-time compare) — then CLAIMS the pass via a terminal,
 * status-guarded UPDATE (`approved` -> `used`). A concurrent second verify
 * (of the OTP, the QR, or one of each) loses the race here: its UPDATE
 * matches 0 rows and it throws {@link GatePassVerificationFailedError} — the
 * same child is never released to two different collectors.
 */
export async function verifyGatePassCredential(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
  presentedSecret: string,
  verifiedBy: string,
  note: string | null,
): Promise<GatePassRow> {
  const rows = await db.queryObject<GatePassRow>(
    `SELECT * FROM gate_passes WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [id, organizationId, schoolId],
  );
  const row = rows[0];
  if (!row) throw new GatePassVerificationFailedError("not_found");
  if (row.status !== "approved") throw new GatePassVerificationFailedError("invalid_status");
  if (!row.otp_hash && !row.qr_token_hash) throw new GatePassVerificationFailedError("no_credential");
  if (
    row.credential_expires_at &&
    new Date(row.credential_expires_at).getTime() < Date.now()
  ) {
    throw new GatePassVerificationFailedError("expired");
  }

  const trimmed = presentedSecret.trim();
  if (!trimmed) throw new GatePassVerificationFailedError("empty_credential");
  const presentedHash = await hashGatePassSecret(trimmed);
  const otpMatch = row.otp_hash != null && timingSafeEqualHex(presentedHash, row.otp_hash);
  const qrMatch = row.qr_token_hash != null && timingSafeEqualHex(presentedHash, row.qr_token_hash);
  if (!otpMatch && !qrMatch) throw new GatePassVerificationFailedError("bad_credential");

  const updated = await db.queryObject<GatePassRow>(
    `UPDATE gate_passes
     SET status = 'used', verified_by = $4, verified_at = timezone('utc', now()),
         verification_note = $5, updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3 AND status = 'approved'
     RETURNING *`,
    [id, organizationId, schoolId, verifiedBy, note],
  );
  const final = updated[0];
  if (!final) throw new GatePassVerificationFailedError("race_lost");
  return final;
}
