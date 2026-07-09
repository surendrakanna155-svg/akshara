// P0-1 (gap-remediation wave) — student scope must NOT 404 for a real student
// with no seeded `student_entities` row. The parent sibling already falls back
// to a default snapshot built from real `students`/`sis_student_enrollments`
// rows (resolveParentSnapshot -> buildDefaultParentSnapshot); the student scope
// was missing the same fallback, so a real student got a hard 404 on
// dashboard/attendance/exams/timetable/profile.
//
// This file proves, DB-free (mock TenantQueryClient, no live Postgres):
//   1. resolveStudentSnapshot returns the REAL store row untouched when one
//      exists (fallback never triggers for a seeded row).
//   2. resolveStudentSnapshot builds a POPULATED default (never throws / never
//      surfaces SnapshotNotFoundError) for a student with no seeded row, for
//      every entity type the student app reads.
//   3. A non-SnapshotNotFoundError from the store still propagates (the
//      fallback must not swallow real errors).
//   4. buildDefaultStudentSnapshot's default shapes match the EXACT keys
//      lib/core/repositories/api/student/mapper/student_mapper.dart reads —
//      this is also the P2 seed-contract fix (rollNo not rollNumber; the
//      dashboard/profile fields the old seed never carried at all).
//   5. loadStudentSnapshotContext resolves real name/class/roll-number from
//      students + sis_student_enrollments (and degrades gracefully — not an
//      error — when the profile/guardian rows are RLS-invisible or absent).

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { createStudentScopedEntityReadStore } from "./student_scoped_entity_read_store.ts";
import { resolveStudentSnapshot } from "./mobile_read_handlers.ts";
import {
  buildDefaultStudentSnapshot,
  loadStudentSnapshotContext,
  type StudentSnapshotContext,
} from "../pilot/pilot_operations_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const STUDENT = "a4000000-0000-4000-8000-000000000009"; // a REAL student — no demo seed row

const studentStore = createStudentScopedEntityReadStore("student_entities", "Student");

/**
 * Combined mock covering every query resolveStudentSnapshot's full path can
 * issue: the student_entities snapshot lookup (student_scoped_entity_read_store),
 * and — on a miss — the students/sis_student_enrollments/student_profiles
 * context join, the schools lookup, and the student_guardians/users lookup
 * (pilot_operations_repository.loadStudentSnapshotContext).
 */
class MockStudentContextDb {
  constructor(
    private readonly opts: {
      snapshotRow?: Record<string, unknown>;
      studentRow?: {
        display_name: string;
        class_name: string | null;
        section_name: string | null;
        roll_number: string | null;
        admission_number: string | null;
        date_of_birth: string | null;
        blood_group: string | null;
      };
      schoolName?: string;
      guardians?: Array<
        { name: string; relation: string; phone: string | null; email: string | null }
      >;
    } = {},
  ) {}

  // deno-lint-ignore no-explicit-any
  async queryObject<T>(sql: string, _args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM student_entities")) {
      return this.opts.snapshotRow
        ? [{ payload: this.opts.snapshotRow }] as unknown as T[]
        : [] as T[];
    }
    if (sql.includes("FROM students s")) {
      return this.opts.studentRow ? [this.opts.studentRow] as unknown as T[] : [] as T[];
    }
    if (sql.includes("FROM schools WHERE id")) {
      return this.opts.schoolName
        ? [{ name: this.opts.schoolName }] as unknown as T[]
        : [] as T[];
    }
    if (sql.includes("FROM student_guardians sg")) {
      return (this.opts.guardians ?? []) as unknown as T[];
    }
    throw new Error(`MockStudentContextDb: unexpected query: ${sql}`);
  }
}

Deno.test("resolveStudentSnapshot returns the real snapshot untouched when a row exists (no fallback)", async () => {
  const db = new MockStudentContextDb({
    snapshotRow: { studentName: "Ravi Kumar", classLabel: "8-A", unreadNotifications: 2 },
  }) as unknown as TenantQueryClient;

  const snapshot = await resolveStudentSnapshot(
    studentStore,
    db,
    ORG,
    SCHOOL,
    STUDENT,
    "snapshot_dashboard",
  );

  assertEquals(snapshot.studentName, "Ravi Kumar");
  assertEquals(snapshot.unreadNotifications, 2);
});

for (
  const entityType of [
    "snapshot_dashboard",
    "snapshot_attendance",
    "snapshot_exams",
    "snapshot_timetable",
    "snapshot_profile",
  ] as const
) {
  Deno.test(`resolveStudentSnapshot(${entityType}): no seeded row -> populated default, NOT a 404/error`, async () => {
    const db = new MockStudentContextDb({
      // no snapshotRow => store.getSnapshot throws SnapshotNotFoundError
      studentRow: {
        display_name: "Anita Rao",
        class_name: "6",
        section_name: "B",
        roll_number: "12",
        admission_number: "ADM-0099",
        date_of_birth: "2014-05-02",
        blood_group: "O+",
      },
      schoolName: "Akshara Public School",
      guardians: [
        { name: "Rao Kumar", relation: "father", phone: "9800000000", email: "rao@example.com" },
      ],
    }) as unknown as TenantQueryClient;

    const snapshot = await resolveStudentSnapshot(
      studentStore,
      db,
      ORG,
      SCHOOL,
      STUDENT,
      entityType,
    );

    // The core P0: this must be a plain object, never a thrown NOT_FOUND.
    assertEquals(typeof snapshot, "object");
    assertEquals(snapshot.studentName, "Anita Rao");
    assertEquals(snapshot.classLabel, "6-B");
  });
}

Deno.test("resolveStudentSnapshot: a real (non-SnapshotNotFoundError) failure still propagates", async () => {
  const boom = new Error("connection reset");
  const throwingStore = createStudentScopedEntityReadStore("student_entities", "Student");
  const db = {
    queryObject: () => {
      throw boom;
    },
  } as unknown as TenantQueryClient;

  await assertRejects(
    () => resolveStudentSnapshot(throwingStore, db, ORG, SCHOOL, STUDENT, "snapshot_dashboard"),
    Error,
    "connection reset",
  );
});

Deno.test("buildDefaultStudentSnapshot(snapshot_dashboard): matches student_mapper.dart's StudentDashboardData keys", () => {
  const context: StudentSnapshotContext = {
    studentName: "Ravi Kumar",
    classLabel: "8-A",
    rollNo: "23",
    admissionNo: "ADM-0001",
    dateOfBirth: "2012-01-01",
    bloodGroup: "B+",
    schoolName: "Akshara Public School",
    parentContacts: [],
  };
  const snapshot = buildDefaultStudentSnapshot("snapshot_dashboard", context);

  assertEquals(snapshot.studentName, "Ravi Kumar");
  assertEquals(snapshot.classLabel, "8-A");
  assertEquals(Array.isArray(snapshot.todaySchedule), true);
  assertEquals(typeof snapshot.attendanceKpi, "object");
  assertEquals(Array.isArray(snapshot.homeworkDue), true);
  assertEquals(typeof snapshot.examReminder, "object");
  assertEquals(Array.isArray(snapshot.quickActions), true);
  assertEquals(typeof snapshot.aiInsight, "object");
  assertEquals(typeof snapshot.greetingHeadline, "string");
  assertEquals(typeof snapshot.greetingSubtitle, "string");
  assertEquals(snapshot.unreadNotifications, 0);
});

Deno.test("buildDefaultStudentSnapshot(snapshot_attendance): matches AttendanceMonthData keys", () => {
  const context: StudentSnapshotContext = {
    studentName: "Ravi Kumar",
    classLabel: "8-A",
    rollNo: "",
    admissionNo: "",
    dateOfBirth: "",
    bloodGroup: "",
    schoolName: "",
    parentContacts: [],
  };
  const snapshot = buildDefaultStudentSnapshot("snapshot_attendance", context);

  assertEquals(typeof snapshot.month, "string");
  assertEquals(typeof snapshot.kpi, "object");
  assertEquals(Array.isArray(snapshot.calendarDays), true);
  assertEquals(Array.isArray(snapshot.recentLogs), true);
  // childName/childClass are what overlayAttendanceSnapshotFromRecords reads
  // (`snapshot.childClass ?? snapshot.classLabel`) for the class-teacher lookup.
  assertEquals(snapshot.childName, "Ravi Kumar");
  assertEquals(snapshot.childClass, "8-A");
});

Deno.test("buildDefaultStudentSnapshot(snapshot_exams): matches StudentExamsData keys", () => {
  const context: StudentSnapshotContext = {
    studentName: "Ravi Kumar",
    classLabel: "8-A",
    rollNo: "",
    admissionNo: "",
    dateOfBirth: "",
    bloodGroup: "",
    schoolName: "",
    parentContacts: [],
  };
  const snapshot = buildDefaultStudentSnapshot("snapshot_exams", context);

  assertEquals(snapshot.studentName, "Ravi Kumar");
  assertEquals(snapshot.classLabel, "8-A");
  assertEquals(snapshot.averagePercent, 0);
  assertEquals(Array.isArray(snapshot.upcomingExams), true);
  assertEquals(Array.isArray(snapshot.examResults), true);
  assertEquals(Array.isArray(snapshot.subjectScores), true);
});

Deno.test("buildDefaultStudentSnapshot(snapshot_timetable): matches ParentTimetableData keys + forces a real classLabel", () => {
  const context: StudentSnapshotContext = {
    studentName: "Ravi Kumar",
    classLabel: "8-A",
    rollNo: "",
    admissionNo: "",
    dateOfBirth: "",
    bloodGroup: "",
    schoolName: "",
    parentContacts: [],
  };
  const snapshot = buildDefaultStudentSnapshot("snapshot_timetable", context);

  // The student handler passes `classLabel: String(snapshot.classLabel ?? "")`
  // straight through as options.classLabel to overlayTimetableSnapshotFromSlots,
  // and `options.classLabel ?? fallback` does NOT fall through on "" (only on
  // null/undefined) — so classLabel must be the REAL value here, not blank,
  // or a real student's timetable slots would never be found.
  assertEquals(snapshot.classLabel, "8-A");
  assertEquals(typeof snapshot.weekRangeLabel, "string");
  assertEquals(snapshot.totalPeriodsThisWeek, 0);
  assertEquals(snapshot.completedPeriodsToday, 0);
  assertEquals(snapshot.upcomingPeriodsToday, 0);
  assertEquals(Array.isArray(snapshot.days), true);
});

Deno.test("buildDefaultStudentSnapshot(snapshot_profile): fixes the seed-contract mismatch (rollNo, not rollNumber)", () => {
  const context: StudentSnapshotContext = {
    studentName: "Ravi Kumar",
    classLabel: "8-A",
    rollNo: "23",
    admissionNo: "ADM-0001",
    dateOfBirth: "2012-01-01",
    bloodGroup: "B+",
    schoolName: "Akshara Public School",
    parentContacts: [
      { name: "Suresh Kumar", relation: "father", phoneLabel: "9800000000", email: "" },
    ],
  };
  const snapshot = buildDefaultStudentSnapshot("snapshot_profile", context);

  // student_mapper.dart's toProfile() reads `rollNo`, never `rollNumber` — the
  // old student_entities seed shipped `rollNumber`, so it silently never reached
  // the client. This default must use the key the client actually reads.
  assertEquals(snapshot.rollNo, "23");
  assertEquals(snapshot.admissionNo, "ADM-0001");
  assertEquals(snapshot.dateOfBirth, "2012-01-01");
  assertEquals(snapshot.bloodGroup, "B+");
  assertEquals(snapshot.schoolName, "Akshara Public School");
  assertEquals(Array.isArray(snapshot.parentContacts), true);
  assertEquals((snapshot.parentContacts as unknown[]).length, 1);
  assertEquals(Array.isArray(snapshot.academicSummary), true);
  assertEquals(snapshot.studentName, "Ravi Kumar");
  assertEquals(snapshot.classLabel, "8-A");
});

Deno.test("loadStudentSnapshotContext: resolves real name/class/roll-number from students + sis_student_enrollments", async () => {
  const db = new MockStudentContextDb({
    studentRow: {
      display_name: "Anita Rao",
      class_name: "6",
      section_name: "B",
      roll_number: "12",
      admission_number: "ADM-0099",
      date_of_birth: "2014-05-02",
      blood_group: "O+",
    },
    schoolName: "Akshara Public School",
    guardians: [
      { name: "Rao Kumar", relation: "father", phone: "9800000000", email: "rao@example.com" },
    ],
  }) as unknown as TenantQueryClient;

  const context = await loadStudentSnapshotContext(db, ORG, SCHOOL, STUDENT);

  assertEquals(context.studentName, "Anita Rao");
  assertEquals(context.classLabel, "6-B");
  assertEquals(context.rollNo, "12");
  assertEquals(context.admissionNo, "ADM-0099");
  assertEquals(context.dateOfBirth, "2014-05-02");
  assertEquals(context.bloodGroup, "O+");
  assertEquals(context.schoolName, "Akshara Public School");
  assertEquals(context.parentContacts.length, 1);
  assertEquals(context.parentContacts[0]!.name, "Rao Kumar");
});

Deno.test("loadStudentSnapshotContext: degrades gracefully (never throws) when students/profile/guardian rows are absent", async () => {
  const db = new MockStudentContextDb({}) as unknown as TenantQueryClient;

  const context = await loadStudentSnapshotContext(db, ORG, SCHOOL, STUDENT);

  assertEquals(context.studentName, "Student");
  assertEquals(context.classLabel, "");
  assertEquals(context.rollNo, "");
  assertEquals(context.admissionNo, "");
  assertEquals(context.parentContacts.length, 0);
  // schoolName falls back to the platform default label, never blank/undefined.
  assertEquals(typeof context.schoolName, "string");
  assertEquals(context.schoolName.length > 0, true);
});
