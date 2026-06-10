import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  ACADEMIC_YEAR_SCHOOL_A,
  ACADEMIC_YEAR_SCHOOL_B,
  AcademicYearNotFoundError,
  ConcurrentCurrentYearError,
  listAcademicYearsPage,
  updateAcademicYear,
} from "./academic_years_repository.ts";
import {
  ACADEMIC_CLASS_SCHOOL_A,
  ACADEMIC_CLASS_SCHOOL_B,
  ClassNotFoundError,
  listClassesPage,
  updateClass,
} from "./classes_repository.ts";
import {
  ACADEMIC_SECTION_SCHOOL_A,
  ACADEMIC_SECTION_SCHOOL_B,
  listSectionsPage,
  SectionNotFoundError,
  updateSection,
} from "./sections_repository.ts";
import {
  ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A,
  ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_B,
  DuplicatePrimaryClassTeacherError,
  listTeacherAssignmentsPage,
  TeacherAssignmentNotFoundError,
  updateTeacherAssignment,
} from "./teacher_assignments_repository.ts";
import { matchAcademicRoute } from "./academic_router.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";
const STAFF = "a3000000-0000-4000-8000-000000000001";

type Row = Record<string, unknown>;

class MockAcademicPaginationDb {
  years: Row[] = [
    {
      id: ACADEMIC_YEAR_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      year_label: "2026-27",
      start_date: "2026-04-01",
      end_date: "2027-03-31",
      is_current: true,
      status: "active",
      created_by: STAFF,
      created_at: "2026-06-15T00:00:00.000Z",
      updated_at: "2026-06-15T00:00:00.000Z",
    },
    {
      id: "ce100000-0000-4000-8000-000000000099",
      organization_id: ORG,
      school_id: SCHOOL_A,
      year_label: "2025-26",
      start_date: "2025-04-01",
      end_date: "2026-03-31",
      is_current: false,
      status: "archived",
      created_by: STAFF,
      created_at: "2025-06-15T00:00:00.000Z",
      updated_at: "2025-06-15T00:00:00.000Z",
    },
    {
      id: ACADEMIC_YEAR_SCHOOL_B,
      organization_id: ORG,
      school_id: SCHOOL_B,
      year_label: "2026-27",
      start_date: "2026-04-01",
      end_date: "2027-03-31",
      is_current: true,
      status: "active",
      created_by: STAFF,
      created_at: "2026-06-15T00:00:00.000Z",
      updated_at: "2026-06-15T00:00:00.000Z",
    },
  ];
  classes: Row[] = [
    {
      id: ACADEMIC_CLASS_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      academic_year_id: ACADEMIC_YEAR_SCHOOL_A,
      class_name: "5",
      display_order: 1,
      status: "active",
      created_by: STAFF,
      created_at: "2026-06-15T00:00:00.000Z",
      updated_at: "2026-06-15T00:00:00.000Z",
    },
    {
      id: ACADEMIC_CLASS_SCHOOL_B,
      organization_id: ORG,
      school_id: SCHOOL_B,
      academic_year_id: ACADEMIC_YEAR_SCHOOL_B,
      class_name: "5",
      display_order: 1,
      status: "active",
      created_by: STAFF,
      created_at: "2026-06-15T00:00:00.000Z",
      updated_at: "2026-06-15T00:00:00.000Z",
    },
  ];
  sections: Row[] = [
    {
      id: ACADEMIC_SECTION_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      class_id: ACADEMIC_CLASS_SCHOOL_A,
      section_name: "A",
      capacity: 40,
      strength: 0,
      status: "active",
      created_by: STAFF,
      created_at: "2026-06-15T00:00:00.000Z",
      updated_at: "2026-06-15T00:00:00.000Z",
    },
    {
      id: ACADEMIC_SECTION_SCHOOL_B,
      organization_id: ORG,
      school_id: SCHOOL_B,
      class_id: ACADEMIC_CLASS_SCHOOL_B,
      section_name: "A",
      capacity: 40,
      strength: 0,
      status: "active",
      created_by: STAFF,
      created_at: "2026-06-15T00:00:00.000Z",
      updated_at: "2026-06-15T00:00:00.000Z",
    },
  ];
  assignments: Row[] = [
    {
      id: ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      teacher_id: "d1000000-0000-4000-8000-000000000001",
      section_id: ACADEMIC_SECTION_SCHOOL_A,
      role: "class_teacher",
      is_primary: true,
      created_by: STAFF,
      created_at: "2026-06-15T00:00:00.000Z",
      updated_at: "2026-06-15T00:00:00.000Z",
    },
    {
      id: ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_B,
      organization_id: ORG,
      school_id: SCHOOL_B,
      teacher_id: "d1000000-0000-4000-8000-000000000002",
      section_id: ACADEMIC_SECTION_SCHOOL_B,
      role: "class_teacher",
      is_primary: true,
      created_by: STAFF,
      created_at: "2026-06-15T00:00:00.000Z",
      updated_at: "2026-06-15T00:00:00.000Z",
    },
  ];
  clearCurrentEnabled = true;
  clearPrimaryEnabled = true;

  filterYears(orgId: unknown, schoolId: unknown, filters: { status?: string; isCurrent?: boolean }) {
    return this.years.filter((y) =>
      y.organization_id === orgId &&
      y.school_id === schoolId &&
      (filters.status == null || y.status === filters.status) &&
      (filters.isCurrent == null || y.is_current === filters.isCurrent)
    );
  }

  parseYearFilters(sql: string, args: unknown[], startIdx = 2) {
    const filters: { status?: string; isCurrent?: boolean } = {};
    let argIndex = startIdx;
    if (sql.includes("status = $")) filters.status = args[argIndex++] as string;
    if (sql.includes("is_current = $")) filters.isCurrent = args[argIndex++] as boolean;
    return filters;
  }

  parseClassFilters(sql: string, args: unknown[], startIdx = 2) {
    const filters: { academicYearId?: string; status?: string } = {};
    let argIndex = startIdx;
    if (sql.includes("academic_year_id = $")) filters.academicYearId = args[argIndex++] as string;
    if (sql.includes("status = $")) filters.status = args[argIndex++] as string;
    return filters;
  }

  parseSectionFilters(sql: string, args: unknown[], startIdx = 2) {
    const filters: { classId?: string; academicYearId?: string; status?: string } = {};
    let argIndex = startIdx;
    if (sql.includes("s.class_id = $")) filters.classId = args[argIndex++] as string;
    if (sql.includes("c.academic_year_id = $")) filters.academicYearId = args[argIndex++] as string;
    if (sql.includes("s.status = $")) filters.status = args[argIndex++] as string;
    return filters;
  }

  parseAssignmentFilters(sql: string, args: unknown[], startIdx = 2) {
    const filters: {
      sectionId?: string;
      teacherId?: string;
      classId?: string;
      role?: string;
    } = {};
    let argIndex = startIdx;
    if (sql.includes("ta.section_id = $")) filters.sectionId = args[argIndex++] as string;
    if (sql.includes("ta.teacher_id = $")) filters.teacherId = args[argIndex++] as string;
    if (sql.includes("s.class_id = $")) filters.classId = args[argIndex++] as string;
    if (sql.includes("ta.role = $")) filters.role = args[argIndex++] as string;
    return filters;
  }

  async queryCount(sql: string, args: unknown[] = []): Promise<number> {
    if (sql.includes("FROM academic_years")) {
      return this.filterYears(args[0], args[1], this.parseYearFilters(sql, args)).length;
    }
    if (sql.includes("FROM classes")) {
      const filters = this.parseClassFilters(sql, args);
      return this.classes.filter((c) =>
        c.organization_id === args[0] &&
        c.school_id === args[1] &&
        (filters.academicYearId == null || c.academic_year_id === filters.academicYearId) &&
        (filters.status == null || c.status === filters.status)
      ).length;
    }
    if (sql.includes("FROM sections s")) {
      const filters = this.parseSectionFilters(sql, args);
      return this.sections.filter((s) => {
        const cls = this.classes.find((c) => c.id === s.class_id)!;
        return s.organization_id === args[0] &&
          s.school_id === args[1] &&
          (filters.classId == null || s.class_id === filters.classId) &&
          (filters.academicYearId == null || cls.academic_year_id === filters.academicYearId) &&
          (filters.status == null || s.status === filters.status);
      }).length;
    }
    if (sql.includes("FROM teacher_assignments ta")) {
      const filters = this.parseAssignmentFilters(sql, args);
      return this.assignments.filter((a) => {
        const section = this.sections.find((s) => s.id === a.section_id)!;
        return a.organization_id === args[0] &&
          a.school_id === args[1] &&
          (filters.sectionId == null || a.section_id === filters.sectionId) &&
          (filters.teacherId == null || a.teacher_id === filters.teacherId) &&
          (filters.classId == null || section.class_id === filters.classId) &&
          (filters.role == null || a.role === filters.role);
      }).length;
    }
    return 0;
  }

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("SELECT * FROM academic_years") && sql.includes("WHERE id = $1")) {
      const row = this.years.find((y) =>
        y.id === args[0] && y.organization_id === args[1] && y.school_id === args[2]
      );
      return (row ? [row] : []) as T[];
    }
    if (sql.includes("FROM academic_years") && sql.includes("ORDER BY start_date")) {
      const filters = this.parseYearFilters(sql, args);
      const filtered = this.filterYears(args[0], args[1], filters);
      const limit = args[args.length - 2] as number;
      const offset = args[args.length - 1] as number;
      return filtered.slice(offset, offset + limit) as T[];
    }
    if (sql.includes("UPDATE academic_years SET is_current = false")) {
      if (!this.clearCurrentEnabled) return [] as T[];
      for (const y of this.years) {
        if (
          y.organization_id === args[0] &&
          y.school_id === args[1] &&
          y.is_current === true &&
          (args[2] == null || y.id !== args[2])
        ) {
          y.is_current = false;
        }
      }
      return [] as T[];
    }
    if (sql.includes("UPDATE academic_years SET") && sql.includes("year_label = COALESCE")) {
      const idx = this.years.findIndex((y) =>
        y.id === args[0] && y.organization_id === args[1] && y.school_id === args[2]
      );
      if (idx < 0) return [] as T[];
      if (args[6] === true) {
        const existingCurrent = this.years.some((y) =>
          y.school_id === args[2] &&
          y.is_current === true &&
          y.id !== args[0]
        );
        if (existingCurrent && !this.clearCurrentEnabled) {
          throw new Error(
            "duplicate key value violates unique constraint academic_years_one_current_per_school",
          );
        }
      }
      if (args[6] != null) this.years[idx]!.is_current = args[6];
      return [this.years[idx] as T];
    }
    if (sql.includes("SELECT * FROM classes") && sql.includes("WHERE id = $1")) {
      const row = this.classes.find((c) =>
        c.id === args[0] && c.organization_id === args[1] && c.school_id === args[2]
      );
      return (row ? [row] : []) as T[];
    }
    if (sql.includes("FROM classes") && sql.includes("ORDER BY display_order")) {
      const filters = this.parseClassFilters(sql, args);
      const filtered = this.classes.filter((c) =>
        c.organization_id === args[0] &&
        c.school_id === args[1] &&
        (filters.academicYearId == null || c.academic_year_id === filters.academicYearId) &&
        (filters.status == null || c.status === filters.status)
      );
      const limit = args[args.length - 2] as number;
      const offset = args[args.length - 1] as number;
      return filtered.slice(offset, offset + limit) as T[];
    }
    if (sql.includes("UPDATE classes SET")) {
      const idx = this.classes.findIndex((c) =>
        c.id === args[0] && c.organization_id === args[1] && c.school_id === args[2]
      );
      return idx < 0 ? [] as T[] : [this.classes[idx] as T];
    }
    if (sql.includes("SELECT * FROM sections") && sql.includes("WHERE id = $1")) {
      const row = this.sections.find((s) =>
        s.id === args[0] && s.organization_id === args[1] && s.school_id === args[2]
      );
      return (row ? [row] : []) as T[];
    }
    if (sql.includes("FROM sections s") && sql.includes("ORDER BY c.display_order")) {
      const filters = this.parseSectionFilters(sql, args);
      const filtered = this.sections.filter((s) => {
        const cls = this.classes.find((c) => c.id === s.class_id)!;
        return s.organization_id === args[0] &&
          s.school_id === args[1] &&
          (filters.classId == null || s.class_id === filters.classId) &&
          (filters.academicYearId == null || cls.academic_year_id === filters.academicYearId) &&
          (filters.status == null || s.status === filters.status);
      });
      const limit = args[args.length - 2] as number;
      const offset = args[args.length - 1] as number;
      return filtered.slice(offset, offset + limit).map((s) => {
        const cls = this.classes.find((c) => c.id === s.class_id)!;
        return { ...s, class_name: cls.class_name, academic_year_id: cls.academic_year_id };
      }) as T[];
    }
    if (sql.includes("UPDATE sections SET")) {
      const idx = this.sections.findIndex((s) =>
        s.id === args[0] && s.organization_id === args[1] && s.school_id === args[2]
      );
      return idx < 0 ? [] as T[] : [this.sections[idx] as T];
    }
    if (sql.includes("SELECT * FROM teacher_assignments") && sql.includes("WHERE id = $1")) {
      const row = this.assignments.find((a) =>
        a.id === args[0] && a.organization_id === args[1] && a.school_id === args[2]
      );
      return (row ? [row] : []) as T[];
    }
    if (sql.includes("UPDATE teacher_assignments") && sql.includes("is_primary = false")) {
      if (!this.clearPrimaryEnabled) return [] as T[];
      for (const row of this.assignments) {
        if (
          row.organization_id === args[0] &&
          row.school_id === args[1] &&
          row.section_id === args[2] &&
          row.role === "class_teacher" &&
          row.is_primary === true &&
          (args[3] == null || row.id !== args[3])
        ) {
          row.is_primary = false;
        }
      }
      return [] as T[];
    }
    if (sql.includes("UPDATE teacher_assignments SET") && sql.includes("teacher_id = $4")) {
      const idx = this.assignments.findIndex((a) =>
        a.id === args[0] && a.organization_id === args[1] && a.school_id === args[2]
      );
      if (idx < 0) return [] as T[];
      if (args[5] === "class_teacher" && args[6] === true) {
        const duplicate = this.assignments.some((a) =>
          a.section_id === args[4] &&
          a.role === "class_teacher" &&
          a.is_primary === true &&
          a.id !== args[0] &&
          !this.clearPrimaryEnabled
        );
        if (duplicate) {
          throw new Error(
            "duplicate key value violates unique constraint teacher_assignments_one_primary_class_teacher",
          );
        }
      }
      this.assignments[idx] = {
        ...this.assignments[idx]!,
        teacher_id: args[3],
        section_id: args[4],
        role: args[5],
        is_primary: args[6],
      };
      return [this.assignments[idx] as T];
    }
    if (sql.includes("FROM teacher_assignments ta") && sql.includes("ORDER BY ta.created_at")) {
      const filters = this.parseAssignmentFilters(sql, args);
      const filtered = this.assignments.filter((a) => {
        const section = this.sections.find((s) => s.id === a.section_id)!;
        return a.organization_id === args[0] &&
          a.school_id === args[1] &&
          (filters.sectionId == null || a.section_id === filters.sectionId) &&
          (filters.teacherId == null || a.teacher_id === filters.teacherId) &&
          (filters.classId == null || section.class_id === filters.classId) &&
          (filters.role == null || a.role === filters.role);
      });
      const limit = args[args.length - 2] as number;
      const offset = args[args.length - 1] as number;
      return filtered.slice(offset, offset + limit).map((a) => {
        const section = this.sections.find((s) => s.id === a.section_id)!;
        const cls = this.classes.find((c) => c.id === section.class_id)!;
        return {
          ...a,
          class_id: section.class_id,
          class_name: cls.class_name,
          section_name: section.section_name,
          teacher_name: "Teacher",
        };
      }) as T[];
    }
    return [] as T[];
  }
}

function asDb(mock: MockAcademicPaginationDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

Deno.test("listAcademicYearsPage applies filters to count and items consistently", async () => {
  const db = new MockAcademicPaginationDb();
  const page1 = await listAcademicYearsPage(asDb(db), ORG, SCHOOL_A, { isCurrent: true }, {
    page: 1,
    pageSize: 1,
  });
  assertEquals(page1.total, 1);
  assertEquals(page1.items.length, 1);
  assertEquals(page1.hasMore, false);
  assertEquals(page1.items[0]!.is_current, true);
});

Deno.test("listClassesPage paginates with matching total and hasMore", async () => {
  const db = new MockAcademicPaginationDb();
  db.classes.push({
    id: "cf100000-0000-4000-8000-000000000099",
    organization_id: ORG,
    school_id: SCHOOL_A,
    academic_year_id: ACADEMIC_YEAR_SCHOOL_A,
    class_name: "6",
    display_order: 2,
    status: "active",
    created_by: STAFF,
    created_at: "2026-06-15T00:00:00.000Z",
    updated_at: "2026-06-15T00:00:00.000Z",
  });
  const page1 = await listClassesPage(
    asDb(db),
    ORG,
    SCHOOL_A,
    { academicYearId: ACADEMIC_YEAR_SCHOOL_A },
    { page: 1, pageSize: 1 },
  );
  assertEquals(page1.total, 2);
  assertEquals(page1.items.length, 1);
  assertEquals(page1.hasMore, true);
});

Deno.test("listSectionsPage count query uses class join filters", async () => {
  const db = new MockAcademicPaginationDb();
  const result = await listSectionsPage(
    asDb(db),
    ORG,
    SCHOOL_A,
    { academicYearId: ACADEMIC_YEAR_SCHOOL_A },
    { page: 1, pageSize: 10 },
  );
  assertEquals(result.total, 1);
  assertEquals(result.items[0]!.class_name, "5");
});

Deno.test("listTeacherAssignmentsPage count query uses same join filters as items", async () => {
  const db = new MockAcademicPaginationDb();
  const result = await listTeacherAssignmentsPage(
    asDb(db),
    ORG,
    SCHOOL_A,
    { role: "class_teacher" },
    { page: 1, pageSize: 10 },
  );
  assertEquals(result.total, 1);
  assertEquals(result.items[0]!.role, "class_teacher");
});

Deno.test("updateAcademicYear maps concurrent current-year violation on update", async () => {
  const db = new MockAcademicPaginationDb();
  db.clearCurrentEnabled = false;
  await assertRejects(
    () =>
      updateAcademicYear(asDb(db), ORG, SCHOOL_A, "ce100000-0000-4000-8000-000000000099", {
        isCurrent: true,
      }),
    ConcurrentCurrentYearError,
  );
});

Deno.test("updateTeacherAssignment maps concurrent primary teacher violation", async () => {
  const db = new MockAcademicPaginationDb();
  db.clearPrimaryEnabled = false;
  db.assignments.push({
    id: "d2000000-0000-4000-8000-000000000099",
    organization_id: ORG,
    school_id: SCHOOL_A,
    teacher_id: "d1000000-0000-4000-8000-000000000001",
    section_id: ACADEMIC_SECTION_SCHOOL_A,
    role: "subject_teacher",
    is_primary: false,
    created_by: STAFF,
    created_at: "2026-06-15T00:00:00.000Z",
    updated_at: "2026-06-15T00:00:00.000Z",
  });
  await assertRejects(
    () =>
      updateTeacherAssignment(asDb(db), ORG, SCHOOL_A, "d2000000-0000-4000-8000-000000000099", {
        role: "class_teacher",
        isPrimary: true,
      }),
    DuplicatePrimaryClassTeacherError,
  );
});

Deno.test("cross-school PUT updates return not-found at repository layer", async () => {
  const db = new MockAcademicPaginationDb();
  await assertRejects(
    () => updateAcademicYear(asDb(db), ORG, SCHOOL_A, ACADEMIC_YEAR_SCHOOL_B, { status: "archived" }),
    AcademicYearNotFoundError,
  );
  await assertRejects(
    () => updateClass(asDb(db), ORG, SCHOOL_A, ACADEMIC_CLASS_SCHOOL_B, { status: "archived" }),
    ClassNotFoundError,
  );
  await assertRejects(
    () => updateSection(asDb(db), ORG, SCHOOL_A, ACADEMIC_SECTION_SCHOOL_B, { strength: 1 }),
    SectionNotFoundError,
  );
  await assertRejects(
    () =>
      updateTeacherAssignment(asDb(db), ORG, SCHOOL_A, ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_B, {
        isPrimary: false,
      }),
    TeacherAssignmentNotFoundError,
  );
});

Deno.test("academic router keeps collection routes distinct from PUT id routes", () => {
  assertEquals(matchAcademicRoute("GET", "/academic/years")?.handler.name, "handleListAcademicYears");
  assertEquals(matchAcademicRoute("GET", `/academic/years/${ACADEMIC_YEAR_SCHOOL_A}`), null);
  assertEquals(
    matchAcademicRoute("PUT", `/academic/years/${ACADEMIC_YEAR_SCHOOL_A}`)?.handler.name,
    "handleUpdateAcademicYear",
  );
  assertEquals(matchAcademicRoute("POST", "/academic/teacher-assignments")?.handler.name, "handleCreateTeacherAssignment");
  assertEquals(
    matchAcademicRoute("PUT", `/academic/teacher-assignments/${ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A}`)?.handler.name,
    "handleUpdateTeacherAssignment",
  );
});
