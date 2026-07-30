// PRC-A Batch 2 — Student Health / Infirmary: repository + operation tests.
//
// Hand-rolled in-file fake DB (project convention — there is no shared fake).
// It pattern-matches the exact SQL these modules issue and branches on the
// positional args.
//
// ⚠ WHAT THESE TESTS CANNOT PROVE. The fake does not evaluate JOIN semantics and
// does not enforce RLS at all. So:
//   * every RLS policy in 20260887000000_student_health.sql is UNVERIFIED here —
//     tenant isolation, the parent-own-child branch, and the absence of an
//     UPDATE/DELETE path on the two immutable tables are only really provable
//     against live Postgres;
//   * `teacherTeachesStudent` is a 3-branch UNION over teacher_assignments /
//     sections / classes / timetable_slots. The fake answers it from a seeded
//     set, so these tests prove the CALLER's fail-closed behaviour, NOT that the
//     SQL resolves the roster correctly.
// Both need a live probe. See the module report's live-probe list.

import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { StudentHealthError } from "./student_health_repository.ts";
import {
  actorFromClaims,
  administerMedicationOp,
  createAuthorizationOp,
  createCareAlertOp,
  type HealthActor,
  listIncidentsOp,
  PARENT_INCIDENT_NOTIFICATION_BODY,
  PARENT_INCIDENT_NOTIFICATION_TITLE,
  readCareAlertOp,
  readStudentRecordOp,
  recordIncidentOp,
  revokeAuthorizationOp,
  updateCareAlertOp,
} from "./student_health_operations.ts";
import type { AccessTokenClaims } from "../jwt.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const NURSE = "a3000000-0000-4000-8000-00000000000n".replace("n", "1");
const TEACHER = "a3000000-0000-4000-8000-000000000002";
const STUDENT = "a4000000-0000-4000-8000-000000000001";
const OTHER_STUDENT = "a4000000-0000-4000-8000-000000000002";
const GUARDIAN = "a5000000-0000-4000-8000-000000000001";
const AUTH_ID = "a6000000-0000-4000-8000-000000000001";
const ALERT_ID = "a7000000-0000-4000-8000-000000000001";

const SCOPE = { organizationId: ORG, schoolId: SCHOOL };

type Row = Record<string, unknown>;

interface AuthSeed {
  id: string;
  studentId: string;
  status: string;
  validFrom: string;
  validUntil: string | null;
  medicationName: string;
}

interface AlertSeed {
  id: string;
  studentId: string;
  label: string;
  actionNote: string;
  severity: string;
  isActive: boolean;
}

/**
 * Faithful in-memory model of the SQL this module issues. `TODAY` is what the
 * repository's `CURRENT_DATE` resolves to — the validity window is decided by
 * the DB's clock, never the worker's, so the fake supplies it here too.
 */
const TODAY = "2026-07-15";

class HealthMockDb {
  students = new Set<string>([STUDENT, OTHER_STUDENT]);
  guardians = new Map<string, string[]>([[STUDENT, [GUARDIAN]]]);
  /** `${teacherId}|${studentId}` pairs the roster resolves. */
  teaches = new Set<string>();
  authorizations = new Map<string, AuthSeed>();
  careAlerts = new Map<string, AlertSeed>();

  incidents: Row[] = [];
  accessLog: Row[] = [];
  notifications: Row[] = [];
  administrations: Row[] = [];
  createdAlerts: Row[] = [];
  /** Set to run right after `probeAuthorization` — simulates a concurrent write. */
  onProbe: (() => void) | null = null;

  seedAuthorization(seed: Partial<AuthSeed> = {}): AuthSeed {
    const row: AuthSeed = {
      id: AUTH_ID,
      studentId: STUDENT,
      status: "active",
      validFrom: "2026-07-01",
      validUntil: "2026-12-31",
      medicationName: "Salbutamol inhaler",
      ...seed,
    };
    this.authorizations.set(row.id, row);
    return row;
  }

  seedAlert(seed: Partial<AlertSeed> = {}): AlertSeed {
    const row: AlertSeed = {
      id: ALERT_ID,
      studentId: STUDENT,
      label: "Severe peanut allergy",
      actionNote: "Epipen in infirmary. Call infirmary immediately.",
      severity: "critical",
      isActive: true,
      ...seed,
    };
    this.careAlerts.set(row.id, row);
    return row;
  }

  private authRow(a: AuthSeed): Row {
    return {
      id: a.id,
      student_id: a.studentId,
      medication_name: a.medicationName,
      dosage: "2 puffs",
      route: "inhaled",
      schedule_note: "",
      valid_from: a.validFrom,
      valid_until: a.validUntil,
      authorized_by_guardian_id: GUARDIAN,
      authorization_source: "written_form",
      authorization_ref: "FORM-2026-014",
      status: a.status,
      revoked_at: a.status === "revoked" ? "2026-07-10T00:00:00.000Z" : null,
      revoked_by: a.status === "revoked" ? NURSE : null,
      created_by: NURSE,
      created_at: "2026-07-01T00:00:00.000Z",
    };
  }

  private alertRow(a: AlertSeed): Row {
    return {
      id: a.id,
      student_id: a.studentId,
      alert_label: a.label,
      action_note: a.actionNote,
      severity: a.severity,
      is_active: a.isActive,
      created_by: NURSE,
      created_at: "2026-07-01T00:00:00.000Z",
      updated_at: "2026-07-01T00:00:00.000Z",
    };
  }

  // deno-lint-ignore require-await
  async queryCount(sql: string, args: unknown[] = []): Promise<number> {
    // teacherTeachesStudent — the 3-branch UNION.
    if (sql.includes(") links")) {
      const teacherId = String(args[3]);
      const studentId = String(args[2]);
      return this.teaches.has(`${teacherId}|${studentId}`) ? 1 : 0;
    }
    // studentExistsInSchool
    if (sql.includes("FROM students")) {
      return this.students.has(String(args[0])) &&
          String(args[1]) === ORG && String(args[2]) === SCHOOL
        ? 1
        : 0;
    }
    throw new Error(`unmatched queryCount SQL: ${sql}`);
  }

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // ── audit ────────────────────────────────────────────────────────────────
    if (sql.includes("INSERT INTO student_health_access_log")) {
      this.accessLog.push({
        organization_id: args[0],
        school_id: args[1],
        student_id: args[2],
        actor_id: args[3],
        actor_role: args[4],
        access_kind: args[5],
        route: args[6],
        purpose: args[7],
      });
      return [] as T[];
    }

    // ── notifications ────────────────────────────────────────────────────────
    if (sql.includes("INSERT INTO notification_deliveries")) {
      const row = {
        id: `delivery-${this.notifications.length + 1}`,
        organization_id: args[0],
        school_id: args[1],
        recipient_user_id: args[2],
        channel: args[3],
        category: args[5],
        rendered_subject: args[6],
        rendered_body: args[7],
        status: "pending",
      };
      this.notifications.push(row);
      return [row] as T[];
    }

    // ── incidents ────────────────────────────────────────────────────────────
    if (sql.includes("INSERT INTO student_health_incidents")) {
      const row = {
        id: `incident-${this.incidents.length + 1}`,
        student_id: args[2],
        occurred_at: args[3] ?? "2026-07-15T09:00:00.000Z",
        reported_by: args[4],
        recorded_by: args[5],
        incident_type: args[6],
        complaint_summary: args[7],
        observations: args[8],
        treatment_given: args[9],
        outcome: args[10],
        referred_to: args[11],
        parent_notified_at: null,
        parent_notification_ref: null,
        created_at: "2026-07-15T09:00:00.000Z",
      };
      this.incidents.push(row);
      return [row] as T[];
    }
    if (sql.includes("UPDATE student_health_incidents")) {
      const target = this.incidents.find((i) => i.id === args[0]);
      if (target) {
        target.parent_notified_at = "2026-07-15T09:01:00.000Z";
        target.parent_notification_ref = args[3];
      }
      return [] as T[];
    }
    if (sql.includes("FROM student_health_incidents")) {
      return this.incidents.filter((i) => i.student_id === args[2]) as T[];
    }

    // ── guardians ────────────────────────────────────────────────────────────
    if (sql.includes("FROM student_guardians")) {
      const ids = this.guardians.get(String(args[2])) ?? [];
      return ids.map((guardian_user_id) => ({ guardian_user_id })) as T[];
    }

    // ── medication administration log (checked BEFORE the auth SELECT, since
    //    the INSERT…SELECT mentions FROM student_medication_authorizations) ────
    if (sql.includes("INSERT INTO student_medication_administration_log")) {
      const a = this.authorizations.get(String(args[2]));
      // Model the atomic guard in the INSERT…SELECT's WHERE clause exactly.
      const passes = a !== undefined &&
        a.status === "active" &&
        a.validFrom <= TODAY &&
        (a.validUntil === null || a.validUntil >= TODAY);
      if (!passes) return [] as T[];
      const row = {
        id: `admin-${this.administrations.length + 1}`,
        student_id: a!.studentId,
        authorization_id: a!.id,
        administered_at: "2026-07-15T09:05:00.000Z",
        administered_by: args[3],
        dosage_given: args[4],
        note: args[5],
      };
      this.administrations.push(row);
      return [row] as T[];
    }
    if (sql.includes("FROM student_medication_administration_log")) {
      return this.administrations.filter((r) => r.student_id === args[2]) as T[];
    }

    // ── medication authorizations ────────────────────────────────────────────
    if (sql.includes("INSERT INTO student_medication_authorizations")) {
      const row = {
        id: AUTH_ID,
        student_id: args[2],
        medication_name: args[3],
        dosage: args[4],
        route: args[5],
        schedule_note: args[6],
        valid_from: args[7],
        valid_until: args[8],
        authorized_by_guardian_id: args[9],
        authorization_source: args[10],
        authorization_ref: args[11],
        status: "active",
        revoked_at: null,
        revoked_by: null,
        created_by: args[12],
        created_at: "2026-07-15T09:00:00.000Z",
      };
      return [row] as T[];
    }
    // probeAuthorization — carries the DB's CURRENT_DATE.
    if (sql.includes("CURRENT_DATE::text AS today")) {
      const a = this.authorizations.get(String(args[0]));
      const out = a
        ? [{
          id: a.id,
          student_id: a.studentId,
          status: a.status,
          valid_from: a.validFrom,
          valid_until: a.validUntil,
          medication_name: a.medicationName,
          today: TODAY,
        }]
        : [];
      // Fire the race hook AFTER the probe read, BEFORE the guarded insert.
      this.onProbe?.();
      return out as T[];
    }
    if (sql.includes("UPDATE student_medication_authorizations")) {
      const a = this.authorizations.get(String(args[0]));
      // The guard: `AND status = 'active'`.
      if (!a || a.status !== "active") return [] as T[];
      a.status = "revoked";
      return [this.authRow(a)] as T[];
    }
    if (sql.includes("FROM student_medication_authorizations")) {
      return [...this.authorizations.values()]
        .filter((a) => a.studentId === args[2] && a.status === "active")
        .map((a) => this.authRow(a)) as T[];
    }

    // ── care alerts ──────────────────────────────────────────────────────────
    if (sql.includes("INSERT INTO student_care_alerts")) {
      const row = {
        id: ALERT_ID,
        student_id: args[2],
        alert_label: args[3],
        action_note: args[4],
        severity: args[5],
        is_active: true,
        created_by: args[6],
        created_at: "2026-07-15T09:00:00.000Z",
        updated_at: "2026-07-15T09:00:00.000Z",
      };
      this.createdAlerts.push(row);
      return [row] as T[];
    }
    if (sql.includes("UPDATE student_care_alerts")) {
      const a = this.careAlerts.get(String(args[0]));
      // The guard: `AND is_active = true`.
      if (!a || !a.isActive) return [] as T[];
      if (args[3] != null) a.label = String(args[3]);
      if (args[4] != null) a.actionNote = String(args[4]);
      if (args[5] != null) a.severity = String(args[5]);
      if (args[6] != null) a.isActive = Boolean(args[6]);
      return [this.alertRow(a)] as T[];
    }
    if (sql.includes("FROM student_care_alerts")) {
      return [...this.careAlerts.values()]
        .filter((a) => a.studentId === args[2] && a.isActive)
        .map((a) => this.alertRow(a)) as T[];
    }

    // ── audit read ───────────────────────────────────────────────────────────
    if (sql.includes("FROM student_health_access_log")) {
      return this.accessLog.filter((r) => r.student_id === args[2]) as T[];
    }

    throw new Error(`unmatched queryObject SQL: ${sql}`);
  }
}

function db(mock: HealthMockDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

function nurseActor(): HealthActor {
  return {
    actorId: NURSE,
    actorRole: "healthStaff",
    isCareTeam: true,
    route: "/student-health/x",
    purpose: "infirmary care",
  };
}

function teacherActor(): HealthActor {
  return {
    actorId: TEACHER,
    actorRole: "classTeacher",
    isCareTeam: false,
    route: "/student-health/students/x/care-alert",
    purpose: "class safety",
  };
}

// ─── actorFromClaims: the token is authoritative ─────────────────────────────

function claims(over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: NURSE,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL,
    role: "healthStaff",
    role_slugs: ["healthStaff"],
    primary_role: "healthStaff",
    permissions: ["manageStudentHealth", "viewStudentHealthRecord"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  };
}

Deno.test("actor: identity + roles come from the TOKEN, never the request", () => {
  const actor = actorFromClaims(claims(), "/r", "p");
  assertEquals(actor.actorId, NURSE);
  assertEquals(actor.actorRole, "healthStaff");
  assertEquals(actor.isCareTeam, true);
});

Deno.test("actor: isCareTeam is FALSE for a teaching role (drives the teach gate)", () => {
  const actor = actorFromClaims(
    claims({
      sub: TEACHER,
      role: "classTeacher",
      role_slugs: ["classTeacher"],
      permissions: ["viewStudentCareAlert"],
    }),
    "/r",
    "p",
  );
  assertEquals(actor.isCareTeam, false);
  assertEquals(actor.actorId, TEACHER);
});

// ─── The teacher surface ─────────────────────────────────────────────────────

Deno.test("care alert: a teacher is DENIED (403) for a student they do not teach", async () => {
  const mock = new HealthMockDb();
  mock.seedAlert();
  // mock.teaches is empty — no roster link.
  const error = await assertRejects(
    () => readCareAlertOp(db(mock), SCOPE, teacherActor(), STUDENT),
    StudentHealthError,
  );
  assertEquals(error.status, 403);
  assertEquals(error.code, "NOT_THIS_TEACHERS_STUDENT");
  // The deny happens BEFORE the read and before the audit row.
  assertEquals(mock.accessLog.length, 0);
});

Deno.test("care alert: a teacher IS allowed for a student they teach", async () => {
  const mock = new HealthMockDb();
  mock.seedAlert();
  mock.teaches.add(`${TEACHER}|${STUDENT}`);
  const alerts = await readCareAlertOp(db(mock), SCOPE, teacherActor(), STUDENT);
  assertEquals(alerts.length, 1);
  assertEquals(alerts[0]!.alert_label, "Severe peanut allergy");
});

Deno.test("care alert: teaching student A does NOT unlock student B", async () => {
  const mock = new HealthMockDb();
  mock.seedAlert({ id: ALERT_ID, studentId: OTHER_STUDENT });
  mock.teaches.add(`${TEACHER}|${STUDENT}`); // teaches A, asks for B
  const error = await assertRejects(
    () => readCareAlertOp(db(mock), SCOPE, teacherActor(), OTHER_STUDENT),
    StudentHealthError,
  );
  assertEquals(error.status, 403);
});

Deno.test("care alert: health staff need no teaching link (a nurse teaches nobody)", async () => {
  const mock = new HealthMockDb();
  mock.seedAlert();
  const alerts = await readCareAlertOp(db(mock), SCOPE, nurseActor(), STUDENT);
  assertEquals(alerts.length, 1);
});

Deno.test("care alert: retired (is_active=false) alerts are never returned", async () => {
  const mock = new HealthMockDb();
  mock.seedAlert({ isActive: false });
  const alerts = await readCareAlertOp(db(mock), SCOPE, nurseActor(), STUDENT);
  assertEquals(alerts.length, 0);
});

Deno.test("care alert: the teacher's rows carry NO clinical field", async () => {
  const mock = new HealthMockDb();
  mock.seedAlert();
  mock.teaches.add(`${TEACHER}|${STUDENT}`);
  const alerts = await readCareAlertOp(db(mock), SCOPE, teacherActor(), STUDENT);
  const keys = Object.keys(alerts[0]!);
  for (
    const forbidden of [
      "complaint_summary",
      "observations",
      "treatment_given",
      "outcome",
      "medication_name",
      "incident_type",
      "referred_to",
    ]
  ) {
    assertEquals(keys.includes(forbidden), false, `care alert leaked ${forbidden}`);
  }
});

// ─── Audit: exactly one row per sensitive access ─────────────────────────────

Deno.test("audit: reading the full record writes exactly ONE view_record row", async () => {
  const mock = new HealthMockDb();
  await readStudentRecordOp(db(mock), SCOPE, nurseActor(), STUDENT);
  assertEquals(mock.accessLog.length, 1);
  assertEquals(mock.accessLog[0]!.access_kind, "view_record");
  assertEquals(mock.accessLog[0]!.student_id, STUDENT);
  assertEquals(mock.accessLog[0]!.actor_id, NURSE);
  assertEquals(mock.accessLog[0]!.purpose, "infirmary care");
});

Deno.test("audit: listing incidents writes exactly ONE view_record row", async () => {
  const mock = new HealthMockDb();
  await listIncidentsOp(db(mock), SCOPE, nurseActor(), STUDENT);
  assertEquals(mock.accessLog.length, 1);
  assertEquals(mock.accessLog[0]!.access_kind, "view_record");
});

Deno.test("audit: a teacher's care-alert read writes exactly ONE view_care_alert row", async () => {
  const mock = new HealthMockDb();
  mock.seedAlert();
  mock.teaches.add(`${TEACHER}|${STUDENT}`);
  await readCareAlertOp(db(mock), SCOPE, teacherActor(), STUDENT);
  assertEquals(mock.accessLog.length, 1);
  assertEquals(mock.accessLog[0]!.access_kind, "view_care_alert");
  assertEquals(mock.accessLog[0]!.actor_id, TEACHER);
  assertEquals(mock.accessLog[0]!.actor_role, "classTeacher");
});

Deno.test("audit: recording an incident writes exactly ONE write_incident row", async () => {
  const mock = new HealthMockDb();
  await recordIncidentOp(db(mock), SCOPE, nurseActor(), {
    studentId: STUDENT,
    occurredAt: null,
    reportedBy: null,
    incidentType: "injury",
    complaintSummary: "Fell in the corridor",
    observations: "Grazed left knee",
    treatmentGiven: "Cleaned and dressed",
    outcome: "returned_to_class",
    referredTo: null,
  });
  assertEquals(mock.accessLog.length, 1);
  assertEquals(mock.accessLog[0]!.access_kind, "write_incident");
});

Deno.test("audit: creating an authorization writes exactly ONE write_authorization row", async () => {
  const mock = new HealthMockDb();
  await createAuthorizationOp(db(mock), SCOPE, nurseActor(), {
    studentId: STUDENT,
    medicationName: "Salbutamol inhaler",
    dosage: "2 puffs",
    route: "inhaled",
    scheduleNote: "As needed",
    validFrom: "2026-07-01",
    validUntil: "2026-12-31",
    authorizedByGuardianId: GUARDIAN,
    authorizationSource: "written_form",
    authorizationRef: "FORM-2026-014",
  });
  assertEquals(mock.accessLog.length, 1);
  assertEquals(mock.accessLog[0]!.access_kind, "write_authorization");
});

Deno.test("audit: administering writes exactly ONE administer_medication row", async () => {
  const mock = new HealthMockDb();
  mock.seedAuthorization();
  await administerMedicationOp(db(mock), SCOPE, nurseActor(), {
    authorizationId: AUTH_ID,
    expectedStudentId: null,
    dosageGiven: "2 puffs",
    note: "",
  });
  assertEquals(mock.accessLog.length, 1);
  assertEquals(mock.accessLog[0]!.access_kind, "administer_medication");
  assertEquals(mock.accessLog[0]!.student_id, STUDENT);
});

Deno.test("audit: revoking writes exactly ONE revoke_authorization row", async () => {
  const mock = new HealthMockDb();
  mock.seedAuthorization();
  await revokeAuthorizationOp(db(mock), SCOPE, nurseActor(), AUTH_ID);
  assertEquals(mock.accessLog.length, 1);
  assertEquals(mock.accessLog[0]!.access_kind, "revoke_authorization");
});

Deno.test("audit: creating a care alert writes ONE write_care_alert row (not write_incident)", async () => {
  const mock = new HealthMockDb();
  await createCareAlertOp(db(mock), SCOPE, nurseActor(), {
    studentId: STUDENT,
    label: "Severe peanut allergy",
    actionNote: "Epipen in infirmary.",
    severity: "critical",
  });
  assertEquals(mock.accessLog.length, 1);
  assertEquals(mock.accessLog[0]!.access_kind, "write_care_alert");
});

// ─── Incidents ───────────────────────────────────────────────────────────────

Deno.test("incident: recorded_by is the TOKEN subject even if the body claims otherwise", async () => {
  const mock = new HealthMockDb();
  await recordIncidentOp(db(mock), SCOPE, nurseActor(), {
    studentId: STUDENT,
    occurredAt: null,
    // A teacher legitimately flagged it; the AUTHOR is still the nurse.
    reportedBy: TEACHER,
    incidentType: "illness",
    complaintSummary: "Headache",
    observations: "",
    treatmentGiven: "Rest",
    outcome: "returned_to_class",
    referredTo: null,
  });
  assertEquals(mock.incidents[0]!.recorded_by, NURSE);
  assertEquals(mock.incidents[0]!.reported_by, TEACHER);
});

Deno.test("incident: an unknown student is rejected 404 and writes nothing", async () => {
  const mock = new HealthMockDb();
  const error = await assertRejects(
    () =>
      recordIncidentOp(db(mock), SCOPE, nurseActor(), {
        studentId: "a4000000-0000-4000-8000-0000000000ff",
        occurredAt: null,
        reportedBy: null,
        incidentType: "illness",
        complaintSummary: "x",
        observations: "",
        treatmentGiven: "",
        outcome: "observation",
        referredTo: null,
      }),
    StudentHealthError,
  );
  assertEquals(error.status, 404);
  assertEquals(mock.incidents.length, 0);
  assertEquals(mock.accessLog.length, 0);
});

// ─── Parent notification: NO clinical detail ─────────────────────────────────

Deno.test("notification: the guardian payload carries NO clinical detail", async () => {
  const mock = new HealthMockDb();
  const result = await recordIncidentOp(db(mock), SCOPE, nurseActor(), {
    studentId: STUDENT,
    occurredAt: null,
    reportedBy: null,
    incidentType: "allergic_reaction",
    complaintSummary: "Ate a peanut biscuit, lips swelling",
    observations: "Hives on neck; breathing clear",
    treatmentGiven: "Epipen administered",
    outcome: "referred_hospital",
    referredTo: "City Hospital",
  });

  assertEquals(result.notifiedGuardians, 1);
  assertEquals(mock.notifications.length, 1);
  const payload = JSON.stringify(mock.notifications[0]);

  // Every clinical string from the incident must be absent from the payload.
  for (
    const clinical of [
      "peanut",
      "biscuit",
      "swelling",
      "Hives",
      "Epipen",
      "allergic_reaction",
      "referred_hospital",
      "City Hospital",
      "breathing",
    ]
  ) {
    assertEquals(
      payload.toLowerCase().includes(clinical.toLowerCase()),
      false,
      `notification leaked clinical detail: ${clinical}`,
    );
  }
  // It says what the owner decision allows, and no more.
  assertEquals(mock.notifications[0]!.rendered_subject, PARENT_INCIDENT_NOTIFICATION_TITLE);
  assertEquals(mock.notifications[0]!.rendered_body, PARENT_INCIDENT_NOTIFICATION_BODY);
  assertStringIncludes(PARENT_INCIDENT_NOTIFICATION_BODY, "contact the school office");
});

Deno.test("notification: the dispatch ref is recorded on the incident", async () => {
  const mock = new HealthMockDb();
  const result = await recordIncidentOp(db(mock), SCOPE, nurseActor(), {
    studentId: STUDENT,
    occurredAt: null,
    reportedBy: null,
    incidentType: "illness",
    complaintSummary: "Fever",
    observations: "",
    treatmentGiven: "",
    outcome: "sent_home",
    referredTo: null,
  });
  assertEquals(result.incident.parent_notification_ref, "delivery-1");
  assertEquals(mock.incidents[0]!.parent_notification_ref, "delivery-1");
});

Deno.test("notification: a student with no active guardian leaves parent_notified_at NULL", async () => {
  const mock = new HealthMockDb();
  mock.guardians.set(STUDENT, []);
  const result = await recordIncidentOp(db(mock), SCOPE, nurseActor(), {
    studentId: STUDENT,
    occurredAt: null,
    reportedBy: null,
    incidentType: "illness",
    complaintSummary: "Fever",
    observations: "",
    treatmentGiven: "",
    outcome: "sent_home",
    referredTo: null,
  });
  // Honest: nobody was told, and the record does not pretend otherwise.
  assertEquals(result.notifiedGuardians, 0);
  assertEquals(result.incident.parent_notified_at, null);
  assertEquals(mock.notifications.length, 0);
});

// ─── Medication administration guards ────────────────────────────────────────

Deno.test("administer: REJECTED (422) against a revoked authorization", async () => {
  const mock = new HealthMockDb();
  mock.seedAuthorization({ status: "revoked" });
  const error = await assertRejects(
    () =>
      administerMedicationOp(db(mock), SCOPE, nurseActor(), {
        authorizationId: AUTH_ID,
        expectedStudentId: null,
        dosageGiven: "2 puffs",
        note: "",
      }),
    StudentHealthError,
  );
  assertEquals(error.status, 422);
  assertEquals(error.code, "AUTHORIZATION_NOT_ACTIVE");
  assertEquals(mock.administrations.length, 0);
  assertEquals(mock.accessLog.length, 0);
});

Deno.test("administer: REJECTED (422) against an EXPIRED window", async () => {
  const mock = new HealthMockDb();
  mock.seedAuthorization({ validFrom: "2026-01-01", validUntil: "2026-06-30" });
  const error = await assertRejects(
    () =>
      administerMedicationOp(db(mock), SCOPE, nurseActor(), {
        authorizationId: AUTH_ID,
        expectedStudentId: null,
        dosageGiven: "2 puffs",
        note: "",
      }),
    StudentHealthError,
  );
  assertEquals(error.status, 422);
  assertEquals(error.code, "AUTHORIZATION_EXPIRED");
  assertEquals(mock.administrations.length, 0);
});

Deno.test("administer: REJECTED (422) before the window opens", async () => {
  const mock = new HealthMockDb();
  mock.seedAuthorization({ validFrom: "2026-09-01", validUntil: null });
  const error = await assertRejects(
    () =>
      administerMedicationOp(db(mock), SCOPE, nurseActor(), {
        authorizationId: AUTH_ID,
        expectedStudentId: null,
        dosageGiven: "2 puffs",
        note: "",
      }),
    StudentHealthError,
  );
  assertEquals(error.code, "AUTHORIZATION_NOT_YET_VALID");
  assertEquals(mock.administrations.length, 0);
});

Deno.test("administer: an open-ended (valid_until NULL) authorization is administrable", async () => {
  const mock = new HealthMockDb();
  mock.seedAuthorization({ validUntil: null });
  const row = await administerMedicationOp(db(mock), SCOPE, nurseActor(), {
    authorizationId: AUTH_ID,
    expectedStudentId: null,
    dosageGiven: "2 puffs",
    note: "",
  });
  assertEquals(row.student_id, STUDENT);
  assertEquals(mock.administrations.length, 1);
});

Deno.test("administer: REJECTED (422) when the authorization is another student's", async () => {
  const mock = new HealthMockDb();
  mock.seedAuthorization({ studentId: OTHER_STUDENT });
  const error = await assertRejects(
    () =>
      administerMedicationOp(db(mock), SCOPE, nurseActor(), {
        authorizationId: AUTH_ID,
        expectedStudentId: STUDENT, // claims it is STUDENT's; it is not
        dosageGiven: "2 puffs",
        note: "",
      }),
    StudentHealthError,
  );
  assertEquals(error.code, "AUTHORIZATION_STUDENT_MISMATCH");
  assertEquals(mock.administrations.length, 0);
});

Deno.test("administer: the log's student comes from the AUTHORIZATION, not the request", async () => {
  const mock = new HealthMockDb();
  mock.seedAuthorization({ studentId: OTHER_STUDENT });
  const row = await administerMedicationOp(db(mock), SCOPE, nurseActor(), {
    authorizationId: AUTH_ID,
    expectedStudentId: null, // no assertion → the auth's own student wins
    dosageGiven: "2 puffs",
    note: "",
  });
  assertEquals(row.student_id, OTHER_STUDENT);
});

Deno.test("administer: 404 when the authorization is not in this school", async () => {
  const mock = new HealthMockDb();
  const error = await assertRejects(
    () =>
      administerMedicationOp(db(mock), SCOPE, nurseActor(), {
        authorizationId: "a6000000-0000-4000-8000-0000000000ff",
        expectedStudentId: null,
        dosageGiven: "2 puffs",
        note: "",
      }),
    StudentHealthError,
  );
  assertEquals(error.status, 404);
});

Deno.test("administer: a revoke landing AFTER the probe still stops the dose (atomic guard)", async () => {
  const mock = new HealthMockDb();
  const seed = mock.seedAuthorization();
  // The probe reads 'active'; a concurrent revoke commits before our INSERT.
  mock.onProbe = () => {
    seed.status = "revoked";
    mock.onProbe = null;
  };
  const error = await assertRejects(
    () =>
      administerMedicationOp(db(mock), SCOPE, nurseActor(), {
        authorizationId: AUTH_ID,
        expectedStudentId: null,
        dosageGiven: "2 puffs",
        note: "",
      }),
    StudentHealthError,
  );
  assertEquals(error.code, "AUTHORIZATION_NOT_ACTIVE");
  // The INSERT…SELECT guard matched 0 rows — no dose was logged.
  assertEquals(mock.administrations.length, 0);
  assertEquals(mock.accessLog.length, 0);
});

// ─── Concurrency: guarded terminal writes ────────────────────────────────────

Deno.test("revoke: the loser of a concurrent double-revoke writes NOTHING", async () => {
  const mock = new HealthMockDb();
  mock.seedAuthorization();

  // Winner.
  const first = await revokeAuthorizationOp(db(mock), SCOPE, nurseActor(), AUTH_ID);
  assertEquals(first.status, "revoked");
  assertEquals(mock.accessLog.length, 1);

  // Loser: `AND status='active'` matches 0 rows → throw → withTenantContext
  // rolls its transaction back, so no second audit row either.
  const error = await assertRejects(
    () => revokeAuthorizationOp(db(mock), SCOPE, nurseActor(), AUTH_ID),
    StudentHealthError,
  );
  assertEquals(error.status, 409);
  assertEquals(error.code, "AUTHORIZATION_NOT_ACTIVE");
  assertEquals(mock.accessLog.length, 1, "the loser must not append an audit row");
});

Deno.test("care alert: the loser of a concurrent double-deactivate writes NOTHING", async () => {
  const mock = new HealthMockDb();
  mock.seedAlert();

  const first = await updateCareAlertOp(db(mock), SCOPE, nurseActor(), ALERT_ID, {
    alertLabel: null,
    actionNote: null,
    severity: null,
    isActive: false,
  });
  assertEquals(first.is_active, false);
  assertEquals(mock.accessLog.length, 1);

  const error = await assertRejects(
    () =>
      updateCareAlertOp(db(mock), SCOPE, nurseActor(), ALERT_ID, {
        alertLabel: null,
        actionNote: null,
        severity: null,
        isActive: false,
      }),
    StudentHealthError,
  );
  assertEquals(error.status, 409);
  assertEquals(error.code, "CARE_ALERT_NOT_ACTIVE");
  assertEquals(mock.accessLog.length, 1, "the loser must not append an audit row");
});

// ─── Consent provenance ──────────────────────────────────────────────────────

Deno.test("authorization: a guardian who is not THIS child's guardian is rejected (422)", async () => {
  const mock = new HealthMockDb();
  const error = await assertRejects(
    () =>
      createAuthorizationOp(db(mock), SCOPE, nurseActor(), {
        studentId: STUDENT,
        medicationName: "Salbutamol inhaler",
        dosage: "2 puffs",
        route: "inhaled",
        scheduleNote: "",
        validFrom: "2026-07-01",
        validUntil: null,
        authorizedByGuardianId: "a5000000-0000-4000-8000-0000000000ff",
        authorizationSource: "written_form",
        authorizationRef: "FORM-1",
      }),
    StudentHealthError,
  );
  assertEquals(error.code, "GUARDIAN_NOT_LINKED");
  assertEquals(error.status, 422);
  assertEquals(mock.accessLog.length, 0);
});

Deno.test("authorization: consent provenance is persisted verbatim", async () => {
  const mock = new HealthMockDb();
  const row = await createAuthorizationOp(db(mock), SCOPE, nurseActor(), {
    studentId: STUDENT,
    medicationName: "Salbutamol inhaler",
    dosage: "2 puffs",
    route: "inhaled",
    scheduleNote: "As needed",
    validFrom: "2026-07-01",
    validUntil: "2026-12-31",
    authorizedByGuardianId: GUARDIAN,
    authorizationSource: "doctor_prescription",
    authorizationRef: "RX-2026-0912",
  });
  assertEquals(row.authorization_source, "doctor_prescription");
  assertEquals(row.authorization_ref, "RX-2026-0912");
  assertEquals(row.authorized_by_guardian_id, GUARDIAN);
  assertEquals(row.created_by, NURSE);
});

// ─── Immutability: the administration log has no update path ─────────────────

Deno.test("immutability: no code path UPDATEs or DELETEs the administration log", () => {
  const sources = [
    "student_health_repository.ts",
    "student_health_operations.ts",
    "student_health_handlers.ts",
  ];
  for (const file of sources) {
    const src = Deno.readTextFileSync(new URL(`./${file}`, import.meta.url));
    const table = "student_medication_administration_log";
    for (const verb of ["UPDATE", "DELETE FROM"]) {
      assertEquals(
        new RegExp(`${verb}\\s+${table}`, "i").test(src),
        false,
        `${file} must never ${verb} ${table}`,
      );
    }
  }
});

Deno.test("immutability: no code path UPDATEs or DELETEs the access log", () => {
  const sources = [
    "student_health_repository.ts",
    "student_health_operations.ts",
    "student_health_handlers.ts",
  ];
  for (const file of sources) {
    const src = Deno.readTextFileSync(new URL(`./${file}`, import.meta.url));
    const table = "student_health_access_log";
    for (const verb of ["UPDATE", "DELETE FROM"]) {
      assertEquals(
        new RegExp(`${verb}\\s+${table}`, "i").test(src),
        false,
        `${file} must never ${verb} ${table}`,
      );
    }
  }
});

Deno.test("migration: the immutable tables are granted only SELECT, INSERT", () => {
  const sql = Deno.readTextFileSync(
    new URL(
      "../../../migrations/20260887000000_student_health.sql",
      import.meta.url,
    ),
  );
  for (
    const table of [
      "student_medication_administration_log",
      "student_health_access_log",
    ]
  ) {
    assertStringIncludes(sql, `GRANT SELECT, INSERT ON ${table} TO erp_tenant;`);
    // No UPDATE/DELETE grant, and no UPDATE/DELETE policy, anywhere for them.
    assertEquals(
      new RegExp(`GRANT[^;]*UPDATE[^;]*ON ${table}`, "i").test(sql),
      false,
      `${table} must not be granted UPDATE`,
    );
    assertEquals(
      new RegExp(`GRANT[^;]*DELETE[^;]*ON ${table}`, "i").test(sql),
      false,
      `${table} must not be granted DELETE`,
    );
    assertEquals(
      new RegExp(`ON ${table}\\s+FOR (UPDATE|DELETE)`, "i").test(sql),
      false,
      `${table} must have no UPDATE/DELETE policy`,
    );
  }
});

Deno.test("migration: viewStudentHealthRecord is granted to NO teaching or admin role", () => {
  const sql = Deno.readTextFileSync(
    new URL(
      "../../../migrations/20260887000000_student_health.sql",
      import.meta.url,
    ),
  );
  // Isolate the grant block for the record permission.
  const block = sql.split("SELECT rd.slug, 'viewStudentHealthRecord'")[1]!
    .split("ON CONFLICT")[0]!;
  for (
    const forbidden of [
      "'teacher'",
      "'classTeacher'",
      "'coordinator'",
      "'officeStaff'",
      "'schoolAdmin'",
      "'management'",
      "'superAdmin'",
      "'organizationOwner'",
      "'organizationAdmin'",
      "'counselor'",
    ]
  ) {
    assertEquals(
      block.includes(forbidden),
      false,
      `viewStudentHealthRecord must not be granted to ${forbidden}`,
    );
  }
  for (const allowed of ["'healthStaff'", "'principal'", "'vicePrincipal'"]) {
    assertStringIncludes(block, allowed);
  }
});

Deno.test("migration: manage + administer are granted to healthStaff ONLY", () => {
  const sql = Deno.readTextFileSync(
    new URL(
      "../../../migrations/20260887000000_student_health.sql",
      import.meta.url,
    ),
  );
  for (const perm of ["manageStudentHealth", "administerStudentMedication"]) {
    const block = sql.split(`SELECT rd.slug, '${perm}'`)[1]!.split("ON CONFLICT")[0]!;
    assertStringIncludes(block, "WHERE rd.slug IN ('healthStaff')");
  }
});
