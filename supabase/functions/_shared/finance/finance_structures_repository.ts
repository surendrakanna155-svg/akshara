import type { TenantQueryClient } from "../tenant_db.ts";
import {
  CatalogMismatchError,
  CatalogNotFoundError,
  resolveAcademicClass,
  resolveAcademicPlacement,
  resolveAcademicSection,
  type ResolverContext,
  type YearResolveResult,
} from "../academic/academic_catalog_resolver.ts";
import { getClass } from "../academic/classes_repository.ts";
import { getSection, getSectionWithClass } from "../academic/sections_repository.ts";
import type {
  FeeStructureClassBindingLabels,
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
  // Cap 67 — resolved class/section display labels for a bound structure
  // (null when unbound); carried alongside the row so callers (handlers) can
  // pass them straight into feeStructureToApi without a second lookup.
  classBinding: FeeStructureClassBindingLabels;
}

export interface CreateFeeStructureInput {
  name: string;
  academicYear: string;
  academicYearId?: string | null;
  // Cap 67 — real class/section binding (either id resolves directly, or a
  // label is resolved against the structure's academic year, exactly like
  // academicYearId/academicYear above). Both omitted = unbound (unchanged
  // existing behaviour).
  classId?: string | null;
  className?: string | null;
  sectionId?: string | null;
  sectionName?: string | null;
  description: string | null;
  status: string;
  createdBy: string;
  items: FeeStructureItemInput[];
}

export interface UpdateFeeStructureInput {
  name?: string;
  academicYear?: string;
  academicYearId?: string | null;
  // Cap 67 — undefined on ALL FOUR of these = binding left unchanged.
  // `classId === null` (explicit) = unbind (clears class AND section).
  // Otherwise, whichever fields are provided are (re)resolved.
  classId?: string | null;
  className?: string | null;
  sectionId?: string | null;
  sectionName?: string | null;
  description?: string | null;
  status?: string;
  items?: FeeStructureItemInput[];
}

function offsetFor(page: number, pageSize: number): number {
  return Math.max(0, (page - 1) * pageSize);
}

interface ClassSectionBindingInput {
  classId?: string | null;
  className?: string | null;
  sectionId?: string | null;
  sectionName?: string | null;
}

interface ClassSectionBindingResult {
  classId: string | null;
  sectionId: string | null;
}

/**
 * Cap 67 — resolves an OPTIONAL class/section binding for a fee structure.
 * Mirrors resolveAcademicPlacement's id-or-label resolution (same catalog,
 * same validation — "do NOT invent a new class model") but stays fully
 * additive: when none of the four fields are set, this isn't even called by
 * the caller, and a structure never gets a binding it didn't ask for.
 *
 * A section given WITHOUT a class is resolved by looking the section's OWN
 * class up (`getSectionWithClass`) rather than requiring the caller to
 * redundantly also pass the class — the section authoritatively determines
 * its class, same as `validatePlacementHierarchy`'s backfill in the shared
 * resolver.
 */
async function resolveClassSectionBinding(
  ctx: ResolverContext,
  year: YearResolveResult,
  input: ClassSectionBindingInput,
): Promise<ClassSectionBindingResult> {
  const wantsClass = Boolean(input.classId?.trim() || input.className?.trim());
  const wantsSection = Boolean(input.sectionId?.trim() || input.sectionName?.trim());

  if (!wantsClass && !wantsSection) {
    return { classId: null, sectionId: null };
  }

  if (!wantsClass && wantsSection) {
    const sectionId = input.sectionId?.trim();
    if (!sectionId) {
      throw new CatalogMismatchError(
        "classId or className is required to resolve a section by name",
      );
    }
    const section = await getSectionWithClass(ctx.db, ctx.organizationId, ctx.schoolId, sectionId);
    if (!section) {
      throw new CatalogNotFoundError(`Catalog not found: section ${sectionId}`);
    }
    if (year.academicYearId && section.academic_year_id !== year.academicYearId) {
      throw new CatalogMismatchError(
        `Section ${sectionId} does not belong to academic year ${year.academicYearId}`,
      );
    }
    return { classId: section.class_id, sectionId: section.id };
  }

  const cls = await resolveAcademicClass(ctx, input, year, { mode: "full" });
  if (!wantsSection) {
    return { classId: cls.classId, sectionId: null };
  }
  const section = await resolveAcademicSection(ctx, input, cls, { mode: "full" });
  return { classId: cls.classId, sectionId: section.sectionId };
}

/** Cap 67 — looks up display labels for a (possibly unbound) class/section. */
async function resolveClassSectionLabels(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  classId: string | null,
  sectionId: string | null,
): Promise<FeeStructureClassBindingLabels> {
  if (!classId) return { className: null, sectionName: null };
  const [cls, section] = await Promise.all([
    getClass(db, organizationId, schoolId, classId),
    sectionId ? getSection(db, organizationId, schoolId, sectionId) : Promise.resolve(null),
  ]);
  return {
    className: cls?.class_name ?? null,
    sectionName: section?.section_name ?? null,
  };
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
    const classBinding = await resolveClassSectionLabels(
      db,
      organizationId,
      schoolId,
      structure.class_id,
      structure.section_id,
    );
    items.push({ structure, items: structureItems, classBinding });
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
  const classBinding = await resolveClassSectionLabels(
    db,
    organizationId,
    schoolId,
    structure.class_id,
    structure.section_id,
  );
  return { structure, items, classBinding };
}

/**
 * Sets a fee structure's status (approval-center decision path). Fee structures
 * are created `inactive` when approval is required and only go `active` once the
 * decision is approved; reject leaves them `inactive`. Returns the row, or null
 * when absent. Idempotent.
 */
export async function setFeeStructureStatus(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  structureId: string,
  status: "active" | "inactive",
): Promise<FinanceFeeStructureRow | null> {
  const rows = await db.queryObject<FinanceFeeStructureRow>(
    `UPDATE finance_fee_structures
        SET status = $4, updated_at = timezone('utc', now())
      WHERE id = $1 AND organization_id = $2 AND school_id = $3
      RETURNING *`,
    [structureId, organizationId, schoolId, status],
  );
  return rows[0] ?? null;
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

  // Cap 67 — OPTIONAL class/section binding, resolved against the SAME
  // academic year just placed above. Neither field set = unbound, exactly
  // today's behaviour.
  const binding = await resolveClassSectionBinding(
    { db, organizationId, schoolId },
    { academicYearId: placement.academicYearId, academicYear: placement.academicYear },
    {
      classId: input.classId,
      className: input.className,
      sectionId: input.sectionId,
      sectionName: input.sectionName,
    },
  );

  const rows = await db.queryObject<FinanceFeeStructureRow>(
    `INSERT INTO finance_fee_structures (
      organization_id, school_id, name, academic_year, academic_year_id,
      class_id, section_id, description, status, created_by
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
    RETURNING *`,
    [
      organizationId,
      schoolId,
      input.name,
      placement.academicYear,
      placement.academicYearId,
      binding.classId,
      binding.sectionId,
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
  const classBinding = await resolveClassSectionLabels(
    db,
    organizationId,
    schoolId,
    structure.class_id,
    structure.section_id,
  );
  return { structure, items, classBinding };
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

  // Cap 67 — undefined on ALL FOUR binding fields = leave the existing
  // binding exactly as-is (no resolver call at all — a status-only or
  // name-only PATCH must never accidentally touch the class/section link).
  // `classId === null` explicitly = unbind. Anything else = re-resolve.
  const bindingFieldsProvided = input.classId !== undefined ||
    input.className !== undefined ||
    input.sectionId !== undefined ||
    input.sectionName !== undefined;
  let classId = existing.structure.class_id;
  let sectionId = existing.structure.section_id;
  if (bindingFieldsProvided) {
    if (input.classId === null) {
      classId = null;
      sectionId = null;
    } else {
      const binding = await resolveClassSectionBinding(
        { db, organizationId, schoolId },
        { academicYearId: placement.academicYearId, academicYear: placement.academicYear },
        {
          classId: input.classId,
          className: input.className,
          sectionId: input.sectionId,
          sectionName: input.sectionName,
        },
      );
      classId = binding.classId;
      sectionId = binding.sectionId;
    }
  }

  const rows = await db.queryObject<FinanceFeeStructureRow>(
    `UPDATE finance_fee_structures SET
      name = $4,
      academic_year = $5,
      academic_year_id = $6,
      class_id = $7,
      section_id = $8,
      description = $9,
      status = $10,
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
      classId,
      sectionId,
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
  const classBinding = await resolveClassSectionLabels(
    db,
    organizationId,
    schoolId,
    structure.class_id,
    structure.section_id,
  );
  return { structure, items, classBinding };
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
