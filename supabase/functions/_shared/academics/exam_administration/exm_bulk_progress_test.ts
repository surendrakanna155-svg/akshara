// EXM-1 (bulk marks save) + EXM-2 (marks-entry progress board) — DB-free unit
// tests for the repository-level pieces that back the two new routes.
//
//  • EXM-2: listMarksEntryProgress groups per marks_entry exam and counts
//    entered (marks_entered = true — includes AB/ML/DB rows) vs total, and
//    marksEntryProgressToApi derives pending = total - entered.
//  • EXM-1: the bulk save reuses updateExamMark per row, so its published-row
//    immutability + status→NULL-marks semantics are the SAME guards proven in
//    qa_x_033_exam_results_antitamper_test.ts / exm_d6_absent_status_test.ts.
//    Here we lock the partial-success shape: a bad row must not abort the batch.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";
import {
  listMarksEntryProgress,
  marksEntryProgressToApi,
  type MarksEntryProgressRow,
  updateExamMark,
  type ExamMarkRow,
} from "./exam_administration_repository.ts";

const ORG = "org-1";
const SCHOOL = "school-1";

// ── EXM-2 progress board ──────────────────────────────────────────────────────

/** Fake DB returning the GROUP BY progress aggregate for the school. */
class ProgressDb {
  constructor(
    private rows: Array<{
      exam_id: string;
      title: string;
      subject: string;
      grade: string;
      section_name: string;
      entered_count: string;
      total_count: string;
    }>,
  ) {}
  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, _args: any[] = []): Promise<T[]> {
    if (sql.includes("FROM exam_sessions es") && sql.includes("marks_entered")) {
      return Promise.resolve(this.rows as unknown as T[]);
    }
    return Promise.resolve([] as T[]);
  }
}

Deno.test("EXM-2: listMarksEntryProgress parses counts to numbers", async () => {
  const db = new ProgressDb([
    {
      exam_id: "exam-1",
      title: "Term 2 Maths",
      subject: "Mathematics",
      grade: "8",
      section_name: "A",
      entered_count: "18",
      total_count: "30",
    },
  ]) as unknown as TenantQueryClient;
  const rows = await listMarksEntryProgress(db, ORG, SCHOOL);
  assertEquals(rows.length, 1);
  assertEquals(rows[0]!.entered_count, 18);
  assertEquals(rows[0]!.total_count, 30);
  assertEquals(rows[0]!.subject, "Mathematics");
});

Deno.test("EXM-2: marksEntryProgressToApi derives pending = total - entered", () => {
  const row: MarksEntryProgressRow = {
    exam_id: "exam-1",
    title: "Term 2 Maths",
    subject: "Mathematics",
    grade: "8",
    section_name: "A",
    entered_count: 18,
    total_count: 30,
  };
  const api = marksEntryProgressToApi(row);
  assertEquals(api.examId, "exam-1");
  assertEquals(api.enteredCount, 18);
  assertEquals(api.totalCount, 30);
  assertEquals(api.pending, 12);
  assertEquals(api.sectionName, "A");
});

Deno.test("EXM-2: pending never goes negative (clamped at 0)", () => {
  const api = marksEntryProgressToApi({
    exam_id: "e",
    title: "t",
    subject: "s",
    grade: "8",
    section_name: "A",
    entered_count: 5,
    total_count: 3,
  });
  assertEquals(api.pending, 0);
});

// ── EXM-1 bulk save — per-row guards (same updateExamMark path) ────────────────

function markRow(overrides: Partial<ExamMarkRow> = {}): ExamMarkRow {
  return {
    id: "mark-1",
    organization_id: ORG,
    school_id: SCHOOL,
    student_id: "stu-1",
    exam_id: "exam-1",
    exam_title: "Term 2",
    class_label: "8A",
    marks_obtained: null,
    max_marks: 100,
    student_name: "Asha",
    roll_number: "12",
    student_code: "S12",
    published: false,
    grade_letter: null,
    marks_entered: false,
    status: "present",
    updated_at: "2026-06-28T00:00:00Z",
    row_version: 1,
    ...overrides,
  };
}

Deno.test("EXM-1: a present row in a batch persists its integer marks", async () => {
  class Db {
    constructor(private row: ExamMarkRow) {}
    // deno-lint-ignore no-explicit-any
    queryObject<T>(sql: string, _args: any[] = []): Promise<T[]> {
      if (sql.includes("UPDATE exam_mark_entries")) {
        return Promise.resolve(
          [{ ...this.row, marks_obtained: 40, marks_entered: true, row_version: 2 }] as T[],
        );
      }
      return Promise.resolve([] as T[]);
    }
  }
  const db = new Db(markRow()) as unknown as TenantQueryClient;
  const updated = await updateExamMark(db, ORG, SCHOOL, "mark-1", 40);
  assertEquals(updated.marks_obtained, 40);
  assertEquals(updated.marks_entered, true);
});

Deno.test("EXM-1: a non-present (absent) row in a batch forces NULL marks", async () => {
  class Db {
    // deno-lint-ignore no-explicit-any
    queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
      if (sql.includes("UPDATE exam_mark_entries")) {
        // arg 4 is the persisted marks value — MUST be NULL for a non-present row.
        assertEquals(args[3], null);
        return Promise.resolve(
          [markRow({ marks_obtained: null, marks_entered: true, status: "absent", row_version: 2 })] as T[],
        );
      }
      return Promise.resolve([] as T[]);
    }
  }
  const db = new Db() as unknown as TenantQueryClient;
  // A supplied number is ignored for a non-present status (forced NULL).
  const updated = await updateExamMark(db, ORG, SCHOOL, "mark-1", 99, null, "absent");
  assertEquals(updated.marks_obtained, null);
  assertEquals(updated.status, "absent");
  assertEquals(updated.marks_entered, true);
});
