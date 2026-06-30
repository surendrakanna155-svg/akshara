// QA-R-009 — Backup & DR: `/health/backup` decision-logic BEHAVIOUR certification.
//
// `handleBackupHealth` (tenant_handlers.ts ~L284) is the operator-facing
// freshness probe: it reads the ops ledger (ops_backup_runs / ops_restore_drills)
// over the service-role connection and decides 200 (ok) vs 503 (degraded). This
// suite drives that decision with a MOCKED service client and pins the contract:
//
//   200  → a successful backup exists within `backupMaxAgeHours`
//   503  → no successful backup at all
//   503  → the most recent run FAILED (surfaced, does not need to be the success row)
//   503  → the latest successful backup is STALE (older than backupMaxAgeHours)
//   body → always surfaces the last restore-drill status (lastDrill)
//
// plus the internal-health auth gate is enforced (mirrors internal_health_auth_test.ts:
// the probe is operator-only and 403s without the token).
//
// HOW THE CLIENT IS MOCKED — `handleBackupHealth` builds a real supabase-js client
// via `createServiceClient` (no DI seam), so we mock at the `globalThis.fetch`
// boundary: supabase-js issues GET `/rest/v1/ops_backup_runs?...` and
// `/rest/v1/ops_restore_drills?...` PostgREST requests. We route the stub by the
// table name in the URL (and the `status=eq.success` filter that distinguishes the
// "latest successful" query from the "latest any" query) and return ledger rows as
// a JSON array. This keeps the test net-free — CI runs `deno test` with NO
// --allow-net, and the stub replaces the network entirely, so nothing escapes.
//
// INTEGRITY-THRESHOLD NOTE (deliverable 2): the restore-drill INTEGRITY thresholds
// (`tables > 100`, `organizations` non-empty) live ONLY in bash
// (deploy/akshara-vps/backup/akshara-restore-drill.sh L53/L59) — they gate whether
// a drill row is written `success` vs `failed`. There is no TS port to unit-test,
// so we do not fake one. Instead we certify the surfacing contract the operator
// actually consumes: `/health/backup` faithfully reports the drill's recorded
// status/tablesChecked/mismatch, AND a drill row that FAILED the bash thresholds
// (e.g. organizations empty → mismatch set) is surfaced verbatim. The bash
// threshold logic itself is asserted in qa_r_009_restore_drill_logic_test.ts.

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleBackupHealth } from "./tenant_handlers.ts";
import type { AppConfig } from "./config.ts";

// --- config (mirrors internal_health_auth_test.ts baseConfig; backupMaxAgeHours=26) ---

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
  supabaseUrl: "https://example.supabase.co",
  supabaseServiceRoleKey: "service-role-key",
  publicStorageBaseUrl: null,
  erpTenantDatabaseUrl: null,
  internalHealthToken: "test-internal-token",
  backupMaxAgeHours: 26,
};

const AUTHED_HEADERS = { "x-internal-health-token": "test-internal-token" };

// --- service-client mock (globalThis.fetch interception) ---------------------

interface LedgerRows {
  /** rows for the `status=eq.success` query (latest successful backup). */
  success?: unknown[];
  /** rows for the unfiltered query (latest run of any status). */
  any?: unknown[];
  /** rows for ops_restore_drills (latest drill). */
  drill?: unknown[];
}

/**
 * Installs a `globalThis.fetch` stub that answers supabase-js PostgREST GETs from
 * `rows`, then runs `handleBackupHealth` and returns the parsed envelope + status.
 * Restores the real fetch in a finally so tests don't leak the stub.
 */
async function probeWith(
  rows: LedgerRows,
  init: RequestInit = { headers: AUTHED_HEADERS },
  config: AppConfig = baseConfig,
): Promise<{ status: number; body: { data: BackupBody | null; error: unknown } }> {
  const realFetch = globalThis.fetch;
  globalThis.fetch = ((input: Request | URL | string) => {
    const url = input instanceof Request ? input.url : String(input);
    let payload: unknown[] = [];
    if (url.includes("/ops_backup_runs")) {
      payload = url.includes("status=eq.success") ? (rows.success ?? []) : (rows.any ?? []);
    } else if (url.includes("/ops_restore_drills")) {
      payload = rows.drill ?? [];
    }
    return Promise.resolve(
      new Response(JSON.stringify(payload), {
        status: 200,
        headers: { "content-type": "application/json" },
      }),
    );
  }) as typeof fetch;

  try {
    const res = await handleBackupHealth(
      new Request("https://example/health/backup", init),
      config,
    );
    return { status: res.status, body: await res.json() };
  } finally {
    globalThis.fetch = realFetch;
  }
}

interface BackupBody {
  status: string;
  reason: string | null;
  maxAgeHours: number;
  lastBackup: { kind: string; ageHours: number; offsite: boolean } | null;
  lastRunFailed: boolean;
  lastRunError: string | null;
  offsiteWarning: boolean | null;
  lastDrill: { status: string; tablesChecked: number | null; mismatch: string | null } | null;
}

function hoursAgoIso(h: number): string {
  return new Date(Date.now() - h * 3_600_000).toISOString();
}

function successRow(opts: { ageHours: number; offsite?: boolean }) {
  const ts = hoursAgoIso(opts.ageHours);
  return {
    status: "success",
    kind: "nightly",
    artifact_bytes: 4_200_000,
    sha256: "deadbeef",
    offsite: opts.offsite ?? true,
    offsite_location: "rclone:offsite",
    finished_at: ts,
    created_at: ts,
    error: null,
  };
}

function drillRow(opts: { status: string; tables?: number; mismatch?: string | null }) {
  const ts = hoursAgoIso(2);
  return {
    status: opts.status,
    tables_checked: opts.tables ?? 180,
    rows_sampled: 7,
    mismatch: opts.mismatch ?? null,
    finished_at: ts,
    created_at: ts,
  };
}

// --- 200: a fresh successful backup is healthy -------------------------------

Deno.test("QA-R-009 /health/backup returns 200 when a successful backup exists within max-age", async () => {
  const fresh = successRow({ ageHours: 5 }); // < 26h
  const drill = drillRow({ status: "success" });
  const { status, body } = await probeWith({
    success: [fresh],
    any: [fresh],
    drill: [drill],
  });

  assertEquals(status, 200);
  assertEquals(body.data?.status, "ok");
  assertEquals(body.data?.reason, null);
  assertEquals(body.data?.lastBackup?.kind, "nightly");
  assert((body.data?.lastBackup?.ageHours ?? 99) <= 6);
});

// --- 503: no successful backup at all ----------------------------------------

Deno.test("QA-R-009 /health/backup returns 503 when there is no successful backup", async () => {
  const { status, body } = await probeWith({
    success: [], // nothing successful, ever
    any: [],
    drill: [],
  });

  assertEquals(status, 503);
  assertEquals(body.data?.status, "degraded");
  assertEquals(body.data?.reason, "no_successful_backup");
  assertEquals(body.data?.lastBackup, null);
});

// --- 503: the most recent run FAILED (surfaced) ------------------------------

Deno.test("QA-R-009 /health/backup surfaces a failed latest run and degrades", async () => {
  const ts = hoursAgoIso(1);
  const failedAny = {
    status: "failed",
    kind: "nightly",
    finished_at: ts,
    created_at: ts,
    error: "pg_dump: connection refused",
  };
  // No successful row at all → degraded; lastRunFailed must be surfaced with its error.
  const { status, body } = await probeWith({
    success: [],
    any: [failedAny],
    drill: [],
  });

  assertEquals(status, 503);
  assertEquals(body.data?.status, "degraded");
  assertEquals(body.data?.lastRunFailed, true);
  assertEquals(body.data?.lastRunError, "pg_dump: connection refused");
  assertEquals(body.data?.reason, "no_successful_backup");
});

// --- 503: the latest successful backup is STALE (older than backupMaxAgeHours) ---

Deno.test("QA-R-009 /health/backup returns 503 when the latest backup is STALE (> backupMaxAgeHours)", async () => {
  const stale = successRow({ ageHours: 40 }); // > 26h default
  const { status, body } = await probeWith({
    success: [stale],
    any: [stale],
    drill: [drillRow({ status: "success" })],
  });

  assertEquals(status, 503);
  assertEquals(body.data?.status, "degraded");
  assertEquals(body.data?.reason, "backup_stale");
  assertEquals(body.data?.maxAgeHours, 26);
  assert((body.data?.lastBackup?.ageHours ?? 0) > 26);
});

// boundary: a backup exactly at the max-age threshold is still healthy (not stale).
Deno.test("QA-R-009 /health/backup treats a backup AT the max-age boundary as healthy", async () => {
  const atBoundary = successRow({ ageHours: 26 }); // == backupMaxAgeHours, not > it
  const { status, body } = await probeWith({
    success: [atBoundary],
    any: [atBoundary],
    drill: [],
  });
  assertEquals(status, 200);
  assertEquals(body.data?.status, "ok");
});

// --- body always surfaces the last drill status ------------------------------

Deno.test("QA-R-009 /health/backup surfaces the last restore-drill status (success)", async () => {
  const fresh = successRow({ ageHours: 3 });
  const { body } = await probeWith({
    success: [fresh],
    any: [fresh],
    drill: [drillRow({ status: "success", tables: 184 })],
  });

  assertEquals(body.data?.lastDrill?.status, "success");
  assertEquals(body.data?.lastDrill?.tablesChecked, 184);
  assertEquals(body.data?.lastDrill?.mismatch, null);
});

Deno.test("QA-R-009 /health/backup surfaces a FAILED drill verbatim (bash integrity threshold breach)", async () => {
  // A drill the bash script marked failed because organizations was empty after
  // restore (akshara-restore-drill.sh L59). The probe must surface it, not swallow it.
  const fresh = successRow({ ageHours: 3 });
  const { status, body } = await probeWith({
    success: [fresh],
    any: [fresh],
    drill: [
      drillRow({ status: "failed", tables: 180, mismatch: "organizations table empty after restore" }),
    ],
  });

  // backup itself is fresh → 200, but the operator can still see the drill failed.
  assertEquals(status, 200);
  assertEquals(body.data?.lastDrill?.status, "failed");
  assertEquals(body.data?.lastDrill?.mismatch, "organizations table empty after restore");
});

Deno.test("QA-R-009 /health/backup reports lastDrill null when no drill has run", async () => {
  const fresh = successRow({ ageHours: 3 });
  const { body } = await probeWith({ success: [fresh], any: [fresh], drill: [] });
  assertEquals(body.data?.lastDrill, null);
});

// --- offsite warning is surfaced but does NOT flip status --------------------

Deno.test("QA-R-009 /health/backup flags a local-only (no offsite) backup without degrading", async () => {
  const localOnly = successRow({ ageHours: 4, offsite: false });
  const { status, body } = await probeWith({
    success: [localOnly],
    any: [localOnly],
    drill: [],
  });

  assertEquals(status, 200); // offsite=false is a warning, not a failure
  assertEquals(body.data?.status, "ok");
  assertEquals(body.data?.offsiteWarning, true);
  assertEquals(body.data?.lastBackup?.offsite, false);
});

// --- internal-health auth gate is enforced (mirrors internal_health_auth_test.ts) ---

Deno.test("QA-R-009 /health/backup rejects a request with no internal-health token (403)", async () => {
  // No x-internal-health-token header → requireInternalHealthAccess denies before
  // any ledger read. Mirrors internal_health_auth_test.ts 'rejects missing token'.
  const { status } = await probeWith(
    { success: [successRow({ ageHours: 1 })] },
    {}, // no headers
  );
  assertEquals(status, 403);
});

Deno.test("QA-R-009 /health/backup rejects a wrong internal-health token (403)", async () => {
  const { status } = await probeWith(
    { success: [successRow({ ageHours: 1 })] },
    { headers: { "x-internal-health-token": "wrong-token" } },
  );
  assertEquals(status, 403);
});

Deno.test("QA-R-009 /health/backup is blocked in production when no token is configured (403)", async () => {
  // Mirrors internal_health_auth_test.ts 'production blocks ... when token not configured'.
  const { status } = await probeWith(
    { success: [successRow({ ageHours: 1 })] },
    {},
    { ...baseConfig, environment: "production", internalHealthToken: null },
  );
  assertEquals(status, 403);
});
