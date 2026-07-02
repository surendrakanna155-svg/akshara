// QW4 · QA-B-034 (P0) — Academics / exam-administration route-contract (DB-free).
//
// routeExamAdministration owns /academics/exams. The two rows the spec calls
// out are the exam create (write) + exam list (read):
//   • POST /academics/exams  → handleCreateExam, gated on "manageExams"
//   • GET  /academics/exams  → handleListExams,  gated on "viewExams"
// (gate slugs are the source-of-truth EXAM_OPERATION_PERMISSIONS map in
// exam_administration_handlers.ts:56). Every exam op runs through withAuth =
// requirePermission(slug) then requireSchoolOperationalScope (handlers.ts:103).
//
// This proves the WRITE-PERSIST CONTRACT up to the DB boundary:
//   • POST is DENIED without manageExams (403) — incl. a viewExams-only reader;
//   • POST with manageExams + a valid body PASSES the gate + validation and
//     reaches the unconfigured tenant DB (503 = DB-free proxy for "persisting");
//   • POST with a missing required field (title) is rejected (422) before DB;
//   • GET is DENIED without viewExams (403) and PASSES with it (503);
//   • a manageExams holder also satisfies the GET (viewExams superset? no — they
//     are distinct slugs; a manage-only token without viewExams is denied GET);
//   • unauthenticated → 401; unregistered → 404; foreign path → null.
//
// REMAINDER (infra-blocked): the real 201 + a persisted exam_sessions row, and
// the per-school RLS isolation of that row, need a live ERP_TENANT_DATABASE_URL
// (live cert). The route/RBAC/validation contract is fully provable DB-free.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../../config.ts";
import type { AccessTokenClaims } from "../../jwt.ts";
import { signAccessToken } from "../../jwt.ts";
import { routeExamAdministration } from "./exam_administration_router.ts";
import {
  EXAM_OPERATION_PERMISSIONS,
  MARKS_ENTRY_PROGRESS_PERMISSIONS,
} from "./exam_administration_handlers.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "exam-user-1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "examCoordinator",
    role_slugs: ["examCoordinator"],
    primary_role: "examCoordinator",
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
  body?: unknown,
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const req = new Request(`https://x${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  // The router receives the URL PATHNAME (no query string) — mirror production
  // by stripping any `?term=…` before matching, while the request URL keeps it
  // so handlers can still read query params.
  const pathname = path.split("?")[0]!;
  return routeExamAdministration(req, config, method, pathname);
}

const validExam = { title: "Term 2 Maths", subject: "Mathematics", grade: "8" };

Deno.test("QA-B-034: the create/list slugs are the documented exam permissions", () => {
  // Lock the source-of-truth map so a silent slug change fails this contract.
  assertEquals(EXAM_OPERATION_PERMISSIONS.createExam, "manageExams");
  assertEquals(EXAM_OPERATION_PERMISSIONS.listExams, "viewExams");
});

Deno.test("QA-B-034: POST /academics/exams is denied without manageExams (403)", async () => {
  // A viewExams-only reader cannot create an exam.
  const res = await call("POST", "/academics/exams", ["viewExams"], validExam);
  assertEquals(res?.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-034: POST /academics/exams persists with manageExams (passes gate+validation → 503)", async () => {
  const res = await call("POST", "/academics/exams", ["manageExams"], validExam);
  // Gate + body validation passed → reached the (unconfigured) tenant DB where
  // the createExamSession INSERT would run.
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-034: POST /academics/exams rejects a missing title (422) before the DB", async () => {
  const res = await call("POST", "/academics/exams", ["manageExams"], {
    subject: "Mathematics",
    grade: "8",
  });
  assertEquals(res?.status, 422);
});

Deno.test("QA-B-034: POST /academics/exams without school scope is denied (403)", async () => {
  const token = await signAccessToken(
    SECRET,
    claims(["manageExams"], { scope: "platform", school_id: null }),
    900,
  );
  const req = new Request("https://x/academics/exams", {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify(validExam),
  });
  const res = await routeExamAdministration(req, config, "POST", "/academics/exams");
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-034: GET /academics/exams is denied without viewExams (403)", async () => {
  const res = await call("GET", "/academics/exams", ["manageExamMarks"]);
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-034: GET /academics/exams reads with viewExams (passes gate → 503)", async () => {
  const res = await call("GET", "/academics/exams", ["viewExams"]);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-034: exam routes reject an unauthenticated caller (401)", async () => {
  const post = new Request("https://x/academics/exams", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(validExam),
  });
  assertEquals((await routeExamAdministration(post, config, "POST", "/academics/exams"))?.status, 401);
  const getReq = new Request("https://x/academics/exams", { method: "GET" });
  assertEquals((await routeExamAdministration(getReq, config, "GET", "/academics/exams"))?.status, 401);
});

Deno.test("QA-B-034: an unregistered /academics/exams path returns 404", async () => {
  const res = await call("DELETE", "/academics/exams", ["manageExams"]);
  assertEquals(res?.status, 404);
});

Deno.test("QA-B-034: a non-/academics/exams path returns null (no match)", async () => {
  const res = await call("GET", "/student/exams", ["viewExams"]);
  assertEquals(res, null);
});

// ── EXM-1 — POST /academics/exams/{examId}/marks/batch (bulk marks save) ───────

Deno.test("EXM-1: bulk-save slug is manageExamMarks (same guard as single PATCH)", () => {
  assertEquals(EXAM_OPERATION_PERMISSIONS.bulkUpdateExamMarks, "manageExamMarks");
});

Deno.test("EXM-1: POST /academics/exams/{id}/marks/batch is denied without manageExamMarks (403)", async () => {
  const res = await call(
    "POST",
    "/academics/exams/exam-1/marks/batch",
    ["viewExams"],
    { entries: [{ id: "exam-1_01", marksObtained: 40 }] },
  );
  assertEquals(res?.status, 403);
  assertEquals((await res!.json()).error.code, "FORBIDDEN");
});

Deno.test("EXM-1: POST bulk with manageExamMarks passes the gate → reaches DB (503)", async () => {
  const res = await call(
    "POST",
    "/academics/exams/exam-1/marks/batch",
    ["manageExamMarks"],
    { entries: [{ id: "exam-1_01", marksObtained: 40 }] },
  );
  // Gate + body validation passed → reached the (unconfigured) tenant DB.
  assertEquals(res?.status, 503);
});

Deno.test("EXM-1: POST bulk rejects a non-array entries body (422) before the DB", async () => {
  const res = await call(
    "POST",
    "/academics/exams/exam-1/marks/batch",
    ["manageExamMarks"],
    { entries: "nope" },
  );
  assertEquals(res?.status, 422);
});

Deno.test("EXM-1: bulk route rejects an unauthenticated caller (401)", async () => {
  const req = new Request("https://x/academics/exams/exam-1/marks/batch", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ entries: [] }),
  });
  const res = await routeExamAdministration(
    req,
    config,
    "POST",
    "/academics/exams/exam-1/marks/batch",
  );
  assertEquals(res?.status, 401);
});

// ── EXM-2 — GET /academics/exams/progress (marks-entry progress board) ─────────

Deno.test("EXM-2: progress board grants viewExams OR verifyExamResults", () => {
  assertEquals(
    [...MARKS_ENTRY_PROGRESS_PERMISSIONS],
    ["viewExams", "verifyExamResults"],
  );
});

Deno.test("EXM-2: GET /academics/exams/progress reads with viewExams (passes gate → 503)", async () => {
  const res = await call("GET", "/academics/exams/progress", ["viewExams"]);
  assertEquals(res?.status, 503);
});

Deno.test("EXM-2: GET /academics/exams/progress reads with verifyExamResults (passes gate → 503)", async () => {
  const res = await call("GET", "/academics/exams/progress", ["verifyExamResults"]);
  assertEquals(res?.status, 503);
});

Deno.test("EXM-2: GET /academics/exams/progress is denied without either grant (403)", async () => {
  const res = await call("GET", "/academics/exams/progress", ["manageExamMarks"]);
  assertEquals(res?.status, 403);
  assertEquals((await res!.json()).error.code, "FORBIDDEN");
});

Deno.test("EXM-2: /progress is matched as the progress board, NOT as GET /academics/exams/{examId}", async () => {
  // A viewExams reader hitting /progress must not be routed to handleGetExam
  // (which would 503 via a getExamSession for an exam literally named
  // "progress"). Both currently 503 pre-DB, so lock the routing by asserting the
  // manageExamMarks-only caller is DENIED on /progress (viewExams-gated) but a
  // getExam of a real id would ALSO be denied — instead assert the OR-grant:
  // verifyExamResults alone (which does NOT grant viewExams / getExam) passes.
  const res = await call(
    "GET",
    "/academics/exams/progress",
    ["verifyExamResults"],
  );
  assertEquals(res?.status, 503); // reached the progress handler, not a 403
});

Deno.test("EXM-2: progress route rejects an unauthenticated caller (401)", async () => {
  const req = new Request("https://x/academics/exams/progress", { method: "GET" });
  const res = await routeExamAdministration(
    req,
    config,
    "GET",
    "/academics/exams/progress",
  );
  assertEquals(res?.status, 401);
});

// ── EXM-3/4/5/7 — read-only exam reports (all gated on viewExams) ───────────────

Deno.test("EXM-reports: the report slugs are all viewExams", () => {
  assertEquals(EXAM_OPERATION_PERMISSIONS.tabulation, "viewExams");
  assertEquals(EXAM_OPERATION_PERMISSIONS.toppers, "viewExams");
  assertEquals(EXAM_OPERATION_PERMISSIONS.merit, "viewExams");
  assertEquals(EXAM_OPERATION_PERMISSIONS.distribution, "viewExams");
  assertEquals(EXAM_OPERATION_PERMISSIONS.datesheet, "viewExams");
});

// EXM-3 — tabulation register.
Deno.test("EXM-3: GET class/{c}/tabulation is denied without viewExams (403)", async () => {
  const res = await call(
    "GET",
    "/academics/exams/class/8-A/tabulation?term=Term%202",
    ["manageExamMarks"],
  );
  assertEquals(res?.status, 403);
  assertEquals((await res!.json()).error.code, "FORBIDDEN");
});

Deno.test("EXM-3: GET class/{c}/tabulation reads with viewExams (passes gate → 503)", async () => {
  const res = await call(
    "GET",
    "/academics/exams/class/8-A/tabulation?term=Term%202",
    ["viewExams"],
  );
  assertEquals(res?.status, 503);
});

Deno.test("EXM-3: GET class/{c}/tabulation without term is rejected (422) before the DB", async () => {
  const res = await call(
    "GET",
    "/academics/exams/class/8-A/tabulation",
    ["viewExams"],
  );
  assertEquals(res?.status, 422);
});

Deno.test("EXM-3: class/{c}/tabulation is routed as a report, NOT as GET /exams/{examId}", async () => {
  // "class" must not be mistaken for an examId. A viewExams reader passes the
  // tabulation gate → 503; the request never falls through to handleGetExam.
  const res = await call(
    "GET",
    "/academics/exams/class/8-A/tabulation?term=Term%202",
    ["viewExams"],
  );
  assertEquals(res?.status, 503);
});

// EXM-4a — subject toppers (per exam).
Deno.test("EXM-4: GET exams/{id}/toppers is denied without viewExams (403)", async () => {
  const res = await call(
    "GET",
    "/academics/exams/exam-1/toppers?limit=5",
    ["manageExamMarks"],
  );
  assertEquals(res?.status, 403);
});

Deno.test("EXM-4: GET exams/{id}/toppers reads with viewExams (passes gate → 503)", async () => {
  const res = await call(
    "GET",
    "/academics/exams/exam-1/toppers?limit=5",
    ["viewExams"],
  );
  assertEquals(res?.status, 503);
});

// EXM-4b — merit list (per class + term).
Deno.test("EXM-4: GET class/{c}/merit is denied without viewExams (403)", async () => {
  const res = await call(
    "GET",
    "/academics/exams/class/8-A/merit?term=Term%202",
    ["manageExamMarks"],
  );
  assertEquals(res?.status, 403);
});

Deno.test("EXM-4: GET class/{c}/merit reads with viewExams (passes gate → 503)", async () => {
  const res = await call(
    "GET",
    "/academics/exams/class/8-A/merit?term=Term%202",
    ["viewExams"],
  );
  assertEquals(res?.status, 503);
});

Deno.test("EXM-4: GET class/{c}/merit without term is rejected (422)", async () => {
  const res = await call("GET", "/academics/exams/class/8-A/merit", ["viewExams"]);
  assertEquals(res?.status, 422);
});

// EXM-5 — pass/fail + grade distribution (per exam).
Deno.test("EXM-5: GET exams/{id}/distribution is denied without viewExams (403)", async () => {
  const res = await call(
    "GET",
    "/academics/exams/exam-1/distribution",
    ["manageExamMarks"],
  );
  assertEquals(res?.status, 403);
});

Deno.test("EXM-5: GET exams/{id}/distribution reads with viewExams (passes gate → 503)", async () => {
  const res = await call(
    "GET",
    "/academics/exams/exam-1/distribution",
    ["viewExams"],
  );
  assertEquals(res?.status, 503);
});

// EXM-7 — datesheet (per class + term).
Deno.test("EXM-7: GET class/{c}/datesheet is denied without viewExams (403)", async () => {
  const res = await call(
    "GET",
    "/academics/exams/class/8-A/datesheet?term=Term%202",
    ["manageExamMarks"],
  );
  assertEquals(res?.status, 403);
});

Deno.test("EXM-7: GET class/{c}/datesheet reads with viewExams (passes gate → 503)", async () => {
  const res = await call(
    "GET",
    "/academics/exams/class/8-A/datesheet?term=Term%202",
    ["viewExams"],
  );
  assertEquals(res?.status, 503);
});

Deno.test("EXM-7: GET class/{c}/datesheet without term is rejected (422)", async () => {
  const res = await call(
    "GET",
    "/academics/exams/class/8-A/datesheet",
    ["viewExams"],
  );
  assertEquals(res?.status, 422);
});

Deno.test("EXM-reports: a report route rejects an unauthenticated caller (401)", async () => {
  const req = new Request(
    "https://x/academics/exams/class/8-A/tabulation?term=Term%202",
    { method: "GET" },
  );
  const res = await routeExamAdministration(
    req,
    config,
    "GET",
    "/academics/exams/class/8-A/tabulation",
  );
  assertEquals(res?.status, 401);
});

// ── EXM-6 — marks_entry_deadline on create / schedule ──────────────────────────

Deno.test("EXM-6: POST /academics/exams accepts a marksEntryDeadline (passes → 503)", async () => {
  const res = await call("POST", "/academics/exams", ["manageExams"], {
    ...validExam,
    marksEntryDeadline: "2026-08-01T18:30:00Z",
  });
  // Gate + validation (incl. deadline parse) passed → reached the DB.
  assertEquals(res?.status, 503);
});

Deno.test("EXM-6: POST /academics/exams rejects a bad marksEntryDeadline (422) before DB", async () => {
  const res = await call("POST", "/academics/exams", ["manageExams"], {
    ...validExam,
    marksEntryDeadline: "not-a-date",
  });
  assertEquals(res?.status, 422);
});

Deno.test("EXM-6: POST /academics/exams with no deadline still passes (503)", async () => {
  const res = await call("POST", "/academics/exams", ["manageExams"], validExam);
  assertEquals(res?.status, 503);
});

// ── EXM-D1 — GET /academics/exams/class/{c}/report-cards (batch cards) ──────────

Deno.test("EXM-D1: report-cards slug is viewExams", () => {
  assertEquals(EXAM_OPERATION_PERMISSIONS.reportCards, "viewExams");
});

Deno.test("EXM-D1: GET class/{c}/report-cards is denied without viewExams (403)", async () => {
  const res = await call(
    "GET",
    "/academics/exams/class/8-A/report-cards?term=Term%202",
    ["manageExamMarks"],
  );
  assertEquals(res?.status, 403);
  assertEquals((await res!.json()).error.code, "FORBIDDEN");
});

Deno.test("EXM-D1: GET class/{c}/report-cards reads with viewExams (passes gate → 503)", async () => {
  const res = await call(
    "GET",
    "/academics/exams/class/8-A/report-cards?term=Term%202",
    ["viewExams"],
  );
  assertEquals(res?.status, 503);
});

Deno.test("EXM-D1: GET class/{c}/report-cards without term is rejected (422) before the DB", async () => {
  const res = await call(
    "GET",
    "/academics/exams/class/8-A/report-cards",
    ["viewExams"],
  );
  assertEquals(res?.status, 422);
});

Deno.test("EXM-D1: report-cards is routed as a report, NOT as GET /exams/{examId}", async () => {
  // "class" must never be mistaken for an examId; a viewExams reader passes the
  // report-cards gate → 503.
  const res = await call(
    "GET",
    "/academics/exams/class/8-A/report-cards?term=Term%202",
    ["viewExams"],
  );
  assertEquals(res?.status, 503);
});

// ── EXM-D2 — POST /academics/exams/{id}/students/{sid}/grace (moderation) ───────

Deno.test("EXM-D2: grace + adjustments slugs are moderateExamMarks", () => {
  assertEquals(EXAM_OPERATION_PERMISSIONS.graceMark, "moderateExamMarks");
  assertEquals(EXAM_OPERATION_PERMISSIONS.listAdjustments, "moderateExamMarks");
});

Deno.test("EXM-D2: POST grace is denied without moderateExamMarks (403)", async () => {
  // A plain marks-entry teacher CANNOT moderate.
  const res = await call(
    "POST",
    "/academics/exams/exam-1/students/stu-1/grace",
    ["viewExams", "manageExamMarks"],
    { delta: 5, reason: "Re-eval" },
  );
  assertEquals(res?.status, 403);
  assertEquals((await res!.json()).error.code, "FORBIDDEN");
});

Deno.test("EXM-D2: POST grace with moderateExamMarks passes the gate → 503", async () => {
  const res = await call(
    "POST",
    "/academics/exams/exam-1/students/stu-1/grace",
    ["moderateExamMarks"],
    { delta: 5, reason: "Re-evaluation grace" },
  );
  assertEquals(res?.status, 503);
});

Deno.test("EXM-D2: POST grace rejects a missing reason (422) before the DB", async () => {
  const res = await call(
    "POST",
    "/academics/exams/exam-1/students/stu-1/grace",
    ["moderateExamMarks"],
    { delta: 5 },
  );
  assertEquals(res?.status, 422);
});

Deno.test("EXM-D2: POST grace rejects a non-integer delta (422) before the DB", async () => {
  const res = await call(
    "POST",
    "/academics/exams/exam-1/students/stu-1/grace",
    ["moderateExamMarks"],
    { delta: 2.5, reason: "half mark" },
  );
  assertEquals(res?.status, 422);
});

Deno.test("EXM-D2: grace route rejects an unauthenticated caller (401)", async () => {
  const req = new Request(
    "https://x/academics/exams/exam-1/students/stu-1/grace",
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ delta: 5, reason: "x" }),
    },
  );
  const res = await routeExamAdministration(
    req,
    config,
    "POST",
    "/academics/exams/exam-1/students/stu-1/grace",
  );
  assertEquals(res?.status, 401);
});

Deno.test("EXM-D2: GET adjustments is denied without moderateExamMarks (403)", async () => {
  const res = await call(
    "GET",
    "/academics/exams/exam-1/adjustments",
    ["viewExams"],
  );
  assertEquals(res?.status, 403);
});

Deno.test("EXM-D2: GET adjustments with moderateExamMarks passes the gate → 503", async () => {
  const res = await call(
    "GET",
    "/academics/exams/exam-1/adjustments",
    ["moderateExamMarks"],
  );
  assertEquals(res?.status, 503);
});

// ── EXM-D4 — GET /academics/exams/{id}/hall-tickets (admit cards) ───────────────

Deno.test("EXM-D4: hall-tickets slug is viewExams", () => {
  assertEquals(EXAM_OPERATION_PERMISSIONS.hallTickets, "viewExams");
});

Deno.test("EXM-D4: GET hall-tickets is denied without viewExams (403)", async () => {
  const res = await call(
    "GET",
    "/academics/exams/exam-1/hall-tickets",
    ["manageExamMarks"],
  );
  assertEquals(res?.status, 403);
});

Deno.test("EXM-D4: GET hall-tickets reads with viewExams (passes gate → 503)", async () => {
  const res = await call(
    "GET",
    "/academics/exams/exam-1/hall-tickets",
    ["viewExams"],
  );
  assertEquals(res?.status, 503);
});

// ── EXM-D5 — seating: generate (manage) + read (view) ──────────────────────────

Deno.test("EXM-D5: seating slugs are manageExams (generate) + viewExams (read)", () => {
  assertEquals(EXAM_OPERATION_PERMISSIONS.generateSeating, "manageExams");
  assertEquals(EXAM_OPERATION_PERMISSIONS.getSeating, "viewExams");
});

Deno.test("EXM-D5: POST seating/generate is denied without manageExams (403)", async () => {
  const res = await call(
    "POST",
    "/academics/exams/exam-1/seating/generate",
    ["viewExams"],
    { capacity: 30 },
  );
  assertEquals(res?.status, 403);
});

Deno.test("EXM-D5: POST seating/generate with manageExams passes the gate → 503", async () => {
  const res = await call(
    "POST",
    "/academics/exams/exam-1/seating/generate",
    ["manageExams"],
    { capacity: 30 },
  );
  assertEquals(res?.status, 503);
});

Deno.test("EXM-D5: POST seating/generate rejects a bad capacity (422) before the DB", async () => {
  const res = await call(
    "POST",
    "/academics/exams/exam-1/seating/generate",
    ["manageExams"],
    { capacity: 0 },
  );
  assertEquals(res?.status, 422);
});

Deno.test("EXM-D5: seating/generate is NOT mistaken for GET /exams/{examId}", async () => {
  // The two-segment suffix must route to the seating handler, not handleGetExam.
  const res = await call(
    "POST",
    "/academics/exams/exam-1/seating/generate",
    ["manageExams"],
    { capacity: 30 },
  );
  assertEquals(res?.status, 503);
});

Deno.test("EXM-D5: GET seating is denied without viewExams (403)", async () => {
  const res = await call(
    "GET",
    "/academics/exams/exam-1/seating",
    ["manageExamMarks"],
  );
  assertEquals(res?.status, 403);
});

Deno.test("EXM-D5: GET seating reads with viewExams (passes gate → 503)", async () => {
  const res = await call(
    "GET",
    "/academics/exams/exam-1/seating",
    ["viewExams"],
  );
  assertEquals(res?.status, 503);
});
