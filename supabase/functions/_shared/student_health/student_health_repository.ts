// PRC-A Batch 2 — Student Health / Infirmary repository.
//
// Owner decision #1 (LOCKED 2026-07-15). Two invariants run through this file:
//
//   1. AUDIT IS IN-TRANSACTION. `logHealthAccess` is called on the same
//      `TenantQueryClient` as the read/write it records, inside the single
//      implicit transaction `withTenantContext` opens. If the operation rolls
//      back, its audit row rolls back with it — the log never claims an access
//      that did not happen, and an access can never happen without its log.
//
//   2. TERMINAL WRITES ARE GUARDED. This project has a recurring defect class:
//      a terminal state-write with no status guard lets two concurrent requests
//      both "win" and double-apply. Every terminal write here re-asserts the
//      expected pre-state in the WHERE clause (`AND status = 'active'`,
//      `AND is_active = true`) and throws when it matches 0 rows, so the loser
//      of a race rolls the whole transaction back and writes nothing.

import type { TenantQueryClient } from "../tenant_db.ts";
import type {
  CareAlertRow,
  HealthAccessKind,
  HealthAccessLogRow,
  HealthIncidentRow,
  MedicationAdministrationRow,
  MedicationAuthorizationRow,
} from "./student_health_types.ts";

/** A domain error carrying the HTTP status the handler should surface. */
export class StudentHealthError extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly status = 422,
  ) {
    super(message);
    this.name = "StudentHealthError";
  }
}

export interface HealthScope {
  organizationId: string;
  schoolId: string;
}

// ─── Audit ───────────────────────────────────────────────────────────────────

export interface LogHealthAccessInput {
  studentId: string;
  actorId: string;
  actorRole: string;
  accessKind: HealthAccessKind;
  route: string;
  purpose: string;
}

/**
 * Append one immutable access-log row. MUST be called on the same `db` (i.e. the
 * same transaction) as the operation it records.
 *
 * ⚠ Records SUCCESSFUL accesses only. A denied attempt throws before reaching
 * here, and even if it did not, the rollback would erase the row. Recording
 * denied attempts needs a separate out-of-transaction sink and an extra
 * `access_kind` value — flagged to the owner, not silently faked here.
 */
export async function logHealthAccess(
  db: TenantQueryClient,
  scope: HealthScope,
  input: LogHealthAccessInput,
): Promise<void> {
  await db.queryObject(
    `INSERT INTO student_health_access_log
       (organization_id, school_id, student_id, actor_id, actor_role,
        access_kind, route, purpose)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
    [
      scope.organizationId,
      scope.schoolId,
      input.studentId,
      input.actorId,
      input.actorRole,
      input.accessKind,
      input.route,
      input.purpose,
    ],
  );
}

export async function listAccessLog(
  db: TenantQueryClient,
  scope: HealthScope,
  studentId: string,
  limit = 200,
): Promise<HealthAccessLogRow[]> {
  return await db.queryObject<HealthAccessLogRow>(
    `SELECT id, student_id, actor_id, actor_role, access_kind, route, purpose,
            occurred_at
       FROM student_health_access_log
      WHERE organization_id = $1 AND school_id = $2 AND student_id = $3
      ORDER BY occurred_at DESC
      LIMIT $4`,
    [scope.organizationId, scope.schoolId, studentId, limit],
  );
}

// ─── Teacher → students they actually teach ──────────────────────────────────

/**
 * Owner decision #1: a teacher may see a care alert only for students they
 * actually teach — never "any student in the school".
 *
 * Two independent links exist in this codebase and BOTH are honoured, because
 * neither alone covers every school:
 *
 *   * `teacher_assignments (teacher_id → users.id, section_id, role)` — the
 *     academic-foundation roster (class_teacher / subject_teacher / coordinator).
 *   * `timetable_slots (teacher_user_id | substitute_teacher_user_id, section_id)`
 *     — the operational timetable; a substitute standing in front of the class
 *     today needs the allergy alert as much as the permanent teacher does.
 *
 * The JWT `sub` IS the teacher key in both tables (`teacher_assignments.teacher_id`
 * and `timetable_slots.teacher_user_id` both reference `users.id` directly) —
 * there is no employees/staff indirection to bridge.
 *
 * ⚠ `sis_student_enrollments.section_id` is a NULLABLE soft FK (added by
 * 20260618000000_academic_soft_fk.sql); older enrollments carry only the
 * `class_name`/`section_name` TEXT pair. A section_id-only join would silently
 * deny every teacher on a school whose enrollments predate the soft FK — a
 * fail-closed bug that looks like a permissions problem. So the text-label link
 * is included as a second branch, mirroring `isClassTeacherForExam`
 * (exam_administration_repository.ts:1627).
 *
 * Fails CLOSED: no resolvable link → 0 → deny.
 */
export async function teacherTeachesStudent(
  db: TenantQueryClient,
  scope: HealthScope,
  teacherUserId: string,
  studentId: string,
): Promise<boolean> {
  const count = await db.queryCount(
    `SELECT count(*)::text AS count FROM (
       -- (a) roster link on the section_id soft FK
       SELECT 1
         FROM sis_student_enrollments e
         JOIN teacher_assignments ta
           ON ta.section_id = e.section_id
          AND ta.organization_id = e.organization_id
          AND ta.school_id = e.school_id
        WHERE e.organization_id = $1 AND e.school_id = $2
          AND e.student_id = $3 AND e.is_current = true
          AND ta.teacher_id = $4
       UNION ALL
       -- (b) roster link on the class/section TEXT labels (section_id may be NULL)
       SELECT 1
         FROM sis_student_enrollments e
         JOIN teacher_assignments ta
           ON ta.organization_id = e.organization_id
          AND ta.school_id = e.school_id
         JOIN sections sec ON sec.id = ta.section_id
         JOIN classes c ON c.id = sec.class_id
        WHERE e.organization_id = $1 AND e.school_id = $2
          AND e.student_id = $3 AND e.is_current = true
          AND ta.teacher_id = $4
          AND c.class_name = e.class_name
          AND sec.section_name IS NOT DISTINCT FROM e.section_name
       UNION ALL
       -- (c) timetable link, including today's substitute
       SELECT 1
         FROM sis_student_enrollments e
         JOIN timetable_slots ts
           ON ts.section_id = e.section_id
          AND ts.organization_id = e.organization_id
          AND ts.school_id = e.school_id
        WHERE e.organization_id = $1 AND e.school_id = $2
          AND e.student_id = $3 AND e.is_current = true
          AND (ts.teacher_user_id = $4 OR ts.substitute_teacher_user_id = $4)
     ) links`,
    [scope.organizationId, scope.schoolId, studentId, teacherUserId],
  );
  return count > 0;
}

/** Active guardians for a student — the notification recipients. */
export async function listGuardianUserIdsForStudent(
  db: TenantQueryClient,
  scope: HealthScope,
  studentId: string,
): Promise<string[]> {
  const rows = await db.queryObject<{ guardian_user_id: string }>(
    `SELECT guardian_user_id
       FROM student_guardians
      WHERE organization_id = $1 AND school_id = $2 AND student_id = $3
        AND status = 'active'`,
    [scope.organizationId, scope.schoolId, studentId],
  );
  return rows.map((r) => r.guardian_user_id);
}

/** Guards that the student exists in THIS org+school before any health write. */
export async function studentExistsInSchool(
  db: TenantQueryClient,
  scope: HealthScope,
  studentId: string,
): Promise<boolean> {
  const count = await db.queryCount(
    `SELECT count(*)::text AS count
       FROM students
      WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [studentId, scope.organizationId, scope.schoolId],
  );
  return count > 0;
}

// ─── Incidents ───────────────────────────────────────────────────────────────

export interface CreateIncidentInput {
  studentId: string;
  occurredAt?: string | null;
  reportedBy?: string | null;
  recordedBy: string;
  incidentType: string;
  complaintSummary: string;
  observations: string;
  treatmentGiven: string;
  outcome: string;
  referredTo?: string | null;
}

export async function createIncident(
  db: TenantQueryClient,
  scope: HealthScope,
  input: CreateIncidentInput,
): Promise<HealthIncidentRow> {
  const rows = await db.queryObject<HealthIncidentRow>(
    `INSERT INTO student_health_incidents
       (organization_id, school_id, student_id, occurred_at, reported_by,
        recorded_by, incident_type, complaint_summary, observations,
        treatment_given, outcome, referred_to)
     VALUES ($1, $2, $3, COALESCE($4::timestamptz, timezone('utc', now())), $5,
             $6, $7, $8, $9, $10, $11, $12)
     RETURNING id, student_id, occurred_at, reported_by, recorded_by,
               incident_type, complaint_summary, observations, treatment_given,
               outcome, referred_to, parent_notified_at, parent_notification_ref,
               created_at`,
    [
      scope.organizationId,
      scope.schoolId,
      input.studentId,
      input.occurredAt ?? null,
      input.reportedBy ?? null,
      input.recordedBy,
      input.incidentType,
      input.complaintSummary,
      input.observations,
      input.treatmentGiven,
      input.outcome,
      input.referredTo ?? null,
    ],
  );
  const row = rows[0];
  if (!row) {
    throw new StudentHealthError(
      "INCIDENT_NOT_CREATED",
      "Incident insert returned no row",
      500,
    );
  }
  return row;
}

/** Records that the guardian dispatch happened, and its delivery ref. */
export async function markIncidentParentNotified(
  db: TenantQueryClient,
  scope: HealthScope,
  incidentId: string,
  notificationRef: string,
): Promise<void> {
  await db.queryObject(
    `UPDATE student_health_incidents
        SET parent_notified_at = timezone('utc', now()),
            parent_notification_ref = $4
      WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [incidentId, scope.organizationId, scope.schoolId, notificationRef],
  );
}

export async function listIncidents(
  db: TenantQueryClient,
  scope: HealthScope,
  studentId: string,
  limit = 200,
): Promise<HealthIncidentRow[]> {
  return await db.queryObject<HealthIncidentRow>(
    `SELECT id, student_id, occurred_at, reported_by, recorded_by, incident_type,
            complaint_summary, observations, treatment_given, outcome,
            referred_to, parent_notified_at, parent_notification_ref, created_at
       FROM student_health_incidents
      WHERE organization_id = $1 AND school_id = $2 AND student_id = $3
      ORDER BY occurred_at DESC
      LIMIT $4`,
    [scope.organizationId, scope.schoolId, studentId, limit],
  );
}

// ─── Medication authorizations ───────────────────────────────────────────────

export interface CreateAuthorizationInput {
  studentId: string;
  medicationName: string;
  dosage: string;
  route: string;
  scheduleNote: string;
  validFrom: string;
  validUntil?: string | null;
  authorizedByGuardianId?: string | null;
  authorizationSource: string;
  authorizationRef: string;
  createdBy: string;
}

export async function createAuthorization(
  db: TenantQueryClient,
  scope: HealthScope,
  input: CreateAuthorizationInput,
): Promise<MedicationAuthorizationRow> {
  const rows = await db.queryObject<MedicationAuthorizationRow>(
    `INSERT INTO student_medication_authorizations
       (organization_id, school_id, student_id, medication_name, dosage, route,
        schedule_note, valid_from, valid_until, authorized_by_guardian_id,
        authorization_source, authorization_ref, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8::date, $9::date, $10, $11, $12, $13)
     RETURNING id, student_id, medication_name, dosage, route, schedule_note,
               valid_from::text AS valid_from, valid_until::text AS valid_until,
               authorized_by_guardian_id, authorization_source, authorization_ref,
               status, revoked_at, revoked_by, created_by, created_at`,
    [
      scope.organizationId,
      scope.schoolId,
      input.studentId,
      input.medicationName,
      input.dosage,
      input.route,
      input.scheduleNote,
      input.validFrom,
      input.validUntil ?? null,
      input.authorizedByGuardianId ?? null,
      input.authorizationSource,
      input.authorizationRef,
      input.createdBy,
    ],
  );
  const row = rows[0];
  if (!row) {
    throw new StudentHealthError(
      "AUTHORIZATION_NOT_CREATED",
      "Authorization insert returned no row",
      500,
    );
  }
  return row;
}

export async function listActiveAuthorizations(
  db: TenantQueryClient,
  scope: HealthScope,
  studentId: string,
): Promise<MedicationAuthorizationRow[]> {
  return await db.queryObject<MedicationAuthorizationRow>(
    `SELECT id, student_id, medication_name, dosage, route, schedule_note,
            valid_from::text AS valid_from, valid_until::text AS valid_until,
            authorized_by_guardian_id, authorization_source, authorization_ref,
            status, revoked_at, revoked_by, created_by, created_at
       FROM student_medication_authorizations
      WHERE organization_id = $1 AND school_id = $2 AND student_id = $3
        AND status = 'active'
      ORDER BY created_at DESC`,
    [scope.organizationId, scope.schoolId, studentId],
  );
}

/**
 * Terminal write — REVOKE. `AND status = 'active'` is the race guard: two
 * concurrent revokes both read 'active', but only one UPDATE matches a row; the
 * loser matches 0, throws, and `withTenantContext` rolls its transaction back so
 * it writes nothing at all (including its audit row).
 */
export async function revokeAuthorization(
  db: TenantQueryClient,
  scope: HealthScope,
  authorizationId: string,
  revokedBy: string,
): Promise<MedicationAuthorizationRow> {
  const rows = await db.queryObject<MedicationAuthorizationRow>(
    `UPDATE student_medication_authorizations
        SET status = 'revoked',
            revoked_at = timezone('utc', now()),
            revoked_by = $4
      WHERE id = $1 AND organization_id = $2 AND school_id = $3
        AND status = 'active'
      RETURNING id, student_id, medication_name, dosage, route, schedule_note,
                valid_from::text AS valid_from, valid_until::text AS valid_until,
                authorized_by_guardian_id, authorization_source,
                authorization_ref, status, revoked_at, revoked_by, created_by,
                created_at`,
    [authorizationId, scope.organizationId, scope.schoolId, revokedBy],
  );
  const row = rows[0];
  if (!row) {
    // Either it does not exist in this org+school, or it is already
    // revoked/expired. Both are "not an active authorization to revoke".
    throw new StudentHealthError(
      "AUTHORIZATION_NOT_ACTIVE",
      "No active medication authorization matched — it may have been revoked already",
      409,
    );
  }
  return row;
}

interface AuthorizationProbe {
  id: string;
  student_id: string;
  status: string;
  valid_from: string;
  valid_until: string | null;
  medication_name: string;
  today: string;
}

/**
 * Reads the authorization together with the DATABASE's idea of today, so the
 * validity-window decision never depends on an edge worker's clock.
 */
export async function probeAuthorization(
  db: TenantQueryClient,
  scope: HealthScope,
  authorizationId: string,
): Promise<AuthorizationProbe | null> {
  const rows = await db.queryObject<AuthorizationProbe>(
    `SELECT a.id, a.student_id, a.status,
            a.valid_from::text AS valid_from, a.valid_until::text AS valid_until,
            a.medication_name, CURRENT_DATE::text AS today
       FROM student_medication_authorizations a
      WHERE a.id = $1 AND a.organization_id = $2 AND a.school_id = $3`,
    [authorizationId, scope.organizationId, scope.schoolId],
  );
  return rows[0] ?? null;
}

export interface AdministerInput {
  authorizationId: string;
  /** Optional client assertion of the student — cross-checked, never trusted. */
  expectedStudentId?: string | null;
  administeredBy: string;
  dosageGiven: string;
  note: string;
}

/**
 * Administer a medication against a guardian authorization.
 *
 * Never administers against an expired/revoked/foreign authorization. Two layers:
 *
 *   1. `probeAuthorization` gives a PRECISE 422 (revoked vs out-of-window vs
 *      wrong student) so the health-staff member knows why they were stopped.
 *   2. The INSERT itself is `INSERT … SELECT … WHERE status='active' AND window`
 *      — the guard is re-asserted ATOMICALLY at write time, so a revoke landing
 *      between the probe and the insert still stops the dose. 0 rows → throw.
 *
 * `student_id` is taken from the authorization row (`a.student_id`), NOT from the
 * request: the log physically cannot attach a dose to a different child than the
 * one whose guardian consented.
 */
export async function administerMedication(
  db: TenantQueryClient,
  scope: HealthScope,
  input: AdministerInput,
): Promise<MedicationAdministrationRow> {
  const probe = await probeAuthorization(db, scope, input.authorizationId);
  if (!probe) {
    throw new StudentHealthError(
      "AUTHORIZATION_NOT_FOUND",
      "Medication authorization not found in this school",
      404,
    );
  }
  if (
    input.expectedStudentId && input.expectedStudentId !== probe.student_id
  ) {
    throw new StudentHealthError(
      "AUTHORIZATION_STUDENT_MISMATCH",
      "This medication authorization belongs to a different student",
      422,
    );
  }
  if (probe.status !== "active") {
    throw new StudentHealthError(
      "AUTHORIZATION_NOT_ACTIVE",
      `Medication authorization is ${probe.status} — it must not be administered`,
      422,
    );
  }
  // ISO dates compare correctly as strings; `today` comes from the DB.
  if (probe.valid_from > probe.today) {
    throw new StudentHealthError(
      "AUTHORIZATION_NOT_YET_VALID",
      "Medication authorization is not valid yet",
      422,
    );
  }
  if (probe.valid_until !== null && probe.valid_until < probe.today) {
    throw new StudentHealthError(
      "AUTHORIZATION_EXPIRED",
      "Medication authorization has expired — it must not be administered",
      422,
    );
  }

  const rows = await db.queryObject<MedicationAdministrationRow>(
    `INSERT INTO student_medication_administration_log
       (organization_id, school_id, student_id, authorization_id,
        administered_by, dosage_given, note)
     SELECT $1, $2, a.student_id, a.id, $4, $5, $6
       FROM student_medication_authorizations a
      WHERE a.id = $3 AND a.organization_id = $1 AND a.school_id = $2
        AND a.status = 'active'
        AND a.valid_from <= CURRENT_DATE
        AND (a.valid_until IS NULL OR a.valid_until >= CURRENT_DATE)
     RETURNING id, student_id, authorization_id, administered_at,
               administered_by, dosage_given, note`,
    [
      scope.organizationId,
      scope.schoolId,
      input.authorizationId,
      input.administeredBy,
      input.dosageGiven,
      input.note,
    ],
  );
  const row = rows[0];
  if (!row) {
    // The probe passed but the atomic guard did not: a concurrent revoke/expiry
    // landed in between. Refuse the dose.
    throw new StudentHealthError(
      "AUTHORIZATION_NOT_ACTIVE",
      "Medication authorization is no longer active — it must not be administered",
      422,
    );
  }
  return row;
}

export async function listRecentAdministrations(
  db: TenantQueryClient,
  scope: HealthScope,
  studentId: string,
  limit = 50,
): Promise<MedicationAdministrationRow[]> {
  return await db.queryObject<MedicationAdministrationRow>(
    `SELECT id, student_id, authorization_id, administered_at, administered_by,
            dosage_given, note
       FROM student_medication_administration_log
      WHERE organization_id = $1 AND school_id = $2 AND student_id = $3
      ORDER BY administered_at DESC
      LIMIT $4`,
    [scope.organizationId, scope.schoolId, studentId, limit],
  );
}

// ─── Care alerts ─────────────────────────────────────────────────────────────

export interface CreateCareAlertInput {
  studentId: string;
  alertLabel: string;
  actionNote: string;
  severity: string;
  createdBy: string;
}

export async function createCareAlert(
  db: TenantQueryClient,
  scope: HealthScope,
  input: CreateCareAlertInput,
): Promise<CareAlertRow> {
  const rows = await db.queryObject<CareAlertRow>(
    `INSERT INTO student_care_alerts
       (organization_id, school_id, student_id, alert_label, action_note,
        severity, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING id, student_id, alert_label, action_note, severity, is_active,
               created_by, created_at, updated_at`,
    [
      scope.organizationId,
      scope.schoolId,
      input.studentId,
      input.alertLabel,
      input.actionNote,
      input.severity,
      input.createdBy,
    ],
  );
  const row = rows[0];
  if (!row) {
    throw new StudentHealthError(
      "CARE_ALERT_NOT_CREATED",
      "Care alert insert returned no row",
      500,
    );
  }
  return row;
}

export interface UpdateCareAlertInput {
  alertLabel?: string | null;
  actionNote?: string | null;
  severity?: string | null;
  isActive?: boolean | null;
}

/**
 * Terminal-state-guarded update. `AND is_active = true` means only a LIVE alert
 * can be edited or retired; a concurrent double-deactivate has exactly one
 * winner, and the loser matches 0 rows, throws, and rolls back (writing no audit
 * row either).
 */
export async function updateCareAlert(
  db: TenantQueryClient,
  scope: HealthScope,
  alertId: string,
  input: UpdateCareAlertInput,
): Promise<CareAlertRow> {
  const rows = await db.queryObject<CareAlertRow>(
    `UPDATE student_care_alerts
        SET alert_label = COALESCE($4, alert_label),
            action_note = COALESCE($5, action_note),
            severity    = COALESCE($6, severity),
            is_active   = COALESCE($7, is_active)
      WHERE id = $1 AND organization_id = $2 AND school_id = $3
        AND is_active = true
      RETURNING id, student_id, alert_label, action_note, severity, is_active,
                created_by, created_at, updated_at`,
    [
      alertId,
      scope.organizationId,
      scope.schoolId,
      input.alertLabel ?? null,
      input.actionNote ?? null,
      input.severity ?? null,
      input.isActive ?? null,
    ],
  );
  const row = rows[0];
  if (!row) {
    throw new StudentHealthError(
      "CARE_ALERT_NOT_ACTIVE",
      "No active care alert matched — it may have been retired already",
      409,
    );
  }
  return row;
}

/** The teacher read: ACTIVE alerts only, worst-first. */
export async function listActiveCareAlerts(
  db: TenantQueryClient,
  scope: HealthScope,
  studentId: string,
): Promise<CareAlertRow[]> {
  return await db.queryObject<CareAlertRow>(
    `SELECT id, student_id, alert_label, action_note, severity, is_active,
            created_by, created_at, updated_at
       FROM student_care_alerts
      WHERE organization_id = $1 AND school_id = $2 AND student_id = $3
        AND is_active = true
      ORDER BY CASE severity
                 WHEN 'critical' THEN 0
                 WHEN 'important' THEN 1
                 ELSE 2
               END,
               created_at DESC`,
    [scope.organizationId, scope.schoolId, studentId],
  );
}
