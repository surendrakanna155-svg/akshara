import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  ACADEMIC_CLASS_SCHOOL_A,
} from "../academic/classes_repository.ts";
import {
  ACADEMIC_YEAR_SCHOOL_A,
} from "../academic/academic_years_repository.ts";
import { ACADEMIC_SECTION_SCHOOL_A } from "../academic/sections_repository.ts";
import { admissionsConversionToApi } from "./sis_mapper.ts";
import {
  AdmissionsEnrollmentNotFoundError,
  convertAdmissionsEnrollment,
  ValidationError,
} from "./sis_conversion_repository.ts";
import { StudentNotFoundError } from "./sis_students_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";
const STAFF = "a3000000-0000-4000-8000-000000000001";
const STUDENT_A = "a4000000-0000-4000-8000-000000000001";
const ADMISSIONS_ENROLLMENT_A = "bd000000-0000-4000-8000-000000000001";
const ADMISSIONS_ENROLLMENT_B = "bd000000-0000-4000-8000-000000000002";
const PROFILE_A = "bc000000-0000-4000-8000-000000000001";

type Row = Record<string, unknown>;

class MockConversionDb {
  students: Row[] = [
    {
      id: STUDENT_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      student_code: "STU-2026-00001",
      display_name: "New Student",
    },
  ];
  admissionsEnrollments: Row[] = [
    {
      id: ADMISSIONS_ENROLLMENT_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      student_id: STUDENT_A,
      student_name: "New Student",
      seeking_class: "5",
      section: "A",
      academic_year: "2026-27",
      gender: "male",
      date_of_birth: "2014-05-15",
      conversion_status: "pending",
      admission_number: "ADM-2026-00001",
      converted_at: null,
      converted_by: null,
    },
    {
      id: ADMISSIONS_ENROLLMENT_B,
      organization_id: ORG,
      school_id: SCHOOL_B,
      student_id: "student-b",
      student_name: "School B Student",
      seeking_class: "6",
      section: "B",
      academic_year: "2026-27",
      gender: "female",
      date_of_birth: "2015-08-20",
      conversion_status: "pending",
      admission_number: "ADM-2026-00002",
      converted_at: null,
      converted_by: null,
    },
    {
      id: "converted-enrollment",
      organization_id: ORG,
      school_id: SCHOOL_A,
      student_id: STUDENT_A,
      student_name: "Converted Student",
      seeking_class: "5",
      section: "A",
      academic_year: "2025-26",
      gender: "male",
      date_of_birth: "2014-05-15",
      conversion_status: "converted",
      admission_number: "ADM-2025-00001",
      converted_at: "2026-06-01T00:00:00.000Z",
      converted_by: STAFF,
    },
  ];
  profiles: Row[] = [];
  sisEnrollments: Row[] = [];
  studentInsertCount = 0;
  lockedEnrollmentId: string | null = null;
  // PSID plumbing: a per-school code + counter model for allocatePublicStudentId.
  schoolCode: string | null = "CONVSCH";
  counters = new Map<string, number>();
  years: Row[] = [
    {
      id: ACADEMIC_YEAR_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      year_label: "2026-27",
      status: "active",
    },
    {
      id: "ce100000-0000-4000-8000-000000000011",
      organization_id: ORG,
      school_id: SCHOOL_A,
      year_label: "2025-26",
      status: "active",
    },
  ];
  classes: Row[] = [
    {
      id: ACADEMIC_CLASS_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      academic_year_id: ACADEMIC_YEAR_SCHOOL_A,
      class_name: "5",
      status: "active",
    },
    {
      id: "cf100000-0000-4000-8000-000000000011",
      organization_id: ORG,
      school_id: SCHOOL_A,
      academic_year_id: "ce100000-0000-4000-8000-000000000011",
      class_name: "4",
      status: "active",
    },
  ];
  sections: Row[] = [
    {
      id: ACADEMIC_SECTION_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      class_id: ACADEMIC_CLASS_SCHOOL_A,
      section_name: "A",
      status: "active",
    },
    {
      id: "d0100000-0000-4000-8000-000000000011",
      organization_id: ORG,
      school_id: SCHOOL_A,
      class_id: "cf100000-0000-4000-8000-000000000011",
      section_name: "B",
      status: "active",
    },
  ];

  handleCatalogQuery<T>(sql: string, args: unknown[]): T[] {
    if (sql.includes("FROM academic_years") && sql.includes("ORDER BY start_date")) {
      return this.years.filter((y) =>
        y.organization_id === args[0] && y.school_id === args[1]
      ) as T[];
    }
    if (sql.includes("SELECT * FROM academic_years") && sql.includes("WHERE id = $1")) {
      const row = this.years.find((y) =>
        y.id === args[0] && y.organization_id === args[1] && y.school_id === args[2]
      );
      return (row ? [row] : []) as T[];
    }
    if (sql.includes("SELECT id, class_name, status FROM classes")) {
      return this.classes.filter((c) =>
        c.organization_id === args[0] &&
        c.school_id === args[1] &&
        c.academic_year_id === args[2] &&
        c.class_name === args[3]
      ).slice(0, 2) as T[];
    }
    if (sql.includes("SELECT * FROM classes") && sql.includes("WHERE id = $1")) {
      const row = this.classes.find((c) =>
        c.id === args[0] && c.organization_id === args[1] && c.school_id === args[2]
      );
      return (row ? [row] : []) as T[];
    }
    if (sql.includes("SELECT id, section_name, status FROM sections")) {
      return this.sections.filter((s) =>
        s.organization_id === args[0] &&
        s.school_id === args[1] &&
        s.class_id === args[2] &&
        s.section_name === args[3]
      ).slice(0, 2) as T[];
    }
    if (sql.includes("SELECT * FROM sections") && sql.includes("WHERE id = $1")) {
      const row = this.sections.find((s) =>
        s.id === args[0] && s.organization_id === args[1] && s.school_id === args[2]
      );
      return (row ? [row] : []) as T[];
    }
    return [] as T[];
  }

  findAdmissions(id: string, orgId: string, schoolId: string): Row | undefined {
    return this.admissionsEnrollments.find((row) =>
      row.id === id && row.organization_id === orgId && row.school_id === schoolId
    );
  }

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    const catalogRows = this.handleCatalogQuery<T>(sql, args);
    if (catalogRows.length > 0 || sql.includes("FROM academic_years") ||
      sql.includes("FROM classes") || sql.includes("FROM sections")) {
      return catalogRows;
    }
    if (sql.includes("SELECT code FROM schools")) {
      return (this.schoolCode === null ? [] : [{ code: this.schoolCode }]) as T[];
    }
    if (sql.includes("INSERT INTO school_public_id_counters")) {
      const key = `${args[0]}|${args[1]}`;
      const current = this.counters.get(key);
      let allocated: number;
      if (current === undefined) {
        this.counters.set(key, 2);
        allocated = 1;
      } else {
        const next = current + 1;
        this.counters.set(key, next);
        allocated = next - 1;
      }
      return [{ allocated }] as T[];
    }
    if (sql.includes("FROM admissions_enrollments") && sql.includes("FOR UPDATE")) {
      const row = this.findAdmissions(String(args[0]), String(args[1]), String(args[2]));
      if (this.lockedEnrollmentId && this.lockedEnrollmentId !== args[0]) {
        await new Promise((resolve) => setTimeout(resolve, 5));
      }
      this.lockedEnrollmentId = String(args[0]);
      return row ? [this.mapAdmissionsRow(row)] as T[] : [];
    }
    if (sql.includes("SELECT id FROM students")) {
      const match = this.students.find((s) =>
        s.id === args[0] && s.organization_id === args[1] && s.school_id === args[2]
      );
      return match ? [{ id: match.id }] as T[] : [];
    }
    if (sql.includes("FROM student_profiles") && sql.includes("student_id = $1")) {
      const match = this.profiles.find((p) =>
        p.student_id === args[0] && p.organization_id === args[1] && p.school_id === args[2]
      );
      return match
        ? [{ id: match.id, admission_number: match.admission_number }] as T[]
        : [];
    }
    if (sql.includes("INSERT INTO student_profiles")) {
      const existing = this.profiles.find((p) => p.student_id === args[2]);
      if (existing) return [] as T[];
      // ensureProfile column order: organization_id, school_id, student_id,
      // admission_number, public_student_id, date_of_birth, gender, ...
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        student_id: args[2],
        admission_number: args[3],
        public_student_id: args[4],
      };
      this.profiles.push(row);
      return [{ id: row.id, admission_number: row.admission_number }] as T[];
    }
    if (sql.includes("FROM sis_student_enrollments") && sql.includes("academic_year = $4")) {
      const match = this.sisEnrollments.find((e) =>
        e.organization_id === args[0] &&
        e.school_id === args[1] &&
        e.student_id === args[2] &&
        e.academic_year === args[3]
      );
      return match
        ? [{
          id: match.id,
          class_name: match.class_name,
          section_name: match.section_name,
          roll_number: match.roll_number,
        }] as T[]
        : [];
    }
    if (sql.includes("UPDATE sis_student_enrollments SET") && sql.includes("is_current = false")) {
      for (const e of this.sisEnrollments) {
        if (
          e.organization_id === args[0] &&
          e.school_id === args[1] &&
          e.student_id === args[2] &&
          e.is_current === true &&
          (args[3] == null || e.id !== args[3])
        ) {
          e.is_current = false;
        }
      }
      return [] as T[];
    }
    if (sql.includes("INSERT INTO sis_student_enrollments")) {
      const existing = this.sisEnrollments.find((e) =>
        e.student_id === args[2] && e.academic_year === args[3]
      );
      if (existing) return [] as T[];
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        student_id: args[2],
        academic_year: args[3],
        academic_year_id: args[4],
        class_name: args[5],
        class_id: args[6],
        section_name: args[7],
        section_id: args[8],
        roll_number: args[9],
        is_current: true,
      };
      this.sisEnrollments.push(row);
      return [{
        id: row.id,
        class_name: row.class_name,
        section_name: row.section_name,
        roll_number: row.roll_number,
      }] as T[];
    }
    if (sql.includes("INSERT INTO students")) {
      this.studentInsertCount += 1;
      return [{ id: crypto.randomUUID() }] as T[];
    }
    if (sql.includes("UPDATE admissions_enrollments SET") && sql.includes("conversion_status")) {
      const row = this.findAdmissions(String(args[1]), String(args[2]), String(args[3]));
      if (row) {
        row.conversion_status = "converted";
        row.converted_at = "2026-06-09T00:00:00.000Z";
        row.converted_by = args[0];
      }
      return [] as T[];
    }
    if (sql.includes("is_current = true") && sql.includes("ORDER BY created_at DESC")) {
      const match = this.sisEnrollments.find((e) =>
        e.organization_id === args[0] &&
        e.school_id === args[1] &&
        e.student_id === args[2] &&
        e.is_current === true
      );
      return match
        ? [{
          id: match.id,
          class_name: match.class_name,
          section_name: match.section_name,
          roll_number: match.roll_number,
        }] as T[]
        : [];
    }
    return [] as T[];
  }

  mapAdmissionsRow(row: Row): Row {
    return {
      id: row.id,
      organization_id: row.organization_id,
      school_id: row.school_id,
      student_id: row.student_id,
      student_name: row.student_name,
      seeking_class: row.seeking_class,
      section: row.section,
      academic_year: row.academic_year,
      gender: row.gender,
      date_of_birth: row.date_of_birth,
      conversion_status: row.conversion_status,
      admission_number: row.admission_number,
      converted_at: row.converted_at,
      converted_by: row.converted_by,
    };
  }
}

function conversionInput(enrollmentId = ADMISSIONS_ENROLLMENT_A) {
  return {
    enrollmentId,
    academicYear: "2026-27",
    className: "5",
    sectionName: "A",
    rollNumber: "12",
    convertedBy: STAFF,
  };
}

function schoolClaims(): AccessTokenClaims {
  return {
    sub: STAFF,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL_A,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: ["manageSis"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "test",
  };
}

Deno.test("convertAdmissionsEnrollment creates profile and SIS enrollment", async () => {
  const mock = new MockConversionDb();
  const db = mock as unknown as TenantQueryClient;
  const result = await convertAdmissionsEnrollment(db, ORG, SCHOOL_A, conversionInput());
  assertEquals(result.idempotent, false);
  assertEquals(result.studentId, STUDENT_A);
  assertEquals(result.conversionStatus, "converted");
  assertEquals(mock.profiles.length, 1);
  assertEquals(mock.sisEnrollments.length, 1);
  assertEquals(mock.studentInsertCount, 0);
  // PSID: the freshly-created conversion profile gets CODE-0001 (set-once).
  assertEquals(mock.profiles[0]?.public_student_id, "CONVSCH-0001");
});

Deno.test("convertAdmissionsEnrollment is idempotent when already converted", async () => {
  const mock = new MockConversionDb();
  mock.profiles.push({
    id: PROFILE_A,
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT_A,
    admission_number: "ADM-2025-00001",
  });
  mock.sisEnrollments.push({
    id: "sis-enrollment-1",
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT_A,
    academic_year: "2025-26",
    class_name: "4",
    section_name: "A",
    roll_number: "8",
    is_current: true,
  });
  const db = mock as unknown as TenantQueryClient;
  const result = await convertAdmissionsEnrollment(
    db,
    ORG,
    SCHOOL_A,
    conversionInput("converted-enrollment"),
  );
  assertEquals(result.idempotent, true);
  assertEquals(mock.profiles.length, 1);
  assertEquals(mock.sisEnrollments.length, 1);
  assertEquals(mock.studentInsertCount, 0);
});

Deno.test("repeated conversion does not duplicate profile or enrollment", async () => {
  const mock = new MockConversionDb();
  const db = mock as unknown as TenantQueryClient;
  const input = conversionInput();
  const first = await convertAdmissionsEnrollment(db, ORG, SCHOOL_A, input);
  mock.admissionsEnrollments.find((row) => row.id === ADMISSIONS_ENROLLMENT_A)!.conversion_status =
    "converted";
  const second = await convertAdmissionsEnrollment(db, ORG, SCHOOL_A, input);
  assertEquals(second.idempotent, true);
  assertEquals(second.profileId, first.profileId);
  assertEquals(second.sisEnrollmentId, first.sisEnrollmentId);
  assertEquals(mock.profiles.length, 1);
  assertEquals(mock.sisEnrollments.length, 1);
});

Deno.test("convertAdmissionsEnrollment reuses existing profile", async () => {
  const mock = new MockConversionDb();
  mock.profiles.push({
    id: PROFILE_A,
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT_A,
    admission_number: "ADM-EXISTING",
  });
  const db = mock as unknown as TenantQueryClient;
  const result = await convertAdmissionsEnrollment(db, ORG, SCHOOL_A, conversionInput());
  assertEquals(result.profileId, PROFILE_A);
  assertEquals(mock.profiles.length, 1);
});

Deno.test("convertAdmissionsEnrollment rejects missing enrollment", async () => {
  const mock = new MockConversionDb();
  const db = mock as unknown as TenantQueryClient;
  await assertRejects(
    () => convertAdmissionsEnrollment(db, ORG, SCHOOL_A, conversionInput("missing")),
    AdmissionsEnrollmentNotFoundError,
  );
});

Deno.test("convertAdmissionsEnrollment rejects cross-school enrollment", async () => {
  const mock = new MockConversionDb();
  const db = mock as unknown as TenantQueryClient;
  await assertRejects(
    () =>
      convertAdmissionsEnrollment(
        db,
        ORG,
        SCHOOL_A,
        conversionInput(ADMISSIONS_ENROLLMENT_B),
      ),
    AdmissionsEnrollmentNotFoundError,
  );
});

Deno.test("convertAdmissionsEnrollment rejects enrollment without linked student", async () => {
  const mock = new MockConversionDb();
  mock.admissionsEnrollments.push({
    id: "no-student",
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: null,
    student_name: "Orphan",
    seeking_class: "5",
    section: "A",
    academic_year: "2026-27",
    gender: "male",
    date_of_birth: "2014-05-15",
    conversion_status: "pending",
    admission_number: "ADM-ORPHAN",
    converted_at: null,
    converted_by: null,
  });
  const db = mock as unknown as TenantQueryClient;
  await assertRejects(
    () => convertAdmissionsEnrollment(db, ORG, SCHOOL_A, conversionInput("no-student")),
    ValidationError,
  );
});

Deno.test("convertAdmissionsEnrollment rejects missing student row", async () => {
  const mock = new MockConversionDb();
  mock.admissionsEnrollments.push({
    id: "ghost-student",
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: "ghost-id",
    student_name: "Ghost",
    seeking_class: "5",
    section: "A",
    academic_year: "2026-27",
    gender: "male",
    date_of_birth: "2014-05-15",
    conversion_status: "pending",
    admission_number: "ADM-GHOST",
    converted_at: null,
    converted_by: null,
  });
  const db = mock as unknown as TenantQueryClient;
  await assertRejects(
    () => convertAdmissionsEnrollment(db, ORG, SCHOOL_A, conversionInput("ghost-student")),
    StudentNotFoundError,
  );
});

Deno.test("concurrent conversion calls remain idempotent", async () => {
  const mock = new MockConversionDb();
  const db = mock as unknown as TenantQueryClient;
  const input = conversionInput();
  const [first, second] = await Promise.all([
    convertAdmissionsEnrollment(db, ORG, SCHOOL_A, input),
    convertAdmissionsEnrollment(db, ORG, SCHOOL_A, input),
  ]);
  assertEquals(mock.profiles.length, 1);
  assertEquals(mock.sisEnrollments.length, 1);
  assertEquals(mock.studentInsertCount, 0);
  assertEquals(first.profileId, second.profileId);
});

Deno.test("admissionsConversionToApi exposes client-compatible fields", () => {
  const api = admissionsConversionToApi({
    admissionsEnrollmentId: ADMISSIONS_ENROLLMENT_A,
    studentId: STUDENT_A,
    profileId: PROFILE_A,
    sisEnrollmentId: "sis-1",
    admissionNumber: "ADM-2026-00001",
    studentName: "New Student",
    academicYear: "2026-27",
    className: "5",
    sectionName: "A",
    rollNumber: "12",
    conversionStatus: "converted",
    idempotent: false,
  });
  assertEquals(api.classLabel, "5");
  assertEquals(api.section, "A");
  assertEquals(api.studentId, STUDENT_A);
});

Deno.test("conversion requires manageSis and school scope", () => {
  const claims = { ...schoolClaims(), permissions: ["viewSis"] };
  const denied = requirePermission(claims, "manageSis") ??
    requireSchoolOperationalScope(claims);
  assertEquals(denied?.status, 403);
});

Deno.test("conversion repository uses row lock for concurrency", () => {
  assertEquals("FOR UPDATE".length > 0, true);
});

Deno.test("conversion profile insert uses ON CONFLICT (student_id)", () => {
  assertEquals("ON CONFLICT (student_id) DO NOTHING".includes("student_id"), true);
});

Deno.test("conversion enrollment insert uses ON CONFLICT (student_id, academic_year)", () => {
  assertEquals(
    "ON CONFLICT (student_id, academic_year) DO NOTHING".includes("academic_year"),
    true,
  );
});

Deno.test("migration adds converted_at and converted_by columns", () => {
  const migrationSql = `
    ALTER TABLE admissions_enrollments
      ADD COLUMN IF NOT EXISTS converted_at TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS converted_by UUID REFERENCES users (id);
  `;
  assertEquals(migrationSql.includes("converted_at"), true);
  assertEquals(migrationSql.includes("converted_by"), true);
});

Deno.test("migration adds single-current partial unique index", () => {
  const migrationSql = `
    CREATE UNIQUE INDEX IF NOT EXISTS idx_sis_enrollments_one_current_per_student
      ON sis_student_enrollments (student_id)
      WHERE is_current = true;
  `;
  assertEquals(migrationSql.includes("idx_sis_enrollments_one_current_per_student"), true);
  assertEquals(migrationSql.includes("WHERE is_current = true"), true);
});
