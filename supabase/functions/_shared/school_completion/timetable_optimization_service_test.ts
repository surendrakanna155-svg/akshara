import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  analyzeTimetableOptimization,
  applyTimetableOptimization,
  computeQualityScore,
} from "./timetable_optimization_service.ts";

Deno.test("computeQualityScore penalizes conflicts and overload", () => {
  assertEquals(
    computeQualityScore({ conflictCount: 0, overloadCount: 0, gapCount: 0, timetableCount: 5 }),
    100,
  );
  assertEquals(
    computeQualityScore({ conflictCount: 2, overloadCount: 1, gapCount: 3, timetableCount: 5 }),
    54,
  );
  assertEquals(
    computeQualityScore({ conflictCount: 0, overloadCount: 0, gapCount: 0, timetableCount: 0 }),
    0,
  );
});

// P0-2 (gap-remediation wave) — end-to-end MockDb coverage for
// applyTimetableOptimization: an overloaded teacher should get a genuinely
// actionable ("redistribute_workload") recommendation, and applying it must
// perform a REAL write (via reassignTimetablePeriodTeacher) that a follow-up
// analysis actually reflects — not an echoed no-op.

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const YEAR = "ce100000-0000-4000-8000-000000000001";
const TEACHER_A = "b0000000-0000-4000-8000-00000000000a";
const TEACHER_B = "b0000000-0000-4000-8000-00000000000b";

interface Period {
  id: string;
  organization_id: string;
  school_id: string;
  academic_year_id: string;
  timetable_id: string;
  section_id: string;
  day_of_week: number;
  period_number: number;
  subject_label: string;
  teacher_id: string | null;
  teacher_assignment_id: string | null;
  room_label: string;
  status: string;
}

interface UserRow {
  id: string;
  display_name: string;
  phone: string;
}

class OptimizationMockDb {
  updated: Array<{ id: string; teacherId: string }> = [];
  constructor(public periods: Period[], public users: UserRow[]) {}

  private timetableRows() {
    const map = new Map<string, { id: string; section_id: string; status: string }>();
    for (const p of this.periods) {
      if (!map.has(p.timetable_id)) {
        map.set(p.timetable_id, { id: p.timetable_id, section_id: p.section_id, status: p.status });
      }
    }
    return [...map.values()];
  }

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // analyzeTimetableOptimization: timetables list.
    if (sql.includes("SELECT id, section_id, status")) {
      const [orgId, schoolId, yearId] = args as string[];
      return this.timetableRows()
        .filter((t) => {
          const p = this.periods.find((x) => x.timetable_id === t.id)!;
          return p.organization_id === orgId && p.school_id === schoolId && p.academic_year_id === yearId;
        }) as T[];
    }

    // analyzeTimetableOptimization: periods.
    if (sql.includes("tp.timetable_id, tp.day_of_week")) {
      const [orgId, schoolId, yearId] = args as string[];
      return this.periods
        .filter((p) =>
          p.organization_id === orgId && p.school_id === schoolId && p.academic_year_id === yearId &&
          p.status !== "archived"
        )
        .map((p) => ({
          timetable_id: p.timetable_id,
          day_of_week: p.day_of_week,
          period_number: p.period_number,
          teacher_id: p.teacher_id,
          room_label: p.room_label,
          subject_label: p.subject_label,
        })) as T[];
    }

    // analyzeTimetableOptimization: teacher display names.
    if (sql.includes("JOIN school_memberships sm ON sm.user_id = u.id") && sql.includes("sm.school_id = $1")) {
      return this.users.map((u) => ({ id: u.id, display_name: u.display_name })) as T[];
    }

    // rebalanceOneTeacherPeriod: movable periods for the overloaded teacher.
    if (sql.includes("p.id AS period_id, p.subject_label, t.status")) {
      const [orgId, schoolId, yearId, teacherId] = args as string[];
      return this.periods
        .filter((p) =>
          p.organization_id === orgId && p.school_id === schoolId && p.academic_year_id === yearId &&
          p.status !== "archived" && p.teacher_id === teacherId
        )
        .sort((a, b) => b.day_of_week - a.day_of_week || b.period_number - a.period_number)
        .map((p) => ({ period_id: p.id, subject_label: p.subject_label, status: p.status })) as T[];
    }

    // rebalanceOneTeacherPeriod: other-teacher weekly workload.
    if (sql.includes("count(*)::int AS cnt")) {
      const [orgId, schoolId, yearId, excludeTeacherId] = args as string[];
      const counts = new Map<string, number>();
      for (const p of this.periods) {
        if (
          p.organization_id === orgId && p.school_id === schoolId && p.academic_year_id === yearId &&
          p.status !== "archived" && p.teacher_id && p.teacher_id !== excludeTeacherId
        ) {
          counts.set(p.teacher_id, (counts.get(p.teacher_id) ?? 0) + 1);
        }
      }
      return [...counts.entries()].map(([teacher_id, cnt]) => ({ teacher_id, cnt })) as T[];
    }

    // rebalanceOneTeacherPeriod: subject-qualified other teachers.
    if (sql.includes("SELECT DISTINCT p.teacher_id")) {
      const [orgId, schoolId, yearId, excludeTeacherId, subjectLabel] = args as string[];
      const ids = new Set(
        this.periods
          .filter((p) =>
            p.organization_id === orgId && p.school_id === schoolId && p.academic_year_id === yearId &&
            p.status !== "archived" && p.teacher_id !== excludeTeacherId && p.subject_label === subjectLabel
          )
          .map((p) => p.teacher_id),
      );
      return [...ids].map((teacher_id) => ({ teacher_id })) as T[];
    }

    // reassignTimetablePeriodTeacher: load current period + parent timetable.
    if (sql.includes("t.status, t.section_id") && sql.includes("WHERE p.id = $1")) {
      const [id, orgId, schoolId] = args as string[];
      const p = this.periods.find((x) => x.id === id && x.organization_id === orgId && x.school_id === schoolId);
      if (!p) return [] as T[];
      return [{
        id: p.id,
        timetable_id: p.timetable_id,
        academic_year_id: p.academic_year_id,
        status: p.status,
        section_id: p.section_id,
        day_of_week: p.day_of_week,
        period_number: p.period_number,
        subject_label: p.subject_label,
        teacher_id: p.teacher_id,
        teacher_assignment_id: p.teacher_assignment_id,
        room_label: p.room_label,
      }] as T[];
    }

    // reassignTimetablePeriodTeacher: clash re-check (loadSchoolPeriodsWithMeta).
    if (sql.includes("t.id AS timetable_id, t.section_id")) {
      const [orgId, schoolId, yearId] = args as string[];
      return this.periods
        .filter((p) =>
          p.organization_id === orgId && p.school_id === schoolId && p.academic_year_id === yearId &&
          p.status !== "archived"
        )
        .map((p) => ({
          timetable_id: p.timetable_id,
          section_id: p.section_id,
          day_of_week: p.day_of_week,
          period_number: p.period_number,
          subject_label: p.subject_label,
          teacher_id: p.teacher_id,
          teacher_assignment_id: p.teacher_assignment_id,
          room_label: p.room_label,
        })) as T[];
    }

    // reassignTimetablePeriodTeacher: the write.
    if (sql.includes("SET teacher_id = $4")) {
      const [id, _org, _school, teacherId] = args as [string, string, string, string];
      const p = this.periods.find((x) => x.id === id)!;
      p.teacher_id = teacherId;
      this.updated.push({ id, teacherId });
      return [{
        id: p.id,
        timetable_id: p.timetable_id,
        day_of_week: p.day_of_week,
        period_number: p.period_number,
        subject_label: p.subject_label,
        teacher_id: p.teacher_id,
        teacher_assignment_id: p.teacher_assignment_id,
        room_label: p.room_label,
      }] as T[];
    }

    throw new Error(`Unhandled SQL in OptimizationMockDb: ${sql.slice(0, 90)}`);
  }
}

function buildFixture(): OptimizationMockDb {
  const periods: Period[] = [];
  // Teacher A: 25 Math periods (day 1-5 x period 1-5) → overloaded (> 24).
  for (let day = 1; day <= 5; day++) {
    for (let num = 1; num <= 5; num++) {
      periods.push({
        id: `a-${day}-${num}`,
        organization_id: ORG,
        school_id: SCHOOL,
        academic_year_id: YEAR,
        timetable_id: "tt-a",
        section_id: "sec-a",
        day_of_week: day,
        period_number: num,
        subject_label: "Math",
        teacher_id: TEACHER_A,
        teacher_assignment_id: null,
        room_label: "Room A",
        status: "validated",
      });
    }
  }
  // Teacher B: 1 Math period at a slot Teacher A never uses → lightest,
  // subject-qualified rebalance target.
  periods.push({
    id: "b-1-6",
    organization_id: ORG,
    school_id: SCHOOL,
    academic_year_id: YEAR,
    timetable_id: "tt-b",
    section_id: "sec-b",
    day_of_week: 1,
    period_number: 6,
    subject_label: "Math",
    teacher_id: TEACHER_B,
    teacher_assignment_id: null,
    room_label: "Room B",
    status: "validated",
  });
  const users: UserRow[] = [
    { id: TEACHER_A, display_name: "Teacher A", phone: "+910000000001" },
    { id: TEACHER_B, display_name: "Teacher B", phone: "+910000000002" },
  ];
  return new OptimizationMockDb(periods, users);
}

function asDb(mock: OptimizationMockDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

Deno.test("analyzeTimetableOptimization emits an actionable redistribute_workload recommendation for an overloaded teacher", async () => {
  const mock = buildFixture();
  const result = await analyzeTimetableOptimization(asDb(mock), ORG, SCHOOL, YEAR);
  assertEquals(result.overloadAlerts.length, 1);
  assertEquals(result.overloadAlerts[0]!.teacherId, TEACHER_A);

  const actionable = result.recommendations.filter((r) => !r.readOnly);
  assertEquals(actionable.length, 1);
  assertEquals(actionable[0]!.recommendationId, `rebalance_${TEACHER_A}`);
  assertEquals(actionable[0]!.kind, "redistribute_workload");
});

Deno.test("applyTimetableOptimization with no matching ids applies nothing", async () => {
  const mock = buildFixture();
  const result = await applyTimetableOptimization(asDb(mock), ORG, SCHOOL, YEAR, ["not_a_real_id"], false);
  assertEquals(result.appliedRecommendationIds, []);
  assertEquals(result.appliedCount, 0);
  assertEquals(result.message, "No actionable recommendations selected.");
  assertEquals(mock.updated.length, 0);
});

Deno.test("applyTimetableOptimization(applyAll) moves a real period off the overloaded teacher and the re-analysis reflects it", async () => {
  const mock = buildFixture();
  const before = await analyzeTimetableOptimization(asDb(mock), ORG, SCHOOL, YEAR);
  assertEquals(before.overloadAlerts.length, 1);

  const result = await applyTimetableOptimization(asDb(mock), ORG, SCHOOL, YEAR, [], true);
  assertEquals(result.appliedRecommendationIds, [`rebalance_${TEACHER_A}`]);
  assertEquals(result.appliedCount, 1);
  assertEquals(mock.updated.length, 1, "exactly one real period reassignment was written");

  // The moved period now belongs to Teacher B, so Teacher A drops to 24
  // periods (no longer > the 24 overload threshold) — a genuine state change,
  // not an echo of the pre-apply numbers.
  const after = await analyzeTimetableOptimization(asDb(mock), ORG, SCHOOL, YEAR);
  assertEquals(after.overloadAlerts.length, 0);
  assertEquals(result.updatedConflictCount, after.conflictCount);
  assertEquals(result.updatedQualityScore, after.qualityScore);
});

Deno.test("applyTimetableOptimization only applies requested ids when applyAll is false", async () => {
  const mock = buildFixture();
  const result = await applyTimetableOptimization(
    asDb(mock),
    ORG,
    SCHOOL,
    YEAR,
    [`rebalance_${TEACHER_A}`],
    false,
  );
  assertEquals(result.appliedRecommendationIds, [`rebalance_${TEACHER_A}`]);
  assertEquals(mock.updated.length, 1);
});
