import type { TenantQueryClient } from "../tenant_db.ts";
import { createAcademicYear, type AcademicYearRow } from "../academic/academic_years_repository.ts";
import { createClass } from "../academic/classes_repository.ts";
import { createSection } from "../academic/sections_repository.ts";
import { createFeeStructure } from "../finance/finance_structures_repository.ts";
import { encodeFeeHead } from "../finance/finance_mapper.ts";
import { upsertSchoolBranding } from "../school_completion/branding_repository.ts";
import { createSubject } from "../school_completion/subjects_repository.ts";
import { generateSyllabusFromTemplates } from "../school_completion/syllabus_automation_service.ts";
import { getSchoolConfig, saveSchoolConfig } from "../school_config/school_config_repository.ts";
import type { StartupOnboardingRow } from "./startup_onboarding_repository.ts";

export interface StartupOnboardingProvisionResult {
  schoolProfileUpdated: boolean;
  brandingUpdated: boolean;
  academicYearId?: string;
  classIds: string[];
  sectionIds: string[];
  feeStructureIds: string[];
  subjectIds: string[];
  syllabusTopicsCreated: number;
  capabilitiesApplied: boolean;
  warnings: string[];
  provisioned: boolean;
}

/**
 * G1 — translate the founder's selected modules into the 8 `school_configuration`
 * capability flags, so the choice made during onboarding actually drives the
 * runtime gate (nav / dashboard / API / search / notifications / AI all read
 * `school_configuration.capabilities`, not `schools.settings.modules_enabled`).
 *
 * The optional 8 flags mirror `entitlement_resolver.CAPABILITY_ENTITLEMENTS`.
 * A module is ON only when the founder enabled it; multiBranch / trustOrganization
 * stay OFF for a single-school go-live (set by the Organization Builder instead).
 */
function capabilitiesFromModules(modulesEnabled: string[]): Record<string, boolean> {
  const has = (...keys: string[]) =>
    keys.some((k) => modulesEnabled.includes(k));
  return {
    transport: has("transport"),
    hostel: has("hostel"),
    library: has("library"),
    inventory: has("inventory"),
    alumni: has("alumni"),
    hrPayroll: has("hr", "hr_payroll", "hrpayroll", "payroll"),
    multiBranch: false,
    trustOrganization: false,
  };
}

/**
 * Upserts `school_configuration` so the founder's module selection is the
 * authoritative capability set. Preserves any existing school_type / curriculum /
 * operations model / branch count when a Discovery-wizard row already exists.
 */
async function applyCapabilities(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  userId: string,
  row: StartupOnboardingRow,
): Promise<boolean> {
  const capabilities = capabilitiesFromModules(row.modules_enabled ?? []);
  const existing = await getSchoolConfig(db, schoolId);
  await saveSchoolConfig(db, organizationId, schoolId, userId, {
    schoolType: existing?.schoolType ?? "day_school",
    curriculum: existing?.curriculum ??
      (row.curriculum?.trim() || row.board?.trim() || "cbse").toLowerCase(),
    operationsModel: existing?.operationsModel ?? "single_school",
    branchCount: existing?.branchCount ?? 1,
    capabilities,
  });
  return true;
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
  // The edge `erp_tenant` role has SELECT-only on the core `schools` table, so
  // the write goes through a scoped SECURITY DEFINER function (it self-enforces
  // org⇄school scope). See migration 20260813000000.
  const updated = await db.queryObject<{ ok: boolean }>(
    `SELECT onboarding_update_school_profile($1, $2, $3, $4::jsonb) AS ok`,
    [organizationId, schoolId, row.school_name, JSON.stringify(settings)],
  );
  return updated[0]?.ok === true;
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
  const subjectIds: string[] = [];
  let syllabusTopicsCreated = 0;

  const schoolProfileUpdated = await updateSchoolProfile(db, organizationId, schoolId, row);
  if (!schoolProfileUpdated) {
    warnings.push("School profile row not updated — verify school scope");
  }

  // G1 — make the founder's module selection drive the runtime gate.
  let capabilitiesApplied = false;
  try {
    capabilitiesApplied = await applyCapabilities(db, organizationId, schoolId, userId, row);
  } catch (error) {
    warnings.push(`Capability gating not applied: ${String(error)}`);
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

  // Find-or-create (pre-check SELECT before INSERT). The whole provision runs in
  // ONE transaction, so a unique-violation — even one caught in JS — would abort
  // the transaction and fail every later statement. Pre-checking keeps go-live
  // idempotent: re-running reuses existing rows without ever raising a PG error.
  if (academicYear) {
    for (const [idx, className] of row.classes.entries()) {
      let classId: string | undefined;
      const existingCls = await db.queryObject<{ id: string }>(
        `SELECT id FROM classes
         WHERE organization_id = $1 AND school_id = $2
           AND academic_year_id = $3 AND class_name = $4
         LIMIT 1`,
        [organizationId, schoolId, academicYear.id, className],
      );
      if (existingCls[0]) {
        classId = existingCls[0].id;
        classIds.push(classId);
      } else {
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
          warnings.push(`Class ${className} skipped: ${String(error)}`);
        }
      }

      if (!classId) continue;

      for (const sectionName of row.sections) {
        const existingSec = await db.queryObject<{ id: string }>(
          `SELECT id FROM sections
           WHERE class_id = $1 AND section_name = $2 LIMIT 1`,
          [classId, sectionName],
        );
        if (existingSec[0]) {
          sectionIds.push(existingSec[0].id);
          continue;
        }
        try {
          const section = await createSection(db, organizationId, schoolId, {
            classId,
            sectionName,
            capacity: 40,
            createdBy: userId,
          });
          sectionIds.push(section.id);
        } catch (error) {
          warnings.push(`Section ${sectionName} for ${className} skipped: ${String(error)}`);
        }
      }
    }
  }

  // G8 — provision a default subject set (+ syllabus) so a school that goes live
  // via startup onboarding lands with subjects (teachers/exams/timetable need
  // them), matching the setup-wizard end-state instead of zero subjects.
  if (academicYear && classIds.length > 0) {
    const defaultSubjects = ["English", "Mathematics", "Science"];
    const gradeLabel = row.classes[0] ?? "Grade 1";
    for (const [idx, name] of defaultSubjects.entries()) {
      const code = `${name.slice(0, 3).toUpperCase().padEnd(3, "X")}${idx}`;
      // Find-or-create (pre-check) to stay idempotent within the single txn.
      const existingSubj = await db.queryObject<{ id: string }>(
        `SELECT id FROM academic_subjects
         WHERE organization_id = $1 AND school_id = $2 AND subject_code = $3 LIMIT 1`,
        [organizationId, schoolId, code],
      );
      if (existingSubj[0]) {
        subjectIds.push(existingSubj[0].id);
        continue;
      }
      try {
        const subject = await createSubject(db, organizationId, schoolId, {
          subjectCode: code,
          subjectName: name,
          category: "core",
          gradeLabels: row.classes,
          createdBy: userId,
        });
        subjectIds.push(subject.id);
        try {
          const syllabus = await generateSyllabusFromTemplates(db, organizationId, schoolId, {
            academicYearId: academicYear.id,
            className: gradeLabel,
            subjectId: subject.id,
            subjectName: name,
            gradeLabel,
            source: "template",
            createdBy: userId,
          });
          syllabusTopicsCreated += syllabus.topicsCreated;
        } catch {
          warnings.push(`Syllabus auto-generation skipped for ${name}`);
        }
      } catch {
        warnings.push(`Subject ${name} may already exist — skipped duplicate`);
      }
    }
  }

  const feeStructureName = `${row.fee_model.replaceAll("_", " ")} fees`;
  // Pre-check by name so a re-run reuses the draft instead of adding a duplicate.
  const existingFee = await db.queryObject<{ id: string }>(
    `SELECT id FROM finance_fee_structures
     WHERE organization_id = $1 AND school_id = $2 AND name = $3 LIMIT 1`,
    [organizationId, schoolId, feeStructureName],
  );
  if (existingFee[0]) {
    feeStructureIds.push(existingFee[0].id);
  } else {
    try {
      const fee = await createFeeStructure(db, organizationId, schoolId, {
        name: feeStructureName,
        academicYear: row.academic_year,
        academicYearId: academicYear?.id ?? null,
        description: "Auto-provisioned from startup onboarding",
        status: "inactive",
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
  }

  return {
    schoolProfileUpdated,
    brandingUpdated: true,
    academicYearId: academicYear?.id,
    classIds,
    sectionIds,
    feeStructureIds,
    subjectIds,
    syllabusTopicsCreated,
    capabilitiesApplied,
    warnings,
    provisioned: schoolProfileUpdated && Boolean(academicYear?.id),
  };
}
