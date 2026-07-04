import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, MAX_BULK_ITEMS, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { correlationIdFromRequest, recordMutationAudit } from "../audit/audit_repository.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import { enqueueNotificationRequested } from "../communication/notification_service.ts";
import {
  createLeaveRequest,
  cancelParentLeaveRequest,
  attachParentLeaveDocument,
  insertHomeworkAssignment,
  reviewHomework,
  bulkReviewHomework,
  submitHomework,
  listHomeworkNonSubmitters,
  notifyHomeworkNonSubmitters,
  listTeacherHomeworkHistory,
  updateExamMark,
  listTimetableSlots,
  listGuardianUserIdsForStudent,
  upsertAttendanceSession,
  validateDueDate,
  dueDateToLabel,
  isDueDateInPast,
  AttendanceLockedError,
  AttendanceClosedDayError,
  AttendanceRosterMismatchError,
  HomeworkNotDeliveredError,
  HomeworkAlreadySubmittedError,
  ParentLeaveNotFoundError,
  ParentLeaveNotPendingError,
  type AttendanceMarkEntry,
} from "./pilot_operations_repository.ts";

function parseAttendanceEntries(body: Record<string, unknown>): AttendanceMarkEntry[] {
  const entries = body.entries as Array<Record<string, unknown>> | undefined;
  if (!entries) return [];
  return entries.map((entry) => ({
    studentId: String(entry.student_id ?? entry.studentId ?? ""),
    mark: String(entry.mark ?? "present"),
  }));
}

function snakeStr(body: Record<string, unknown>, key: string): string {
  return String(body[key] ?? "");
}

/**
 * HWK-3 — resolve the target class-sections from a create body. Accepts a
 * `class_labels`/`classLabels` array (multi-section assign) OR a single
 * `class_label`/`classLabel` (back-compat). Trims, drops blanks and de-dupes so
 * one class is never fanned out twice. Exported pure so the fan-out targeting is
 * unit-testable without a database.
 */
export function parseHomeworkClassLabels(
  body: Record<string, unknown>,
): string[] {
  const rawLabels = body.class_labels ?? body.classLabels;
  const singleLabel = String(body.class_label ?? body.classLabel ?? "").trim();
  const candidates = Array.isArray(rawLabels)
    ? rawLabels.map((v) => String(v).trim())
    : singleLabel
    ? [singleLabel]
    : [];
  return Array.from(new Set(candidates.filter((v) => v.length > 0)));
}

// ATT-D3 — read an optional ISO date (YYYY-MM-DD) from the body. Returns null
// when absent or not a plausible ISO date, so a malformed value degrades to a
// legacy label-only leave rather than a bad INSERT.
function optionalIsoDate(body: Record<string, unknown>, key: string): string | null {
  const raw = body[key];
  if (raw == null) return null;
  const value = String(raw).trim();
  return /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : null;
}

async function auditMobileWrite(
  db: Parameters<typeof recordMutationAudit>[0],
  claims: Parameters<typeof recordMutationAudit>[1],
  req: Request,
  eventType: string,
  entityType: string,
  entityId: string,
  metadata: Record<string, unknown>,
): Promise<void> {
  await recordMutationAudit(
    db,
    claims,
    {
      eventType,
      category: "workflow",
      entityType,
      entityId,
      metadata,
      correlationId: correlationIdFromRequest(req),
    },
    {
      eventType: `${entityType}.${eventType}`,
      payload: metadata,
      sourceModule: "pilot",
      idempotencyKey: `${entityType}:${entityId}:${Date.now()}`,
    },
    req,
  );
}

/** Map attendance integrity failures to precise HTTP responses (gates #1/#5/#6/#7/#8). */
function mapAttendanceError(error: unknown): Response | null {
  if (error instanceof AttendanceLockedError) {
    return errorEnvelope("ATTENDANCE_LOCKED", error.message, 409);
  }
  if (error instanceof AttendanceClosedDayError) {
    return errorEnvelope("ATTENDANCE_DAY_CLOSED", error.message, 422);
  }
  if (error instanceof AttendanceRosterMismatchError) {
    return errorEnvelope("ATTENDANCE_ROSTER_MISMATCH", error.message, 422);
  }
  return null;
}

export async function handleTeacherAttendanceDraft(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "school" || !auth.claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Teacher scope required", 403);
  }
  // MJ-M10/ATTEN-3: marking attendance is a teaching action — gate on the
  // granular permission so non-teaching school staff cannot mark/overwrite.
  const denied = requirePermission(auth.claims, "markAttendance");
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON", 422);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const entries = parseAttendanceEntries(body);
      const saved = await upsertAttendanceSession(db, {
        organizationId: auth.claims.tenant_id,
        schoolId: auth.claims.school_id!,
        classId: snakeStr(body, "class_id"),
        classLabel: snakeStr(body, "class_id"),
        takenBy: auth.claims.sub,
        status: "draft",
        entries,
        periodLabel: snakeStr(body, "period_label"),
      });
      await auditMobileWrite(db, auth.claims, req, "attendanceDraftSaved", "attendance_session", saved.sessionId, {
        classId: snakeStr(body, "class_id"),
        markedCount: entries.length,
      });
      return saved;
    });
    return jsonResponse(envelope({
      classId: snakeStr(body, "class_id"),
      savedAtLabel: "Just now",
      markedCount: parseAttendanceEntries(body).length,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const mapped = mapAttendanceError(error);
    if (mapped) return mapped;
    return errorEnvelope("INTERNAL_ERROR", "Failed to save attendance draft", 500);
  }
}

export async function handleTeacherAttendanceSubmit(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "school" || !auth.claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Teacher scope required", 403);
  }
  // MJ-M10/ATTEN-3: submitting attendance (which fires guardian absence alerts)
  // requires the markAttendance permission, not just school scope.
  const denied = requirePermission(auth.claims, "markAttendance");
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON", 422);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const entries = parseAttendanceEntries(body);
      const saved = await upsertAttendanceSession(db, {
        organizationId: auth.claims.tenant_id,
        schoolId: auth.claims.school_id!,
        classId: snakeStr(body, "class_id"),
        classLabel: snakeStr(body, "class_id"),
        takenBy: auth.claims.sub,
        status: "submitted",
        entries,
        periodLabel: snakeStr(body, "period_label"),
      });
      await auditMobileWrite(db, auth.claims, req, "attendanceSubmitted", "attendance_session", saved.sessionId, {
        classId: snakeStr(body, "class_id"),
        ...saved.counts,
      });
      for (const entry of entries.filter((e) => e.mark === "absent")) {
        const guardians = await listGuardianUserIdsForStudent(
          db,
          auth.claims.tenant_id,
          auth.claims.school_id!,
          entry.studentId,
        );
        for (const guardianUserId of guardians) {
          await enqueueNotificationRequested(
            db,
            auth.claims.tenant_id,
            auth.claims.school_id!,
            guardianUserId,
            "Attendance alert",
            `Student marked absent for class ${snakeStr(body, "class_id")}`,
            "attendance",
          );
        }
      }
      return saved;
    });
    return jsonResponse(envelope({
      classId: snakeStr(body, "class_id"),
      submittedAtLabel: "Just now",
      presentCount: result.counts.present,
      absentCount: result.counts.absent,
      lateCount: result.counts.late,
      // ATT-D3 — additive; existing clients ignore these extra fields.
      excusedCount: result.counts.excused,
      halfDayCount: result.counts.halfDay,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const mapped = mapAttendanceError(error);
    if (mapped) return mapped;
    return errorEnvelope("INTERNAL_ERROR", "Failed to submit attendance", 500);
  }
}

export async function handleTeacherLeaveSubmit(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "school" || !auth.claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Teacher scope required", 403);
  }
  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON", 422);

  try {
    const leave = await withTenantContext(config, auth.claims, async (db) => {
      const row = await createLeaveRequest(db, {
        organizationId: auth.claims.tenant_id,
        schoolId: auth.claims.school_id!,
        requesterUserId: auth.claims.sub,
        requesterScope: "teacher",
        studentId: null,
        typeLabel: snakeStr(body, "type_label"),
        fromDateLabel: snakeStr(body, "from_date_label"),
        toDateLabel: snakeStr(body, "to_date_label"),
        fromDate: optionalIsoDate(body, "from_date"),
        toDate: optionalIsoDate(body, "to_date"),
        reason: snakeStr(body, "reason"),
      });
      await auditMobileWrite(db, auth.claims, req, "leaveSubmitted", "mobile_leave_request", String(row.id), row);
      return row;
    });
    return jsonResponse(envelope(leave), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to submit leave", 500);
  }
}

export async function handleParentLeaveSubmit(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "parent" || !auth.claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Parent scope required", 403);
  }
  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON", 422);

  const childId = snakeStr(body, "child_id");
  if (!auth.claims.child_ids.includes(childId)) {
    return errorEnvelope("FORBIDDEN", "Child not linked to parent account", 403);
  }

  try {
    const leave = await withTenantContext(config, auth.claims, async (db) => {
      const row = await createLeaveRequest(db, {
        organizationId: auth.claims.tenant_id,
        schoolId: auth.claims.school_id!,
        requesterUserId: auth.claims.sub,
        requesterScope: "parent",
        studentId: childId,
        typeLabel: snakeStr(body, "type"),
        fromDateLabel: snakeStr(body, "from_date_label"),
        toDateLabel: snakeStr(body, "to_date_label"),
        fromDate: optionalIsoDate(body, "from_date"),
        toDate: optionalIsoDate(body, "to_date"),
        reason: snakeStr(body, "reason"),
        hasAttachment: Boolean(body.has_attachment),
        attachmentName: body.attachment_name ? String(body.attachment_name) : null,
      });
      await auditMobileWrite(db, auth.claims, req, "leaveSubmitted", "mobile_leave_request", String(row.id), row);
      return row;
    });
    return jsonResponse(envelope(leave), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to submit leave", 500);
  }
}

/**
 * Map the shared parent-leave mutation errors to precise HTTP responses:
 *   - not found / not one of the caller's own-child leaves → 404 (no cross-family
 *     leak — we never confirm the id belongs to another parent);
 *   - already decided (approved/rejected/cancelled) → 409 (immutable, mirroring
 *     the leave-decision-immutability rule).
 * Returns null when the error is not a parent-leave guard error.
 */
function mapParentLeaveError(error: unknown): Response | null {
  if (error instanceof ParentLeaveNotFoundError) {
    return errorEnvelope("NOT_FOUND", error.message, 404);
  }
  if (error instanceof ParentLeaveNotPendingError) {
    return errorEnvelope("LEAVE_NOT_PENDING", error.message, 409);
  }
  return null;
}

/**
 * PAR-D1 — POST /parent/leave/:id/cancel
 *
 * A parent withdraws a PENDING leave they submitted for their OWN child (owner
 * default: cancel is allowed before approval). Own-child scoping is enforced in
 * the repository against the caller's JWT `child_ids` AND `requester_user_id`
 * (never a client-supplied student id); pending-only immutability rejects an
 * already-decided request with 409. Audited as `parent.leave.cancelled`.
 */
export async function handleParentLeaveCancel(
  req: Request,
  config: AppConfig,
  leaveId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "parent" || !auth.claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Parent scope required", 403);
  }

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const cancelled = await cancelParentLeaveRequest(db, {
        organizationId: auth.claims.tenant_id,
        schoolId: auth.claims.school_id!,
        requesterUserId: auth.claims.sub,
        childIds: auth.claims.child_ids,
        leaveId,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("parent.leave.cancelled", "mobile_leave_request", cancelled.id, {
          studentId: cancelled.studentId,
          status: cancelled.status,
        }),
        req,
      );
      return cancelled;
    });
    return jsonResponse(
      envelope({ id: result.id, status: result.status }),
      { status: 200 },
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const mapped = mapParentLeaveError(error);
    if (mapped) return mapped;
    return errorEnvelope("INTERNAL_ERROR", "Failed to cancel leave", 500);
  }
}

/**
 * PAR-3 — POST /parent/leave/:id/attachment
 *
 * A parent attaches a medical-certificate reference to a PENDING leave they
 * submitted for their OWN child. Own-child scoped + pending-only (same guards as
 * cancel). Following the established HWK-7 "attachment reference, real upload
 * pending storage" pattern, the attachment reference (storage path / file name)
 * is persisted on the leave's existing `has_attachment` + `attachment_name`
 * columns so GET /parent/leave surfaces it; wiring a real parent-leave storage
 * bucket is the documented residual. Audited as `parent.leave.attachment.added`.
 * A parent can NEVER attach to another child's leave.
 */
export async function handleParentLeaveAttachment(
  req: Request,
  config: AppConfig,
  leaveId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "parent" || !auth.claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Parent scope required", 403);
  }
  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON", 422);

  // The attachment reference: a human file name / label (required) and an
  // optional storage path (the presigned object path, once real upload is
  // wired). The reference is never a client-supplied student id — the child is
  // resolved server-side from the leave row itself.
  const attachmentName =
    String(body.attachment_name ?? body.attachmentName ?? body.file_name ?? "").trim();
  if (!attachmentName) {
    return errorEnvelope("VALIDATION_ERROR", "attachment_name is required", 422);
  }
  const storagePath =
    String(body.storage_path ?? body.storagePath ?? "").trim() || null;

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const attached = await attachParentLeaveDocument(db, {
        organizationId: auth.claims.tenant_id,
        schoolId: auth.claims.school_id!,
        requesterUserId: auth.claims.sub,
        childIds: auth.claims.child_ids,
        leaveId,
        attachmentName,
        storagePath,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("parent.leave.attachment.added", "mobile_leave_request", attached.id, {
          studentId: attached.studentId,
          attachmentName: attached.attachmentName,
        }),
        req,
      );
      return attached;
    });
    return jsonResponse(
      envelope({
        id: result.id,
        hasAttachment: true,
        attachmentName: result.attachmentName,
      }),
      { status: 200 },
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const mapped = mapParentLeaveError(error);
    if (mapped) return mapped;
    return errorEnvelope("INTERNAL_ERROR", "Failed to attach leave document", 500);
  }
}

export async function handleStudentHomeworkSubmit(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "student" || !auth.claims.school_id || !auth.claims.student_id) {
    return errorEnvelope("FORBIDDEN", "Student scope required", 403);
  }
  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON", 422);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const row = await submitHomework(db, {
        organizationId: auth.claims.tenant_id,
        schoolId: auth.claims.school_id!,
        studentId: auth.claims.student_id!,
        homeworkId: snakeStr(body, "homework_id"),
        notes: snakeStr(body, "notes"),
        attachmentLabel: body.attachment_label ? String(body.attachment_label) : null,
      });
      await auditMobileWrite(db, auth.claims, req, "homeworkSubmitted", "homework_submission", snakeStr(body, "homework_id"), row);
      return row;
    });
    return jsonResponse(envelope(result), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    // Cross-class scope: assignment was not delivered to this student → 404 (do
    // not confirm the id exists for another class).
    if (error instanceof HomeworkNotDeliveredError) {
      return errorEnvelope("HOMEWORK_NOT_DELIVERED", error.message, 404);
    }
    // Idempotency: a second submission of the same assignment → 409, not 500.
    if (error instanceof HomeworkAlreadySubmittedError) {
      return errorEnvelope("HOMEWORK_ALREADY_SUBMITTED", error.message, 409);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to submit homework", 500);
  }
}

export async function handleTeacherHomeworkReview(
  req: Request,
  config: AppConfig,
  submissionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "school" || !auth.claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Teacher scope required", 403);
  }
  // MJ-M10/TEACH-4: grading a submission requires the manageHomework permission.
  const denied = requirePermission(auth.claims, "manageHomework");
  if (denied) return denied;
  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON", 422);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const row = await reviewHomework(
        db,
        auth.claims.tenant_id,
        auth.claims.school_id!,
        submissionId,
        {
          grade: snakeStr(body, "grade"),
          comment: snakeStr(body, "comment"),
          reviewerId: auth.claims.sub,
        },
      );
      await auditMobileWrite(db, auth.claims, req, "homeworkReviewed", "homework_submission", submissionId, {
        grade: snakeStr(body, "grade"),
      });
      return row;
    });
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to review homework", 500);
  }
}

export async function handleTeacherHomeworkCreate(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "school" || !auth.claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Teacher scope required", 403);
  }
  // MJ-M10/TEACH-4: creating homework requires the manageHomework permission.
  const denied = requirePermission(auth.claims, "manageHomework");
  if (denied) return denied;
  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON", 422);

  // HWK-3 — multi-section assign. The teacher may target several class-sections
  // in ONE action: `class_labels` is a de-duped array; a single `class_label`
  // stays supported (back-compat). Each targeted class gets its OWN assignment
  // delivery (one homework_assignment + one homework_item fan-out per class), so
  // per-class submission tracking (HWK-2/5/6) stays clean.
  const classLabels = parseHomeworkClassLabels(body);
  const subject = String(body.subject ?? "").trim();
  const title = String(body.title ?? "").trim();
  if (classLabels.length === 0 || !subject || !title) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "class_label(s), subject and title are required",
      422,
    );
  }

  // HWK-1 — a real due date replaces the free-text label on the pilot path. It
  // is REQUIRED and must be a valid calendar date (YYYY-MM-DD); a blank or
  // unparseable value is a 422. A past due date is allowed (warn-not-block): we
  // flag it in the response (`dueDateInPast`) but still create the homework.
  const dueDateRaw = body.due_date ?? body.dueDate;
  const dueDate = validateDueDate(dueDateRaw);
  if (!dueDate) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "due_date is required and must be a valid date (YYYY-MM-DD)",
      422,
    );
  }
  // Prefer an explicit label if the client sent one; otherwise derive a human
  // "Due 08 Jun" label from the real date so existing renderers still work.
  const explicitLabel = String(body.due_label ?? body.dueLabel ?? "").trim();
  const dueLabel = explicitLabel.length > 0 ? explicitLabel : dueDateToLabel(dueDate);
  const dueDateInPast = isDueDateInPast(dueDate);
  const studentNameRaw = String(body.student_name ?? body.studentName ?? "").trim();
  const studentName = studentNameRaw.length > 0 ? studentNameRaw : null;
  // HWK-4 — optional teacher attachment (reference/label, not a real file
  // upload; no homework bucket exists yet). Both keys are optional and degrade
  // to null when absent.
  const attachmentName =
    String(body.attachment_name ?? body.attachmentName ?? "").trim() || null;
  const attachmentRef =
    String(body.attachment_ref ?? body.attachmentRef ?? "").trim() || null;

  try {
    const created = await withTenantContext(config, auth.claims, async (db) => {
      const perClass: Array<
        { id: string; classLabel: string; deliveredCount: number }
      > = [];
      // One assignment delivery per targeted class (each with its own id).
      for (const classLabel of classLabels) {
        const homeworkId = `hw_${crypto.randomUUID()}`;
        const one = await insertHomeworkAssignment(db, {
          organizationId: auth.claims.tenant_id,
          schoolId: auth.claims.school_id!,
          teacherId: auth.claims.sub,
          homeworkId,
          classLabel,
          subject,
          title,
          dueLabel,
          dueDate,
          studentName,
          attachmentName,
          attachmentRef,
        });
        await auditMobileWrite(
          db,
          auth.claims,
          req,
          "homeworkCreated",
          "homework_assignment",
          one.id,
          { classLabel, subject, dueDate, deliveredCount: one.deliveredCount },
        );
        perClass.push({
          id: one.id,
          classLabel,
          deliveredCount: one.deliveredCount,
        });
      }
      return perClass;
    });

    const totalDelivered = created.reduce((sum, c) => sum + c.deliveredCount, 0);
    // Back-compat: the single-class response keeps its flat {id, classLabel,
    // deliveredCount} shape (existing client mapper reads these). The per-class
    // breakdown rides `classes` for the multi-section create UI.
    const first = created[0]!;
    return jsonResponse(
      envelope({
        id: first.id,
        title,
        classLabel: first.classLabel,
        subject,
        dueLabel,
        dueDate,
        dueDateInPast,
        attachmentName,
        attachmentRef,
        deliveredCount: first.deliveredCount,
        classes: created,
        totalDeliveredCount: totalDelivered,
      }),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to create homework", 500);
  }
}

// HWK-2 — GET /teacher/homework/{homeworkId}/non-submitters
//
// The delivered roster (student_entities homework_item for this homework_id)
// LEFT JOIN homework_submissions → students who have NOT submitted. Powers the
// teacher review screen's "Not submitted (N)" tab. School/teacher scope +
// manageHomework (same gate as create/review). RLS scopes rows to the school.
export async function handleTeacherHomeworkNonSubmitters(
  req: Request,
  config: AppConfig,
  homeworkId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "school" || !auth.claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Teacher scope required", 403);
  }
  const denied = requirePermission(auth.claims, "manageHomework");
  if (denied) return denied;

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      await listHomeworkNonSubmitters(
        db,
        auth.claims.tenant_id,
        auth.claims.school_id!,
        homeworkId,
      )
    );
    return jsonResponse(
      envelope({
        homeworkId,
        notSubmittedCount: items.length,
        items: items.map((i) => ({ studentId: i.studentId, name: i.name })),
      }),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to load non-submitters", 500);
  }
}

// HWK-5 — GET /teacher/homework/history?from=YYYY-MM-DD&to=YYYY-MM-DD
//
// The teacher's own homework assignments with real submitted/total counts,
// optionally filtered to an inclusive due-date range. The CSV export is built
// client-side from these rows via the shared export service. School/teacher
// scope + manageHomework. Paginated.
export async function handleTeacherHomeworkHistory(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "school" || !auth.claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Teacher scope required", 403);
  }
  const denied = requirePermission(auth.claims, "manageHomework");
  if (denied) return denied;

  const url = new URL(req.url);
  const fromDate = optionalIsoDate(
    { from: url.searchParams.get("from") ?? undefined },
    "from",
  );
  const toDate = optionalIsoDate(
    { to: url.searchParams.get("to") ?? undefined },
    "to",
  );
  const page = Math.max(1, parseInt(url.searchParams.get("page") ?? "1", 10) || 1);
  const pageSize = Math.min(
    200,
    Math.max(1, parseInt(url.searchParams.get("pageSize") ?? "50", 10) || 50),
  );

  try {
    const result = await withTenantContext(config, auth.claims, async (db) =>
      await listTeacherHomeworkHistory(
        db,
        auth.claims.tenant_id,
        auth.claims.school_id!,
        auth.claims.sub,
        { fromDate, toDate },
        { page, pageSize },
      )
    );
    return jsonResponse(
      envelope({
        items: result.items,
        pagination: {
          page: result.page,
          pageSize: result.pageSize,
          total: result.total,
          hasMore: result.hasMore,
        },
      }),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to load homework history", 500);
  }
}

// HWK-6 — POST /teacher/homework/bulk-review
//
// Mark many submissions reviewed in one action. Body: { homework_id, grade,
// comment, submission_ids?[] }. An empty/omitted submission_ids means "all
// still-pending submissions for this homework_id". Reuses reviewHomework per
// row (same student_entities write-back), returning a partial-success summary.
export async function handleTeacherHomeworkBulkReview(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "school" || !auth.claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Teacher scope required", 403);
  }
  const denied = requirePermission(auth.claims, "manageHomework");
  if (denied) return denied;
  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON", 422);

  const homeworkId = snakeStr(body, "homework_id") || snakeStr(body, "homeworkId");
  const rawIds = body.submission_ids ?? body.submissionIds;
  const submissionIds = Array.isArray(rawIds)
    ? rawIds.map((v) => String(v)).filter((v) => v.trim().length > 0)
    : [];
  if (!homeworkId && submissionIds.length === 0) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "homework_id or submission_ids is required",
      422,
    );
  }
  // ENG-8 (SEC-11): cap the bulk array before any per-row DB work.
  if (submissionIds.length > MAX_BULK_ITEMS) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `Maximum ${MAX_BULK_ITEMS} submission_ids per request`,
      422,
    );
  }
  const grade = snakeStr(body, "grade");
  const comment = snakeStr(body, "comment");

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const summary = await bulkReviewHomework(
        db,
        auth.claims.tenant_id,
        auth.claims.school_id!,
        { homeworkId, submissionIds, grade, comment, reviewerId: auth.claims.sub },
      );
      await auditMobileWrite(
        db,
        auth.claims,
        req,
        "homeworkBulkReviewed",
        "homework_assignment",
        homeworkId || "bulk",
        { reviewed: summary.reviewed, skipped: summary.skipped, grade },
      );
      return summary;
    });
    return jsonResponse(
      envelope({
        homeworkId,
        reviewed: result.reviewed,
        skipped: result.skipped,
        reviewedIds: result.reviewedIds,
      }),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to bulk-review homework", 500);
  }
}

// HWK-D1 — POST /teacher/homework/{homeworkId}/notify-non-submitters
//
// The MANUAL teacher-triggered no-submit nudge (opt-in). For each non-submitter
// (HWK-2 query) resolve their guardian user ids and enqueue a push notification
// (category 'academic'), reusing the same enqueueNotificationRequested path the
// absence alerts use. Audited. (An automatic post-due nudge rides a future
// XCT-2 rule engine — this endpoint is the deliberate teacher action.)
export async function handleTeacherHomeworkNotifyNonSubmitters(
  req: Request,
  config: AppConfig,
  homeworkId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "school" || !auth.claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Teacher scope required", 403);
  }
  const denied = requirePermission(auth.claims, "manageHomework");
  if (denied) return denied;

  // Optional teacher-authored message; a deterministic default otherwise.
  const body = (await readJson<Record<string, unknown>>(req)) ?? {};
  const messageBody = (String(body.message ?? "").trim() || null) ??
    "Homework is still pending — please help your child submit it.";

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const summary = await notifyHomeworkNonSubmitters(
        db,
        auth.claims.tenant_id,
        auth.claims.school_id!,
        homeworkId,
        (guardianUserId) =>
          enqueueNotificationRequested(
            db,
            auth.claims.tenant_id,
            auth.claims.school_id!,
            guardianUserId,
            "Homework reminder",
            messageBody,
            "academic",
          ).then(() => undefined),
      );
      await auditMobileWrite(
        db,
        auth.claims,
        req,
        "homeworkNonSubmittersNotified",
        "homework_assignment",
        homeworkId,
        summary,
      );
      return summary;
    });
    return jsonResponse(
      envelope({
        homeworkId,
        studentsPending: result.studentsPending,
        notificationsQueued: result.notificationsQueued,
      }),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope(
      "INTERNAL_ERROR",
      "Failed to notify non-submitters",
      500,
    );
  }
}

export async function handleTeacherExamMarkUpdate(
  req: Request,
  config: AppConfig,
  markEntryId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "school" || !auth.claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Teacher scope required", 403);
  }
  // MJ-M10/TEACH-4: editing exam marks requires the manageExamMarks permission
  // (the existing exam-governance permission, reused for the mobile teacher path).
  const denied = requirePermission(auth.claims, "manageExamMarks");
  if (denied) return denied;
  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON", 422);

  // RT-08: server-side marks bound. `marks_obtained` is an INTEGER column with a
  // DB CHECK (0 <= marks <= max_marks). Reject a negative / non-integer fast
  // here; the upper bound is enforced by the DB CHECK and mapped to 422 below
  // (rather than leaking as a 500). Without this, a client could persist
  // negative or >max marks and corrupt grades / percentages.
  const marksObtained = Number(body.marks_obtained ?? body.marksObtained ?? 0);
  if (!Number.isFinite(marksObtained) || !Number.isInteger(marksObtained) || marksObtained < 0) {
    return errorEnvelope("VALIDATION_ERROR", "marks_obtained must be a non-negative integer", 422);
  }

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const row = await updateExamMark(
        db,
        auth.claims.tenant_id,
        auth.claims.school_id!,
        markEntryId,
        marksObtained,
        auth.claims.sub,
      );
      await auditMobileWrite(db, auth.claims, req, "examMarkUpdated", "exam_mark_entry", markEntryId, row);
      return row;
    });
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    // Published marks are immutable on the mobile/pilot path too — corrections
    // only (matches the academics exam path).
    if (error instanceof Error && error.message.includes("published and immutable")) {
      return errorEnvelope("EXAM_MARK_PUBLISHED", error.message, 409);
    }
    if (error instanceof Error && error.message.includes("not found")) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    // RT-08: the DB CHECK rejected marks > max_marks (or < 0) — a client input
    // error, not a server fault.
    if (error instanceof Error && error.message.includes("exam_mark_entries_marks_bounds")) {
      return errorEnvelope("VALIDATION_ERROR", "marks_obtained must be between 0 and max_marks", 422);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to update exam mark", 500);
  }
}

export async function handleTeacherTimetable(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "school" || !auth.claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Teacher scope required", 403);
  }

  const url = new URL(req.url);
  const classLabel = url.searchParams.get("class_label") ?? url.searchParams.get("classLabel") ??
    undefined;

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      await listTimetableSlots(
        db,
        auth.claims.tenant_id,
        auth.claims.school_id!,
        classLabel ?? undefined,
      )
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load timetable", 500);
  }
}

export async function handleParentTimetable(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "parent" || !auth.claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Parent scope required", 403);
  }

  const url = new URL(req.url);
  const classLabel = url.searchParams.get("class_label") ?? url.searchParams.get("classLabel") ??
    undefined;
  if (!classLabel) {
    return errorEnvelope("VALIDATION_ERROR", "class_label is required", 422);
  }

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      await listTimetableSlots(
        db,
        auth.claims.tenant_id,
        auth.claims.school_id!,
        classLabel,
      )
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load timetable", 500);
  }
}
