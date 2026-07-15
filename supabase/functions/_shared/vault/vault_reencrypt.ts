// PRC-A cap 45 — one-off maintenance routine: upgrades legacy
// (`key_version = 1`, reversible Base64) `platform_secret_vault` rows to
// AES-256-GCM (`key_version = 2`, see `vault_crypto.ts`).
//
// Idempotent + non-destructive by construction:
//   - only ever SELECTs rows still at the legacy key_version;
//   - the UPDATE re-affirms `key_version = 1` in its WHERE clause, so a row
//     converted by a concurrent run (or already upgraded via `rotateSecret`)
//     is simply not written twice;
//   - a second full run over an already-converted vault finds nothing to
//     convert (`scanned = 0`);
//   - per-row try/catch: one bad row (corrupt legacy payload, transient DB
//     hiccup) is counted as `failed` and skipped — it can NEVER abort the
//     batch or lose the row's existing (still-legacy, still-readable)
//     ciphertext. Nothing is deleted; a failed row is left exactly as it was.
//
// `reencryptLegacyVaultSecrets` is the pure, DB-shaped core (same
// `PlatformQueryClient` seam as the rest of `vault_service.ts`, so it is
// testable with the repo's fake-DB idiom with no live database).
// `handleReencryptVaultSecrets` is a small HTTP entrypoint mirroring the
// existing `managePlatformVault` handlers in
// `../control_center/platform_providers_handlers.ts` (same
// authenticateRequest → requirePermission → withPlatformContext shape).
//
// PRC-A caps 44-49: this handler IS wired into the router
// (`control_center_router.ts` → POST /control-center/vault/reencrypt`) — the
// header note above about it not being wired was stale. It ran on
// `withTenantContext` (the `erp_tenant` connection), which has no grant on
// `platform_secret_vault`, so it always failed `permission denied` in
// production exactly like the other vault handlers; rewired to
// `withPlatformContext` here.

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import { authenticateRequest, requirePermission } from "../permission_middleware.ts";
import {
  PlatformDbNotConfiguredError,
  platformDbNotConfiguredResponse,
  PlatformScopeDeniedError,
  type PlatformQueryClient,
  withPlatformContext,
} from "../platform_db.ts";
import { decryptLegacyBase64, encryptSecretV2, isV2Ciphertext } from "./vault_crypto.ts";
import { VAULT_CURRENT_KEY_VERSION, VAULT_LEGACY_KEY_VERSION, type VaultSecretRow } from "./vault_service.ts";

export interface VaultReencryptionReport {
  scanned: number;
  converted: number;
  skipped: number;
  failed: number;
  failedIds: string[];
}

/**
 * Scans `platform_secret_vault` for `key_version = 1` (legacy Base64) rows,
 * decrypts and re-encrypts each with AES-256-GCM, and writes back
 * `key_version = 2`. Safe to run repeatedly (idempotent) and safe to run
 * mid-traffic (per-row, non-transactional — a failure on one row never
 * touches another).
 */
export async function reencryptLegacyVaultSecrets(
  db: PlatformQueryClient,
): Promise<VaultReencryptionReport> {
  const rows = await db.queryObject<VaultSecretRow>(
    `SELECT * FROM platform_secret_vault WHERE key_version = $1`,
    [VAULT_LEGACY_KEY_VERSION],
  );

  const report: VaultReencryptionReport = {
    scanned: rows.length,
    converted: 0,
    skipped: 0,
    failed: 0,
    failedIds: [],
  };

  for (const row of rows) {
    try {
      // Belt-and-braces idempotency: even though the SELECT filtered on
      // key_version=1, a row whose ciphertext is already v2-shaped (e.g.
      // converted by a concurrent run, or a legacy key_version that was
      // never bumped when the string was already AES) is left untouched.
      if (isV2Ciphertext(row.encrypted_payload)) {
        report.skipped++;
        continue;
      }
      const plaintext = decryptLegacyBase64(row.encrypted_payload);
      const reencrypted = await encryptSecretV2(plaintext);
      const updated = await db.queryObject<{ id: string }>(
        `UPDATE platform_secret_vault
         SET encrypted_payload = $2, key_version = $3, updated_at = now()
         WHERE id = $1 AND key_version = $4
         RETURNING id`,
        [row.id, reencrypted, VAULT_CURRENT_KEY_VERSION, VAULT_LEGACY_KEY_VERSION],
      );
      if (updated.length > 0) {
        report.converted++;
      } else {
        // Someone else converted it between our SELECT and UPDATE — not a
        // failure, just already done.
        report.skipped++;
      }
    } catch (_error) {
      // Never abort the batch and never drop the row's existing (still
      // legacy, still readable) ciphertext — just count it and move on.
      report.failed++;
      report.failedIds.push(row.id);
    }
  }

  return report;
}

/**
 * HTTP entrypoint for the routine above, shaped exactly like the existing
 * `managePlatformVault` handlers (`handleRotateVaultSecret` /
 * `handleCheckVaultHealth` in `platform_providers_handlers.ts`) — wired into
 * `control_center_router.ts` at `POST /control-center/vault/reencrypt`.
 */
export async function handleReencryptVaultSecrets(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "managePlatformVault");
  if (denied) return denied;

  try {
    const report = await withPlatformContext(config, auth.claims, (db) =>
      reencryptLegacyVaultSecrets(db)
    );
    return jsonResponse(envelope(report));
  } catch (error) {
    if (error instanceof PlatformDbNotConfiguredError) return platformDbNotConfiguredResponse(error);
    if (error instanceof PlatformScopeDeniedError) return errorEnvelope("FORBIDDEN", error.message, 403);
    return errorEnvelope("INTERNAL_ERROR", String(error), 500);
  }
}
