# Akshara ERP — Performance Targets & SLA (SINGLE SOURCE OF TRUTH)

**Date:** 2026-06-30 · **Owner:** surendrakanna155@gmail.com
**Wave:** QW8 (final GA certification gate) · **Items:** QA-R-005 (performance targets + repeatable harness) · QA-R-006 (verify-at-scale)
**Governed by:** the Engineering Operating System (`/eos`) per [`engineering/ENGINEERING_GATE_POLICY.md`](engineering/ENGINEERING_GATE_POLICY.md).
**Constitution anchor:** [`engineering/AKSHARA_ENGINEERING_CONSTITUTION.md`](engineering/AKSHARA_ENGINEERING_CONSTITUTION.md) — Part 5A, *Performance Metrics / Acceptance Criteria / Failure Conditions*.

> **Purpose.** This is the authoritative, committed list of Akshara's numeric performance
> targets. The numbers were previously scattered as inline budgets across the latency probe,
> the Flutter benchmark tests, and the k6 script. This doc consolidates them into one table,
> with a **source citation per number**, maps each onto the Constitution's performance
> dimensions, and states plainly which targets are **verified LOCALLY** (synthetic scale, green
> in CI) versus which require the **live-VPS k6 cron** (INFRA-BLOCKED, carried on the
> live-regression lane). No target lives in only one test file anymore — this doc is the index.

---

## 1. Constitution performance dimensions (Part 5A)

The Engineering Constitution (Part 5A, *Performance Metrics*) requires tracking these dimensions:

| # | Constitution dimension | Akshara coverage |
|---|---|---|
| D1 | Application startup | Dashboard/first-screen load budget (see T2) |
| D2 | Average screen load | Dashboard < 500ms (T2); large-school SIS/list loads (T3–T5) |
| D3 | API latency | Backend p95 read/write (T1, live) + in-process handler p95 (T6, local) |
| D4 | Search / list latency | Large-school paged loads (T5); large-list lazy render (T7, T8) |
| D5 | Synchronization latency | Offline read-cache + sync (built QW6) — covered by the resilience wave, not re-stated here |
| D6 | Crash-free sessions | CI widget/golden suite (Flutter) + EOS gate; no separate numeric SLA in this doc |
| D7 | Memory usage | Bounded render window / recycling proof (T7, T8) — lazy lists keep render-tree memory O(viewport), not O(n) |

The Constitution's *Acceptance Criteria* are qualitative ("remains responsive / smooth /
reliable; degradation within accepted targets; scalability objectives achieved"). The numeric
targets below are the engineering team's committed, testable expression of those criteria.

---

## 2. Committed targets

Legend — **Verification:** `LOCAL` = asserted by a green test in CI (synthetic scale) ·
`LIVE` = asserted only by the scheduled k6 cron against the live VPS pilot (production-representative
infra) · `INFRA-BLOCKED` = the live leg has no scheduled runner yet, so it is carried on the
live-regression lane and flips to verified on its first scheduled run.

| ID | Target | Budget | Constitution dim | Verification | Source citation |
|----|--------|--------|------------------|--------------|-----------------|
| **T1a** | Backend p95 read latency (auth/login, dashboard) | **< 224 ms** | D3 | LIVE · **INFRA-BLOCKED** | `scripts/perf/qa_x_025_p95_latency_probe.js` L38, L59–62 + [`scripts/perf/README.md`](../scripts/perf/README.md) |
| **T1b** | Backend p95 write latency (finance collect, exam publish) | **< 400 ms** | D3 | LIVE · **INFRA-BLOCKED** | `scripts/perf/qa_x_025_p95_latency_probe.js` L40, L64–65 + README |
| **T1c** | Backend error budget (`http_req_failed`) | **< 1%** | D3 | LIVE · **INFRA-BLOCKED** | `scripts/perf/qa_x_025_p95_latency_probe.js` L67 + README |
| **T2** | Dashboard load (finance/inventory/intelligence/SIS dashboards) | **< 500 ms** | D1, D2 | LOCAL | `test/performance/pilot_dashboard_benchmark_test.dart` L12, L21–57 |
| **T3** | Large-school SIS student list | **< 800 ms** | D2, D4 | LOCAL | `test/performance/large_school_benchmark_test.dart` L9, L19–26 |
| **T4** | Large-school batch dashboard loads | **< 1200 ms** | D2 | LOCAL | `test/performance/large_school_benchmark_test.dart` L10, L28–35 |
| **T5** | Large-school paged list loads (50/100-per-page) | **< 1500 ms** | D2, D4 | LOCAL | `test/performance/large_school_benchmark_test.dart` L37–45 |
| **T6** | In-process backend handler p95 (route match + JWT verify + RBAC gate + parse), DB-free | **p95 < 50 ms · max < 250 ms** | D3 | LOCAL | `supabase/functions/_shared/perf/qa_r_006_handler_latency_bench_test.ts` (`HANDLER_P95_BUDGET_MS` / `HANDLER_MAX_BUDGET_MS`) |
| **T7** | Large-list lazy render (5000-row list builds only a viewport window) | **itemBuilder calls < viewport+30 (≈40) of 5000** | D4, D7 | LOCAL | `test/performance/qa_x_024_large_list_lazy_render_test.dart` L22, L33 |
| **T8** | Large-roster render (5000-pupil marks/attendance roster) | **build < 250 ms · itemBuilder calls < viewport+30 (≈36) of 5000 · recycling on deep scroll** | D2, D4, D7 | LOCAL | `test/performance/qa_r_006_large_roster_render_test.dart` (`buildBudgetMs` / `lazyCeiling`) |

---

## 3. Verified-LOCALLY vs LIVE-only — what GA can rely on

### Verified LOCALLY (green in CI, synthetic scale) — the QA-R-006 local half

- **T2–T5** — Flutter dashboard / large-school benchmarks run against the mock repositories at
  pilot/large-school scale and assert their wall-clock budgets every CI run.
- **T6** — `qa_r_006_handler_latency_bench_test.ts` fires **N = 200** synthetic requests through
  the in-process `handleRequest` (extracted from `Deno.serve` so it is socket-free unit-testable —
  see `supabase/functions/api/app.ts` ~L226). It uses the established **DB-free seam**: a config
  with empty `supabaseUrl`/`serviceRoleKey` makes session validation a no-op (no network — see
  `supabase/functions/_shared/session_validation.ts` L96) and a null `erpTenantDatabaseUrl` makes an
  authorized route resolve to **503 TENANT_DB_NOT_CONFIGURED** (the "authorized-but-no-DB" proxy used
  across the `qw4_*_route_contract_test.ts` suite). It asserts the aggregate p95 of the hot path
  (route match + JWT verify + RBAC gate + body parse/validation) under T6. A second N = 200 run
  proves denied (403) requests are at least as cheap, and a **1000-record** batch payload proves the
  routing/validation cost is **O(1) in payload size** (a large roster body routes/validates in the
  same latency band as a 1-record body).
- **T7, T8** — 5000-row lazy-render proofs. They assert the render tree only ever materializes a
  viewport-sized window (laziness → O(viewport), not O(n)), the last row is not built up front, and
  rows are recycled (not retained) after a deep scroll — the bounded-render-memory property (D7).

### LIVE-only — INFRA-BLOCKED, carried on the live-regression lane — the QA-R-006 live half

- **T1a / T1b / T1c** — the headline **224 ms read / 400 ms write p95** and **< 1% error budget**
  are the production SLA. They are meaningful only against production-representative infra (real
  edge + Postgres + connection pool + network), so they are asserted exclusively by
  `scripts/perf/qa_x_025_p95_latency_probe.js` (k6) run against the live VPS pilot.
  **This is INFRA-BLOCKED**: there is no scheduled latency-probe runner in the dev environment, so
  the script has **no green local unit test by design** (it throws in `setup()` if `API_BASE_URL` is
  unset). It is the direct analogue of QW1's live-regression cron rows; it flips to *Verified* on its
  first scheduled run against the live VPS. Until then T1 is carried on the live-regression lane,
  **not** claimed as locally verified.

> **GA statement.** Akshara's client-side and in-process backend performance (T2–T8) is verified
> locally at synthetic scale and green in CI. The end-to-end production p95 SLA (T1) is authored and
> wired but **INFRA-BLOCKED** pending the scheduled live-VPS k6 cron; it must not be marked verified
> from local evidence.

---

## 4. Repeatable harness (QA-R-005)

| Layer | Harness | Command |
|-------|---------|---------|
| Flutter perf budgets (T2–T5, T7, T8) | `flutter_test` widget/benchmark tests under `test/performance/` | `flutter test test/performance/` |
| Backend in-process latency (T6) | Deno test using the DB-free `handleRequest` seam | `deno test --allow-env --allow-read supabase/functions/_shared/perf/` |
| Live backend p95 SLA (T1) | k6 latency-regression probe (live VPS only) | `API_BASE_URL=https://<host>/functions/v1/api k6 run scripts/perf/qa_x_025_p95_latency_probe.js` |

The first two layers run in CI on every push (the same invocations the project's
`flutter_ci.yml` / `backend_staging.yml` workflows already use for the test suite). The third is the
scheduled live-regression cron and is INFRA-BLOCKED until that runner exists.

---

## 5. Change control

Any change to a number in §2 must (a) update the cited source budget in the test/script and
(b) update its row here in the same commit — the doc and the asserting test are kept in lockstep so
this table never drifts from what CI actually enforces.
