// PRA-P1-12 (S6): a second published session for the SAME subject+term (a
// supplementary / re-exam) must REPLACE the first in totals — not be added on top
// of it. Before the fix, both the tabulation register and the report card
// accumulated every session row into the student total, so a subject with two
// sessions was double-counted, inflating total, percent, grade and rank.
//
// Rows arrive oldest→newest (ORDER BY es.updated_at ASC), so the fake returns the
// original first and the supplementary last; the newest cell must win.

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  loadReportCards,
  loadTabulationRegister,
  unpublishExamResults,
} from "./exam_administration_repository.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";

interface Row {
  student_id: string;
  student_code: string;
  student_name: string;
  roll_number: string;
  subject: string;
  exam_title: string;
  marks_obtained: number | null;
  effective_marks: number | null;
  max_marks: number;
  status: string;
  grade_letter: string | null;
}

// One student, Mathematics /100: original session 40 (fail), then a supplementary
// session 75 (pass). Oldest first, newest last.
const ROWS: Row[] = [
  {
    student_id: "s1",
    student_code: "S1",
    student_name: "Meera",
    roll_number: "01",
    subject: "Mathematics",
    exam_title: "Term 2",
    marks_obtained: 40,
    effective_marks: null,
    max_marks: 100,
    status: "present",
    grade_letter: null,
  },
  {
    student_id: "s1",
    student_code: "S1",
    student_name: "Meera",
    roll_number: "01",
    subject: "Mathematics",
    exam_title: "Term 2 (Supplementary)",
    marks_obtained: 75,
    effective_marks: null,
    max_marks: 100,
    status: "present",
    grade_letter: null,
  },
];

function db(rows: Row[]): TenantQueryClient {
  return {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, _args: unknown[] = []): Promise<any[]> {
      if (sql.includes("es.subject AS subject") && sql.includes("es.updated_at AS exam_updated_at")) {
        // Both tabulation and report-card SELECTs match; return the shared rows
        // shape (extra fields are ignored by whichever query reads them).
        return Promise.resolve(
          rows.map((r) => ({ ...r, exam_updated_at: "2026-06-28T00:00:00Z" })),
        );
      }
      return Promise.resolve([]);
    },
  } as unknown as TenantQueryClient;
}

Deno.test("P1-12 tabulation counts a two-session subject ONCE (newest wins, no double-count)", async () => {
  const reg = await loadTabulationRegister(db(ROWS), "org", "school", "8-A", "Term 2");
  assertEquals(reg.students.length, 1);
  const s = reg.students[0];
  // NOT 40+75=115. The supplementary (75) replaces the original (40).
  assertEquals(s.total, 75);
  assertEquals(s.totalMax, 100); // NOT 200 — the subject's max counts once
  assertEquals(Math.round(s.percent), 75);
  // Exactly one Mathematics column, showing the newest mark.
  assertEquals(Object.keys(s.perSubject).length, 1);
  assertEquals(s.perSubject["Mathematics"].marks, 75);
});

Deno.test("P1-12 report card lists the subject ONCE and totals it once", async () => {
  const cards = await loadReportCards(db(ROWS), "org", "school", "8-A", "Term 2");
  assertEquals(cards.length, 1);
  const c = cards[0];
  // One subject row, not two duplicated Mathematics rows.
  assertEquals(c.subjects.length, 1);
  assertEquals(c.subjects[0].subject, "Mathematics");
  assertEquals(c.subjects[0].score, 75);
  // Total counts the subject once (75/100), not 115/200.
  assertEquals(c.totalScore, 75);
  assertEquals(c.totalMax, 100);
  assert(Math.abs(c.overallPercent - 75) < 0.001);
});

// ── PRA-P1-12: unpublish reopens a published exam for correction ───────────────

function unpublishDb(phase: string): { db: TenantQueryClient; ops: string[] } {
  const ops: string[] = [];
  const db = {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, _args: unknown[] = []): Promise<any[]> {
      if (sql.includes("SELECT * FROM exam_sessions")) {
        return Promise.resolve([{ id: "exam-1", phase, max_marks: 100 }]);
      }
      if (sql.includes("UPDATE exam_mark_entries") && sql.includes("published = false")) {
        ops.push("reopen-marks");
        return Promise.resolve([{ id: "m1" }, { id: "m2" }, { id: "m3" }]);
      }
      if (sql.includes("UPDATE exam_sessions SET phase")) {
        ops.push("phase-processed");
        return Promise.resolve([{ id: "exam-1", phase: "processed" }]);
      }
      return Promise.resolve([]);
    },
  } as unknown as TenantQueryClient;
  return { db, ops };
}

Deno.test("P1-12 unpublish reopens a PUBLISHED exam → marks cleared, phase back to processed", async () => {
  const { db, ops } = unpublishDb("published");
  const reopened = await unpublishExamResults(db, "org", "school", "exam-1");
  assertEquals(reopened, 3);
  assert(ops.includes("reopen-marks"));
  assert(ops.includes("phase-processed"));
});

Deno.test("P1-12 unpublish REFUSES a not-yet-published exam (nothing to reopen)", async () => {
  const { db, ops } = unpublishDb("processed");
  await assertRejects(() => unpublishExamResults(db, "org", "school", "exam-1"));
  // No reopen / phase change happened.
  assertEquals(ops.length, 0);
});
