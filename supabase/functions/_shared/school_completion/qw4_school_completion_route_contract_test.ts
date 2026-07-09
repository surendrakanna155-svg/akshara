// QW4 · QA-B-011 + QA-B-046 — school_completion ROUTE/RBAC contract (DB-free).
//
// `routeSchoolCompletion` owns ~45 routes across five handler files
// (school_completion_handlers, phase9, phase10, phase15, timetable_workforce_
// handlers — added P0-2 gap-remediation wave). This file is
// table-driven: for every registered route we map the EXACT permission slug
// (grepped from each handler's requirePermission/requireAnyPermission call) and
// assert BOTH legs DB-free:
//   - HOLDER of the slug  → gate PASSES → reaches the unconfigured tenant DB → 503
//     (TENANT_DB_NOT_CONFIGURED, the DB-free proxy for "authorized").
//   - NON-HOLDER          → 403 FORBIDDEN.
// Plus path-match contract: an unregistered /school/ path → 404; a non-/school/
// path → router returns null.
//
// OR gates (timetables/automate, comms analytics) are covered with one case per
// alternative slug. Two reads gate on a MANAGE slug by design (rooms list,
// syllabus templates) — encoded faithfully, flagged in FINDINGS as a P3 note.
// Coverage: all ~40 routes have a holder+non-holder row below.
// Live remainder (infra): real persisted rows + per-school RLS = live cert.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeSchoolCompletion } from "./school_completion_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;
const UUID = "11111111-1111-4111-8111-111111111111";

function claims(permissions: string[]): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "principal",
    role_slugs: ["principal"],
    primary_role: "principal",
    permissions,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
  };
}

async function call(
  method: string,
  path: string,
  perms: string[],
  body?: unknown,
): Promise<Response> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const req = new Request(`https://x${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  // The router matches on the bare path; the handler reads any query from req.url.
  const matchPath = path.split("?")[0]!;
  const res = await routeSchoolCompletion(req, config, method, matchPath);
  if (res === null) throw new Error(`route returned null for ${method} ${path}`);
  return res;
}

// Each row: method, path, the slug that AUTHORIZES it, and a VALID body so the
// holder leg sails past validation to the DB boundary (503) rather than 422.
interface Row {
  method: string;
  path: string;
  slug: string;
  body?: unknown;
}

const ROUTES: Row[] = [
  // --- school_completion_handlers ---
  { method: "GET", path: "/school/subjects", slug: "viewSubjects" },
  { method: "POST", path: "/school/subjects", slug: "manageSubjects", body: { subjectCode: "MAT", subjectName: "Math" } },
  { method: "PATCH", path: `/school/subjects/${UUID}`, slug: "manageSubjects", body: { subjectName: "Maths" } },
  { method: "GET", path: "/school/lesson-logs", slug: "viewLessonLogs" },
  { method: "POST", path: "/school/lesson-logs", slug: "manageLessonLogs", body: { className: "8-A", topic: "Algebra" } },
  { method: "GET", path: "/school/branding", slug: "viewSchoolBranding" },
  { method: "PUT", path: "/school/branding", slug: "manageSchoolBranding", body: { primaryColor: "#fff" } },
  { method: "GET", path: "/school/whatsapp-provider", slug: "viewWhatsAppProvider" },
  // managePlatformWhatsApp is a platform slug (no school-scope gate).
  { method: "PUT", path: "/school/whatsapp-provider", slug: "managePlatformWhatsApp", body: { provider: "gupshup" } },
  { method: "POST", path: "/school/whatsapp-provider/test", slug: "managePlatformWhatsApp", body: { toPhone: "+919999999999" } },

  // --- phase9_handlers ---
  { method: "GET", path: "/school/class-subject-assignments", slug: "viewSubjectAssignments" },
  { method: "POST", path: "/school/class-subject-assignments", slug: "manageSubjectAssignments", body: { academicYearId: "ay-1", classId: "c-1", subjectId: "s-1" } },
  { method: "DELETE", path: `/school/class-subject-assignments/${UUID}`, slug: "manageSubjectAssignments" },
  { method: "GET", path: "/school/teacher-subject-assignments", slug: "viewSubjectAssignments" },
  { method: "POST", path: "/school/teacher-subject-assignments", slug: "manageSubjectAssignments", body: { academicYearId: "ay-1", teacherUserId: "t-1", subjectId: "s-1", classId: "c-1" } },
  { method: "GET", path: "/school/subject-workload", slug: "viewSubjectAssignments" },
  { method: "GET", path: "/school/lesson-analytics/teacher", slug: "viewLessonAnalytics" },
  { method: "GET", path: "/school/lesson-analytics/principal", slug: "viewLessonAnalytics" },
  // optimize reads academicYearId from the QUERY string → include it so the
  // holder leg passes validation and reaches the DB boundary (503).
  { method: "GET", path: "/school/timetables/optimize?academicYearId=ay-1", slug: "viewTimetableOptimization" },
  // P0-2 (gap-remediation wave) — 5 endpoints SubstituteManagerScreen /
  // TeacherReassignmentScreen / TimetableOptimizationScreen call, backed by
  // timetable_workforce_handlers + applyTimetableOptimization. Reads gate on
  // viewTimetableOptimization, writes on manageAcademicTimetable (route_guards.
  // dart: RouteNames.substituteManager/teacherReassignment → manageAcademicTimetable).
  { method: "POST", path: "/school/timetables/optimize/apply", slug: "manageAcademicTimetable", body: { academicYearId: "ay-1", applyAll: true } },
  { method: "GET", path: "/school/timetables/substitute/coverage?academicYearId=ay-1", slug: "viewTimetableOptimization" },
  { method: "POST", path: "/school/timetables/substitute/assign", slug: "manageAcademicTimetable", body: { slotId: "p1:2026-07-13", substituteTeacherId: "t-1" } },
  { method: "GET", path: "/school/timetables/reassign/options?academicYearId=ay-1", slug: "viewTimetableOptimization" },
  { method: "POST", path: "/school/timetables/reassign", slug: "manageAcademicTimetable", body: { academicYearId: "ay-1", sourceTeacherId: "t-1", targetTeacherId: "t-2", slotIds: ["p1"] } },
  { method: "GET", path: "/school/communications/delivery-analytics", slug: "viewCommunicationDelivery" },
  { method: "POST", path: "/school/communications/send-template", slug: "manageCommunicationTemplates", body: { templateCode: "tpl", recipientUserId: "u-9" } },
  { method: "GET", path: "/school/pilot/dashboard", slug: "viewPilotDashboard" },

  // --- phase15_handlers (all gate on the comms-analytics OR helper) ---
  { method: "GET", path: "/school/communications/analytics/summary", slug: "viewCommunicationAnalytics" },
  { method: "GET", path: "/school/communications/analytics/campaigns", slug: "viewCommunicationAnalytics" },
  { method: "GET", path: "/school/communications/analytics/delivery", slug: "viewCommunicationAnalytics" },
  { method: "GET", path: "/school/communications/analytics/effectiveness", slug: "viewCommunicationAnalytics" },
  { method: "GET", path: "/school/communications/analytics/parent-engagement", slug: "viewCommunicationAnalytics" },
  { method: "GET", path: "/school/communications/analytics/parent-adoption", slug: "viewCommunicationAnalytics" },
  { method: "GET", path: "/school/parent-activation/dashboard", slug: "viewCommunicationAnalytics" },

  // --- phase10_handlers ---
  { method: "GET", path: "/school/syllabus/templates", slug: "manageSyllabus" },
  { method: "POST", path: "/school/syllabus/generate", slug: "manageSyllabus", body: { academicYearId: "ay-1", className: "8-A", subjectId: "s-1", subjectName: "Math" } },
  { method: "POST", path: "/school/syllabus/clone", slug: "manageSyllabus", body: { fromYearId: "ay-1", toYearId: "ay-2" } },
  { method: "GET", path: "/school/syllabus/chapters", slug: "viewAcademicProgress" },
  { method: "POST", path: "/school/academic/complete-topic", slug: "manageAcademicProgress", body: { topicId: "t-1" } },
  { method: "GET", path: "/school/academic/teacher-progress", slug: "viewAcademicProgress" },
  { method: "GET", path: "/school/academic/principal-progress", slug: "viewAcademicProgress" },
  { method: "GET", path: "/school/rooms", slug: "manageAcademicRooms" },
  { method: "POST", path: "/school/rooms", slug: "manageAcademicRooms", body: { roomLabel: "R-101" } },
  // allocate reads academicYearId from the QUERY string (not the body).
  { method: "POST", path: "/school/rooms/allocate?academicYearId=ay-1", slug: "manageAcademicRooms" },
  { method: "POST", path: "/school/exam-timetable/generate", slug: "manageAcademicRooms", body: { academicYearId: "ay-1", className: "8-A", subjects: ["Math"], startDate: "2026-01-01" } },
  // intelligence also reads academicYearId from the QUERY string.
  { method: "GET", path: "/school/timetables/intelligence?academicYearId=ay-1", slug: "viewTimetableOptimization" },
];

// A slug a real caller would never carry for these routes — forces the 403 leg.
const NONHOLDER = ["viewProfileSelf"];

for (const r of ROUTES) {
  const pathOnly = r.path.split("?")[0]!;
  const slug = r.slug;

  Deno.test(`QA-B-011: ${r.method} ${pathOnly} authorizes a ${slug} holder (503)`, async () => {
    const res = await call(r.method, r.path, [slug], r.body);
    assertEquals(
      res.status,
      503,
      `${r.method} ${pathOnly} with ${slug} expected 503, got ${res.status}`,
    );
  });

  Deno.test(`QA-B-011: ${r.method} ${pathOnly} denies a non-holder (403)`, async () => {
    const res = await call(r.method, r.path, NONHOLDER, r.body);
    assertEquals(
      res.status,
      403,
      `${r.method} ${pathOnly} non-holder expected 403, got ${res.status}`,
    );
  });
}

// --- OR-gate alternative-slug coverage (the helpers accept either slug) ---
Deno.test("QA-B-011: timetables/automate OR-gate — manageAcademicTimetable authorizes (503)", async () => {
  const res = await call("POST", "/school/timetables/automate", ["manageAcademicTimetable"], { academicYearId: "ay-1" });
  assertEquals(res.status, 503);
});
Deno.test("QA-B-011: timetables/automate OR-gate — manageTimetableAutomation authorizes (503)", async () => {
  const res = await call("POST", "/school/timetables/automate", ["manageTimetableAutomation"], { academicYearId: "ay-1" });
  assertEquals(res.status, 503);
});
Deno.test("QA-B-011: timetables/automate denies a non-holder (403)", async () => {
  const res = await call("POST", "/school/timetables/automate", NONHOLDER, { academicYearId: "ay-1" });
  assertEquals(res.status, 403);
});
Deno.test("QA-B-011: comms analytics OR-gate — viewCommunicationDelivery authorizes the summary (503)", async () => {
  const res = await call("GET", "/school/communications/analytics/summary", ["viewCommunicationDelivery"]);
  assertEquals(res.status, 503);
});

// --- path-match contract (QA-B-046) ---
Deno.test("QA-B-046: a non-/school/ path → router returns null", async () => {
  const token = await signAccessToken(SECRET, claims(["viewSubjects"]), 900);
  const req = new Request("https://x/finance/refunds", {
    method: "GET",
    headers: { authorization: `Bearer ${token}` },
  });
  const res = await routeSchoolCompletion(req, config, "GET", "/finance/refunds");
  assertEquals(res, null);
});

Deno.test("QA-B-046: an unregistered /school/ path → 404 NOT_FOUND", async () => {
  const res = await call("GET", "/school/does-not-exist", ["viewSubjects"]);
  assertEquals(res.status, 404);
});

Deno.test("QA-B-046: a registered path with an unregistered method → 404", async () => {
  // /school/subjects has GET + POST only; DELETE is not registered.
  const res = await call("DELETE", "/school/subjects", ["manageSubjects"]);
  assertEquals(res.status, 404);
});

Deno.test("QA-B-046: a write rejects malformed input (422) before the DB", async () => {
  // POST /school/subjects with no fields → validation 422, proving the body check
  // fires after the gate but before the DB.
  const res = await call("POST", "/school/subjects", ["manageSubjects"], {});
  assertEquals(res.status, 422);
});
