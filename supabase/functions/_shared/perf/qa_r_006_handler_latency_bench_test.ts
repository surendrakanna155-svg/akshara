// QA-R-006 — Backend handler latency micro-benchmark (in-process, DB-free).
//
// The full request handler `handleRequest` (supabase/functions/api/app.ts ~L226)
// is extracted from `Deno.serve` so it is unit-testable WITHOUT binding a socket
// or a live DB. We exercise it exactly as the qw4_*_route_contract_test.ts suite
// does, against the established DB-free seam:
//
//   • `configLoader` is injectable → we feed a config with an EMPTY supabaseUrl /
//     serviceRoleKey, which makes `assertSessionValid` a no-op (see
//     session_validation.ts L96: it returns null — skips the session lookup — when
//     those are unset), so no network call is attempted; AND `erpTenantDatabaseUrl`
//     is null, so an AUTHORIZED tenant-enforced route resolves to
//     503 TENANT_DB_NOT_CONFIGURED — the canonical "authorized-but-no-DB" proxy.
//
// What this measures LOCALLY (the synthetic-scale half of verify-at-scale):
//   the in-process cost of the hot path that runs on EVERY request — config load,
//   CORS, correlation id, route matching, JWT verify, the RBAC permission gate,
//   body parse + validation — up to (but not including) the real DB round-trip.
//   We fire N synthetic requests through the in-memory handler, collect each
//   `durationMs`, and assert an aggregate p95 under a documented budget.
//
// What this does NOT measure (the live-k6 leg, INFRA-BLOCKED):
//   the true end-to-end p95 with a real edge + Postgres + connection pool over the
//   network. That is scripts/perf/qa_x_025_p95_latency_probe.js (224ms read / 400ms
//   write p95, <1% error budget), which runs only against the live VPS pilot and is
//   carried on the live-regression lane. See docs/PERFORMANCE_TARGETS.md.
//
// The batch test below feeds an N-record payload (large attendance + large marks
// bodies). Because the route is DB-free here, that asserts the routing/JWT/RBAC/
// validation cost is O(1) in payload size (a 1000-record body is handled in the
// same latency band as a 1-record body) — it does NOT claim the true at-scale
// persist latency, which is the live-k6 leg.

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleRequest } from "../../api/app.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";

// ── Documented latency budgets (see docs/PERFORMANCE_TARGETS.md) ─────────────
// These are IN-PROCESS handler budgets for the routing/JWT/RBAC/validation hot
// path, NOT the live p95 SLA. They are intentionally generous so the test is a
// regression tripwire (a 50x blow-up in the in-memory hot path), not a flaky
// wall-clock race on a busy CI box.
const HANDLER_P95_BUDGET_MS = 50; // aggregate p95 of the in-process hot path
const HANDLER_MAX_BUDGET_MS = 250; // hard ceiling for the slowest single request
const BATCH_BUDGET_MS = 50; // a 1000-record body must route/validate in this band

const SECRET = "test-jwt-secret-minimum-32-characters-long";

// DB-free config: empty supabaseUrl/serviceRoleKey ⇒ session lookup is skipped
// (no network); erpTenantDatabaseUrl null ⇒ authorized routes resolve to 503.
const config = {
  environment: "test",
  jwtSecret: SECRET,
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
  supabaseUrl: "",
  supabaseServiceRoleKey: "",
  publicStorageBaseUrl: null,
  erpTenantDatabaseUrl: null,
  internalHealthToken: null,
  backupMaxAgeHours: 26,
} as AppConfig;

const configLoader = () => config;

function claims(perms: string[]): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: perms,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
  };
}

async function token(perms: string[]): Promise<string> {
  return await signAccessToken(SECRET, claims(perms), 900);
}

/** p95 (nearest-rank) of a duration sample. */
function p95(samples: number[]): number {
  const sorted = [...samples].sort((a, b) => a - b);
  const idx = Math.ceil(0.95 * sorted.length) - 1;
  return sorted[Math.max(0, idx)]!;
}

// ── Sanity: the DB-free seam resolves an AUTHORIZED hot route to 503 ──────────
Deno.test("QA-R-006 setup: authorized read resolves DB-free to 503 (no socket, no DB)", async () => {
  const t = await token(["viewFinance"]);
  const req = new Request("https://x/finance/dashboard", {
    method: "GET",
    headers: { authorization: `Bearer ${t}` },
  });
  const res = await handleRequest(req, configLoader);
  // 503 = authorized + scope passed, reached the unconfigured tenant DB.
  assertEquals(res.status, 503, "authorized hot read should reach the DB-free 503 proxy");
  // No-auth health is the free baseline (no JWT verify, no RBAC).
  const health = await handleRequest(new Request("https://x/health"), configLoader);
  assertEquals(health.status, 200);
});

// ── QA-R-006 (a): aggregate p95 of N synthetic hot-read requests ──────────────
Deno.test("QA-R-006: 200 synthetic hot-read requests — aggregate p95 under the handler budget", async () => {
  const N = 200;
  const t = await token(["viewFinance"]);

  // Warm up JWT/crypto + module graph so the first-call cost (one-time JIT/import)
  // is not counted in the steady-state p95 sample.
  for (let i = 0; i < 10; i++) {
    const warm = new Request("https://x/finance/dashboard", {
      method: "GET",
      headers: { authorization: `Bearer ${t}` },
    });
    await handleRequest(warm, configLoader);
  }

  const durations: number[] = [];
  for (let i = 0; i < N; i++) {
    const req = new Request("https://x/finance/dashboard", {
      method: "GET",
      headers: { authorization: `Bearer ${t}` },
    });
    const start = performance.now();
    const res = await handleRequest(req, configLoader);
    durations.push(performance.now() - start);
    // Every request must take the SAME authorized path (a 401/403 here would mean
    // the gate rejected it and we'd be timing the wrong thing).
    assertEquals(res.status, 503, `request ${i} should be authorized-but-no-DB (503)`);
  }

  const p95Ms = p95(durations);
  const maxMs = Math.max(...durations);
  assert(
    p95Ms < HANDLER_P95_BUDGET_MS,
    `aggregate in-process p95 over ${N} requests was ${p95Ms.toFixed(2)}ms ` +
      `(budget < ${HANDLER_P95_BUDGET_MS}ms). The hot path — route match + JWT ` +
      `verify + RBAC gate — regressed.`,
  );
  assert(
    maxMs < HANDLER_MAX_BUDGET_MS,
    `slowest single request was ${maxMs.toFixed(2)}ms (ceiling < ${HANDLER_MAX_BUDGET_MS}ms)`,
  );
});

// ── QA-R-006 (b): unauthorized requests are rejected fast (RBAC short-circuit) ─
Deno.test("QA-R-006: 200 unauthorized requests are denied fast — RBAC gate is not a latency hole", async () => {
  const N = 200;
  // A token with a benign, non-finance permission → 403 at the gate, BEFORE any
  // DB-free 503. Denials must be at least as cheap as authorized routing.
  const t = await token(["viewInventory"]);

  for (let i = 0; i < 10; i++) {
    await handleRequest(
      new Request("https://x/finance/dashboard", {
        method: "GET",
        headers: { authorization: `Bearer ${t}` },
      }),
      configLoader,
    );
  }

  const durations: number[] = [];
  for (let i = 0; i < N; i++) {
    const req = new Request("https://x/finance/dashboard", {
      method: "GET",
      headers: { authorization: `Bearer ${t}` },
    });
    const start = performance.now();
    const res = await handleRequest(req, configLoader);
    durations.push(performance.now() - start);
    assertEquals(res.status, 403, `request ${i} should be denied at the RBAC gate (403)`);
  }

  const p95Ms = p95(durations);
  assert(
    p95Ms < HANDLER_P95_BUDGET_MS,
    `denied-request in-process p95 was ${p95Ms.toFixed(2)}ms (budget < ${HANDLER_P95_BUDGET_MS}ms)`,
  );
});

// ── QA-R-006 (c): N-record batch payload — routing/validation is O(1) in size ─
// True at-scale persist latency is the live-k6 leg (QA-X-025). What we CAN prove
// locally: feeding a 1000-record body through the authorized hot path costs the
// same latency band as a 1-record body — the router/JWT/RBAC/parse cost does not
// scale with payload size, so a large class roster of attendance/marks does not
// blow up the pre-DB hot path.
Deno.test("QA-R-006: a 1000-record write payload routes/validates in the same latency band as a 1-record one", async () => {
  // Exam marks PATCH gates on manageExamMarks; attendance correction on manageSis.
  // Both reach the DB-free 503 once authorized, so the only thing the body size
  // changes is the parse/validation cost we want to bound.
  const marksToken = await token(["manageExamMarks"]);
  const sisToken = await token(["manageSis"]);

  function marksReq(records: number): Request {
    // A large bulk-marks-style body: N student rows in one request.
    const entries = Array.from({ length: records }, (_, i) => ({
      student_id: `00000000-0000-0000-0000-${String(i).padStart(12, "0")}`,
      marks_obtained: (i % 100),
      remarks: "auto",
    }));
    return new Request(
      "https://x/academics/exams/marks/00000000-0000-0000-0000-000000000001",
      {
        method: "PATCH",
        headers: {
          authorization: `Bearer ${marksToken}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({ marks_obtained: 50, batch: entries }),
      },
    );
  }

  function attendanceReq(records: number): Request {
    const corrections = Array.from({ length: records }, (_, i) => ({
      session_id: "00000000-0000-0000-0000-000000000001",
      student_id: `00000000-0000-0000-0000-${String(i).padStart(12, "0")}`,
      requested_status: i % 2 === 0 ? "present" : "absent",
      reason: "bulk correction",
    }));
    return new Request("https://x/attendance/corrections", {
      method: "POST",
      headers: {
        authorization: `Bearer ${sisToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ corrections, batch: corrections }),
    });
  }

  async function timeOnce(req: Request): Promise<{ ms: number; status: number }> {
    const start = performance.now();
    const res = await handleRequest(req, configLoader);
    return { ms: performance.now() - start, status: res.status };
  }

  // Warm up.
  await timeOnce(marksReq(1));
  await timeOnce(attendanceReq(1));

  // 1-record baseline vs 1000-record large roster, for both write paths.
  const marksSmall = await timeOnce(marksReq(1));
  const marksLarge = await timeOnce(marksReq(1000));
  const attSmall = await timeOnce(attendanceReq(1));
  const attLarge = await timeOnce(attendanceReq(1000));

  // The authorized write path is DB-free here: marks PATCH reaches 503; the
  // attendance correction handler validates the (single-record) body shape AFTER
  // the gate, so a 1000-record array body trips validation (422) — either way the
  // request passed JWT+RBAC, which is the cost we are bounding. Assert it stayed
  // off 401/403/404 (gate/route rejection) so we know the hot path actually ran.
  for (const r of [marksSmall, marksLarge, attSmall, attLarge]) {
    assert(
      r.status === 503 || r.status === 422,
      `expected an authorized DB-free outcome (503) or post-gate validation (422), got ${r.status}`,
    );
  }

  // O(1)-in-payload: a 1000-record body must process within the batch budget.
  assert(
    marksLarge.ms < BATCH_BUDGET_MS,
    `1000-record marks body took ${marksLarge.ms.toFixed(2)}ms (budget < ${BATCH_BUDGET_MS}ms) — routing/validation should not scale with payload size`,
  );
  assert(
    attLarge.ms < BATCH_BUDGET_MS,
    `1000-record attendance body took ${attLarge.ms.toFixed(2)}ms (budget < ${BATCH_BUDGET_MS}ms)`,
  );

  // Sub-linear: the 1000x body is not 1000x slower than the 1-record body. We
  // allow a generous 50ms absolute slack to stay robust on a noisy CI box while
  // still catching an accidental O(n) parse/validation regression.
  assert(
    marksLarge.ms <= marksSmall.ms + 50,
    `1000-record marks (${marksLarge.ms.toFixed(2)}ms) should be within 50ms of 1-record (${marksSmall.ms.toFixed(2)}ms) — payload size must not dominate the pre-DB hot path`,
  );
  assert(
    attLarge.ms <= attSmall.ms + 50,
    `1000-record attendance (${attLarge.ms.toFixed(2)}ms) should be within 50ms of 1-record (${attSmall.ms.toFixed(2)}ms)`,
  );
});
