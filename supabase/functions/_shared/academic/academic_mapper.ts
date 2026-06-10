import type { AcademicYearRow } from "./academic_years_repository.ts";
import type { ClassRow } from "./classes_repository.ts";
import type { SectionListRow, SectionRow } from "./sections_repository.ts";
import type { TeacherAssignmentListRow } from "./teacher_assignments_repository.ts";

export function listEnvelope(
  items: Record<string, unknown>[],
  pagination: {
    page: number;
    pageSize: number;
    total: number;
    hasMore: boolean;
  },
): Record<string, unknown> {
  return {
    items,
    pagination: {
      page: pagination.page,
      pageSize: pagination.pageSize,
      total: pagination.total,
      hasMore: pagination.hasMore,
    },
  };
}

export function academicYearToApi(row: AcademicYearRow): Record<string, unknown> {
  return {
    yearId: row.id,
    yearLabel: row.year_label,
    startDate: row.start_date,
    endDate: row.end_date,
    isCurrent: row.is_current,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function classToApi(row: ClassRow): Record<string, unknown> {
  return {
    classId: row.id,
    academicYearId: row.academic_year_id,
    className: row.class_name,
    displayOrder: row.display_order,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function sectionToApi(
  row: SectionRow | SectionListRow,
): Record<string, unknown> {
  const className = "class_name" in row ? row.class_name : undefined;
  return {
    sectionId: row.id,
    classId: row.class_id,
    ...(className ? { className } : {}),
    sectionName: row.section_name,
    capacity: row.capacity,
    strength: row.strength,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function teacherAssignmentToApi(
  row: TeacherAssignmentListRow,
): Record<string, unknown> {
  return {
    assignmentId: row.id,
    teacherId: row.teacher_id,
    teacherName: row.teacher_name,
    classId: row.class_id,
    className: row.class_name,
    sectionId: row.section_id,
    sectionName: row.section_name,
    role: row.role,
    isPrimary: row.is_primary,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
