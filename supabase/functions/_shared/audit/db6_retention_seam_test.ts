// P1-CODE-3 · DB-6 — audit retention code seam (non-destructive half).
import {
  assert,
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { auditRetentionCutoff, sizeAuditRetention } from "./audit_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { loadConfig } from "../config.ts";
import { routeAudit } from "./audit_router.ts";

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

// ── P0-RETENTION — the seam is now actually CONSUMED ────────────────────────
//
// `AUDIT_RETENTION_DAYS` used to be parsed into config and read by nothing, so
// the published policy described a horizon the system never applied. These
// tests pin the two properties that make the reconciled policy true:
//   1. sizing REPORTS the horizon (so an operator can size a purge), and
//   2. sizing DELETES NOTHING (audit_events stays append-only).

const ORG = "a1000000-0000-4000-8000-000000000001";

const CLAIMS = {
  sub: "a3000000-0000-4000-8000-000000000001",
  tenant_id: ORG,
  organization_id: ORG,
  school_id: "a2000000-0000-4000-8000-000000000001",
} as unknown as AccessTokenClaims;

/** Records every statement so a test can prove none of them mutate. */
class RecordingDb {
  sql: string[] = [];
  constructor(private readonly beyond: string, private readonly total: string) {}

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, _args: unknown[] = []): Promise<T[]> {
    this.sql.push(sql);
    return [{ count: this.beyond }] as T[];
  }

  // deno-lint-ignore require-await
  async queryCount(sql: string, _args: unknown[] = []): Promise<number> {
    this.sql.push(sql);
    return Number(this.total);
  }
}

Deno.test("P0-RETENTION: sizeAuditRetention reports the horizon, the cutoff and the blast radius", async () => {
  const db = new RecordingDb("42", "1000");
  const now = Date.UTC(2026, 6, 4, 0, 0, 0);

  const sizing = await sizeAuditRetention(
    db as unknown as TenantQueryClient,
    CLAIMS,
    730,
    now,
  );

  assertEquals(sizing.retentionDays, 730);
  assertEquals(sizing.beyondRetention, 42);
  assertEquals(sizing.total, 1000);
  assertEquals(
    sizing.cutoff,
    new Date(now - 730 * 24 * 60 * 60 * 1000).toISOString(),
  );
  // The policy says purging is explicitly-invoked ops-lane only. Pin it, so a
  // future scheduled purge cannot silently contradict the published policy.
  assertEquals(sizing.automaticPurgeEnabled, false);
});

Deno.test("P0-RETENTION: sizing audit retention issues NO destructive statement (append-only)", async () => {
  const db = new RecordingDb("7", "9");
  await sizeAuditRetention(db as unknown as TenantQueryClient, CLAIMS, 365);

  assert(db.sql.length > 0, "expected the sizing path to query something");
  for (const sql of db.sql) {
    const upper = sql.toUpperCase();
    for (const verb of ["DELETE", "TRUNCATE", "DROP", "UPDATE", "INSERT"]) {
      assert(
        !upper.includes(verb),
        `sizing must not mutate audit_events, but issued ${verb}: ${sql}`,
      );
    }
  }
});

Deno.test("P0-RETENTION: GET /audit/retention is wired and rejects an unauthenticated caller", async () => {
  const saved = new Map<string, string | undefined>();
  const setEnv = (k: string, v: string) => {
    saved.set(k, Deno.env.get(k));
    Deno.env.set(k, v);
  };
  setEnv("JWT_SECRET", "test-jwt-secret-minimum-32-characters-long");
  setEnv("SUPABASE_URL", "https://test.supabase.local");
  setEnv("SUPABASE_SERVICE_ROLE_KEY", "test-service-role-key");
  try {
    const config = loadConfig();
    const res = await routeAudit(
      new Request("https://api.local/audit/retention"),
      config,
      "GET",
      "/audit/retention",
    );
    // Non-null => the route resolved to a handler (it is no longer a 404).
    assert(res !== null, "GET /audit/retention must resolve to a handler");
    // Auth is enforced before any tenant work.
    assertEquals(res.status, 401);
  } finally {
    for (const [k, v] of saved) {
      if (v === undefined) Deno.env.delete(k);
      else Deno.env.set(k, v);
    }
  }
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
