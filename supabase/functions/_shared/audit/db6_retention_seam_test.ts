// P1-CODE-3 · DB-6 — audit retention code seam (non-destructive half).
import { assertEquals, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { auditRetentionCutoff } from "./audit_repository.ts";
import { loadConfig } from "../config.ts";

Deno.test("DB-6: auditRetentionCutoff returns the horizon `retentionDays` before now", () => {
  const now = Date.UTC(2026, 6, 4, 0, 0, 0); // 2026-07-04
  const cutoff = auditRetentionCutoff(now, 730);
  // 730 days earlier.
  assertEquals(cutoff.getTime(), now - 730 * 24 * 60 * 60 * 1000);
});

Deno.test("DB-6: auditRetentionCutoff rejects a non-positive window", () => {
  const now = Date.now();
  assertThrows(() => auditRetentionCutoff(now, 0));
  assertThrows(() => auditRetentionCutoff(now, -1));
  assertThrows(() => auditRetentionCutoff(now, Number.NaN));
});

Deno.test("DB-6: auditRetentionDays defaults to 730 (2y) and reads AUDIT_RETENTION_DAYS", () => {
  const saved = new Map<string, string | undefined>();
  const setEnv = (k: string, v: string) => {
    saved.set(k, Deno.env.get(k));
    Deno.env.set(k, v);
  };
  setEnv("JWT_SECRET", "test-jwt-secret-minimum-32-characters-long");
  setEnv("SUPABASE_URL", "https://test.supabase.local");
  setEnv("SUPABASE_SERVICE_ROLE_KEY", "test-service-role-key");
  const prevRetention = Deno.env.get("AUDIT_RETENTION_DAYS");
  try {
    Deno.env.delete("AUDIT_RETENTION_DAYS");
    assertEquals(loadConfig().auditRetentionDays, 730);
    Deno.env.set("AUDIT_RETENTION_DAYS", "365");
    assertEquals(loadConfig().auditRetentionDays, 365);
  } finally {
    for (const [k, v] of saved) {
      if (v === undefined) Deno.env.delete(k);
      else Deno.env.set(k, v);
    }
    if (prevRetention === undefined) Deno.env.delete("AUDIT_RETENTION_DAYS");
    else Deno.env.set("AUDIT_RETENTION_DAYS", prevRetention);
  }
});
