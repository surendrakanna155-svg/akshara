import type { TenantQueryClient } from "../tenant_db.ts";
import {
  clampPageSize,
  offsetFor,
  type PaginationParams,
  type PaginationResult,
} from "./academic_pagination.ts";

export const ACADEMIC_YEAR_SCHOOL_A = "ce100000-0000-4000-8000-000000000001";
export const ACADEMIC_YEAR_SCHOOL_B = "ce100000-0000-4000-8000-000000000002";

/** SQL fragment used by tenant isolation probes for academic year visibility. */
export const ACADEMIC_YEARS_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM academic_years
`;

/** SQL fragment used by API-layer tenant isolation probes (list). */
export const ACADEMIC_YEARS_API_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM academic_years ay
  WHERE ay.organization_id = app_current_tenant_id()
    AND ay.school_id = app_current_school_id()
`;

/** SQL fragment used by API-layer tenant isolation probes (detail/update by id). */
export const ACADEMIC_YEAR_DETAIL_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM academic_years
  WHERE id = $1
`;

export interface AcademicYearRow {
  id: string;
  organization_id: string;
  school_id: string;
  year_label: string;
  start_date: string;
  startDate?: string;
  end_date: string;
  endDate?: string;
  is_current: boolean;
  status: string;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateAcademicYearInput {
  yearLabel: string;
  startDate: string;
  endDate: string;
  isCurrent?: boolean;
  status?: string;
  createdBy: string;
}

export interface UpdateAcademicYearInput {
  yearLabel?: string;
  startDate?: string;
  endDate?: string;
  isCurrent?: boolean;
  status?: string;
}

export interface AcademicYearListFilters {
  status?: string;
  isCurrent?: boolean;
}

export class DuplicateAcademicYearLabelError extends Error {
  constructor(label: string) {
    super(`Academic year label already exists: ${label}`);
    this.name = "DuplicateAcademicYearLabelError";
  }
}

export class AcademicYearNotFoundError extends Error {
  constructor(id: string) {
    super(`Academic year not found: ${id}`);
    this.name = "AcademicYearNotFoundError";
  }
}

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ValidationError";
  }
}

export class ConcurrentCurrentYearError extends Error {
  constructor(schoolId: string) {
    super(`Only one current academic year is allowed per school: ${schoolId}`);
    this.name = "ConcurrentCurrentYearError";
  }
}

function isDuplicateCurrentYearError(error: unknown): boolean {
  const message = String(error);
  return message.includes("academic_years_one_current_per_school") ||
    (message.includes("duplicate key") && message.includes("is_current"));
}

function assertValidDates(startDate: string, endDate: string): void {
  if (endDate < startDate) {
    throw new ValidationError("endDate must be on or after startDate");
  }
}

async function clearCurrentYear(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  exceptId?: string,
): Promise<void> {
  const args: unknown[] = [organizationId, schoolId];
  let sql = `UPDATE academic_years SET is_current = false, updated_at = timezone('utc', now())
             WHERE organization_id = $1 AND school_id = $2 AND is_current = true`;
  if (exceptId) {
    sql += ` AND id <> $3`;
    args.push(exceptId);
  }
  await db.queryObject(sql, args);
}

export async function listAcademicYears(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<AcademicYearRow[]> {
  return await db.queryObject<AcademicYearRow>(
    `SELECT * FROM academic_years
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY start_date DESC, year_label ASC`,
    [organizationId, schoolId],
  );
}

export async function getAcademicYear(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  yearId: string,
): Promise<AcademicYearRow | null> {
  const rows = await db.queryObject<AcademicYearRow>(
    `SELECT * FROM academic_years
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [yearId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function listAcademicYearsPage(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filters: AcademicYearListFilters,
  pagination: PaginationParams,
): Promise<PaginationResult<AcademicYearRow>> {
  const limit = clampPageSize(pagination.pageSize);
  const offset = offsetFor(pagination.page, limit);
  const conditions = ["organization_id = $1", "school_id = $2"];
  const args: unknown[] = [organizationId, schoolId];

  if (filters.status) {
    conditions.push(`status = $${args.length + 1}`);
    args.push(filters.status);
  }
  if (filters.isCurrent !== undefined) {
    conditions.push(`is_current = $${args.length + 1}`);
    args.push(filters.isCurrent);
  }

  const where = conditions.join(" AND ");
  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM academic_years WHERE ${where}`,
    args,
  );
  const items = await db.queryObject<AcademicYearRow>(
    `SELECT * FROM academic_years
     WHERE ${where}
     ORDER BY start_date DESC, year_label ASC
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

export async function createAcademicYear(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateAcademicYearInput,
): Promise<AcademicYearRow> {
  assertValidDates(input.startDate, input.endDate);
  const status = input.status ?? "active";
  const isCurrent = input.isCurrent ?? false;

  if (isCurrent) {
    await clearCurrentYear(db, organizationId, schoolId);
  }

  try {
    const rows = await db.queryObject<AcademicYearRow>(
      `INSERT INTO academic_years (
        organization_id, school_id, year_label, start_date, end_date,
        is_current, status, created_by
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING *`,
      [
        organizationId,
        schoolId,
        input.yearLabel.trim(),
        input.startDate,
        input.endDate,
        isCurrent,
        status,
        input.createdBy,
      ],
    );
    return rows[0]!;
  } catch (error) {
    if (String(error).includes("academic_years_school_id_year_label_key") ||
      (String(error).includes("duplicate key") &&
        String(error).includes("year_label"))) {
      throw new DuplicateAcademicYearLabelError(input.yearLabel);
    }
    if (isDuplicateCurrentYearError(error)) {
      throw new ConcurrentCurrentYearError(schoolId);
    }
    throw error;
  }
}

export async function updateAcademicYear(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  yearId: string,
  input: UpdateAcademicYearInput,
): Promise<AcademicYearRow> {
  const existing = await getAcademicYear(db, organizationId, schoolId, yearId);
  if (!existing) throw new AcademicYearNotFoundError(yearId);

  const startDate = input.startDate ?? existing.start_date;
  const endDate = input.endDate ?? existing.end_date;
  assertValidDates(startDate, endDate);

  if (input.isCurrent === true) {
    await clearCurrentYear(db, organizationId, schoolId, yearId);
  }

  try {
    const rows = await db.queryObject<AcademicYearRow>(
      `UPDATE academic_years SET
        year_label = COALESCE($4, year_label),
        start_date = COALESCE($5, start_date),
        end_date = COALESCE($6, end_date),
        is_current = COALESCE($7, is_current),
        status = COALESCE($8, status),
        updated_at = timezone('utc', now())
       WHERE id = $1 AND organization_id = $2 AND school_id = $3
       RETURNING *`,
      [
        yearId,
        organizationId,
        schoolId,
        input.yearLabel?.trim() ?? null,
        input.startDate ?? null,
        input.endDate ?? null,
        input.isCurrent ?? null,
        input.status ?? null,
      ],
    );
    return rows[0]!;
  } catch (error) {
    if (input.yearLabel &&
      (String(error).includes("academic_years_school_id_year_label_key") ||
        (String(error).includes("duplicate key") &&
          String(error).includes("year_label")))) {
      throw new DuplicateAcademicYearLabelError(input.yearLabel);
    }
    if (isDuplicateCurrentYearError(error)) {
      throw new ConcurrentCurrentYearError(schoolId);
    }
    throw error;
  }
}
