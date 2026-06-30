// QA-X-025 — Backend p95 latency regression probe (k6).
//
// ⚠️  INFRA-BLOCKED — REQUIRES THE LIVE VPS ENVIRONMENT. ⚠️
// This script is NOT runnable in local CI: there is no scheduled latency probe
// in the dev environment and the hot endpoints require a live edge + real DB +
// real auth. It is authored here so it can be wired to a scheduled run against
// the live pilot VPS (see ./README.md). Do not expect it to go green locally.
//
// What it does:
//   Drives k6 traffic at the hot read/write endpoints exercised on every login
//   and dashboard load — auth/login, dashboard, finance collect, exam publish —
//   and asserts a per-endpoint AND aggregate p95 latency budget. The baseline
//   budget (224ms p95) is taken from the live performance certification; a
//   scheduled run that breaches it is a latency regression.
//
// Run (live VPS only):
//   API_BASE_URL=https://akshara.veloraunisexsalon.com/functions/v1/api \
//   ADMIN_PHONE=9876543210 \
//   k6 run scripts/perf/qa_x_025_p95_latency_probe.js
//
// Optionally provide a pre-minted token to skip the login leg:
//   ACCESS_TOKEN=eyJ... k6 run scripts/perf/qa_x_025_p95_latency_probe.js
import http from "k6/http";
import { check, group, sleep } from "k6";
import { Trend } from "k6/metrics";

// ---------------------------------------------------------------------------
// Config — ALL live-env driven. No localhost default on purpose: this probe is
// meaningless without a real backend, so it fails loudly if BASE_URL is unset.
// ---------------------------------------------------------------------------
const BASE_URL = __ENV.API_BASE_URL;
const ADMIN_PHONE = __ENV.ADMIN_PHONE || "9876543210";
const ORG_ID = __ENV.ORG_ID || "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = __ENV.SCHOOL_A || "a2000000-0000-4000-8000-000000000001";
const PRESET_TOKEN = __ENV.ACCESS_TOKEN || "";

// Baseline p95 budget (ms) from the live performance certification.
const P95_BUDGET_MS = Number(__ENV.P95_BUDGET_MS || 224);
// A slightly looser per-endpoint ceiling for the write path (collect/publish).
const P95_WRITE_BUDGET_MS = Number(__ENV.P95_WRITE_BUDGET_MS || 400);

// Per-endpoint latency trends so a regression can be attributed to one route.
const loginLatency = new Trend("ep_auth_login_ms", true);
const dashboardLatency = new Trend("ep_dashboard_ms", true);
const collectLatency = new Trend("ep_finance_collect_ms", true);
const examPublishLatency = new Trend("ep_exam_publish_ms", true);

export const options = {
  // Modest, steady load — this is a latency-regression probe, not a stress test.
  scenarios: {
    hot_endpoints: {
      executor: "constant-vus",
      vus: Number(__ENV.VUS || 10),
      duration: __ENV.DURATION || "1m",
    },
  },
  thresholds: {
    // Aggregate read budget — the headline 224ms p95 cert number.
    "http_req_duration{kind:read}": [`p(95)<${P95_BUDGET_MS}`],
    // Per-endpoint read budgets.
    "ep_auth_login_ms": [`p(95)<${P95_BUDGET_MS}`],
    "ep_dashboard_ms": [`p(95)<${P95_BUDGET_MS}`],
    // Write path gets a looser ceiling but is still bounded.
    "ep_finance_collect_ms": [`p(95)<${P95_WRITE_BUDGET_MS}`],
    "ep_exam_publish_ms": [`p(95)<${P95_WRITE_BUDGET_MS}`],
    // Overall error budget: <1% failures.
    "http_req_failed": ["rate<0.01"],
  },
};

function jsonHeaders(token) {
  const h = { "Content-Type": "application/json" };
  if (token) h["Authorization"] = `Bearer ${token}`;
  return h;
}

// OTP login → access token (mirrors scripts/*_smoke.sh login_phone).
function login() {
  if (PRESET_TOKEN) return PRESET_TOKEN;

  const start = http.post(
    `${BASE_URL}/auth/login`,
    JSON.stringify({ identifier: ADMIN_PHONE, type: "phone" }),
    { headers: jsonHeaders(), tags: { kind: "read", ep: "auth_login_start" } },
  );
  loginLatency.add(start.timings.duration);
  const startBody = start.json("data") || {};
  const sessionId = startBody.sessionId;
  // Dev/cert backends surface the OTP in the response for automation.
  const otp = startBody.otp ||
    (startBody.message && (startBody.message.match(/(\d{4,8})/) || [])[1]);
  if (!sessionId || !otp) return "";

  const verify = http.post(
    `${BASE_URL}/auth/verify-otp`,
    JSON.stringify({
      identifier: ADMIN_PHONE,
      type: "phone",
      otp,
      sessionId,
      scope: "school",
      schoolId: SCHOOL_A,
    }),
    { headers: jsonHeaders(), tags: { kind: "read", ep: "auth_verify" } },
  );
  loginLatency.add(verify.timings.duration);
  return (verify.json("data") || {}).accessToken || "";
}

export function setup() {
  if (!BASE_URL) {
    throw new Error(
      "QA-X-025 is INFRA-BLOCKED: set API_BASE_URL to the live VPS edge " +
        "(e.g. https://<host>/functions/v1/api). This probe cannot run locally.",
    );
  }
  const token = login();
  if (!token) {
    throw new Error(
      "QA-X-025: could not obtain an access token from the live backend. " +
        "Provide ACCESS_TOKEN=... or ensure ADMIN_PHONE can log in.",
    );
  }
  return { token };
}

export default function (data) {
  const token = data.token;
  const headers = jsonHeaders(token);

  group("dashboard (hot read)", () => {
    const res = http.get(`${BASE_URL}/dashboard`, {
      headers,
      tags: { kind: "read", ep: "dashboard" },
    });
    dashboardLatency.add(res.timings.duration);
    check(res, { "dashboard 2xx": (r) => r.status >= 200 && r.status < 300 });
  });

  group("finance collect (hot write)", () => {
    // Idempotency-keyed collect so repeated probe runs don't double-post money.
    const res = http.post(
      `${BASE_URL}/finance/collections`,
      JSON.stringify({
        invoiceId: __ENV.PROBE_INVOICE_ID || "probe-invoice",
        amount: 1,
        paymentMethod: "cash",
        idempotencyKey: `qa-x-025-${__VU}-${__ITER}`,
      }),
      {
        headers: {
          ...headers,
          "Idempotency-Key": `qa-x-025-${__VU}-${__ITER}`,
        },
        tags: { kind: "write", ep: "finance_collect" },
      },
    );
    collectLatency.add(res.timings.duration);
    // 2xx (collected) or 4xx (validation/idempotent replay) are both fine for
    // latency measurement; a 5xx is a real failure counted by http_req_failed.
    check(res, { "collect responded < 500": (r) => r.status < 500 });
  });

  group("exam publish (hot write)", () => {
    const res = http.post(
      `${BASE_URL}/exams/${__ENV.PROBE_EXAM_ID || "probe-exam"}/publish`,
      JSON.stringify({ idempotencyKey: `qa-x-025-pub-${__VU}-${__ITER}` }),
      {
        headers: {
          ...headers,
          "Idempotency-Key": `qa-x-025-pub-${__VU}-${__ITER}`,
        },
        tags: { kind: "write", ep: "exam_publish" },
      },
    );
    examPublishLatency.add(res.timings.duration);
    check(res, { "publish responded < 500": (r) => r.status < 500 });
  });

  sleep(1);
}
