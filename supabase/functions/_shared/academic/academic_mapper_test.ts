import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  academicYearToApi,
  classToApi,
  listEnvelope,
  sectionToApi,
  teacherAssignmentToApi,
} from "./academic_mapper.ts";

Deno.test("academicYearToApi returns camelCase contract", () => {
  const api = academicYearToApi({
    id: "ce100000-0000-4000-8000-000000000001",
    organization_id: "org",
    school_id: "school",
    year_label: "2026-27",
    start_date: "2026-04-01",
    end_date: "2027-03-31",
    is_current: true,
    status: "active",
    created_by: "staff",
    created_at: "2026-06-15T00:00:00.000Z",
    updated_at: "2026-06-15T00:00:00.000Z",
  });
  assertEquals(api.yearId, "ce100000-0000-4000-8000-000000000001");
  assertEquals(api.yearLabel, "2026-27");
  assertEquals(api.isCurrent, true);
  assertEquals(Object.keys(api).includes("year_label"), false);
});

Deno.test("classToApi returns camelCase contract", () => {
  const api = classToApi({
    id: "class-1",
    organization_id: "org",
    school_id: "school",
    academic_year_id: "year-1",
    class_name: "5",
    display_order: 1,
    status: "active",
    created_by: "staff",
    created_at: "2026-06-15T00:00:00.000Z",
    updated_at: "2026-06-15T00:00:00.000Z",
  });
  assertEquals(api.classId, "class-1");
  assertEquals(api.academicYearId, "year-1");
  assertEquals(api.className, "5");
});

Deno.test("sectionToApi includes className when present", () => {
  const api = sectionToApi({
    id: "section-1",
    organization_id: "org",
    school_id: "school",
    class_id: "class-1",
    section_name: "A",
    capacity: 40,
    strength: 0,
    status: "active",
    created_by: "staff",
    created_at: "2026-06-15T00:00:00.000Z",
    updated_at: "2026-06-15T00:00:00.000Z",
    class_name: "5",
    academic_year_id: "year-1",
  });
  assertEquals(api.sectionId, "section-1");
  assertEquals(api.className, "5");
  assertEquals(api.strength, 0);
});

Deno.test("teacherAssignmentToApi returns camelCase contract", () => {
  const api = teacherAssignmentToApi({
    id: "assign-1",
    organization_id: "org",
    school_id: "school",
    teacher_id: "teacher-1",
    section_id: "section-1",
    role: "class_teacher",
    is_primary: true,
    created_by: "staff",
    created_at: "2026-06-15T00:00:00.000Z",
    updated_at: "2026-06-15T00:00:00.000Z",
    class_id: "class-1",
    class_name: "5",
    section_name: "A",
    teacher_name: "Teacher A",
  });
  assertEquals(api.assignmentId, "assign-1");
  assertEquals(api.teacherName, "Teacher A");
  assertEquals(api.isPrimary, true);
});

Deno.test("listEnvelope wraps paginated items", () => {
  const payload = listEnvelope([{ yearId: "y1" }], {
    page: 1,
    pageSize: 20,
    total: 1,
    hasMore: false,
  });
  assert(Array.isArray((payload.items as unknown[])));
  assertEquals((payload.pagination as Record<string, unknown>).total, 1);
});
