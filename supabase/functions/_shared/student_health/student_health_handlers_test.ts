// PRC-A Batch 2 — Student Health / Infirmary: DB-free HTTP-level handler
// tests, mirroring the established route-contract pattern (see
// certificate_desk_handlers_test.ts): with no ERP_TENANT_DATABASE_URL /
// SUPABASE_* configured, `assertSessionValid` short-circuits to null
// (session_validation.ts skips the live lookup when supabaseUrl /
// supabaseServiceRoleKey are unset), so a request that clears every
// permission gate proceeds all the way to `withTenantContext` and fails
// there with a deterministic 503 TENANT_DB_NOT_CONFIGURED — proving the gate
// order (401 -> 403 -> 422 -> reaches DB) without a real Postgres connection.
//
// Owner decision #1 (LOCKED 2026-07-15) is strict need-to-know least-
// privilege for child medical data. THIS FILE is the executable proof of the
// RBAC matrix at the CODE level: which permission each route demands, that
// `manageStudentHealth` and `administerStudentMedication` are genuinely
// separate gates (not aliases), and that every denial is a well-formed
// FORBIDDEN envelope naming the permission it wants.
//
// ⚠ WHAT THIS FILE CANNOT PROVE (see the module report for the full list):
//   * RLS policies in 20260887000000_student_health.sql (tenant isolation,
//     the parent-own-child branch) — no live Postgres here.
//   * `teacherTeachesStudent`'s roster/timetable resolution — that a
//     `viewStudentCareAlert` holder is narrowed to students they actually
//     teach happens INSIDE the DB transaction (readCareAlertOp), which a
//     DB-free test never reaches. That fail-closed behaviour against a fake
//     DB is proven in student_health_repository_test.ts; the live join needs
//     a Postgres probe.
// These tests prove: the permission gate at the handler boundary is correct,
// and that a caller who clears it reaches the DB layer and NOTHING further.

import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeStudentHealth } from "./student_health_router.ts";
import {
  careAlertToApi,
  handleAdministerMedication,
} from "./student_health_handlers.ts";
import {
  HEALTH_PERM_ADMINISTER,
  HEALTH_PERM_MANAGE,
  HEALTH_PERM_VIEW_CARE_ALERT,
  HEALTH_PERM_VIEW_RECORD,
  type CareAlertRow,
} from "./student_health_types.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

const STUDENT = "a4000000-0000-4000-8000-000000000001";
const ALERT_ID = "a7000000-0000-4000-8000-000000000001";
const AUTH_ID = "a6000000-0000-4000-8000-000000000001";

function claims(perms: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "teacher",
    role_slugs: ["teacher"],
    primary_role: "teacher",
    permissions: perms,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  };
}

type Over = (Partial<AccessTokenClaims> & { permissions?: string[] }) | null | "invalid-token";

async function call(
  method: string,
  path: string,
  over: Over,
  body?: unknown,
): Promise<Response> {
  const init: RequestInit = { method };
  if (over === "invalid-token") {
    init.headers = { authorization: "Bearer not-a-real-jwt" };
  } else if (over) {
    const token = await signAccessToken(SECRET, claims(over.permissions ?? [], over), 900);
    init.headers = { authorization: `Bearer ${token}` };
  }
  if (body !== undefined) {
    init.headers = { ...(init.headers ?? {}), "content-type": "application/json" };
    init.body = JSON.stringify(body);
  }
  // Mirrors routePath(): the router matches on the PATHNAME only.
  const pathname = path.split("?")[0]!;
  const res = await routeStudentHealth(new Request(`https://x${path}`, init), config, method, pathname);
  if (res === null) throw new Error(`routeStudentHealth returned null for ${method} ${path}`);
  return res;
}

async function json(res: Response): Promise<{ data: unknown; error: { code: string; message: string } | null }> {
  return await res.json();
}

// Every route in the module, with a benign body for the writes. Used to sweep
// the 401 (no bearer / invalid bearer) contract across the whole surface.
const ALL_ROUTES: { method: string; path: string; body?: unknown }[] = [
  { method: "POST", path: "/student-health/incidents", body: {} },
  { method: "GET", path: `/student-health/incidents?studentId=${STUDENT}` },
  { method: "GET", path: `/student-health/students/${STUDENT}/record` },
  { method: "GET", path: `/student-health/students/${STUDENT}/care-alert` },
  { method: "POST", path: "/student-health/care-alerts", body: {} },
  { method: "PATCH", path: `/student-health/care-alerts/${ALERT_ID}`, body: {} },
  { method: "POST", path: "/student-health/authorizations", body: {} },
  { method: "POST", path: `/student-health/authorizations/${AUTH_ID}/revoke`, body: {} },
  { method: "POST", path: `/student-health/authorizations/${AUTH_ID}/administer`, body: {} },
  { method: "GET", path: `/student-health/access-log?studentId=${STUDENT}` },
];

// ─── 401: every route, no bearer AND an invalid bearer ───────────────────────

for (const r of ALL_ROUTES) {
  Deno.test(`401: ${r.method} ${r.path} with NO bearer token`, async () => {
    const res = await call(r.method, r.path, null, r.body);
    assertEquals(res.status, 401);
    const env = await json(res);
    assertEquals(env.data, null);
    assertEquals(env.error?.code, "UNAUTHORIZED");
  });

  Deno.test(`401: ${r.method} ${r.path} with an INVALID bearer token`, async () => {
    const res = await call(r.method, r.path, "invalid-token", r.body);
    assertEquals(res.status, 401);
    const env = await json(res);
    assertEquals(env.error?.code, "UNAUTHORIZED");
  });
}

// ─── 403 matrix — the core of owner decision #1 ──────────────────────────────

Deno.test("403: a teacher (ONLY viewStudentCareAlert) is DENIED the full clinical record route", async () => {
  const res = await call(
    "GET",
    `/student-health/students/${STUDENT}/record`,
    { permissions: [HEALTH_PERM_VIEW_CARE_ALERT], role: "classTeacher", role_slugs: ["classTeacher"] },
  );
  assertEquals(res.status, 403);
  const env = await json(res);
  assertEquals(env.error?.code, "FORBIDDEN");
  assertStringIncludes(env.error!.message, HEALTH_PERM_VIEW_RECORD);
});

Deno.test("403: a classTeacher (ONLY viewStudentCareAlert) is DENIED the incidents-list route", async () => {
  const res = await call(
    "GET",
    `/student-health/incidents?studentId=${STUDENT}`,
    { permissions: [HEALTH_PERM_VIEW_CARE_ALERT], role: "classTeacher", role_slugs: ["classTeacher"] },
  );
  assertEquals(res.status, 403);
  const env = await json(res);
  assertEquals(env.error?.code, "FORBIDDEN");
  assertStringIncludes(env.error!.message, HEALTH_PERM_VIEW_RECORD);
});

Deno.test("403: officeStaff holding neither health permission is DENIED the record route", async () => {
  const res = await call(
    "GET",
    `/student-health/students/${STUDENT}/record`,
    { permissions: [], role: "officeStaff", role_slugs: ["officeStaff"] },
  );
  assertEquals(res.status, 403);
  assertEquals((await json(res)).error?.code, "FORBIDDEN");
});

Deno.test("403: schoolAdmin holding neither health permission is DENIED the record route", async () => {
  const res = await call(
    "GET",
    `/student-health/students/${STUDENT}/record`,
    { permissions: [], role: "schoolAdmin", role_slugs: ["schoolAdmin"] },
  );
  assertEquals(res.status, 403);
  assertEquals((await json(res)).error?.code, "FORBIDDEN");
});

Deno.test("403: a school-scoped organizationAdmin holding neither health permission is DENIED the record route", async () => {
  // Deliberately school-scoped (not organization-scoped) so the denial is
  // proven to be the PERMISSION gate, not the scope gate — see the dedicated
  // scope-rejection tests below for the scope case.
  const res = await call(
    "GET",
    `/student-health/students/${STUDENT}/record`,
    { permissions: [], role: "organizationAdmin", role_slugs: ["organizationAdmin"], scope: "school" },
  );
  assertEquals(res.status, 403);
  const env = await json(res);
  assertEquals(env.error?.code, "FORBIDDEN");
  assertStringIncludes(env.error!.message, HEALTH_PERM_VIEW_RECORD);
});

Deno.test("403: without manageStudentHealth, cannot create an incident", async () => {
  const res = await call("POST", "/student-health/incidents", { permissions: [] }, {
    studentId: STUDENT,
    incidentType: "illness",
    outcome: "returned_to_class",
  });
  assertEquals(res.status, 403);
  const env = await json(res);
  assertEquals(env.error?.code, "FORBIDDEN");
  assertStringIncludes(env.error!.message, HEALTH_PERM_MANAGE);
});

Deno.test("403: without manageStudentHealth, cannot create a care alert", async () => {
  const res = await call("POST", "/student-health/care-alerts", { permissions: [] }, {
    studentId: STUDENT,
    label: "Severe peanut allergy",
  });
  assertEquals(res.status, 403);
  const env = await json(res);
  assertEquals(env.error?.code, "FORBIDDEN");
  assertStringIncludes(env.error!.message, HEALTH_PERM_MANAGE);
});

Deno.test("403: without manageStudentHealth, cannot create a medication authorization", async () => {
  const res = await call("POST", "/student-health/authorizations", { permissions: [] }, {
    studentId: STUDENT,
    medicationName: "Salbutamol inhaler",
    dosage: "2 puffs",
    validFrom: "2026-07-01",
    authorizationSource: "written_form",
    authorizationRef: "FORM-1",
  });
  assertEquals(res.status, 403);
  const env = await json(res);
  assertEquals(env.error?.code, "FORBIDDEN");
  assertStringIncludes(env.error!.message, HEALTH_PERM_MANAGE);
});

Deno.test("403: without manageStudentHealth, cannot revoke an authorization", async () => {
  const res = await call(
    "POST",
    `/student-health/authorizations/${AUTH_ID}/revoke`,
    { permissions: [] },
    {},
  );
  assertEquals(res.status, 403);
  const env = await json(res);
  assertEquals(env.error?.code, "FORBIDDEN");
  assertStringIncludes(env.error!.message, HEALTH_PERM_MANAGE);
});

Deno.test("403: without manageStudentHealth, cannot update/retire a care alert", async () => {
  const res = await call(
    "PATCH",
    `/student-health/care-alerts/${ALERT_ID}`,
    { permissions: [] },
    { isActive: false },
  );
  assertEquals(res.status, 403);
  const env = await json(res);
  assertEquals(env.error?.code, "FORBIDDEN");
  assertStringIncludes(env.error!.message, HEALTH_PERM_MANAGE);
});

Deno.test("403: without administerStudentMedication, cannot administer medication", async () => {
  const res = await call(
    "POST",
    `/student-health/authorizations/${AUTH_ID}/administer`,
    { permissions: [] },
    { dosageGiven: "2 puffs" },
  );
  assertEquals(res.status, 403);
  const env = await json(res);
  assertEquals(env.error?.code, "FORBIDDEN");
  assertStringIncludes(env.error!.message, HEALTH_PERM_ADMINISTER);
});

Deno.test("403: manageStudentHealth does NOT imply administerStudentMedication — the two gates are separate, not aliases", async () => {
  // Holds the WRITE-everything-else permission but not the administer one.
  const res = await call(
    "POST",
    `/student-health/authorizations/${AUTH_ID}/administer`,
    { permissions: [HEALTH_PERM_MANAGE], role: "healthStaff", role_slugs: ["healthStaff"] },
    { dosageGiven: "2 puffs" },
  );
  assertEquals(res.status, 403);
  const env = await json(res);
  assertEquals(env.error?.code, "FORBIDDEN");
  assertStringIncludes(env.error!.message, HEALTH_PERM_ADMINISTER);
});

Deno.test("403: administerStudentMedication alone does NOT imply manageStudentHealth — cannot create an authorization", async () => {
  // The converse of the alias check: holding ONLY the narrow administer
  // permission must not unlock the broader manage-everything-else surface.
  const res = await call(
    "POST",
    "/student-health/authorizations",
    { permissions: [HEALTH_PERM_ADMINISTER], role: "healthStaff", role_slugs: ["healthStaff"] },
    {
      studentId: STUDENT,
      medicationName: "Salbutamol inhaler",
      dosage: "2 puffs",
      validFrom: "2026-07-01",
      authorizationSource: "written_form",
      authorizationRef: "FORM-1",
    },
  );
  assertEquals(res.status, 403);
  const env = await json(res);
  assertEquals(env.error?.code, "FORBIDDEN");
  assertStringIncludes(env.error!.message, HEALTH_PERM_MANAGE);
});

Deno.test("care-alert route ALLOWS a viewStudentCareAlert holder — no false 403 (reaches the DB layer, 503)", async () => {
  const res = await call(
    "GET",
    `/student-health/students/${STUDENT}/care-alert`,
    { permissions: [HEALTH_PERM_VIEW_CARE_ALERT], role: "classTeacher", role_slugs: ["classTeacher"] },
  );
  assertEquals(res.status, 503);
  assertEquals((await json(res)).error?.code, "TENANT_DB_NOT_CONFIGURED");
});

Deno.test("care-alert route ALLOWS a health-staff holder too (isCareTeam path, no false 403)", async () => {
  const res = await call(
    "GET",
    `/student-health/students/${STUDENT}/care-alert`,
    {
      permissions: [HEALTH_PERM_VIEW_CARE_ALERT, HEALTH_PERM_VIEW_RECORD],
      role: "healthStaff",
      role_slugs: ["healthStaff"],
    },
  );
  assertEquals(res.status, 503);
});

Deno.test("403: the FORBIDDEN envelope is well-formed and names the missing permission (shape check)", async () => {
  const res = await call("POST", "/student-health/care-alerts", { permissions: [] }, {});
  assertEquals(res.status, 403);
  const env = await json(res);
  assertEquals(env.data, null);
  assertEquals(typeof env.error?.code, "string");
  assertEquals(env.error?.code, "FORBIDDEN");
  assertEquals(typeof env.error?.message, "string");
  assertStringIncludes(env.error!.message, HEALTH_PERM_MANAGE);
});

// ─── non-school scope rejected, even carrying the right permission(s) ───────

Deno.test("scope: a parent-scope caller is rejected on the incident-write route even WITH manageStudentHealth", async () => {
  const res = await call(
    "POST",
    "/student-health/incidents",
    { permissions: [HEALTH_PERM_MANAGE], scope: "parent", child_ids: ["c1"] },
    { studentId: STUDENT, incidentType: "illness", outcome: "returned_to_class" },
  );
  assertEquals(res.status, 403);
  assertEquals((await json(res)).error?.code, "FORBIDDEN");
});

Deno.test("scope: an organization-scope caller (no school_id) is rejected on the record route even WITH viewStudentHealthRecord", async () => {
  const res = await call(
    "GET",
    `/student-health/students/${STUDENT}/record`,
    { permissions: [HEALTH_PERM_VIEW_RECORD], scope: "organization", school_id: null },
  );
  assertEquals(res.status, 403);
  assertEquals((await json(res)).error?.code, "FORBIDDEN");
});

Deno.test("scope: a parent-scope caller is rejected on the care-alert route even WITH viewStudentCareAlert", async () => {
  const res = await call(
    "GET",
    `/student-health/students/${STUDENT}/care-alert`,
    { permissions: [HEALTH_PERM_VIEW_CARE_ALERT], scope: "parent", child_ids: ["c1"] },
  );
  assertEquals(res.status, 403);
  assertEquals((await json(res)).error?.code, "FORBIDDEN");
});

Deno.test("scope: an organization-scope caller is rejected on the administer route even WITH administerStudentMedication", async () => {
  const res = await call(
    "POST",
    `/student-health/authorizations/${AUTH_ID}/administer`,
    { permissions: [HEALTH_PERM_ADMINISTER], scope: "organization", school_id: null },
    { dosageGiven: "2 puffs" },
  );
  assertEquals(res.status, 403);
  assertEquals((await json(res)).error?.code, "FORBIDDEN");
});

Deno.test("scope: a school-scope caller with NO school_id is rejected (belt-and-braces on requireSchoolOperationalScope)", async () => {
  const res = await call(
    "GET",
    `/student-health/students/${STUDENT}/record`,
    { permissions: [HEALTH_PERM_VIEW_RECORD], scope: "school", school_id: null },
  );
  assertEquals(res.status, 403);
});

// ─── validation: malformed/missing body fields -> 422, never 500 ────────────

const NURSE_MANAGE = { permissions: [HEALTH_PERM_MANAGE], role: "healthStaff", role_slugs: ["healthStaff"] };
const NURSE_READ = { permissions: [HEALTH_PERM_VIEW_RECORD], role: "healthStaff", role_slugs: ["healthStaff"] };
const NURSE_ADMINISTER = {
  permissions: [HEALTH_PERM_ADMINISTER],
  role: "healthStaff",
  role_slugs: ["healthStaff"],
};

Deno.test("422: create incident — missing studentId", async () => {
  const res = await call("POST", "/student-health/incidents", NURSE_MANAGE, {
    incidentType: "illness",
    outcome: "returned_to_class",
  });
  assertEquals(res.status, 422);
  assertEquals((await json(res)).error?.code, "VALIDATION_ERROR");
});

Deno.test("422: create incident — malformed (non-JSON) body degrades to 422, not 500", async () => {
  const token = await signAccessToken(SECRET, claims(NURSE_MANAGE.permissions, NURSE_MANAGE), 900);
  const req = new Request("https://x/student-health/incidents", {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: "{not valid json",
  });
  const res = await routeStudentHealth(req, config, "POST", "/student-health/incidents");
  assertEquals(res?.status, 422);
  assertEquals((await res!.json()).error?.code, "VALIDATION_ERROR");
});

Deno.test("422: create incident — invalid incidentType", async () => {
  const res = await call("POST", "/student-health/incidents", NURSE_MANAGE, {
    studentId: STUDENT,
    incidentType: "not-a-real-type",
    outcome: "returned_to_class",
  });
  assertEquals(res.status, 422);
});

Deno.test("422: create incident — invalid outcome", async () => {
  const res = await call("POST", "/student-health/incidents", NURSE_MANAGE, {
    studentId: STUDENT,
    incidentType: "illness",
    outcome: "not-a-real-outcome",
  });
  assertEquals(res.status, 422);
});

Deno.test("422: create care alert — missing studentId", async () => {
  const res = await call("POST", "/student-health/care-alerts", NURSE_MANAGE, {
    label: "Severe peanut allergy",
  });
  assertEquals(res.status, 422);
});

Deno.test("422: create care alert — label under 3 chars", async () => {
  const res = await call("POST", "/student-health/care-alerts", NURSE_MANAGE, {
    studentId: STUDENT,
    label: "ab",
  });
  assertEquals(res.status, 422);
});

Deno.test("422: create care alert — invalid severity", async () => {
  const res = await call("POST", "/student-health/care-alerts", NURSE_MANAGE, {
    studentId: STUDENT,
    label: "Severe peanut allergy",
    severity: "urgent-ish",
  });
  assertEquals(res.status, 422);
});

Deno.test("422: update care alert — a non-UUID alert id in the path", async () => {
  const res = await call("PATCH", "/student-health/care-alerts/not-a-uuid", NURSE_MANAGE, {
    isActive: false,
  });
  assertEquals(res.status, 422);
});

Deno.test("422: update care alert — invalid severity in the body", async () => {
  const res = await call("PATCH", `/student-health/care-alerts/${ALERT_ID}`, NURSE_MANAGE, {
    severity: "urgent-ish",
  });
  assertEquals(res.status, 422);
});

Deno.test("422: create authorization — missing studentId", async () => {
  const res = await call("POST", "/student-health/authorizations", NURSE_MANAGE, {
    medicationName: "Salbutamol inhaler",
    dosage: "2 puffs",
    validFrom: "2026-07-01",
    authorizationSource: "written_form",
    authorizationRef: "FORM-1",
  });
  assertEquals(res.status, 422);
});

Deno.test("422: create authorization — medicationName under 2 chars", async () => {
  const res = await call("POST", "/student-health/authorizations", NURSE_MANAGE, {
    studentId: STUDENT,
    medicationName: "S",
    dosage: "2 puffs",
    validFrom: "2026-07-01",
    authorizationSource: "written_form",
    authorizationRef: "FORM-1",
  });
  assertEquals(res.status, 422);
});

Deno.test("422: create authorization — missing dosage", async () => {
  const res = await call("POST", "/student-health/authorizations", NURSE_MANAGE, {
    studentId: STUDENT,
    medicationName: "Salbutamol inhaler",
    validFrom: "2026-07-01",
    authorizationSource: "written_form",
    authorizationRef: "FORM-1",
  });
  assertEquals(res.status, 422);
});

Deno.test("422: create authorization — malformed validFrom", async () => {
  const res = await call("POST", "/student-health/authorizations", NURSE_MANAGE, {
    studentId: STUDENT,
    medicationName: "Salbutamol inhaler",
    dosage: "2 puffs",
    validFrom: "07-01-2026",
    authorizationSource: "written_form",
    authorizationRef: "FORM-1",
  });
  assertEquals(res.status, 422);
});

Deno.test("422: create authorization — malformed validUntil", async () => {
  const res = await call("POST", "/student-health/authorizations", NURSE_MANAGE, {
    studentId: STUDENT,
    medicationName: "Salbutamol inhaler",
    dosage: "2 puffs",
    validFrom: "2026-07-01",
    validUntil: "not-a-date",
    authorizationSource: "written_form",
    authorizationRef: "FORM-1",
  });
  assertEquals(res.status, 422);
});

Deno.test("422: create authorization — validUntil before validFrom", async () => {
  const res = await call("POST", "/student-health/authorizations", NURSE_MANAGE, {
    studentId: STUDENT,
    medicationName: "Salbutamol inhaler",
    dosage: "2 puffs",
    validFrom: "2026-07-15",
    validUntil: "2026-01-01",
    authorizationSource: "written_form",
    authorizationRef: "FORM-1",
  });
  assertEquals(res.status, 422);
});

Deno.test("422: create authorization — invalid authorizationSource", async () => {
  const res = await call("POST", "/student-health/authorizations", NURSE_MANAGE, {
    studentId: STUDENT,
    medicationName: "Salbutamol inhaler",
    dosage: "2 puffs",
    validFrom: "2026-07-01",
    authorizationSource: "a-verbal-promise",
    authorizationRef: "FORM-1",
  });
  assertEquals(res.status, 422);
});

Deno.test("422: create authorization — missing authorizationRef (consent provenance is mandatory)", async () => {
  const res = await call("POST", "/student-health/authorizations", NURSE_MANAGE, {
    studentId: STUDENT,
    medicationName: "Salbutamol inhaler",
    dosage: "2 puffs",
    validFrom: "2026-07-01",
    authorizationSource: "written_form",
  });
  assertEquals(res.status, 422);
});

Deno.test("422: administer medication — a non-UUID authorization id in the path", async () => {
  const res = await call("POST", "/student-health/authorizations/not-a-uuid/administer", NURSE_ADMINISTER, {
    dosageGiven: "2 puffs",
  });
  assertEquals(res.status, 422);
});

Deno.test("422: administer medication — missing dosageGiven", async () => {
  const res = await call(
    "POST",
    `/student-health/authorizations/${AUTH_ID}/administer`,
    NURSE_ADMINISTER,
    {},
  );
  assertEquals(res.status, 422);
});

Deno.test("422: get student record — a non-UUID student id in the path", async () => {
  const res = await call("GET", "/student-health/students/not-a-uuid/record", NURSE_READ);
  assertEquals(res.status, 422);
});

Deno.test("422: get care alert — a non-UUID student id in the path", async () => {
  const res = await call("GET", "/student-health/students/not-a-uuid/care-alert", {
    permissions: [HEALTH_PERM_VIEW_CARE_ALERT],
  });
  assertEquals(res.status, 422);
});

Deno.test("422: list incidents — missing ?studentId=", async () => {
  const res = await call("GET", "/student-health/incidents", NURSE_READ);
  assertEquals(res.status, 422);
});

Deno.test("422: list incidents — a non-UUID ?studentId=", async () => {
  const res = await call("GET", "/student-health/incidents?studentId=not-a-uuid", NURSE_READ);
  assertEquals(res.status, 422);
});

Deno.test("422: access log — missing ?studentId=", async () => {
  const res = await call("GET", "/student-health/access-log", NURSE_READ);
  assertEquals(res.status, 422);
});

// ─── happy-permission path reaches the DB layer and nothing further ─────────
// (Full behaviour — audits, notification-detail-free bodies, guard races —
// is proven against the fake DB in student_health_repository_test.ts. Here we
// only prove the handler's OWN gates let a valid caller through.)

Deno.test("reaches DB (503): nurse creating a well-formed incident clears every handler gate", async () => {
  const res = await call("POST", "/student-health/incidents", NURSE_MANAGE, {
    studentId: STUDENT,
    incidentType: "illness",
    outcome: "returned_to_class",
    complaintSummary: "Headache",
    treatmentGiven: "Rest",
  });
  assertEquals(res.status, 503);
  assertEquals((await json(res)).error?.code, "TENANT_DB_NOT_CONFIGURED");
});

Deno.test("reaches DB (503): principal (leadership) can read the full record", async () => {
  const res = await call(
    "GET",
    `/student-health/students/${STUDENT}/record`,
    { permissions: [HEALTH_PERM_VIEW_RECORD], role: "principal", role_slugs: ["principal"] },
  );
  assertEquals(res.status, 503);
});

Deno.test("reaches DB (503): vicePrincipal (leadership) can read the full record", async () => {
  const res = await call(
    "GET",
    `/student-health/students/${STUDENT}/record`,
    { permissions: [HEALTH_PERM_VIEW_RECORD], role: "vicePrincipal", role_slugs: ["vicePrincipal"] },
  );
  assertEquals(res.status, 503);
});

Deno.test("reaches DB (503): nurse administering with a well-formed body clears every handler gate", async () => {
  const res = await call(
    "POST",
    `/student-health/authorizations/${AUTH_ID}/administer`,
    NURSE_ADMINISTER,
    { dosageGiven: "2 puffs", note: "" },
  );
  assertEquals(res.status, 503);
});

// ─── careAlertToApi: the ONLY mapper reachable from the teacher route ───────
// Pure function, no DB needed. Defense-in-depth on top of the repository
// test (which asserts the raw DB row's keys); this asserts the API SHAPE
// itself has no field a clinical string could ever be written into.

Deno.test("careAlertToApi: the teacher-facing shape carries exactly the 5 allowed fields and nothing else", () => {
  const row: CareAlertRow = {
    id: ALERT_ID,
    student_id: STUDENT,
    alert_label: "Severe peanut allergy",
    action_note: "Epipen in infirmary. Call infirmary immediately.",
    severity: "critical",
    is_active: true,
    created_by: "nurse-1",
    created_at: "2026-07-01T00:00:00.000Z",
    updated_at: "2026-07-01T00:00:00.000Z",
  };
  const api = careAlertToApi(row);
  assertEquals(
    Object.keys(api).sort(),
    ["actionNote", "id", "label", "severity", "studentId"].sort(),
  );
  assertEquals(api.label, "Severe peanut allergy");
  assertEquals(api.actionNote, "Epipen in infirmary. Call infirmary immediately.");
  assertEquals(api.severity, "critical");
});

Deno.test("handleAdministerMedication is exported with the name the router dispatch relies on", () => {
  // Guards the router's `match?.handler.name` assertions in
  // student_health_router_test.ts against an accidental rename.
  assertEquals(handleAdministerMedication.name, "handleAdministerMedication");
});
