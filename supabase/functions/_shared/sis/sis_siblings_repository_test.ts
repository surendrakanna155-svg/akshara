import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { studentSiblingItemToApi } from "./sis_mapper.ts";
import { listStudentSiblings } from "./sis_students_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";

const SUBJECT = "a4000000-0000-4000-8000-000000000001";
const SIBLING = "a4000000-0000-4000-8000-000000000002";
const HALF_SIBLING = "a4000000-0000-4000-8000-000000000003";
const STRANGER = "a4000000-0000-4000-8000-000000000004";
const CROSS_SCHOOL = "a4000000-0000-4000-8000-000000000005";
const INACTIVE_LINK = "a4000000-0000-4000-8000-000000000006";
const LONELY = "a4000000-0000-4000-8000-000000000007";

// Shared guardians.
const GUARDIAN_1 = "a3000000-0000-4000-8000-000000000001"; // subject + sibling + cross-school + inactive-link
const GUARDIAN_2 = "a3000000-0000-4000-8000-000000000002"; // subject + half-sibling
const GUARDIAN_3 = "a3000000-0000-4000-8000-000000000003"; // stranger only (not shared)
const GUARDIAN_4 = "a3000000-0000-4000-8000-000000000004"; // lonely only (not shared)

type Row = Record<string, unknown>;

function student(id: string, schoolId: string, name: string, code: string): Row {
  return {
    id,
    organization_id: ORG,
    school_id: schoolId,
    student_code: code,
    display_name: name,
    status: "active",
  };
}

function guardianLink(
  studentId: string,
  guardianUserId: string,
  schoolId: string,
  status: string,
): Row {
  return {
    student_id: studentId,
    organization_id: ORG,
    school_id: schoolId,
    guardian_user_id: guardianUserId,
    status,
  };
}

class MockSiblingsDb {
  students: Row[] = [
    student(SUBJECT, SCHOOL_A, "Aarav Subject", "STU-001"),
    student(SIBLING, SCHOOL_A, "Bhavna Sibling", "STU-002"),
    student(HALF_SIBLING, SCHOOL_A, "Chetan Half", "STU-003"),
    student(STRANGER, SCHOOL_A, "Divya Stranger", "STU-004"),
    student(CROSS_SCHOOL, SCHOOL_B, "Esha CrossSchool", "STU-005"),
    student(INACTIVE_LINK, SCHOOL_A, "Farhan Inactive", "STU-006"),
    student(LONELY, SCHOOL_A, "Gita Lonely", "STU-007"),
  ];
  profiles: Row[] = [
    {
      student_id: SIBLING,
      organization_id: ORG,
      school_id: SCHOOL_A,
      admission_number: "ADM-SIB-001",
      public_student_id: "STGSCH-0002",
    },
  ];
  enrollments: Row[] = [
    {
      student_id: SIBLING,
      organization_id: ORG,
      school_id: SCHOOL_A,
      class_name: "5",
      section_name: "A",
      is_current: true,
    },
  ];
  guardians: Row[] = [
    // Subject's active guardians (school A).
    guardianLink(SUBJECT, GUARDIAN_1, SCHOOL_A, "active"),
    guardianLink(SUBJECT, GUARDIAN_2, SCHOOL_A, "active"),
    // Sibling shares GUARDIAN_1 (active) → included.
    guardianLink(SIBLING, GUARDIAN_1, SCHOOL_A, "active"),
    // Half-sibling shares GUARDIAN_2 (active) → included (any shared guardian counts).
    guardianLink(HALF_SIBLING, GUARDIAN_2, SCHOOL_A, "active"),
    // Stranger has an unrelated guardian → excluded.
    guardianLink(STRANGER, GUARDIAN_3, SCHOOL_A, "active"),
    // Cross-school student shares the SAME guardian id but in school B → excluded.
    guardianLink(CROSS_SCHOOL, GUARDIAN_1, SCHOOL_B, "active"),
    // Inactive-link student shares GUARDIAN_1 but its link is inactive → excluded.
    guardianLink(INACTIVE_LINK, GUARDIAN_1, SCHOOL_A, "inactive"),
    // Lonely student's only guardian is not shared with the subject → excluded.
    guardianLink(LONELY, GUARDIAN_4, SCHOOL_A, "active"),
  ];

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("student_guardians sib") && sql.includes("EXISTS")) {
      return this.filterSiblings(args) as T[];
    }
    return [] as T[];
  }

  // Mirrors the listStudentSiblings SQL: siblings = other students in the SAME
  // org + school with an ACTIVE guardian link whose guardian_user_id is also an
  // ACTIVE guardian of the subject in the same org + school.
  filterSiblings(args: unknown[]): Row[] {
    const orgId = args[0];
    const schoolId = args[1];
    const subjectId = args[2];

    const subjectGuardianIds = new Set(
      this.guardians
        .filter((g) =>
          g.student_id === subjectId &&
          g.organization_id === orgId &&
          g.school_id === schoolId &&
          g.status === "active"
        )
        .map((g) => g.guardian_user_id),
    );

    return this.students
      .filter((s) =>
        s.organization_id === orgId &&
        s.school_id === schoolId &&
        s.id !== subjectId &&
        this.guardians.some((g) =>
          g.student_id === s.id &&
          g.organization_id === orgId &&
          g.school_id === schoolId &&
          g.status === "active" &&
          subjectGuardianIds.has(g.guardian_user_id)
        )
      )
      .map((s) => {
        const profile = this.profiles.find((p) => p.student_id === s.id);
        const enrollment = this.enrollments.find((e) =>
          e.student_id === s.id && e.is_current === true
        );
        return {
          student_id: s.id,
          student_code: s.student_code,
          display_name: s.display_name,
          status: s.status,
          admission_number: profile?.admission_number ?? null,
          public_student_id: profile?.public_student_id ?? null,
          class_name: enrollment?.class_name ?? null,
          section_name: enrollment?.section_name ?? null,
        };
      })
      .sort((a, b) =>
        String(a.display_name).localeCompare(String(b.display_name))
      );
  }
}

Deno.test("SIS-4 listStudentSiblings returns students sharing an active guardian", async () => {
  const db = new MockSiblingsDb() as unknown as TenantQueryClient;
  const rows = await listStudentSiblings(db, ORG, SCHOOL_A, SUBJECT);
  const ids = rows.map((r) => r.student_id);

  // Both the full sibling (GUARDIAN_1) and the half-sibling (GUARDIAN_2) appear.
  assertEquals(ids.includes(SIBLING), true);
  assertEquals(ids.includes(HALF_SIBLING), true);
  // Ordered by display_name ASC: "Bhavna Sibling" before "Chetan Half".
  assertEquals(rows[0]?.student_id, SIBLING);
});

Deno.test("SIS-4 listStudentSiblings excludes the subject itself", async () => {
  const db = new MockSiblingsDb() as unknown as TenantQueryClient;
  const rows = await listStudentSiblings(db, ORG, SCHOOL_A, SUBJECT);
  assertEquals(rows.some((r) => r.student_id === SUBJECT), false);
});

Deno.test("SIS-4 listStudentSiblings enforces cross-school isolation", async () => {
  const db = new MockSiblingsDb() as unknown as TenantQueryClient;
  const rows = await listStudentSiblings(db, ORG, SCHOOL_A, SUBJECT);
  // A student in another school sharing the SAME guardian id never appears.
  assertEquals(rows.some((r) => r.student_id === CROSS_SCHOOL), false);
});

Deno.test("SIS-4 listStudentSiblings ignores inactive guardian links", async () => {
  const db = new MockSiblingsDb() as unknown as TenantQueryClient;
  const rows = await listStudentSiblings(db, ORG, SCHOOL_A, SUBJECT);
  assertEquals(rows.some((r) => r.student_id === INACTIVE_LINK), false);
});

Deno.test("SIS-4 listStudentSiblings excludes students with no shared guardian", async () => {
  const db = new MockSiblingsDb() as unknown as TenantQueryClient;
  const rows = await listStudentSiblings(db, ORG, SCHOOL_A, SUBJECT);
  assertEquals(rows.some((r) => r.student_id === STRANGER), false);
  assertEquals(rows.some((r) => r.student_id === LONELY), false);
  // Exactly the two genuine siblings.
  assertEquals(rows.length, 2);
});

Deno.test("SIS-4 listStudentSiblings returns [] when the student has no shared guardian", async () => {
  const db = new MockSiblingsDb() as unknown as TenantQueryClient;
  // LONELY's only guardian (GUARDIAN_4) is not shared with anyone else.
  const rows = await listStudentSiblings(db, ORG, SCHOOL_A, LONELY);
  assertEquals(rows, []);
});

Deno.test("SIS-4 studentSiblingItemToApi maps the read-only summary fields", () => {
  const api = studentSiblingItemToApi({
    student_id: SIBLING,
    student_code: "STU-002",
    display_name: "Bhavna Sibling",
    status: "active",
    admission_number: "ADM-SIB-001",
    public_student_id: "STGSCH-0002",
    class_name: "5",
    section_name: "A",
  });

  assertEquals(api.studentId, SIBLING);
  assertEquals(api.displayName, "Bhavna Sibling");
  assertEquals(api.admissionNumber, "ADM-SIB-001");
  assertEquals(api.className, "5");
  assertEquals(api.sectionName, "A");
  assertEquals(api.status, "active");
  assertEquals(api.publicStudentId, "STGSCH-0002");
});

Deno.test("SIS-4 studentSiblingItemToApi defaults null summary fields to empty strings", () => {
  const api = studentSiblingItemToApi({
    student_id: HALF_SIBLING,
    student_code: "STU-003",
    display_name: "Chetan Half",
    status: "active",
    admission_number: null,
    public_student_id: null,
    class_name: null,
    section_name: null,
  });

  assertEquals(api.admissionNumber, "");
  assertEquals(api.publicStudentId, "");
  assertEquals(api.className, "");
  assertEquals(api.sectionName, "");
});
