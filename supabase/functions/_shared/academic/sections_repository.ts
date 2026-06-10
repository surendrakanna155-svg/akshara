import type { TenantQueryClient } from "../tenant_db.ts";
import { getClass } from "./classes_repository.ts";
import {
  clampPageSize,
  offsetFor,
  type PaginationParams,
  type PaginationResult,
} from "./academic_pagination.ts";

export const ACADEMIC_SECTION_SCHOOL_A = "d0100000-0000-4000-8000-000000000001";
export const ACADEMIC_SECTION_SCHOOL_B = "d0100000-0000-4000-8000-000000000003";

/** SQL fragment used by tenant isolation probes for section visibility. */
export const ACADEMIC_SECTIONS_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM sections
`;

/** SQL fragment used by API-layer tenant isolation probes (list). */
export const ACADEMIC_SECTIONS_API_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM sections s
  INNER JOIN classes c ON c.id = s.class_id
  WHERE s.organization_id = app_current_tenant_id()
    AND s.school_id = app_current_school_id()
`;

/** SQL fragment used by API-layer tenant isolation probes (detail/update by id). */
export const ACADEMIC_SECTION_DETAIL_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM sections s
  INNER JOIN classes c ON c.id = s.class_id
  WHERE s.id = $1
`;

export interface SectionRow {
  id: string;
  organization_id: string;
  school_id: string;
  class_id: string;
  section_name: string;
  capacity: number | null;
  strength: number;
  status: string;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface SectionListRow extends SectionRow {
  class_name: string;
  academic_year_id: string;
}

export interface CreateSectionInput {
  classId: string;
  sectionName: string;
  capacity?: number | null;
  strength?: number;
  status?: string;
  createdBy: string;
}

export interface UpdateSectionInput {
  sectionName?: string;
  capacity?: number | null;
  strength?: number;
  status?: string;
}

export interface SectionListFilters {
  classId?: string;
  academicYearId?: string;
  status?: string;
}

export class DuplicateSectionError extends Error {
  constructor(sectionName: string, classId: string) {
    super(`Section ${sectionName} already exists for class ${classId}`);
    this.name = "DuplicateSectionError";
  }
}

export class SectionNotFoundError extends Error {
  constructor(id: string) {
    super(`Section not found: ${id}`);
    this.name = "SectionNotFoundError";
  }
}

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ValidationError";
  }
}

async function assertClassInSchool(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  classId: string,
): Promise<void> {
  const row = await getClass(db, organizationId, schoolId, classId);
  if (!row) {
    throw new ValidationError(`Class not found in school scope: ${classId}`);
  }
}

export async function listSections(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  classId?: string,
): Promise<SectionRow[]> {
  const args: unknown[] = [organizationId, schoolId];
  let sql = `SELECT * FROM sections
             WHERE organization_id = $1 AND school_id = $2`;
  if (classId) {
    sql += ` AND class_id = $3`;
    args.push(classId);
  }
  sql += ` ORDER BY section_name ASC`;
  return await db.queryObject<SectionRow>(sql, args);
}

export async function getSection(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  sectionId: string,
): Promise<SectionRow | null> {
  const rows = await db.queryObject<SectionRow>(
    `SELECT * FROM sections
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [sectionId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function getSectionWithClass(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  sectionId: string,
): Promise<SectionListRow | null> {
  const rows = await db.queryObject<SectionListRow>(
    `SELECT
       s.*,
       c.class_name,
       c.academic_year_id
     FROM sections s
     INNER JOIN classes c ON c.id = s.class_id
     WHERE s.id = $1 AND s.organization_id = $2 AND s.school_id = $3`,
    [sectionId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function listSectionsPage(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filters: SectionListFilters,
  pagination: PaginationParams,
): Promise<PaginationResult<SectionListRow>> {
  const limit = clampPageSize(pagination.pageSize);
  const offset = offsetFor(pagination.page, limit);
  const conditions = ["s.organization_id = $1", "s.school_id = $2"];
  const args: unknown[] = [organizationId, schoolId];

  if (filters.classId) {
    conditions.push(`s.class_id = $${args.length + 1}`);
    args.push(filters.classId);
  }
  if (filters.academicYearId) {
    conditions.push(`c.academic_year_id = $${args.length + 1}`);
    args.push(filters.academicYearId);
  }
  if (filters.status) {
    conditions.push(`s.status = $${args.length + 1}`);
    args.push(filters.status);
  }

  const where = conditions.join(" AND ");
  const total = await db.queryCount(
    `SELECT count(*)::text AS count
     FROM sections s
     INNER JOIN classes c ON c.id = s.class_id
     WHERE ${where}`,
    args,
  );
  const items = await db.queryObject<SectionListRow>(
    `SELECT
       s.*,
       c.class_name,
       c.academic_year_id
     FROM sections s
     INNER JOIN classes c ON c.id = s.class_id
     WHERE ${where}
     ORDER BY c.display_order ASC, c.class_name ASC, s.section_name ASC
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

export async function createSection(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateSectionInput,
): Promise<SectionRow> {
  await assertClassInSchool(db, organizationId, schoolId, input.classId);
  const sectionName = input.sectionName.trim();
  if (!sectionName) throw new ValidationError("sectionName is required");
  const strength = input.strength ?? 0;

  try {
    const rows = await db.queryObject<SectionRow>(
      `INSERT INTO sections (
        organization_id, school_id, class_id, section_name, capacity, strength,
        status, created_by
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING *`,
      [
        organizationId,
        schoolId,
        input.classId,
        sectionName,
        input.capacity ?? null,
        strength,
        input.status ?? "active",
        input.createdBy,
      ],
    );
    return rows[0]!;
  } catch (error) {
    if (String(error).includes("sections_class_id_section_name_key") ||
      String(error).includes("duplicate key")) {
      throw new DuplicateSectionError(sectionName, input.classId);
    }
    throw error;
  }
}

export async function updateSection(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  sectionId: string,
  input: UpdateSectionInput,
): Promise<SectionRow> {
  const existing = await getSection(db, organizationId, schoolId, sectionId);
  if (!existing) throw new SectionNotFoundError(sectionId);

  try {
    const rows = await db.queryObject<SectionRow>(
      `UPDATE sections SET
        section_name = COALESCE($4, section_name),
        capacity = COALESCE($5, capacity),
        strength = COALESCE($6, strength),
        status = COALESCE($7, status),
        updated_at = timezone('utc', now())
       WHERE id = $1 AND organization_id = $2 AND school_id = $3
       RETURNING *`,
      [
        sectionId,
        organizationId,
        schoolId,
        input.sectionName?.trim() ?? null,
        input.capacity ?? null,
        input.strength ?? null,
        input.status ?? null,
      ],
    );
    return rows[0]!;
  } catch (error) {
    if (input.sectionName &&
      (String(error).includes("sections_class_id_section_name_key") ||
        String(error).includes("duplicate key"))) {
      throw new DuplicateSectionError(input.sectionName, existing.class_id);
    }
    throw error;
  }
}
