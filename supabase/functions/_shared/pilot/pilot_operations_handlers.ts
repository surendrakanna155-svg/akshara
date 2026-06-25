import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { correlationIdFromRequest, recordMutationAudit } from "../audit/audit_repository.ts";
import { enqueueNotificationRequested } from "../communication/notification_service.ts";
import {
  createLeaveRequest,
  insertHomeworkAssignment,
  reviewHomework,
  submitHomework,
  updateExamMark,
  listTimetableSlots,
  listGuardianUserIdsForStudent,
  upsertAttendanceSession,
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

export async function handleTeacherAttendanceDraft(
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
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
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
  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON", 422);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const row = await reviewHomework(db, submissionId, {
        grade: snakeStr(body, "grade"),
        comment: snakeStr(body, "comment"),
        reviewerId: auth.claims.sub,
      });
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
  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON", 422);

  const classLabel = String(body.class_label ?? body.classLabel ?? "").trim();
  const subject = String(body.subject ?? "").trim();
  const title = String(body.title ?? "").trim();
  if (!classLabel || !subject || !title) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "class_label, subject and title are required",
      422,
    );
  }
  const dueLabel = String(body.due_label ?? body.dueLabel ?? "").trim() || "—";
  const studentNameRaw = String(body.student_name ?? body.studentName ?? "").trim();
  const studentName = studentNameRaw.length > 0 ? studentNameRaw : null;
  const homeworkId = `hw_${crypto.randomUUID()}`;

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const created = await insertHomeworkAssignment(db, {
        organizationId: auth.claims.tenant_id,
        schoolId: auth.claims.school_id!,
        teacherId: auth.claims.sub,
        homeworkId,
        classLabel,
        subject,
        title,
        dueLabel,
        studentName,
      });
      await auditMobileWrite(
        db,
        auth.claims,
        req,
        "homeworkCreated",
        "homework_assignment",
        created.id,
        { classLabel, subject, deliveredCount: created.deliveredCount },
      );
      return created;
    });
    return jsonResponse(
      envelope({
        id: result.id,
        title,
        classLabel,
        subject,
        dueLabel,
        deliveredCount: result.deliveredCount,
      }),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to create homework", 500);
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
  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON", 422);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const row = await updateExamMark(
        db,
        auth.claims.tenant_id,
        auth.claims.school_id!,
        markEntryId,
        Number(body.marks_obtained ?? body.marksObtained ?? 0),
        auth.claims.sub,
      );
      await auditMobileWrite(db, auth.claims, req, "examMarkUpdated", "exam_mark_entry", markEntryId, row);
      return row;
    });
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof Error && error.message.includes("not found")) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
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
