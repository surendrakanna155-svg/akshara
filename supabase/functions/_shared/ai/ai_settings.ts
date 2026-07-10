// Resolve the effective AI runtime config (provider + model + key).
//
// DB-first: an admin configures the AI provider, model, and key from the
// Control Center → Providers panel (platform_provider_configs + the secret
// vault). When a usable panel config exists it wins; otherwise we fall back to
// the env values (AI_PROVIDER / *_API_KEY / *_MODEL). Either way, no key for the
// active provider = callers use their safe deterministic/stub output.

import type { TenantQueryClient } from "../tenant_db.ts";
import { decryptCredential } from "../vault/vault_service.ts";
import {
  aiApiKey,
  type AiProvider,
  aiProvider,
  claudeModel,
  DEFAULT_CLAUDE_MODEL,
  DEFAULT_OPENROUTER_MODEL,
} from "./anthropic_client.ts";

export interface AiRuntimeConfig {
  provider: AiProvider;
  model: string;
  apiKey?: string;
  /** Where the config came from — for telemetry/debugging only. */
  source: "panel" | "env";
  /**
   * The raw admin-saved provider `config` JSON (panel source only), so the
   * Model Gateway can read per-school governance knobs (rate limits, monthly
   * spend cap) without a second query. Undefined for the env fallback.
   */
  rawConfig?: Record<string, unknown> | null;
}

/** Map a stored provider_name to an AiProvider our client can actually call. */
function mapProviderName(name: string): AiProvider | null {
  switch (name.toLowerCase()) {
    case "openrouter":
      return "openrouter";
    case "anthropic":
    case "claude":
      return "anthropic";
    default:
      // openai / gemini / stub aren't callable by callClaude — fall back to env.
      return null;
  }
}

function envConfig(): AiRuntimeConfig {
  return { provider: aiProvider(), model: claudeModel(), apiKey: aiApiKey(), source: "env" };
}

interface AiConfigRow {
  provider_name: string;
  config: Record<string, unknown> | null;
  encrypted_payload: string | null;
}

/**
 * Resolve provider/model/key, preferring the admin-saved panel config (the
 * active, primary AI provider for this org) over env. Never throws, and never
 * poisons the caller's transaction: the panel lookup runs inside a SAVEPOINT, so
 * a failed query (e.g. the tenant role lacking SELECT on the platform tables)
 * rolls back to the savepoint and we fall through to env — leaving the
 * surrounding transaction usable.
 */
export async function resolveAiConfig(
  db: TenantQueryClient,
  orgId?: string | null,
): Promise<AiRuntimeConfig> {
  const SP = "ai_cfg_lookup";
  let savepointOpen = false;
  try {
    await db.queryObject(`SAVEPOINT ${SP}`);
    savepointOpen = true;
    const rows = await db.queryObject<AiConfigRow>(
      `SELECT pc.provider_name, pc.config, sv.encrypted_payload
         FROM platform_provider_configs pc
         LEFT JOIN platform_secret_vault sv ON sv.id = pc.vault_secret_id
        WHERE pc.provider_category = 'ai' AND pc.is_active = true
          AND (pc.organization_id = $1 OR pc.organization_id IS NULL)
        ORDER BY (pc.organization_id IS NOT NULL) DESC, pc.is_primary DESC, pc.updated_at DESC
        LIMIT 1`,
      [orgId ?? null],
    );
    await db.queryObject(`RELEASE SAVEPOINT ${SP}`);
    savepointOpen = false;
    const row = rows[0];
    if (row?.encrypted_payload) {
      const provider = mapProviderName(row.provider_name);
      if (provider) {
        const apiKey = decryptCredential(row.encrypted_payload).trim();
        const cfgModel = typeof row.config?.model === "string"
          ? (row.config.model as string).trim()
          : "";
        const model = cfgModel ||
          (provider === "openrouter" ? DEFAULT_OPENROUTER_MODEL : DEFAULT_CLAUDE_MODEL);
        if (apiKey) {
          return { provider, model, apiKey, source: "panel", rawConfig: row.config ?? null };
        }
      }
    }
  } catch {
    // Roll the failed statement back to the savepoint so the surrounding
    // transaction stays usable, then fall through to env.
    if (savepointOpen) {
      try {
        await db.queryObject(`ROLLBACK TO SAVEPOINT ${SP}`);
      } catch {
        // ignore — best effort
      }
    }
  }
  return envConfig();
}
