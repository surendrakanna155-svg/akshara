/**
 * AcademicCatalogResolver v1
 *
 * Canonical placement resolver for SIS, Admissions, Finance, and future
 * Attendance / Timetable / Exams / Promotions / Teacher Workload modules.
 * Do not duplicate placement resolution logic elsewhere.
 */
import type { TenantQueryClient } from "../tenant_db.ts";
import { getClass } from "./classes_repository.ts";
import { getSection } from "./sections_repository.ts";
import {
  getAcademicYear,
  listAcademicYears,
  type AcademicYearRow,
} from "./academic_years_repository.ts";

export class CatalogNotFoundError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CatalogNotFoundError";
  }
}

export class CatalogMismatchError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CatalogMismatchError";
  }
}

export interface ResolverContext {
  db: TenantQueryClient;
  organizationId: string;
  schoolId: string;
}

export interface PlacementInput {
  academicYearId?: string | null;
  academicYear?: string | null;
  classId?: string | null;
  className?: string | null;
  sectionId?: string | null;
  sectionName?: string | null;
}

export type PlacementMode = "full" | "admissions" | "year_only";

export interface PlacementResolveOptions {
  mode: PlacementMode;
}

export interface YearResolveResult {
  academicYearId: string | null;
  academicYear: string;
}

export interface ClassResolveResult {
  classId: string | null;
  className: string;
}

export interface SectionResolveResult {
  sectionId: string | null;
  sectionName: string | null;
}

export interface PlacementResolveResult {
  academicYearId: string | null;
  academicYear: string;
  classId: string | null;
  className: string;
  sectionId: string | null;
  sectionName: string | null;
}

/** Matches Flutter `academic_year_label.dart` — trim, dash normalize, remove whitespace. */
export function normalizeAcademicYearLabel(label: string): string {
  return label
    .trim()
    .replaceAll("–", "-")
    .replaceAll("—", "-")
    .replaceAll(/\s+/g, "");
}

export function isEmptySection(value: string | null | undefined): boolean {
  return value == null || value.trim() === "";
}

function isEmptyYearLabel(value: string | null | undefined): boolean {
  if (value == null) return true;
  return normalizeAcademicYearLabel(value) === "";
}

function trimClassName(value: string | null | undefined): string {
  return value?.trim() ?? "";
}

function assertActiveOperationalStatus(
  entity: string,
  status: string,
  id: string,
): void {
  if (status !== "active") {
    throw new CatalogMismatchError(
      `Catalog row is not active: ${entity} ${id}`,
    );
  }
}

async function loadYearByLabel(
  ctx: ResolverContext,
  label: string,
): Promise<AcademicYearRow | null> {
  const normalized = normalizeAcademicYearLabel(label);
  if (!normalized) return null;
  const years = await listAcademicYears(ctx.db, ctx.organizationId, ctx.schoolId);
  const matches = years.filter((year) =>
    normalizeAcademicYearLabel(year.year_label) === normalized
  );
  if (matches.length > 1) {
    throw new CatalogMismatchError(
      `Ambiguous academic year label: ${label}`,
    );
  }
  return matches[0] ?? null;
}

async function loadClassByLabel(
  ctx: ResolverContext,
  academicYearId: string,
  className: string,
): Promise<{ id: string; class_name: string; status: string } | null> {
  const trimmed = className.trim();
  if (!trimmed) return null;
  const rows = await ctx.db.queryObject<{
    id: string;
    class_name: string;
    status: string;
  }>(
    `SELECT id, class_name, status FROM classes
     WHERE organization_id = $1 AND school_id = $2
       AND academic_year_id = $3 AND class_name = $4
     LIMIT 2`,
    [ctx.organizationId, ctx.schoolId, academicYearId, trimmed],
  );
  if (rows.length > 1) {
    throw new CatalogMismatchError(
      `Ambiguous class label: ${className}`,
    );
  }
  return rows[0] ?? null;
}

async function loadSectionByLabel(
  ctx: ResolverContext,
  classId: string,
  sectionName: string,
): Promise<{ id: string; section_name: string; status: string } | null> {
  const trimmed = sectionName.trim();
  if (!trimmed) return null;
  const rows = await ctx.db.queryObject<{
    id: string;
    section_name: string;
    status: string;
  }>(
    `SELECT id, section_name, status FROM sections
     WHERE organization_id = $1 AND school_id = $2
       AND class_id = $3 AND section_name = $4
     LIMIT 2`,
    [ctx.organizationId, ctx.schoolId, classId, trimmed],
  );
  if (rows.length > 1) {
    throw new CatalogMismatchError(
      `Ambiguous section label: ${sectionName}`,
    );
  }
  return rows[0] ?? null;
}

export async function resolveAcademicYear(
  ctx: ResolverContext,
  input: Pick<PlacementInput, "academicYearId" | "academicYear">,
  options: PlacementResolveOptions,
): Promise<YearResolveResult> {
  const yearId = input.academicYearId?.trim() || null;
  const yearLabelInput = input.academicYear ?? null;

  if (yearId) {
    const year = await getAcademicYear(
      ctx.db,
      ctx.organizationId,
      ctx.schoolId,
      yearId,
    );
    if (!year) {
      throw new CatalogNotFoundError(`Catalog not found: academic year ${yearId}`);
    }
    assertActiveOperationalStatus("academic_year", year.status, year.id);
    if (!isEmptyYearLabel(yearLabelInput)) {
      const normalizedInput = normalizeAcademicYearLabel(yearLabelInput!);
      const normalizedCatalog = normalizeAcademicYearLabel(year.year_label);
      if (normalizedInput !== normalizedCatalog) {
        throw new CatalogMismatchError(
          `Academic year label does not match catalog id: ${yearId}`,
        );
      }
    }
    return {
      academicYearId: year.id,
      academicYear: year.year_label,
    };
  }

  if (isEmptyYearLabel(yearLabelInput)) {
    if (options.mode === "admissions") {
      return { academicYearId: null, academicYear: "" };
    }
    throw new CatalogMismatchError("Academic year context is required");
  }

  const year = await loadYearByLabel(ctx, yearLabelInput!);
  if (!year) {
    throw new CatalogNotFoundError(
      `Catalog not found: academic year ${yearLabelInput}`,
    );
  }
  assertActiveOperationalStatus("academic_year", year.status, year.id);
  return {
    academicYearId: year.id,
    academicYear: year.year_label,
  };
}

export async function resolveAcademicClass(
  ctx: ResolverContext,
  input: Pick<PlacementInput, "classId" | "className">,
  year: YearResolveResult,
  options: PlacementResolveOptions,
): Promise<ClassResolveResult> {
  const classId = input.classId?.trim() || null;
  const classNameInput = input.className ?? null;

  if (options.mode === "year_only") {
    return { classId: null, className: "" };
  }

  if (options.mode === "admissions" && year.academicYearId == null) {
    return { classId: null, className: trimClassName(classNameInput) };
  }

  if (classId) {
    const cls = await getClass(ctx.db, ctx.organizationId, ctx.schoolId, classId);
    if (!cls) {
      throw new CatalogNotFoundError(`Catalog not found: class ${classId}`);
    }
    assertActiveOperationalStatus("class", cls.status, cls.id);
    if (year.academicYearId && cls.academic_year_id !== year.academicYearId) {
      throw new CatalogMismatchError(
        `Class ${classId} does not belong to academic year ${year.academicYearId}`,
      );
    }
    if (trimClassName(classNameInput)) {
      if (cls.class_name !== trimClassName(classNameInput)) {
        throw new CatalogMismatchError(
          `Class label does not match catalog id: ${classId}`,
        );
      }
    }
    return { classId: cls.id, className: cls.class_name };
  }

  const className = trimClassName(classNameInput);
  if (!className) {
    throw new CatalogMismatchError("Class name is required");
  }

  if (!year.academicYearId) {
    throw new CatalogMismatchError(
      "Academic year context is required for class label resolution",
    );
  }

  const cls = await loadClassByLabel(ctx, year.academicYearId, className);
  if (!cls) {
    throw new CatalogNotFoundError(
      `Catalog not found: class ${className}`,
    );
  }
  assertActiveOperationalStatus("class", cls.status, cls.id);
  return { classId: cls.id, className: cls.class_name };
}

export async function resolveAcademicSection(
  ctx: ResolverContext,
  input: Pick<PlacementInput, "sectionId" | "sectionName">,
  cls: ClassResolveResult,
  options: PlacementResolveOptions,
): Promise<SectionResolveResult> {
  const sectionId = input.sectionId?.trim() || null;
  const sectionNameInput = input.sectionName;

  if (isEmptySection(sectionNameInput) && !sectionId) {
    return { sectionId: null, sectionName: null };
  }

  if (
    options.mode === "admissions" &&
    !cls.classId &&
    !sectionId
  ) {
    return { sectionId: null, sectionName: null };
  }

  if (sectionId) {
    const section = await getSection(
      ctx.db,
      ctx.organizationId,
      ctx.schoolId,
      sectionId,
    );
    if (!section) {
      throw new CatalogNotFoundError(`Catalog not found: section ${sectionId}`);
    }
    assertActiveOperationalStatus("section", section.status, section.id);
    if (cls.classId && section.class_id !== cls.classId) {
      throw new CatalogMismatchError(
        `Section ${sectionId} does not belong to class ${cls.classId}`,
      );
    }
    if (!isEmptySection(sectionNameInput)) {
      if (section.section_name !== sectionNameInput!.trim()) {
        throw new CatalogMismatchError(
          `Section label does not match catalog id: ${sectionId}`,
        );
      }
    }
    return { sectionId: section.id, sectionName: section.section_name };
  }

  if (isEmptySection(sectionNameInput)) {
    return { sectionId: null, sectionName: null };
  }

  if (!cls.classId) {
    throw new CatalogMismatchError(
      "Class context is required for section label resolution",
    );
  }

  const section = await loadSectionByLabel(
    ctx,
    cls.classId,
    sectionNameInput!.trim(),
  );
  if (!section) {
    throw new CatalogNotFoundError(
      `Catalog not found: section ${sectionNameInput}`,
    );
  }
  assertActiveOperationalStatus("section", section.status, section.id);
  return { sectionId: section.id, sectionName: section.section_name };
}

export async function validatePlacementHierarchy(
  ctx: ResolverContext,
  result: PlacementResolveResult,
): Promise<void> {
  if (result.sectionId) {
    const section = await getSection(
      ctx.db,
      ctx.organizationId,
      ctx.schoolId,
      result.sectionId,
    );
    if (!section) {
      throw new CatalogMismatchError(
        `Hierarchy validation failed: section ${result.sectionId}`,
      );
    }
    if (
      section.organization_id !== ctx.organizationId ||
      section.school_id !== ctx.schoolId
    ) {
      throw new CatalogMismatchError(
        `Hierarchy validation failed: section ${result.sectionId}`,
      );
    }
    if (result.classId && section.class_id !== result.classId) {
      throw new CatalogMismatchError(
        `Section ${result.sectionId} does not belong to class ${result.classId}`,
      );
    }
    if (!result.classId) {
      result.classId = section.class_id;
    }
  }

  if (result.classId) {
    const cls = await getClass(ctx.db, ctx.organizationId, ctx.schoolId, result.classId);
    if (!cls) {
      throw new CatalogMismatchError(
        `Hierarchy validation failed: class ${result.classId}`,
      );
    }
    if (
      cls.organization_id !== ctx.organizationId ||
      cls.school_id !== ctx.schoolId
    ) {
      throw new CatalogMismatchError(
        `Hierarchy validation failed: class ${result.classId}`,
      );
    }
    if (result.academicYearId && cls.academic_year_id !== result.academicYearId) {
      throw new CatalogMismatchError(
        `Class ${result.classId} does not belong to academic year ${result.academicYearId}`,
      );
    }
    if (!result.academicYearId) {
      result.academicYearId = cls.academic_year_id;
    }
  }

  if (result.academicYearId) {
    const year = await getAcademicYear(
      ctx.db,
      ctx.organizationId,
      ctx.schoolId,
      result.academicYearId,
    );
    if (!year) {
      throw new CatalogMismatchError(
        `Hierarchy validation failed: academic year ${result.academicYearId}`,
      );
    }
    if (
      year.organization_id !== ctx.organizationId ||
      year.school_id !== ctx.schoolId
    ) {
      throw new CatalogMismatchError(
        `Hierarchy validation failed: academic year ${result.academicYearId}`,
      );
    }
  }
}

export async function resolveAcademicPlacement(
  ctx: ResolverContext,
  input: PlacementInput,
  options: PlacementResolveOptions,
): Promise<PlacementResolveResult> {
  const year = await resolveAcademicYear(ctx, input, options);

  if (options.mode === "year_only") {
    const result: PlacementResolveResult = {
      academicYearId: year.academicYearId,
      academicYear: year.academicYear,
      classId: null,
      className: "",
      sectionId: null,
      sectionName: null,
    };
    if (year.academicYearId) {
      await validatePlacementHierarchy(ctx, result);
    }
    return result;
  }

  const cls = await resolveAcademicClass(ctx, input, year, options);
  const section = await resolveAcademicSection(ctx, input, cls, options);

  const result: PlacementResolveResult = {
    academicYearId: year.academicYearId,
    academicYear: year.academicYear,
    classId: cls.classId,
    className: cls.className,
    sectionId: section.sectionId,
    sectionName: section.sectionName,
  };

  if (result.academicYearId || result.classId || result.sectionId) {
    await validatePlacementHierarchy(ctx, result);
  }

  return result;
}
