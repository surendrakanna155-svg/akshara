// School configuration data access — school scope.
//
// One row per school holds the capability gating the Smart School Discovery
// wizard produces. Reads return null when a school has not yet configured
// (the app then falls back to its sensible default). Writes upsert the single
// row keyed on school_id.

import type { TenantQueryClient } from "../tenant_db.ts";

// ── Tenant-isolation probes (QA-R-004 — per-school configuration isolation) ───
// Configuration is school-scoped (RLS: organization_id = tenant AND scope =
// 'school' AND school_id = current_school). School A must read only its own
// configuration row and never School B's.
export const SCHOOL_CONFIGURATION_PROBE_SCHOOL_A = "e2000000-0000-4000-8000-000000000001";
export const SCHOOL_CONFIGURATION_PROBE_SCHOOL_B = "e2000000-0000-4000-8000-000000000002";
export const SCHOOL_CONFIGURATION_PROBE_SQL = `
  SELECT count(*)::text AS count FROM school_configuration WHERE id = $1::uuid
`;

export interface SchoolConfigRow {
  schoolType: string;
  curriculum: string;
  operationsModel: string;
  branchCount: number;
  capabilities: Record<string, unknown>;
  configuredAt: string;
}

interface RawRow {
  school_type: string;
  curriculum: string;
  operations_model: string;
  branch_count: number;
  capabilities: Record<string, unknown>;
  configured_at: string;
}

export interface SchoolConfigInput {
  schoolType: string;
  curriculum: string;
  operationsModel: string;
  branchCount: number;
  capabilities: Record<string, unknown>;
}

function map(row: RawRow): SchoolConfigRow {
  return {
    schoolType: row.school_type,
    curriculum: row.curriculum,
    operationsModel: row.operations_model,
    branchCount: Number(row.branch_count),
    capabilities: row.capabilities ?? {},
    configuredAt: new Date(row.configured_at).toISOString(),
  };
}

/** Reads the school's configuration, or null when it has never been set. */
export async function getSchoolConfig(
  db: TenantQueryClient,
  schoolId: string,
): Promise<SchoolConfigRow | null> {
  const rows = await db.queryObject<RawRow>(
    `SELECT school_type, curriculum, operations_model, branch_count,
            capabilities, configured_at
       FROM school_configuration
      WHERE school_id = $1
      LIMIT 1`,
    [schoolId],
  );
  const row = rows[0];
  return row ? map(row) : null;
}

/** Upserts the single configuration row for a school. */
export async function saveSchoolConfig(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  actorId: string,
  input: SchoolConfigInput,
): Promise<SchoolConfigRow> {
  const rows = await db.queryObject<RawRow>(
    `INSERT INTO school_configuration (
        organization_id, school_id, school_type, curriculum, operations_model,
        branch_count, capabilities, configured_by, configured_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8, timezone('utc', now()))
      ON CONFLICT (school_id) DO UPDATE SET
        school_type = EXCLUDED.school_type,
        curriculum = EXCLUDED.curriculum,
        operations_model = EXCLUDED.operations_model,
        branch_count = EXCLUDED.branch_count,
        capabilities = EXCLUDED.capabilities,
        configured_by = EXCLUDED.configured_by,
        configured_at = timezone('utc', now())
      RETURNING school_type, curriculum, operations_model, branch_count,
                capabilities, configured_at`,
    [
      orgId,
      schoolId,
      input.schoolType,
      input.curriculum,
      input.operationsModel,
      input.branchCount,
      JSON.stringify(input.capabilities ?? {}),
      actorId,
    ],
  );
  return map(rows[0]);
}
