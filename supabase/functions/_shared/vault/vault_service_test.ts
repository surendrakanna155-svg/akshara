// PRC-A cap 45 — provider secret encryption at rest.
//
// Proves, without a live DB, that:
//   - AES-256-GCM round-trips (encrypt -> decrypt gives back the plaintext,
//     and the ciphertext never contains it);
//   - decrypting with the wrong key fails CLEANLY (throws — never silently
//     returns garbage);
//   - a legacy (key_version=1, plain Base64) row still decrypts, with NO
//     VAULT_ENC_KEY configured at all;
//   - storeSecret/rotateSecret refuse to run (throw) when VAULT_ENC_KEY is
//     unset — secrets are never written unencrypted;
//   - the API-facing shapes (`vaultSecretToApi` / `providerConfigToApi`)
//     never leak the encrypted payload or plaintext.

import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { PlatformQueryClient } from "../platform_db.ts";
import {
  decryptLegacyBase64,
  encryptLegacyBase64,
  isV2Ciphertext,
  VAULT_V2_PREFIX,
  VaultEncryptionNotConfiguredError,
} from "./vault_crypto.ts";
import {
  decryptCredential,
  encryptCredential,
  providerConfigToApi,
  rotateSecret,
  storeSecret,
  vaultSecretToApi,
  VAULT_CURRENT_KEY_VERSION,
  VAULT_LEGACY_KEY_VERSION,
  type ProviderConfigRow,
  type VaultSecretRow,
} from "./vault_service.ts";

const KEY_A = "a".repeat(64); // 64 hex chars = 32 bytes
const KEY_B = "b".repeat(64); // a DIFFERENT 32-byte key

function clearVaultKey() {
  Deno.env.delete("VAULT_ENC_KEY");
}

// deno-lint-ignore no-explicit-any
function fakeDb(rows: any[] = []): PlatformQueryClient {
  return {
    // deno-lint-ignore no-explicit-any require-await
    queryObject: async (_sql: string, _params?: unknown[]) => rows as any,
    // deno-lint-ignore no-explicit-any
  } as any as PlatformQueryClient;
}

Deno.test("AES-256-GCM round-trip: encrypt then decrypt recovers the exact plaintext", async () => {
  Deno.env.set("VAULT_ENC_KEY", KEY_A);
  try {
    const secret = "sk-ant-super-secret-12345";
    const encrypted = await encryptCredential(secret);
    assertEquals(encrypted.startsWith(VAULT_V2_PREFIX), true);
    assertEquals(isV2Ciphertext(encrypted), true);
    assertEquals(encrypted.includes(secret), false);
    assertEquals(await decryptCredential(encrypted), secret);
  } finally {
    clearVaultKey();
  }
});

Deno.test("AES-256-GCM: two encryptions of the same plaintext never reuse an IV (distinct ciphertexts)", async () => {
  Deno.env.set("VAULT_ENC_KEY", KEY_A);
  try {
    const secret = "sk-same-plaintext-both-times";
    const first = await encryptCredential(secret);
    const second = await encryptCredential(secret);
    assertEquals(first === second, false);
    assertEquals(await decryptCredential(first), secret);
    assertEquals(await decryptCredential(second), secret);
  } finally {
    clearVaultKey();
  }
});

Deno.test("decrypting a v2 ciphertext with the WRONG key fails cleanly (throws, never returns garbage)", async () => {
  Deno.env.set("VAULT_ENC_KEY", KEY_A);
  const encrypted = await encryptCredential("sk-only-decryptable-with-key-a");
  Deno.env.set("VAULT_ENC_KEY", KEY_B);
  try {
    await assertRejects(() => decryptCredential(encrypted));
  } finally {
    clearVaultKey();
  }
});

Deno.test("decrypting a v2 ciphertext with NO key configured throws (fails closed, not open)", async () => {
  Deno.env.set("VAULT_ENC_KEY", KEY_A);
  const encrypted = await encryptCredential("sk-needs-a-key-to-read-back");
  clearVaultKey();
  await assertRejects(
    () => decryptCredential(encrypted),
    VaultEncryptionNotConfiguredError,
  );
});

Deno.test("legacy (key_version=1) Base64 rows still decrypt with NO VAULT_ENC_KEY configured", async () => {
  clearVaultKey();
  const secret = "sk-legacy-pre-aes-secret";
  const legacyEncoded = encryptLegacyBase64(secret);
  assertEquals(isV2Ciphertext(legacyEncoded), false);
  assertEquals(await decryptCredential(legacyEncoded), secret);
  assertEquals(decryptLegacyBase64(legacyEncoded), secret);
});

Deno.test("storeSecret refuses to run when VAULT_ENC_KEY is absent (throws before touching the DB)", async () => {
  clearVaultKey();
  await assertRejects(
    () =>
      storeSecret(fakeDb(), {
        providerCategory: "ai",
        providerName: "anthropic",
        credential: "sk-should-never-be-written",
        actorUserId: "u-1",
      }),
    VaultEncryptionNotConfiguredError,
  );
});

Deno.test("rotateSecret refuses to run when VAULT_ENC_KEY is absent", async () => {
  clearVaultKey();
  await assertRejects(
    () => rotateSecret(fakeDb(), "secret-1", "sk-new-should-never-be-written", "u-1"),
    VaultEncryptionNotConfiguredError,
  );
});

Deno.test("storeSecret writes AES-256-GCM ciphertext + key_version=2 when VAULT_ENC_KEY is configured", async () => {
  Deno.env.set("VAULT_ENC_KEY", KEY_A);
  try {
    const inserted: { sql: string; params: unknown[] }[] = [];
    const db = {
      // deno-lint-ignore require-await
      queryObject: async (sql: string, params: unknown[] = []) => {
        inserted.push({ sql, params });
        if (sql.includes("INSERT INTO platform_secret_vault")) {
          const row: VaultSecretRow = {
            id: "secret-1",
            organization_id: null,
            provider_category: params[1] as string,
            provider_name: params[2] as string,
            encrypted_payload: params[3] as string,
            key_version: params[4] as number,
            health_status: "unknown",
            last_health_check_at: null,
            last_rotated_at: new Date().toISOString(),
            failover_secret_id: null,
          };
          return [row];
        }
        return [];
      },
    } as unknown as PlatformQueryClient;

    const secret = await storeSecret(db, {
      providerCategory: "ai",
      providerName: "anthropic",
      credential: "sk-brand-new",
      actorUserId: "u-1",
    });
    assertEquals(secret.key_version, VAULT_CURRENT_KEY_VERSION);
    assertEquals(isV2Ciphertext(secret.encrypted_payload), true);
    assertEquals(await decryptCredential(secret.encrypted_payload), "sk-brand-new");
  } finally {
    clearVaultKey();
  }
});

Deno.test("masking preserved: vaultSecretToApi never exposes the encrypted payload", () => {
  const row: VaultSecretRow = {
    id: "secret-1",
    organization_id: null,
    provider_category: "ai",
    provider_name: "anthropic",
    encrypted_payload: "v2:super-secret-ciphertext-should-never-leak",
    key_version: VAULT_LEGACY_KEY_VERSION,
    health_status: "healthy",
    last_health_check_at: null,
    last_rotated_at: null,
    failover_secret_id: null,
  };
  const api = vaultSecretToApi(row);
  const serialized = JSON.stringify(api);
  assertEquals(serialized.includes("super-secret-ciphertext"), false);
  assertEquals(serialized.includes("encrypted_payload"), false);
  assertEquals((api as Record<string, unknown>).encryptedPayload, undefined);
});

Deno.test("masking preserved: providerConfigToApi never exposes a credential, only a boolean", () => {
  const row: ProviderConfigRow = {
    id: "cfg-1",
    organization_id: null,
    provider_category: "ai",
    provider_name: "anthropic",
    vault_secret_id: "secret-1",
    is_active: true,
    is_primary: true,
    config: {},
    health_status: "healthy",
  };
  const api = providerConfigToApi(row);
  assertEquals(api.hasCredential, true);
  assertEquals((api as Record<string, unknown>).credential, undefined);
  assertEquals((api as Record<string, unknown>).encryptedPayload, undefined);
});
