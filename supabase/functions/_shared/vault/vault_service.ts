import type { TenantQueryClient } from "../tenant_db.ts";

export interface VaultSecretRow {
  id: string;
  organization_id: string | null;
  provider_category: string;
  provider_name: string;
  encrypted_payload: string;
  key_version: number;
  health_status: string;
  last_health_check_at: string | null;
  last_rotated_at: string | null;
  failover_secret_id: string | null;
}

export interface ProviderConfigRow {
  id: string;
  organization_id: string | null;
  provider_category: string;
  provider_name: string;
  vault_secret_id: string | null;
  is_active: boolean;
  is_primary: boolean;
  config: Record<string, unknown>;
  health_status: string;
}

const SUPPORTED_PROVIDERS = {
  ai: ["openai", "claude", "gemini", "stub"],
  whatsapp: ["msg91", "gupshup", "stub"],
  sms: ["msg91", "stub"],
} as const;

export function encryptCredential(plaintext: string, _keyVersion = 1): string {
  return btoa(unescape(encodeURIComponent(plaintext)));
}

export function decryptCredential(encrypted: string): string {
  return decodeURIComponent(escape(atob(encrypted)));
}

export async function storeSecret(
  db: TenantQueryClient,
  input: {
    organizationId?: string;
    providerCategory: string;
    providerName: string;
    credential: string;
    actorUserId: string;
  },
): Promise<VaultSecretRow> {
  const encrypted = encryptCredential(input.credential);
  const rows = await db.queryObject<VaultSecretRow>(
    `INSERT INTO platform_secret_vault (
       organization_id, provider_category, provider_name, encrypted_payload, last_rotated_at
     ) VALUES ($1, $2, $3, $4, now())
     RETURNING *`,
    [input.organizationId ?? null, input.providerCategory, input.providerName, encrypted],
  );
  const secret = rows[0]!;
  await db.queryObject(
    `INSERT INTO platform_secret_audit_log (secret_id, action, actor_user_id, metadata)
     VALUES ($1, 'created', $2, $3::jsonb)`,
    [secret.id, input.actorUserId, JSON.stringify({ providerName: input.providerName })],
  );
  return secret;
}

export async function rotateSecret(
  db: TenantQueryClient,
  secretId: string,
  newCredential: string,
  actorUserId: string,
): Promise<VaultSecretRow> {
  const encrypted = encryptCredential(newCredential);
  const rows = await db.queryObject<VaultSecretRow>(
    `UPDATE platform_secret_vault
     SET encrypted_payload = $2, key_version = key_version + 1,
         last_rotated_at = now(), health_status = 'unknown', updated_at = now()
     WHERE id = $1 RETURNING *`,
    [secretId, encrypted],
  );
  await db.queryObject(
    `INSERT INTO platform_secret_audit_log (secret_id, action, actor_user_id)
     VALUES ($1, 'rotated', $2)`,
    [secretId, actorUserId],
  );
  return rows[0]!;
}

export async function checkSecretHealth(
  db: TenantQueryClient,
  secretId: string,
): Promise<{ healthy: boolean; status: string }> {
  const rows = await db.queryObject<VaultSecretRow>(
    `SELECT * FROM platform_secret_vault WHERE id = $1`,
    [secretId],
  );
  const secret = rows[0];
  if (!secret) return { healthy: false, status: "failed" };

  let healthy = false;
  try {
    const decrypted = decryptCredential(secret.encrypted_payload);
    healthy = decrypted.length > 0;
  } catch {
    healthy = false;
  }
  const status = healthy ? "healthy" : "failed";
  await db.queryObject(
    `UPDATE platform_secret_vault
     SET health_status = $2, last_health_check_at = now(), updated_at = now()
     WHERE id = $1`,
    [secretId, status],
  );
  await db.queryObject(
    `INSERT INTO platform_secret_audit_log (secret_id, action, metadata)
     VALUES ($1, 'health_check', $2::jsonb)`,
    [secretId, JSON.stringify({ status })],
  );
  return { healthy, status };
}

export async function resolveFailoverSecret(
  db: TenantQueryClient,
  secretId: string,
): Promise<VaultSecretRow | null> {
  const rows = await db.queryObject<VaultSecretRow>(
    `SELECT * FROM platform_secret_vault WHERE id = $1`,
    [secretId],
  );
  const primary = rows[0];
  if (!primary?.failover_secret_id) return primary ?? null;
  const failover = await db.queryObject<VaultSecretRow>(
    `SELECT * FROM platform_secret_vault WHERE id = $1`,
    [primary.failover_secret_id],
  );
  return failover[0] ?? primary;
}

export async function upsertProviderConfig(
  db: TenantQueryClient,
  input: {
    organizationId?: string;
    providerCategory: string;
    providerName: string;
    vaultSecretId?: string;
    isActive?: boolean;
    isPrimary?: boolean;
    config?: Record<string, unknown>;
  },
): Promise<ProviderConfigRow> {
  const category = input.providerCategory as keyof typeof SUPPORTED_PROVIDERS;
  if (!SUPPORTED_PROVIDERS[category]?.includes(input.providerName as never)) {
    throw new Error(`Unsupported provider: ${input.providerCategory}/${input.providerName}`);
  }

  if (input.isPrimary) {
    await db.queryObject(
      `UPDATE platform_provider_configs SET is_primary = false
       WHERE provider_category = $1 AND COALESCE(organization_id, '00000000-0000-4000-8000-000000000000'::uuid)
         = COALESCE($2::uuid, '00000000-0000-4000-8000-000000000000'::uuid)`,
      [input.providerCategory, input.organizationId ?? null],
    );
  }

  const existing = await db.queryObject<ProviderConfigRow>(
    `SELECT * FROM platform_provider_configs
     WHERE provider_category = $1 AND provider_name = $2
       AND COALESCE(organization_id, '00000000-0000-4000-8000-000000000000'::uuid)
           = COALESCE($3::uuid, '00000000-0000-4000-8000-000000000000'::uuid)`,
    [input.providerCategory, input.providerName, input.organizationId ?? null],
  );

  if (existing[0]) {
    const rows = await db.queryObject<ProviderConfigRow>(
      `UPDATE platform_provider_configs
       SET vault_secret_id = coalesce($2, vault_secret_id),
           is_active = coalesce($3, is_active),
           is_primary = coalesce($4, is_primary),
           config = coalesce($5::jsonb, config),
           updated_at = now()
       WHERE id = $1 RETURNING *`,
      [
        existing[0].id,
        input.vaultSecretId ?? null,
        input.isActive,
        input.isPrimary,
        input.config ? JSON.stringify(input.config) : null,
      ],
    );
    return rows[0]!;
  }

  const rows = await db.queryObject<ProviderConfigRow>(
    `INSERT INTO platform_provider_configs (
       organization_id, provider_category, provider_name, vault_secret_id,
       is_active, is_primary, config
     ) VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)
     RETURNING *`,
    [
      input.organizationId ?? null,
      input.providerCategory,
      input.providerName,
      input.vaultSecretId ?? null,
      input.isActive ?? true,
      input.isPrimary ?? false,
      JSON.stringify(input.config ?? {}),
    ],
  );
  return rows[0]!;
}

export async function listProviderConfigs(
  db: TenantQueryClient,
  organizationId?: string,
): Promise<ProviderConfigRow[]> {
  return await db.queryObject<ProviderConfigRow>(
    `SELECT id, organization_id, provider_category, provider_name, vault_secret_id,
            is_active, is_primary, config, health_status
     FROM platform_provider_configs
     WHERE organization_id IS NOT DISTINCT FROM $1::uuid
     ORDER BY provider_category, is_primary DESC`,
    [organizationId ?? null],
  );
}

export function providerConfigToApi(row: ProviderConfigRow) {
  return {
    id: row.id,
    providerCategory: row.provider_category,
    providerName: row.provider_name,
    hasCredential: row.vault_secret_id != null,
    isActive: row.is_active,
    isPrimary: row.is_primary,
    healthStatus: row.health_status,
    config: row.config,
  };
}

export function vaultSecretToApi(row: VaultSecretRow) {
  return {
    id: row.id,
    providerCategory: row.provider_category,
    providerName: row.provider_name,
    keyVersion: row.key_version,
    healthStatus: row.health_status,
    lastHealthCheckAt: row.last_health_check_at,
    lastRotatedAt: row.last_rotated_at,
    hasFailover: row.failover_secret_id != null,
  };
}
