// COM-4 (Track B gap-sweep) — internal-cron alt-path for
// POST /communications/broadcasts/run-scheduled.
//
// The route normally requires a full user JWT + `manageCommunications`. A
// scheduler has neither, so it authenticates with `x-internal-cron-token`
// instead (communication_cron_auth.ts). This suite proves:
//   1. NEVER unauthenticated — missing/wrong cron token AND no JWT is always
//      401, including when the server-side token itself is unset (fail
//      closed — no environment gets an "unconfigured = open" bypass).
//   2. A valid cron token authorizes the ALL-ORGS run, isolated per org.
//   3. The pre-existing JWT + manageCommunications single-org path is
//      untouched by any of the above.
//
// Stubbing approach mirrors qa_r_010_health_routes_test.ts: the tenant-DB
// path is driven via the AppConfig seam (erpTenantDatabaseUrl = null →
// TenantDbNotConfiguredError, deterministic, no socket); the organizations
// lookup (supabase-js, used only on the cron path) is driven by stubbing
// globalThis.fetch — no --allow-net needed, the real wire is never touched.

import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { handleRunScheduledBroadcasts } from "./communication_handlers.ts";

const JWT_SECRET = "test-jwt-secret-minimum-32-characters-long";
const CRON_TOKEN = "sched-cron-secret-for-tests";
const CRON_HEADER = "x-internal-cron-token";

// DB-free: no erpTenantDatabaseUrl, so any org's withTenantContext() throws
// TenantDbNotConfiguredError deterministically (no socket, no live DB).
const baseConfig: AppConfig = {
  environment: "staging",
  jwtSecret: JWT_SECRET,
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
  internalHealthToken: null,
  backupMaxAgeHours: 26,
  auditRetentionDays: 730,
};

function setCronTokenEnv(value: string | undefined) {
  if (value === undefined) Deno.env.delete("INTERNAL_CRON_TOKEN");
  else Deno.env.set("INTERNAL_CRON_TOKEN", value);
}

/** Runs `fn` with INTERNAL_CRON_TOKEN set to `value` (or unset), always
 * restoring whatever was there before — tests in this process share env. */
async function withCronTokenEnv<T>(
  value: string | undefined,
  fn: () => Promise<T>,
): Promise<T> {
  const prev = Deno.env.get("INTERNAL_CRON_TOKEN");
  setCronTokenEnv(value);
  try {
    return await fn();
  } finally {
    setCronTokenEnv(prev);
  }
}

/** Swaps globalThis.fetch for the duration of `fn`, always restoring it —
 * same helper shape as qa_r_010_health_routes_test.ts. */
async function withFetch<T>(stub: typeof fetch, fn: () => Promise<T>): Promise<T> {
  const real = globalThis.fetch;
  globalThis.fetch = stub;
  try {
    return await fn();
  } finally {
    globalThis.fetch = real;
  }
}

/** A fetch that returns the same JSON body + status for every call — the
 * organizations lookup is the only supabase-js call on the cron path. */
function constFetch(status: number, body: unknown): typeof fetch {
  return (() =>
    Promise.resolve(
      new Response(JSON.stringify(body), {
        status,
        headers: { "content-type": "application/json" },
      }),
    )) as typeof fetch;
}

function cronRequest(token: string | null): Request {
  const headers: Record<string, string> = {};
  if (token !== null) headers[CRON_HEADER] = token;
  return new Request("https://x/communications/broadcasts/run-scheduled", {
    method: "POST",
    headers,
  });
}

function claims(over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "principal",
    role_slugs: ["principal"],
    primary_role: "principal",
    permissions: ["manageCommunications"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  };
}

async function jwtRequest(perms: string[]): Promise<Request> {
  const token = await signAccessToken(JWT_SECRET, claims({ permissions: perms }), 900);
  return new Request("https://x/communications/broadcasts/run-scheduled", {
    method: "POST",
    headers: { authorization: `Bearer ${token}` },
  });
}

// ── 1. NEVER unauthenticated ─────────────────────────────────────────────

Deno.test("missing cron token + no JWT → 401 (falls through, then rejected)", async () => {
  await withCronTokenEnv(CRON_TOKEN, async () => {
    const res = await handleRunScheduledBroadcasts(cronRequest(null), baseConfig);
    assertEquals(res.status, 401);
  });
});

Deno.test("wrong cron token + no JWT → 401", async () => {
  await withCronTokenEnv(CRON_TOKEN, async () => {
    const res = await handleRunScheduledBroadcasts(cronRequest("not-the-token"), baseConfig);
    assertEquals(res.status, 401);
  });
});

Deno.test("FAIL CLOSED: server INTERNAL_CRON_TOKEN unset + any presented token + no JWT → 401", async () => {
  await withCronTokenEnv(undefined, async () => {
    const res = await handleRunScheduledBroadcasts(cronRequest("anything-at-all"), baseConfig);
    assertEquals(res.status, 401);
  });
});

Deno.test("FAIL CLOSED: server INTERNAL_CRON_TOKEN unset + the OLD token value from another env + no JWT → 401", async () => {
  // Guards against a stale/rotated token still working once the server secret
  // is removed — unset must mean "nobody gets in via this header", full stop.
  await withCronTokenEnv(undefined, async () => {
    const res = await handleRunScheduledBroadcasts(cronRequest(CRON_TOKEN), baseConfig);
    assertEquals(res.status, 401);
  });
});

// ── 2. Valid token → authorized ALL-ORGS run ─────────────────────────────

Deno.test("valid cron token → runs the all-orgs sweep (200, isolated per org)", async () => {
  await withCronTokenEnv(CRON_TOKEN, async () => {
    const res = await withFetch(
      constFetch(200, [{ id: "org-a" }, { id: "org-b" }]),
      () => handleRunScheduledBroadcasts(cronRequest(CRON_TOKEN), baseConfig),
    );
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.data.cron, true);
    assertEquals(body.data.orgsConsidered, 2);
    // No live tenant DB configured in this fixture — each org's run fails
    // independently (isolated), not the whole request (proves fan-out, not
    // an all-or-nothing batch).
    assertEquals(body.data.orgsFailed, 2);
    assertEquals(body.data.results.length, 2);
    assertEquals(
      body.data.results.map((r: { organizationId: string }) => r.organizationId).sort(),
      ["org-a", "org-b"],
    );
    for (const r of body.data.results) {
      assertStringIncludes(r.error, "ERP_TENANT_DATABASE_URL");
    }
  });
});

Deno.test("valid cron token but organizations lookup itself fails → 500 (nothing could start)", async () => {
  await withCronTokenEnv(CRON_TOKEN, async () => {
    const res = await withFetch(
      constFetch(500, { message: "db down", code: "XX000" }),
      () => handleRunScheduledBroadcasts(cronRequest(CRON_TOKEN), baseConfig),
    );
    assertEquals(res.status, 500);
  });
});

// ── 3. Existing JWT + manageCommunications path is unchanged ─────────────
//
// A real bearer JWT proceeds past authenticateRequest() into assertSessionValid(),
// which does a live session-revocation lookup via the service client UNLESS
// supabaseUrl/supabaseServiceRoleKey are absent (the established DB-less unit
// test seam — see session_validation.ts's guard and qw4_communication_route_
// contract_test.ts's `{ jwtSecret: SECRET } as AppConfig` fixture). These two
// tests only need to prove the pre-existing JWT+permission gate is untouched,
// not re-prove session-lookup behavior, so they use that same DB-less config.
const dbLessConfig = { jwtSecret: JWT_SECRET } as AppConfig;

Deno.test("existing path unchanged: no cron header, valid JWT + manageCommunications reaches the DB seam (503)", async () => {
  await withCronTokenEnv(CRON_TOKEN, async () => {
    const res = await handleRunScheduledBroadcasts(await jwtRequest(["manageCommunications"]), dbLessConfig);
    assertEquals(res.status, 503);
    const body = await res.json();
    assertEquals(body.error.code, "TENANT_DB_NOT_CONFIGURED");
  });
});

Deno.test("existing path unchanged: no cron header, valid JWT WITHOUT manageCommunications is still 403", async () => {
  await withCronTokenEnv(CRON_TOKEN, async () => {
    const res = await handleRunScheduledBroadcasts(await jwtRequest(["viewCommunications"]), dbLessConfig);
    assertEquals(res.status, 403);
  });
});

Deno.test("existing path unchanged: no cron header, no JWT is still 401", async () => {
  await withCronTokenEnv(CRON_TOKEN, async () => {
    const req = new Request("https://x/communications/broadcasts/run-scheduled", { method: "POST" });
    const res = await handleRunScheduledBroadcasts(req, baseConfig);
    assertEquals(res.status, 401);
  });
});
