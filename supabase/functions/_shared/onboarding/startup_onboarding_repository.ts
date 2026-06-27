import type { StartupOnboardingProvisionResult } from "./startup_onboarding_provision_service.ts";
import { provisionSchoolFromStartupOnboarding } from "./startup_onboarding_provision_service.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

export interface StartupOnboardingRow {
  id: string;
  organization_id: string;
  school_id: string;
  current_step: string;
  school_name: string;
  board: string;
  curriculum: string;
  address: string;
  contact_phone: string;
  contact_email: string;
  academic_year: string;
  classes: string[];
  sections: string[];
  fee_model: string;
  fee_categories: string[];
  logo_url: string;
  theme_primary: string;
  theme_secondary: string;
  branding_preferences: Record<string, unknown>;
  default_language: string;
  modules_enabled: string[];
  is_live: boolean;
  go_live_at: string | null;
  updated_at: string;
}

export interface StartupOnboardingPayload {
  currentStep?: string;
  schoolName?: string;
  board?: string;
  curriculum?: string;
  address?: string;
  contactPhone?: string;
  contactEmail?: string;
  academicYear?: string;
  classes?: string[];
  sections?: string[];
  feeModel?: string;
  feeCategories?: string[];
  logoUrl?: string;
  themePrimary?: string;
  themeSecondary?: string;
  brandingPreferences?: Record<string, unknown>;
  defaultLanguage?: string;
  modulesEnabled?: string[];
}

export function rowToApi(row: StartupOnboardingRow) {
  return {
    id: row.id,
    currentStep: row.current_step,
    schoolName: row.school_name,
    board: row.board,
    curriculum: row.curriculum,
    address: row.address,
    contactPhone: row.contact_phone,
    contactEmail: row.contact_email,
    academicYear: row.academic_year,
    classes: row.classes,
    sections: row.sections,
    feeModel: row.fee_model,
    feeCategories: row.fee_categories,
    logoUrl: row.logo_url,
    themePrimary: row.theme_primary,
    themeSecondary: row.theme_secondary,
    brandingPreferences: row.branding_preferences,
    defaultLanguage: row.default_language,
    modulesEnabled: row.modules_enabled,
    isLive: row.is_live,
    goLiveAt: row.go_live_at,
    lastSavedAt: row.updated_at,
  };
}

export function validateForGoLive(row: StartupOnboardingRow): string[] {
  const errors: string[] = [];
  if (!row.school_name.trim()) errors.push("School name is required");
  if (!row.board.trim() && !row.curriculum.trim()) {
    errors.push("Board or curriculum is required");
  }
  if (!row.address.trim()) errors.push("School address is required");
  if (!row.contact_phone.trim() && !row.contact_email.trim()) {
    errors.push("Contact phone or email is required");
  }
  if (!row.academic_year.trim()) errors.push("Academic year is required");
  if (!row.classes.length) errors.push("At least one class is required");
  if (!row.sections.length) errors.push("At least one section is required");
  if (!row.fee_model.trim()) errors.push("Fee model is required");
  if (!row.fee_categories.length) errors.push("At least one fee category is required");
  if (!row.default_language.trim()) errors.push("Default language is required");
  if (!row.theme_primary.trim()) errors.push("Primary theme colour is required");
  return errors;
}

export async function getStartupOnboarding(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<StartupOnboardingRow | null> {
  const rows = await db.queryObject<StartupOnboardingRow>(
    `SELECT * FROM startup_onboarding
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function upsertStartupOnboarding(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  userId: string,
  payload: StartupOnboardingPayload,
): Promise<StartupOnboardingRow> {
  const existing = await getStartupOnboarding(db, organizationId, schoolId);
  if (!existing) {
    const rows = await db.queryObject<StartupOnboardingRow>(
      `INSERT INTO startup_onboarding (
         organization_id, school_id, current_step, school_name, board, curriculum,
         address, contact_phone, contact_email, academic_year, classes, sections,
         fee_model, fee_categories, logo_url, theme_primary, theme_secondary,
         branding_preferences, default_language, modules_enabled, created_by, updated_by
       ) VALUES (
         $1, $2,
         coalesce($3, 'schoolProfile'),
         coalesce($4, ''),
         coalesce($5, ''),
         coalesce($6, 'CBSE'),
         coalesce($7, ''),
         coalesce($8, ''),
         coalesce($9, ''),
         coalesce($10, ''),
         coalesce($11::jsonb, '[]'::jsonb),
         coalesce($12::jsonb, '[]'::jsonb),
         coalesce($13, ''),
         coalesce($14::jsonb, '[]'::jsonb),
         coalesce($15, ''),
         coalesce($16, '#1565C0'),
         coalesce($17, '#42A5F5'),
         coalesce($18::jsonb, '{}'::jsonb),
         coalesce($19, 'en'),
         coalesce($20::jsonb, '["sis","finance","attendance"]'::jsonb),
         $21, $21
       )
       RETURNING *`,
      [
        organizationId,
        schoolId,
        payload.currentStep ?? null,
        payload.schoolName ?? null,
        payload.board ?? null,
        payload.curriculum ?? null,
        payload.address ?? null,
        payload.contactPhone ?? null,
        payload.contactEmail ?? null,
        payload.academicYear ?? null,
        payload.classes ? JSON.stringify(payload.classes) : null,
        payload.sections ? JSON.stringify(payload.sections) : null,
        payload.feeModel ?? null,
        payload.feeCategories ? JSON.stringify(payload.feeCategories) : null,
        payload.logoUrl ?? null,
        payload.themePrimary ?? null,
        payload.themeSecondary ?? null,
        payload.brandingPreferences ? JSON.stringify(payload.brandingPreferences) : null,
        payload.defaultLanguage ?? null,
        payload.modulesEnabled ? JSON.stringify(payload.modulesEnabled) : null,
        userId,
      ],
    );
    return rows[0]!;
  }

  const merged: StartupOnboardingPayload = {
    currentStep: payload.currentStep ?? existing.current_step,
    schoolName: payload.schoolName ?? existing.school_name,
    board: payload.board ?? existing.board,
    curriculum: payload.curriculum ?? existing.curriculum,
    address: payload.address ?? existing.address,
    contactPhone: payload.contactPhone ?? existing.contact_phone,
    contactEmail: payload.contactEmail ?? existing.contact_email,
    academicYear: payload.academicYear ?? existing.academic_year,
    classes: payload.classes ?? existing.classes,
    sections: payload.sections ?? existing.sections,
    feeModel: payload.feeModel ?? existing.fee_model,
    feeCategories: payload.feeCategories ?? existing.fee_categories,
    logoUrl: payload.logoUrl ?? existing.logo_url,
    themePrimary: payload.themePrimary ?? existing.theme_primary,
    themeSecondary: payload.themeSecondary ?? existing.theme_secondary,
    brandingPreferences: payload.brandingPreferences ?? existing.branding_preferences,
    defaultLanguage: payload.defaultLanguage ?? existing.default_language,
    modulesEnabled: payload.modulesEnabled ?? existing.modules_enabled,
  };

  const rows = await db.queryObject<StartupOnboardingRow>(
    `UPDATE startup_onboarding SET
       current_step = $3,
       school_name = $4,
       board = $5,
       curriculum = $6,
       address = $7,
       contact_phone = $8,
       contact_email = $9,
       academic_year = $10,
       classes = $11::jsonb,
       sections = $12::jsonb,
       fee_model = $13,
       fee_categories = $14::jsonb,
       logo_url = $15,
       theme_primary = $16,
       theme_secondary = $17,
       branding_preferences = $18::jsonb,
       default_language = $19,
       modules_enabled = $20::jsonb,
       updated_by = $21,
       updated_at = timezone('utc', now())
     WHERE organization_id = $1 AND school_id = $2
     RETURNING *`,
    [
      organizationId,
      schoolId,
      merged.currentStep,
      merged.schoolName,
      merged.board,
      merged.curriculum,
      merged.address,
      merged.contactPhone,
      merged.contactEmail,
      merged.academicYear,
      JSON.stringify(merged.classes ?? []),
      JSON.stringify(merged.sections ?? []),
      merged.feeModel,
      JSON.stringify(merged.feeCategories ?? []),
      merged.logoUrl,
      merged.themePrimary,
      merged.themeSecondary,
      JSON.stringify(merged.brandingPreferences ?? {}),
      merged.defaultLanguage,
      JSON.stringify(merged.modulesEnabled ?? []),
      userId,
    ],
  );
  return rows[0]!;
}

export function provisionToApi(result: StartupOnboardingProvisionResult) {
  return {
    schoolProfileUpdated: result.schoolProfileUpdated,
    brandingUpdated: result.brandingUpdated,
    academicYearId: result.academicYearId,
    classCount: result.classIds.length,
    sectionCount: result.sectionIds.length,
    feeStructureCount: result.feeStructureIds.length,
    subjectCount: result.subjectIds.length,
    syllabusTopicsCreated: result.syllabusTopicsCreated,
    capabilitiesApplied: result.capabilitiesApplied,
    warnings: result.warnings,
    provisioned: result.provisioned,
  };
}

export async function goLiveStartupOnboarding(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  userId: string,
): Promise<{
  row: StartupOnboardingRow | null;
  errors: string[];
  provision?: StartupOnboardingProvisionResult;
}> {
  const existing = await getStartupOnboarding(db, organizationId, schoolId);
  if (!existing) {
    return { row: null, errors: ["Onboarding not started"] };
  }
  const errors = validateForGoLive(existing);
  if (errors.length > 0) {
    return { row: existing, errors };
  }

  const provision = await provisionSchoolFromStartupOnboarding(
    db,
    organizationId,
    schoolId,
    userId,
    existing,
  );

  const rows = await db.queryObject<StartupOnboardingRow>(
    `UPDATE startup_onboarding SET
       is_live = true,
       current_step = 'goLive',
       go_live_at = timezone('utc', now()),
       updated_by = $3,
       updated_at = timezone('utc', now())
     WHERE organization_id = $1 AND school_id = $2
     RETURNING *`,
    [organizationId, schoolId, userId],
  );
  return { row: rows[0] ?? null, errors: [], provision };
}
