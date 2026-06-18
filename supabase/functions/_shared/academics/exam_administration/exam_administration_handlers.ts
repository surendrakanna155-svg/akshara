import type { AppConfig } from "../../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../../tenant_handlers.ts";
import { findApprovedByEntity } from "../../approval/approval_repository.ts";
import {
  createExamSession,
  examMarkToApi,
  examSessionToApi,
  ExamApprovalMismatchError,
  ExamApprovalRequiredError,
  ExamMarkNotFoundError,
  ExamNotFoundError,
  ExamScopeForbiddenError,
  ExamValidationError,
  getExamMark,
  getExamSession,
  listExamMarks,
  listExamSessions,
  listPublishedResultsForStudent,
  openMarksEntry,
  processExamResults,
  publishExamResults,
  scheduleExamSession,
  teacherTeachesExamSession,
  updateExamMark,
  verifyCoordinatorResults,
} from "./exam_administration_repository.ts";

type ExamClaims = Parameters<typeof requirePermission>[0];

/**
 * P2 — a plain subject teacher (can manage marks but cannot verify) is scoped
 * to their own subject + class assignments. Oversight roles (coordinator,
 * principal, VP, school admin, management) hold verifyExamResults and see all
 * marks in the school.
 */
export function isSubjectTeacherScoped(claims: ExamClaims): boolean {
  return !claims.permissions.includes("verifyExamResults");
}

/** Granular permission required per exam operation (P1). Source of truth for tests. */
export const EXAM_OPERATION_PERMISSIONS = {
  listExams: "viewExams",
  getExam: "viewExams",
  createExam: "manageExams",
  scheduleExam: "manageExams",
  openMarksEntry: "manageExams",
  listExamMarks: "manageExamMarks",
  updateExamMark: "manageExamMarks",
  processResults: "submitExamResults",
  verifyCoordinator: "verifyExamResults",
  publishResults: "publishExamResults",
  listPublishedForStudent: "viewExams",
} as const;

function mapExamError(error: unknown): Response {
  if (error instanceof ExamNotFoundError) {
    return errorEnvelope("EXAM_NOT_FOUND", error.message, 404);
  }
  if (error instanceof ExamMarkNotFoundError) {
    return errorEnvelope("EXAM_MARK_NOT_FOUND", error.message, 404);
  }
  if (error instanceof ExamScopeForbiddenError) {
    return errorEnvelope("EXAM_SCOPE_FORBIDDEN", error.message, 403);
  }
  if (error instanceof ExamValidationError) {
    return errorEnvelope("EXAM_VALIDATION", error.message, 422);
  }
  if (error instanceof ExamApprovalRequiredError) {
    return errorEnvelope("EXAM_APPROVAL_REQUIRED", error.message, 403);
  }
  if (error instanceof ExamApprovalMismatchError) {
    return errorEnvelope("EXAM_APPROVAL_MISMATCH", error.message, 409);
  }
  throw error;
}

async function withAuth<T>(
  req: Request,
  config: AppConfig,
  permission: string,
  handler: (claims: ExamClaims) => Promise<T>,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  // P1 — enforce the granular exam permission for this operation (not coarse SIS),
  // plus an active school scope.
  const denied = requirePermission(auth.claims, permission) ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const result = await handler(auth.claims);
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    return mapExamError(error);
  }
}

function tenantIds(claims: ExamClaims) {
  return {
    organizationId: organizationIdFromClaims(claims),
    schoolId: schoolIdFromClaims(claims),
  };
}

export async function handleListExams(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await withAuth(req, config, "viewExams", async (claims) => {
    const { organizationId, schoolId } = tenantIds(claims);
    const rows = await withTenantContext(config, claims, (db) =>
      listExamSessions(db, organizationId, schoolId)
    );
    return rows.map(examSessionToApi);
  });
}

export async function handleGetExam(
  req: Request,
  config: AppConfig,
  examId: string,
): Promise<Response> {
  return await withAuth(req, config, "viewExams", async (claims) => {
    const { organizationId, schoolId } = tenantIds(claims);
    const row = await withTenantContext(config, claims, (db) =>
      getExamSession(db, organizationId, schoolId, examId)
    );
    if (!row) throw new ExamNotFoundError(examId);
    return examSessionToApi(row);
  });
}

export async function handleCreateExam(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await withAuth(req, config, "manageExams", async (claims) => {
    const body = await readJson<Record<string, unknown>>(req);
    if (!body) throw new ExamValidationError("JSON body required");

    const title = String(body.title ?? "").trim();
    const subject = String(body.subject ?? "").trim();
    const grade = String(body.grade ?? "").trim();
    if (!title || !subject || !grade) {
      throw new ExamValidationError("title, subject, and grade are required");
    }

    const { organizationId, schoolId } = tenantIds(claims);
    const row = await withTenantContext(config, claims, (db) =>
      createExamSession(db, organizationId, schoolId, {
        title,
        subject,
        grade,
        section: String(body.section ?? "").trim(),
        termLabel: String(body.termLabel ?? body.term_label ?? "").trim(),
        dateLabel: String(body.dateLabel ?? body.date_label ?? "").trim(),
        timeLabel: String(body.timeLabel ?? body.time_label ?? "").trim(),
        venueLabel: String(body.venueLabel ?? body.venue_label ?? "").trim(),
        syllabusLabel: String(body.syllabusLabel ?? body.syllabus_label ?? "").trim(),
        maxMarks: Number(body.maxMarks ?? body.max_marks ?? 100) || 100,
        examType: String(body.examType ?? body.exam_type ?? "unit_test"),
        createdBy: claims.sub,
      })
    );
    return examSessionToApi(row);
  });
}

export async function handleScheduleExam(
  req: Request,
  config: AppConfig,
  examId: string,
): Promise<Response> {
  return await withAuth(req, config, "manageExams", async (claims) => {
    const { organizationId, schoolId } = tenantIds(claims);
    const row = await withTenantContext(config, claims, (db) =>
      scheduleExamSession(db, organizationId, schoolId, examId)
    );
    return examSessionToApi(row);
  });
}

export async function handleOpenMarksEntry(
  req: Request,
  config: AppConfig,
  examId: string,
): Promise<Response> {
  return await withAuth(req, config, "manageExams", async (claims) => {
    const { organizationId, schoolId } = tenantIds(claims);
    const row = await withTenantContext(config, claims, (db) =>
      openMarksEntry(db, organizationId, schoolId, examId)
    );
    return examSessionToApi(row);
  });
}

export async function handleListExamMarks(
  req: Request,
  config: AppConfig,
  examId: string,
): Promise<Response> {
  return await withAuth(req, config, "manageExamMarks", async (claims) => {
    const { organizationId, schoolId } = tenantIds(claims);
    const rows = await withTenantContext(config, claims, async (db) => {
      const session = await getExamSession(db, organizationId, schoolId, examId);
      if (!session) throw new ExamNotFoundError(examId);
      // P2 — a plain subject teacher may only read marks for exams they teach.
      if (
        isSubjectTeacherScoped(claims) &&
        !(await teacherTeachesExamSession(
          db,
          organizationId,
          schoolId,
          claims.sub,
          session,
        ))
      ) {
        throw new ExamScopeForbiddenError();
      }
      return await listExamMarks(db, organizationId, schoolId, examId);
    });
    return rows.map(examMarkToApi);
  });
}

export async function handleUpdateExamMark(
  req: Request,
  config: AppConfig,
  markEntryId: string,
): Promise<Response> {
  return await withAuth(req, config, "manageExamMarks", async (claims) => {
    const body = await readJson<Record<string, unknown>>(req);
    if (!body) throw new ExamValidationError("JSON body required");
    const marksObtained = Number(body.marksObtained ?? body.marks_obtained);
    if (!Number.isFinite(marksObtained)) {
      throw new ExamValidationError("marksObtained is required");
    }

    const { organizationId, schoolId } = tenantIds(claims);
    const row = await withTenantContext(config, claims, async (db) => {
      // P2 — a plain subject teacher may only edit marks for exams they teach.
      if (isSubjectTeacherScoped(claims)) {
        const mark = await getExamMark(db, organizationId, schoolId, markEntryId);
        if (!mark) throw new ExamMarkNotFoundError(markEntryId);
        const session = await getExamSession(
          db,
          organizationId,
          schoolId,
          mark.exam_id,
        );
        if (!session) throw new ExamNotFoundError(mark.exam_id);
        if (
          !(await teacherTeachesExamSession(
            db,
            organizationId,
            schoolId,
            claims.sub,
            session,
          ))
        ) {
          throw new ExamScopeForbiddenError();
        }
      }
      return await updateExamMark(
        db,
        organizationId,
        schoolId,
        markEntryId,
        marksObtained,
      );
    });
    return examMarkToApi(row);
  });
}

export async function handleProcessExamResults(
  req: Request,
  config: AppConfig,
  examId: string,
): Promise<Response> {
  return await withAuth(req, config, "submitExamResults", async (claims) => {
    const { organizationId, schoolId } = tenantIds(claims);
    const row = await withTenantContext(config, claims, (db) =>
      processExamResults(db, organizationId, schoolId, examId)
    );
    return examSessionToApi(row);
  });
}

export async function handleVerifyCoordinator(
  req: Request,
  config: AppConfig,
  examId: string,
): Promise<Response> {
  return await withAuth(req, config, "verifyExamResults", async (claims) => {
    const body = await readJson<Record<string, unknown>>(req);
    const verifiedBy = String(
      body?.verifiedBy ?? body?.verified_by ?? claims.sub,
    ).trim();

    const { organizationId, schoolId } = tenantIds(claims);
    const row = await withTenantContext(config, claims, (db) =>
      verifyCoordinatorResults(
        db,
        organizationId,
        schoolId,
        examId,
        verifiedBy,
      )
    );
    return examSessionToApi(row);
  });
}

export async function handlePublishExamResults(
  req: Request,
  config: AppConfig,
  examId: string,
): Promise<Response> {
  return await withAuth(req, config, "publishExamResults", async (claims) => {
    const body = await readJson<Record<string, unknown>>(req);
    const approvalId = body?.approvalId != null
      ? String(body.approvalId)
      : body?.approval_id != null
        ? String(body.approval_id)
        : undefined;
    const requireApproval = body?.requireApproval !== false &&
      body?.require_approval !== false;

    const { organizationId, schoolId } = tenantIds(claims);

    if (requireApproval) {
      const approved = await withTenantContext(config, claims, (db) =>
        findApprovedByEntity(
          db,
          organizationId,
          schoolId,
          "examResults",
          "exam_session",
          examId,
        )
      );
      if (!approved) {
        throw new ExamApprovalRequiredError();
      }
      if (approvalId && approved.id !== approvalId) {
        throw new ExamApprovalMismatchError();
      }
    }

    const publishedCount = await withTenantContext(config, claims, (db) =>
      publishExamResults(db, organizationId, schoolId, examId)
    );
    return { examId, publishedCount };
  });
}

export async function handleListPublishedResultsForStudent(
  req: Request,
  config: AppConfig,
  studentId: string,
): Promise<Response> {
  return await withAuth(req, config, "viewExams", async (claims) => {
    const { organizationId, schoolId } = tenantIds(claims);
    const rows = await withTenantContext(config, claims, (db) =>
      listPublishedResultsForStudent(db, organizationId, schoolId, studentId)
    );
    return rows;
  });
}
