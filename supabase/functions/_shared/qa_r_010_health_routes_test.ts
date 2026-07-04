// QA-R-010 (P1 · monitoring/ops) — Health-route handler certification.
//
// The watchdog (deploy/akshara-vps/monitoring/akshara-watchdog.sh) and any uptime
// probe depend on the /health/* routes registered in api/app.ts (~262-275):
//
//   GET /health                liveness  — no auth, no DB, always 200
//   GET /health/ready          DB readiness probe
//   GET /health/tenant-access  token-gated · RLS isolation probe
//   GET /health/operations     token-gated · ops snapshot
//   GET /health/storage        token-gated · bucket reachability
//   GET /health/providers      token-gated · aggregate provider health
//   GET /health/backup         token-gated · backup-freshness ledger probe
//
// This suite pins the operational contract those probes rely on, DB-free:
//
//   1. LIVENESS — GET /health returns 200 with the expected envelope and never
//      touches auth or the database (handleHealth is pure/synchronous).
//   2. AUTH GATE — every sensitive /health/* handler runs requireInternalHealthAccess
//      FIRST: 403 when the internal token is configured but the header is
//      missing/wrong, and the gate passes (handler proceeds) with the matching
//      header. (No header == no access == 403, mirroring the live 401/403 posture.)
//   3. STATUS SHAPE — each handler returns 200 "ok/ready" on a healthy stub and
//      503 "degraded" on an unhealthy stub, with the documented body shape.
//
// Stubbing approach mirrors the existing handler tests:
//   * the tenant-DB handlers are driven via the AppConfig seam — erpTenantDatabaseUrl
//     = null makes probeTenantConnection() deterministically return { ok:false }
//     (no socket), exercising the degraded 503 branch (see tenant_handlers.ts and
//     internal_health_auth_test.ts for the same config-driven style);
//   * the supabase-js-backed handlers (storage/providers/ready/backup) are driven
//     by stubbing globalThis.fetch — the same transport supabase-js uses — so the
//     healthy-200 and degraded-503 branches are both reachable without a network.
//
// Run (per supabase/functions/api/deno.json — no --allow-net needed for the
// config-seam tests; the fetch-stub tests declare --allow-net but never hit the
// wire because globalThis.fetch is replaced):
//   deno test --allow-env --allow-read --allow-net \
//     supabase/functions/_shared/qa_r_010_health_routes_test.ts

import { assertEquals } from "jsr:@std/assert@1";
import {
  handleBackupHealth,
  handleOperationsHealth,
  handleProviderHealth,
  handleStorageHealth,
  handleTenantAccessHealth,
} from "./tenant_handlers.ts";
import { handleHealth, handleReady } from "./auth_handlers.ts";
import type { AppConfig } from "./config.ts";

const TOKEN = "test-internal-token";

// A complete AppConfig (mirrors internal_health_auth_test.ts) with the internal
// health token configured and NO tenant DB URL — so probeTenantConnection() fails
// fast without a socket.
const baseConfig: AppConfig = {
  environment: "staging",
  jwtSecret: "x".repeat(32),
  accessTokenTtlSeconds: 900,
  refreshTokenTtlSeconds: 2592000,
  otpTtlSeconds: 300,
  otpMaxAttempts: 3,
  otpDevMode: false,
  otpPilotPhones: [],
  otpRateWindowSeconds: 3600,
  otpMaxRequestsPerPhone: 5,
  otpMaxRequestsPerIp: 20,
  otpResendCooldownSeconds: 60,
  smsProvider: "fast2sms",
  smsApiKey: null,
  smsFast2smsRoute: "q",
  smsFast2smsSenderId: null,
  smsFast2smsMessageId: null,
  transactionalSmsEnabled: false,
  supabaseUrl: "https://stub.supabase.co",
  supabaseServiceRoleKey: "service-role-key",
  publicStorageBaseUrl: null,
  erpTenantDatabaseUrl: null,
  internalHealthToken: TOKEN,
  backupMaxAgeHours: 26,
  auditRetentionDays: 730,
};

function withToken(path: string): Request {
  return new Request(`https://example${path}`, {
    headers: { "x-internal-health-token": TOKEN },
  });
}

function noToken(path: string): Request {
  return new Request(`https://example${path}`);
}

/** Swaps globalThis.fetch for the duration of `fn`, always restoring it. */
async function withFetch<T>(
  stub: typeof fetch,
  fn: () => Promise<T>,
): Promise<T> {
  const real = globalThis.fetch;
  globalThis.fetch = stub;
  try {
    return await fn();
  } finally {
    globalThis.fetch = real;
  }
}

/** A fetch that returns the same JSON body + status for every call. */
function constFetch(status: number, body: unknown): typeof fetch {
  return (() =>
    Promise.resolve(
      new Response(JSON.stringify(body), {
        status,
        headers: { "content-type": "application/json" },
      }),
    )) as typeof fetch;
}

/** A fetch that picks a body by which table/path the URL targets. */
function tableFetch(pick: (url: string) => unknown): typeof fetch {
  return ((input: Request | URL | string) => {
    const url = typeof input === "string"
      ? input
      : input instanceof URL
      ? input.href
      : input.url;
    return Promise.resolve(
      new Response(JSON.stringify(pick(url)), {
        status: 200,
        headers: { "content-type": "application/json" },
      }),
    );
  }) as typeof fetch;
}

// ─── 1. Liveness — no auth, no DB, always 200 ────────────────────────────────

Deno.test("GET /health liveness: 200, expected envelope, no auth or DB required", async () => {
  // handleHealth() takes NO request and NO config — it cannot consult auth or the
  // database. Calling it with no token and no DB url still returns 200.
  const res = handleHealth();
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.data.status, "ok");
  assertEquals(body.data.service, "akshara-api");
  assertEquals(body.error, null);
});

// ─── 2. Auth gate — sensitive /health/* require the internal token ───────────

const SENSITIVE: Array<
  { name: string; path: string; handler: (req: Request, c: AppConfig) => Promise<Response> }
> = [
  { name: "tenant-access", path: "/health/tenant-access", handler: handleTenantAccessHealth },
  { name: "operations", path: "/health/operations", handler: handleOperationsHealth },
  { name: "storage", path: "/health/storage", handler: handleStorageHealth },
  { name: "providers", path: "/health/providers", handler: handleProviderHealth },
  { name: "backup", path: "/health/backup", handler: handleBackupHealth },
];

Deno.test("sensitive /health/* deny (403) when the internal token is missing — gate runs before DB", async () => {
  for (const { name, path, handler } of SENSITIVE) {
    // No header → requireInternalHealthAccess returns 403 and the handler
    // short-circuits BEFORE any DB/storage probe (proves the gate is first).
    const res = await handler(noToken(path), baseConfig);
    assertEquals(res.status, 403, `${name} did not 403 without the internal token`);
    const body = await res.json();
    assertEquals(body.error.code, "FORBIDDEN", `${name} wrong error code`);
  }
});

Deno.test("sensitive /health/* deny (403) when the internal token is WRONG", async () => {
  for (const { name, path, handler } of SENSITIVE) {
    const req = new Request(`https://example${path}`, {
      headers: { "x-internal-health-token": "not-the-token" },
    });
    const res = await handler(req, baseConfig);
    assertEquals(res.status, 403, `${name} accepted a wrong token`);
  }
});

Deno.test("sensitive /health/* PASS the gate with the matching token (proceed past auth)", async () => {
  // With the correct token the gate returns null and the handler proceeds to its
  // probe; here the tenant-DB-backed handlers reach their degraded path (no DB
  // url) and return 503 — a non-403 status, proving the gate let them through.
  for (const name of ["tenant-access", "operations"] as const) {
    const entry = SENSITIVE.find((s) => s.name === name)!;
    const res = await entry.handler(withToken(entry.path), baseConfig);
    assertEquals(
      res.status === 403,
      false,
      `${name} was still blocked by the auth gate with a valid token`,
    );
  }
});

// ─── 3. Status shape — healthy 200 vs unhealthy 503 ──────────────────────────

Deno.test("GET /health/ready: 200 ready when DB reachable, 503 degraded when not", async () => {
  // Healthy: organizations select returns a row.
  const ok = await withFetch(constFetch(200, [{ id: "org-1" }]), () => handleReady(baseConfig));
  assertEquals(ok.status, 200);
  const okBody = await ok.json();
  assertEquals(okBody.data.status, "ready");
  assertEquals(okBody.data.database, true);

  // Degraded: the select errors (PostgREST 500) → 503 degraded.
  const bad = await withFetch(
    constFetch(500, { message: "db down", code: "XX000" }),
    () => handleReady(baseConfig),
  );
  assertEquals(bad.status, 503);
  const badBody = await bad.json();
  assertEquals(badBody.data.status, "degraded");
  assertEquals(badBody.data.database, false);
});

Deno.test("GET /health/storage: 200 ok when bucket reachable, 503 degraded when not", async () => {
  // Healthy: list() returns an (empty) array, no error.
  const ok = await withFetch(
    constFetch(200, []),
    () => handleStorageHealth(withToken("/health/storage"), baseConfig),
  );
  assertEquals(ok.status, 200);
  const okBody = await ok.json();
  assertEquals(okBody.data.status, "ok");
  assertEquals(okBody.data.reachable, true);
  assertEquals(okBody.data.bucket, "school-memories");

  // Degraded: list() returns a storage error.
  const bad = await withFetch(
    constFetch(500, { error: "boom", message: "boom", statusCode: "500" }),
    () => handleStorageHealth(withToken("/health/storage"), baseConfig),
  );
  assertEquals(bad.status, 503);
  const badBody = await bad.json();
  assertEquals(badBody.data.status, "degraded");
  assertEquals(badBody.data.reachable, false);
});

Deno.test("GET /health/tenant-access: 503 degraded when the tenant DB is unconfigured", async () => {
  // No erpTenantDatabaseUrl → probeTenantConnection() → { ok:false } → degraded.
  const res = await handleTenantAccessHealth(withToken("/health/tenant-access"), baseConfig);
  assertEquals(res.status, 503);
  const body = await res.json();
  assertEquals(body.data.status, "degraded");
  assertEquals(body.data.connection.ok, false);
  assertEquals(body.data.isolation.pass, false);
});

Deno.test("GET /health/operations: 503 degraded when the tenant DB is unconfigured", async () => {
  const res = await handleOperationsHealth(withToken("/health/operations"), baseConfig);
  assertEquals(res.status, 503);
  const body = await res.json();
  assertEquals(body.data.status, "degraded");
  assertEquals(body.data.connection.ok, false);
});

Deno.test("GET /health/providers: 503 degraded when tenant DB unreachable (even if storage is up)", async () => {
  // Storage probe succeeds via the fetch stub, but the tenant connection is
  // unconfigured → aggregate status is degraded (connection ∧ storage).
  const res = await withFetch(
    constFetch(200, []),
    () => handleProviderHealth(withToken("/health/providers"), baseConfig),
  );
  assertEquals(res.status, 503);
  const body = await res.json();
  assertEquals(body.data.status, "degraded");
  assertEquals(body.data.connection.ok, false);
  assertEquals(body.data.storage.reachable, true);
});

Deno.test("GET /health/backup: 200 ok on a fresh successful backup, 503 degraded when stale", async () => {
  const nowIso = new Date().toISOString();
  const oldIso = new Date(Date.now() - 1000 * 60 * 60 * 100).toISOString(); // 100h old

  // Healthy: a successful backup created now (age 0 <= backupMaxAgeHours 26).
  const ok = await withFetch(
    tableFetch((url) =>
      url.includes("ops_backup_runs")
        ? {
          status: "success",
          kind: "full",
          artifact_bytes: 12345,
          sha256: "abc",
          offsite: true,
          offsite_location: "s3://x",
          finished_at: nowIso,
          created_at: nowIso,
          error: null,
        }
        : url.includes("ops_restore_drills")
        ? {
          status: "passed",
          tables_checked: 10,
          rows_sampled: 100,
          mismatch: null,
          finished_at: nowIso,
          created_at: nowIso,
        }
        : null
    ),
    () => handleBackupHealth(withToken("/health/backup"), baseConfig),
  );
  assertEquals(ok.status, 200);
  const okBody = await ok.json();
  assertEquals(okBody.data.status, "ok");
  assertEquals(okBody.data.reason, null);
  assertEquals(okBody.data.lastBackup.kind, "full");

  // Degraded: the only successful backup is 100h old > 26h max → backup_stale.
  const stale = await withFetch(
    tableFetch((url) =>
      url.includes("ops_backup_runs")
        ? {
          status: "success",
          kind: "full",
          artifact_bytes: 1,
          sha256: "a",
          offsite: false,
          offsite_location: null,
          finished_at: oldIso,
          created_at: oldIso,
          error: null,
        }
        : null
    ),
    () => handleBackupHealth(withToken("/health/backup"), baseConfig),
  );
  assertEquals(stale.status, 503);
  const staleBody = await stale.json();
  assertEquals(staleBody.data.status, "degraded");
  assertEquals(staleBody.data.reason, "backup_stale");
});

Deno.test("GET /health/backup: 503 degraded when the backup ledger is unreadable", async () => {
  // PostgREST returns an error (e.g. missing relation) → ledger_unreadable.
  const res = await withFetch(
    constFetch(400, { message: "relation does not exist", code: "42P01" }),
    () => handleBackupHealth(withToken("/health/backup"), baseConfig),
  );
  assertEquals(res.status, 503);
  const body = await res.json();
  assertEquals(body.data.status, "degraded");
  assertEquals(body.data.reason, "ledger_unreadable");
});
