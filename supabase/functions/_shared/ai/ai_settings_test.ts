import { assertEquals } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import { encryptCredential } from "../vault/vault_service.ts";
import { resolveAiConfig } from "./ai_settings.ts";

// deno-lint-ignore no-explicit-any
function fakeDb(rows: any[]): TenantQueryClient {
  return {
    // deno-lint-ignore no-explicit-any
    queryObject: (_sql: string, _params?: unknown[]) => Promise.resolve(rows as any),
    // deno-lint-ignore no-explicit-any
  } as any as TenantQueryClient;
}

// A valid 32-byte VAULT_ENC_KEY so encryptCredential (AES-256-GCM) can build
// the fixture rows below — this test exercises resolveAiConfig's DB-row
// wiring, not vault encryption itself (see vault/vault_service_test.ts for
// that), so a fixed test-only key is fine.
const TEST_VAULT_KEY = "0".repeat(63) + "1"; // 64 hex chars = 32 bytes

function clearAiEnv() {
  for (const k of ["AI_PROVIDER", "ANTHROPIC_API_KEY", "OPENROUTER_API_KEY", "ANTHROPIC_MODEL", "AI_MODEL", "OPENROUTER_MODEL"]) {
    Deno.env.delete(k);
  }
}

Deno.test("resolveAiConfig prefers the saved panel config (OpenRouter + model + key)", async () => {
  clearAiEnv();
  Deno.env.set("VAULT_ENC_KEY", TEST_VAULT_KEY);
  const db = fakeDb([{
    provider_name: "openrouter",
    config: { model: "anthropic/claude-opus-4-8" },
    encrypted_payload: await encryptCredential("sk-or-panel"),
  }]);
  const cfg = await resolveAiConfig(db, "org-1");
  assertEquals(cfg.provider, "openrouter");
  assertEquals(cfg.model, "anthropic/claude-opus-4-8");
  assertEquals(cfg.apiKey, "sk-or-panel");
  assertEquals(cfg.source, "panel");
  clearAiEnv();
  Deno.env.delete("VAULT_ENC_KEY");
});

Deno.test("resolveAiConfig maps claude -> anthropic and uses default model when unset", async () => {
  clearAiEnv();
  Deno.env.set("VAULT_ENC_KEY", TEST_VAULT_KEY);
  const db = fakeDb([{
    provider_name: "claude",
    config: {},
    encrypted_payload: await encryptCredential("sk-ant-panel"),
  }]);
  const cfg = await resolveAiConfig(db, "org-1");
  assertEquals(cfg.provider, "anthropic");
  assertEquals(cfg.model, "claude-opus-4-8");
  assertEquals(cfg.apiKey, "sk-ant-panel");
  clearAiEnv();
  Deno.env.delete("VAULT_ENC_KEY");
});

Deno.test("resolveAiConfig falls back to env for unsupported saved provider", async () => {
  clearAiEnv();
  Deno.env.set("VAULT_ENC_KEY", TEST_VAULT_KEY);
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-env");
  const db = fakeDb([{
    provider_name: "gemini", // not callable by our client
    config: { model: "gemini-2.0" },
    encrypted_payload: await encryptCredential("g-key"),
  }]);
  const cfg = await resolveAiConfig(db, "org-1");
  assertEquals(cfg.provider, "anthropic");
  assertEquals(cfg.apiKey, "sk-ant-env");
  assertEquals(cfg.source, "env");
  clearAiEnv();
  Deno.env.delete("VAULT_ENC_KEY");
});

Deno.test("resolveAiConfig falls back to env when no panel row exists", async () => {
  clearAiEnv();
  Deno.env.set("AI_PROVIDER", "openrouter");
  Deno.env.set("OPENROUTER_API_KEY", "sk-or-env");
  const cfg = await resolveAiConfig(fakeDb([]), "org-1");
  assertEquals(cfg.provider, "openrouter");
  assertEquals(cfg.apiKey, "sk-or-env");
  assertEquals(cfg.source, "env");
  clearAiEnv();
});
