import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  decryptCredential,
  encryptCredential,
} from "../vault/vault_service.ts";

Deno.test("vault encrypt/decrypt round-trip for provider credentials", () => {
  const secret = "sk-test-openai-key-12345";
  const encrypted = encryptCredential(secret);
  assertEquals(encrypted.includes(secret), false);
  assertEquals(decryptCredential(encrypted), secret);
});

Deno.test("vault supports MSG91 and Gupshup credential shapes", () => {
  for (const key of ["msg91-auth-key-abc", "gupshup-api-secret-xyz"]) {
    assertEquals(decryptCredential(encryptCredential(key)), key);
  }
});
