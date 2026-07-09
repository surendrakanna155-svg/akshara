import type { TenantQueryClient } from "../tenant_db.ts";
import type { WhatsAppProviderConfig, WhatsAppProviderType } from "./whatsapp_providers.ts";

export interface WhatsAppConfigRow {
  id: string;
  organization_id: string;
  school_id: string;
  provider: WhatsAppProviderType;
  sender_id: string | null;
  api_key_ref: string | null;
  template_namespace: string | null;
  is_active: boolean;
}

export async function getWhatsAppProviderConfig(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<WhatsAppConfigRow | null> {
  const rows = await db.queryObject<WhatsAppConfigRow>(
    `SELECT * FROM whatsapp_provider_configs WHERE organization_id = $1 AND school_id = $2`,
    [orgId, schoolId],
  );
  return rows[0] ?? null;
}

export async function upsertWhatsAppProviderConfig(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: {
    provider: WhatsAppProviderType;
    senderId?: string;
    apiKeyRef?: string;
    templateNamespace?: string;
    isActive?: boolean;
    createdBy: string;
  },
): Promise<WhatsAppConfigRow> {
  const rows = await db.queryObject<WhatsAppConfigRow>(
    `INSERT INTO whatsapp_provider_configs (
       organization_id, school_id, provider, sender_id, api_key_ref,
       template_namespace, is_active, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     ON CONFLICT (organization_id, school_id)
     DO UPDATE SET
       provider = EXCLUDED.provider,
       sender_id = EXCLUDED.sender_id,
       api_key_ref = EXCLUDED.api_key_ref,
       template_namespace = EXCLUDED.template_namespace,
       is_active = EXCLUDED.is_active,
       updated_at = timezone('utc', now())
     RETURNING *`,
    [
      orgId,
      schoolId,
      input.provider,
      input.senderId ?? null,
      input.apiKeyRef ?? null,
      input.templateNamespace ?? null,
      input.isActive ?? true,
      input.createdBy,
    ],
  );
  return rows[0]!;
}

export function whatsAppConfigToApi(row: WhatsAppConfigRow | null): WhatsAppProviderConfig & { id?: string } {
  if (!row) {
    // GAP-P1-9: no row means no admin has ever configured a real provider for
    // this school. Reporting isActive:true here (the prior default) told the
    // school-admin status screen ("Status: Active") that WhatsApp was live when
    // it was actually a placeholder that never sends anything.
    return { provider: "stub", senderId: null, apiKeyRef: null, templateNamespace: null, isActive: false };
  }
  return {
    id: row.id,
    provider: row.provider,
    senderId: row.sender_id,
    apiKeyRef: row.api_key_ref ? "***" : null,
    templateNamespace: row.template_namespace,
    isActive: row.is_active,
  };
}

export function whatsAppConfigToRuntime(row: WhatsAppConfigRow | null): WhatsAppProviderConfig {
  if (!row) {
    // isActive:true (deliberately, unlike whatsAppConfigToApi's default above)
    // so an unconfigured school's send attempt reaches sendWhatsAppMessage's
    // "stub" branch and returns its specific "not configured" error, instead
    // of short-circuiting on the generic "provider is inactive" guard. Either
    // way the result is success:false — never a fabricated "sent".
    return { provider: "stub", senderId: null, apiKeyRef: null, templateNamespace: null, isActive: true };
  }
  return {
    provider: row.provider,
    senderId: row.sender_id,
    apiKeyRef: row.api_key_ref,
    templateNamespace: row.template_namespace,
    isActive: row.is_active,
  };
}
