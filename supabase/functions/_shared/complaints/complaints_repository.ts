// PRC-A Batch 2 (caps 101-108) — Complaint / Internal Issue repository.
//
// Every terminal state-write is a GUARDED UPDATE (`AND status = '<expected>'`,
// or an explicit IN-list for the narrower /assign edge) that returns zero
// rows on a lost race; callers throw on zero rows so the enclosing
// `withTenantContext` transaction rolls back. This is the fix pattern for
// this project's recurring "terminal write with no status guard -> concurrent
// double-apply" defect class (see the account/invoice money-integrity
// precedent) — a complaint's status is judged the same way an account
// balance is: a bare, unconditional UPDATE would let two concurrent actors
// both "win" a transition.

import { ASSIGNABLE_FROM, isLegalTransition, type ComplaintStatus } from "./complaints_sla.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

export class ComplaintError extends Error {
  readonly code: string;
  readonly status: number;
  constructor(code: string, message: string, status = 422) {
    super(message);
    this.name = "ComplaintError";
    this.code = code;
    this.status = status;
  }
}

export class ComplaintNotFoundError extends ComplaintError {
  constructor(id: string) {
    super("NOT_FOUND", `Complaint not found: ${id}`, 404);
  }
}

export class IllegalTransitionError extends ComplaintError {
  constructor(from: string, to: string) {
    super("ILLEGAL_TRANSITION", `Cannot transition a complaint from '${from}' to '${to}'`, 422);
  }
}

export class ResolutionNoteRequiredError extends ComplaintError {
  constructor() {
    super(
      "RESOLUTION_NOTE_REQUIRED",
      "A non-empty resolution note is required to resolve a complaint",
      422,
    );
  }
}

export class IllegalAssignError extends ComplaintError {
  constructor(status: string) {
    super(
      "ILLEGAL_ASSIGN",
      `Cannot assign a complaint in status '${status}' — reopen it first`,
      422,
    );
  }
}

export class ComplaintConflictError extends ComplaintError {
  constructor(message = "This complaint was changed concurrently by someone else") {
    super("CONFLICT", message, 409);
  }
}

export class VendorNotFoundError extends ComplaintError {
  constructor(id: string) {
    super("VENDOR_NOT_FOUND", `Vendor not found in this school: ${id}`, 404);
  }
}

export interface ComplaintScope {
  organizationId: string;
  schoolId: string;
}

export interface ComplaintRow {
  id: string;
  organization_id: string;
  school_id: string;
  category: string;
  title: string;
  description: string;
  severity: string;
  status: string;
  raised_by: string;
  raised_by_role: string;
  related_student_id: string | null;
  assigned_to: string | null;
  assigned_at: string | null;
  assigned_by: string | null;
  sla_due_at: string;
  first_response_at: string | null;
  resolved_at: string | null;
  resolved_by: string | null;
  resolution_note: string | null;
  reopened_count: number;
  vendor_id: string | null;
  repair_cost: string | null;
  photo_path: string | null;
  created_at: string;
  updated_at: string;
}

export interface ComplaintEventRow {
  id: string;
  complaint_id: string;
  event_type: string;
  actor_id: string;
  actor_name: string;
  note: string | null;
  metadata: Record<string, unknown>;
  occurred_at: string;
}

const COLUMNS = `
  id, organization_id, school_id, category, title, description, severity, status,
  raised_by, raised_by_role, related_student_id, assigned_to,
  assigned_at::text AS assigned_at, assigned_by,
  sla_due_at::text AS sla_due_at, first_response_at::text AS first_response_at,
  resolved_at::text AS resolved_at, resolved_by, resolution_note, reopened_count,
  vendor_id, repair_cost::text AS repair_cost, photo_path,
  created_at::text AS created_at, updated_at::text AS updated_at
`;

// ── raise ────────────────────────────────────────────────────────────────

export interface RaiseComplaintInput {
  category: string;
  title: string;
  description: string;
  severity: string;
  raisedBy: string;
  raisedByRole: string;
  relatedStudentId?: string | null;
  photoPath?: string | null;
  slaDueAt: Date;
}

export async function raiseComplaint(
  db: TenantQueryClient,
  scope: ComplaintScope,
  input: RaiseComplaintInput,
): Promise<ComplaintRow> {
  const rows = await db.queryObject<ComplaintRow>(
    `INSERT INTO complaints (
       organization_id, school_id, category, title, description, severity, status,
       raised_by, raised_by_role, related_student_id, sla_due_at, photo_path
     ) VALUES ($1,$2,$3,$4,$5,$6,'open',$7,$8,$9,$10,$11)
     RETURNING ${COLUMNS}`,
    [
      scope.organizationId,
      scope.schoolId,
      input.category,
      input.title,
      input.description,
      input.severity,
      input.raisedBy,
      input.raisedByRole,
      input.relatedStudentId ?? null,
      input.slaDueAt.toISOString(),
      input.photoPath ?? null,
    ],
  );
  return rows[0]!;
}

// ── list / detail ───────────────────────────────────────────────────────

export interface ComplaintListFilters {
  status?: string;
  category?: string;
  severity?: string;
  assignedTo?: string;
  /** When set, restricts the list to complaints raised by this user
   * (a raiser without manage/principal visibility, or a parent). */
  raisedBy?: string;
  limit?: number;
}

export async function listComplaints(
  db: TenantQueryClient,
  scope: ComplaintScope,
  filters: ComplaintListFilters,
): Promise<ComplaintRow[]> {
  const conditions = ["organization_id = $1", "school_id = $2"];
  const args: unknown[] = [scope.organizationId, scope.schoolId];

  const push = (fragment: string, value: string) => {
    args.push(value);
    conditions.push(`${fragment} $${args.length}`);
  };
  if (filters.status) push("status =", filters.status);
  if (filters.category) push("category =", filters.category);
  if (filters.severity) push("severity =", filters.severity);
  if (filters.assignedTo) push("assigned_to =", filters.assignedTo);
  if (filters.raisedBy) push("raised_by =", filters.raisedBy);

  const limit = Math.min(200, Math.max(1, filters.limit ?? 200));
  args.push(limit);

  return await db.queryObject<ComplaintRow>(
    `SELECT ${COLUMNS} FROM complaints
      WHERE ${conditions.join(" AND ")}
      ORDER BY created_at DESC
      LIMIT $${args.length}`,
    args,
  );
}

/** Fetches one complaint scoped to org+school, optionally restricted to
 * `raisedBy` (a raiser/parent may only ever fetch their own). Throws
 * ComplaintNotFoundError both when the id truly does not exist AND when it
 * exists but is out of the caller's restricted view — a caller must never be
 * able to distinguish "not mine" from "doesn't exist" (no enumeration leak). */
export async function getComplaint(
  db: TenantQueryClient,
  scope: ComplaintScope,
  id: string,
  raisedBy?: string,
): Promise<ComplaintRow> {
  const conditions = ["organization_id = $1", "school_id = $2", "id = $3"];
  const args: unknown[] = [scope.organizationId, scope.schoolId, id];
  if (raisedBy) {
    args.push(raisedBy);
    conditions.push(`raised_by = $${args.length}`);
  }
  const rows = await db.queryObject<ComplaintRow>(
    `SELECT ${COLUMNS} FROM complaints WHERE ${conditions.join(" AND ")} LIMIT 1`,
    args,
  );
  const row = rows[0];
  if (!row) throw new ComplaintNotFoundError(id);
  return row;
}

export async function listComplaintEvents(
  db: TenantQueryClient,
  scope: ComplaintScope,
  complaintId: string,
): Promise<ComplaintEventRow[]> {
  return await db.queryObject<ComplaintEventRow>(
    `SELECT id, complaint_id, event_type, actor_id, actor_name, note, metadata,
            occurred_at::text AS occurred_at
       FROM complaint_events
      WHERE organization_id = $1 AND school_id = $2 AND complaint_id = $3
      ORDER BY occurred_at ASC`,
    [scope.organizationId, scope.schoolId, complaintId],
  );
}

// ── timeline (append-only) ─────────────────────────────────────────────

export interface RecordEventInput {
  complaintId: string;
  eventType: string;
  actorId: string;
  actorName?: string;
  note?: string | null;
  metadata?: Record<string, unknown>;
}

export async function recordEvent(
  db: TenantQueryClient,
  scope: ComplaintScope,
  input: RecordEventInput,
): Promise<ComplaintEventRow> {
  const rows = await db.queryObject<ComplaintEventRow>(
    `INSERT INTO complaint_events (
       organization_id, school_id, complaint_id, event_type, actor_id, actor_name,
       note, metadata
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8::jsonb)
     RETURNING id, complaint_id, event_type, actor_id, actor_name, note, metadata,
               occurred_at::text AS occurred_at`,
    [
      scope.organizationId,
      scope.schoolId,
      input.complaintId,
      input.eventType,
      input.actorId,
      input.actorName ?? "",
      input.note ?? null,
      JSON.stringify(input.metadata ?? {}),
    ],
  );
  return rows[0]!;
}

// ── assign ──────────────────────────────────────────────────────────────

export interface AssignComplaintInput {
  assignedTo: string;
  assignedBy: string;
}

/** Performs the open|reopened -> assigned edge plus the assignment fields in
 * one guarded write. Re-assignment while already assigned/in_progress is not
 * supported here (use /status to reopen, then re-assign). */
export async function assignComplaint(
  db: TenantQueryClient,
  scope: ComplaintScope,
  id: string,
  input: AssignComplaintInput,
): Promise<ComplaintRow> {
  const rows = await db.queryObject<ComplaintRow>(
    `UPDATE complaints
        SET assigned_to = $4, assigned_by = $5, assigned_at = timezone('utc', now()),
            status = 'assigned', updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2 AND id = $3
        AND status IN (${ASSIGNABLE_FROM.map((s) => `'${s}'`).join(", ")})
      RETURNING ${COLUMNS}`,
    [scope.organizationId, scope.schoolId, id, input.assignedTo, input.assignedBy],
  );
  const row = rows[0];
  if (row) return row;
  // Distinguish "doesn't exist" (404) from "exists but not assignable" (422) —
  // this SELECT throws ComplaintNotFoundError for us when truly missing.
  const existing = await getComplaint(db, scope, id);
  throw new IllegalAssignError(existing.status);
}

// ── status transition ──────────────────────────────────────────────────

export interface TransitionStatusInput {
  to: ComplaintStatus;
  expectedFrom: string;
  resolutionNote?: string | null;
  actorId: string;
}

/** Every branch is a guarded UPDATE (`AND status = $expectedFrom`) — a lost
 * race (someone else transitioned it between the caller's read and this
 * write) returns zero rows, and this throws ComplaintConflictError so the
 * enclosing transaction rolls back rather than silently double-applying. */
export async function transitionStatus(
  db: TenantQueryClient,
  scope: ComplaintScope,
  id: string,
  input: TransitionStatusInput,
): Promise<ComplaintRow> {
  if (!isLegalTransition(input.expectedFrom, input.to)) {
    throw new IllegalTransitionError(input.expectedFrom, input.to);
  }
  if (input.to === "resolved" && !(input.resolutionNote && input.resolutionNote.trim().length > 0)) {
    throw new ResolutionNoteRequiredError();
  }

  let rows: ComplaintRow[];
  if (input.to === "resolved") {
    rows = await db.queryObject<ComplaintRow>(
      `UPDATE complaints
          SET status = $4, resolved_at = timezone('utc', now()), resolved_by = $5,
              resolution_note = $6, updated_at = timezone('utc', now())
        WHERE organization_id = $1 AND school_id = $2 AND id = $3 AND status = $7
        RETURNING ${COLUMNS}`,
      [
        scope.organizationId,
        scope.schoolId,
        id,
        input.to,
        input.actorId,
        input.resolutionNote,
        input.expectedFrom,
      ],
    );
  } else if (input.to === "reopened") {
    rows = await db.queryObject<ComplaintRow>(
      `UPDATE complaints
          SET status = $4, reopened_count = reopened_count + 1,
              resolved_at = NULL, resolved_by = NULL, updated_at = timezone('utc', now())
        WHERE organization_id = $1 AND school_id = $2 AND id = $3 AND status = $5
        RETURNING ${COLUMNS}`,
      [scope.organizationId, scope.schoolId, id, input.to, input.expectedFrom],
    );
  } else {
    rows = await db.queryObject<ComplaintRow>(
      `UPDATE complaints
          SET status = $4, updated_at = timezone('utc', now())
        WHERE organization_id = $1 AND school_id = $2 AND id = $3 AND status = $5
        RETURNING ${COLUMNS}`,
      [scope.organizationId, scope.schoolId, id, input.to, input.expectedFrom],
    );
  }

  const row = rows[0];
  if (!row) {
    throw new ComplaintConflictError(
      `Complaint status changed concurrently — expected '${input.expectedFrom}'`,
    );
  }
  return row;
}

/** Maps a target status to the specific timeline event type when the CHECK
 * constraint defines one (resolved/closed/reopened), else the generic
 * status_changed. */
export function eventTypeForTransition(to: ComplaintStatus): string {
  if (to === "resolved" || to === "closed" || to === "reopened") return to;
  return "status_changed";
}

// ── comment / first response ───────────────────────────────────────────

/** Opportunistic, idempotent-safe marker: guarded on `first_response_at IS
 * NULL` so two concurrent staff comments can only ever have one winner —
 * losing this race is a harmless no-op (the field is already set), unlike
 * the money-integrity terminal writes above, so this does NOT throw on zero
 * rows. */
export async function markFirstResponse(
  db: TenantQueryClient,
  scope: ComplaintScope,
  id: string,
): Promise<boolean> {
  const rows = await db.queryObject<{ id: string }>(
    `UPDATE complaints
        SET first_response_at = timezone('utc', now()), updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2 AND id = $3 AND first_response_at IS NULL
      RETURNING id`,
    [scope.organizationId, scope.schoolId, id],
  );
  return rows.length > 0;
}

// ── vendor attach ───────────────────────────────────────────────────────

export interface VendorRow {
  id: string;
  display_name: string;
}

export async function findVendorInScope(
  db: TenantQueryClient,
  scope: ComplaintScope,
  vendorId: string,
): Promise<VendorRow | null> {
  const rows = await db.queryObject<VendorRow>(
    `SELECT id, display_name FROM inventory_vendors
      WHERE organization_id = $1 AND school_id = $2 AND id = $3
      LIMIT 1`,
    [scope.organizationId, scope.schoolId, vendorId],
  );
  return rows[0] ?? null;
}

export interface AttachVendorInput {
  vendorId: string;
  repairCost: number | null;
}

/** `repair_cost`/`vendor_id` are an ABSOLUTE overwrite of a nullable field
 * (not a delta like an account balance), so an unguarded last-write-wins is
 * not a money-integrity race here — mirrors the invoice (absolute) case, not
 * the account (delta) case, per this project's established distinction.
 * Still existence-guarded (404 if the complaint id is not in this scope). */
export async function attachVendor(
  db: TenantQueryClient,
  scope: ComplaintScope,
  id: string,
  input: AttachVendorInput,
): Promise<ComplaintRow> {
  const rows = await db.queryObject<ComplaintRow>(
    `UPDATE complaints
        SET vendor_id = $4, repair_cost = $5, updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2 AND id = $3
      RETURNING ${COLUMNS}`,
    [scope.organizationId, scope.schoolId, id, input.vendorId, input.repairCost],
  );
  const row = rows[0];
  if (!row) throw new ComplaintNotFoundError(id);
  return row;
}

// ── photo attach ────────────────────────────────────────────────────────

export async function attachPhoto(
  db: TenantQueryClient,
  scope: ComplaintScope,
  id: string,
  photoPath: string,
): Promise<ComplaintRow> {
  const rows = await db.queryObject<ComplaintRow>(
    `UPDATE complaints
        SET photo_path = $4, updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2 AND id = $3
      RETURNING ${COLUMNS}`,
    [scope.organizationId, scope.schoolId, id, photoPath],
  );
  const row = rows[0];
  if (!row) throw new ComplaintNotFoundError(id);
  return row;
}
