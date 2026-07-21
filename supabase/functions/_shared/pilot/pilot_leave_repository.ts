import type { TenantQueryClient } from "../tenant_db.ts";

export async function listGuardianUserIdsForStudent(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
): Promise<string[]> {
  const rows = await db.queryObject<{ guardian_user_id: string }>(
    `SELECT guardian_user_id FROM student_guardians
     WHERE organization_id = $1 AND school_id = $2 AND student_id = $3 AND status = 'active'`,
    [orgId, schoolId, studentId],
  );
  return rows.map((row) => row.guardian_user_id);
}

export async function createLeaveRequest(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    requesterUserId: string;
    requesterScope: "parent" | "teacher";
    studentId: string | null;
    typeLabel: string;
    fromDateLabel: string;
    toDateLabel: string;
    // ATT-D3 Part B — optional machine-readable ISO (YYYY-MM-DD) bounds. When
    // provided on a leave that is later APPROVED, they let the auto-excuse fire.
    // Omitted → legacy label-only leave (never auto-excuses).
    fromDate?: string | null;
    toDate?: string | null;
    reason: string;
    hasAttachment?: boolean;
    attachmentName?: string | null;
  },
): Promise<Record<string, unknown>> {
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO mobile_leave_requests (
       organization_id, school_id, requester_user_id, requester_scope,
       student_id, type_label, from_date_label, to_date_label, reason,
       has_attachment, attachment_name, from_date, to_date
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12::date,$13::date)
     RETURNING id`,
    [
      input.organizationId,
      input.schoolId,
      input.requesterUserId,
      input.requesterScope,
      input.studentId,
      input.typeLabel,
      input.fromDateLabel,
      input.toDateLabel,
      input.reason,
      input.hasAttachment ?? false,
      input.attachmentName ?? null,
      input.fromDate ?? null,
      input.toDate ?? null,
    ],
  );
  const id = rows[0]!.id;
  return leaveToApi(id, input);
}

function leaveToApi(id: string, input: {
  typeLabel: string;
  fromDateLabel: string;
  toDateLabel: string;
  reason: string;
  hasAttachment?: boolean;
  attachmentName?: string | null;
  requesterScope: "parent" | "teacher";
}): Record<string, unknown> {
  return {
    id,
    childName: input.requesterScope === "parent" ? "Linked child" : "",
    childClass: input.requesterScope === "parent" ? "8-A" : "",
    type: input.typeLabel,
    typeLabel: input.typeLabel,
    fromDateLabel: input.fromDateLabel,
    toDateLabel: input.toDateLabel,
    reason: input.reason,
    status: "pending",
    submittedLabel: "Just now",
    timeline: [{ label: "Submitted", timeLabel: "Just now", isComplete: true }],
    hasAttachment: input.hasAttachment ?? false,
    attachmentName: input.attachmentName ?? null,
  };
}

/**
 * MJ-H12 — list a parent's leave applications for GET /parent/leave.
 *
 * POST /parent/leave persists into `mobile_leave_requests` (the canonical store
 * the school/HR approval + intelligence side reads). The parent's leave history
 * screen, however, read the `parent_entities` "leave_request" cache, so a parent
 * never saw the leave they just submitted. This reads the real rows back for the
 * resolved child, mapped to the same shape `leaveToApi` returns so the existing
 * parent_mapper.toLeaveRequest parser consumes it unchanged. Paginated in-memory
 * (a parent has few leave rows). Newest first.
 */
export async function listParentLeaveRequests(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  pagination: { page: number; pageSize: number },
): Promise<{
  items: Array<Record<string, unknown>>;
  page: number;
  pageSize: number;
  total: number;
  hasMore: boolean;
}> {
  const rows = await db.queryObject<{
    id: string;
    type_label: string;
    from_date_label: string;
    to_date_label: string;
    reason: string;
    status: string;
    has_attachment: boolean;
    attachment_name: string | null;
    submitted_label: string;
  }>(
    `SELECT id, type_label, from_date_label, to_date_label, reason, status,
            has_attachment, attachment_name,
            to_char(created_at, 'DD Mon YYYY') AS submitted_label
       FROM mobile_leave_requests
      WHERE organization_id = $1 AND school_id = $2 AND student_id = $3::uuid
      ORDER BY created_at DESC`,
    [organizationId, schoolId, studentId],
  );
  const all = rows.map((r) => ({
    id: r.id,
    // Convention mirrors leaveToApi (the POST response): this list is already
    // scoped to the active child, so a placeholder label is honest, not faked
    // identity. The parent app shows the child from its own active-child context.
    childName: "Linked child",
    childClass: "",
    type: r.type_label,
    typeLabel: r.type_label,
    fromDateLabel: r.from_date_label,
    toDateLabel: r.to_date_label,
    reason: r.reason,
    status: r.status,
    submittedLabel: r.submitted_label,
    timeline: [{ label: "Submitted", timeLabel: r.submitted_label, isComplete: true }],
    hasAttachment: r.has_attachment,
    attachmentName: r.attachment_name,
  }));
  const total = all.length;
  const start = Math.max(0, (pagination.page - 1) * pagination.pageSize);
  const items = all.slice(start, start + pagination.pageSize);
  return {
    items,
    page: pagination.page,
    pageSize: pagination.pageSize,
    total,
    hasMore: start + items.length < total,
  };
}

// ── PAR-D1 / PAR-3 — parent leave mutations (cancel + attachment) ────────────

/**
 * PAR-D1 — a leave the parent tried to cancel does not exist for them, or is no
 * longer pending. Both surface distinctly to the handler: NOT_FOUND (the id is
 * not one of this parent's own-child pending leaves) vs a non-pending status
 * (already decided → immutable, mirroring the leave-decision-immutability rule).
 */
export class ParentLeaveNotFoundError extends Error {
  constructor(leaveId: string) {
    super(`Leave request not found: ${leaveId}`);
    this.name = "ParentLeaveNotFoundError";
  }
}

/** PAR-D1 — the leave exists but is already approved/rejected/cancelled. */
export class ParentLeaveNotPendingError extends Error {
  readonly status: string;
  constructor(status: string) {
    super(
      `Leave request is '${status}' and can no longer be cancelled — only a pending request may be withdrawn`,
    );
    this.name = "ParentLeaveNotPendingError";
    this.status = status;
  }
}

/**
 * Load a leave request that MUST belong to this parent and one of their own
 * children. Ownership is enforced two ways (defence in depth):
 *   1. `requester_user_id = requesterUserId` — the RLS parent policy already
 *      restricts a parent to leaves they themselves submitted, but we re-assert
 *      it here so the guard holds even under a service-role/test client.
 *   2. `student_id = ANY(childIds)` — the caller's JWT `child_ids` (the own-child
 *      choke point). A leave for a child no longer linked to this parent is
 *      treated as not-found, never mutated.
 * Returns null when no such row exists (→ NOT_FOUND, no cross-family leak).
 */
async function loadOwnChildLeave(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  requesterUserId: string,
  childIds: string[],
  leaveId: string,
): Promise<{ id: string; student_id: string | null; status: string } | null> {
  if (childIds.length === 0) return null;
  const rows = await db.queryObject<
    { id: string; student_id: string | null; status: string }
  >(
    `SELECT id, student_id, status
       FROM mobile_leave_requests
      WHERE organization_id = $1 AND school_id = $2
        AND id = $3::uuid
        AND requester_scope = 'parent'
        AND requester_user_id = $4::uuid
        AND student_id = ANY($5::uuid[])
      LIMIT 1`,
    [organizationId, schoolId, leaveId, requesterUserId, childIds],
  );
  return rows[0] ?? null;
}

/**
 * PAR-D1 — withdraw a PENDING leave the parent submitted for their own child.
 * Own-child scoped (see {@link loadOwnChildLeave}) and pending-only: an already
 * approved/rejected/cancelled request is immutable (→ 409), mirroring the
 * leave-decision-immutability rule. Flips status to 'cancelled' and returns the
 * canonical row so the parent's leave history (GET /parent/leave) reflects it.
 */
export async function cancelParentLeaveRequest(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    requesterUserId: string;
    childIds: string[];
    leaveId: string;
  },
): Promise<{ id: string; studentId: string | null; status: string }> {
  const existing = await loadOwnChildLeave(
    db,
    input.organizationId,
    input.schoolId,
    input.requesterUserId,
    input.childIds,
    input.leaveId,
  );
  if (!existing) {
    throw new ParentLeaveNotFoundError(input.leaveId);
  }
  if (existing.status !== "pending") {
    throw new ParentLeaveNotPendingError(existing.status);
  }
  // Conditional UPDATE (WHERE status = 'pending') closes the race with a
  // concurrent school-side approval: if the row was decided between the load and
  // the write, no row is returned and we treat it as no-longer-pending (409).
  const rows = await db.queryObject<{ id: string; student_id: string | null }>(
    `UPDATE mobile_leave_requests
        SET status = 'cancelled', updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2
        AND id = $3::uuid
        AND requester_user_id = $4::uuid
        AND status = 'pending'
      RETURNING id, student_id`,
    [input.organizationId, input.schoolId, input.leaveId, input.requesterUserId],
  );
  const updated = rows[0];
  if (!updated) {
    // Lost the race — the row was decided concurrently; still immutable.
    throw new ParentLeaveNotPendingError("approved");
  }
  return { id: updated.id, studentId: updated.student_id, status: "cancelled" };
}

/**
 * PAR-3 — attach a medical certificate reference to a leave the parent submitted
 * for their own child. Own-child scoped (see {@link loadOwnChildLeave}). Follows
 * the HWK-7 "attachment reference, real upload pending storage" pattern: the
 * reference (storage path / file name) is persisted on the existing
 * `has_attachment` + `attachment_name` columns so GET /parent/leave surfaces it;
 * wiring a real parent-leave storage bucket is the residual. Allowed while the
 * leave is still pending — an already-decided leave is immutable (→ 409), the
 * same rule as cancel. A parent can NEVER attach to another child's leave.
 */
export async function attachParentLeaveDocument(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    requesterUserId: string;
    childIds: string[];
    leaveId: string;
    attachmentName: string;
    storagePath: string | null;
  },
): Promise<{ id: string; studentId: string | null; attachmentName: string }> {
  const existing = await loadOwnChildLeave(
    db,
    input.organizationId,
    input.schoolId,
    input.requesterUserId,
    input.childIds,
    input.leaveId,
  );
  if (!existing) {
    throw new ParentLeaveNotFoundError(input.leaveId);
  }
  if (existing.status !== "pending") {
    throw new ParentLeaveNotPendingError(existing.status);
  }
  const rows = await db.queryObject<{ id: string; student_id: string | null }>(
    `UPDATE mobile_leave_requests
        SET has_attachment = true,
            attachment_name = $5,
            updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2
        AND id = $3::uuid
        AND requester_user_id = $4::uuid
        AND status = 'pending'
      RETURNING id, student_id`,
    [
      input.organizationId,
      input.schoolId,
      input.leaveId,
      input.requesterUserId,
      input.attachmentName,
    ],
  );
  const updated = rows[0];
  if (!updated) {
    throw new ParentLeaveNotPendingError("approved");
  }
  return {
    id: updated.id,
    studentId: updated.student_id,
    attachmentName: input.attachmentName,
  };
}

// --- TEACH-1: leave history (GET /teacher/leave) ---
//
// The teacher's own leave applications from mobile_leave_requests (the canonical
// store the HR/approval side reads). Scoped to requester_user_id = teacher and
// requester_scope = 'teacher'. Same shape the leave_request seed used. Empty
// => []. Newest first.
export async function listTeacherLeaveRequests(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  teacherUserId: string,
  pagination: { page: number; pageSize: number },
): Promise<{
  items: Array<Record<string, unknown>>;
  page: number;
  pageSize: number;
  total: number;
  hasMore: boolean;
}> {
  const rows = await db.queryObject<{
    id: string;
    type_label: string;
    from_date_label: string;
    to_date_label: string;
    reason: string;
    status: string;
    submitted_label: string;
  }>(
    `SELECT id, type_label, from_date_label, to_date_label, reason, status,
            to_char(created_at, 'DD Mon YYYY') AS submitted_label
       FROM mobile_leave_requests
      WHERE organization_id = $1 AND school_id = $2
        AND requester_user_id = $3::uuid AND requester_scope = 'teacher'
      ORDER BY created_at DESC`,
    [orgId, schoolId, teacherUserId],
  );

  const all = rows.map((r) => ({
    id: r.id,
    type: r.type_label,
    typeLabel: r.type_label,
    fromDateLabel: r.from_date_label,
    toDateLabel: r.to_date_label,
    reason: r.reason,
    status: r.status,
    submittedLabel: r.submitted_label,
    timeline: [
      { label: "Submitted", dateLabel: r.submitted_label, isComplete: true },
      {
        label: r.status === "rejected" ? "Rejected" : "Approved",
        dateLabel: "",
        isComplete: r.status === "approved" || r.status === "rejected",
      },
    ],
  }));
  const total = all.length;
  const start = Math.max(0, (pagination.page - 1) * pagination.pageSize);
  const items = all.slice(start, start + pagination.pageSize);
  return {
    items,
    page: pagination.page,
    pageSize: pagination.pageSize,
    total,
    hasMore: start + items.length < total,
  };
}
