import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
// P1 (observability): every attendance-correction mutation emits a forensic
// audit row + domain event. `emitMutationAudit` (not raw `recordMutationAudit`)
// so the correlation id is auto-derived from the request; the `Request` is
// ALWAYS passed so ip/user-agent are captured with the actor.
import { attendanceAudit, emitMutationAudit } from "../audit/mutation_audit_catalog.ts";
import {
  AttendanceCorrectionNotFoundError,
  AttendanceValidationError,
  correctionToApi,
  createAttendanceCorrection,
  getAttendanceCorrection,
  listAttendanceCorrections,
  updateAttendanceCorrectionStatus,
  type AttendanceCorrectionStatus,
} from "./attendance_correction_repository.ts";
import {
  attendanceSessionToApi,
  AttendanceSessionNotFoundError,
  getAttendanceSession,
  listAttendanceSessions,
  MAX_SESSIONS_WINDOW_DAYS,
} from "./attendance_sessions_repository.ts";
import {
  consecutiveAbsenceRowToApi,
  getAttendanceRegister,
  getConsecutiveAbsences,
  getMonthlyRegister,
  getPendingAttendance,
  getShortAttendance,
  monthlyRegisterToApi,
  pendingClassRowToApi,
  registerRowToApi,
  shortAttendanceRowToApi,
} from "./attendance_office_repository.ts";

type AuthedClaims = Parameters<typeof requirePermission>[0];

function requireAttendanceRead(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "viewSis") ??
    requireSchoolOperationalScope(claims);
}

function requireAttendanceWrite(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "manageSis") ??
    requireSchoolOperationalScope(claims);
}

/** Deciding a correction's status is an approval action — not plain manageSis. */
function requireAttendanceApprove(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "approveAttendanceCorrection") ??
    requireSchoolOperationalScope(claims);
}

function mapAttendanceError(error: unknown): Response {
  if (error instanceof AttendanceCorrectionNotFoundError) {
    return errorEnvelope("ATTENDANCE_CORRECTION_NOT_FOUND", error.message, 404);
  }
  if (error instanceof AttendanceSessionNotFoundError) {
    return errorEnvelope("ATTENDANCE_SESSION_NOT_FOUND", error.message, 404);
  }
  if (error instanceof AttendanceValidationError) {
    return errorEnvelope("ATTENDANCE_VALIDATION", error.message, 422);
  }
  throw error;
}

/**
 * Authenticate → authorize → run. The ONLY way a handler in this module reaches
 * business logic.
 *
 * SEC-AUTH-FIRST: `handler` may now return a `Response` instead of a payload, and
 * it is passed through untouched. That exists so REQUEST VALIDATION can live
 * inside the callback — i.e. after authentication and the permission check —
 * rather than above the `withAuth` call.
 *
 * It used to live above it, and that is the defect the live pilot exhibited:
 * `GET /attendance/register/monthly` read its query string and answered
 * `422 classLabel is required` to a caller with no credentials at all, handing
 * out the route's parameter contract. The central gate in `api/app.ts` now stops
 * such a request long before it gets here, but a handler must not depend on
 * something upstream to make it safe — the pilot is the proof of what happens
 * when the upstream gate is the only copy of the rule.
 */
async function withAuth<T>(
  req: Request,
  config: AppConfig,
  readOnly: boolean,
  handler: (claims: AuthedClaims) => Promise<T | Response>,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = readOnly
    ? requireAttendanceRead(auth.claims)
    : requireAttendanceWrite(auth.claims);
  if (denied) return denied;

  try {
    const result = await handler(auth.claims);
    // A validation/short-circuit Response from inside the callback is returned
    // verbatim; anything else is the success payload.
    if (result instanceof Response) return result;
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    return mapAttendanceError(error);
  }
}

function tenantIds(claims: AuthedClaims) {
  return {
    organizationId: organizationIdFromClaims(claims),
    schoolId: schoolIdFromClaims(claims),
  };
}

/**
 * Parse an optional positive-int query param. Returns undefined for a
 * missing/blank/non-numeric value so the repository applies its own default and
 * clamping (pagination is silently clamped, not rejected — matching the shared
 * entity-read pagination convention).
 */
function parseOptionalInt(raw: string | null): number | undefined {
  if (raw === null || raw.trim() === "") return undefined;
  const n = Number.parseInt(raw, 10);
  return Number.isFinite(n) ? n : undefined;
}

/**
 * GET /attendance/sessions?page=&pageSize=&windowDays=
 *
 * ICA-C3 (P1, perf): the list is now paginated + date-windowed (see
 * listAttendanceSessions). page/pageSize follow the shared pagination
 * convention (pageSize hard-capped at 100 in the repository; silently clamped,
 * not rejected). windowDays is an optional trailing look-back; when supplied it
 * is range-validated (1..366) and 422'd, matching the sibling office reads.
 *
 * Response shape change: this used to return a bare array of sessions
 * (`data: [...]`). It now returns a pagination envelope
 * (`data: { items: [...], total, page, pageSize, hasMore }`) — the same
 * convention as the generic entity read store. No client currently consumes
 * this route, so there is no old-shape caller to preserve; the default page
 * still carries the most recent sessions first.
 */
export async function handleListAttendanceSessions(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const url = new URL(req.url);
  const page = parseOptionalInt(url.searchParams.get("page"));
  const pageSize = parseOptionalInt(url.searchParams.get("pageSize"));

  // windowDays is validated up front (like the other office reads) so a bad
  // explicit value is a clean 422 rather than being silently clamped.
  const windowDaysRaw = url.searchParams.get("windowDays");
  let windowDays: number | undefined;
  if (windowDaysRaw !== null && windowDaysRaw.trim() !== "") {
    const parsed = Number.parseInt(windowDaysRaw, 10);
    if (
      !Number.isFinite(parsed) || parsed < 1 ||
      parsed > MAX_SESSIONS_WINDOW_DAYS
    ) {
      return errorEnvelope(
        "ATTENDANCE_VALIDATION",
        `windowDays must be between 1 and ${MAX_SESSIONS_WINDOW_DAYS}`,
        422,
      );
    }
    windowDays = parsed;
  }

  return await withAuth(req, config, true, async (claims) => {
    const { organizationId, schoolId } = tenantIds(claims);
    const result = await withTenantContext(config, claims, (db) =>
      listAttendanceSessions(db, organizationId, schoolId, {
        page,
        pageSize,
        windowDays,
      })
    );
    return {
      items: result.items.map(attendanceSessionToApi),
      total: result.total,
      page: result.page,
      pageSize: result.pageSize,
      hasMore: result.hasMore,
    };
  });
}

export async function handleGetAttendanceSession(
  req: Request,
  config: AppConfig,
  sessionId: string,
): Promise<Response> {
  return await withAuth(req, config, true, async (claims) => {
    const { organizationId, schoolId } = tenantIds(claims);
    const row = await withTenantContext(config, claims, (db) =>
      getAttendanceSession(db, organizationId, schoolId, sessionId)
    );
    if (!row) throw new AttendanceSessionNotFoundError(sessionId);
    return attendanceSessionToApi(row);
  });
}

// --- OFFICE / ADMIN reads (ATT-1, ATT-2, ATT-4, ATT-D1, ATT-D2) --------------

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const MONTH_RE = /^\d{4}-\d{2}$/;

/** ATT-1 — GET /attendance/register?classLabel=&date= */
export async function handleAttendanceRegister(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await withAuth(req, config, true, async (claims) => {
    const url = new URL(req.url);
    const classLabel = (url.searchParams.get("classLabel") ?? "").trim();
    const date = (url.searchParams.get("date") ?? "").trim();
    if (!classLabel) {
      return errorEnvelope("ATTENDANCE_VALIDATION", "classLabel is required", 422);
    }
    if (!DATE_RE.test(date)) {
      return errorEnvelope("ATTENDANCE_VALIDATION", "date (YYYY-MM-DD) is required", 422);
    }
    const { organizationId, schoolId } = tenantIds(claims);
    const rows = await withTenantContext(config, claims, (db) =>
      getAttendanceRegister(db, organizationId, schoolId, classLabel, date)
    );
    return rows.map(registerRowToApi);
  });
}

/** ATT-2 — GET /attendance/register/monthly?classLabel=&month=YYYY-MM */
export async function handleAttendanceMonthlyRegister(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await withAuth(req, config, true, async (claims) => {
    const url = new URL(req.url);
    const classLabel = (url.searchParams.get("classLabel") ?? "").trim();
    const month = (url.searchParams.get("month") ?? "").trim();
    if (!classLabel) {
      return errorEnvelope("ATTENDANCE_VALIDATION", "classLabel is required", 422);
    }
    if (!MONTH_RE.test(month)) {
      return errorEnvelope("ATTENDANCE_VALIDATION", "month (YYYY-MM) is required", 422);
    }
    const { organizationId, schoolId } = tenantIds(claims);
    const register = await withTenantContext(config, claims, (db) =>
      getMonthlyRegister(db, organizationId, schoolId, classLabel, month)
    );
    return monthlyRegisterToApi(register);
  });
}

/** ATT-4 — GET /attendance/pending?date= */
export async function handleAttendancePending(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await withAuth(req, config, true, async (claims) => {
    const url = new URL(req.url);
    const date = (url.searchParams.get("date") ?? "").trim();
    if (!DATE_RE.test(date)) {
      return errorEnvelope("ATTENDANCE_VALIDATION", "date (YYYY-MM-DD) is required", 422);
    }
    const { organizationId, schoolId } = tenantIds(claims);
    const rows = await withTenantContext(config, claims, (db) =>
      getPendingAttendance(db, organizationId, schoolId, date)
    );
    return rows.map(pendingClassRowToApi);
  });
}

/** ATT-D1 — GET /attendance/alerts/consecutive-absence?days=3 */
export async function handleAttendanceConsecutiveAbsence(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await withAuth(req, config, true, async (claims) => {
    const url = new URL(req.url);
    const days = Number.parseInt(url.searchParams.get("days") ?? "3", 10);
    if (!Number.isFinite(days) || days < 1 || days > 60) {
      return errorEnvelope("ATTENDANCE_VALIDATION", "days must be between 1 and 60", 422);
    }
    const { organizationId, schoolId } = tenantIds(claims);
    const rows = await withTenantContext(config, claims, (db) =>
      getConsecutiveAbsences(db, organizationId, schoolId, days)
    );
    return rows.map(consecutiveAbsenceRowToApi);
  });
}

/** ATT-D2 — GET /attendance/alerts/short-attendance?threshold=75&windowDays=30 */
export async function handleAttendanceShortAttendance(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await withAuth(req, config, true, async (claims) => {
    const url = new URL(req.url);
    const threshold = Number.parseInt(url.searchParams.get("threshold") ?? "75", 10);
    const windowDays = Number.parseInt(url.searchParams.get("windowDays") ?? "30", 10);
    if (!Number.isFinite(threshold) || threshold < 1 || threshold > 100) {
      return errorEnvelope("ATTENDANCE_VALIDATION", "threshold must be between 1 and 100", 422);
    }
    if (!Number.isFinite(windowDays) || windowDays < 1 || windowDays > 366) {
      return errorEnvelope("ATTENDANCE_VALIDATION", "windowDays must be between 1 and 366", 422);
    }
    const { organizationId, schoolId } = tenantIds(claims);
    const rows = await withTenantContext(config, claims, (db) =>
      getShortAttendance(db, organizationId, schoolId, threshold, windowDays)
    );
    return rows.map(shortAttendanceRowToApi);
  });
}

// --- CORRECTIONS (the only mutations this module owns) -----------------------
//
// `source` on each audit event is the API route that produced the mutation —
// what lets a support engineer tell a parent-filed request from a staff-filed
// one, and the direct staff decision route from the approvals workflow. All
// three land on the same `attendance_corrections` row.
const STAFF_CORRECTION_SOURCE = "POST /attendance/corrections";
const PARENT_CORRECTION_SOURCE = "POST /parent/attendance/corrections";
const CORRECTION_DECISION_SOURCE = "PATCH /attendance/corrections/:id/status";

/**
 * Millisecond-precision ISO form of a row timestamp, used as the audit outbox
 * nonce. `updated_at` arrives as a `Date` from the Postgres driver (the row type
 * says `string`) and as a string from fixtures; `Date.toString()` would drop the
 * milliseconds and could collide across two rapid re-decisions. Falls back to
 * the raw value rather than throwing — an audit must never fail a mutation.
 */
function timestampNonce(value: unknown): string {
  const date = value instanceof Date ? value : new Date(String(value));
  return Number.isNaN(date.getTime()) ? String(value) : date.toISOString();
}

export async function handleListAttendanceCorrections(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await withAuth(req, config, true, async (claims) => {
    const url = new URL(req.url);
    const status = url.searchParams.get("status") as AttendanceCorrectionStatus | null;
    const { organizationId, schoolId } = tenantIds(claims);
    const rows = await withTenantContext(config, claims, (db) =>
      listAttendanceCorrections(
        db,
        organizationId,
        schoolId,
        status ?? undefined,
      )
    );
    return rows.map(correctionToApi);
  });
}

export async function handleGetAttendanceCorrection(
  req: Request,
  config: AppConfig,
  correctionId: string,
): Promise<Response> {
  return await withAuth(req, config, true, async (claims) => {
    const { organizationId, schoolId } = tenantIds(claims);
    const row = await withTenantContext(config, claims, (db) =>
      getAttendanceCorrection(db, organizationId, schoolId, correctionId)
    );
    if (!row) {
      throw new AttendanceCorrectionNotFoundError(correctionId);
    }
    return correctionToApi(row);
  });
}

export async function handleCreateAttendanceCorrection(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await withAuth(req, config, false, async (claims) => {
    const body = await readJson<Record<string, unknown>>(req);
    if (!body) throw new AttendanceValidationError("JSON body required");

    const sisStudentId = String(body.sisStudentId ?? body.sis_student_id ?? "").trim();
    if (!sisStudentId) {
      throw new AttendanceValidationError("sisStudentId is required");
    }

    const { organizationId, schoolId } = tenantIds(claims);
    const row = await withTenantContext(config, claims, async (db) => {
      const created = await createAttendanceCorrection(db, organizationId, schoolId, {
        sisStudentId,
        studentName: String(body.studentName ?? body.student_name ?? ""),
        classLabel: String(body.classLabel ?? body.class_label ?? ""),
        section: String(body.section ?? body.section_name ?? ""),
        dateLabel: String(body.dateLabel ?? body.date_label ?? ""),
        fromMark: String(body.fromMark ?? body.from_mark ?? ""),
        toMark: String(body.toMark ?? body.to_mark ?? ""),
        reason: String(body.reason ?? ""),
        requesterId: String(body.requesterId ?? body.requester_id ?? claims.sub),
        requesterName: String(body.requesterName ?? body.requester_name ?? "Requester"),
        requesterRole: String(body.requesterRole ?? body.requester_role ?? "teacher"),
        presentDelta: Number(body.presentDelta ?? body.present_delta ?? 1) || 1,
      });
      // Same transaction as the INSERT: the request and its audit row commit
      // together or not at all. Values read back from the PERSISTED row, so the
      // audit records what was actually stored (normalised marks), not the body.
      await emitMutationAudit(
        db,
        claims,
        attendanceAudit.correctionRequested(created.id, {
          sisStudentId: created.sis_student_id,
          studentId: created.student_id,
          dateLabel: created.date_label,
          markChange: { from: created.from_mark, to: created.to_mark },
          reason: created.reason,
          requesterId: created.requester_id,
          requesterRole: created.requester_role,
          source: STAFF_CORRECTION_SOURCE,
        }),
        req,
      );
      return created;
    });
    return correctionToApi(row);
  });
}

/**
 * POST /parent/attendance/corrections — a parent submits a correction request
 * for their OWN child (ATTEN-2 / MJ-M11). The staff correction route
 * (handleCreateAttendanceCorrection) requires manageSis, which a parent never
 * holds, so parents were 403'd. Here we authorize on parent scope and force the
 * requester to be the parent: requester_role is pinned to 'parent' and
 * requester_id to the parent's user id, regardless of the body. The DB is the
 * authoritative gate — the attendance_corrections_parent_insert RLS policy
 * rejects the INSERT unless the resolved student is linked to this parent via
 * student_guardians, so a parent cannot file a correction for another child.
 */
export async function handleParentCreateAttendanceCorrection(
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
  const sisStudentId = String(body.sisStudentId ?? body.sis_student_id ?? "").trim();
  if (!sisStudentId) {
    return errorEnvelope("ATTENDANCE_VALIDATION", "sisStudentId is required", 422);
  }

  const { organizationId, schoolId } = tenantIds(auth.claims);
  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const created = await createAttendanceCorrection(db, organizationId, schoolId, {
        // Unique id — the parent-scope SELECT RLS hides staff rows, so the
        // sequential count would collide on the (org, school, id) PK.
        id: `att_corr_p_${crypto.randomUUID()}`,
        sisStudentId,
        studentName: String(body.studentName ?? body.student_name ?? ""),
        classLabel: String(body.classLabel ?? body.class_label ?? ""),
        section: String(body.section ?? body.section_name ?? ""),
        dateLabel: String(body.dateLabel ?? body.date_label ?? ""),
        fromMark: String(body.fromMark ?? body.from_mark ?? ""),
        toMark: String(body.toMark ?? body.to_mark ?? ""),
        reason: String(body.reason ?? ""),
        // Pinned to the calling parent — never trust the body for identity.
        requesterId: auth.claims.sub,
        requesterName: String(body.requesterName ?? body.requester_name ?? "Parent"),
        requesterRole: "parent",
        presentDelta: Number(body.presentDelta ?? body.present_delta ?? 1) || 1,
      });
      // The parent submit is audited HERE, at the submit — not (only) at the
      // staff approval. A request that is never decided, or is silently
      // rejected, must still show that the parent asked and when. Parent scope
      // is permitted to INSERT into audit_events/domain_events (see
      // 20260920000140 / 20260725000000), so this does not break the write.
      await emitMutationAudit(
        db,
        auth.claims,
        attendanceAudit.correctionRequested(created.id, {
          sisStudentId: created.sis_student_id,
          studentId: created.student_id,
          dateLabel: created.date_label,
          markChange: { from: created.from_mark, to: created.to_mark },
          reason: created.reason,
          requesterId: created.requester_id,
          requesterRole: created.requester_role,
          source: PARENT_CORRECTION_SOURCE,
        }),
        req,
      );
      return created;
    });
    return jsonResponse(envelope(correctionToApi(row)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    // An RLS WITH CHECK failure (child not linked to this parent) surfaces as a
    // "new row violates row-level security policy" db error — return a clean 403.
    // Match the RLS phrasing specifically so unrelated db errors (e.g. a PK
    // clash) are NOT masked as a 403.
    if (
      error instanceof Error &&
      /row-level security|permission denied/i.test(error.message)
    ) {
      return errorEnvelope("FORBIDDEN", "Child not linked to parent account", 403);
    }
    return mapAttendanceError(error);
  }
}

export async function handleUpdateAttendanceCorrectionStatus(
  req: Request,
  config: AppConfig,
  correctionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  // Approving/rejecting a correction is a governance decision — gate on the
  // approve permission, not plain manageSis (closes an approval-bypass).
  const denied = requireAttendanceApprove(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body required", 422);
  }
  const status = String(body.status ?? "").trim() as AttendanceCorrectionStatus;
  if (!status) {
    return errorEnvelope("ATTENDANCE_VALIDATION", "status is required", 422);
  }

  const { organizationId, schoolId } = tenantIds(auth.claims);
  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      // Read the row BEFORE the flip, in the same transaction, so the audit
      // carries a real before→after instead of only the post-state. It also
      // turns an unknown id into the same clean 404 the UPDATE would raise.
      const before = await getAttendanceCorrection(
        db,
        organizationId,
        schoolId,
        correctionId,
      );
      if (!before) throw new AttendanceCorrectionNotFoundError(correctionId);

      const updated = await updateAttendanceCorrectionStatus(
        db,
        organizationId,
        schoolId,
        correctionId,
        status,
      );

      // The forensic answer to "who approved the change to my child's mark?".
      // Emitted inside the same transaction as the status flip, so the decision
      // and its trail commit together. `updated_at` is the nonce: a legitimate
      // re-decision of the same correction is recorded, not deduped away.
      await emitMutationAudit(
        db,
        auth.claims,
        attendanceAudit.correctionDecided(correctionId, {
          sisStudentId: updated.sis_student_id,
          studentId: updated.student_id,
          dateLabel: updated.date_label,
          before: { status: before.status },
          after: { status: updated.status },
          markChange: { from: updated.from_mark, to: updated.to_mark },
          requestReason: updated.reason,
          requesterId: updated.requester_id,
          requesterRole: updated.requester_role,
          source: CORRECTION_DECISION_SOURCE,
          nonce: timestampNonce(updated.updated_at),
        }),
        req,
      );
      return updated;
    });
    return jsonResponse(envelope(correctionToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    return mapAttendanceError(error);
  }
}
