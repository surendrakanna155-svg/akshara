import type { TenantQueryClient } from "../tenant_db.ts";
import type { SetupWizardInputs } from "./setup_wizard_service.ts";

export interface SetupWizardSessionRow {
  id: string;
  status: string;
  current_step: string;
  inputs: unknown;
  recommendations: unknown;
  warnings: unknown;
  missing_items: unknown;
}

/**
 * Create a new setup-wizard session row and return its id.
 */
export async function createSetupWizardSession(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  inputsJson: string,
  recommendationsJson: string,
  warningsJson: string,
  missingItemsJson: string,
  createdBy: string | undefined,
): Promise<string> {
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO setup_wizard_sessions (
       organization_id, school_id, inputs, recommendations, warnings, missing_items, created_by
     ) VALUES ($1, $2, $3::jsonb, $4::jsonb, $5::jsonb, $6::jsonb, $7)
     RETURNING id`,
    [
      organizationId,
      schoolId,
      inputsJson,
      recommendationsJson,
      warningsJson,
      missingItemsJson,
      createdBy,
    ],
  );
  return rows[0]!.id;
}

/**
 * Fetch a setup-wizard session by id, or undefined when it does not exist.
 */
export async function getSetupWizardSession(
  db: TenantQueryClient,
  sessionId: string,
): Promise<SetupWizardSessionRow | undefined> {
  const rows = await db.queryObject<SetupWizardSessionRow>(
    `SELECT id, status, current_step, inputs, recommendations, warnings, missing_items
     FROM setup_wizard_sessions WHERE id = $1`,
    [sessionId],
  );
  return rows[0];
}

/**
 * The stored `inputs` jsonb for a setup-wizard session, or null when the
 * session id does not exist.
 */
export async function getSetupWizardSessionInputs(
  db: TenantQueryClient,
  sessionId: string,
): Promise<SetupWizardInputs | null> {
  const rows = await db.queryObject<{ inputs: SetupWizardInputs }>(
    `SELECT inputs FROM setup_wizard_sessions WHERE id = $1`,
    [sessionId],
  );
  return rows[0]?.inputs ?? null;
}

/**
 * Persist the merged inputs/recommendations/warnings/missing-items and
 * advance the session's current step (and status, on completion).
 */
export async function updateSetupWizardSession(
  db: TenantQueryClient,
  sessionId: string,
  step: string,
  inputsJson: string,
  recommendationsJson: string,
  warningsJson: string,
  missingItemsJson: string,
  status: string,
): Promise<void> {
  await db.queryObject(
    `UPDATE setup_wizard_sessions
     SET current_step = $2, inputs = $3::jsonb, recommendations = $4::jsonb,
         warnings = $5::jsonb, missing_items = $6::jsonb, status = $7,
         updated_at = timezone('utc', now())
     WHERE id = $1`,
    [
      sessionId,
      step,
      inputsJson,
      recommendationsJson,
      warningsJson,
      missingItemsJson,
      status,
    ],
  );
}
