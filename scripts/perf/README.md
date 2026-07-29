# Performance / latency probes (`scripts/perf/`)

Load and latency probes that run against the **live VPS pilot**, not local CI.

## QA-X-025 — Backend p95 latency regression probe (INFRA-BLOCKED)

**File:** `qa_x_025_p95_latency_probe.js` (k6)

**Status: INFRA-BLOCKED — authored, not locally runnable.**
There is no scheduled latency probe in the dev environment, and the endpoints
this script targets (`auth/login`, `dashboard`, `finance collect`,
`exam publish`) require a live edge + real DB + real auth. This is the QW6
analogue of QW1's live-regression cron rows (e.g. `QA-X-035 / QA-X-036 /
QA-X-039` in `docs/QW1_COMPLETION_CERTIFICATION.md`): the artifact is written
and valid, and it flips to *Verified* on its **first scheduled run against the
live VPS** — it intentionally has **no green local unit test**.

### What it asserts

- **Aggregate read p95 < 224ms** — the baseline from the live performance
  certification (override with `P95_BUDGET_MS`).
- **Per-endpoint read p95** for `auth/login` and `dashboard` < the same budget,
  so a regression can be attributed to a single route.
- **Write-path p95** (`finance collect`, `exam publish`) < `P95_WRITE_BUDGET_MS`
  (default 400ms).
- **Error budget** `http_req_failed` rate < 1%.

A k6 run **exits non-zero** when any threshold is breached — that is the
latency-regression signal a scheduled job should alert on.

### Why it cannot run in local CI

- No localhost default for `API_BASE_URL` — the script throws in `setup()` if it
  is unset, so it fails loudly rather than producing a meaningless local number.
- It needs real OTP login against the live backend (or a pre-minted
  `ACCESS_TOKEN`) and live finance/exam fixtures to exercise the write paths.
- p95 is only meaningful against production-representative infra (real network,
  real Postgres, real connection pool), which the dev box does not have.

### Running it (live VPS only)

Requires [`k6`](https://k6.io/docs/get-started/installation/).

```bash
# Read + write hot endpoints, OTP login, 224ms p95 budget:
API_BASE_URL=https://api.nikshaos.in/functions/v1/api \
ADMIN_PHONE=9876543210 \
k6 run scripts/perf/qa_x_025_p95_latency_probe.js

# Skip the login leg with a pre-minted token:
API_BASE_URL=https://<host>/functions/v1/api \
ACCESS_TOKEN=eyJ... \
k6 run scripts/perf/qa_x_025_p95_latency_probe.js
```

### Environment variables

| Var | Required | Default | Purpose |
|-----|----------|---------|---------|
| `API_BASE_URL` | **yes** | _(none — throws)_ | Live edge base, e.g. `https://<host>/functions/v1/api` |
| `ACCESS_TOKEN` | no | _(login via OTP)_ | Pre-minted bearer token to skip the login leg |
| `ADMIN_PHONE` | no | `9876543210` | Phone used for OTP login |
| `SCHOOL_A` / `ORG_ID` | no | pilot IDs | Login scope / tenant |
| `P95_BUDGET_MS` | no | `224` | Read-path p95 budget (cert baseline) |
| `P95_WRITE_BUDGET_MS` | no | `400` | Write-path p95 budget |
| `VUS` / `DURATION` | no | `10` / `1m` | Virtual users / run duration |
| `PROBE_INVOICE_ID` / `PROBE_EXAM_ID` | no | placeholders | Live fixtures for the write paths |

### Wiring it to a schedule

Run on a nightly/cron job from a host that can reach the live VPS (the same
place QW1's live-regression DB/CI crons run). Treat a non-zero k6 exit (any
breached threshold) as a latency-regression alert. Until that scheduled run
exists, this row stays **INFRA-BLOCKED**.
