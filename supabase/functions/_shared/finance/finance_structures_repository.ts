import type { TenantQueryClient } from "../tenant_db.ts";
import { resolveAcademicPlacement } from "../academic/academic_catalog_resolver.ts";
import type {
  FeeStructureItemInput,
  FinanceFeeStructureItemRow,
  FinanceFeeStructureRow,
} from "./finance_mapper.ts";

export interface PaginationParams {
  page: number;
  pageSize: number;
}

export interface PaginationResult<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

export interface FeeStructureWithItems {
  structure: FinanceFeeStructureRow;
  items: FinanceFeeStructureItemRow[];
}

export interface CreateFeeStructureInput {
  name: string;
  academicYear: string;
  academicYearId?: string | null;
  description: string | null;
  status: string;
  createdBy: string;
  items: FeeStructureItemInput[];
}

export interface UpdateFeeStructureInput {
  name?: string;
  academicYear?: string;
  academicYearId?: string | null;
  description?: string | null;
  status?: string;
  items?: FeeStructureItemInput[];
}

function offsetFor(page: number, pageSize: number): number {
  return Math.max(0, (page - 1) * pageSize);
}

async function loadItemsForStructure(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  structureId: string,
): Promise<FinanceFeeStructureItemRow[]> {
  return await db.queryObject<FinanceFeeStructureItemRow>(
    `SELECT * FROM finance_fee_structure_items
     WHERE fee_structure_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY sort_order ASC, created_at ASC`,
    [structureId, organizationId, schoolId],
  );
}

async function insertItems(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  structureId: string,
  items: FeeStructureItemInput[],
): Promise<void> {
  for (const item of items) {
    await db.queryObject(
      `INSERT INTO finance_fee_structure_items (
        fee_structure_id, organization_id, school_id, fee_head, amount, sort_order
      ) VALUES ($1, $2, $3, $4, $5, $6)`,
      [
        structureId,
        organizationId,
        schoolId,
        item.feeHead,
        item.amount,
        item.sortOrder,
      ],
    );
  }
}

export async function listFeeStructures(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  pagination: PaginationParams,
  academicYear?: string,
): Promise<PaginationResult<FeeStructureWithItems>> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = offsetFor(pagination.page, limit);

  const filters = ["organization_id = $1", "school_id = $2"];
  const args: unknown[] = [organizationId, schoolId];

  if (academicYear) {
    filters.push(`academic_year = $${args.length + 1}`);
    args.push(academicYear);
  }

  const where = filters.join(" AND ");

  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM finance_fee_structures WHERE ${where}`,
    args,
  );

  const structures = await db.queryObject<FinanceFeeStructureRow>(
    `SELECT * FROM finance_fee_structures
     WHERE ${where}
     ORDER BY created_at DESC
     LIMIT $${args.length + 1} OFFSET $${args.length + 2}`,
    [...args, limit, offset],
  );

  const items: FeeStructureWithItems[] = [];
  for (const structure of structures) {
    const structureItems = await loadItemsForStructure(
      db,
      organizationId,
      schoolId,
      structure.id,
    );
    items.push({ structure, items: structureItems });
  }

  return {
    items,
    total,
    page: pagination.page,
    pageSize: limit,
    hasMore: offset + structures.length < total,
  };
}

export async function getFeeStructure(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  structureId: string,
): Promise<FeeStructureWithItems | null> {
  const rows = await db.queryObject<FinanceFeeStructureRow>(
    `SELECT * FROM finance_fee_structures
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [structureId, organizationId, schoolId],
  );
  const structure = rows[0];
  if (!structure) return null;

  const items = await loadItemsForStructure(
    db,
    organizationId,
    schoolId,
    structureId,
  );
  return { structure, items };
}

export async function createFeeStructure(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateFeeStructureInput,
): Promise<FeeStructureWithItems> {
  const placement = await resolveAcademicPlacement(
    { db, organizationId, schoolId },
    {
      academicYear: input.academicYear,
      academicYearId: input.academicYearId,
    },
    { mode: "year_only" },
  );

  const rows = await db.queryObject<FinanceFeeStructureRow>(
    `INSERT INTO finance_fee_structures (
      organization_id, school_id, name, academic_year, academic_year_id,
      description, status, created_by
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    RETURNING *`,
    [
      organizationId,
      schoolId,
      input.name,
      placement.academicYear,
      placement.academicYearId,
      input.description,
      input.status,
      input.createdBy,
    ],
  );
  const structure = rows[0]!;

  if (input.items.length > 0) {
    await insertItems(db, organizationId, schoolId, structure.id, input.items);
  }

  const items = await loadItemsForStructure(
    db,
    organizationId,
    schoolId,
    structure.id,
  );
  return { structure, items };
}

export async function updateFeeStructure(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  structureId: string,
  input: UpdateFeeStructureInput,
): Promise<FeeStructureWithItems | null> {
  const existing = await getFeeStructure(db, organizationId, schoolId, structureId);
  if (!existing) return null;

  const name = input.name ?? existing.structure.name;
  const academicYearInput = input.academicYear ?? existing.structure.academic_year;
  const academicYearIdInput = input.academicYearId !== undefined
    ? input.academicYearId
    : existing.structure.academic_year_id;
  const placement = await resolveAcademicPlacement(
    { db, organizationId, schoolId },
    {
      academicYear: academicYearInput,
      academicYearId: academicYearIdInput,
    },
    { mode: "year_only" },
  );
  const description = input.description !== undefined
    ? input.description
    : existing.structure.description;
  const status = input.status ?? existing.structure.status;

  const rows = await db.queryObject<FinanceFeeStructureRow>(
    `UPDATE finance_fee_structures SET
      name = $4,
      academic_year = $5,
      academic_year_id = $6,
      description = $7,
      status = $8,
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3
    RETURNING *`,
    [
      structureId,
      organizationId,
      schoolId,
      name,
      placement.academicYear,
      placement.academicYearId,
      description,
      status,
    ],
  );
  const structure = rows[0]!;

  if (input.items) {
    await db.queryObject(
      `DELETE FROM finance_fee_structure_items
       WHERE fee_structure_id = $1 AND organization_id = $2 AND school_id = $3`,
      [structureId, organizationId, schoolId],
    );
    if (input.items.length > 0) {
      await insertItems(db, organizationId, schoolId, structureId, input.items);
    }
  }

  const items = await loadItemsForStructure(
    db,
    organizationId,
    schoolId,
    structureId,
  );
  return { structure, items };
}

export async function archiveFeeStructure(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  structureId: string,
): Promise<FeeStructureWithItems | null> {
  return await updateFeeStructure(db, organizationId, schoolId, structureId, {
    status: "inactive",
  });
}
