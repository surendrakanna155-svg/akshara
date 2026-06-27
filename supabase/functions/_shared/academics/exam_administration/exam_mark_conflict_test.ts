import {
  assertEquals,
  assertInstanceOf,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type ExamMarkRow,
  ExamMarkConflictError,
  examMarkToApi,
  updateExamMark,
} from "./exam_administration_repository.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";

const ORG = "org-1";
const SCHOOL = "school-1";

function markRow(overrides: Partial<ExamMarkRow> = {}): ExamMarkRow {
  return {
    id: "mark-1",
    organization_id: ORG,
    school_id: SCHOOL,
    student_id: "stu-1",
    exam_id: "exam-1",
    exam_title: "Term 1",
    class_label: "8A",
    marks_obtained: 40,
    max_marks: 100,
    student_name: "Asha",
    roll_number: "12",
    student_code: "S12",
    published: false,
    grade_letter: null,
    marks_entered: true,
    updated_at: "2026-06-28T00:00:00Z",
    row_version: 3,
    ...overrides,
  };
}

/** Mock that returns a current row at version 3 and a bumped row on update. */
class MockDb {
  constructor(private current: ExamMarkRow) {}
  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, _args: any[] = []): Promise<T[]> {
    if (sql.includes("SELECT * FROM exam_mark_entries")) {
      return Promise.resolve([this.current] as T[]);
    }
    if (sql.includes("UPDATE exam_mark_entries")) {
      // The bump_row_version trigger increments the version on write.
      return Promise.resolve(
        [{ ...this.current, marks_obtained: 55, row_version: this.current.row_version + 1 }] as T[],
      );
    }
    // UPDATE exam_sessions ... (coordinator reset) → no rows.
    return Promise.resolve([] as T[]);
  }
}

function db(row: ExamMarkRow): TenantQueryClient {
  return new MockDb(row) as unknown as TenantQueryClient;
}

Deno.test("no expectedVersion → unconditional update succeeds + version bumps", async () => {
  const updated = await updateExamMark(db(markRow()), ORG, SCHOOL, "mark-1", 55);
  assertEquals(updated.marks_obtained, 55);
  assertEquals(updated.row_version, 4, "trigger bumped 3 → 4");
});

Deno.test("matching expectedVersion → update succeeds", async () => {
  const updated = await updateExamMark(db(markRow()), ORG, SCHOOL, "mark-1", 55, 3);
  assertEquals(updated.marks_obtained, 55);
  assertEquals(updated.row_version, 4);
});

Deno.test("stale expectedVersion → ExamMarkConflictError carrying the current row", async () => {
  const error = await assertRejects(
    () => updateExamMark(db(markRow({ row_version: 3 })), ORG, SCHOOL, "mark-1", 55, 1),
  );
  assertInstanceOf(error, ExamMarkConflictError);
  // The conflict carries the CURRENT server row so the client can resolve it.
  assertEquals(error.currentRow.row_version, 3);
  const api = examMarkToApi(error.currentRow);
  assertEquals(api.rowVersion, 3);
});

Deno.test("examMarkToApi exposes rowVersion for the client to capture", () => {
  const api = examMarkToApi(markRow({ row_version: 7 }));
  assertEquals(api.rowVersion, 7);
});
