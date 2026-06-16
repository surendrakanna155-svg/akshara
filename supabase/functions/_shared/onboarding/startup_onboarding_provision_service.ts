import type { TenantQueryClient } from "../tenant_db.ts";
import { createAcademicYear, type AcademicYearRow } from "../academic/academic_years_repository.ts";
import { createClass, DuplicateClassError } from "../academic/classes_repository.ts";
import { createSection, DuplicateSectionError } from "../academic/sections_repository.ts";
import { createFeeStructure } from "../finance/finance_structures_repository.ts";
import { encodeFeeHead } from "../finance/finance_mapper.ts";
import { upsertSchoolBranding } from "../school_completion/branding_repository.ts";
import type { StartupOnboardingRow } from "./startup_onboarding_repository.ts";

export interface StartupOnboardingProvisionResult {
  schoolProfileUpdated: boolean;
  brandingUpdated: boolean;
  academicYearId?: string;
  classIds: string[];
  sectionIds: string[];
  feeStructureIds: string[];
  warnings: string[];
  provisioned: boolean;
}

function parseAcademicYearBounds(yearLabel: string): { startDate: string; endDate: string } {
  const match = yearLabel.match(/(\d{4})\D+(\d{2,4})/);
  if (match) {
    const startYear = Number(match[1]);
    let endYear = Number(match[2]);
    if (endYear < 100) endYear = Math.floor(startYear / 100) * 100 + endYear;
    if (endYear <= startYear) endYear = startYear + 1;
    return {
      startDate: `${startYear}-04-01`,
      endDate: `${endYear}-03-31`,
    };
  }
  const startYear = new Date().getFullYear();
  return {
    startDate: `${startYear}-04-01`,
    endDate: `${startYear + 1}-03-31`,
  };
}

async function findAcademicYearByLabel(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  yearLabel: string,
): Promise<AcademicYearRow | null> {
  const rows = await db.queryObject<AcademicYearRow>(
    `SELECT * FROM academic_years
     WHERE organization_id = $1 AND school_id = $2 AND year_label = $3
     LIMIT 1`,
    [organizationId, schoolId, yearLabel],
  );
  return rows[0] ?? null;
}

async function updateSchoolProfile(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  row: StartupOnboardingRow,
): Promise<boolean> {
  const settings = {
    startupOnboarding: {
      board: row.board,
      curriculum: row.curriculum,
      address: row.address,
      contactPhone: row.contact_phone,
      contactEmail: row.contact_email,
      defaultLanguage: row.default_language,
      modulesEnabled: row.modules_enabled,
      feeModel: row.fee_model,
      brandingPreferences: row.branding_preferences,
      provisionedAt: new Date().toISOString(),
    },
  };
  const updated = await db.queryObject<{ id: string }>(
    `UPDATE schools SET
       name = $3,
       settings = coalesce(settings, '{}'::jsonb) || $4::jsonb,
       updated_at = timezone('utc', now())
     WHERE organization_id = $1 AND id = $2 AND deleted_at IS NULL
     RETURNING id`,
    [organizationId, schoolId, row.school_name, JSON.stringify(settings)],
  );
  return updated.length > 0;
}

export async function provisionSchoolFromStartupOnboarding(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  userId: string,
  row: StartupOnboardingRow,
): Promise<StartupOnboardingProvisionResult> {
  const warnings: string[] = [];
  const classIds: string[] = [];
  const sectionIds: string[] = [];
  const feeStructureIds: string[] = [];

  const schoolProfileUpdated = await updateSchoolProfile(db, organizationId, schoolId, row);
  if (!schoolProfileUpdated) {
    warnings.push("School profile row not updated — verify school scope");
  }

  await upsertSchoolBranding(db, organizationId, schoolId, {
    displayName: row.school_name,
    tagline: row.board || row.curriculum,
    primaryColor: row.theme_primary,
    secondaryColor: row.theme_secondary,
    logoUrl: row.logo_url || undefined,
  });

  const bounds = parseAcademicYearBounds(row.academic_year);
  let academicYear = await findAcademicYearByLabel(
    db,
    organizationId,
    schoolId,
    row.academic_year,
  );
  if (!academicYear) {
    try {
      academicYear = await createAcademicYear(db, organizationId, schoolId, {
        yearLabel: row.academic_year,
        startDate: bounds.startDate,
        endDate: bounds.endDate,
        isCurrent: true,
        createdBy: userId,
      });
    } catch (error) {
      academicYear = await findAcademicYearByLabel(
        db,
        organizationId,
        schoolId,
        row.academic_year,
      );
      if (!academicYear) {
        warnings.push(`Academic year provisioning failed: ${String(error)}`);
      } else {
        warnings.push(`Academic year ${row.academic_year} already exists — reused`);
      }
    }
  }

  if (academicYear) {
    for (const [idx, className] of row.classes.entries()) {
      let classId: string | undefined;
      try {
        const cls = await createClass(db, organizationId, schoolId, {
          academicYearId: academicYear.id,
          className,
          displayOrder: idx,
          createdBy: userId,
        });
        classId = cls.id;
        classIds.push(cls.id);
      } catch (error) {
        if (error instanceof DuplicateClassError) {
          const existing = await db.queryObject<{ id: string }>(
            `SELECT id FROM classes
             WHERE organization_id = $1 AND school_id = $2
               AND academic_year_id = $3 AND class_name = $4
             LIMIT 1`,
            [organizationId, schoolId, academicYear.id, className],
          );
          classId = existing[0]?.id;
          if (classId) {
            classIds.push(classId);
            warnings.push(`Class ${className} already exists — reused`);
          }
        } else {
          warnings.push(`Class ${className} skipped: ${String(error)}`);
        }
      }

      if (!classId) continue;

      for (const sectionName of row.sections) {
        try {
          const section = await createSection(db, organizationId, schoolId, {
            classId,
            sectionName,
            capacity: 40,
            createdBy: userId,
          });
          sectionIds.push(section.id);
        } catch (error) {
          if (error instanceof DuplicateSectionError) {
            warnings.push(`Section ${sectionName} for ${className} already exists — skipped`);
          } else {
            warnings.push(`Section ${sectionName} for ${className} skipped: ${String(error)}`);
          }
        }
      }
    }
  }

  const feeStructureName = `${row.fee_model.replaceAll("_", " ")} fees`;
  try {
    const fee = await createFeeStructure(db, organizationId, schoolId, {
      name: feeStructureName,
      academicYear: row.academic_year,
      academicYearId: academicYear?.id ?? null,
      description: "Auto-provisioned from startup onboarding",
      status: "draft",
      createdBy: userId,
      items: row.fee_categories.map((category, idx) => ({
        feeHead: encodeFeeHead("tuition", category),
        amount: 0,
        sortOrder: idx,
      })),
    });
    feeStructureIds.push(fee.structure.id);
  } catch (error) {
    warnings.push(`Fee structure provisioning skipped: ${String(error)}`);
  }

  return {
    schoolProfileUpdated,
    brandingUpdated: true,
    academicYearId: academicYear?.id,
    classIds,
    sectionIds,
    feeStructureIds,
    warnings,
    provisioned: schoolProfileUpdated && Boolean(academicYear?.id),
  };
}
