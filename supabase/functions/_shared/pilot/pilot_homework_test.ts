import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  insertHomeworkAssignment,
  overlayStudentHomeworkFromSubmissions,
  overlayTeacherHomeworkSubmissions,
  parseClassLabel,
  reviewHomework,
} from "./pilot_operations_repository.ts";

interface Capture {
  sql: string;
  args: unknown[];
}

// SQL-aware mock: routes each query to the first route whose `match` substring
// is found in the SQL and records every executed statement so write-backs can
// be asserted. A route's `rows` may be a function of the bound args.
function mockDb(
  routes: Array<{
    match: string;
    rows: unknown[] | ((args: unknown[]) => unknown[]);
  }>,
  captures: Capture[],
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

// --- parseClassLabel (MJ-H8 helper) ---

Deno.test("parseClassLabel splits '8-A' into class + section", () => {
  assertEquals(parseClassLabel("8-A"), { className: "8", sectionName: "A" });
});

Deno.test("parseClassLabel splits whitespace form '8 A'", () => {
  assertEquals(parseClassLabel("8 A"), { className: "8", sectionName: "A" });
});

Deno.test("parseClassLabel treats bare class '8' as whole class (no section)", () => {
  assertEquals(parseClassLabel("8"), { className: "8", sectionName: null });
});

Deno.test("parseClassLabel trims surrounding whitespace", () => {
  assertEquals(parseClassLabel("  10 - B  "), { className: "10", sectionName: "B" });
});

// --- MJ-C2: teacher homework read attaches submissions[] + pendingReviews ---

Deno.test("overlayTeacherHomeworkSubmissions attaches real submissions + pendingReviews", async () => {
  const captures: Capture[] = [];
  const items = [
    { id: "hw-1", title: "Algebra 5.2", classLabel: "8-A", dueLabel: "Tomorrow" },
    { id: "hw-2", title: "Photosynthesis", classLabel: "8-A", dueLabel: "Friday" },
  ];
  const result = await overlayTeacherHomeworkSubmissions(
    mockDb([
      {
        match: "FROM homework_submissions hs",
        rows: [
          {
            id: "sub-uuid-1",
            homework_id: "hw-1",
            student_name: "Asha Rao",
            class_label: "8-A",
            status: "submitted",
            grade: null,
            comment: null,
            submitted_label: "23 Jun 2026",
          },
          {
            id: "sub-uuid-2",
            homework_id: "hw-1",
            student_name: "Ravi Kumar",
            class_label: "8-A",
            status: "reviewed",
            grade: "A",
            comment: "Great work",
            submitted_label: "22 Jun 2026",
          },
        ],
      },
    ], captures),
    "org",
    "school",
    items,
  );

  const hw1 = result[0];
  const subs = hw1.submissions as Record<string, unknown>[];
  assertEquals(subs.length, 2);
  // real submission UUID carried through (so the review POST targets a real row)
  assertEquals(subs[0].id, "sub-uuid-1");
  assertEquals(subs[0].studentName, "Asha Rao");
  assertEquals(subs[0].status, "submitted");
  assertEquals(subs[0].submittedLabel, "23 Jun 2026");
  assertEquals(subs[1].grade, "A");
  // pendingReviews counts only 'submitted' (not yet reviewed)
  assertEquals(hw1.pendingReviews, 1);

  // hw-2 has no submissions
  const hw2 = result[1];
  assertEquals((hw2.submissions as unknown[]).length, 0);
  assertEquals(hw2.pendingReviews, 0);
});

Deno.test("overlayTeacherHomeworkSubmissions returns items untouched when none", async () => {
  const captures: Capture[] = [];
  const result = await overlayTeacherHomeworkSubmissions(
    mockDb([], captures),
    "org",
    "school",
    [],
  );
  assertEquals(result, []);
});

// --- MJ-H7: reviewHomework writes status/grade back to student_entities ---

Deno.test("reviewHomework writes grade/status back to student_entities homework_item", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    {
      match: "UPDATE homework_submissions",
      rows: [{ id: "sub-1", homework_id: "hw-1", student_id: "stu-9" }],
    },
    { match: "FROM students", rows: [{ display_name: "Asha Rao" }] },
    { match: "UPDATE student_entities", rows: [] },
  ], captures);

  const result = await reviewHomework(db, "org", "school", "sub-1", {
    grade: "A+",
    comment: "Well done",
    reviewerId: "teacher-1",
  });

  // the student_entities write-back happened, scoped to the right keys
  const writeBack = captures.find((c) => c.sql.includes("UPDATE student_entities"));
  assert(writeBack, "expected an UPDATE on student_entities");
  assertEquals(writeBack!.args[0], "org");
  assertEquals(writeBack!.args[1], "school");
  assertEquals(writeBack!.args[2], "hw-1"); // homework id
  assertEquals(writeBack!.args[3], "A+"); // grade
  assertEquals(writeBack!.args[4], "Well done"); // comment
  assertEquals(writeBack!.args[5], "stu-9"); // student id
  assert(
    writeBack!.sql.includes("'reviewed'"),
    "write-back must set status reviewed",
  );

  // review result carries the real student name + grade
  const submission = result.submission as Record<string, unknown>;
  assertEquals(submission.studentName, "Asha Rao");
  assertEquals(submission.grade, "A+");
  assertEquals(submission.status, "reviewed");
});

Deno.test("reviewHomework skips write-back when submission row is missing", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    { match: "UPDATE homework_submissions", rows: [] },
  ], captures);

  await reviewHomework(db, "org", "school", "missing", {
    grade: "B",
    comment: "",
    reviewerId: "teacher-1",
  });

  const writeBack = captures.find((c) => c.sql.includes("UPDATE student_entities"));
  assertEquals(writeBack, undefined);
});

// --- MJ-H7 belt-and-suspenders: student list overlay ---

Deno.test("overlayStudentHomeworkFromSubmissions reflects reviewed status + grade", async () => {
  const captures: Capture[] = [];
  const items = [
    { id: "hw-1", subject: "Math", title: "Algebra", dueLabel: "x", status: "pending" },
    { id: "hw-2", subject: "Science", title: "Lab", dueLabel: "y", status: "pending" },
  ];
  const result = await overlayStudentHomeworkFromSubmissions(
    mockDb([
      {
        match: "FROM homework_submissions",
        rows: [
          {
            homework_id: "hw-1",
            status: "reviewed",
            grade: "A",
            comment: "Nice",
            submitted_label: "20 Jun 2026",
          },
        ],
      },
    ], captures),
    "org",
    "school",
    "stu-1",
    items,
  );

  // hw-1 reflects the reviewed submission with grade/comment
  assertEquals(result[0].status, "reviewed");
  assertEquals(result[0].reviewGrade, "A");
  assertEquals(result[0].reviewComment, "Nice");
  assertEquals(result[0].submittedLabel, "20 Jun 2026");
  // hw-2 has no submission, untouched (still pending)
  assertEquals(result[1].status, "pending");
  assertEquals(result[1].reviewGrade, undefined);
});

// --- MJ-H8: insertHomeworkAssignment targets the class via enrollments ---

Deno.test("insertHomeworkAssignment targets only the matching class when enrollments exist", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    { match: "INSERT INTO teacher_entities", rows: [] },
    {
      match: "INNER JOIN sis_student_enrollments e",
      rows: [{ id: "stu-1" }, { id: "stu-2" }],
    },
    {
      match: "count(*)::text AS total FROM sis_student_enrollments",
      rows: [{ total: "12" }],
    },
    { match: "INSERT INTO student_entities", rows: [] },
  ], captures);

  const result = await insertHomeworkAssignment(db, {
    organizationId: "org",
    schoolId: "school",
    teacherId: "teacher-1",
    homeworkId: "hw_x",
    classLabel: "8-A",
    subject: "Math",
    title: "Algebra",
    dueLabel: "Tomorrow",
    studentName: null,
  });

  // only the 2 enrolled students of class 8 section A were targeted
  assertEquals(result.deliveredCount, 2);
  // the class-targeting query ran with parsed class_name + section_name
  const classQuery = captures.find((c) =>
    c.sql.includes("INNER JOIN sis_student_enrollments e")
  );
  assert(classQuery, "expected the enrollment-targeting query");
  assertEquals(classQuery!.args[2], "8"); // class_name
  assertEquals(classQuery!.args[3], "A"); // section_name
  // exactly 2 homework_item inserts
  const inserts = captures.filter((c) =>
    c.sql.includes("INSERT INTO student_entities")
  );
  assertEquals(inserts.length, 2);
});

Deno.test("insertHomeworkAssignment falls back to all active students when no enrollments", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    { match: "INSERT INTO teacher_entities", rows: [] },
    {
      match: "count(*)::text AS total FROM sis_student_enrollments",
      rows: [{ total: "0" }],
    },
    {
      // the fallback full-roster query (no enrollment join)
      match: "WHERE organization_id = $1 AND school_id = $2 AND status = 'active'",
      rows: [{ id: "a" }, { id: "b" }, { id: "c" }],
    },
    { match: "INSERT INTO student_entities", rows: [] },
  ], captures);

  const result = await insertHomeworkAssignment(db, {
    organizationId: "org",
    schoolId: "school",
    teacherId: "teacher-1",
    homeworkId: "hw_y",
    classLabel: "8-A",
    subject: "Math",
    title: "Algebra",
    dueLabel: "Tomorrow",
    studentName: null,
  });

  // legacy behavior: whole active roster targeted
  assertEquals(result.deliveredCount, 3);
  // the enrollment-targeting query was NOT used
  const classQuery = captures.find((c) =>
    c.sql.includes("INNER JOIN sis_student_enrollments e")
  );
  assertEquals(classQuery, undefined);
});

Deno.test("insertHomeworkAssignment named-student branch targets one student", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    { match: "INSERT INTO teacher_entities", rows: [] },
    { match: "lower(display_name) = lower($3)", rows: [{ id: "stu-named" }] },
    { match: "INSERT INTO student_entities", rows: [] },
  ], captures);

  const result = await insertHomeworkAssignment(db, {
    organizationId: "org",
    schoolId: "school",
    teacherId: "teacher-1",
    homeworkId: "hw_z",
    classLabel: "8-A",
    subject: "Math",
    title: "Algebra",
    dueLabel: "Tomorrow",
    studentName: "Asha Rao",
  });

  assertEquals(result.deliveredCount, 1);
  // enrollment count was never checked for the named branch
  const enrollCount = captures.find((c) =>
    c.sql.includes("count(*)::text AS total FROM sis_student_enrollments")
  );
  assertEquals(enrollCount, undefined);
});
