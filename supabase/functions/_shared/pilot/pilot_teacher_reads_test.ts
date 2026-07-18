import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  listTeacherAttendanceClasses,
  listTeacherExamMarks,
  listTeacherLeaveRequests,
  listTeacherUpcomingExams,
  overlayTeacherAttendanceStudents,
  overlayTeacherDashboard,
} from "./pilot_operations_repository.ts";

interface Capture {
  sql: string;
  args: unknown[];
}

// SQL-aware mock: routes each query to the first route whose `match` substring
// is found in the SQL; records every executed statement. A route's `rows` may
// be a function of the bound args (so a query that runs per-class can vary).
function mockDb(
  routes: Array<{
    match: string;
    rows: unknown[] | ((args: unknown[]) => unknown[]);
  }>,
  captures: Capture[] = [],
): TenantQueryClient {
  return {
    queryObject: async <T>(sql: string, args: unknown[] = []) => {
      captures.push({ sql, args });
      const hit = routes.find((r) => sql.includes(r.match));
      const rows = typeof hit?.rows === "function" ? hit.rows(args) : hit?.rows;
      return (rows ?? []) as T[];
    },
  } as unknown as TenantQueryClient;
}

const ORG = "org";
const SCHOOL = "school";
const TEACHER = "11111111-1111-4111-8111-111111111111";
const PAGE = { page: 1, pageSize: 20 };

// =========================================================================
// TEACH-1: attendance class list
// =========================================================================

Deno.test("listTeacherAttendanceClasses returns empty when teacher teaches nothing", async () => {
  const result = await listTeacherAttendanceClasses(
    mockDb([{ match: "FROM timetable_slots ts", rows: [] }]),
    ORG,
    SCHOOL,
    TEACHER,
    PAGE,
  );
  assertEquals(result.items, []);
  assertEquals(result.total, 0);
});

Deno.test("listTeacherAttendanceClasses ids match roster keys + flags pending", async () => {
  const result = await listTeacherAttendanceClasses(
    // PRA-P0-07 / P1-31 (S3): classes come from the canonical binding, then a
    // per-class unnest computes marked/count (one row per class, not per period).
    mockDb([
      {
        match: "FROM teacher_subject_assignments tsa",
        rows: [
          { class_name: "8", section_name: "A" },
          { class_name: "8", section_name: "B" },
        ],
      },
      {
        match: "unnest($3::text[])",
        rows: [
          { class_label: "8-A", marked: true, student_count: 30 },
          { class_label: "8-B", marked: false, student_count: 28 },
        ],
      },
    ]),
    ORG,
    SCHOOL,
    TEACHER,
    PAGE,
  );
  assertEquals(result.total, 2);
  // id matches the studentsByClass key form (class_<label>)
  assertEquals(result.items[0].id, "class_8-A");
  assertEquals(result.items[0].studentCount, 30);
  assertEquals(result.items[0].isPending, false); // already marked today
  assertEquals(result.items[1].id, "class_8-B");
  assertEquals(result.items[1].isPending, true); // not yet marked
});

// =========================================================================
// TEACH-1: attendance roster
// =========================================================================

Deno.test("overlayTeacherAttendanceStudents returns empty roster when teacher has no classes", async () => {
  const result = await overlayTeacherAttendanceStudents(
    mockDb([{ match: "FROM timetable_slots", rows: [] }]),
    ORG,
    SCHOOL,
    TEACHER,
    { classLabel: "8-A", students: [{ id: "seed" }], summary: { present: 9 } },
  );
  assertEquals(result.classLabel, "");
  assertEquals(result.studentsByClass, {});
  assertEquals(result.students, []);
  assertEquals(result.summary, { present: 0, absent: 0, late: 0 });
});

Deno.test("overlayTeacherAttendanceStudents builds studentsByClass with real marks", async () => {
  const result = await overlayTeacherAttendanceStudents(
    mockDb([
      // PRA-P0-07 (S3): teacher classes now come from the canonical binding.
      { match: "FROM teacher_subject_assignments tsa", rows: [{ class_name: "8", section_name: "A" }] },
      {
        match: "FROM students s",
        rows: [
          { id: "stu-1", name: "Asha Rao", roll_no: "1", mark: "present" },
          { id: "stu-2", name: "Ravi Kumar", roll_no: "2", mark: "absent" },
          { id: "stu-3", name: "Meena Devi", roll_no: "3", mark: null },
        ],
      },
    ]),
    ORG,
    SCHOOL,
    TEACHER,
    { classLabel: "seed", students: [], summary: { present: 0, absent: 0, late: 0 } },
  );

  assertEquals(result.classLabel, "8-A");
  const byClass = result.studentsByClass as Record<string, Record<string, unknown>[]>;
  assertEquals(byClass["class_8-A"].length, 3);
  assertEquals(byClass["class_8-A"][0], {
    id: "stu-1",
    name: "Asha Rao",
    rollNo: "1",
    mark: "present",
  });
  // unmarked student keeps the 'unmarked' marker
  assertEquals(byClass["class_8-A"][2].mark, "unmarked");
  // summary reflects only marked students of the first class
  assertEquals(result.summary, { present: 1, absent: 1, late: 0 });
  // `students` mirrors the first class for legacy single-class consumers
  assertEquals((result.students as unknown[]).length, 3);
});

// =========================================================================
// TEACH-1: upcoming exams
// =========================================================================

Deno.test("listTeacherUpcomingExams returns empty when teacher has no classes", async () => {
  const result = await listTeacherUpcomingExams(
    mockDb([{ match: "SELECT DISTINCT class_label", rows: [] }]),
    ORG,
    SCHOOL,
    TEACHER,
    PAGE,
  );
  assertEquals(result.items, []);
  assertEquals(result.total, 0);
  assertEquals(result.hasMore, false);
});

Deno.test("listTeacherUpcomingExams maps real exam_sessions to client shape", async () => {
  const result = await listTeacherUpcomingExams(
    mockDb([
      // PRA-P0-07 (S3): teacher classes now come from the canonical binding.
      { match: "FROM teacher_subject_assignments tsa", rows: [{ class_name: "8", section_name: "A" }] },
      {
        match: "FROM exam_sessions",
        rows: [
          {
            id: "exam_5",
            title: "Unit Test 3",
            subject: "Mathematics",
            grade: "8",
            section_name: "A",
            date_label: "20 Jul 2026",
            max_marks: 50,
          },
        ],
      },
    ]),
    ORG,
    SCHOOL,
    TEACHER,
    PAGE,
  );
  assertEquals(result.total, 1);
  assertEquals(result.items[0], {
    id: "exam_5",
    title: "Unit Test 3",
    subject: "Mathematics",
    classLabel: "8-A",
    dateLabel: "20 Jul 2026",
    maxMarks: 50,
  });
});

// =========================================================================
// TEACH-1: exam marks
// =========================================================================

Deno.test("listTeacherExamMarks returns empty when teacher has no classes", async () => {
  const result = await listTeacherExamMarks(
    mockDb([{ match: "SELECT DISTINCT class_label", rows: [] }]),
    ORG,
    SCHOOL,
    TEACHER,
    PAGE,
  );
  assertEquals(result.items, []);
  assertEquals(result.total, 0);
});

Deno.test("listTeacherExamMarks maps real mark entries (null when not entered)", async () => {
  const result = await listTeacherExamMarks(
    mockDb([
      // PRA-P0-07 (S3): teacher classes now come from the canonical binding.
      { match: "FROM teacher_subject_assignments tsa", rows: [{ class_name: "8", section_name: "A" }] },
      {
        match: "FROM exam_mark_entries me",
        rows: [
          {
            id: "exam_5_1",
            student_id: "stu-1",
            student_code: "S001",
            student_name: "Asha Rao",
            roll_number: "1",
            marks_obtained: 42,
            marks_entered: true,
            max_marks: 50,
          },
          {
            id: "exam_5_2",
            student_id: "stu-2",
            student_code: null,
            student_name: "Ravi Kumar",
            roll_number: "2",
            marks_obtained: 0,
            marks_entered: false,
            max_marks: 50,
          },
        ],
      },
    ]),
    ORG,
    SCHOOL,
    TEACHER,
    PAGE,
  );
  assertEquals(result.total, 2);
  assertEquals(result.items[0], {
    id: "exam_5_1",
    sisStudentId: "S001",
    studentName: "Asha Rao",
    rollNo: "1",
    marksObtained: 42,
    maxMarks: 50,
  });
  // not-yet-entered => marksObtained null, falls back to student_id for sisStudentId
  assertEquals(result.items[1].marksObtained, null);
  assertEquals(result.items[1].sisStudentId, "stu-2");
});

// =========================================================================
// TEACH-1: leave history
// =========================================================================

Deno.test("listTeacherLeaveRequests returns empty when no leave rows", async () => {
  const result = await listTeacherLeaveRequests(
    mockDb([{ match: "FROM mobile_leave_requests", rows: [] }]),
    ORG,
    SCHOOL,
    TEACHER,
    PAGE,
  );
  assertEquals(result.items, []);
  assertEquals(result.total, 0);
});

Deno.test("listTeacherLeaveRequests maps real teacher-scoped rows", async () => {
  const captures: Capture[] = [];
  const result = await listTeacherLeaveRequests(
    mockDb([
      {
        match: "FROM mobile_leave_requests",
        rows: [
          {
            id: "leave-1",
            type_label: "casual",
            from_date_label: "1 Jul 2026",
            to_date_label: "2 Jul 2026",
            reason: "Family function",
            status: "approved",
            submitted_label: "28 Jun 2026",
          },
        ],
      },
    ], captures),
    ORG,
    SCHOOL,
    TEACHER,
    PAGE,
  );
  assertEquals(result.total, 1);
  const item = result.items[0];
  assertEquals(item.id, "leave-1");
  assertEquals(item.typeLabel, "casual");
  assertEquals(item.fromDateLabel, "1 Jul 2026");
  assertEquals(item.status, "approved");
  // approved => second timeline step complete
  assertEquals((item.timeline as Record<string, unknown>[])[1].isComplete, true);
  // scoped to this teacher only
  const q = captures.find((c) => c.sql.includes("FROM mobile_leave_requests"));
  assertEquals(q!.args[2], TEACHER);
});

// =========================================================================
// TEACH-5: dashboard
// =========================================================================

Deno.test("overlayTeacherDashboard returns empty schedule + neutral insight for fresh school", async () => {
  const result = await overlayTeacherDashboard(
    mockDb([
      { match: "FROM timetable_slots", rows: [] },
      { match: "FROM homework_submissions hs", rows: [{ count: "0" }] },
    ]),
    ORG,
    SCHOOL,
    TEACHER,
    {
      greetingHeadline: "Good morning",
      todaySchedule: [{ id: "seed" }],
      pendingTasks: [{ id: "seed" }],
      aiInsight: { message: "2 classes need attendance today.", actionLabel: "Mark now" },
    },
  );
  // seed scaffolding preserved
  assertEquals(result.greetingHeadline, "Good morning");
  // computed: no classes today
  assertEquals(result.todaySchedule, []);
  assertEquals(result.pendingTasks, []);
  assertEquals(result.aiInsight, {
    message: "No classes scheduled for today.",
    actionLabel: "",
  });
  const summary = result.attendanceSummary as Record<string, unknown>;
  assertEquals(summary.classesTotal, 0);
  assertEquals(summary.classesMarked, 0);
});

Deno.test("overlayTeacherDashboard derives todaySchedule + pending attendance", async () => {
  const result = await overlayTeacherDashboard(
    mockDb([
      {
        match: "FROM timetable_slots",
        rows: [
          { period_number: 1, subject_label: "Math", class_label: "8-A", room_label: "201" },
          { period_number: 2, subject_label: "Math", class_label: "8-B", room_label: "202" },
        ],
      },
      // only 8-A is marked today
      { match: "FROM attendance_sessions", rows: [{ class_label: "8-A" }] },
      { match: "FROM homework_submissions hs", rows: [{ count: "3" }] },
    ]),
    ORG,
    SCHOOL,
    TEACHER,
    { greetingHeadline: "Hi" },
  );

  const schedule = result.todaySchedule as Record<string, unknown>[];
  assertEquals(schedule.length, 2);
  assertEquals(schedule[0].subject, "Math");
  assertEquals(schedule[0].classLabel, "8-A");

  // 2 classes today, 1 marked => 1 pending attendance + 3 homework reviews
  const tasks = result.pendingTasks as Record<string, unknown>[];
  assertEquals(tasks.length, 2);
  assertEquals(tasks[0], {
    id: "attendance",
    icon: "attendance",
    count: 1,
    label: "1 class needs attendance",
  });
  assertEquals(tasks[1].count, 3);

  // insight prioritises attendance
  assertEquals(result.aiInsight, {
    message: "1 class needs attendance today.",
    actionLabel: "Mark now",
  });

  const summary = result.attendanceSummary as Record<string, unknown>;
  assertEquals(summary.classesTotal, 2);
  assertEquals(summary.classesMarked, 1);
  assertEquals(summary.pendingClassId, "class_8-B");
});

Deno.test("overlayTeacherDashboard shows all-caught-up when every class is marked", async () => {
  const result = await overlayTeacherDashboard(
    mockDb([
      {
        match: "FROM timetable_slots",
        rows: [
          { period_number: 1, subject_label: "Math", class_label: "8-A", room_label: "201" },
        ],
      },
      { match: "FROM attendance_sessions", rows: [{ class_label: "8-A" }] },
      { match: "FROM homework_submissions hs", rows: [{ count: "0" }] },
    ]),
    ORG,
    SCHOOL,
    TEACHER,
    {},
  );
  assertEquals(result.pendingTasks, []);
  assertEquals(result.aiInsight, {
    message: "All caught up — attendance is marked for today's classes.",
    actionLabel: "",
  });
});
