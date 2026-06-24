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

function clearAiEnv() {
  for (const k of ["AI_PROVIDER", "ANTHROPIC_API_KEY", "OPENROUTER_API_KEY", "ANTHROPIC_MODEL", "AI_MODEL", "OPENROUTER_MODEL"]) {
    Deno.env.delete(k);
  }
}

Deno.test("resolveAiConfig prefers the saved panel config (OpenRouter + model + key)", async () => {
  clearAiEnv();
  const db = fakeDb([{
    provider_name: "openrouter",
    config: { model: "anthropic/claude-opus-4-8" },
    encrypted_payload: encryptCredential("sk-or-panel"),
  }]);
  const cfg = await resolveAiConfig(db, "org-1");
  assertEquals(cfg.provider, "openrouter");
  assertEquals(cfg.model, "anthropic/claude-opus-4-8");
  assertEquals(cfg.apiKey, "sk-or-panel");
  assertEquals(cfg.source, "panel");
  clearAiEnv();
});

Deno.test("resolveAiConfig maps claude -> anthropic and uses default model when unset", async () => {
  clearAiEnv();
  const db = fakeDb([{
    provider_name: "claude",
    config: {},
    encrypted_payload: encryptCredential("sk-ant-panel"),
  }]);
  const cfg = await resolveAiConfig(db, "org-1");
  assertEquals(cfg.provider, "anthropic");
  assertEquals(cfg.model, "claude-opus-4-8");
  assertEquals(cfg.apiKey, "sk-ant-panel");
  clearAiEnv();
});

Deno.test("resolveAiConfig falls back to env for unsupported saved provider", async () => {
  clearAiEnv();
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-env");
  const db = fakeDb([{
    provider_name: "gemini", // not callable by our client
    config: { model: "gemini-2.0" },
    encrypted_payload: encryptCredential("g-key"),
  }]);
  const cfg = await resolveAiConfig(db, "org-1");
  assertEquals(cfg.provider, "anthropic");
  assertEquals(cfg.apiKey, "sk-ant-env");
  assertEquals(cfg.source, "env");
  clearAiEnv();
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
