// PRA-P1-13 — the school's grading scale must PERSIST and be AUTHORITATIVE at
// publish + report time. Previously the backend derived every letter grade from
// a compile-time constant (A+/A/B+/B/C/D/F, pass fixed at 40%), so a CBSE school
// that picked an A1–E scale still had A+/A/B printed and a silently-fixed pass
// boundary. These tests prove:
//   • gradeForPercent honours a custom scale AND reproduces the legacy scale by
//     default;
//   • loadGradeScale returns the school row when present, else the legacy default;
//   • the publish + report/distribution paths use the RESOLVED scale;
//   • an unconfigured school (no row) has ZERO behaviour change;
//   • the PUT payload validation rejects malformed scales.

import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  DEFAULT_GRADE_BANDS,
  DEFAULT_PASS_MARK_PERCENT,
  type GradeBand,
  gradeForPercent,
  loadExamDistribution,
  loadGradeScale,
  loadReportCards,
  parseGradeScaleInput,
  publishExamResults,
} from "./exam_administration_repository.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";
import type { AppConfig } from "../../config.ts";
import type { AccessTokenClaims } from "../../jwt.ts";
import { signAccessToken } from "../../jwt.ts";
import {
  matchExamAdministrationRoute,
  routeExamAdministration,
} from "./exam_administration_router.ts";
import {
  EXAM_OPERATION_PERMISSIONS,
  handleGetGradeScale,
  handlePutGradeScale,
} from "./exam_administration_handlers.ts";

// A CBSE-style scale (A1–E) that differs from the legacy default at EVERY bucket.
const CBSE_BANDS: GradeBand[] = [
  { minPercent: 91, letter: "A1" },
  { minPercent: 81, letter: "A2" },
  { minPercent: 71, letter: "B1" },
  { minPercent: 61, letter: "B2" },
  { minPercent: 33, letter: "D" },
  { minPercent: 0, letter: "E" },
];

// A stored grade-scale row as it comes back from exam_grade_scales.
function gradeScaleRow(bands: GradeBand[], passMark: number) {
  return {
    scale_code: "cbse_a1_e",
    bands: bands.map((b) => ({ minPercent: b.minPercent, letter: b.letter })),
    pass_mark_percent: passMark,
  };
}

// ── gradeForPercent ────────────────────────────────────────────────────────

Deno.test("gradeForPercent reproduces the legacy scale by default", () => {
  assertEquals(gradeForPercent(95), "A+");
  assertEquals(gradeForPercent(85), "A");
  assertEquals(gradeForPercent(75), "B+");
  assertEquals(gradeForPercent(65), "B");
  assertEquals(gradeForPercent(55), "C");
  assertEquals(gradeForPercent(45), "D");
  assertEquals(gradeForPercent(30), "F");
  // Explicitly passing the default bands is identical.
  assertEquals(gradeForPercent(95, DEFAULT_GRADE_BANDS), "A+");
});

Deno.test("gradeForPercent honours a custom scale", () => {
  assertEquals(gradeForPercent(95, CBSE_BANDS), "A1");
  assertEquals(gradeForPercent(85, CBSE_BANDS), "A2");
  assertEquals(gradeForPercent(40, CBSE_BANDS), "D");
  assertEquals(gradeForPercent(20, CBSE_BANDS), "E");
});

// ── loadGradeScale (row present vs fallback) ───────────────────────────────

function scaleDb(row: unknown | null): TenantQueryClient {
  return {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, _args: unknown[] = []): Promise<any[]> {
      if (sql.includes("FROM exam_grade_scales")) {
        return Promise.resolve(row == null ? [] : [row]);
      }
      return Promise.resolve([]);
    },
  } as unknown as TenantQueryClient;
}

Deno.test("loadGradeScale returns the school row when present", async () => {
  const scale = await loadGradeScale(
    scaleDb(gradeScaleRow(CBSE_BANDS, 33)),
    "org",
    "school",
  );
  assertEquals(scale.source, "school");
  assertEquals(scale.passMarkPercent, 33);
  assertEquals(scale.bands[0], { minPercent: 91, letter: "A1" });
  // Bands are re-sorted descending regardless of stored order.
  assert(scale.bands[0]!.minPercent > scale.bands[1]!.minPercent);
});

Deno.test("loadGradeScale falls back to the legacy default when NO row exists", async () => {
  const scale = await loadGradeScale(scaleDb(null), "org", "school");
  assertEquals(scale.source, "default");
  assertEquals(scale.passMarkPercent, DEFAULT_PASS_MARK_PERCENT);
  assertEquals(scale.bands, DEFAULT_GRADE_BANDS);
});

Deno.test("loadGradeScale falls back when stored bands are unusable (empty array)", async () => {
  const scale = await loadGradeScale(
    scaleDb({ scale_code: "x", bands: [], pass_mark_percent: 50 }),
    "org",
    "school",
  );
  assertEquals(scale.source, "default");
});

// ── report card path honours the resolved scale ────────────────────────────

function reportCardDb(gradeRow: unknown | null): TenantQueryClient {
  const rows = [{
    student_id: "s1",
    student_code: "S1",
    student_name: "Meera",
    roll_number: "01",
    subject: "Mathematics",
    exam_title: "Term 2",
    marks_obtained: 95,
    effective_marks: null,
    max_marks: 100,
    status: "present",
    grade_letter: null, // not baked → derived on read using the resolved scale
    exam_updated_at: "2026-06-28T00:00:00Z",
  }];
  return {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, _args: unknown[] = []): Promise<any[]> {
      if (sql.includes("FROM exam_grade_scales")) {
        return Promise.resolve(gradeRow == null ? [] : [gradeRow]);
      }
      if (
        sql.includes("es.subject AS subject") &&
        sql.includes("es.updated_at AS exam_updated_at")
      ) {
        return Promise.resolve(rows);
      }
      return Promise.resolve([]);
    },
  } as unknown as TenantQueryClient;
}

Deno.test("loadReportCards derives the letter grade from the SCHOOL scale", async () => {
  const cards = await loadReportCards(
    reportCardDb(gradeScaleRow(CBSE_BANDS, 33)),
    "org",
    "school",
    "8-A",
    "Term 2",
  );
  assertEquals(cards.length, 1);
  // 95% → A1 under CBSE, NOT the legacy A+.
  assertEquals(cards[0].subjects[0].grade, "A1");
  assertEquals(cards[0].overallGrade, "A1");
});

Deno.test("loadReportCards keeps legacy grades when the school has NO scale (zero behaviour change)", async () => {
  const cards = await loadReportCards(
    reportCardDb(null),
    "org",
    "school",
    "8-A",
    "Term 2",
  );
  // 95% → A+ (legacy), unchanged.
  assertEquals(cards[0].subjects[0].grade, "A+");
  assertEquals(cards[0].overallGrade, "A+");
});

// ── distribution path honours the resolved pass mark + scale ───────────────

function distributionDb(gradeRow: unknown | null): TenantQueryClient {
  // One present student at 35/100: passes under a 33% school pass mark, but FAILS
  // under the legacy 40% default.
  const rows = [{
    marks_obtained: 35,
    max_marks: 100,
    status: "present",
    grade_letter: null,
  }];
  return {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, _args: unknown[] = []): Promise<any[]> {
      if (sql.includes("SELECT * FROM exam_sessions")) {
        return Promise.resolve([{ id: "exam-1", max_marks: 100, phase: "published" }]);
      }
      if (sql.includes("FROM exam_grade_scales")) {
        return Promise.resolve(gradeRow == null ? [] : [gradeRow]);
      }
      if (sql.includes("COALESCE(m.effective_marks, m.marks_obtained)")) {
        return Promise.resolve(rows);
      }
      return Promise.resolve([]);
    },
  } as unknown as TenantQueryClient;
}

Deno.test("loadExamDistribution uses the SCHOOL pass mark + scale", async () => {
  const dist = await loadExamDistribution(
    distributionDb(gradeScaleRow(CBSE_BANDS, 33)),
    "org",
    "school",
    "exam-1",
  );
  assertEquals(dist.passMarkPercent, 33);
  assertEquals(dist.passMarkSource, "school");
  // 35% passes under 33; grade bucket uses the custom "D" (>=33), not legacy "F".
  assertEquals(dist.passCount, 1);
  assertEquals(dist.failCount, 0);
  assertEquals(dist.gradeBreakdown[0].grade, "D");
});

Deno.test("loadExamDistribution keeps the legacy 40% + default scale with NO row", async () => {
  const dist = await loadExamDistribution(distributionDb(null), "org", "school", "exam-1");
  assertEquals(dist.passMarkPercent, DEFAULT_PASS_MARK_PERCENT);
  assertEquals(dist.passMarkSource, "default");
  // 35% fails under the legacy 40; grade bucket is the legacy "F".
  assertEquals(dist.passCount, 0);
  assertEquals(dist.failCount, 1);
  assertEquals(dist.gradeBreakdown[0].grade, "F");
});

// ── publish bakes the grade_letter from the resolved scale ─────────────────

function publishDb(gradeRow: unknown | null): {
  db: TenantQueryClient;
  baked: string[];
} {
  const baked: string[] = [];
  const db = {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, args: unknown[] = []): Promise<any[]> {
      if (sql.includes("SELECT * FROM exam_sessions")) {
        // processed (not published) so publish proceeds to bake grades.
        return Promise.resolve([{ id: "exam-1", max_marks: 100, phase: "processed" }]);
      }
      if (sql.includes("SELECT * FROM exam_mark_entries")) {
        return Promise.resolve([{
          id: "m1",
          student_id: "s1",
          status: "present",
          marks_obtained: 95,
          max_marks: 100,
          marks_entered: true,
        }]);
      }
      if (sql.includes("FROM exam_grade_scales")) {
        return Promise.resolve(gradeRow == null ? [] : [gradeRow]);
      }
      if (sql.includes("SUM(delta)")) {
        return Promise.resolve([{ total: "0" }]);
      }
      if (sql.includes("UPDATE exam_mark_entries") && sql.includes("grade_letter = $4")) {
        baked.push(String(args[3])); // $4 = grade_letter
        return Promise.resolve([]);
      }
      if (sql.includes("UPDATE exam_sessions SET phase")) {
        return Promise.resolve([{ id: "exam-1", phase: "published" }]);
      }
      return Promise.resolve([]);
    },
  } as unknown as TenantQueryClient;
  return { db, baked };
}

Deno.test("publishExamResults bakes the grade_letter from the SCHOOL scale", async () => {
  const { db, baked } = publishDb(gradeScaleRow(CBSE_BANDS, 33));
  const count = await publishExamResults(db, "org", "school", "exam-1");
  assertEquals(count, 1);
  assertEquals(baked, ["A1"]); // 95% → A1 under CBSE, NOT legacy A+.
});

Deno.test("publishExamResults bakes the legacy grade with NO school scale (zero behaviour change)", async () => {
  const { db, baked } = publishDb(null);
  const count = await publishExamResults(db, "org", "school", "exam-1");
  assertEquals(count, 1);
  assertEquals(baked, ["A+"]); // 95% → A+ (legacy), unchanged.
});

// ── PUT payload validation ─────────────────────────────────────────────────

Deno.test("parseGradeScaleInput accepts a valid descending scale", () => {
  const input = parseGradeScaleInput({
    scaleCode: "cbse_a1_e",
    passMarkPercent: 33,
    bands: CBSE_BANDS,
  });
  assertEquals(input.scaleCode, "cbse_a1_e");
  assertEquals(input.passMarkPercent, 33);
  assertEquals(input.bands.length, CBSE_BANDS.length);
});

Deno.test("parseGradeScaleInput defaults scaleCode + pass mark when omitted", () => {
  const input = parseGradeScaleInput({
    bands: [{ minPercent: 50, letter: "P" }, { minPercent: 0, letter: "F" }],
  });
  assertEquals(input.scaleCode, "custom");
  assertEquals(input.passMarkPercent, DEFAULT_PASS_MARK_PERCENT);
});

Deno.test("parseGradeScaleInput rejects an empty band list", () => {
  assertThrows(() => parseGradeScaleInput({ bands: [] }));
  assertThrows(() => parseGradeScaleInput({}));
});

Deno.test("parseGradeScaleInput rejects a non-empty letter requirement", () => {
  assertThrows(() =>
    parseGradeScaleInput({
      bands: [{ minPercent: 50, letter: "" }, { minPercent: 0, letter: "F" }],
    })
  );
});

Deno.test("parseGradeScaleInput rejects non-descending / duplicate minPercent", () => {
  assertThrows(() =>
    parseGradeScaleInput({
      bands: [{ minPercent: 50, letter: "A" }, { minPercent: 60, letter: "B" }],
    })
  );
  assertThrows(() =>
    parseGradeScaleInput({
      bands: [{ minPercent: 50, letter: "A" }, { minPercent: 50, letter: "B" }],
    })
  );
});

Deno.test("parseGradeScaleInput rejects an out-of-range pass mark or minPercent", () => {
  assertThrows(() =>
    parseGradeScaleInput({
      passMarkPercent: 150,
      bands: [{ minPercent: 0, letter: "F" }],
    })
  );
  assertThrows(() =>
    parseGradeScaleInput({
      bands: [{ minPercent: 120, letter: "A" }, { minPercent: 0, letter: "F" }],
    })
  );
});

// ── route + permission contract (DB-free, up to the tenant-DB boundary) ─────
//
// Mirrors the QW4 route-contract harness: an unconfigured tenant DB → 503 is the
// DB-free proxy for "passed the gate + validation and reached persistence".

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const routeConfig = { jwtSecret: SECRET } as AppConfig;

function routeClaims(perms: string[]): AccessTokenClaims {
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
  };
}

async function callRoute(
  method: string,
  path: string,
  perms: string[],
  body?: unknown,
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, routeClaims(perms), 900);
  const req = new Request(`https://x${path}`, {
    method,
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  return routeExamAdministration(req, routeConfig, method, path);
}

const VALID_SCALE_BODY = {
  scaleCode: "cbse_a1_e",
  passMarkPercent: 33,
  bands: CBSE_BANDS,
};

Deno.test("grade-scale slugs are getGradeScale=viewExams, putGradeScale=manageExams", () => {
  assertEquals(EXAM_OPERATION_PERMISSIONS.getGradeScale, "viewExams");
  assertEquals(EXAM_OPERATION_PERMISSIONS.putGradeScale, "manageExams");
});

Deno.test("grade-scale GET/PUT route to the grade-scale handlers, NOT GET /exams/{examId}", () => {
  const get = matchExamAdministrationRoute("GET", "/academics/exams/grade-scale");
  assertEquals(get?.handler, handleGetGradeScale);
  const put = matchExamAdministrationRoute("PUT", "/academics/exams/grade-scale");
  assertEquals(put?.handler, handlePutGradeScale);
});

Deno.test("GET grade-scale is denied without viewExams (403)", async () => {
  const res = await callRoute("GET", "/academics/exams/grade-scale", ["manageExamMarks"]);
  assertEquals(res?.status, 403);
});

Deno.test("GET grade-scale reads with viewExams (passes gate → 503)", async () => {
  const res = await callRoute("GET", "/academics/exams/grade-scale", ["viewExams"]);
  assertEquals(res?.status, 503);
});

Deno.test("PUT grade-scale is denied without manageExams (403)", async () => {
  const res = await callRoute(
    "PUT",
    "/academics/exams/grade-scale",
    ["viewExams"],
    VALID_SCALE_BODY,
  );
  assertEquals(res?.status, 403);
});

Deno.test("PUT grade-scale with manageExams + valid body passes gate + validation → 503", async () => {
  const res = await callRoute(
    "PUT",
    "/academics/exams/grade-scale",
    ["manageExams"],
    VALID_SCALE_BODY,
  );
  assertEquals(res?.status, 503);
});

Deno.test("PUT grade-scale rejects a malformed scale (422) BEFORE the DB", async () => {
  const res = await callRoute(
    "PUT",
    "/academics/exams/grade-scale",
    ["manageExams"],
    { bands: [{ minPercent: 50, letter: "A" }, { minPercent: 60, letter: "B" }] },
  );
  assertEquals(res?.status, 422);
});

Deno.test("grade-scale route rejects an unauthenticated caller (401)", async () => {
  const req = new Request("https://x/academics/exams/grade-scale", { method: "GET" });
  const res = await routeExamAdministration(
    req,
    routeConfig,
    "GET",
    "/academics/exams/grade-scale",
  );
  assertEquals(res?.status, 401);
});
