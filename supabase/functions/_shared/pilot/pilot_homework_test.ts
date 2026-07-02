import {
  assert,
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  bulkReviewHomework,
  deriveHomeworkDisplayStatus,
  dueDateToLabel,
  HomeworkAlreadySubmittedError,
  HomeworkNotDeliveredError,
  insertHomeworkAssignment,
  isDueDateInPast,
  listHomeworkNonSubmitters,
  listTeacherHomeworkHistory,
  notifyHomeworkNonSubmitters,
  overlayParentHomeworkDueState,
  overlayStudentHomeworkFromSubmissions,
  overlayTeacherHomeworkSubmissions,
  parseClassLabel,
  reviewHomework,
  submitHomework,
  validateDueDate,
} from "./pilot_operations_repository.ts";
import { parseHomeworkClassLabels } from "./pilot_operations_handlers.ts";

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
    dueDate: "2026-07-10",
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
    dueDate: "2026-07-10",
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
    dueDate: "2026-07-10",
    studentName: "Asha Rao",
  });

  assertEquals(result.deliveredCount, 1);
  // enrollment count was never checked for the named branch
  const enrollCount = captures.find((c) =>
    c.sql.includes("count(*)::text AS total FROM sis_student_enrollments")
  );
  assertEquals(enrollCount, undefined);
});

// --- HWK-1: due_date propagates into the delivered homework_item payload ---

Deno.test("insertHomeworkAssignment carries dueDate into teacher + student payloads", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    { match: "INSERT INTO teacher_entities", rows: [] },
    { match: "lower(display_name) = lower($3)", rows: [{ id: "stu-named" }] },
    { match: "INSERT INTO student_entities", rows: [] },
  ], captures);

  await insertHomeworkAssignment(db, {
    organizationId: "org",
    schoolId: "school",
    teacherId: "teacher-1",
    homeworkId: "hw_due",
    classLabel: "8-A",
    subject: "Math",
    title: "Algebra",
    dueLabel: "Due 10 Jul",
    dueDate: "2026-07-10",
    studentName: "Asha Rao",
  });

  const teacherInsert = captures.find((c) =>
    c.sql.includes("INSERT INTO teacher_entities")
  );
  assert(teacherInsert, "expected the teacher_entities insert");
  assert(
    teacherInsert!.sql.includes("'dueDate'"),
    "teacher payload must carry dueDate",
  );
  assertEquals(teacherInsert!.args[7], "2026-07-10"); // dueDate bound param

  const studentInsert = captures.find((c) =>
    c.sql.includes("INSERT INTO student_entities")
  );
  assert(studentInsert, "expected the student_entities insert");
  assert(
    studentInsert!.sql.includes("'dueDate'"),
    "student payload must carry dueDate",
  );
  assertEquals(studentInsert!.args[7], "2026-07-10"); // dueDate bound param
});

// --- Cross-class scope: submit is rejected for a non-delivered assignment ---

Deno.test("submitHomework rejects when the assignment was not delivered to the student", async () => {
  const captures: Capture[] = [];
  // The delivery-probe SELECT returns no row → not delivered to this student.
  const db = mockDb([
    { match: "FROM student_entities", rows: [] },
  ], captures);

  await assertRejects(
    () =>
      submitHomework(db, {
        organizationId: "org",
        schoolId: "school",
        studentId: "stu-1",
        homeworkId: "hw-other-class",
        notes: "done",
      }),
    HomeworkNotDeliveredError,
  );

  // Never attempted the INSERT once the delivery check failed.
  const insert = captures.find((c) =>
    c.sql.includes("INSERT INTO homework_submissions")
  );
  assertEquals(insert, undefined);
});

Deno.test("submitHomework inserts once the assignment was delivered", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    { match: "FROM student_entities", rows: [{ id: "hw-1" }] },
    { match: "INSERT INTO homework_submissions", rows: [{ id: "sub-1" }] },
  ], captures);

  const result = await submitHomework(db, {
    organizationId: "org",
    schoolId: "school",
    studentId: "stu-1",
    homeworkId: "hw-1",
    notes: "done",
  });

  assertEquals(result.status, "submitted");
  const insert = captures.find((c) =>
    c.sql.includes("INSERT INTO homework_submissions")
  );
  assert(insert, "expected the submission insert");
  // Plain INSERT (no ON CONFLICT upsert) so a dup raises a unique violation.
  assert(
    !insert!.sql.includes("ON CONFLICT"),
    "submit must not upsert — a dup must surface as a conflict",
  );
});

// --- Duplicate submission surfaces as a 409-mappable error, not a 500 ---

Deno.test("submitHomework maps a unique violation to HomeworkAlreadySubmittedError", async () => {
  // Custom throwing mock: delivery probe passes, then the INSERT raises a PG
  // unique_violation (SQLSTATE 23505) as the driver would on a dup.
  const db = {
    queryObject: <T>(sql: string) => {
      if (sql.includes("FROM student_entities")) {
        return Promise.resolve([{ id: "hw-1" }] as T[]);
      }
      if (sql.includes("INSERT INTO homework_submissions")) {
        const err = new Error(
          "duplicate key value violates unique constraint",
        ) as Error & { code: string };
        err.code = "23505";
        throw err;
      }
      return Promise.resolve([] as T[]);
    },
  } as unknown as TenantQueryClient;

  await assertRejects(
    () =>
      submitHomework(db, {
        organizationId: "org",
        schoolId: "school",
        studentId: "stu-1",
        homeworkId: "hw-1",
        notes: "again",
      }),
    HomeworkAlreadySubmittedError,
  );
});

Deno.test("submitHomework rethrows a non-unique DB error unchanged", async () => {
  const db = {
    queryObject: <T>(sql: string) => {
      if (sql.includes("FROM student_entities")) {
        return Promise.resolve([{ id: "hw-1" }] as T[]);
      }
      if (sql.includes("INSERT INTO homework_submissions")) {
        throw new Error("connection reset");
      }
      return Promise.resolve([] as T[]);
    },
  } as unknown as TenantQueryClient;

  await assertRejects(
    () =>
      submitHomework(db, {
        organizationId: "org",
        schoolId: "school",
        studentId: "stu-1",
        homeworkId: "hw-1",
        notes: "x",
      }),
    Error,
    "connection reset",
  );
});

// --- HWK-1: due_date validation ---

Deno.test("validateDueDate accepts a real ISO date, rejects blank/garbage/impossible", () => {
  assertEquals(validateDueDate("2026-07-10"), "2026-07-10");
  assertEquals(validateDueDate("  2026-07-10  "), "2026-07-10");
  assertEquals(validateDueDate(""), null);
  assertEquals(validateDueDate(null), null);
  assertEquals(validateDueDate("next Monday"), null);
  assertEquals(validateDueDate("2026-13-01"), null); // no 13th month
  assertEquals(validateDueDate("2026-02-30"), null); // Feb 30 never exists
  assertEquals(validateDueDate("07/10/2026"), null); // wrong format
});

Deno.test("dueDateToLabel renders a human Due label from an ISO date", () => {
  assertEquals(dueDateToLabel("2026-07-08"), "Due 08 Jul");
  assertEquals(dueDateToLabel("garbage"), "");
});

Deno.test("isDueDateInPast is true only for a date strictly before today", () => {
  const today = new Date(Date.UTC(2026, 6, 10)); // 2026-07-10
  assert(isDueDateInPast("2026-07-09", today));
  assert(!isDueDateInPast("2026-07-10", today)); // today is not past
  assert(!isDueDateInPast("2026-07-11", today));
});

// --- HWK-1: overdue derivation ---

Deno.test("deriveHomeworkDisplayStatus flips pending→overdue when past due", () => {
  const today = new Date(Date.UTC(2026, 6, 10)); // 2026-07-10
  // pending + past due → overdue
  assertEquals(deriveHomeworkDisplayStatus("pending", "2026-07-09", today), "overdue");
  // pending + due today → still pending (not overdue)
  assertEquals(deriveHomeworkDisplayStatus("pending", "2026-07-10", today), "pending");
  // pending + future → pending
  assertEquals(deriveHomeworkDisplayStatus("pending", "2026-07-20", today), "pending");
  // submitted/reviewed are terminal — never overdue even if past due
  assertEquals(deriveHomeworkDisplayStatus("submitted", "2026-07-01", today), "submitted");
  assertEquals(deriveHomeworkDisplayStatus("reviewed", "2026-07-01", today), "reviewed");
  // no dueDate → keep raw status (legacy label-only homework)
  assertEquals(deriveHomeworkDisplayStatus("pending", null, today), "pending");
});

Deno.test("overlayStudentHomeworkFromSubmissions derives overdue for a pending item past due", async () => {
  const captures: Capture[] = [];
  const items = [
    // pending, past due, no submission → should become overdue
    { id: "hw-1", subject: "Math", title: "Algebra", dueLabel: "x", dueDate: "2000-01-01", status: "pending" },
    // pending, no dueDate → stays pending (legacy)
    { id: "hw-2", subject: "Sci", title: "Lab", dueLabel: "y", status: "pending" },
  ];
  const result = await overlayStudentHomeworkFromSubmissions(
    // no submission rows at all
    mockDb([{ match: "FROM homework_submissions", rows: [] }], captures),
    "org",
    "school",
    "stu-1",
    items,
  );
  assertEquals(result[0].status, "overdue");
  assertEquals(result[1].status, "pending");
});

Deno.test("overlayParentHomeworkDueState derives overdue on snapshot items", () => {
  const today = new Date(Date.UTC(2026, 6, 10));
  const snapshot = {
    childName: "Ravi",
    items: [
      { id: "hw-1", status: "pending", dueDate: "2026-07-01" }, // past → overdue
      { id: "hw-2", status: "pending", dueDate: "2026-07-20" }, // future → pending
      { id: "hw-3", status: "submitted", dueDate: "2026-07-01" }, // terminal → submitted
      { id: "hw-4", status: "pending" }, // no dueDate → pending
    ],
  };
  const result = overlayParentHomeworkDueState(snapshot, today);
  const items = result.items as Array<Record<string, unknown>>;
  assertEquals(items[0].status, "overdue");
  assertEquals(items[1].status, "pending");
  assertEquals(items[2].status, "submitted");
  assertEquals(items[3].status, "pending");
  // identity fields preserved
  assertEquals(result.childName, "Ravi");
});

// --- HWK-2: not-submitted list = delivered roster minus submissions ---

Deno.test("listHomeworkNonSubmitters returns delivered students with no submission", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    {
      // The LEFT JOIN already filters to hs.id IS NULL in SQL; the mock just
      // returns the two students the query would surface.
      match: "FROM student_entities se",
      rows: [
        { student_id: "stu-1", name: "Asha Rao" },
        { student_id: "stu-2", name: "Ravi Kumar" },
      ],
    },
  ], captures);

  const result = await listHomeworkNonSubmitters(db, "org", "school", "hw-1");
  assertEquals(result, [
    { studentId: "stu-1", name: "Asha Rao" },
    { studentId: "stu-2", name: "Ravi Kumar" },
  ]);
  // scoped by the homework id + is a LEFT JOIN filtered to unsubmitted rows
  const query = captures[0]!;
  assertEquals(query.args[0], "org");
  assertEquals(query.args[1], "school");
  assertEquals(query.args[2], "hw-1");
  assert(
    query.sql.includes("LEFT JOIN homework_submissions") &&
      query.sql.includes("hs.id IS NULL"),
    "must LEFT JOIN submissions and keep only the never-submitted rows",
  );
});

Deno.test("listHomeworkNonSubmitters returns empty when everyone submitted", async () => {
  const captures: Capture[] = [];
  const db = mockDb([{ match: "FROM student_entities se", rows: [] }], captures);
  const result = await listHomeworkNonSubmitters(db, "org", "school", "hw-1");
  assertEquals(result, []);
});

// --- HWK-6: bulk review reuses reviewHomework per row (partial success) ---

Deno.test("bulkReviewHomework reviews explicit ids and reports skipped for misses", async () => {
  const captures: Capture[] = [];
  // sub-1 + sub-2 update to a real row (reviewed); sub-3 matches no row.
  const db = mockDb([
    {
      match: "UPDATE homework_submissions",
      rows: (args) => {
        const id = String(args[0]);
        if (id === "sub-3") return [];
        return [{ id, homework_id: "hw-1", student_id: `stu-${id}` }];
      },
    },
    { match: "FROM students", rows: [{ display_name: "Asha Rao" }] },
    { match: "UPDATE student_entities", rows: [] },
  ], captures);

  const result = await bulkReviewHomework(db, "org", "school", {
    homeworkId: "hw-1",
    submissionIds: ["sub-1", "sub-2", "sub-3"],
    grade: "A",
    comment: "ok",
    reviewerId: "teacher-1",
  });

  assertEquals(result.reviewed, 2);
  assertEquals(result.skipped, 1);
  assertEquals(result.reviewedIds.sort(), ["sub-1", "sub-2"]);
  // each reviewed row also wrote back to student_entities (reused review path)
  const writeBacks = captures.filter((c) =>
    c.sql.includes("UPDATE student_entities")
  );
  assertEquals(writeBacks.length, 2);
});

Deno.test("bulkReviewHomework with no ids resolves all pending submissions of the assignment", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    {
      // the "all pending for this homework" resolver
      match: "status = 'submitted'",
      rows: [{ id: "sub-a" }, { id: "sub-b" }],
    },
    {
      match: "UPDATE homework_submissions",
      rows: (args) => [{
        id: String(args[0]),
        homework_id: "hw-9",
        student_id: "stu-x",
      }],
    },
    { match: "FROM students", rows: [{ display_name: "Kid" }] },
    { match: "UPDATE student_entities", rows: [] },
  ], captures);

  const result = await bulkReviewHomework(db, "org", "school", {
    homeworkId: "hw-9",
    submissionIds: [],
    grade: "B",
    comment: "",
    reviewerId: "teacher-1",
  });

  assertEquals(result.reviewed, 2);
  assertEquals(result.skipped, 0);
  // it first resolved the pending set for the homework id
  const resolver = captures.find((c) => c.sql.includes("status = 'submitted'"));
  assert(resolver, "expected the pending-submissions resolver query");
  assertEquals(resolver!.args[2], "hw-9");
});

// --- HWK-5: teacher homework history with per-assignment counts + date range ---

Deno.test("listTeacherHomeworkHistory maps counts + passes the date-range filter", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    {
      match: "FROM teacher_entities te",
      rows: [
        {
          id: "hw-1",
          title: "Algebra",
          class_label: "8-A",
          subject: "Math",
          due_label: "Due 10 Jul",
          due_date: "2026-07-10",
          delivered: 30,
          submitted: 22,
        },
      ],
    },
  ], captures);

  const result = await listTeacherHomeworkHistory(
    db,
    "org",
    "school",
    "teacher-1",
    { fromDate: "2026-07-01", toDate: "2026-07-31" },
    { page: 1, pageSize: 50 },
  );

  assertEquals(result.total, 1);
  assertEquals(result.items[0], {
    id: "hw-1",
    title: "Algebra",
    classLabel: "8-A",
    subject: "Math",
    dueLabel: "Due 10 Jul",
    dueDate: "2026-07-10",
    submittedCount: 22,
    totalCount: 30,
  });
  // teacher-scoped + the ISO range bound to the query
  const query = captures[0]!;
  assertEquals(query.args[2], "teacher-1");
  assertEquals(query.args[3], "2026-07-01");
  assertEquals(query.args[4], "2026-07-31");
});

// --- HWK-4: attachment reference rides the create payload ---

Deno.test("insertHomeworkAssignment carries the teacher attachment into both payloads", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    { match: "INSERT INTO teacher_entities", rows: [] },
    { match: "lower(display_name) = lower($3)", rows: [{ id: "stu-named" }] },
    { match: "INSERT INTO student_entities", rows: [] },
  ], captures);

  await insertHomeworkAssignment(db, {
    organizationId: "org",
    schoolId: "school",
    teacherId: "teacher-1",
    homeworkId: "hw_att",
    classLabel: "8-A",
    subject: "Math",
    title: "Algebra",
    dueLabel: "Due 10 Jul",
    dueDate: "2026-07-10",
    studentName: "Asha Rao",
    attachmentName: "worksheet.pdf",
    attachmentRef: "https://drive.example/xyz",
  });

  const teacherInsert = captures.find((c) =>
    c.sql.includes("INSERT INTO teacher_entities")
  );
  assert(teacherInsert!.sql.includes("'attachmentName'"));
  assertEquals(teacherInsert!.args[9], "worksheet.pdf");
  assertEquals(teacherInsert!.args[10], "https://drive.example/xyz");

  const studentInsert = captures.find((c) =>
    c.sql.includes("INSERT INTO student_entities")
  );
  assert(studentInsert!.sql.includes("'attachmentName'"));
  assertEquals(studentInsert!.args[8], "worksheet.pdf");
  assertEquals(studentInsert!.args[9], "https://drive.example/xyz");
});

// --- HWK-7: submit persists note + attachment reference ---

Deno.test("submitHomework persists notes + attachment_label on the submission", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    { match: "FROM student_entities", rows: [{ id: "hw-1" }] },
    { match: "INSERT INTO homework_submissions", rows: [{ id: "sub-1" }] },
  ], captures);

  await submitHomework(db, {
    organizationId: "org",
    schoolId: "school",
    studentId: "stu-1",
    homeworkId: "hw-1",
    notes: "Done, revised twice",
    attachmentLabel: "answer.jpg",
  });

  const insert = captures.find((c) =>
    c.sql.includes("INSERT INTO homework_submissions")
  );
  assert(insert, "expected the submission insert");
  assertEquals(insert!.args[4], "Done, revised twice"); // notes
  assertEquals(insert!.args[5], "answer.jpg"); // attachment_label
});

// --- HWK-3: multi-section fan-out target parsing (pure) ---

Deno.test("parseHomeworkClassLabels reads a class_labels array, trims + de-dupes", () => {
  assertEquals(
    parseHomeworkClassLabels({ class_labels: ["8-A", " 8-B ", "8-A", ""] }),
    ["8-A", "8-B"],
  );
});

Deno.test("parseHomeworkClassLabels falls back to a single class_label (back-compat)", () => {
  assertEquals(parseHomeworkClassLabels({ class_label: "9-C" }), ["9-C"]);
});

Deno.test("parseHomeworkClassLabels returns empty when nothing is targeted", () => {
  assertEquals(parseHomeworkClassLabels({}), []);
  assertEquals(parseHomeworkClassLabels({ class_label: "   " }), []);
});

// --- HWK-D1: notify fan-out enqueues one push per guardian of each non-submitter ---

Deno.test("notifyHomeworkNonSubmitters enqueues to every non-submitter's guardians", async () => {
  const captures: Capture[] = [];
  const db = mockDb([
    {
      match: "FROM student_entities se",
      rows: [
        { student_id: "stu-1", name: "Asha Rao" },
        { student_id: "stu-2", name: "Ravi Kumar" },
      ],
    },
    {
      // listGuardianUserIdsForStudent: stu-1 has 2 guardians, stu-2 has 1.
      match: "FROM student_guardians",
      rows: (args) =>
        String(args[2]) === "stu-1"
          ? [{ guardian_user_id: "g1" }, { guardian_user_id: "g2" }]
          : [{ guardian_user_id: "g3" }],
    },
  ], captures);

  const enqueued: string[] = [];
  const summary = await notifyHomeworkNonSubmitters(
    db,
    "org",
    "school",
    "hw-1",
    (guardianUserId) => {
      enqueued.push(guardianUserId);
      return Promise.resolve();
    },
  );

  assertEquals(summary.studentsPending, 2);
  assertEquals(summary.notificationsQueued, 3);
  assertEquals(enqueued.sort(), ["g1", "g2", "g3"]);
});

Deno.test("notifyHomeworkNonSubmitters queues nothing when everyone submitted", async () => {
  const captures: Capture[] = [];
  const db = mockDb([{ match: "FROM student_entities se", rows: [] }], captures);
  let called = false;
  const summary = await notifyHomeworkNonSubmitters(
    db,
    "org",
    "school",
    "hw-1",
    () => {
      called = true;
      return Promise.resolve();
    },
  );
  assertEquals(summary.studentsPending, 0);
  assertEquals(summary.notificationsQueued, 0);
  assertEquals(called, false);
});
