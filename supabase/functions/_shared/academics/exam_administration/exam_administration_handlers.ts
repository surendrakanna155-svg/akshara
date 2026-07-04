import type { AppConfig } from "../../config.ts";
import { envelope, errorEnvelope, jsonResponse, MAX_BULK_ITEMS, readJson } from "../../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requireAnyPermission,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../../tenant_handlers.ts";
import { findApprovedByEntity } from "../../approval/approval_repository.ts";
import { emitMutationAudit, examAudit } from "../../audit/mutation_audit_catalog.ts";
import { isSmsConfigured, sendTransactionalSms, type SmsConfig } from "../../sms_provider.ts";
import {
  createExamSession,
  datesheetRowToApi,
  DEFAULT_SEATING_ROOM_CAPACITY,
  examDistributionToApi,
  ExamGracePhaseError,
  examMarkAdjustmentToApi,
  type ExamMarkStatus,
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
  generateSeating,
  getExamMark,
  hallTicketToApi,
  isExamMarkStatus,
  getExamSession,
  isClassTeacherForExam,
  listExamMarkAdjustments,
  listExamMarks,
  listExamRemarks,
  listExamSessions,
  listMarksEntryProgress,
  listPublishedResultsForStudent,
  loadDatesheet,
  loadExamDistribution,
  loadExamToppers,
  loadHallTickets,
  loadMeritList,
  loadReportCards,
  loadSeatingPlan,
  loadTabulationRegister,
  marksEntryProgressToApi,
  meritRowToApi,
  openMarksEntry,
  processExamResults,
  publishExamResults,
  recordExamMarkAdjustment,
  reportCardToApi,
  scheduleExamSession,
  tabulationRegisterToApi,
  teacherTeachesExamSession,
  topperToApi,
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
  // EXM-1 bulk marks save reuses the single-mark gate.
  bulkUpdateExamMarks: "manageExamMarks",
  // EXM-3/4/5/7 — read-only exam reports (all gated on viewExams).
  tabulation: "viewExams",
  toppers: "viewExams",
  merit: "viewExams",
  distribution: "viewExams",
  datesheet: "viewExams",
  // EXM-D1 — batch report cards (published) — coordinator read.
  reportCards: "viewExams",
  // EXM-D2 — grace / moderation. Recording a delta needs the new granular
  // coordinator gate; listing the breakdown is coordinator-only too.
  graceMark: "moderateExamMarks",
  listAdjustments: "moderateExamMarks",
  // EXM-D4 — hall tickets (admit cards) — read.
  hallTickets: "viewExams",
  // EXM-D5 — seating: generating a plan is a manage action; reading it is a read.
  generateSeating: "manageExams",
  getSeating: "viewExams",
} as const;

/**
 * EXM-2 — the marks-entry progress board is a coordinator/leadership read: any
 * holder of viewExams OR verifyExamResults may see who still owes marks. Kept
 * as an explicit OR-gate list (not a single slug) so the contract test can lock
 * both grants.
 */
export const MARKS_ENTRY_PROGRESS_PERMISSIONS = [
  "viewExams",
  "verifyExamResults",
] as const;

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
  if (error instanceof ExamGracePhaseError) {
    // Grace after publish (or before processed) — the results are locked.
    return errorEnvelope("EXAM_GRACE_PHASE", error.message, 409);
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

/**
 * OR-gate variant of withAuth: grants when the caller holds ANY of `permissions`
 * (plus an active school scope). Used by the EXM-2 progress board, readable by
 * either viewExams or verifyExamResults holders.
 */
async function withAnyAuth<T>(
  req: Request,
  config: AppConfig,
  permissions: readonly string[],
  handler: (claims: ExamClaims) => Promise<T>,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAnyPermission(auth.claims, [...permissions]) ??
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

/**
 * EXM-2 — marks-entry progress board. One row per exam in the marks_entry phase
 * with entered/total counts so a coordinator sees who still owes marks before
 * processing/publishing. Read gated on viewExams OR verifyExamResults.
 */
export async function handleMarksEntryProgress(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await withAnyAuth(
    req,
    config,
    MARKS_ENTRY_PROGRESS_PERMISSIONS,
    async (claims) => {
      const { organizationId, schoolId } = tenantIds(claims);
      const rows = await withTenantContext(config, claims, (db) =>
        listMarksEntryProgress(db, organizationId, schoolId));
      return rows.map(marksEntryProgressToApi);
    },
  );
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
    // EXM-6 — parse the deadline BEFORE opening the tenant context so a bad value
    // is rejected 422 up front (never masked by the DB-connection error).
    const marksEntryDeadline = parseDeadline(
      body.marksEntryDeadline ?? body.marks_entry_deadline,
    );

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
        // EXM-6 — optional marks-entry deadline (ISO string), null when omitted.
        marksEntryDeadline,
      })
    );
    return examSessionToApi(row);
  });
}

/**
 * EXM-6 — normalise an incoming marks-entry deadline. A blank/absent value → null
 * (no deadline); any other value is coerced to a string and validated as a
 * parseable timestamp (rejected as 422 otherwise so a garbage value never lands).
 */
function parseDeadline(raw: unknown): string | null {
  if (raw == null || raw === "") return null;
  const value = String(raw).trim();
  if (value === "") return null;
  if (Number.isNaN(Date.parse(value))) {
    throw new ExamValidationError(
      `marksEntryDeadline is not a valid timestamp: ${value}`,
    );
  }
  return value;
}

export async function handleScheduleExam(
  req: Request,
  config: AppConfig,
  examId: string,
): Promise<Response> {
  return await withAuth(req, config, "manageExams", async (claims) => {
    // EXM-6 — schedule may (re)set the marks-entry deadline. An absent body
    // leaves it untouched; an explicit key (even null) applies. A bad timestamp
    // is rejected 422 before the DB.
    const body = await readJson<Record<string, unknown>>(req);
    let deadline: string | null | undefined = undefined;
    if (
      body != null &&
      ("marksEntryDeadline" in body || "marks_entry_deadline" in body)
    ) {
      deadline = parseDeadline(
        body.marksEntryDeadline ?? body.marks_entry_deadline,
      );
    }
    const { organizationId, schoolId } = tenantIds(claims);
    const row = await withTenantContext(config, claims, (db) =>
      scheduleExamSession(db, organizationId, schoolId, examId, deadline)
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

/**
 * EXM-D6 — parse + validate a single mark-entry payload (status + marks) exactly
 * as the single-mark PATCH does. Throws ExamValidationError (422) on a bad
 * status or bad marks. Shared by handleUpdateExamMark AND the EXM-1 bulk save so
 * both paths enforce identical bounds / status semantics.
 */
function parseMarkPayload(
  body: Record<string, unknown>,
): { status: ExamMarkStatus; marksObtained: number; expectedVersion: number | null } {
  const statusRaw = body.status ?? body.attendance_status;
  let status: ExamMarkStatus = "present";
  if (statusRaw != null) {
    if (!isExamMarkStatus(statusRaw)) {
      throw new ExamValidationError(
        `Invalid status: ${String(statusRaw)} (must be one of present, absent, medical_leave, debarred)`,
      );
    }
    status = statusRaw;
  }

  // marks are REQUIRED + bounds-checked only for a present student; a
  // non-present student has no meaningful score (marks are forced NULL by the
  // repository) so any supplied number is ignored, not required.
  let marksObtained = 0;
  if (status === "present") {
    marksObtained = Number(body.marksObtained ?? body.marks_obtained);
    if (!Number.isFinite(marksObtained)) {
      throw new ExamValidationError("marksObtained is required");
    }
    // RT-08: server-side lower bound. `marks_obtained` is an INTEGER column; a
    // negative or fractional value would corrupt grades. The upper bound
    // (<= max_marks) needs the entry's max_marks and is enforced in applyMarkUpdate;
    // a DB CHECK (exam_mark_entries_marks_bounds) is the backstop for both.
    if (!Number.isInteger(marksObtained) || marksObtained < 0) {
      throw new ExamValidationError("marksObtained must be a non-negative integer");
    }
  }

  const expectedRaw = body.expectedVersion ?? body.expected_version;
  return {
    status,
    marksObtained,
    expectedVersion: expectedRaw == null ? null : Number(expectedRaw),
  };
}

/**
 * Applies ONE parsed mark update inside an already-open tenant context. This is
 * the single guarded save path (RT-08 upper bound, published-immutability via
 * updateExamMark's `published = false` fence, optimistic-concurrency, P2
 * subject-teacher scope, per-row audit). Both the single PATCH and the EXM-1
 * bulk save funnel through here so the integrity guards can never diverge.
 */
// deno-lint-ignore no-explicit-any
async function applyMarkUpdate(
  db: any,
  req: Request,
  claims: ExamClaims,
  organizationId: string,
  schoolId: string,
  markEntryId: string,
  parsed: { status: ExamMarkStatus; marksObtained: number; expectedVersion: number | null },
) {
  // Load the entry once: needed for the RT-08 upper-bound check, the
  // before→after audit, and reused for the subject-teacher scope check.
  const mark = await getExamMark(db, organizationId, schoolId, markEntryId);
  if (!mark) throw new ExamMarkNotFoundError(markEntryId);
  if (parsed.status === "present" && parsed.marksObtained > mark.max_marks) {
    throw new ExamValidationError(
      `marksObtained (${parsed.marksObtained}) exceeds max_marks (${mark.max_marks})`,
    );
  }
  // P2 — a plain subject teacher may only edit marks for exams they teach.
  if (isSubjectTeacherScoped(claims)) {
    const session = await getExamSession(db, organizationId, schoolId, mark.exam_id);
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
  const before = {
    marksObtained: mark.marks_entered ? mark.marks_obtained : null,
    status: isExamMarkStatus(mark.status) ? mark.status : "present",
  };
  const updated = await updateExamMark(
    db,
    organizationId,
    schoolId,
    markEntryId,
    parsed.marksObtained,
    parsed.expectedVersion,
    parsed.status,
  );
  // Integrity gap (e) — audit the single-mark mutation binding the actor
  // (claims.sub) to the exam + student and the full before→after of marks
  // and status (so the original attempt is recoverable). Non-blocking-safe:
  // a trail failure must not fail the teacher's save.
  const after = {
    marksObtained: updated.marks_obtained,
    status: isExamMarkStatus(updated.status) ? updated.status : "present",
  };
  try {
    await emitMutationAudit(
      db,
      claims,
      examAudit.markUpdated(
        updated.exam_id,
        updated.id,
        updated.student_id,
        before,
        after,
        updated.row_version,
        `${updated.row_version}`,
      ),
      req,
    );
  } catch (auditError) {
    console.error(
      "exam mark-update audit not recorded:",
      auditError instanceof Error ? auditError.message : auditError,
    );
  }
  return updated;
}

export async function handleUpdateExamMark(
  req: Request,
  config: AppConfig,
  markEntryId: string,
): Promise<Response> {
  return await withAuth(req, config, "manageExamMarks", async (claims) => {
    const body = await readJson<Record<string, unknown>>(req);
    if (!body) throw new ExamValidationError("JSON body required");
    const parsed = parseMarkPayload(body);

    const { organizationId, schoolId } = tenantIds(claims);
    const row = await withTenantContext(config, claims, (db) =>
      applyMarkUpdate(
        db,
        req,
        claims,
        organizationId,
        schoolId,
        markEntryId,
        parsed,
      ));
    return examMarkToApi(row);
  });
}

/**
 * EXM-1 — fast bulk marks entry. Applies each entry through the SAME guarded
 * applyMarkUpdate path (published→skip+report, bounds→validate, status→NULL
 * marks for non-present, per-row audit). Partial success: a bad row is reported
 * in `failed` and never mutates; the rest still persist. Returns
 * { updated: [...], failed: [{ id, reason }] }.
 */
export async function handleBulkUpdateExamMarks(
  req: Request,
  config: AppConfig,
  examId: string,
): Promise<Response> {
  return await withAuth(req, config, "manageExamMarks", async (claims) => {
    const body = await readJson<Record<string, unknown>>(req);
    if (!body) throw new ExamValidationError("JSON body required");
    const rawEntries = body.entries;
    if (!Array.isArray(rawEntries)) {
      throw new ExamValidationError("entries array is required");
    }
    // ENG-8 (SEC-11): cap the bulk array before any per-row DB work.
    if (rawEntries.length > MAX_BULK_ITEMS) {
      throw new ExamValidationError(
        `Maximum ${MAX_BULK_ITEMS} entries per request`,
      );
    }

    const { organizationId, schoolId } = tenantIds(claims);
    const updated: Record<string, unknown>[] = [];
    const failed: Array<{ id: string; reason: string }> = [];

    await withTenantContext(config, claims, async (db) => {
      for (const raw of rawEntries) {
        const entry = (raw ?? {}) as Record<string, unknown>;
        const id = String(entry.id ?? "");
        if (!id) {
          failed.push({ id: "", reason: "id is required" });
          continue;
        }
        try {
          const parsed = parseMarkPayload(entry);
          const row = await applyMarkUpdate(
            db,
            req,
            claims,
            organizationId,
            schoolId,
            id,
            parsed,
          );
          updated.push(examMarkToApi(row));
        } catch (error) {
          // Per-row isolation: never abort the whole batch on one bad row. A
          // published row (immutable) surfaces as ExamMarkNotFoundError from the
          // `published = false` fence and is reported, not overwritten.
          failed.push({ id, reason: bulkFailureReason(error) });
        }
      }
    });

    return { examId, updated, failed };
  });
}

/** Human-readable per-row failure reason for the EXM-1 bulk response. */
function bulkFailureReason(error: unknown): string {
  if (error instanceof ExamMarkNotFoundError) {
    // A missing entry OR a published (immutable) row fenced by `published = false`.
    return "mark entry not found or already published";
  }
  if (error instanceof ExamMarkConflictError) {
    return "row changed since last read (version conflict)";
  }
  if (error instanceof ExamValidationError) return error.message;
  if (error instanceof ExamScopeForbiddenError) return error.message;
  if (error instanceof ExamNotFoundError) return error.message;
  return error instanceof Error ? error.message : "unknown error";
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

    const publishedCount = await withTenantContext(config, claims, async (db) => {
      const count = await publishExamResults(db, organizationId, schoolId, examId);
      // QA-X-015 — audit the publish: a non-reversible mutation that exposes
      // results to students/parents must leave a server-side trail binding the
      // actor (claims.sub, set by recordServerAuditEvent) to the result set.
      await emitMutationAudit(
        db,
        claims,
        examAudit.resultsPublished(examId, count, approvalId ?? null),
        req,
      );
      return count;
    });
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

/** Reads the `term` query param (required for the class-scoped term reports). */
function requireTermParam(req: Request): string {
  const term = new URL(req.url).searchParams.get("term")?.trim() ?? "";
  if (!term) throw new ExamValidationError("term query parameter is required");
  return term;
}

/**
 * EXM-3 — tabulation register for a class over a term. Present marks aggregate
 * into total/percent/rank; a non-present cell (AB/ML/DB) shows its code and is
 * EXCLUDED from every statistic (enforced in loadTabulationRegister).
 */
export async function handleTabulationRegister(
  req: Request,
  config: AppConfig,
  classLabel: string,
): Promise<Response> {
  return await withAuth(req, config, "viewExams", async (claims) => {
    const term = requireTermParam(req);
    const { organizationId, schoolId } = tenantIds(claims);
    const register = await withTenantContext(config, claims, (db) =>
      loadTabulationRegister(
        db,
        organizationId,
        schoolId,
        decodeURIComponent(classLabel),
        term,
      ));
    return tabulationRegisterToApi(register);
  });
}

/**
 * EXM-4a — top-N students by marks for one exam (present rows only; a
 * non-present student is never a topper).
 */
export async function handleExamToppers(
  req: Request,
  config: AppConfig,
  examId: string,
): Promise<Response> {
  return await withAuth(req, config, "viewExams", async (claims) => {
    const limitRaw = new URL(req.url).searchParams.get("limit");
    const limit = Number(limitRaw ?? 5);
    const { organizationId, schoolId } = tenantIds(claims);
    const rows = await withTenantContext(config, claims, (db) =>
      loadExamToppers(
        db,
        organizationId,
        schoolId,
        examId,
        Number.isFinite(limit) && limit > 0 ? Math.floor(limit) : 5,
      ));
    return rows.map(topperToApi);
  });
}

/**
 * EXM-4b — merit list: students in a class ranked by term total % (present-only;
 * a fully-non-present student is excluded).
 */
export async function handleMeritList(
  req: Request,
  config: AppConfig,
  classLabel: string,
): Promise<Response> {
  return await withAuth(req, config, "viewExams", async (claims) => {
    const term = requireTermParam(req);
    const { organizationId, schoolId } = tenantIds(claims);
    const rows = await withTenantContext(config, claims, (db) =>
      loadMeritList(
        db,
        organizationId,
        schoolId,
        decodeURIComponent(classLabel),
        term,
      ));
    return rows.map(meritRowToApi);
  });
}

/**
 * EXM-5 — pass/fail split + grade distribution for one exam (present rows only;
 * non-present rows counted only in `excludedCount`, never in the stats).
 */
export async function handleExamDistribution(
  req: Request,
  config: AppConfig,
  examId: string,
): Promise<Response> {
  return await withAuth(req, config, "viewExams", async (claims) => {
    const { organizationId, schoolId } = tenantIds(claims);
    const dist = await withTenantContext(config, claims, (db) =>
      loadExamDistribution(db, organizationId, schoolId, examId));
    return examDistributionToApi(dist);
  });
}

/**
 * EXM-7 — datesheet (exam schedule) for a class over a term. Read-only schedule,
 * no marks involved.
 */
export async function handleDatesheet(
  req: Request,
  config: AppConfig,
  classLabel: string,
): Promise<Response> {
  return await withAuth(req, config, "viewExams", async (claims) => {
    const term = requireTermParam(req);
    const { organizationId, schoolId } = tenantIds(claims);
    const rows = await withTenantContext(config, claims, (db) =>
      loadDatesheet(
        db,
        organizationId,
        schoolId,
        decodeURIComponent(classLabel),
        term,
      ));
    return rows.map(datesheetRowToApi);
  });
}

/**
 * EXM-D1 — batch report-card data for a class + term (published results only).
 * Returns the per-student card the client renders/prints (reusing the
 * report-card PDF builder). Grace is already baked into the effective mark; the
 * per-delta breakdown is never included.
 */
export async function handleReportCards(
  req: Request,
  config: AppConfig,
  classLabel: string,
): Promise<Response> {
  return await withAuth(req, config, "viewExams", async (claims) => {
    const term = requireTermParam(req);
    const { organizationId, schoolId } = tenantIds(claims);
    const cards = await withTenantContext(config, claims, (db) =>
      loadReportCards(
        db,
        organizationId,
        schoolId,
        decodeURIComponent(classLabel),
        term,
      ));
    return cards.map(reportCardToApi);
  });
}

/**
 * EXM-D2 — record a grace / moderation delta for one (exam, student). Gated on
 * the new granular `moderateExamMarks` (coordinator). Allowed only before publish
 * (processed phase); rejected after publish. Audited via emitMutationAudit. The
 * ORIGINAL mark is preserved; the response returns the resulting effective mark.
 */
export async function handleGraceMark(
  req: Request,
  config: AppConfig,
  examId: string,
  studentId: string,
): Promise<Response> {
  return await withAuth(req, config, "moderateExamMarks", async (claims) => {
    const body = await readJson<Record<string, unknown>>(req);
    if (!body) throw new ExamValidationError("JSON body required");
    const deltaRaw = body.delta;
    const delta = Number(deltaRaw);
    if (!Number.isFinite(delta) || !Number.isInteger(delta)) {
      throw new ExamValidationError("delta must be an integer");
    }
    const reason = String(body.reason ?? "").trim();
    if (!reason) {
      throw new ExamValidationError("reason is required");
    }

    const { organizationId, schoolId } = tenantIds(claims);
    return await withTenantContext(config, claims, async (db) => {
      const result = await recordExamMarkAdjustment(
        db,
        organizationId,
        schoolId,
        { examId, studentId, delta, reason, adjustedBy: claims.sub },
      );
      // Audit the moderation (non-blocking-safe): binds the actor to the delta +
      // reason + resulting effective mark so the change is fully traceable.
      try {
        await emitMutationAudit(
          db,
          claims,
          examAudit.markGraceApplied(
            examId,
            studentId,
            result.adjustment.id,
            delta,
            reason,
            result.effectiveMark,
          ),
          req,
        );
      } catch (auditError) {
        console.error(
          "exam grace-mark audit not recorded:",
          auditError instanceof Error ? auditError.message : auditError,
        );
      }
      return {
        adjustment: examMarkAdjustmentToApi(result.adjustment),
        effectiveMark: result.effectiveMark,
        maxMarks: result.maxMarks,
      };
    });
  });
}

/**
 * EXM-D2 — the full grace / moderation breakdown for an exam (coordinator only —
 * NEVER exposed to parents/students). One row per recorded adjustment.
 */
export async function handleListAdjustments(
  req: Request,
  config: AppConfig,
  examId: string,
): Promise<Response> {
  return await withAuth(req, config, "moderateExamMarks", async (claims) => {
    const { organizationId, schoolId } = tenantIds(claims);
    const rows = await withTenantContext(config, claims, (db) =>
      listExamMarkAdjustments(db, organizationId, schoolId, examId));
    return rows.map(examMarkAdjustmentToApi);
  });
}

/**
 * EXM-D4 — per-student hall tickets (admit cards) for one exam. Standard template
 * fields + adopted-default instructions; the client builds each PDF.
 */
export async function handleHallTickets(
  req: Request,
  config: AppConfig,
  examId: string,
): Promise<Response> {
  return await withAuth(req, config, "viewExams", async (claims) => {
    const { organizationId, schoolId } = tenantIds(claims);
    const rows = await withTenantContext(config, claims, (db) =>
      loadHallTickets(db, organizationId, schoolId, examId));
    return rows.map(hallTicketToApi);
  });
}

/**
 * EXM-D5 — (re)generate the seating plan for an exam (manage gate). Mixed-class
 * default (no two adjacent same-class seats when multiple classes sit); single
 * class seats sequentially by roll. Room capacity defaults to 30 (`?capacity=`
 * or body `capacity`).
 */
export async function handleGenerateSeating(
  req: Request,
  config: AppConfig,
  examId: string,
): Promise<Response> {
  return await withAuth(req, config, "manageExams", async (claims) => {
    const body = await readJson<Record<string, unknown>>(req);
    const capRaw = body?.capacity ??
      new URL(req.url).searchParams.get("capacity");
    const capacity = capRaw == null || capRaw === ""
      ? DEFAULT_SEATING_ROOM_CAPACITY
      : Number(capRaw);
    if (!Number.isFinite(capacity) || capacity <= 0) {
      throw new ExamValidationError("capacity must be a positive number");
    }
    const { organizationId, schoolId } = tenantIds(claims);
    return await withTenantContext(config, claims, async (db) => {
      await generateSeating(
        db,
        organizationId,
        schoolId,
        examId,
        Math.floor(capacity),
      );
      return loadSeatingPlan(db, organizationId, schoolId, examId);
    });
  });
}

/** EXM-D5 — read the current seating plan for an exam (grouped by room). */
export async function handleGetSeating(
  req: Request,
  config: AppConfig,
  examId: string,
): Promise<Response> {
  return await withAuth(req, config, "viewExams", async (claims) => {
    const { organizationId, schoolId } = tenantIds(claims);
    const plan = await withTenantContext(config, claims, (db) =>
      loadSeatingPlan(db, organizationId, schoolId, examId));
    return plan;
  });
}
