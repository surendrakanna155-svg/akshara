// Roadmap gap #8 — persisted timetable substitutions (write-path unit tests).
//
// Fully in-memory: a hand-rolled mock TenantQueryClient answers the exact SQL
// the repository issues. Proves: create + idempotent re-assign (ON CONFLICT),
// SUBSTITUTE_BUSY 409, list-by-date shape, delete, and the on-leave derivation
// off mobile_leave_requests (the HR/staff leave source of truth).

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  createSubstitution,
  deleteSubstitution,
  isoDayOfWeek,
  listSubstitutions,
  listTeachersOnLeave,
  SubstitutionValidationError,
} from "./substitution_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const YEAR = "ce100000-0000-4000-8000-000000000001";
const CREATOR = "a3000000-0000-4000-8000-000000000001";
const TEACHER_MATH = "b0000000-0000-4000-8000-000000000001";
const TEACHER_ENG = "b0000000-0000-4000-8000-000000000002";
const SUB_A = "c0000000-0000-4000-8000-000000000001";
const SUB_B = "c0000000-0000-4000-8000-000000000002";

// 2026-07-06 is a Monday → ISO day 1.
const MONDAY = "2026-07-06";

type Row = Record<string, unknown>;

interface Period {
  id: string;
  timetable_id: string;
  organization_id: string;
  school_id: string;
  day_of_week: number;
  period_number: number;
  subject_label: string;
  teacher_id: string | null;
  teacher_assignment_id: string | null;
  room_label: string;
  section_id: string;
  academic_year_id: string;
  status: string;
}

interface Sub {
  id: string;
  organization_id: string;
  school_id: string;
  academic_year_id: string;
  period_id: string;
  sub_date: string;
  original_teacher_id: string | null;
  substitute_teacher_id: string | null;
  reason: string;
  created_by: string | null;
  created_at: string;
}

interface Leave {
  organization_id: string;
  school_id: string;
  requester_user_id: string;
  requester_scope: string;
  status: string;
  from_date: string | null;
  to_date: string | null;
  reason: string;
}

class MockDb {
  periods: Period[];
  subs: Sub[] = [];
  leaves: Leave[] = [];
  private seq = 0;

  constructor(periods: Period[]) {
    this.periods = periods;
  }

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // loadPeriodContext
    if (sql.includes("p.id AS period_id") && sql.includes("WHERE p.id = $1")) {
      const [periodId, orgId, schoolId] = args as string[];
      const p = this.periods.find(
        (x) => x.id === periodId && x.organization_id === orgId && x.school_id === schoolId,
      );
      if (!p) return [] as T[];
      return [{
        period_id: p.id,
        timetable_id: p.timetable_id,
        academic_year_id: p.academic_year_id,
        section_id: p.section_id,
        day_of_week: p.day_of_week,
        period_number: p.period_number,
        subject_label: p.subject_label,
        teacher_id: p.teacher_id,
        teacher_assignment_id: p.teacher_assignment_id,
        room_label: p.room_label,
      }] as T[];
    }

    // resolveGridForSlot (base_teacher_id + substitute join, filtered by day)
    if (sql.includes("p.teacher_id AS base_teacher_id")) {
      const [orgId, schoolId, yearId, subDate, dayOfWeek] = args as [
        string,
        string,
        string,
        string,
        number,
      ];
      return this.periods
        .filter(
          (p) =>
            p.organization_id === orgId &&
            p.school_id === schoolId &&
            p.academic_year_id === yearId &&
            p.status !== "archived" &&
            p.day_of_week === dayOfWeek,
        )
        .map((p) => {
          const s = this.subs.find((x) => x.period_id === p.id && x.sub_date === subDate);
          return {
            period_id: p.id,
            timetable_id: p.timetable_id,
            section_id: p.section_id,
            day_of_week: p.day_of_week,
            period_number: p.period_number,
            subject_label: p.subject_label,
            base_teacher_id: p.teacher_id,
            teacher_assignment_id: p.teacher_assignment_id,
            room_label: p.room_label,
            substitute_teacher_id: s?.substitute_teacher_id ?? null,
          };
        }) as T[];
    }

    // createSubstitution INSERT ... ON CONFLICT DO UPDATE
    if (sql.includes("INSERT INTO academic_timetable_substitutions")) {
      const [
        orgId,
        schoolId,
        yearId,
        periodId,
        subDate,
        originalTeacherId,
        substituteTeacherId,
        reason,
        createdBy,
      ] = args as [string, string, string, string, string, string | null, string, string, string];
      const existing = this.subs.find((x) => x.period_id === periodId && x.sub_date === subDate);
      if (existing) {
        existing.substitute_teacher_id = substituteTeacherId;
        existing.original_teacher_id = originalTeacherId;
        existing.reason = reason;
        existing.created_by = createdBy;
        return [{ ...existing }] as T[];
      }
      const row: Sub = {
        id: `s${++this.seq}`,
        organization_id: orgId,
        school_id: schoolId,
        academic_year_id: yearId,
        period_id: periodId,
        sub_date: subDate,
        original_teacher_id: originalTeacherId,
        substitute_teacher_id: substituteTeacherId,
        reason,
        created_by: createdBy,
        created_at: "2026-07-05T00:00:00.000Z",
      };
      this.subs.push(row);
      return [{ ...row }] as T[];
    }

    // listSubstitutions (join to period + timetable)
    if (sql.includes("FROM academic_timetable_substitutions s") && sql.includes("s.sub_date = $3")) {
      const [orgId, schoolId, date] = args as string[];
      return this.subs
        .filter(
          (s) => s.organization_id === orgId && s.school_id === schoolId && s.sub_date === date,
        )
        .map((s) => {
          const p = this.periods.find((x) => x.id === s.period_id)!;
          return {
            id: s.id,
            period_id: s.period_id,
            sub_date: s.sub_date,
            timetable_id: p.timetable_id,
            section_id: p.section_id,
            day_of_week: p.day_of_week,
            period_number: p.period_number,
            subject_label: p.subject_label,
            original_teacher_id: s.original_teacher_id,
            substitute_teacher_id: s.substitute_teacher_id,
            reason: s.reason,
            room_label: p.room_label,
          };
        }) as T[];
    }

    // deleteSubstitution
    if (sql.includes("DELETE FROM academic_timetable_substitutions")) {
      const [id, orgId, schoolId] = args as string[];
      const idx = this.subs.findIndex(
        (s) => s.id === id && s.organization_id === orgId && s.school_id === schoolId,
      );
      if (idx === -1) return [] as T[];
      const [removed] = this.subs.splice(idx, 1);
      return [{ ...removed }] as T[];
    }

    // listTeachersOnLeave
    if (sql.includes("FROM mobile_leave_requests")) {
      const [orgId, schoolId, date] = args as string[];
      return this.leaves
        .filter(
          (l) =>
            l.organization_id === orgId &&
            l.school_id === schoolId &&
            l.requester_scope === "teacher" &&
            l.status === "approved" &&
            l.from_date !== null &&
            l.to_date !== null &&
            l.from_date <= date &&
            l.to_date >= date,
        )
        .map((l) => ({
          requester_user_id: l.requester_user_id,
          from_date: l.from_date,
          to_date: l.to_date,
          reason: l.reason,
        })) as T[];
    }

    throw new Error(`Unhandled SQL in MockDb: ${sql.slice(0, 80)}`);
  }
}

function period(over: Partial<Period> = {}): Period {
  return {
    id: "p-math-mon-1",
    timetable_id: "tt-section-a",
    organization_id: ORG,
    school_id: SCHOOL,
    day_of_week: 1,
    period_number: 1,
    subject_label: "Mathematics",
    teacher_id: TEACHER_MATH,
    teacher_assignment_id: "ta-1",
    room_label: "Room 8A",
    section_id: "sec-a",
    academic_year_id: YEAR,
    status: "published",
    ...over,
  };
}

function asDb(mock: MockDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

Deno.test("isoDayOfWeek maps calendar dates to 1..7 (Mon..Sun)", () => {
  assertEquals(isoDayOfWeek("2026-07-06"), 1); // Monday
  assertEquals(isoDayOfWeek("2026-07-11"), 6); // Saturday
  assertEquals(isoDayOfWeek("2026-07-12"), 7); // Sunday
});

Deno.test("createSubstitution persists a substitution and stores the original teacher", async () => {
  const mock = new MockDb([period()]);
  const created = await createSubstitution(asDb(mock), {
    orgId: ORG,
    schoolId: SCHOOL,
    periodId: "p-math-mon-1",
    subDate: MONDAY,
    substituteTeacherId: SUB_A,
    reason: "Teacher on leave",
    createdBy: CREATOR,
  });
  assertEquals(created.substitute_teacher_id, SUB_A);
  assertEquals(created.original_teacher_id, TEACHER_MATH);
  assertEquals(created.sub_date, MONDAY);
  assertEquals(mock.subs.length, 1);
});

Deno.test("createSubstitution is idempotent: same (period, date) re-assigns in place", async () => {
  const mock = new MockDb([period()]);
  await createSubstitution(asDb(mock), {
    orgId: ORG,
    schoolId: SCHOOL,
    periodId: "p-math-mon-1",
    subDate: MONDAY,
    substituteTeacherId: SUB_A,
    createdBy: CREATOR,
  });
  const reassigned = await createSubstitution(asDb(mock), {
    orgId: ORG,
    schoolId: SCHOOL,
    periodId: "p-math-mon-1",
    subDate: MONDAY,
    substituteTeacherId: SUB_B,
    createdBy: CREATOR,
  });
  assertEquals(mock.subs.length, 1, "no duplicate row for same period+date");
  assertEquals(reassigned.substitute_teacher_id, SUB_B);
});

Deno.test("createSubstitution rejects a busy substitute with SUBSTITUTE_BUSY (409)", async () => {
  // Two sections both meet Monday period 1. The substitute already teaches the
  // English section that slot → assigning them to the Math section double-books.
  const mathPeriod = period({ id: "p-math-mon-1", section_id: "sec-a", timetable_id: "tt-a" });
  const engPeriod = period({
    id: "p-eng-mon-1",
    section_id: "sec-b",
    timetable_id: "tt-b",
    subject_label: "English",
    teacher_id: SUB_A, // the proposed substitute already teaches here this slot
    room_label: "Room 8B",
  });
  const mock = new MockDb([mathPeriod, engPeriod]);

  const err = await assertRejects(
    () =>
      createSubstitution(asDb(mock), {
        orgId: ORG,
        schoolId: SCHOOL,
        periodId: "p-math-mon-1",
        subDate: MONDAY,
        substituteTeacherId: SUB_A,
        createdBy: CREATOR,
      }),
    SubstitutionValidationError,
    "already teaching",
  );
  assertEquals((err as SubstitutionValidationError).code, "SUBSTITUTE_BUSY");
  assertEquals((err as SubstitutionValidationError).httpStatus, 409);
  assertEquals(mock.subs.length, 0, "no row written on a rejected busy substitute");
});

Deno.test("createSubstitution allows a substitute free that slot even if busy another day", async () => {
  const mathPeriod = period({ id: "p-math-mon-1", timetable_id: "tt-a" });
  // Substitute teaches Tuesday (day 2), not Monday — no clash for a Monday sub.
  const otherDay = period({
    id: "p-eng-tue-1",
    section_id: "sec-b",
    timetable_id: "tt-b",
    day_of_week: 2,
    teacher_id: SUB_A,
  });
  const mock = new MockDb([mathPeriod, otherDay]);
  const created = await createSubstitution(asDb(mock), {
    orgId: ORG,
    schoolId: SCHOOL,
    periodId: "p-math-mon-1",
    subDate: MONDAY,
    substituteTeacherId: SUB_A,
    createdBy: CREATOR,
  });
  assertEquals(created.substitute_teacher_id, SUB_A);
});

Deno.test("createSubstitution 404s when the period is not in this org/school", async () => {
  const mock = new MockDb([period({ school_id: "other-school" })]);
  const err = await assertRejects(
    () =>
      createSubstitution(asDb(mock), {
        orgId: ORG,
        schoolId: SCHOOL,
        periodId: "p-math-mon-1",
        subDate: MONDAY,
        substituteTeacherId: SUB_A,
        createdBy: CREATOR,
      }),
    SubstitutionValidationError,
  );
  assertEquals((err as SubstitutionValidationError).httpStatus, 404);
});

Deno.test("createSubstitution rejects a malformed subDate (422)", async () => {
  const mock = new MockDb([period()]);
  const err = await assertRejects(
    () =>
      createSubstitution(asDb(mock), {
        orgId: ORG,
        schoolId: SCHOOL,
        periodId: "p-math-mon-1",
        subDate: "not-a-date",
        substituteTeacherId: SUB_A,
        createdBy: CREATOR,
      }),
    SubstitutionValidationError,
  );
  assertEquals((err as SubstitutionValidationError).httpStatus, 422);
});

Deno.test("listSubstitutions returns the resolved-grid shape for a date", async () => {
  const mock = new MockDb([period()]);
  await createSubstitution(asDb(mock), {
    orgId: ORG,
    schoolId: SCHOOL,
    periodId: "p-math-mon-1",
    subDate: MONDAY,
    substituteTeacherId: SUB_A,
    reason: "Sick leave",
    createdBy: CREATOR,
  });
  const list = await listSubstitutions(asDb(mock), ORG, SCHOOL, { date: MONDAY });
  assertEquals(list.length, 1);
  const row = list[0];
  assertEquals(row.periodId, "p-math-mon-1");
  assertEquals(row.subDate, MONDAY);
  assertEquals(row.sectionId, "sec-a");
  assertEquals(row.dayOfWeek, 1);
  assertEquals(row.periodNumber, 1);
  assertEquals(row.subjectLabel, "Mathematics");
  assertEquals(row.originalTeacherId, TEACHER_MATH);
  assertEquals(row.substituteTeacherId, SUB_A);
  assertEquals(row.reason, "Sick leave");
  assertEquals(row.roomLabel, "Room 8A");

  // A different date has no substitutions.
  assertEquals((await listSubstitutions(asDb(mock), ORG, SCHOOL, { date: "2026-07-07" })).length, 0);
});

Deno.test("deleteSubstitution removes the row and returns it; missing id returns null", async () => {
  const mock = new MockDb([period()]);
  const created = await createSubstitution(asDb(mock), {
    orgId: ORG,
    schoolId: SCHOOL,
    periodId: "p-math-mon-1",
    subDate: MONDAY,
    substituteTeacherId: SUB_A,
    createdBy: CREATOR,
  });
  const removed = await deleteSubstitution(asDb(mock), ORG, SCHOOL, created.id);
  assertEquals(removed?.id, created.id);
  assertEquals(mock.subs.length, 0);
  assertEquals(await deleteSubstitution(asDb(mock), ORG, SCHOOL, "does-not-exist"), null);
});

Deno.test("listTeachersOnLeave derives approved teacher leaves covering the date", async () => {
  const mock = new MockDb([period()]);
  mock.leaves = [
    // Covers Monday → matches.
    {
      organization_id: ORG,
      school_id: SCHOOL,
      requester_user_id: TEACHER_MATH,
      requester_scope: "teacher",
      status: "approved",
      from_date: "2026-07-05",
      to_date: "2026-07-08",
      reason: "Fever",
    },
    // Approved but window ends before Monday → no match.
    {
      organization_id: ORG,
      school_id: SCHOOL,
      requester_user_id: TEACHER_ENG,
      requester_scope: "teacher",
      status: "approved",
      from_date: "2026-07-01",
      to_date: "2026-07-03",
      reason: "Old",
    },
    // Pending (not approved) → excluded.
    {
      organization_id: ORG,
      school_id: SCHOOL,
      requester_user_id: SUB_A,
      requester_scope: "teacher",
      status: "pending",
      from_date: "2026-07-05",
      to_date: "2026-07-08",
      reason: "Not yet approved",
    },
    // Parent-scope leave → excluded (not a teacher).
    {
      organization_id: ORG,
      school_id: SCHOOL,
      requester_user_id: SUB_B,
      requester_scope: "parent",
      status: "approved",
      from_date: "2026-07-05",
      to_date: "2026-07-08",
      reason: "Parent leave",
    },
    // Legacy label-only (null dates) → never matches.
    {
      organization_id: ORG,
      school_id: SCHOOL,
      requester_user_id: "b0000000-0000-4000-8000-000000000009",
      requester_scope: "teacher",
      status: "approved",
      from_date: null,
      to_date: null,
      reason: "Legacy",
    },
  ];

  const onLeave = await listTeachersOnLeave(asDb(mock), ORG, SCHOOL, MONDAY);
  assertEquals(onLeave.length, 1);
  assertEquals(onLeave[0].teacherId, TEACHER_MATH);
  assertEquals(onLeave[0].reason, "Fever");
});
