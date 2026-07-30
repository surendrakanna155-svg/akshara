// W4 Staff Duty — list/create handlers for the three dedicated duty tables.
//
//   POST /hr/staff-duties/substitutions      record a substitute class   (manageHr)
//   GET  /hr/staff-duties/substitutions      list by ?staffId= or ?date= (viewHr|manageHr)
//   POST /hr/staff-duties/invigilations      record an invigilation duty (manageHr)
//   GET  /hr/staff-duties/invigilations      list by ?staffId= or ?date= (viewHr|manageHr)
//   POST /hr/staff-duties/non-teaching       record a non-teaching duty  (manageHr)
//   GET  /hr/staff-duties/non-teaching       list by ?staffId= or ?date= (viewHr|manageHr)
//   GET  /hr/staff-duties/rollup             per-teacher duty-count rollup (viewHr|manageHr)
//
// RBAC reuses the existing HR-management permissions (manageHr to write, viewHr
// OR manageHr to read) — staff duties are an HR / staff-workload concern. Every
// write audits via moduleEntityAudit INSIDE the tenant transaction, so the audit
// row and the duty row commit (or roll back) together.

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requireAnyPermission,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import {
  createExamInvigilationDuty,
  createNonTeachingDuty,
  createSubstituteClass,
  type ExamInvigilationDutyRow,
  listExamInvigilationDutiesByDate,
  listExamInvigilationDutiesByStaff,
  listNonTeachingDutiesByDate,
  listNonTeachingDutiesByStaff,
  listSubstituteClassesByDate,
  listSubstituteClassesByStaff,
  type NonTeachingDutyRow,
  type StaffDutyScope,
  type SubstituteClassRow,
} from "./staff_duty_repository.ts";
import { buildStaffDutyRollup } from "./staff_duty_rollup.ts";

const WRITE_PERMISSION = "manageHr";
const READ_PERMISSIONS = ["viewHr", "manageHr"];

function requireWriter(claims: AccessTokenClaims): Response | null {
  return requirePermission(claims, WRITE_PERMISSION) ??
    requireSchoolOperationalScope(claims, "Staff duty");
}

function requireReader(claims: AccessTokenClaims): Response | null {
  return requireAnyPermission(claims, READ_PERMISSIONS) ??
    requireSchoolOperationalScope(claims, "Staff duty");
}

function subjectOf(claims: AccessTokenClaims): string {
  return String(claims.sub ?? "");
}

function scopeOf(claims: AccessTokenClaims): StaffDutyScope {
  return {
    organizationId: organizationIdFromClaims(claims),
    schoolId: schoolIdFromClaims(claims),
  };
}

function parseLimit(url: URL): number {
  const raw = Number(url.searchParams.get("limit") ?? "100");
  return Number.isFinite(raw) ? Math.min(500, Math.max(1, Math.trunc(raw))) : 100;
}

/** A duty date must be a plain ISO date (YYYY-MM-DD). */
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

function str(body: Record<string, unknown>, key: string): string {
  const v = body[key];
  return typeof v === "string" ? v.trim() : "";
}

async function readBody(req: Request): Promise<Record<string, unknown> | null> {
  try {
    return (await readJson<Record<string, unknown>>(req)) ?? {};
  } catch {
    return null;
  }
}

function dbErrorResponse(error: unknown): Response {
  if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
  throw error;
}

// ─── API projections (snake_case row → camelCase api) ───────────────────────

function substituteToApi(r: SubstituteClassRow) {
  return {
    id: r.id,
    absentTeacherId: r.absent_teacher_id,
    substituteTeacherId: r.substitute_teacher_id,
    dutyDate: r.duty_date,
    periodLabel: r.period_label,
    timetablePeriodId: r.timetable_period_id,
    reason: r.reason,
    createdBy: r.created_by,
    createdAt: r.created_at,
  };
}

function invigilationToApi(r: ExamInvigilationDutyRow) {
  return {
    id: r.id,
    staffId: r.staff_id,
    examId: r.exam_id,
    examLabel: r.exam_label,
    dutyDate: r.duty_date,
    room: r.room,
    session: r.session,
    createdBy: r.created_by,
    createdAt: r.created_at,
  };
}

function nonTeachingToApi(r: NonTeachingDutyRow) {
  return {
    id: r.id,
    staffId: r.staff_id,
    dutyType: r.duty_type,
    startDate: r.start_date,
    endDate: r.end_date,
    description: r.description,
    createdBy: r.created_by,
    createdAt: r.created_at,
  };
}

// ─── Substitute classes (cap 131) ───────────────────────────────────────────

export async function handleCreateSubstituteClass(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireWriter(auth.claims);
  if (denied) return denied;

  const body = await readBody(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  const absentTeacherId = str(body, "absentTeacherId");
  const substituteTeacherId = str(body, "substituteTeacherId");
  const dutyDate = str(body, "dutyDate");
  if (!absentTeacherId || !substituteTeacherId) {
    return errorEnvelope("STAFF_DUTY_TEACHER_REQUIRED", "absentTeacherId and substituteTeacherId are required", 422);
  }
  if (!ISO_DATE.test(dutyDate)) {
    return errorEnvelope("STAFF_DUTY_DATE_REQUIRED", "dutyDate (YYYY-MM-DD) is required", 422);
  }

  const scope = scopeOf(auth.claims);
  const createdBy = subjectOf(auth.claims);
  try {
    const created = await withTenantContext(config, auth.claims, async (db) => {
      const row = await createSubstituteClass(db, scope, {
        absentTeacherId,
        substituteTeacherId,
        dutyDate,
        periodLabel: str(body, "periodLabel"),
        timetablePeriodId: str(body, "timetablePeriodId") || null,
        reason: str(body, "reason"),
        createdBy,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("staffduty.substitute_class.created", "staff_substitute_class", row.id, {
          substituteTeacherId,
          absentTeacherId,
          dutyDate,
        }),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(substituteToApi(created)), { status: 201 });
  } catch (error) {
    return dbErrorResponse(error);
  }
}

export async function handleListSubstituteClasses(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireReader(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const staffId = (url.searchParams.get("staffId") ?? "").trim();
  const date = (url.searchParams.get("date") ?? "").trim();
  if (!staffId && !date) {
    return errorEnvelope("STAFF_DUTY_FILTER_REQUIRED", "Provide ?staffId= or ?date=", 422);
  }
  const limit = parseLimit(url);
  const scope = scopeOf(auth.claims);
  try {
    const rows = await withTenantContext(config, auth.claims, (db) =>
      staffId
        ? listSubstituteClassesByStaff(db, scope, staffId, limit)
        : listSubstituteClassesByDate(db, scope, date, limit));
    return jsonResponse(envelope({ items: rows.map(substituteToApi), count: rows.length }));
  } catch (error) {
    return dbErrorResponse(error);
  }
}

// ─── Exam invigilation duties (cap 133) ─────────────────────────────────────

export async function handleCreateInvigilationDuty(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireWriter(auth.claims);
  if (denied) return denied;

  const body = await readBody(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  const staffId = str(body, "staffId");
  const dutyDate = str(body, "dutyDate");
  if (!staffId) return errorEnvelope("STAFF_DUTY_STAFF_REQUIRED", "staffId is required", 422);
  if (!ISO_DATE.test(dutyDate)) {
    return errorEnvelope("STAFF_DUTY_DATE_REQUIRED", "dutyDate (YYYY-MM-DD) is required", 422);
  }

  const scope = scopeOf(auth.claims);
  const createdBy = subjectOf(auth.claims);
  try {
    const created = await withTenantContext(config, auth.claims, async (db) => {
      const row = await createExamInvigilationDuty(db, scope, {
        staffId,
        examId: str(body, "examId") || null,
        examLabel: str(body, "examLabel"),
        dutyDate,
        room: str(body, "room"),
        session: str(body, "session"),
        createdBy,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("staffduty.exam_invigilation.created", "staff_exam_invigilation_duty", row.id, {
          staffId,
          dutyDate,
          room: row.room,
        }),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(invigilationToApi(created)), { status: 201 });
  } catch (error) {
    return dbErrorResponse(error);
  }
}

export async function handleListInvigilationDuties(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireReader(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const staffId = (url.searchParams.get("staffId") ?? "").trim();
  const date = (url.searchParams.get("date") ?? "").trim();
  if (!staffId && !date) {
    return errorEnvelope("STAFF_DUTY_FILTER_REQUIRED", "Provide ?staffId= or ?date=", 422);
  }
  const limit = parseLimit(url);
  const scope = scopeOf(auth.claims);
  try {
    const rows = await withTenantContext(config, auth.claims, (db) =>
      staffId
        ? listExamInvigilationDutiesByStaff(db, scope, staffId, limit)
        : listExamInvigilationDutiesByDate(db, scope, date, limit));
    return jsonResponse(envelope({ items: rows.map(invigilationToApi), count: rows.length }));
  } catch (error) {
    return dbErrorResponse(error);
  }
}

// ─── Non-teaching duties (cap 132) ──────────────────────────────────────────

export async function handleCreateNonTeachingDuty(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireWriter(auth.claims);
  if (denied) return denied;

  const body = await readBody(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  const staffId = str(body, "staffId");
  const dutyType = str(body, "dutyType");
  const startDate = str(body, "startDate");
  const endDate = str(body, "endDate") || null;
  if (!staffId) return errorEnvelope("STAFF_DUTY_STAFF_REQUIRED", "staffId is required", 422);
  if (!dutyType) return errorEnvelope("STAFF_DUTY_TYPE_REQUIRED", "dutyType is required", 422);
  if (!ISO_DATE.test(startDate)) {
    return errorEnvelope("STAFF_DUTY_DATE_REQUIRED", "startDate (YYYY-MM-DD) is required", 422);
  }
  if (endDate !== null) {
    if (!ISO_DATE.test(endDate)) {
      return errorEnvelope("STAFF_DUTY_DATE_INVALID", "endDate must be YYYY-MM-DD", 422);
    }
    if (endDate < startDate) {
      return errorEnvelope("STAFF_DUTY_RANGE_INVALID", "endDate must be on or after startDate", 422);
    }
  }

  const scope = scopeOf(auth.claims);
  const createdBy = subjectOf(auth.claims);
  try {
    const created = await withTenantContext(config, auth.claims, async (db) => {
      const row = await createNonTeachingDuty(db, scope, {
        staffId,
        dutyType,
        startDate,
        endDate,
        description: str(body, "description"),
        createdBy,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("staffduty.non_teaching_duty.created", "staff_non_teaching_duty", row.id, {
          staffId,
          dutyType,
          startDate,
          endDate,
        }),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(nonTeachingToApi(created)), { status: 201 });
  } catch (error) {
    return dbErrorResponse(error);
  }
}

export async function handleListNonTeachingDuties(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireReader(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const staffId = (url.searchParams.get("staffId") ?? "").trim();
  const date = (url.searchParams.get("date") ?? "").trim();
  if (!staffId && !date) {
    return errorEnvelope("STAFF_DUTY_FILTER_REQUIRED", "Provide ?staffId= or ?date=", 422);
  }
  const limit = parseLimit(url);
  const scope = scopeOf(auth.claims);
  try {
    const rows = await withTenantContext(config, auth.claims, (db) =>
      staffId
        ? listNonTeachingDutiesByStaff(db, scope, staffId, limit)
        : listNonTeachingDutiesByDate(db, scope, date, limit));
    return jsonResponse(envelope({ items: rows.map(nonTeachingToApi), count: rows.length }));
  } catch (error) {
    return dbErrorResponse(error);
  }
}

// ─── Rollup (caps 131/132/133 — staff workload intelligence) ────────────────

export async function handleStaffDutyRollup(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireReader(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const from = (url.searchParams.get("from") ?? "").trim() || null;
  const to = (url.searchParams.get("to") ?? "").trim() || null;
  if (from !== null && !ISO_DATE.test(from)) {
    return errorEnvelope("STAFF_DUTY_DATE_INVALID", "from must be YYYY-MM-DD", 422);
  }
  if (to !== null && !ISO_DATE.test(to)) {
    return errorEnvelope("STAFF_DUTY_DATE_INVALID", "to must be YYYY-MM-DD", 422);
  }

  const scope = scopeOf(auth.claims);
  try {
    const rollup = await withTenantContext(config, auth.claims, (db) =>
      buildStaffDutyRollup(db, scope.organizationId, scope.schoolId, { from, to }));
    return jsonResponse(envelope(rollup));
  } catch (error) {
    return dbErrorResponse(error);
  }
}
