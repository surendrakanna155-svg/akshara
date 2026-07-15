// PRC-A Batch 2 — Student Health / Infirmary: transactional operations.
//
// Each function here is the ENTIRE body of one route's `withTenantContext`
// transaction: the access check, the read/write, and its audit row, in that
// order, on one `TenantQueryClient`.
//
// Why this file exists rather than inlining these in the handlers: the handlers
// call `withTenantContext`, which builds its own connection pool, so a unit test
// cannot inject a fake DB into them. Everything genuinely worth proving about
// this module — that a teacher is refused a student they do not teach, that
// exactly one audit row accompanies every sensitive access, that a dose is
// refused against a revoked authorization — lives in the transaction body. Split
// out here, those claims are testable against the hand-rolled fake DB instead of
// being asserted only in prose.
//
// The handlers stay thin: authenticate → permission-gate → run one of these in a
// transaction → map to JSON.

import type { TenantQueryClient } from "../tenant_db.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { enqueueNotificationRequested } from "../communication/notification_service.ts";
import {
  administerMedication,
  createAuthorization,
  createCareAlert,
  createIncident,
  type HealthScope,
  listActiveAuthorizations,
  listActiveCareAlerts,
  listGuardianUserIdsForStudent,
  listIncidents,
  listRecentAdministrations,
  logHealthAccess,
  markIncidentParentNotified,
  revokeAuthorization,
  StudentHealthError,
  studentExistsInSchool,
  teacherTeachesStudent,
  updateCareAlert,
} from "./student_health_repository.ts";
import type {
  CareAlertRow,
  HealthIncidentRow,
  MedicationAdministrationRow,
  MedicationAuthorizationRow,
} from "./student_health_types.ts";
import { HEALTH_PERM_VIEW_RECORD } from "./student_health_types.ts";

/**
 * The guardian-facing notification. Owner decision #1: "A parent notification
 * may say 'your child was seen in the infirmary, please contact the school' — it
 * must not carry clinical detail."
 *
 * These are CONSTANTS, not templates: there is no interpolation point through
 * which an incident type, complaint, observation or medication name could reach
 * an SMS/push payload, a provider's logs, or a lock-screen preview visible to
 * whoever happens to be holding the parent's phone. Do not parameterise them.
 */
export const PARENT_INCIDENT_NOTIFICATION_TITLE = "Message from the school";
export const PARENT_INCIDENT_NOTIFICATION_BODY =
  "Your child was seen in the school infirmary today. " +
  "Please contact the school office for details.";

/** Everything an operation needs about the caller — all of it token-derived. */
export interface HealthActor {
  actorId: string;
  actorRole: string;
  /**
   * True when the caller holds `viewStudentHealthRecord` — i.e. health staff or
   * explicitly authorised leadership. Such a caller reads the full record
   * anyway, so narrowing them to "students they teach" would be meaningless (a
   * nurse teaches nobody). Everyone else on the care-alert route is a teaching
   * role and IS narrowed.
   */
  isCareTeam: boolean;
  route: string;
  purpose: string;
}

/** Builds the actor from the token. `sub`/`role_slugs` are never client-supplied. */
export function actorFromClaims(
  claims: AccessTokenClaims,
  route: string,
  purpose: string,
): HealthActor {
  const slugs = claims.role_slugs?.length ? claims.role_slugs : [claims.role];
  return {
    actorId: claims.sub,
    actorRole: slugs.filter(Boolean).join(","),
    isCareTeam: claims.permissions.includes(HEALTH_PERM_VIEW_RECORD),
    route,
    purpose,
  };
}

async function requireStudent(
  db: TenantQueryClient,
  scope: HealthScope,
  studentId: string,
): Promise<void> {
  if (!await studentExistsInSchool(db, scope, studentId)) {
    throw new StudentHealthError(
      "STUDENT_NOT_FOUND",
      "Student not found in this school",
      404,
    );
  }
}

// ─── Incidents ───────────────────────────────────────────────────────────────

export interface RecordIncidentInput {
  studentId: string;
  occurredAt: string | null;
  reportedBy: string | null;
  incidentType: string;
  complaintSummary: string;
  observations: string;
  treatmentGiven: string;
  outcome: string;
  referredTo: string | null;
}

export interface RecordIncidentResult {
  incident: HealthIncidentRow;
  notifiedGuardians: number;
}

/**
 * Record an infirmary visit, audit the write, and notify the guardians with a
 * detail-free message.
 *
 * The notification enqueue is INSIDE the transaction deliberately: if it fails,
 * the incident rolls back too. The alternative — keep the clinical record, drop
 * the notification — would leave a child sent home sick with a parent who was
 * never told, and nothing anywhere recording that the telling failed. Since the
 * enqueue is a plain INSERT into `notification_deliveries`, the only realistic
 * failure is the DB itself, in which case the write was never going to land.
 */
export async function recordIncidentOp(
  db: TenantQueryClient,
  scope: HealthScope,
  actor: HealthActor,
  input: RecordIncidentInput,
): Promise<RecordIncidentResult> {
  await requireStudent(db, scope, input.studentId);

  const incident = await createIncident(db, scope, {
    studentId: input.studentId,
    occurredAt: input.occurredAt,
    reportedBy: input.reportedBy,
    // The AUTHOR is always the token subject, never the request body.
    recordedBy: actor.actorId,
    incidentType: input.incidentType,
    complaintSummary: input.complaintSummary,
    observations: input.observations,
    treatmentGiven: input.treatmentGiven,
    outcome: input.outcome,
    referredTo: input.referredTo,
  });

  await logHealthAccess(db, scope, {
    studentId: input.studentId,
    actorId: actor.actorId,
    actorRole: actor.actorRole,
    accessKind: "write_incident",
    route: actor.route,
    purpose: actor.purpose,
  });

  const guardians = await listGuardianUserIdsForStudent(db, scope, input.studentId);
  let notificationRef: string | null = null;
  for (const guardianUserId of guardians) {
    const delivery = await enqueueNotificationRequested(
      db,
      scope.organizationId,
      scope.schoolId,
      guardianUserId,
      PARENT_INCIDENT_NOTIFICATION_TITLE,
      PARENT_INCIDENT_NOTIFICATION_BODY,
      "health",
    );
    notificationRef ??= delivery.id;
  }
  if (notificationRef) {
    await markIncidentParentNotified(db, scope, incident.id, notificationRef);
    incident.parent_notification_ref = notificationRef;
    incident.parent_notified_at = new Date().toISOString();
  }

  return { incident, notifiedGuardians: guardians.length };
}

/** Full clinical history + its `view_record` audit row. */
export async function listIncidentsOp(
  db: TenantQueryClient,
  scope: HealthScope,
  actor: HealthActor,
  studentId: string,
): Promise<HealthIncidentRow[]> {
  const rows = await listIncidents(db, scope, studentId);
  await logHealthAccess(db, scope, {
    studentId,
    actorId: actor.actorId,
    actorRole: actor.actorRole,
    accessKind: "view_record",
    route: actor.route,
    purpose: actor.purpose,
  });
  return rows;
}

export interface StudentHealthRecord {
  incidents: HealthIncidentRow[];
  authorizations: MedicationAuthorizationRow[];
  administrations: MedicationAdministrationRow[];
  careAlerts: CareAlertRow[];
}

/** The full record + its `view_record` audit row. */
export async function readStudentRecordOp(
  db: TenantQueryClient,
  scope: HealthScope,
  actor: HealthActor,
  studentId: string,
): Promise<StudentHealthRecord> {
  const incidents = await listIncidents(db, scope, studentId);
  const authorizations = await listActiveAuthorizations(db, scope, studentId);
  const administrations = await listRecentAdministrations(db, scope, studentId);
  const careAlerts = await listActiveCareAlerts(db, scope, studentId);
  await logHealthAccess(db, scope, {
    studentId,
    actorId: actor.actorId,
    actorRole: actor.actorRole,
    accessKind: "view_record",
    route: actor.route,
    purpose: actor.purpose,
  });
  return { incidents, authorizations, administrations, careAlerts };
}

// ─── Care alerts ─────────────────────────────────────────────────────────────

/**
 * THE TEACHER SURFACE. A caller who is not on the care team must actually teach
 * this student. FAILS CLOSED: an unresolvable teacher→student link denies.
 *
 * The deny throws BEFORE the read and before the audit row, so a refused teacher
 * receives no alert data and (because the transaction rolls back) leaves no
 * audit row claiming they viewed one.
 */
export async function readCareAlertOp(
  db: TenantQueryClient,
  scope: HealthScope,
  actor: HealthActor,
  studentId: string,
): Promise<CareAlertRow[]> {
  if (!actor.isCareTeam) {
    const teaches = await teacherTeachesStudent(db, scope, actor.actorId, studentId);
    if (!teaches) {
      throw new StudentHealthError(
        "NOT_THIS_TEACHERS_STUDENT",
        "Care alerts are visible only for students you teach",
        403,
      );
    }
  }
  const rows = await listActiveCareAlerts(db, scope, studentId);
  await logHealthAccess(db, scope, {
    studentId,
    actorId: actor.actorId,
    actorRole: actor.actorRole,
    accessKind: "view_care_alert",
    route: actor.route,
    purpose: actor.purpose,
  });
  return rows;
}

export interface CreateCareAlertOpInput {
  studentId: string;
  label: string;
  actionNote: string;
  severity: string;
}

export async function createCareAlertOp(
  db: TenantQueryClient,
  scope: HealthScope,
  actor: HealthActor,
  input: CreateCareAlertOpInput,
): Promise<CareAlertRow> {
  await requireStudent(db, scope, input.studentId);
  const created = await createCareAlert(db, scope, {
    studentId: input.studentId,
    alertLabel: input.label,
    actionNote: input.actionNote,
    severity: input.severity,
    createdBy: actor.actorId,
  });
  await logHealthAccess(db, scope, {
    studentId: input.studentId,
    actorId: actor.actorId,
    actorRole: actor.actorRole,
    accessKind: "write_care_alert",
    route: actor.route,
    purpose: actor.purpose,
  });
  return created;
}

export interface UpdateCareAlertOpInput {
  alertLabel: string | null;
  actionNote: string | null;
  severity: string | null;
  isActive: boolean | null;
}

export async function updateCareAlertOp(
  db: TenantQueryClient,
  scope: HealthScope,
  actor: HealthActor,
  alertId: string,
  input: UpdateCareAlertOpInput,
): Promise<CareAlertRow> {
  // Guarded terminal write (AND is_active = true) — throws on 0 rows.
  const updated = await updateCareAlert(db, scope, alertId, input);
  await logHealthAccess(db, scope, {
    studentId: updated.student_id,
    actorId: actor.actorId,
    actorRole: actor.actorRole,
    accessKind: "write_care_alert",
    route: actor.route,
    purpose: actor.purpose,
  });
  return updated;
}

// ─── Medication authorizations ───────────────────────────────────────────────

export interface CreateAuthorizationOpInput {
  studentId: string;
  medicationName: string;
  dosage: string;
  route: string;
  scheduleNote: string;
  validFrom: string;
  validUntil: string | null;
  authorizedByGuardianId: string | null;
  authorizationSource: string;
  authorizationRef: string;
}

export async function createAuthorizationOp(
  db: TenantQueryClient,
  scope: HealthScope,
  actor: HealthActor,
  input: CreateAuthorizationOpInput,
): Promise<MedicationAuthorizationRow> {
  await requireStudent(db, scope, input.studentId);

  // If a guardian is named, they must be an ACTIVE guardian OF THIS CHILD —
  // consent from someone else's guardian is not consent.
  if (input.authorizedByGuardianId) {
    const guardians = await listGuardianUserIdsForStudent(db, scope, input.studentId);
    if (!guardians.includes(input.authorizedByGuardianId)) {
      throw new StudentHealthError(
        "GUARDIAN_NOT_LINKED",
        "authorizedByGuardianId is not an active guardian of this student",
        422,
      );
    }
  }

  const row = await createAuthorization(db, scope, {
    studentId: input.studentId,
    medicationName: input.medicationName,
    dosage: input.dosage,
    route: input.route,
    scheduleNote: input.scheduleNote,
    validFrom: input.validFrom,
    validUntil: input.validUntil,
    authorizedByGuardianId: input.authorizedByGuardianId,
    authorizationSource: input.authorizationSource,
    authorizationRef: input.authorizationRef,
    createdBy: actor.actorId,
  });
  await logHealthAccess(db, scope, {
    studentId: input.studentId,
    actorId: actor.actorId,
    actorRole: actor.actorRole,
    accessKind: "write_authorization",
    route: actor.route,
    purpose: actor.purpose,
  });
  return row;
}

export async function revokeAuthorizationOp(
  db: TenantQueryClient,
  scope: HealthScope,
  actor: HealthActor,
  authorizationId: string,
): Promise<MedicationAuthorizationRow> {
  // Guarded terminal write (AND status='active'): the loser of a concurrent
  // double-revoke matches 0 rows, throws, and rolls back — no second write, and
  // no audit row claiming a revoke that never happened.
  const row = await revokeAuthorization(db, scope, authorizationId, actor.actorId);
  await logHealthAccess(db, scope, {
    studentId: row.student_id,
    actorId: actor.actorId,
    actorRole: actor.actorRole,
    accessKind: "revoke_authorization",
    route: actor.route,
    purpose: actor.purpose,
  });
  return row;
}

export interface AdministerOpInput {
  authorizationId: string;
  expectedStudentId: string | null;
  dosageGiven: string;
  note: string;
}

export async function administerMedicationOp(
  db: TenantQueryClient,
  scope: HealthScope,
  actor: HealthActor,
  input: AdministerOpInput,
): Promise<MedicationAdministrationRow> {
  const row = await administerMedication(db, scope, {
    authorizationId: input.authorizationId,
    expectedStudentId: input.expectedStudentId,
    administeredBy: actor.actorId,
    dosageGiven: input.dosageGiven,
    note: input.note,
  });
  await logHealthAccess(db, scope, {
    studentId: row.student_id,
    actorId: actor.actorId,
    actorRole: actor.actorRole,
    accessKind: "administer_medication",
    route: actor.route,
    purpose: actor.purpose,
  });
  return row;
}
