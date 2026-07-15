// PRC-A cap 45 — v1 -> v2 vault re-encryption maintenance routine.
//
// Proves, without a live DB (an in-memory `platform_secret_vault` mirroring
// the SELECT/UPDATE the routine issues, following this repo's fake-DB
// idiom of interpreting the SQL shape rather than a full SQL engine — see
// e.g. `finance/finance_fee_reductions_repository_test.ts`), that the
// routine:
//   - converts every legacy (key_version=1) row to AES-256-GCM (key_version=2);
//   - is idempotent — a second run over an already-converted vault finds
//     nothing left to scan/convert;
//   - skips (never re-writes) a row that is already v2-shaped even if its
//     key_version column is stale (defensive idempotency);
//   - isolates a per-row failure (corrupt legacy payload) — it's counted as
//     `failed` and left untouched, and does NOT abort the rest of the batch;
//   - refuses to convert (fails every row, but drops nothing) when
//     VAULT_ENC_KEY is unconfigured.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { encryptLegacyBase64, encryptSecretV2, isV2Ciphertext } from "./vault_crypto.ts";
import { reencryptLegacyVaultSecrets } from "./vault_reencrypt.ts";
import {
  VAULT_CURRENT_KEY_VERSION,
  VAULT_LEGACY_KEY_VERSION,
  type VaultSecretRow,
} from "./vault_service.ts";

const TEST_VAULT_KEY = "c".repeat(64); // 64 hex chars = 32 bytes

function clearVaultKey() {
  Deno.env.delete("VAULT_ENC_KEY");
}

function legacyRow(id: string, plaintext: string): VaultSecretRow {
  return {
    id,
    organization_id: null,
    provider_category: "ai",
    provider_name: "anthropic",
    encrypted_payload: encryptLegacyBase64(plaintext),
    key_version: VAULT_LEGACY_KEY_VERSION,
    health_status: "unknown",
    last_health_check_at: null,
    last_rotated_at: null,
    failover_secret_id: null,
  };
}

/**
 * Interprets the exact SELECT/UPDATE `reencryptLegacyVaultSecrets` issues and
 * mutates in-memory rows, so the tests exercise the real conversion logic
 * end to end with no live database.
 */
class FakeVaultDb {
  rows: VaultSecretRow[];
  constructor(rows: VaultSecretRow[]) {
    this.rows = rows;
  }

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, params: unknown[] = []): Promise<T[]> {
    const s = sql.trim();
    if (s.startsWith("SELECT") && s.includes("platform_secret_vault") && s.includes("key_version = $1")) {
      const version = params[0];
      // Snapshot (copy), like a real SELECT — mutating the copy later
      // shouldn't retroactively change what was "read".
      return this.rows.filter((r) => r.key_version === version).map((r) => ({ ...r })) as unknown as T[];
    }
    if (s.startsWith("UPDATE") && s.includes("platform_secret_vault") && s.includes("RETURNING id")) {
      const [id, encryptedPayload, newVersion, expectedVersion] = params as [string, string, number, number];
      const row = this.rows.find((r) => r.id === id && r.key_version === expectedVersion);
      if (!row) return [] as unknown as T[];
      row.encrypted_payload = encryptedPayload;
      row.key_version = newVersion;
      return [{ id }] as unknown as T[];
    }
    throw new Error(`FakeVaultDb: unexpected SQL in test: ${sql}`);
  }
}

Deno.test("reencryptLegacyVaultSecrets converts every v1 row to v2 and is idempotent on a second run", async () => {
  Deno.env.set("VAULT_ENC_KEY", TEST_VAULT_KEY);
  try {
    const db = new FakeVaultDb([
      legacyRow("s1", "sk-one"),
      legacyRow("s2", "sk-two"),
      legacyRow("s3", "sk-three"),
    ]);

    const first = await reencryptLegacyVaultSecrets(db as unknown as TenantQueryClient);
    assertEquals(first, { scanned: 3, converted: 3, skipped: 0, failed: 0, failedIds: [] });
    for (const row of db.rows) {
      assertEquals(row.key_version, VAULT_CURRENT_KEY_VERSION);
      assertEquals(isV2Ciphertext(row.encrypted_payload), true);
    }

    // Second run: no rows left at key_version=1 — proves idempotency (the
    // SELECT itself finds nothing, so nothing is touched a second time).
    const second = await reencryptLegacyVaultSecrets(db as unknown as TenantQueryClient);
    assertEquals(second, { scanned: 0, converted: 0, skipped: 0, failed: 0, failedIds: [] });
  } finally {
    clearVaultKey();
  }
});

Deno.test("reencryptLegacyVaultSecrets skips a row that is already v2-shaped despite a stale key_version=1 column", async () => {
  Deno.env.set("VAULT_ENC_KEY", TEST_VAULT_KEY);
  try {
    const staleRow = legacyRow("s1", "sk-already-aes");
    staleRow.encrypted_payload = await encryptSecretV2("sk-already-aes");
    const db = new FakeVaultDb([staleRow]);

    const report = await reencryptLegacyVaultSecrets(db as unknown as TenantQueryClient);
    assertEquals(report, { scanned: 1, converted: 0, skipped: 1, failed: 0, failedIds: [] });
    // Left exactly as it was — key_version is NOT force-bumped for a
    // ciphertext the routine didn't itself write.
    assertEquals(db.rows[0].key_version, VAULT_LEGACY_KEY_VERSION);
  } finally {
    clearVaultKey();
  }
});

Deno.test("reencryptLegacyVaultSecrets isolates a per-row failure (corrupt legacy payload) without aborting the batch", async () => {
  Deno.env.set("VAULT_ENC_KEY", TEST_VAULT_KEY);
  try {
    const good1 = legacyRow("s1", "sk-good-one");
    const corrupt = legacyRow("s2", "sk-would-be-bad");
    corrupt.encrypted_payload = "%%%not-valid-base64%%%";
    const good2 = legacyRow("s3", "sk-good-two");
    const db = new FakeVaultDb([good1, corrupt, good2]);

    const report = await reencryptLegacyVaultSecrets(db as unknown as TenantQueryClient);
    assertEquals(report.scanned, 3);
    assertEquals(report.converted, 2);
    assertEquals(report.failed, 1);
    assertEquals(report.failedIds, ["s2"]);
    assertEquals(report.skipped, 0);

    // The good rows converted; the bad row's original (still legacy, still
    // readable) ciphertext was left completely untouched — nothing dropped.
    assertEquals(db.rows.find((r) => r.id === "s1")!.key_version, VAULT_CURRENT_KEY_VERSION);
    assertEquals(db.rows.find((r) => r.id === "s3")!.key_version, VAULT_CURRENT_KEY_VERSION);
    const stillCorrupt = db.rows.find((r) => r.id === "s2")!;
    assertEquals(stillCorrupt.key_version, VAULT_LEGACY_KEY_VERSION);
    assertEquals(stillCorrupt.encrypted_payload, "%%%not-valid-base64%%%");
  } finally {
    clearVaultKey();
  }
});

Deno.test("reencryptLegacyVaultSecrets fails every row (never drops data) when VAULT_ENC_KEY is unconfigured", async () => {
  clearVaultKey();
  const db = new FakeVaultDb([legacyRow("s1", "sk-one"), legacyRow("s2", "sk-two")]);

  const report = await reencryptLegacyVaultSecrets(db as unknown as TenantQueryClient);
  assertEquals(report.scanned, 2);
  assertEquals(report.converted, 0);
  assertEquals(report.failed, 2);
  assertEquals(report.failedIds.sort(), ["s1", "s2"]);
  // Untouched — still legacy, still readable once a key IS configured.
  for (const row of db.rows) {
    assertEquals(row.key_version, VAULT_LEGACY_KEY_VERSION);
  }
});
