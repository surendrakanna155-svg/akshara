# Akshara ERP — QA & Certification-Integrity Audit

**Auditor:** Fable (independent) · **Date:** 2026-07-03 · **HEAD:** `68f15cb` · **Branch:** `feature/data-reliability-platform`
**Part of:** the Fable Final Independent Product Audit. Master report: [`00_FABLE_MASTER_AUDIT_REPORT.md`](00_FABLE_MASTER_AUDIT_REPORT.md).
**Confidence:** High (evidence-cited); live-run reproducibility = Unknown (VPS not reachable from the audit environment).

> This is the single most important report in the package. It answers one question the whole
> project rests on: **are the "237 Verified rows / QW1–QW8 complete / PRODUCTION CERTIFIED" claims
> real, or inflated?** The honest answer is: **substantially real, never fraudulent — but the
> vocabulary systematically over-promises.** "Verified" is one word covering four very different
> grades of evidence, and the hardest half (live DB, cross-tenant RLS, CI enforcement, on-device
> E2E) has, by the project's own admission, never run.

---

## 1. Headline verdict

| Question | Answer |
|---|---|
| Is the QA program fabricated / faked? | **No.** Tests assert genuine logic; money math, the frozen absent-student exclusion rule, maker-checker SoD, and the RBAC matrix all run **production code**, not tautological mocks. |
| Does "237 Verified" mean 237 end-to-end proofs? | **No.** "Verified" spans 4 evidence grades. Estimated split: **~40% real-logic-local, ~22% route-contract-only, ~25% render-on-mock, single-digit-% proven-live**. |
| Has the CI/live-regression enforcement ever run on this work? | **Almost certainly not.** The working branch is 338 commits ahead of `origin/main`; CI triggers only on `main`/`release/**`/PR; the crons are the project's own "Test-Written, first scheduled run pending" rows. |
| Has cross-tenant RLS isolation (the core multi-tenant guarantee) been proven? | **No.** The isolation probes are `ignore`-gated on a tenant DB URL that is never present in CI. Never executed. |
| Is the project honest about the above? | **Yes, remarkably.** Every QW cert says "locally-verifiable scope COMPLETE / CONDITIONAL"; QW8 refuses to declare GA and lists every staged leg. The inflation is in the *summary* language, not hidden fakery. |

**Net:** The engineering *substance* is much better than a skeptic expects; the engineering *scoreboard* is much rosier than the substance warrants. The gap between them is the single biggest governance risk in the project.

---

## 2. The "Verified" reality assessment

The tracker (`docs/FINAL_QA_MASTER_TRACKER.md`) has **283 data rows, 237 marked `Verified`**. Counting the dominant proof cited per row, and cross-checking against the test corpus:

| Evidence grade | Est. count | What it actually proves | Example |
|---|---:|---|---|
| **(a) Live end-to-end** (real VPS + Postgres + auth + RBAC) | **~3–10** | The real thing works | B10/B11/Question-Intelligence live certs (but see §5 — no committed run artifacts) |
| **(b) Local, real logic** (money math, algorithms, real state in-memory, real RBAC map) | **~90–110** | The business logic is correct in isolation | finance collection math, exam rank/exclusion, SoD |
| **(c) Route-contract only** (the "503 = authorized" pattern) | **~53** | The route exists + a permission gate is called | `qw4_finance_route_contract_test.ts` |
| **(d) Render-on-mock** (widget pump / Patrol on mock data) | **~50–70** | The UI renders + has 4 states, against fake data | most `QA-F-*` rows; all 135 Patrol journeys |
| **(e) Staged / never-run** but on a Verified-adjacent line | **~28** | Nothing yet | persistence legs marked "= live-DB" |

Source: direct phrase-counts in the tracker + two independent test-quality deep-dives + a full backend test census (247 files, 1,913 `Deno.test` cases).

---

## 3. What the "503 = authorized" pattern does and does NOT prove

QW4 certified backend routes with a DB-free pattern: a test-minted JWT flows through the router; the handler calls a permission gate; the request then hits the unconfigured DB and returns **`503 TENANT_DB_NOT_CONFIGURED`**. A 503 is read as "authorization passed."

**It genuinely proves** (and these are worth having): route is registered + method-matched; resolves to a specific handler; that handler calls *a* permission gate; missing slug → **403**; unauthenticated → **401**; verb anti-escalation where distinct slugs are wired; pre-DB body validation → **422**; envelope/CORS/correlation-id. **It found and fixed two real bugs** — the systemic OR→AND RBAC inversion across 29 sites (QW4-INV-OR) and a completely unaudited exam-publish mutation. The suites earned their keep.

**It does NOT prove** (and these are the load-bearing gaps): the handler's business logic or output payload; that any DB read/write is correct; **cross-tenant RLS isolation**; that the **role→permission mapping** is right (permissions are *injected* into the test JWT, not derived from a role); **session revocation / logout / demotion take effect** (`session_validation.ts:96-99` short-circuits the entire session-check DB path whenever the DB URL is absent — which is *always*, in these tests); idempotency; persistence; money correctness.

**Conclusion:** it is a legitimate **route-and-gate registration proof**, appropriately scoped. The only danger is reading "Verified" as "the endpoint works." **53 of the 237 Verified rows rest on this.**

---

## 4. The Patrol "E2E journeys" are widget-on-mock, not device-E2E

- **All 135 Patrol tests run with `enableApiMode: false` + `SchoolConfiguration.demoDefault()` + QA-login personas** (`patrol_test/helpers/patrol_app.dart:22-29`). **Zero** files use `$.native` (real device automation).
- The P0 "parent pays fee end-to-end" (`QA-J-001`) is Verified by a test whose own comment says **"mock gateway → initiate → confirm"** and treats mock-store retrieval as "the persistence proof" (`patrol_test/workflows/qw1_parent_money_loop_e2e_test.dart:31-40`). **The real backend money path is never exercised by this "Verified" P0.**
- These are real *UI* proofs (screens render, forms validate, navigation works) — but against fake data. They should be labelled "widget-journey (mock)," not "E2E."

---

## 5. The credible live certs exist — but their evidence isn't committed

The B-series/Journey certifications (B10 Org Builder, B11 Dynamic Widgets, Question Intelligence, the Pilot Simulation) are a **higher regime** than QW: their harnesses genuinely hit the live VPS (`https://akshara.veloraunisexsalon.com`), connect to real Postgres via SSH + `docker exec`, mint real org-scoped JWTs, and assert real DB state + 402/403 (`scripts/qa/live_cert_b10_organization_builder.py:14-58`). The scripts are demonstrably capable of a real run.

**But:** no machine-readable run artifacts are committed. Every "17 PASS / 0 FAIL", "live 34/34", "20/20" is **self-reported prose inside the cert doc**, unverifiable independently, and only ~4 of ~30 live scripts run in the ongoing cron — so the rest are point-in-time snapshots dated 2026-06-25→30 that **may have silently regressed** since. "PRODUCTION CERTIFIED" currently rests on trust, not reproducible evidence.

---

## 6. CI enforcement reality

- **Well-authored, plausibly never run on this work.** 5 workflows exist. `flutter_ci.yml` correctly makes the backend Deno tree a merge gate and enforces both coverage floors *in YAML*.
- **But triggers exclude the working branch.** `flutter_ci` → `push:[main, 'release/**']` + PR. `backend_staging` → `push:[main]`. The entire QW1–QW8 program sits on `feature/data-reliability-platform`, **338 commits ahead of `origin/main`** (last touched 2026-06-15, pre-QW). No PRs, no merges.
- **The project admits the crons are unproven:** `live_regression.yml` (nightly), `maestro_chains.yml`, and full nightly Patrol are the literal "Test-Written … first scheduled run pending" rows (`QA-X-035/036/039`, `QA-B-073`).
- **Net:** the coverage/analyze/route-contract gates *would* bite on a real PR run, but **there is no evidence any of it has executed on this branch, and the live-regression cron — the one thing that would turn the staged live legs green — has never run.**

---

## 7. Coverage is real (a genuine strength)

Flutter **60.24%** / backend **41.4%** are *not* smoke-inflated: the largest covered bucket is business logic (`lib/core/repositories` 54.7%), with exams 90%, audit 92%, security 72%. The floor gate is genuinely wired (`scripts/qa/check_coverage_threshold.sh`, `flutter_ci.yml:38-43`) with a ratchet-up-never-down policy. Caveat: it only bites if the workflow runs (§6), and the committed `coverage/lcov.info` is stale (Jun 28 vs Jul 3 HEAD).

---

## 8. Findings

| ID | Sev | Finding | Evidence | Recommendation |
|---|---|---|---|---|
| QA-1 | **P1** | "Verified" conflates 4 evidence grades; readers infer 237 live proofs | tracker; §2 | Add an **evidence-grade column** (LIVE / LOCAL-LOGIC / CONTRACT / RENDER-MOCK / STAGED). Stop labelling STAGED legs "Verified." |
| QA-2 | ~~P0~~ → **CLOSED (live PASS)** | Cross-tenant RLS isolation was never executed in the suite — **now live-verified 2026-07-03** (report 11 §3b): read + write, cross-tenant + cross-school + parent-scope isolation all PASS, run as the real `erp_tenant` role against real data, rolled back | `tenant_isolation_enforced_test.ts:12,16` (`ignore`-gated); **live probe: 7/7 read + 2/2 write PASS** | ✅ Closed for the live DB. **Still wire the 233-probe suite into CI** for per-table regression coverage (it will now pass). |
| QA-3 | **P0** | The live-regression cron has never run; CI has (almost certainly) never run on the QW branch | §6; branch 338 ahead of `origin/main` | Merge to a gated branch (or add `push: feature/**`), capture + commit the first green run IDs. GA gate depends on 7-day green — the clock has not started. |
| QA-4 | **P1** | 135 "E2E journeys" are widget-on-mock; the P0 money loop uses a mock gateway | `patrol_app.dart:22-29`; `qw1_parent_money_loop_e2e_test.dart:31-40` | Reclassify as "widget-journey (mock)"; reserve the E2E claim for live-cert scripts. |
| QA-5 | **P1** | "PRODUCTION CERTIFIED" pass-counts are self-reported prose; no run artifacts committed | §5 | Commit machine-readable run logs (JSON: timestamp + counts) per live cert; wire all ~30 live scripts into the cron. |
| QA-6 | **P1** | 34 P0 + 23 P1 rows are NOT Verified (Blocked/Partial/Test-Written), concentrated in live-infra | tracker non-Verified rows | State the P0/P1 residual **prominently** next to every "complete" claim. |
| QA-7 | **P2** | 41 of 51 backend routers have no dedicated router test | backend census (§ below) | Add route-match/404 tests for the 41 (finance, transport, hostel, hr, inventory, library, alumni, director, communication…). |
| QA-8 | **P2** | Committed `coverage/lcov.info` is stale (Jun 28 vs Jul 3) | file mtime | Regenerate on each CI run; never rely on a committed lcov. |

---

## 9. Genuine strengths (real rigor, not theater)

- **Non-tautological business-logic tests.** Money reconciliation, spillover allocation, refund ceilings, maker-checker self-approve denial, and the **frozen absent/ML/DB exclusion-from-rank/avg rule tested with real numbers in 3 independent layers** — the fakes supply the row; production code drops it; the assertions fail if the logic is removed.
- **RBAC tests exercise production code**, resolving via the real `RbacService`/`RolePermissionMatrix` (`lib/core/security/role_permissions.dart:34`) with an enum-coverage guard so a new role can't silently escape the matrix.
- **The contract suites found and fixed real bugs** (the 29-site RBAC inversion; the unaudited exam-publish).
- **Coverage is meaningful and honestly floored.**
- **Radical honesty in the certs** — QW8 refuses to declare GA and lists every staged leg. The 503-pattern's limits are documented in the test headers themselves.

## 10. Backend test census (context)

247 test files / 1,913 `Deno.test`: 53 files/608 tests = 503-pattern · 50 files/470 = in-memory fake-DB (real money/status logic) · 146 files/998 = pure logic · 72 files/539 = QA/cert-linked · **2 files/2 tests = live-DB integration, skipped in CI**. 10 of 51 routers have dedicated router tests.

## 11. Unknowns

- Whether any CI workflow has *ever* run (inferred from branch/trigger topology — strong — but `gh` was unauthenticated).
- Whether the live-cert pass counts are truthful *today* (no committed artifacts; VPS unreachable from here).
- Exact green/red state of the suites on HEAD (counted declarations consistent with claimed 1,344 backend / 3,164 Flutter; did not execute).

## 12. Bottom line

The single most important sentence in this audit: **by the project's own gate, GA is BLOCKED — and the two things that would unblock it (the live-regression cron running 7 days green, and the cross-tenant RLS isolation probes passing on a real tenant DB) have never executed even once.** Until they do, "production ready" is unproven — not by a skeptic's standard, but by Akshara's own `QA-R-012` checklist.
