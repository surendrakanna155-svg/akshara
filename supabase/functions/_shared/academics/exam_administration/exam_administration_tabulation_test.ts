// ICA-H1 — the term tabulation register + report card must AGGREGATE the distinct
// assessments a subject has in ONE term (e.g. unit_test + terminal, FA + SA) rather
// than silently collapsing them to the latest-updated exam. The assessment SLOT is
// `exam_type`: two sessions of the SAME slot (a supplementary / re-exam of one
// assessment) still REPLACE each other (PRA-P1-12, no double-count), but DISTINCT
// exam_types each contribute to the student's total / percent / rank. Non-present
// (AB/ML/DB) slots are excluded from every statistic (frozen exclusion rule).
//
// These drive the pure computation over a fake DB, so no live tenant Postgres.

import { assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import {
  loadReportCards,
  loadTabulationRegister,
} from "./exam_administration_repository.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";

interface Mark {
  student_id: string;
  student_code: string;
  student_name: string;
  roll_number: string;
  subject: string;
  exam_type: string;
  exam_title: string;
  marks_obtained: number | null;
  max_marks: number;
  status: string;
  exam_updated_at: string;
}

function m(
  student_id: string,
  student_code: string,
  student_name: string,
  roll_number: string,
  subject: string,
  exam_type: string,
  exam_title: string,
  marks_obtained: number | null,
  max_marks: number,
  status: string,
  updated: string,
): Mark {
  return {
    student_id,
    student_code,
    student_name,
    roll_number,
    subject,
    exam_type,
    exam_title,
    marks_obtained,
    max_marks,
    status,
    exam_updated_at: updated,
  };
}

// Class 8-A, Term 1. Mathematics has TWO distinct assessments in the term
// (unit_test + half_yearly); Science has one (annual). Rows are in updated_at ASC
// order (as the SQL ORDER BY es.updated_at ASC delivers them). half_yearly is NEWER
// than unit_test, so the pre-fix "newest per subject wins" would have kept ONLY the
// half_yearly Maths mark and dropped the unit_test — deflating totals + rank.
const MARKS: Mark[] = [
  // Asha — Maths 30/50 + 60/100, Science 80/100.
  m("s1", "S1", "Asha", "01", "Mathematics", "unit_test", "Unit Test 1", 30, 50, "present", "2026-06-01"),
  m("s1", "S1", "Asha", "01", "Science", "annual", "Annual", 80, 100, "present", "2026-06-10"),
  m("s1", "S1", "Asha", "01", "Mathematics", "half_yearly", "Half Yearly", 60, 100, "present", "2026-06-15"),
  // Bina — Maths 45/50 + 50/100, Science 70/100.
  m("s2", "S2", "Bina", "02", "Mathematics", "unit_test", "Unit Test 1", 45, 50, "present", "2026-06-01"),
  m("s2", "S2", "Bina", "02", "Science", "annual", "Annual", 70, 100, "present", "2026-06-10"),
  m("s2", "S2", "Bina", "02", "Mathematics", "half_yearly", "Half Yearly", 50, 100, "present", "2026-06-15"),
  // Chetan — half_yearly Maths ABSENT: it must NOT count, but unit_test 40/50 does.
  m("s3", "S3", "Chetan", "03", "Mathematics", "unit_test", "Unit Test 1", 40, 50, "present", "2026-06-01"),
  m("s3", "S3", "Chetan", "03", "Science", "annual", "Annual", 90, 100, "present", "2026-06-10"),
  m("s3", "S3", "Chetan", "03", "Mathematics", "half_yearly", "Half Yearly", null, 100, "absent", "2026-06-15"),
  // Dev — a supplementary of the SAME slot (half_yearly): 80 REPLACES 30 (P1-12).
  m("s4", "S4", "Dev", "04", "Mathematics", "half_yearly", "Half Yearly", 30, 100, "present", "2026-06-15"),
  m("s4", "S4", "Dev", "04", "Mathematics", "half_yearly", "Half Yearly (Supplementary)", 80, 100, "present", "2026-06-20"),
];

function db(marks: Mark[]): TenantQueryClient {
  return {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, _args: unknown[] = []): Promise<any[]> {
      // Per-school grade scale — return none so the default scale is used.
      if (sql.includes("FROM exam_grade_scales")) return Promise.resolve([]);
      const isReportCard = sql.includes("es.title AS exam_title");
      const isTabulation = sql.includes("es.subject AS subject") &&
        sql.includes("es.updated_at AS exam_updated_at") && !isReportCard;
      if (isReportCard) {
        return Promise.resolve(marks.map((r) => ({
          student_id: r.student_id,
          student_code: r.student_code,
          student_name: r.student_name,
          subject: r.subject,
          exam_type: r.exam_type,
          exam_title: r.exam_title,
          marks_obtained: r.marks_obtained,
          effective_marks: null,
          max_marks: r.max_marks,
          status: r.status,
          grade_letter: null,
          exam_updated_at: r.exam_updated_at,
        })));
      }
      if (isTabulation) {
        return Promise.resolve(marks.map((r) => ({
          student_id: r.student_id,
          student_code: r.student_code,
          student_name: r.student_name,
          roll_number: r.roll_number,
          subject: r.subject,
          exam_type: r.exam_type,
          marks_obtained: r.marks_obtained,
          max_marks: r.max_marks,
          status: r.status,
          exam_updated_at: r.exam_updated_at,
        })));
      }
      return Promise.resolve([]);
    },
  } as unknown as TenantQueryClient;
}

Deno.test("ICA-H1 tabulation AGGREGATES distinct same-subject exams in a term (not last-wins)", async () => {
  const reg = await loadTabulationRegister(db(MARKS), "org", "school", "8-A", "Term 1");

  const asha = reg.students.find((s) => s.studentId === "s1")!;
  // Maths = unit_test 30/50 + half_yearly 60/100 → 90/150. Pre-fix it was 60/100.
  assertEquals(asha.perSubject["Mathematics"].marks, 90);
  assertEquals(asha.perSubject["Mathematics"].maxMarks, 150);
  assertEquals(asha.perSubject["Science"].marks, 80);
  assertEquals(asha.total, 170); // 90 + 80
  assertEquals(asha.totalMax, 250); // 150 + 100
  assertAlmostEquals(asha.percent, 68, 1e-9);

  const bina = reg.students.find((s) => s.studentId === "s2")!;
  assertEquals(bina.perSubject["Mathematics"].marks, 95); // 45 + 50
  assertEquals(bina.total, 165); // 95 + 70
  assertEquals(bina.totalMax, 250);
  assertAlmostEquals(bina.percent, 66, 1e-9);
});

Deno.test("ICA-H1 tabulation EXCLUDES a non-present assessment slot but keeps the present one", async () => {
  const reg = await loadTabulationRegister(db(MARKS), "org", "school", "8-A", "Term 1");

  const chetan = reg.students.find((s) => s.studentId === "s3")!;
  // half_yearly Maths is ABSENT → only the present unit_test (40/50) counts.
  assertEquals(chetan.perSubject["Mathematics"].marks, 40);
  assertEquals(chetan.perSubject["Mathematics"].maxMarks, 50); // absent max NOT added
  assertEquals(chetan.perSubject["Mathematics"].statusCode, null); // present overall
  assertEquals(chetan.total, 130); // 40 + 90
  assertEquals(chetan.totalMax, 150); // 50 + 100 — the absent 100 is excluded
  assertAlmostEquals(chetan.percent, (130 / 150) * 100, 1e-9);
});

Deno.test("PRA-P1-12 preserved: a supplementary re-exam of the SAME slot REPLACES (no double-count)", async () => {
  const reg = await loadTabulationRegister(db(MARKS), "org", "school", "8-A", "Term 1");

  const dev = reg.students.find((s) => s.studentId === "s4")!;
  // Two half_yearly sessions (30 then 80) collapse to the newest — NOT 110/200.
  assertEquals(dev.perSubject["Mathematics"].marks, 80);
  assertEquals(dev.perSubject["Mathematics"].maxMarks, 100);
  assertEquals(Object.keys(dev.perSubject).length, 1);
  assertEquals(dev.total, 80);
  assertEquals(dev.totalMax, 100);
});

Deno.test("ICA-H1 rank reflects the CORRECTED aggregated totals", async () => {
  const reg = await loadTabulationRegister(db(MARKS), "org", "school", "8-A", "Term 1");
  const rankOf = (id: string) => reg.students.find((s) => s.studentId === id)!.rank;
  // Chetan 86.67% > Dev 80% > Asha 68% > Bina 66%.
  assertEquals(rankOf("s3"), 1);
  assertEquals(rankOf("s4"), 2);
  assertEquals(rankOf("s1"), 3);
  assertEquals(rankOf("s2"), 4);
});

Deno.test("ICA-H1 report card keeps a line PER distinct assessment and totals them all", async () => {
  const cards = await loadReportCards(db(MARKS), "org", "school", "8-A", "Term 1");

  const asha = cards.find((c) => c.sisStudentId === "S1")!;
  // Two Maths lines (unit_test + half_yearly) + one Science line — all counted.
  const ashaMath = asha.subjects.filter((s) => s.subject === "Mathematics");
  assertEquals(ashaMath.length, 2);
  assertEquals(asha.subjects.length, 3);
  assertEquals(asha.totalScore, 170); // 30 + 60 + 80
  assertEquals(asha.totalMax, 250);

  // Supplementary Dev: the SAME slot still collapses to ONE line (80), not two.
  const dev = cards.find((c) => c.sisStudentId === "S4")!;
  const devMath = dev.subjects.filter((s) => s.subject === "Mathematics");
  assertEquals(devMath.length, 1);
  assertEquals(devMath[0]!.score, 80);
  assertEquals(dev.totalScore, 80);
  assertEquals(dev.totalMax, 100);
});
