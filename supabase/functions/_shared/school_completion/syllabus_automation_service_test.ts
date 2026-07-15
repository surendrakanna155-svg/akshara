import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  decryptCredential,
  encryptCredential,
} from "../vault/vault_service.ts";

// A valid 32-byte VAULT_ENC_KEY so encryptCredential (AES-256-GCM) has
// something to encrypt under — see vault/vault_service_test.ts for the full
// AES-GCM / legacy / wrong-key coverage; these two just prove the round-trip
// from this call site still works end to end.
const TEST_VAULT_KEY = "1".repeat(64); // 64 hex chars = 32 bytes

Deno.test("vault encrypt/decrypt round-trip for provider credentials", async () => {
  Deno.env.set("VAULT_ENC_KEY", TEST_VAULT_KEY);
  try {
    const secret = "sk-test-openai-key-12345";
    const encrypted = await encryptCredential(secret);
    assertEquals(encrypted.includes(secret), false);
    assertEquals(await decryptCredential(encrypted), secret);
  } finally {
    Deno.env.delete("VAULT_ENC_KEY");
  }
});

Deno.test("vault supports MSG91 and Gupshup credential shapes", async () => {
  Deno.env.set("VAULT_ENC_KEY", TEST_VAULT_KEY);
  try {
    for (const key of ["msg91-auth-key-abc", "gupshup-api-secret-xyz"]) {
      assertEquals(await decryptCredential(await encryptCredential(key)), key);
    }
  } finally {
    Deno.env.delete("VAULT_ENC_KEY");
  }
});
