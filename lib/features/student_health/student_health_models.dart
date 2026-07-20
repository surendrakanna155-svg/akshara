// PRC-A Batch 2 — Student Health / Infirmary client models.
//
// Owner decision #1 (LOCKED 2026-07-15) — strict need-to-know least-privilege.
// [CareAlert] is the ONLY model shared with the teacher care-alert surface
// (see care_alert/) and it structurally has no field for clinical detail —
// keep it that way. Every other model here (incident / authorization /
// administration / access log) is CLINICAL and must only ever be populated
// from a `viewStudentHealthRecord`-gated read.

const List<String> kIncidentTypes = [
  'illness',
  'injury',
  'allergic_reaction',
  'chronic_episode',
  'routine_checkup',
  'other',
];

const List<String> kIncidentOutcomes = [
  'returned_to_class',
  'sent_home',
  'referred_hospital',
  'observation',
  'other',
];

const List<String> kCareAlertSeverities = ['info', 'important', 'critical'];

const List<String> kAuthorizationSources = [
  'written_form',
  'doctor_prescription',
  'in_person',
  'parent_portal',
  'other',
];

/// The TEACHER surface. Deliberately minimal: a label, what to DO, and how
/// urgent. There is no diagnosis field, no history field, no notes field — a
/// teacher-facing response cannot leak clinical detail because this type has
/// nowhere to put it. Keep it that way.
class CareAlert {
  const CareAlert({
    required this.id,
    required this.studentId,
    required this.label,
    required this.actionNote,
    required this.severity,
  });

  final String id;
  final String studentId;
  final String label;
  final String actionNote;
  final String severity; // info | important | critical

  factory CareAlert.fromJson(Map<String, dynamic> json) => CareAlert(
        id: (json['id'] ?? '').toString(),
        studentId: (json['studentId'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
        actionNote: (json['actionNote'] ?? '').toString(),
        severity: (json['severity'] ?? '').toString(),
      );
}

/// CLINICAL. Only ever populated behind `viewStudentHealthRecord`.
class HealthIncident {
  const HealthIncident({
    required this.id,
    required this.studentId,
    required this.occurredAt,
    required this.recordedBy,
    required this.incidentType,
    required this.complaintSummary,
    required this.observations,
    required this.treatmentGiven,
    required this.outcome,
    this.reportedBy,
    this.referredTo,
    this.parentNotifiedAt,
    this.parentNotificationRef,
  });

  final String id;
  final String studentId;
  final String occurredAt;
  final String? reportedBy;
  final String recordedBy;
  final String incidentType;
  final String complaintSummary;
  final String observations;
  final String treatmentGiven;
  final String outcome;
  final String? referredTo;
  final String? parentNotifiedAt;
  final String? parentNotificationRef;

  factory HealthIncident.fromJson(Map<String, dynamic> json) => HealthIncident(
        id: (json['id'] ?? '').toString(),
        studentId: (json['studentId'] ?? '').toString(),
        occurredAt: (json['occurredAt'] ?? '').toString(),
        reportedBy: (json['reportedBy'])?.toString(),
        recordedBy: (json['recordedBy'] ?? '').toString(),
        incidentType: (json['incidentType'] ?? '').toString(),
        complaintSummary: (json['complaintSummary'] ?? '').toString(),
        observations: (json['observations'] ?? '').toString(),
        treatmentGiven: (json['treatmentGiven'] ?? '').toString(),
        outcome: (json['outcome'] ?? '').toString(),
        referredTo: (json['referredTo'])?.toString(),
        parentNotifiedAt: (json['parentNotifiedAt'])?.toString(),
        parentNotificationRef: (json['parentNotificationRef'])?.toString(),
      );
}

/// The result of recording an incident — includes a COUNT of guardians
/// notified (never a clinical fact) alongside the created incident.
class IncidentCreationResult {
  const IncidentCreationResult({required this.incident, required this.notifiedGuardians});
  final HealthIncident incident;
  final int notifiedGuardians;

  factory IncidentCreationResult.fromJson(Map<String, dynamic> json) => IncidentCreationResult(
        incident: HealthIncident.fromJson((json['incident'] as Map).cast<String, dynamic>()),
        notifiedGuardians: _asInt(json['notifiedGuardians']),
      );
}

/// CLINICAL (carries the medication name/dosage). Only behind
/// `viewStudentHealthRecord`; written via `manageStudentHealth`.
class MedicationAuthorization {
  const MedicationAuthorization({
    required this.id,
    required this.studentId,
    required this.medicationName,
    required this.dosage,
    required this.route,
    required this.scheduleNote,
    required this.validFrom,
    required this.authorizationSource,
    required this.authorizationRef,
    required this.status,
    this.validUntil,
    this.authorizedByGuardianId,
    this.revokedAt,
    this.revokedBy,
  });

  final String id;
  final String studentId;
  final String medicationName;
  final String dosage;
  final String route;
  final String scheduleNote;
  final String validFrom;
  final String? validUntil;
  final String? authorizedByGuardianId;
  final String authorizationSource;
  final String authorizationRef;
  final String status; // active | revoked | expired (server-defined)
  final String? revokedAt;
  final String? revokedBy;

  bool get isActive => status == 'active';

  factory MedicationAuthorization.fromJson(Map<String, dynamic> json) => MedicationAuthorization(
        id: (json['id'] ?? '').toString(),
        studentId: (json['studentId'] ?? '').toString(),
        medicationName: (json['medicationName'] ?? '').toString(),
        dosage: (json['dosage'] ?? '').toString(),
        route: (json['route'] ?? '').toString(),
        scheduleNote: (json['scheduleNote'] ?? '').toString(),
        validFrom: (json['validFrom'] ?? '').toString(),
        validUntil: (json['validUntil'])?.toString(),
        authorizedByGuardianId: (json['authorizedByGuardianId'])?.toString(),
        authorizationSource: (json['authorizationSource'] ?? '').toString(),
        authorizationRef: (json['authorizationRef'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        revokedAt: (json['revokedAt'])?.toString(),
        revokedBy: (json['revokedBy'])?.toString(),
      );
}

/// CLINICAL (ties back to a medication). Only behind `viewStudentHealthRecord`.
class MedicationAdministration {
  const MedicationAdministration({
    required this.id,
    required this.studentId,
    required this.authorizationId,
    required this.administeredAt,
    required this.administeredBy,
    required this.dosageGiven,
    required this.note,
  });

  final String id;
  final String studentId;
  final String authorizationId;
  final String administeredAt;
  final String administeredBy;
  final String dosageGiven;
  final String note;

  factory MedicationAdministration.fromJson(Map<String, dynamic> json) =>
      MedicationAdministration(
        id: (json['id'] ?? '').toString(),
        studentId: (json['studentId'] ?? '').toString(),
        authorizationId: (json['authorizationId'] ?? '').toString(),
        administeredAt: (json['administeredAt'] ?? '').toString(),
        administeredBy: (json['administeredBy'] ?? '').toString(),
        dosageGiven: (json['dosageGiven'] ?? '').toString(),
        note: (json['note'] ?? '').toString(),
      );
}

/// "Who accessed this child's health data" — gated the same as the record
/// itself (`viewStudentHealthRecord`), because knowing a child HAS a health
/// record + who read it is at least as sensitive as the record.
class HealthAccessLogEntry {
  const HealthAccessLogEntry({
    required this.id,
    required this.actorId,
    required this.actorRole,
    required this.accessKind,
    required this.route,
    required this.purpose,
    required this.occurredAt,
  });

  final String id;
  final String actorId;
  final String actorRole;
  final String accessKind;
  final String route;
  final String purpose;
  final String occurredAt;

  factory HealthAccessLogEntry.fromJson(Map<String, dynamic> json) => HealthAccessLogEntry(
        id: (json['id'] ?? '').toString(),
        actorId: (json['actorId'] ?? '').toString(),
        actorRole: (json['actorRole'] ?? '').toString(),
        accessKind: (json['accessKind'] ?? '').toString(),
        route: (json['route'] ?? '').toString(),
        purpose: (json['purpose'] ?? '').toString(),
        occurredAt: (json['occurredAt'] ?? '').toString(),
      );
}

/// The consolidated full clinical record for one student
/// (`GET /student-health/students/:studentId/record`).
class StudentHealthRecord {
  const StudentHealthRecord({
    required this.studentId,
    required this.incidents,
    required this.activeAuthorizations,
    required this.recentAdministrations,
    required this.careAlerts,
  });

  final String studentId;
  final List<HealthIncident> incidents;
  final List<MedicationAuthorization> activeAuthorizations;
  final List<MedicationAdministration> recentAdministrations;
  final List<CareAlert> careAlerts;

  factory StudentHealthRecord.fromJson(Map<String, dynamic> json) => StudentHealthRecord(
        studentId: (json['studentId'] ?? '').toString(),
        incidents: _list(json['incidents'], HealthIncident.fromJson),
        activeAuthorizations:
            _list(json['activeAuthorizations'], MedicationAuthorization.fromJson),
        recentAdministrations:
            _list(json['recentAdministrations'], MedicationAdministration.fromJson),
        careAlerts: _list(json['careAlerts'], CareAlert.fromJson),
      );
}

List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) => [
      if (raw is List)
        for (final item in raw)
          if (item is Map) fromJson(item.cast<String, dynamic>()),
    ];

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
