// PRC-A Batch 2 — Student Health / Infirmary: types only.
//
// Owner decision #1 (LOCKED 2026-07-15): strict need-to-know least-privilege.
// The type split mirrors the privilege split — `CareAlertApi` is the ONLY shape
// a teaching role ever receives, and it structurally cannot carry clinical
// detail because it has no field for it.

export const HEALTH_PERM_MANAGE = "manageStudentHealth";
export const HEALTH_PERM_VIEW_RECORD = "viewStudentHealthRecord";
export const HEALTH_PERM_VIEW_CARE_ALERT = "viewStudentCareAlert";
export const HEALTH_PERM_ADMINISTER = "administerStudentMedication";

export const INCIDENT_TYPES = [
  "illness",
  "injury",
  "allergic_reaction",
  "chronic_episode",
  "routine_checkup",
  "other",
] as const;
export type IncidentType = typeof INCIDENT_TYPES[number];

export const INCIDENT_OUTCOMES = [
  "returned_to_class",
  "sent_home",
  "referred_hospital",
  "observation",
  "other",
] as const;
export type IncidentOutcome = typeof INCIDENT_OUTCOMES[number];

export const CARE_ALERT_SEVERITIES = ["info", "important", "critical"] as const;
export type CareAlertSeverity = typeof CARE_ALERT_SEVERITIES[number];

export const AUTHORIZATION_SOURCES = [
  "written_form",
  "doctor_prescription",
  "in_person",
  "parent_portal",
  "other",
] as const;
export type AuthorizationSource = typeof AUTHORIZATION_SOURCES[number];

export type HealthAccessKind =
  | "view_record"
  | "view_care_alert"
  | "write_incident"
  /** Authoring/retiring a care alert — distinct from recording an incident. */
  | "write_care_alert"
  | "write_authorization"
  | "administer_medication"
  | "revoke_authorization";

// ─── DB row shapes ───────────────────────────────────────────────────────────

export interface HealthIncidentRow {
  id: string;
  student_id: string;
  occurred_at: string;
  reported_by: string | null;
  recorded_by: string;
  incident_type: string;
  complaint_summary: string;
  observations: string;
  treatment_given: string;
  outcome: string;
  referred_to: string | null;
  parent_notified_at: string | null;
  parent_notification_ref: string | null;
  created_at: string;
}

export interface MedicationAuthorizationRow {
  id: string;
  student_id: string;
  medication_name: string;
  dosage: string;
  route: string;
  schedule_note: string;
  valid_from: string;
  valid_until: string | null;
  authorized_by_guardian_id: string | null;
  authorization_source: string;
  authorization_ref: string;
  status: string;
  revoked_at: string | null;
  revoked_by: string | null;
  created_by: string;
  created_at: string;
}

export interface MedicationAdministrationRow {
  id: string;
  student_id: string;
  authorization_id: string;
  administered_at: string;
  administered_by: string;
  dosage_given: string;
  note: string;
}

export interface CareAlertRow {
  id: string;
  student_id: string;
  alert_label: string;
  action_note: string;
  severity: string;
  is_active: boolean;
  created_by: string;
  created_at: string;
  updated_at: string;
}

export interface HealthAccessLogRow {
  id: string;
  student_id: string;
  actor_id: string;
  actor_role: string;
  access_kind: string;
  route: string;
  purpose: string;
  occurred_at: string;
}

// ─── API shapes ──────────────────────────────────────────────────────────────

/**
 * The TEACHER surface. Deliberately minimal: a label, what to DO, and how
 * urgent. There is no diagnosis field, no history field, no notes field — a
 * teacher-facing response cannot leak clinical detail because this type has
 * nowhere to put it. Keep it that way.
 */
export interface CareAlertApi {
  id: string;
  studentId: string;
  label: string;
  actionNote: string;
  severity: string;
}

export interface HealthIncidentApi {
  id: string;
  studentId: string;
  occurredAt: string;
  reportedBy: string | null;
  recordedBy: string;
  incidentType: string;
  complaintSummary: string;
  observations: string;
  treatmentGiven: string;
  outcome: string;
  referredTo: string | null;
  parentNotifiedAt: string | null;
  parentNotificationRef: string | null;
}

export interface MedicationAuthorizationApi {
  id: string;
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
  status: string;
  revokedAt: string | null;
  revokedBy: string | null;
}

export interface MedicationAdministrationApi {
  id: string;
  studentId: string;
  authorizationId: string;
  administeredAt: string;
  administeredBy: string;
  dosageGiven: string;
  note: string;
}
