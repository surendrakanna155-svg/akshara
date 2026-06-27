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
import { isSmsConfigured, sendTransactionalSms, type SmsConfig } from "../../sms_provider.ts";
import {
  createExamSession,
  examMarkToApi,
  examSessionToApi,
  ExamApprovalMismatchError,
  ExamApprovalRequiredError,
  ExamMarkConflictError,
  ExamMarkNotFoundError,
  ExamNotFoundError,
  ExamScopeForbiddenError,
  ExamValidationError,
  examRemarkToApi,
  getExamMark,
  getExamSession,
  isClassTeacherForExam,
  listExamMarks,
  listExamRemarks,
  listExamSessions,
  listPublishedResultsForStudent,
  openMarksEntry,
  processExamResults,
  publishExamResults,
  scheduleExamSession,
  teacherTeachesExamSession,
  updateExamMark,
  upsertExamRemark,
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
  if (error instanceof ExamMarkConflictError) {
    // 409 CONFLICT carrying the current server row in `data` so the Data
    // Reliability Platform can show "yours vs theirs" / re-apply (§8.2).
    return jsonResponse(
      {
        data: examMarkToApi(error.currentRow),
        error: { code: "CONFLICT", message: error.message },
      },
      { status: 409 },
    );
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

/**
 * Best-effort transactional SMS to each student's guardian after exam results
 * are published. Mirrors the fee-receipt hook: gated by `transactionalSmsEnabled`
 * + a configured SMS provider; every failure is logged and swallowed so it can
 * never affect the publish response.
 */
async function notifyParentsOfResults(
  config: AppConfig,
  claims: ExamClaims,
  examId: string,
): Promise<void> {
  if (!config.transactionalSmsEnabled) return;
  const smsConfig: SmsConfig = {
    provider: config.smsProvider,
    apiKey: config.smsApiKey,
    fast2smsRoute: config.smsFast2smsRoute,
    fast2smsSenderId: config.smsFast2smsSenderId,
    fast2smsMessageId: config.smsFast2smsMessageId,
  };
  if (!isSmsConfigured(smsConfig)) return;
  try {
    const targets = await withTenantContext(config, claims, (db) =>
      db.queryObject<{ phone: string; name: string; exam_title: string }>(
        `SELECT u.phone AS phone, s.display_name AS name, es.title AS exam_title
           FROM exam_mark_entries m
           JOIN exam_sessions es ON es.id = m.exam_id
            AND es.organization_id = m.organization_id
            AND es.school_id = m.school_id
           JOIN students s ON s.id = m.student_id
           JOIN student_guardians sg ON sg.student_id = s.id
           JOIN users u ON u.id = sg.guardian_user_id
          WHERE m.exam_id = $1 AND m.published = true AND u.phone IS NOT NULL`,
        [examId],
      ));
    for (const target of targets) {
      if (!target.phone) continue;
      const msg =
        `Akshara: Results for ${target.exam_title} are now published for ${target.name}. View them in the app.`;
      const result = await sendTransactionalSms(smsConfig, target.phone, msg);
      if (!result.ok) {
        console.error(`results SMS not sent (${result.code}): ${result.detail}`);
      }
    }
  } catch (error) {
    console.error("results SMS error:", error instanceof Error ? error.message : error);
  }
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
    // RT-08: server-side lower bound. `marks_obtained` is an INTEGER column; a
    // negative or fractional value would corrupt grades. The upper bound
    // (<= max_marks) needs the entry's max_marks and is enforced below; a DB
    // CHECK (exam_mark_entries_marks_bounds) is the backstop for both.
    if (!Number.isInteger(marksObtained) || marksObtained < 0) {
      throw new ExamValidationError("marksObtained must be a non-negative integer");
    }

    const { organizationId, schoolId } = tenantIds(claims);
    const row = await withTenantContext(config, claims, async (db) => {
      // Load the entry once: needed for the RT-08 upper-bound check and reused
      // for the subject-teacher scope check below.
      const mark = await getExamMark(db, organizationId, schoolId, markEntryId);
      if (!mark) throw new ExamMarkNotFoundError(markEntryId);
      if (marksObtained > mark.max_marks) {
        throw new ExamValidationError(
          `marksObtained (${marksObtained}) exceeds max_marks (${mark.max_marks})`,
        );
      }
      // P2 — a plain subject teacher may only edit marks for exams they teach.
      if (isSubjectTeacherScoped(claims)) {
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
      const expectedRaw = body.expectedVersion ?? body.expected_version;
      return await updateExamMark(
        db,
        organizationId,
        schoolId,
        markEntryId,
        marksObtained,
        expectedRaw == null ? null : Number(expectedRaw),
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
    await notifyParentsOfResults(config, claims, examId);
    return { examId, publishedCount };
  });
}

export async function handleListExamRemarks(
  req: Request,
  config: AppConfig,
  examId: string,
): Promise<Response> {
  return await withAuth(req, config, "viewExams", async (claims) => {
    const { organizationId, schoolId } = tenantIds(claims);
    const rows = await withTenantContext(config, claims, (db) =>
      listExamRemarks(db, organizationId, schoolId, examId)
    );
    return rows.map(examRemarkToApi);
  });
}

export async function handleUpsertExamRemark(
  req: Request,
  config: AppConfig,
  examId: string,
  studentId: string,
): Promise<Response> {
  return await withAuth(req, config, "manageExamMarks", async (claims) => {
    const body = await readJson<Record<string, unknown>>(req);
    if (!body) throw new ExamValidationError("JSON body required");
    const text = String(body.text ?? "").trim();
    const authorRole = String(
      body.authorRole ?? body.author_role ?? "classTeacher",
    );
    if (!["classTeacher", "principal", "vicePrincipal"].includes(authorRole)) {
      throw new ExamValidationError(`Invalid authorRole: ${authorRole}`);
    }

    const { organizationId, schoolId } = tenantIds(claims);
    return await withTenantContext(config, claims, async (db) => {
      const session = await getExamSession(db, organizationId, schoolId, examId);
      if (!session) throw new ExamNotFoundError(examId);
      const isAdmin = claims.permissions.includes("manageExams");
      if (authorRole === "classTeacher") {
        // Class-teacher remark: only the class teacher of the exam's class may
        // author it (admins holding manageExams may override).
        if (
          !isAdmin &&
          !(await isClassTeacherForExam(
            db,
            organizationId,
            schoolId,
            claims.sub,
            session,
          ))
        ) {
          throw new ExamScopeForbiddenError(
            "Only the class teacher may author this remark.",
          );
        }
      } else {
        // Leadership remark (principal / vice-principal): requires the exam
        // leadership authority (manageExams). A plain class teacher cannot post
        // a leadership remark.
        if (!isAdmin) {
          throw new ExamScopeForbiddenError(
            "Only the principal or vice-principal may author the leadership remark.",
          );
        }
      }
      const row = await upsertExamRemark(db, organizationId, schoolId, {
        examId,
        studentId,
        text,
        authorId: claims.sub,
        authorName: String(body.authorName ?? body.author_name ?? claims.sub),
        authorRole,
      });
      return examRemarkToApi(row);
    });
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
