import type { TenantQueryClient } from "../tenant_db.ts";

export interface AcceptanceRow {
  policy_key: string;
  policy_version: string;
  accepted_at: string;
}

/** All policy versions this user has already accepted (RLS scopes to the user). */
export async function listAcceptances(
  db: TenantQueryClient,
  userId: string,
): Promise<AcceptanceRow[]> {
  return await db.queryObject<AcceptanceRow>(
    `SELECT policy_key, policy_version, accepted_at
       FROM legal_acceptances
      WHERE user_id = $1`,
    [userId],
  );
}

export interface RecordAcceptanceInput {
  organizationId: string;
  schoolId: string | null;
  userId: string;
  userRole: string;
  scope: string;
  policyKey: string;
  policyVersion: string;
  ipAddress: string | null;
  userAgent: string | null;
  deviceId: string | null;
}

/** Append-only insert; re-accepting the same version is a no-op. */
export async function insertAcceptance(
  db: TenantQueryClient,
  input: RecordAcceptanceInput,
): Promise<void> {
  await db.queryObject(
    `INSERT INTO legal_acceptances (
       organization_id, school_id, user_id, user_role, scope,
       policy_key, policy_version, ip_address, user_agent, device_id
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     ON CONFLICT (user_id, policy_key, policy_version) DO NOTHING`,
    [
      input.organizationId,
      input.schoolId,
      input.userId,
      input.userRole,
      input.scope,
      input.policyKey,
      input.policyVersion,
      input.ipAddress,
      input.userAgent,
      input.deviceId,
    ],
  );
}

/** Build a (policyKey → set of accepted versions) map from raw rows. */
export function acceptedVersionsByKey(
  rows: AcceptanceRow[],
): Map<string, Set<string>> {
  const map = new Map<string, Set<string>>();
  for (const row of rows) {
    const set = map.get(row.policy_key) ?? new Set<string>();
    set.add(row.policy_version);
    map.set(row.policy_key, set);
  }
  return map;
}
