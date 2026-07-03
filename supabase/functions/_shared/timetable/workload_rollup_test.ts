// Roadmap gap #9 — unified per-teacher workload rollup (pure computation over a
// fake DB, no live Postgres). Proves:
//   • sections[] is FINALLY POPULATED (distinct sections per teacher) — the bug
//     the legacy rollup left as `sections: []` forever.
//   • subjectIds = union of scheduled subject labels + assignment catalog.
//   • over (>24) / under (<10) / balanced classification.
//   • school aggregate (totals + avgPeriods).
//   • honest zeros when no timetable exists.
//   • ONE reconciled overload threshold (24), superseding the subject-assignment 25.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  buildTeacherWorkloadRollup,
  classifyWorkload,
  UNIFIED_OVERLOAD_THRESHOLD,
  UNIFIED_UNDERLOAD_THRESHOLD,
} from "./workload_rollup.ts";
import { TEACHER_OVERLOAD_THRESHOLD } from "./timetable_workload.ts";

const ORG = "org-1";
const SCHOOL = "school-1";
const YEAR = "ay-1";

interface PeriodMeta {
  timetable_id: string;
  section_id: string;
  subject_label: string;
  teacher_id: string | null;
  teacher_assignment_id: string | null;
}
interface TeacherName {
  teacher_id: string;
  teacher_name: string;
}
interface TeacherSubject {
  teacher_user_id: string;
  subject_id: string;
}

/**
 * Fake DB that dispatches on a distinctive SQL fragment for each of the three
 * queries buildTeacherWorkloadRollup issues.
 */
class RollupDb {
  constructor(
    private periods: PeriodMeta[],
    private names: TeacherName[],
    private subjects: TeacherSubject[],
  ) {}
  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, _args: any[] = []): Promise<T[]> {
    if (sql.includes("FROM academic_timetable_periods p")) {
      return Promise.resolve(this.periods as unknown as T[]);
    }
    if (sql.includes("FROM teacher_assignments ta")) {
      return Promise.resolve(this.names as unknown as T[]);
    }
    if (sql.includes("FROM teacher_subject_assignments")) {
      return Promise.resolve(this.subjects as unknown as T[]);
    }
    throw new Error(`unexpected SQL: ${sql}`);
  }
}

function db(
  periods: PeriodMeta[],
  names: TeacherName[] = [],
  subjects: TeacherSubject[] = [],
): TenantQueryClient {
  return new RollupDb(periods, names, subjects) as unknown as TenantQueryClient;
}

/** Emit `n` scheduled periods for one teacher in a section (subject label fixed). */
function periodsFor(
  teacherId: string,
  sectionId: string,
  subjectLabel: string,
  n: number,
): PeriodMeta[] {
  return Array.from({ length: n }, () => ({
    timetable_id: `tt-${sectionId}`,
    section_id: sectionId,
    subject_label: subjectLabel,
    teacher_id: teacherId,
    teacher_assignment_id: `asg-${teacherId}-${sectionId}`,
  }));
}

Deno.test("the reconciled overload threshold is a single shared constant (24)", () => {
  assertEquals(UNIFIED_OVERLOAD_THRESHOLD, 24);
  assertEquals(UNIFIED_UNDERLOAD_THRESHOLD, 10);
  // It equals the legacy timetable threshold (they must never disagree).
  assertEquals(UNIFIED_OVERLOAD_THRESHOLD, TEACHER_OVERLOAD_THRESHOLD);
});

Deno.test("classifyWorkload: >24 over, <10 under, else balanced (boundaries)", () => {
  assertEquals(classifyWorkload(25), "over");
  assertEquals(classifyWorkload(24), "balanced"); // exactly 24 is NOT over
  assertEquals(classifyWorkload(10), "balanced"); // exactly 10 is NOT under
  assertEquals(classifyWorkload(9), "under");
  assertEquals(classifyWorkload(0), "under");
  // 25 periods would be "over" here even though computeSubjectWorkload's 25
  // threshold would call it NOT overloaded — the unified view supersedes it.
  assertEquals(classifyWorkload(25), "over");
});

Deno.test("sections[] is populated with the DISTINCT sections a teacher teaches", async () => {
  // Teacher T1 teaches across sections S1 (5 periods) and S2 (3 periods).
  const periods = [
    ...periodsFor("T1", "S1", "Mathematics", 5),
    ...periodsFor("T1", "S2", "Mathematics", 3),
  ];
  const { teachers } = await buildTeacherWorkloadRollup(db(periods), ORG, SCHOOL, YEAR);
  assertEquals(teachers.length, 1);
  const t1 = teachers[0]!;
  assertEquals(t1.teacherId, "T1");
  assertEquals(t1.periodCount, 8);
  // The legacy bug was `sections: []`; here it is the distinct, sorted set.
  assertEquals(t1.sections, ["S1", "S2"]);
});

Deno.test("subjectIds = union of scheduled labels + assignment catalog", async () => {
  // Scheduled: T1 teaches Mathematics in S1. Catalog also records Physics
  // (assigned but not yet timetabled) → subjectIds is the honest union.
  const periods = periodsFor("T1", "S1", "Mathematics", 4);
  const subjects: TeacherSubject[] = [{ teacher_user_id: "T1", subject_id: "Physics" }];
  const { teachers } = await buildTeacherWorkloadRollup(
    db(periods, [], subjects),
    ORG,
    SCHOOL,
    YEAR,
  );
  assertEquals(teachers[0]!.subjectIds, ["Mathematics", "Physics"]);
});

Deno.test("over / under / balanced classification + school aggregate", async () => {
  // T_OVER: 26 periods (>24) → over.
  // T_UNDER: 6 periods (<10) → under.
  // T_BAL: 15 periods → balanced.
  const periods = [
    ...periodsFor("T_OVER", "S1", "Mathematics", 26),
    ...periodsFor("T_UNDER", "S2", "English", 6),
    ...periodsFor("T_BAL", "S3", "Science", 15),
  ];
  const names: TeacherName[] = [
    { teacher_id: "T_OVER", teacher_name: "Over Teacher" },
    { teacher_id: "T_UNDER", teacher_name: "Under Teacher" },
    { teacher_id: "T_BAL", teacher_name: "Balanced Teacher" },
  ];
  const { teachers, summary } = await buildTeacherWorkloadRollup(
    db(periods, names),
    ORG,
    SCHOOL,
    YEAR,
  );

  // Sorted busiest-first.
  assertEquals(teachers.map((t) => t.teacherId), ["T_OVER", "T_BAL", "T_UNDER"]);

  const byId = new Map(teachers.map((t) => [t.teacherId, t]));
  assertEquals(byId.get("T_OVER")!.status, "over");
  assertEquals(byId.get("T_OVER")!.isOverloaded, true);
  assertEquals(byId.get("T_OVER")!.teacherName, "Over Teacher");
  assertEquals(byId.get("T_UNDER")!.status, "under");
  assertEquals(byId.get("T_UNDER")!.isOverloaded, false);
  assertEquals(byId.get("T_BAL")!.status, "balanced");
  assertEquals(byId.get("T_BAL")!.isOverloaded, false);

  assertEquals(summary.totalTeachers, 3);
  assertEquals(summary.overloaded, 1);
  assertEquals(summary.underloaded, 1);
  assertEquals(summary.balanced, 1);
  // (26 + 15 + 6) / 3 = 15.666… → rounded to 2dp.
  assertEquals(summary.avgPeriods, 15.67);
});

Deno.test("teacherName falls back to teacherId when no name row exists", async () => {
  const periods = periodsFor("T-nameless", "S1", "Mathematics", 12);
  const { teachers } = await buildTeacherWorkloadRollup(db(periods), ORG, SCHOOL, YEAR);
  assertEquals(teachers[0]!.teacherName, "T-nameless");
});

Deno.test("periods with a null teacher_id are ignored", async () => {
  const periods: PeriodMeta[] = [
    ...periodsFor("T1", "S1", "Mathematics", 5),
    // A free/unassigned slot: no teacher.
    {
      timetable_id: "tt-S1",
      section_id: "S1",
      subject_label: "Free",
      teacher_id: null,
      teacher_assignment_id: null,
    },
  ];
  const { teachers, summary } = await buildTeacherWorkloadRollup(
    db(periods),
    ORG,
    SCHOOL,
    YEAR,
  );
  assertEquals(teachers.length, 1);
  assertEquals(teachers[0]!.periodCount, 5);
  assertEquals(summary.totalTeachers, 1);
});

Deno.test("honest zeros when no timetable exists for the year", async () => {
  const { teachers, summary } = await buildTeacherWorkloadRollup(db([]), ORG, SCHOOL, YEAR);
  assertEquals(teachers, []);
  assertEquals(summary, {
    totalTeachers: 0,
    overloaded: 0,
    underloaded: 0,
    balanced: 0,
    avgPeriods: 0,
  });
});

Deno.test("exactly-24 periods is balanced, exactly-25 is over (threshold boundary)", async () => {
  const at24 = periodsFor("T24", "S1", "Mathematics", 24);
  const at25 = periodsFor("T25", "S2", "English", 25);
  const { teachers } = await buildTeacherWorkloadRollup(
    db([...at24, ...at25]),
    ORG,
    SCHOOL,
    YEAR,
  );
  const byId = new Map(teachers.map((t) => [t.teacherId, t]));
  assertEquals(byId.get("T24")!.status, "balanced");
  assertEquals(byId.get("T24")!.isOverloaded, false);
  assertEquals(byId.get("T25")!.status, "over");
  assertEquals(byId.get("T25")!.isOverloaded, true);
});
