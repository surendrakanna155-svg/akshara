import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { matchSisRoute, routeSis } from "./sis_router.ts";
import { enrollmentToApi } from "../admissions/admissions_mapper.ts";
import type { AdmissionsEnrollmentRow } from "../admissions/admissions_mapper.ts";

Deno.test("sis router matches POST /sis/admissions-conversion", () => {
  const match = matchSisRoute("POST", "/sis/admissions-conversion");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleAdmissionsConversion");
});

Deno.test("conversion handler accepts classLabel alias in repository contract", async () => {
  const handlerSource = await Deno.readTextFile(
    new URL("./sis_conversion_handlers.ts", import.meta.url),
  );
  assertEquals(handlerSource.includes("classLabel"), true);
  assertEquals(handlerSource.includes("class_label"), true);
  assertEquals(handlerSource.includes("requirePermission(claims, \"manageSis\")"), true);
  assertEquals(handlerSource.includes("requireSchoolOperationalScope"), true);
});

// ─── #5 — GET /sis/admissions-conversion (route contract, DB-free) ──────────

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "clerk",
    role_slugs: ["clerk"],
    primary_role: "clerk",
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

async function call(
  method: string,
  path: string,
  perms: string[],
): Promise<Response> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const res = await routeSis(
    new Request(`https://x${path}`, {
      method,
      headers: { authorization: `Bearer ${token}` },
    }),
    config,
    method,
    path,
  );
  if (res === null) throw new Error(`routeSis returned null for ${method} ${path}`);
  return res;
}

Deno.test("#5: GET /sis/admissions-conversion requires viewSis (403 without it)", async () => {
  const res = await call("GET", "/sis/admissions-conversion", []);
  assertEquals(res.status, 403);
  assertEquals((await res.json()).error.code, "FORBIDDEN");
});

Deno.test("#5: GET /sis/admissions-conversion reaches the DB (503) with viewSis", async () => {
  const res = await call("GET", "/sis/admissions-conversion", ["viewSis"]);
  assertEquals(res.status, 503);
});

Deno.test("#5: an unauthenticated GET /sis/admissions-conversion is rejected (401)", async () => {
  const res = await routeSis(
    new Request("https://x/sis/admissions-conversion", { method: "GET" }),
    config,
    "GET",
    "/sis/admissions-conversion",
  );
  assertEquals(res?.status, 401);
});

// ─── #5 — reused-query mapping contract (repo) ──────────────────────────────
// Guards the REUSE decision: the SIS read must keep emitting exactly the field
// shape the client's SisMapper.toConversionQueueItem expects, since it is fed
// straight from admissions' enrollmentToApi (the same mapper that already
// backs GET /admissions/enrollments/pending) rather than a duplicate mapper.

Deno.test("#5: enrollmentToApi (reused for the SIS read) emits the fields the client conversion queue expects", () => {
  const row: AdmissionsEnrollmentRow = {
    id: "enr-1",
    organization_id: "org-1",
    school_id: "school-1",
    application_id: "app-1",
    student_id: "stu-1",
    guardian_user_id: "gu-1",
    student_name: "Asha Rao",
    seeking_class: "5",
    section: "A",
    academic_year: "2026-27",
    academic_year_id: "ay-1",
    class_id: "cls-1",
    section_id: "sec-1",
    guardian_name: "Ravi Rao",
    phone: "9999999999",
    gender: "female",
    date_of_birth: "2015-01-01",
    conversion_status: "pending",
    admission_number: "ADM-1",
    submitted_at: "2026-07-01T00:00:00Z",
    created_at: "2026-07-01T00:00:00Z",
  };

  const api = enrollmentToApi(row);

  for (
    const key of [
      "id",
      "studentName",
      "applicationId",
      "seekingClass",
      "section",
      "academicYear",
      "guardianName",
      "phone",
      "submittedAt",
      "conversionStatus",
      "generatedAdmissionNumber",
      "previewStudentId",
      "gender",
      "dateOfBirth",
    ]
  ) {
    assertEquals(key in api, true, `expected field '${key}' in enrollmentToApi output`);
  }
  assertEquals(api.conversionStatus, "pending");
  assertEquals(api.generatedAdmissionNumber, "ADM-1");
  assertEquals(api.previewStudentId, "stu-1");
});
