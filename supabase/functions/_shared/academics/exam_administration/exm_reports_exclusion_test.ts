// EXM-3/4/5 — reports EXCLUDE non-present (AB/ML/DB) rows from every statistic.
//
// 🔴 CRITICAL correctness rule (frozen): a row whose status != 'present'
// (marks_obtained IS NULL; codes AB/ML/DB) is EXCLUDED from totals, averages,
// percent, ranking, pass/fail and grade distribution, and only ever DISPLAYED
// via its status code. These tests drive the pure computation over a fake DB so
// the exclusion is proven WITHOUT a live tenant Postgres.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";
import {
  loadExamDistribution,
  loadExamToppers,
  loadMeritList,
  loadTabulationRegister,
} from "./exam_administration_repository.ts";

const ORG = "org-1";
const SCHOOL = "school-1";

interface FakeMark {
  student_id: string;
  student_code: string | null;
  student_name: string | null;
  roll_number: string | null;
  subject: string;
  marks_obtained: number | null;
  max_marks: number;
  status: string;
  grade_letter?: string | null;
}

// A fake DB whose queryObject dispatches on which report SQL is running. Each
// report's SQL has a distinctive fragment we key on.
class ReportDb {
  constructor(
    private marks: FakeMark[],
    private hasSession = true,
  ) {}
  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, _args: any[] = []): Promise<T[]> {
    // getExamSession lookup (used by toppers + distribution).
    if (
      sql.includes("FROM exam_sessions") &&
      sql.includes("AND id = $3") &&
      !sql.includes("exam_mark_entries")
    ) {
      return Promise.resolve(
        (this.hasSession
          ? [{ id: "exam-1", max_marks: 100, subject: "Mathematics" }]
          : []) as unknown as T[],
      );
    }
    // Tabulation register — joins entries to sessions, orders by exam.
    if (
      sql.includes("FROM exam_mark_entries m") &&
      sql.includes("JOIN exam_sessions es") &&
      sql.includes("es.subject AS subject")
    ) {
      return Promise.resolve(
        this.marks.map((m) => ({
          student_id: m.student_id,
          student_code: m.student_code,
          student_name: m.student_name,
          roll_number: m.roll_number,
          subject: m.subject,
          marks_obtained: m.marks_obtained,
          max_marks: m.max_marks,
          status: m.status,
          exam_updated_at: "2026-06-28T00:00:00Z",
        })) as unknown as T[],
      );
    }
    // Toppers — present-only filter already in SQL; the fake pre-filters too.
    if (
      sql.includes("FROM exam_mark_entries m") &&
      sql.includes("ORDER BY m.marks_obtained DESC")
    ) {
      const present = this.marks
        .filter((m) => m.status === "present" && m.marks_obtained != null)
        .sort((a, b) => (b.marks_obtained ?? 0) - (a.marks_obtained ?? 0));
      return Promise.resolve(present as unknown as T[]);
    }
    // Distribution — reads all marks_entered rows; exclusion is in the code.
    if (
      sql.includes("FROM exam_mark_entries m") &&
      sql.includes("m.grade_letter AS grade_letter")
    ) {
      return Promise.resolve(
        this.marks.map((m) => ({
          marks_obtained: m.marks_obtained,
          max_marks: m.max_marks,
          status: m.status,
          grade_letter: m.grade_letter ?? null,
        })) as unknown as T[],
      );
    }
    return Promise.resolve([] as T[]);
  }
}

function db(marks: FakeMark[]): TenantQueryClient {
  return new ReportDb(marks) as unknown as TenantQueryClient;
}

// A class of 3 students, one subject (Maths /100):
//   present 80, present 40, ABSENT (status=absent, marks null).
const CLASS_MARKS: FakeMark[] = [
  {
    student_id: "s1",
    student_code: "S1",
    student_name: "Aarav",
    roll_number: "01",
    subject: "Mathematics",
    marks_obtained: 80,
    max_marks: 100,
    status: "present",
    grade_letter: "A",
  },
  {
    student_id: "s2",
    student_code: "S2",
    student_name: "Priya",
    roll_number: "02",
    subject: "Mathematics",
    marks_obtained: 40,
    max_marks: 100,
    status: "present",
    grade_letter: "D",
  },
  {
    student_id: "s3",
    student_code: "S3",
    student_name: "Rohan",
    roll_number: "03",
    subject: "Mathematics",
    marks_obtained: null,
    max_marks: 100,
    status: "absent",
    grade_letter: null,
  },
];

Deno.test("EXM-3: tabulation EXCLUDES an absent student from total/percent/rank", async () => {
  const reg = await loadTabulationRegister(db(CLASS_MARKS), ORG, SCHOOL, "8-A", "Term 2");
  const rohan = reg.students.find((s) => s.studentId === "s3")!;
  // Absent row is shown via its status code, contributes nothing to totals.
  assertEquals(rohan.perSubject["Mathematics"].statusCode, "AB");
  assertEquals(rohan.perSubject["Mathematics"].marks, null);
  assertEquals(rohan.total, 0);
  assertEquals(rohan.totalMax, 0);
  // Not ranked — a fully-absent student is not in the ranked pool.
  assertEquals(rohan.rank, null);

  // Present students keep their totals; ranks are 1 & 2 (absent doesn't shift).
  const aarav = reg.students.find((s) => s.studentId === "s1")!;
  const priya = reg.students.find((s) => s.studentId === "s2")!;
  assertEquals(aarav.total, 80);
  assertEquals(aarav.rank, 1);
  assertEquals(priya.total, 40);
  assertEquals(priya.rank, 2);
});

Deno.test("EXM-4b: merit list omits the absent student and ranks present-only", async () => {
  const merit = await loadMeritList(db(CLASS_MARKS), ORG, SCHOOL, "8-A", "Term 2");
  // Only the 2 present students appear; the absent one is excluded entirely.
  assertEquals(merit.length, 2);
  assertEquals(merit.map((m) => m.studentId), ["s1", "s2"]);
  assertEquals(merit[0]!.rank, 1);
  assertEquals(merit[1]!.rank, 2);
});

Deno.test("EXM-4a: toppers never include an absent student", async () => {
  const toppers = await loadExamToppers(db(CLASS_MARKS), ORG, SCHOOL, "exam-1", 5);
  assertEquals(toppers.length, 2);
  assertEquals(toppers[0]!.studentId, "s1");
  assertEquals(toppers[0]!.marks, 80);
  // No absent student ever surfaces as a topper.
  assertEquals(toppers.some((t) => t.studentId === "s3"), false);
});

Deno.test("EXM-5: distribution counts PRESENT rows only; absent is excluded", async () => {
  const dist = await loadExamDistribution(db(CLASS_MARKS), ORG, SCHOOL, "exam-1");
  // 2 present (80 pass, 40 pass at 40% threshold), 1 absent excluded.
  assertEquals(dist.presentCount, 2);
  assertEquals(dist.excludedCount, 1);
  assertEquals(dist.passCount, 2);
  assertEquals(dist.failCount, 0);
  assertEquals(dist.passMarkPercent, 40);
  assertEquals(dist.passMarkSource, "default");
  const total = dist.gradeBreakdown.reduce((sum, g) => sum + g.count, 0);
  // Grade buckets total the PRESENT count — never the absent row.
  assertEquals(total, 2);
});

Deno.test("EXM-5: a present student below the pass mark fails; ML/DB excluded", async () => {
  const marks: FakeMark[] = [
    { ...CLASS_MARKS[0]!, marks_obtained: 30, grade_letter: "F" }, // fails
    { ...CLASS_MARKS[1]!, marks_obtained: 55, grade_letter: "C" }, // passes
    {
      student_id: "s4",
      student_code: "S4",
      student_name: "Meera",
      roll_number: "04",
      subject: "Mathematics",
      marks_obtained: null,
      max_marks: 100,
      status: "medical_leave",
      grade_letter: null,
    },
  ];
  const dist = await loadExamDistribution(db(marks), ORG, SCHOOL, "exam-1");
  assertEquals(dist.presentCount, 2);
  assertEquals(dist.excludedCount, 1); // ML excluded
  assertEquals(dist.passCount, 1);
  assertEquals(dist.failCount, 1);
});
