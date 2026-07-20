// W4 Staff Duty — repository round-trip + org/school binding (DB-free fake DB).
//
// Proves for each of the three dedicated tables:
//   • create INSERTs into the RIGHT table with org+school bound args (never an
//     attendance table);
//   • list-by-staff filters on the correct staff column;
//   • list-by-date filters on the correct date column;
//   • the round-tripped row is returned verbatim.

import { assert, assertEquals } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  createExamInvigilationDuty,
  createNonTeachingDuty,
  createSubstituteClass,
  type ExamInvigilationDutyRow,
  listExamInvigilationDutiesByDate,
  listExamInvigilationDutiesByStaff,
  listNonTeachingDutiesByDate,
  listNonTeachingDutiesByStaff,
  listSubstituteClassesByDate,
  listSubstituteClassesByStaff,
  type NonTeachingDutyRow,
  type SubstituteClassRow,
} from "./staff_duty_repository.ts";

interface Call {
  sql: string;
  args: unknown[];
}

function mockDb(results: unknown[][]): { db: TenantQueryClient; calls: Call[] } {
  const calls: Call[] = [];
  let i = 0;
  const db = {
    queryObject: <T>(sql: string, args: unknown[] = []): Promise<T[]> => {
      calls.push({ sql, args });
      return Promise.resolve((results[i++] ?? []) as T[]);
    },
  } as unknown as TenantQueryClient;
  return { db, calls };
}

const SCOPE = { organizationId: "org-1", schoolId: "school-1" };

const subRow = (over: Partial<SubstituteClassRow> = {}): SubstituteClassRow => ({
  id: "sub-1",
  absent_teacher_id: "teacher-absent",
  substitute_teacher_id: "teacher-sub",
  duty_date: "2026-07-20",
  period_label: "P3",
  timetable_period_id: null,
  reason: "sick leave cover",
  created_by: "admin-1",
  created_at: "2026-07-20T09:00:00Z",
  ...over,
});

const invRow = (over: Partial<ExamInvigilationDutyRow> = {}): ExamInvigilationDutyRow => ({
  id: "inv-1",
  staff_id: "staff-9",
  exam_id: null,
  exam_label: "Term 1 Maths",
  duty_date: "2026-07-20",
  room: "Hall A",
  session: "FN",
  created_by: "admin-1",
  created_at: "2026-07-20T09:00:00Z",
  ...over,
});

const ntRow = (over: Partial<NonTeachingDutyRow> = {}): NonTeachingDutyRow => ({
  id: "nt-1",
  staff_id: "staff-9",
  duty_type: "ground_duty",
  start_date: "2026-07-20",
  end_date: null,
  description: "morning assembly supervision",
  created_by: "admin-1",
  created_at: "2026-07-20T09:00:00Z",
  ...over,
});

// ─── Substitute classes ─────────────────────────────────────────────────────

Deno.test("createSubstituteClass: INSERTs into staff_substitute_classes, org+school bound, burden on the substitute", async () => {
  const { db, calls } = mockDb([[subRow()]]);
  const out = await createSubstituteClass(db, SCOPE, {
    absentTeacherId: "teacher-absent",
    substituteTeacherId: "teacher-sub",
    dutyDate: "2026-07-20",
    periodLabel: "P3",
    timetablePeriodId: null,
    reason: "sick leave cover",
    createdBy: "admin-1",
  });
  assert(calls[0].sql.includes("INSERT INTO staff_substitute_classes"));
  // The dedicated table is used — NEVER an attendance table.
  assert(!/attendance|check_in/i.test(calls[0].sql));
  assertEquals(calls[0].args, [
    "org-1", "school-1", "teacher-absent", "teacher-sub",
    "2026-07-20", "P3", null, "sick leave cover", "admin-1",
  ]);
  assertEquals(out.substitute_teacher_id, "teacher-sub");
});

Deno.test("listSubstituteClassesByStaff: filters on substitute_teacher_id, org+school bound", async () => {
  const { db, calls } = mockDb([[subRow(), subRow({ id: "sub-2" })]]);
  const rows = await listSubstituteClassesByStaff(db, SCOPE, "teacher-sub", 50);
  assert(calls[0].sql.includes("FROM staff_substitute_classes"));
  assert(calls[0].sql.includes("substitute_teacher_id = $3"));
  assert(calls[0].sql.includes("organization_id = $1 AND school_id = $2"));
  assertEquals(calls[0].args, ["org-1", "school-1", "teacher-sub", 50]);
  assertEquals(rows.length, 2);
});

Deno.test("listSubstituteClassesByDate: filters on duty_date", async () => {
  const { db, calls } = mockDb([[subRow()]]);
  await listSubstituteClassesByDate(db, SCOPE, "2026-07-20", 25);
  assert(calls[0].sql.includes("duty_date = $3"));
  assertEquals(calls[0].args, ["org-1", "school-1", "2026-07-20", 25]);
});

// ─── Exam invigilation duties ───────────────────────────────────────────────

Deno.test("createExamInvigilationDuty: INSERTs into staff_exam_invigilation_duties, org+school bound", async () => {
  const { db, calls } = mockDb([[invRow()]]);
  const out = await createExamInvigilationDuty(db, SCOPE, {
    staffId: "staff-9",
    examId: null,
    examLabel: "Term 1 Maths",
    dutyDate: "2026-07-20",
    room: "Hall A",
    session: "FN",
    createdBy: "admin-1",
  });
  assert(calls[0].sql.includes("INSERT INTO staff_exam_invigilation_duties"));
  assert(!/attendance|check_in/i.test(calls[0].sql));
  assertEquals(calls[0].args, [
    "org-1", "school-1", "staff-9", null, "Term 1 Maths",
    "2026-07-20", "Hall A", "FN", "admin-1",
  ]);
  assertEquals(out.room, "Hall A");
});

Deno.test("listExamInvigilationDutiesByStaff: filters on staff_id", async () => {
  const { db, calls } = mockDb([[invRow()]]);
  await listExamInvigilationDutiesByStaff(db, SCOPE, "staff-9", 10);
  assert(calls[0].sql.includes("FROM staff_exam_invigilation_duties"));
  assert(calls[0].sql.includes("staff_id = $3"));
  assertEquals(calls[0].args, ["org-1", "school-1", "staff-9", 10]);
});

Deno.test("listExamInvigilationDutiesByDate: filters on duty_date", async () => {
  const { db, calls } = mockDb([[invRow()]]);
  await listExamInvigilationDutiesByDate(db, SCOPE, "2026-07-20", 10);
  assert(calls[0].sql.includes("duty_date = $3"));
  assertEquals(calls[0].args, ["org-1", "school-1", "2026-07-20", 10]);
});

// ─── Non-teaching duties ────────────────────────────────────────────────────

Deno.test("createNonTeachingDuty: INSERTs into staff_non_teaching_duties (single-day when end null)", async () => {
  const { db, calls } = mockDb([[ntRow()]]);
  const out = await createNonTeachingDuty(db, SCOPE, {
    staffId: "staff-9",
    dutyType: "ground_duty",
    startDate: "2026-07-20",
    endDate: null,
    description: "morning assembly supervision",
    createdBy: "admin-1",
  });
  assert(calls[0].sql.includes("INSERT INTO staff_non_teaching_duties"));
  assert(!/attendance|check_in/i.test(calls[0].sql));
  assertEquals(calls[0].args, [
    "org-1", "school-1", "staff-9", "ground_duty",
    "2026-07-20", null, "morning assembly supervision", "admin-1",
  ]);
  assertEquals(out.end_date, null);
});

Deno.test("listNonTeachingDutiesByStaff: filters on staff_id", async () => {
  const { db, calls } = mockDb([[ntRow()]]);
  await listNonTeachingDutiesByStaff(db, SCOPE, "staff-9", 10);
  assert(calls[0].sql.includes("FROM staff_non_teaching_duties"));
  assert(calls[0].sql.includes("staff_id = $3"));
  assertEquals(calls[0].args, ["org-1", "school-1", "staff-9", 10]);
});

Deno.test("listNonTeachingDutiesByDate: matches duties whose [start,end] range spans the date", async () => {
  const { db, calls } = mockDb([[ntRow({ end_date: "2026-07-25" })]]);
  await listNonTeachingDutiesByDate(db, SCOPE, "2026-07-22", 10);
  // The date must be inside [start_date, COALESCE(end_date, start_date)].
  assert(calls[0].sql.includes("start_date <= $3"));
  assert(calls[0].sql.includes("COALESCE(end_date, start_date) >= $3"));
  assertEquals(calls[0].args, ["org-1", "school-1", "2026-07-22", 10]);
});

Deno.test("every repository query is explicitly org+school bound ($1,$2)", async () => {
  const { db, calls } = mockDb([[subRow()], [invRow()], [ntRow()]]);
  await listSubstituteClassesByStaff(db, SCOPE, "t", 10);
  await listExamInvigilationDutiesByStaff(db, SCOPE, "s", 10);
  await listNonTeachingDutiesByStaff(db, SCOPE, "s", 10);
  for (const c of calls) {
    assert(c.sql.includes("organization_id = $1"), c.sql);
    assert(c.sql.includes("school_id = $2"), c.sql);
    assertEquals(c.args[0], "org-1");
    assertEquals(c.args[1], "school-1");
  }
});
