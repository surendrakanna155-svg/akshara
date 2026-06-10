import type { TenantQueryClient } from "../tenant_db.ts";
import { getAcademicYear } from "./academic_years_repository.ts";
import {
  clampPageSize,
  offsetFor,
  type PaginationParams,
  type PaginationResult,
} from "./academic_pagination.ts";

export const ACADEMIC_CLASS_SCHOOL_A = "cf100000-0000-4000-8000-000000000001";
export const ACADEMIC_CLASS_SCHOOL_B = "cf100000-0000-4000-8000-000000000003";

/** SQL fragment used by tenant isolation probes for class visibility. */
export const ACADEMIC_CLASSES_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM classes
`;

/** SQL fragment used by API-layer tenant isolation probes (list). */
export const ACADEMIC_CLASSES_API_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM classes c
  WHERE c.organization_id = app_current_tenant_id()
    AND c.school_id = app_current_school_id()
`;

/** SQL fragment used by API-layer tenant isolation probes (detail/update by id). */
export const ACADEMIC_CLASS_DETAIL_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM classes
  WHERE id = $1
`;

export interface ClassRow {
  id: string;
  organization_id: string;
  school_id: string;
  academic_year_id: string;
  class_name: string;
  display_order: number;
  status: string;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateClassInput {
  academicYearId: string;
  className: string;
  displayOrder?: number;
  status?: string;
  createdBy: string;
}

export interface UpdateClassInput {
  className?: string;
  displayOrder?: number;
  status?: string;
}

export interface ClassListFilters {
  academicYearId?: string;
  status?: string;
}

export class DuplicateClassError extends Error {
  constructor(className: string, academicYearId: string) {
    super(`Class ${className} already exists for academic year ${academicYearId}`);
    this.name = "DuplicateClassError";
  }
}

export class ClassNotFoundError extends Error {
  constructor(id: string) {
    super(`Class not found: ${id}`);
    this.name = "ClassNotFoundError";
  }
}

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ValidationError";
  }
}

async function assertAcademicYearInSchool(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  academicYearId: string,
): Promise<void> {
  const year = await getAcademicYear(db, organizationId, schoolId, academicYearId);
  if (!year) {
    throw new ValidationError(`Academic year not found in school scope: ${academicYearId}`);
  }
}

export async function listClasses(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  academicYearId?: string,
): Promise<ClassRow[]> {
  const args: unknown[] = [organizationId, schoolId];
  let sql = `SELECT * FROM classes
             WHERE organization_id = $1 AND school_id = $2`;
  if (academicYearId) {
    sql += ` AND academic_year_id = $3`;
    args.push(academicYearId);
  }
  sql += ` ORDER BY display_order ASC, class_name ASC`;
  return await db.queryObject<ClassRow>(sql, args);
}

export async function getClass(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  classId: string,
): Promise<ClassRow | null> {
  const rows = await db.queryObject<ClassRow>(
    `SELECT * FROM classes
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [classId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function listClassesPage(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filters: ClassListFilters,
  pagination: PaginationParams,
): Promise<PaginationResult<ClassRow>> {
  const limit = clampPageSize(pagination.pageSize);
  const offset = offsetFor(pagination.page, limit);
  const conditions = ["organization_id = $1", "school_id = $2"];
  const args: unknown[] = [organizationId, schoolId];

  if (filters.academicYearId) {
    conditions.push(`academic_year_id = $${args.length + 1}`);
    args.push(filters.academicYearId);
  }
  if (filters.status) {
    conditions.push(`status = $${args.length + 1}`);
    args.push(filters.status);
  }

  const where = conditions.join(" AND ");
  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM classes WHERE ${where}`,
    args,
  );
  const items = await db.queryObject<ClassRow>(
    `SELECT * FROM classes
     WHERE ${where}
     ORDER BY display_order ASC, class_name ASC
     LIMIT $${args.length + 1} OFFSET $${args.length + 2}`,
    [...args, limit, offset],
  );

  return {
    items,
    total,
    page: pagination.page,
    pageSize: limit,
    hasMore: offset + items.length < total,
  };
}

export async function createClass(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateClassInput,
): Promise<ClassRow> {
  await assertAcademicYearInSchool(db, organizationId, schoolId, input.academicYearId);
  const className = input.className.trim();
  if (!className) throw new ValidationError("className is required");

  try {
    const rows = await db.queryObject<ClassRow>(
      `INSERT INTO classes (
        organization_id, school_id, academic_year_id, class_name, display_order,
        status, created_by
      ) VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *`,
      [
        organizationId,
        schoolId,
        input.academicYearId,
        className,
        input.displayOrder ?? 0,
        input.status ?? "active",
        input.createdBy,
      ],
    );
    return rows[0]!;
  } catch (error) {
    if (String(error).includes("classes_academic_year_id_class_name_key") ||
      String(error).includes("duplicate key")) {
      throw new DuplicateClassError(className, input.academicYearId);
    }
    throw error;
  }
}

export async function updateClass(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  classId: string,
  input: UpdateClassInput,
): Promise<ClassRow> {
  const existing = await getClass(db, organizationId, schoolId, classId);
  if (!existing) throw new ClassNotFoundError(classId);

  try {
    const rows = await db.queryObject<ClassRow>(
      `UPDATE classes SET
        class_name = COALESCE($4, class_name),
        display_order = COALESCE($5, display_order),
        status = COALESCE($6, status),
        updated_at = timezone('utc', now())
       WHERE id = $1 AND organization_id = $2 AND school_id = $3
       RETURNING *`,
      [
        classId,
        organizationId,
        schoolId,
        input.className?.trim() ?? null,
        input.displayOrder ?? null,
        input.status ?? null,
      ],
    );
    return rows[0]!;
  } catch (error) {
    if (input.className &&
      (String(error).includes("classes_academic_year_id_class_name_key") ||
        String(error).includes("duplicate key"))) {
      throw new DuplicateClassError(input.className, existing.academic_year_id);
    }
    throw error;
  }
}
