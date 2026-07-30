// PRC-A Batch 2 — Student Health / Infirmary handlers.
//
// Owner decision #1 (LOCKED 2026-07-15) — strict need-to-know least-privilege.
// THIS FILE IS THE LOAD-BEARING ACCESS CONTROL for the health-staff/teacher
// split. RLS pins rows to the tenant + school and adds a parent-own-child
// branch, but a teacher and a nurse both carry scope='school' with the same
// school_id, so RLS cannot tell them apart. What keeps a teacher out of the
// clinical tables is that `viewStudentHealthRecord` is granted to no teaching
// role and every clinical route demands it here.
//
// The teacher's ONLY health surface is GET …/care-alert, which reads a different
// table (`student_care_alerts`, minimum actionable facts only) and is
// additionally narrowed to students that caller actually teaches.
//
// Each handler is: authenticate → permission-gate → run ONE operation inside a
// single transaction → map to JSON. The transaction bodies live in
// student_health_operations.ts so they are testable against a fake DB.
//
// ⚠ NO CLINICAL DETAIL LEAVES THIS MODULE except through the two
// `viewStudentHealthRecord` routes. Specifically:
//   * nothing here calls console.log/console.error — health rows are never
//     written to request or error logs;
//   * error messages are static strings and never interpolate a complaint,
//     observation, diagnosis, treatment or medication name;
//   * the guardian notification body is a fixed, detail-free constant.
// Keep all three true when editing.

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson, routePath } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { type HealthScope, StudentHealthError } from "./student_health_repository.ts";
import {
  actorFromClaims,
  administerMedicationOp,
  createAuthorizationOp,
  createCareAlertOp,
  listIncidentsOp,
  readCareAlertOp,
  readStudentRecordOp,
  recordIncidentOp,
  revokeAuthorizationOp,
  updateCareAlertOp,
} from "./student_health_operations.ts";
import { listAccessLog } from "./student_health_repository.ts";
import {
  AUTHORIZATION_SOURCES,
  CARE_ALERT_SEVERITIES,
  type CareAlertApi,
  type CareAlertRow,
  HEALTH_PERM_ADMINISTER,
  HEALTH_PERM_MANAGE,
  HEALTH_PERM_VIEW_CARE_ALERT,
  HEALTH_PERM_VIEW_RECORD,
  type HealthIncidentApi,
  type HealthIncidentRow,
  INCIDENT_OUTCOMES,
  INCIDENT_TYPES,
  type MedicationAdministrationApi,
  type MedicationAdministrationRow,
  type MedicationAuthorizationApi,
  type MedicationAuthorizationRow,
} from "./student_health_types.ts";

type Claims = AccessTokenClaims;

function scopeOf(claims: Claims): HealthScope {
  return {
    organizationId: organizationIdFromClaims(claims),
    schoolId: schoolIdFromClaims(claims),
  };
}

function purposeFrom(req: Request, body?: Record<string, unknown>): string {
  const fromBody = body?.purpose;
  if (typeof fromBody === "string" && fromBody.trim()) {
    return fromBody.trim().slice(0, 500);
  }
  const url = new URL(req.url);
  return (url.searchParams.get("purpose") ?? "").trim().slice(0, 500);
}

function requireHealthManager(claims: Claims): Response | null {
  return requireSchoolOperationalScope(claims) ??
    requirePermission(claims, HEALTH_PERM_MANAGE);
}

function requireRecordReader(claims: Claims): Response | null {
  return requireSchoolOperationalScope(claims) ??
    requirePermission(claims, HEALTH_PERM_VIEW_RECORD);
}

function str(v: unknown): string {
  return typeof v === "string" ? v.trim() : "";
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function invalidStudent(): Response {
  return errorEnvelope("VALIDATION_ERROR", "A valid studentId is required", 422);
}

// ─── API mappers ─────────────────────────────────────────────────────────────

/** The ONLY mapper reachable from the teacher route. It has no clinical field. */
export function careAlertToApi(r: CareAlertRow): CareAlertApi {
  return {
    id: r.id,
    studentId: r.student_id,
    label: r.alert_label,
    actionNote: r.action_note,
    severity: r.severity,
  };
}

function incidentToApi(r: HealthIncidentRow): HealthIncidentApi {
  return {
    id: r.id,
    studentId: r.student_id,
    occurredAt: r.occurred_at,
    reportedBy: r.reported_by,
    recordedBy: r.recorded_by,
    incidentType: r.incident_type,
    complaintSummary: r.complaint_summary,
    observations: r.observations,
    treatmentGiven: r.treatment_given,
    outcome: r.outcome,
    referredTo: r.referred_to,
    parentNotifiedAt: r.parent_notified_at,
    parentNotificationRef: r.parent_notification_ref,
  };
}

function authorizationToApi(r: MedicationAuthorizationRow): MedicationAuthorizationApi {
  return {
    id: r.id,
    studentId: r.student_id,
    medicationName: r.medication_name,
    dosage: r.dosage,
    route: r.route,
    scheduleNote: r.schedule_note,
    validFrom: r.valid_from,
    validUntil: r.valid_until,
    authorizedByGuardianId: r.authorized_by_guardian_id,
    authorizationSource: r.authorization_source,
    authorizationRef: r.authorization_ref,
    status: r.status,
    revokedAt: r.revoked_at,
    revokedBy: r.revoked_by,
  };
}

function administrationToApi(r: MedicationAdministrationRow): MedicationAdministrationApi {
  return {
    id: r.id,
    studentId: r.student_id,
    authorizationId: r.authorization_id,
    administeredAt: r.administered_at,
    administeredBy: r.administered_by,
    dosageGiven: r.dosage_given,
    note: r.note,
  };
}

/** Maps domain throws to responses without leaking clinical text. */
function toResponse(error: unknown): Response {
  if (error instanceof TenantDbNotConfiguredError) {
    return tenantDbNotConfiguredResponse(error);
  }
  if (error instanceof StudentHealthError) {
    return errorEnvelope(error.code, error.message, error.status);
  }
  throw error;
}

// ─── POST /student-health/incidents ──────────────────────────────────────────
export async function handleCreateIncident(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireHealthManager(auth.claims);
  if (denied) return denied;

  const body = (await readJson<Record<string, unknown>>(req)) ?? {};
  const studentId = str(body.studentId);
  if (!UUID_RE.test(studentId)) return invalidStudent();

  const incidentType = str(body.incidentType);
  if (!(INCIDENT_TYPES as readonly string[]).includes(incidentType)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `incidentType must be one of: ${INCIDENT_TYPES.join(", ")}`,
      422,
    );
  }
  const outcome = str(body.outcome);
  if (!(INCIDENT_OUTCOMES as readonly string[]).includes(outcome)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `outcome must be one of: ${INCIDENT_OUTCOMES.join(", ")}`,
      422,
    );
  }

  const scope = scopeOf(auth.claims);
  const actor = actorFromClaims(auth.claims, routePath(req), purposeFrom(req, body));

  try {
    const result = await withTenantContext(config, auth.claims, (db) =>
      recordIncidentOp(db, scope, actor, {
        studentId,
        occurredAt: str(body.occurredAt) || null,
        // `reportedBy` is the staff member who flagged it (e.g. the class
        // teacher who sent the child down) — legitimately client-supplied.
        // The AUTHOR (`recorded_by`) is always the token subject.
        reportedBy: UUID_RE.test(str(body.reportedBy)) ? str(body.reportedBy) : null,
        incidentType,
        complaintSummary: str(body.complaintSummary),
        observations: str(body.observations),
        treatmentGiven: str(body.treatmentGiven),
        outcome,
        referredTo: str(body.referredTo) || null,
      }));

    return jsonResponse(
      envelope({
        incident: incidentToApi(result.incident),
        // A count of guardians notified — never a clinical fact.
        notifiedGuardians: result.notifiedGuardians,
      }),
      { status: 201 },
    );
  } catch (error) {
    return toResponse(error);
  }
}

// ─── GET /student-health/incidents?studentId= ────────────────────────────────
export async function handleListIncidents(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireRecordReader(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const studentId = (url.searchParams.get("studentId") ?? "").trim();
  if (!UUID_RE.test(studentId)) return invalidStudent();

  const scope = scopeOf(auth.claims);
  const actor = actorFromClaims(auth.claims, routePath(req), purposeFrom(req));

  try {
    const incidents = await withTenantContext(config, auth.claims, (db) =>
      listIncidentsOp(db, scope, actor, studentId));
    return jsonResponse(envelope({ incidents: incidents.map(incidentToApi) }));
  } catch (error) {
    return toResponse(error);
  }
}

// ─── GET /student-health/students/:studentId/record ──────────────────────────
export async function handleGetStudentRecord(
  req: Request,
  config: AppConfig,
  studentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireRecordReader(auth.claims);
  if (denied) return denied;

  if (!UUID_RE.test(studentId)) return invalidStudent();

  const scope = scopeOf(auth.claims);
  const actor = actorFromClaims(auth.claims, routePath(req), purposeFrom(req));

  try {
    const record = await withTenantContext(config, auth.claims, (db) =>
      readStudentRecordOp(db, scope, actor, studentId));

    return jsonResponse(envelope({
      studentId,
      incidents: record.incidents.map(incidentToApi),
      activeAuthorizations: record.authorizations.map(authorizationToApi),
      recentAdministrations: record.administrations.map(administrationToApi),
      careAlerts: record.careAlerts.map(careAlertToApi),
    }));
  } catch (error) {
    return toResponse(error);
  }
}

// ─── GET /student-health/students/:studentId/care-alert ──────────────────────
/**
 * THE TEACHER SURFACE. Two gates:
 *   1. `viewStudentCareAlert` — teaching roles, health staff, leadership.
 *   2. a caller NOT holding `viewStudentHealthRecord` must actually teach this
 *      student (resolved in `readCareAlertOp`). FAILS CLOSED.
 */
export async function handleGetCareAlert(
  req: Request,
  config: AppConfig,
  studentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const scopeDenied = requireSchoolOperationalScope(auth.claims);
  if (scopeDenied) return scopeDenied;
  const denied = requirePermission(auth.claims, HEALTH_PERM_VIEW_CARE_ALERT);
  if (denied) return denied;

  if (!UUID_RE.test(studentId)) return invalidStudent();

  const scope = scopeOf(auth.claims);
  const actor = actorFromClaims(auth.claims, routePath(req), purposeFrom(req));

  try {
    const alerts = await withTenantContext(config, auth.claims, (db) =>
      readCareAlertOp(db, scope, actor, studentId));

    // careAlertToApi is the ONLY mapper used here — a clinical row has no path
    // into this response.
    return jsonResponse(envelope({
      studentId,
      careAlerts: alerts.map(careAlertToApi),
    }));
  } catch (error) {
    return toResponse(error);
  }
}

// ─── POST /student-health/care-alerts ────────────────────────────────────────
export async function handleCreateCareAlert(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireHealthManager(auth.claims);
  if (denied) return denied;

  const body = (await readJson<Record<string, unknown>>(req)) ?? {};
  const studentId = str(body.studentId);
  if (!UUID_RE.test(studentId)) return invalidStudent();

  const label = str(body.label) || str(body.alertLabel);
  if (label.length < 3) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "A care alert label (>=3 chars) is required",
      422,
    );
  }
  const severity = str(body.severity) || "important";
  if (!(CARE_ALERT_SEVERITIES as readonly string[]).includes(severity)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `severity must be one of: ${CARE_ALERT_SEVERITIES.join(", ")}`,
      422,
    );
  }

  const scope = scopeOf(auth.claims);
  const actor = actorFromClaims(auth.claims, routePath(req), purposeFrom(req, body));

  try {
    const alert = await withTenantContext(config, auth.claims, (db) =>
      createCareAlertOp(db, scope, actor, {
        studentId,
        label,
        actionNote: str(body.actionNote),
        severity,
      }));
    return jsonResponse(envelope({ careAlert: careAlertToApi(alert) }), { status: 201 });
  } catch (error) {
    return toResponse(error);
  }
}

// ─── PATCH /student-health/care-alerts/:id ───────────────────────────────────
export async function handleUpdateCareAlert(
  req: Request,
  config: AppConfig,
  alertId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireHealthManager(auth.claims);
  if (denied) return denied;

  if (!UUID_RE.test(alertId)) {
    return errorEnvelope("VALIDATION_ERROR", "A valid care alert id is required", 422);
  }

  const body = (await readJson<Record<string, unknown>>(req)) ?? {};
  const severity = str(body.severity);
  if (severity && !(CARE_ALERT_SEVERITIES as readonly string[]).includes(severity)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `severity must be one of: ${CARE_ALERT_SEVERITIES.join(", ")}`,
      422,
    );
  }
  const label = str(body.label) || str(body.alertLabel);

  const scope = scopeOf(auth.claims);
  const actor = actorFromClaims(auth.claims, routePath(req), purposeFrom(req, body));

  try {
    const alert = await withTenantContext(config, auth.claims, (db) =>
      updateCareAlertOp(db, scope, actor, alertId, {
        alertLabel: label || null,
        actionNote: typeof body.actionNote === "string" ? str(body.actionNote) : null,
        severity: severity || null,
        isActive: typeof body.isActive === "boolean" ? body.isActive : null,
      }));
    return jsonResponse(envelope({ careAlert: careAlertToApi(alert) }));
  } catch (error) {
    return toResponse(error);
  }
}

// ─── POST /student-health/authorizations ─────────────────────────────────────
export async function handleCreateAuthorization(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireHealthManager(auth.claims);
  if (denied) return denied;

  const body = (await readJson<Record<string, unknown>>(req)) ?? {};
  const studentId = str(body.studentId);
  if (!UUID_RE.test(studentId)) return invalidStudent();

  const medicationName = str(body.medicationName);
  if (medicationName.length < 2) {
    return errorEnvelope("VALIDATION_ERROR", "medicationName is required", 422);
  }
  const dosage = str(body.dosage);
  if (!dosage) {
    return errorEnvelope("VALIDATION_ERROR", "dosage is required", 422);
  }
  const validFrom = str(body.validFrom);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(validFrom)) {
    return errorEnvelope("VALIDATION_ERROR", "validFrom (YYYY-MM-DD) is required", 422);
  }
  const validUntil = str(body.validUntil);
  if (validUntil && !/^\d{4}-\d{2}-\d{2}$/.test(validUntil)) {
    return errorEnvelope("VALIDATION_ERROR", "validUntil must be YYYY-MM-DD", 422);
  }
  if (validUntil && validUntil < validFrom) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "validUntil must not be before validFrom",
      422,
    );
  }
  // CONSENT PROVENANCE — the point of the record. An authorization that cannot
  // say HOW the guardian consented is not an authorization, so both the source
  // and a reference to the artefact are mandatory.
  const authorizationSource = str(body.authorizationSource);
  if (!(AUTHORIZATION_SOURCES as readonly string[]).includes(authorizationSource)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `authorizationSource must be one of: ${AUTHORIZATION_SOURCES.join(", ")}`,
      422,
    );
  }
  const authorizationRef = str(body.authorizationRef);
  if (authorizationRef.length < 2) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "authorizationRef is required — record how the guardian's consent was obtained",
      422,
    );
  }

  const scope = scopeOf(auth.claims);
  const actor = actorFromClaims(auth.claims, routePath(req), purposeFrom(req, body));

  try {
    const created = await withTenantContext(config, auth.claims, (db) =>
      createAuthorizationOp(db, scope, actor, {
        studentId,
        medicationName,
        dosage,
        route: str(body.route) || "oral",
        scheduleNote: str(body.scheduleNote),
        validFrom,
        validUntil: validUntil || null,
        authorizedByGuardianId: str(body.authorizedByGuardianId) || null,
        authorizationSource,
        authorizationRef,
      }));
    return jsonResponse(
      envelope({ authorization: authorizationToApi(created) }),
      { status: 201 },
    );
  } catch (error) {
    return toResponse(error);
  }
}

// ─── POST /student-health/authorizations/:id/revoke ──────────────────────────
export async function handleRevokeAuthorization(
  req: Request,
  config: AppConfig,
  authorizationId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireHealthManager(auth.claims);
  if (denied) return denied;

  if (!UUID_RE.test(authorizationId)) {
    return errorEnvelope("VALIDATION_ERROR", "A valid authorization id is required", 422);
  }

  const body = (await readJson<Record<string, unknown>>(req)) ?? {};
  const scope = scopeOf(auth.claims);
  const actor = actorFromClaims(auth.claims, routePath(req), purposeFrom(req, body));

  try {
    const revoked = await withTenantContext(config, auth.claims, (db) =>
      revokeAuthorizationOp(db, scope, actor, authorizationId));
    return jsonResponse(envelope({ authorization: authorizationToApi(revoked) }));
  } catch (error) {
    return toResponse(error);
  }
}

// ─── POST /student-health/authorizations/:id/administer ──────────────────────
export async function handleAdministerMedication(
  req: Request,
  config: AppConfig,
  authorizationId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const scopeDenied = requireSchoolOperationalScope(auth.claims);
  if (scopeDenied) return scopeDenied;
  const denied = requirePermission(auth.claims, HEALTH_PERM_ADMINISTER);
  if (denied) return denied;

  if (!UUID_RE.test(authorizationId)) {
    return errorEnvelope("VALIDATION_ERROR", "A valid authorization id is required", 422);
  }

  const body = (await readJson<Record<string, unknown>>(req)) ?? {};
  const dosageGiven = str(body.dosageGiven);
  if (!dosageGiven) {
    return errorEnvelope("VALIDATION_ERROR", "dosageGiven is required", 422);
  }

  const scope = scopeOf(auth.claims);
  const actor = actorFromClaims(auth.claims, routePath(req), purposeFrom(req, body));

  try {
    const administered = await withTenantContext(config, auth.claims, (db) =>
      administerMedicationOp(db, scope, actor, {
        authorizationId,
        // Optional client assertion — cross-checked, never trusted.
        expectedStudentId: str(body.studentId) || null,
        dosageGiven,
        note: str(body.note),
      }));
    return jsonResponse(
      envelope({ administration: administrationToApi(administered) }),
      { status: 201 },
    );
  } catch (error) {
    return toResponse(error);
  }
}

// ─── GET /student-health/access-log?studentId= ───────────────────────────────
/**
 * Who accessed this child's health data. Gated on `viewStudentHealthRecord` —
 * the log reveals that a child HAS a health record and which staff read it, so
 * it is at least as sensitive as the record itself.
 *
 * Reading the access log is NOT itself audited: an audit of the audit would
 * recurse, and this read is already confined to the care team. Called out rather
 * than glossed over.
 */
export async function handleListAccessLog(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireRecordReader(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const studentId = (url.searchParams.get("studentId") ?? "").trim();
  if (!UUID_RE.test(studentId)) return invalidStudent();

  const scope = scopeOf(auth.claims);

  try {
    const rows = await withTenantContext(
      config,
      auth.claims,
      (db) => listAccessLog(db, scope, studentId),
    );
    return jsonResponse(envelope({
      studentId,
      entries: rows.map((r) => ({
        id: r.id,
        actorId: r.actor_id,
        actorRole: r.actor_role,
        accessKind: r.access_kind,
        route: r.route,
        purpose: r.purpose,
        occurredAt: r.occurred_at,
      })),
    }));
  } catch (error) {
    return toResponse(error);
  }
}
