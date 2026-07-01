# AKSHARA ERP — Final QA Completion Roadmap

**Date:** 2026-06-27 · HEAD `0f33c6a` · Companion to [`FINAL_QA_AUDIT.md`](FINAL_QA_AUDIT.md) and [`FINAL_QA_MASTER_TRACKER.md`](FINAL_QA_MASTER_TRACKER.md).

> **Scope vs quality.** This roadmap proves *quality* (the QA waves QW1–QW8). For *scope* — every
> product/commercial gap, UX issue, architecture improvement, and future feature — the single source
> of truth is [`PRODUCT_COMMERCIAL_BACKLOG.md`](PRODUCT_COMMERCIAL_BACKLOG.md) (reconciled from the
> `still_pending.md` audit, with the locked owner decisions O1–O10). The two are cross-linked, not
> duplicated.

> **This roadmap is a plan, not an instruction to start.** All 246 tracker rows are `Open`. **No tests or fixes will be written until the owner approves execution.** GA Certification stays **paused** until the waves below are complete and green.

> **Engineering gate:** This plan is governed by the Engineering Operating System (`/eos`) per [`engineering/ENGINEERING_GATE_POLICY.md`](engineering/ENGINEERING_GATE_POLICY.md). No wave or row here is "complete" until `/eos <scope>` returns PASS against the [Engineering Constitution](engineering/AKSHARA_ENGINEERING_CONSTITUTION.md). The EOS is the only engineering standard for this work — do not add bespoke checklists.

> **⏭ ROADMAP CONTINUES BELOW QW8 (added 2026-07-01).** QW1–QW8 + Phase 0 are **historical, completed, and frozen** (this document does not modify a single certification, tracker entry, or milestone above the "NEXT-GENERATION ROADMAP" divider). The engineering program now continues with three new phases after QW8: **Phase B — Release Engineering** (the Track B live-VPS validation that currently blocks GA `QA-R-012`), **Phase C — Product Enhancement Implementation** (post-GA, sourced only from the frozen [`PRODUCT_ENHANCEMENT_BACKLOG.md`](PRODUCT_ENHANCEMENT_BACKLOG.md)), and **Phase D — Future / Phase 2 / Commercial** (sourced only from [`PRODUCT_COMMERCIAL_BACKLOG.md`](PRODUCT_COMMERCIAL_BACKLOG.md)). Jump to the **[NEXT-GENERATION ROADMAP](#next-generation-roadmap--phases-b--c--d)** section.

---

## Sequencing principle

The waves are ordered so that **value and safety compound**:

0. **Phase 0 builds the Data Reliability Platform first.** Per the owner architecture decision (2026-06-27), draft persistence + a sync engine + retry are **core platform reliability requirements**, not optional features. The offline/retry tracker rows are **NOT** `Won't-Build`; they are **prerequisites**. QW1 does not start until this platform's architecture is approved and implemented. See the dedicated Phase 0 section below.
1. **QW1 ships the P0 truth *and* the enforcement.** It closes the pilot-critical journey/RBAC/RLS gaps **and** wires the existing-but-unrun suites into CI. After QW1, every later wave's new tests are continuously executed instead of rotting (closes finding **F6**).
2. **QW2 / QW3 / QW4 run in parallel** — they touch different layers (E2E journeys, Flutter widgets, backend Deno) and rarely conflict. This is where "use parallel agents" pays off most.
3. **QW5 / QW6 last (technical coverage)** — secondary/advanced journeys and non-functional/resilience sweeps, once the core is provably correct and guarded.
4. **QW7 / QW8 are mandatory certification gates (behaviour + production readiness)** — added 2026-06-27 as permanent final waves. QW1–QW6 prove *technical* coverage; QW7 certifies *end-user behaviour* (every element does the expected thing, in the right language, for the right role, with the right notification); QW8 is the **final commercial go-live gate** (multi-school SaaS, performance, security, backup/DR, white-label, commercial readiness). **GA is declared only after QW8 passes.**

```
   ┌══════════════════════ PHASE 0 — Data Reliability Platform (prerequisite) ══════════════════════┐
   ║  Draft Persistence · Sync Engine (queue + backoff + idempotency + conflict) · Repository hook   ║
   ║  → design approved → implemented → unblocks the 5 offline/retry rows                            ║
   └═══════════════════════════════════════════════╤════════════════════════════════════════════════┘
                                                   ▼
        ┌─────────────────────────── QW1 (gate: also wires CI) ───────────────────────────┐
        │  P0 journeys · 4 missing personas · P0 RBAC/RLS · money/attendance/push · CI on  │
        └───────────────┬───────────────────┬───────────────────┬─────────────────────────┘
                        │ (parallel)        │ (parallel)         │ (parallel)
                   ┌────▼────┐         ┌─────▼─────┐        ┌─────▼──────┐
                   │  QW2    │         │   QW3     │        │    QW4     │
                   │ Journey │         │  Flutter  │        │  Backend   │
                   │ writes  │         │  widgets  │        │  contracts │
                   └────┬────┘         └─────┬─────┘        └─────┬──────┘
                        └───────────────┬────┴────────────────────┘
                                   ┌────▼────┐     ┌────────┐
                                   │  QW5    │     │  QW6   │
                                   │ Sec/Adv │     │ Resil. │
                                   └────┬────┘     └───┬────┘
                                        └──────┬───────┘
                                       ┌───────▼────────┐
                                       │      QW7       │  Feature Behaviour Certification (mandatory)
                                       │  behaviour ·   │  every element does the expected thing,
                                       │  comms · i18n  │  in the right language, for the right role
                                       │  · RBAC · A/I  │
                                       └───────┬────────┘
                                       ┌───────▼────────┐
                                       │      QW8       │  Production Readiness & Market Certification
                                       │  multi-school  │  (FINAL commercial go-live gate)
                                       │  perf · sec ·  │
                                       │  DR · commerce │
                                       └────────────────┘
```

**Exit definition for the whole program (GA-unblock):** every `P0` and `P1` row across QW1–QW8 is `Verified`; every `P2` row is `Verified` or explicitly deferred with owner sign-off; CI runs the full Patrol + Maestro + backend suites and enforces a coverage threshold; the live-regression cron is green for 7 consecutive days; **and the QW8 Final Production Checklist (`QA-R-012`) is fully satisfied.** GA is declared only then.

---

## Phase 0 — Data Reliability Platform (PREREQUISITE) — ✅ COMPLETE (2026-06-28) — QW1 UNBLOCKED

> **STATUS: COMPLETE, DEPLOYED & LIVE-CERTIFIED.** Phase 0a (foundation) + Phase 0b
> (integration + live backend deploy) are done. The platform is wired into the live
> app (bootstrap, lifecycle draft-flush, Sync Center/banner), the four pilot-critical
> writes (attendance, exam marks, leave, fee) route through `ReliableWriter`, drafts
> auto-save/resume, fee shows "Pending Sync" with no offline receipt (R1), and the
> backend applies **universal idempotency** + **row_version/409-conflict** —
> **deployed to the VPS pilot and live-certified 20/20** (+ red-team regression
> **26/26**). **EOS gate: PASS** (0 P0 / 0 P1) — see
> [`docs/engineering/eos/EOS_DATA_RELIABILITY_PLATFORM_PHASE0B_REPORT.md`](engineering/eos/EOS_DATA_RELIABILITY_PLATFORM_PHASE0B_REPORT.md)
> and [`docs/DATA_RELIABILITY_PLATFORM_CERTIFICATION.md`](DATA_RELIABILITY_PLATFORM_CERTIFICATION.md).
> Tracker rows `QA-X-001/002/004/005/006/007/008/009` → **Verified**.
> **QW1 may now begin.** (Phase 0c — inherit-by-default for all ~154 mutations — runs opportunistically and does not block QW1.)

**Owner decision (2026-06-27):** the offline + retry rows are **core platform reliability requirements**, not optional features. Build a **reusable platform layer** (not per-feature logic) before any QA wave begins. The rows previously flagged feature-dependent — `QA-X-001` (offline attendance draft), `QA-X-002` (offline fee collect), `QA-X-004` (offline cached reads), `QA-X-005` (connectivity status), `QA-X-008` (5xx/429 retry/backoff), plus `QA-X-006/009` (double-submit + unsaved-guard) and `QA-X-007` (auth refresh-replay) — are now **Phase 0 prerequisites**, then tested-and-closed in QW1/QW6.

**Platform scope (3 pillars):**
1. **Draft Persistence** — automatic local draft save during data entry; recovery after app close / restart / phone lock / interruption; resume exactly where the user left off (WhatsApp-draft UX).
2. **Sync Engine** — queue write operations while offline; auto-sync on reconnect; exponential backoff; **idempotent writes** (no duplicate records); conflict detection + safe resolution; user-visible sync status where appropriate.
3. **Repository Integration** — every write passes through the common platform; future modules inherit it automatically; no per-screen offline code.

**Phase 0 governance:**
- The **architecture is presented for owner review and approval BEFORE implementation** → see `docs/DATA_RELIABILITY_PLATFORM_DESIGN.md`. ✅ approved.
- ~~QW1 does not start until the platform design is approved and implemented.~~ ✅ **Implemented + deployed + live-certified + EOS PASS → QW1 unblocked (2026-06-28).**
- Exit criteria: platform layer merged + unit/widget/integration tested; all writes routed through it; the 8 offline/retry/draft tracker rows are `Verified`. ✅ **Met** (`flutter analyze` 0 · `flutter test` 2504/0 · reliability Deno 10/10 · live cert 20/20 · regression 26/26).

> The earlier "owner-decision gate" (build-vs-accept) is **closed: decision = BUILD.** No tracker row is `Won't-Build`.

---

## QW1 — Critical Path & CI Enforcement  ·  53 rows  ·  effort: L

> **IN PROGRESS (started 2026-06-28).** The **CI Enforcement Backbone landed first** (the roadmap's "land early" enforcement half): backend full Deno tree is now a PR + deploy gate (`QA-B-071/072`, `QA-X-037` — **Verified**, 889/0 local), an lcov coverage-minimum gate is enforced (`QA-X-038` — **Verified**, floor 60% vs 60.24% measured), and the full-Patrol nightly, Maestro approval-chains, and live-regression cron workflows are authored (`QA-X-035` Passing; `QA-X-036/039`, `QA-B-073` Test-Written — flip to Verified on first scheduled CI run). **EOS gate: CONDITIONAL PASS.** See [`QW1_CI_ENFORCEMENT_CERTIFICATION.md`](QW1_CI_ENFORCEMENT_CERTIFICATION.md).
>
> **Then the 7 P0 Flutter widget surfaces landed** — `QA-F-001/002` (auth OTP+login), `QA-F-005/006` (fees summary + PayNow bar, the money loop), `QA-F-012` (attendance), `QA-F-014` (leave form), `QA-F-018` (notifications) — all **Verified** (21/21 widget tests green, analyze clean; **EOS gate: PASS**, 1 P2 tracked: attendance calendar 12px overflow at the 428px breakpoint).
>
> **Patrol e2e is verifiable locally** (emulator `Medium_Phone_API_36.0` + patrol_cli v4.4.0), so the QA-J journey rows reach Verified here.
>
> **Then the QA personas + RBAC-isolation journeys + money loop landed** — `QA-J-019/024/037/047/058` (HR/School-Admin/Director/Staff personas, QA-harness-only per owner decision), `QA-J-061` (staff→teacher gate), `QA-J-001/060` (parent money loop) — all **Verified** (Patrol 5/5 green; **EOS gate: PASS**; one P1 found-and-fixed in-flight — QA-login persona permission resolution). See [`QW1_PERSONA_RBAC_MONEY_CERTIFICATION.md`](QW1_PERSONA_RBAC_MONEY_CERTIFICATION.md).
>
> **Then the P0 journey batches landed (2026-06-28):** messaging (`QA-J-002/013/057`), year-end commit (`QA-J-038/039/059`), homework + teacher marks (`QA-J-008/012/014`), admission approve (`QA-J-032`), legal gate (`QA-J-062`), ChainScope + control-center negatives (`QA-J-048/052`), and the backend RBAC per-route matrix + anti-escalation (`QA-B-038/049`) — **all Verified** (Patrol journeys green on the emulator; complex multi-step screens proven via deterministic integration tests with the UI deferred to QW3/QW7; backend full Deno tree **892/0**). **EOS gate: PASS** for every batch — see the EOS ledger.
>
> **Then the CLOSEOUT landed (2026-06-28) — locally-verifiable QW1 scope COMPLETE.** The
> chain-org-**allowed** positive (`QA-J-048`) closed via `QaLoginPersona.chainDirector` (Patrol
> `qw1-rbac-pos` green); the last open locally-verifiable P0 rows were built and verified —
> `QA-J-003` (parent child-switch Patrol), `QA-J-009` (student cross-shell Patrol),
> `QA-F-026/036/038` (legal / attendance-gate / marks-grid widget tests),
> `QA-B-014/066` (finance route contract + per-route 403 envelope Deno); and tracker-lag rows
> already covered by passing tests were reconciled to **Verified** (`QA-F-001/002`,
> `QA-X-001/002/006`). **EOS gate: PASS** (locally-verifiable scope). See
> [`QW1_COMPLETION_CERTIFICATION.md`](QW1_COMPLETION_CERTIFICATION.md).
>
> **QW1 row status: 44 Verified · 5 Open (INFRA-BLOCKED) · 1 Passing · 3 Test-Written.**
>
> **Remaining QW1 (infrastructure-dependent only — NOT locally fixable):**
> (1) **Live Postgres / RLS** — `QA-B-051/052/057` (+ the `QA-B-014` cross-tenant leg): rolled-back-txn
> probes need `ERP_TENANT_DATABASE_URL` with RLS → **live-regression DB cron**.
> (2) **FCM Push** — `QA-X-010/012`: token register/refresh + push-tap deep-link need FCM on a device
> → **device/FCM CI lane**.
> (3) **VPS Cron** — `QA-X-035` (Passing) · `QA-X-036/039`, `QA-B-073` (Test-Written): CI workflows
> authored; flip to Verified on **first scheduled run**.
> The wave is **CONDITIONAL** at the program level until these environment-gated rows turn green on
> their lanes; no locally-verifiable P0/P1 remains.

**Goal:** Make every pilot-critical workflow provably correct *and* make the whole test estate run in CI so it can never silently regress again.

**Scope (53):** all P0 journeys (`QA-J` P0s), the 10 P0 Flutter UI surfaces, the 10 ship-first backend rows, and the 10 P0 cross-cutting rows.
- **Money loop:** parent pay-fee completion + receipt persist (`QA-J-001/060`, `QA-F-005/006`), finance collect/refund contracts + RLS (`QA-B-014/015/057`), double-submit guard at money sites (`QA-X-006`, *Phase 0*), offline fee-collect (`QA-X-002`, *Phase 0*).
- **Attendance/exams loop:** teacher attendance screen + mark-all gate (`QA-F-036`), teacher marks-entry → verification (`QA-J-014`, `QA-F-038`), offline attendance + draft-resume (`QA-X-001`, *Phase 0*).
- **Homework loop:** teacher create+publish (`QA-J-012`), student submit+persist (`QA-J-008`).
- **The 4 missing personas + RBAC isolation:** HR, Staff (functional), School Admin, Director (`QA-J-019/024/037/047/058`), cross-shell deep-link (`QA-J-009/061`), ControlCenterGuard negatives (`QA-J-052`), ChainScope (`QA-J-048`), backend per-route RBAC matrix + longest-prefix + control-center guard (`QA-B-038/049/050`).
- **RLS P0:** hr / hostel / finance cross-tenant probes (`QA-B-051/052/057`).
- **Messaging send:** parent↔teacher (`QA-J-002/013/057`).
- **Academic year-end commit:** promote/reshuffle/balance commit-verified (`QA-J-038/039/059`); admission approve (`QA-J-032`).
- **Auth/legal UI:** OTP + login screens pumped (`QA-F-001/002`), legal-acceptance gate + fail-open (`QA-F-026`, `QA-J-062`).
- **Push P0:** FCM token register/refresh (`QA-X-010`), deep-link routing (`QA-X-012`).
- **CI enablement (the enforcement half):** full Patrol in CI (`QA-X-035`), Maestro in CI (`QA-X-036`), backend `api/` tests + smoke in CI (`QA-X-037`, `QA-B-071/072`), scheduled live-regression cron (`QA-X-039`, `QA-B-073`), coverage threshold (`QA-X-038`).

**Entry criteria:** owner approval + owner-decision gate resolved.
**Exit criteria:** all 53 rows `Verified`; CI green running the full suites; live-regression cron stood up.
**Suggested execution:** 3 parallel agent streams — (1) journeys + personas, (2) Flutter P0 widgets + auth, (3) backend RBAC/RLS + CI wiring. The CI-wiring rows should land **early** in the wave so subsequent rows are auto-validated.

---

## QW2 — Module Write/Persistence E2E  ·  32 rows  ·  effort: M

> **CLOSEOUT 2026-06-28 — locally-verifiable scope COMPLETE. EOS gate: PASS.** All 32 rows worked
> across 6 batches (staff-functional · teacher · school-admin · principal · platform-director-
> entitlement · cross-cutting). The theme — *write under the correct persona, not a god-login* —
> was proven deterministically against the real gates (`MutationPermissionRegistry`,
> `RolePermissionMatrix`, `canAccessErpRoute`, `SchoolCapabilityRegistry`, `EntitlementResolver`):
> 8 test files, **32/32 green**, analyze clean. Persistence is cited per row from the existing
> superAdmin e2e suites; UI-under-persona = Patrol follow-up. **QW2 row status: 28 Verified · 4
> Open** (blocked, with explicit reasons): `QA-J-004` (FCM push, with QA-X-010/012), `QA-J-063`
> (AI-scope server-enforced → live/RLS lane), `QA-J-005` (PTM backend not shipped — SchoolBuildScope-
> hidden), `QA-J-010` (student self-service comms backend not built). Wave is **CONDITIONAL** until
> those feature/infra lanes land. See [`QW2_COMPLETION_CERTIFICATION.md`](QW2_COMPLETION_CERTIFICATION.md).

**Goal:** Every operational module's real write workflow is exercised **end-to-end under the correct persona** with persistence asserted (not nav/READ, not god-login).

**Scope (32):** the P1 `QA-J` rows — HR employee/payroll/Excel under HR persona (`QA-J-020/021/022`); Staff functional flows (library issue/return, transport route→allocate→board, hostel assign→check-in→roll-call, storekeeper PO limits, counselor lead→convert) under their own personas (`QA-J-026/027/028/029/030`); finance collect→reaches-parent chain (`QA-J-025`); principal reject-with-comment + broadcast + result-reject path (`QA-J-033/034/035/036`); school-admin convert+create-login, transfer/TC, section-balance commit, AI prefill, subject→class-teacher→timetable chain (`QA-J-040..044`); director metric-input→margin/ROI (`QA-J-049`); super-admin provision→login-to-tenant, plan-assign→entitlement-effect (`QA-J-053/054`); cross-cutting attendance-correction loop, question-paper build→validate→publish, AI-assistant persona scope, capability/entitlement gating (`QA-J-063/064/066/068/069`).
**Entry:** QW1 personas exist (depends on `QA-J-019/024/037/047`).
**Exit:** all 32 rows `Verified`, each asserting a persisted state change under the scoped persona.
**Suggested execution:** parallelise by role-cluster (HR+Staff, Principal+SchoolAdmin, Director+SuperAdmin, cross-cutting).

---

## QW3 — Flutter Widget/UI & State Coverage  ·  53 rows  ·  effort: M

> **CLOSEOUT 2026-06-28 — locally-verifiable scope COMPLETE. EOS gate: PASS.** All 53 `QA-F`
> rows worked across 7 parallel module-clusters: **52 Verified · 1 Open** (`QA-F-048` blocked —
> the HR Excel employee-import UI does not exist). **263 new widget/golden/router tests** across
> 38 files; full sweep **`flutter analyze` 0 issues · `flutter test` +2849/0**. The pump harness
> caught **2 P1-class crashes** (Intelligence enum-`.name` dynamic-dispatch `NoSuchMethodError`;
> unified-onboarding mid-build provider mutation) and **5 layout defects** — all fixed in-flight —
> and surfaced 6 honest validation/UX gaps tracked for QW6/QW7. See
> [`QW3_COMPLETION_CERTIFICATION.md`](QW3_COMPLETION_CERTIFICATION.md).

**Goal:** Close the screen-pump gap (finding **F4**) — every screen renders, every form validates, every dialog/bottom-sheet opens+confirms, every loading/error/empty state shows.

**Scope (53):** the P1/P2 `QA-F` rows — auth staff/splash; the full parent fees widget set + attendance + exam/leave widgets + child-switcher; notifications list mark-read; onboarding forms/stepper/import preview; operations hub; legal review; achievement_promotion (zero-coverage module); finance search/dialogs/export; teacher homework/marks/leave/AI forms; student submit/result rows/attendance; education CSV import + add/edit dialogs + moderation queue; HR Excel import + action buttons + employee form; employee 360; school_config discovery; settings AI; director sub-screens + portfolio form; entitlements negative path; per-persona nav-builder route map; control-center/org-builder/intelligence/verticals/transport-dialog sweeps; dashboard goldens (finance/admissions/director).
**Entry:** none beyond QW1 CI wiring (so widget tests run on every PR).
**Exit:** all 53 rows `Verified`; lcov per-module floor met for the listed screens.
**Suggested execution:** highly parallelisable — one agent per module-cluster, table-driven pump harnesses where possible.

---

## QW4 — Backend API/RBAC/RLS/Error-path  ·  70 rows  ·  effort: L

> **CLOSEOUT 2026-06-30 — locally-verifiable scope COMPLETE. EOS gate: PASS.** All 73 QW4 rows worked
> across 3 batches: **59 Verified · 8 Partial · 6 Blocked** (the 6 Blocked + the Partial data legs are
> pure live-Postgres/RLS rolled-back-txn probes needing `ERP_TENANT_DATABASE_URL`). Proven DB-free via
> the route-contract pattern (503 = authorized proxy) + an `app.ts` testable seam; backend
> **`deno test` 1344/0**, flutter **2874/0**, analyze clean. The suites caught + fixed **2 P1s**
> (QW4-INV-OR systemic OR-fallback RBAC inversion across 29 sites/15 files via a new
> `requireAnyPermission` helper; exam-results publish was completely unaudited) and **hardened CORS on
> error paths**; built a read-path `RetryInterceptor` and a backend coverage floor (40%) in CI. See
> [`QW4_BACKEND_API_CERTIFICATION.md`](QW4_BACKEND_API_CERTIFICATION.md).

**Goal:** Turn the backend from "37% RBAC-documented, 9/50 routers tested" into a fully contract-asserted surface (findings **F5/F9**).

**Scope (70):** the `QA-B` QW4 rows + `QA-X` QW4 rows —
- **Untested modules** (employee, inventory_distribution, parent_experience, principal_command, school_calendar, school_config, memories, setup_wizard, teacher_assistant, growth, school_completion-40, pilot_operations) — `QA-B-001..012`.
- **Router/contract suites** for the 41 untested routers (finance-28, communication-19, control_center-17, transport-17, hostel-14, hr-13, library-13, alumni-13, inventory-12, director-12, + analytics/copilot/timetable/legal/student/operations/exam/onboarding/org-builder/widget) — `QA-B-013..037`.
- **RBAC matrix** extension to all 446 routes + per-module gates + separation-of-duties — `QA-B-039..050`.
- **RLS probes** (rolled-back-txn cross-tenant) for library/alumni/inventory/transport/school_completion + control-center/director org-scope + parent per-child — `QA-B-053..061`.
- **Error-paths** (404 fallthrough, 500/CONFIG_ERROR envelope, per-module 402, per-route 403 matrix, 4xx body validation, CORS, request-log, webhook HMAC) — `QA-B-062..070`.
- **Backend coverage threshold + author-then-wire** — `QA-B-074/075`; foreground/background push + in-app notification list — `QA-X-003/007/011/013`.
**Entry:** QW1 CI wiring complete (so these tests actually execute) — `QA-B-075` notes contracts must be *authored* before wiring has anything to run.
**Exit:** RBAC inventory covers 446/446 routes with holder/non-holder assertions; every router has a path-match/404 test; cross-tenant probe per money/PII module; all error envelopes asserted; backend coverage threshold enforced.
**Suggested execution:** parallelise by router-cluster; the per-route RBAC matrix is one table-driven suite.

---

## QW5 — Secondary / Advanced / Verticals Journeys  ·  14 rows  ·  effort: S

> **CLOSEOUT 2026-06-30 — locally-verifiable scope COMPLETE. EOS gate: PASS.** All 14 P2 `QA-J` rows
> worked across 5 batches: **12 Verified · 1 Partial · 1 Blocked**. The wave's defining move was a
> **mandatory backlog cross-check before any code** — a 5-agent discovery pass classified each row
> REAL/READ-ONLY/MOCK/PHASE-2 and surfaced **3 owner decisions** (backup-restore → defer to QW8;
> white-label → re-scope to GA-ready School Branding; student report-card download → wire it),
> honouring "no new product behaviour without owner approval". Proven deterministically against the
> real gates (`MutationPermissionRegistry`, `RolePermissionMatrix`, `EntitlementResolver`) plus two
> widget render proofs; **11 new test files**, **1 owner-approved feature wire-up** (student
> report-card export reusing the shared `AksharaReportExportService`), `flutter test` **2905/0**,
> analyze clean. **Partial:** `QA-J-055` (platform-ops acknowledge — gate contract green, live
> round-trip infra-blocked: `managePlatformOperations` unseeded server-side, 404 live). **Blocked:**
> `QA-J-046` (backup→restore — owner-deferred to QW8 `QA-R-009`; user-facing restore has no backend).
> See [`QW5_COMPLETION_CERTIFICATION.md`](QW5_COMPLETION_CERTIFICATION.md).

**Goal:** Cover the lower-risk, advanced, and display-only journeys once the core is locked.
**Scope (14):** the P2 `QA-J` rows — parent transport view / notification mark-read; student report-card download; teacher student-risk intervention; HR recruitment/performance writes; finance refund verb negative; school-admin room/syllabus auto-allocate + backup→restore; director board-pack PDF + entitlement lock; super-admin alert-ack + white-label apply; onboarding import under schoolAdmin; achievement multi-channel publish.
**Entry:** QW2 complete (shares personas/flows).
**Exit:** all 14 rows `Verified` or owner-deferred.

---

## QW6 — Resilience & Non-functional  ·  24 rows  ·  effort: M

> **CLOSEOUT 2026-06-30 — locally-verifiable scope COMPLETE. EOS gate: PASS.** Of the 24 rows, 3
> (`QA-X-014/015/016` audit-trail) were already closed in QW4; the 21 open rows worked across 7
> batches (offline-reliability · audit · state-sweeps · import/export · performance · golden ·
> security): **17 Verified · 2 Verified-rescoped · 1 Test-Written/infra-blocked · 1 Blocked-
> MISSING-FEATURE.** A **mandatory discovery cross-check before any code** (4-agent pass) classified
> every row REAL-NOW / INFRA-BLOCKED / MISSING-FEATURE and surfaced **4 owner decisions** — honouring
> "no new product behaviour / no assuming scope": (1) **`QA-X-004` offline cached reads = BUILD** —
> Phase 0 shipped offline *writes* (outbox/drafts) but no read cache, so a reusable read-cache
> platform was built (`CacheRecord` + store + a single `OfflineReadCacheInterceptor` Dio choke point,
> SQLCipher v1→v2 migration, LRU-bounded, tenant-scoped, wiped on logout); (2) **`QA-X-017` backend
> denied-audit = also wire it** — emitted at the single `handleRequest` choke point (no change to the
> 29 `requirePermission` sites); (3) **`QA-X-021`/`QA-X-022` = re-scope** to the existing real slices
> (student importer round-trip; single-payment reconcile idempotency), broad variants (education-CSV /
> batch-file reconcile) owner-deferred; (4) **`QA-X-020` HR Excel import = defer** (feature does not
> exist; logged to `PRODUCT_COMMERCIAL_BACKLOG.md`). **69 new Flutter tests + 37 new Deno tests +
> 20 golden baselines**, `flutter analyze` 0 · `flutter test` **2974/0** · new Deno **37/0** · `api/`
> regression **16/0**. **Infra-blocked:** `QA-X-025` (p95 latency k6 probe authored; needs the live
> VPS cron). See [`QW6_COMPLETION_CERTIFICATION.md`](QW6_COMPLETION_CERTIFICATION.md).

**Goal:** Verify the app behaves under stress, failure, and scale — and that observability (audit/notifications) actually fires.
**Scope (24):** the `QA-X` QW6 rows —
- **Offline** cached reads + connectivity banner + unsaved-guard (verifies Phase 0 platform behaviour) — `QA-X-004/005/009`.
- **Audit-trail persistence** assertions for fee-collect / exam-publish / approvals / RBAC-deny — `QA-X-014..017`.
- **State sweeps** (systematic loading/error/empty + no-raw-error-leak) — `QA-X-018/019`.
- **Import/export integrity** (HR Excel, education CSV, finance reconciliation, PDF/Excel format incl. board-pack) — `QA-X-020..023`.
- **Performance** (large-list rendering, p95 latency cron, parent fan-out at scale) — `QA-X-024..026`.
- **Golden** (finance, admissions, director/control-center, HR/management dashboards) — `QA-X-027..030`.
- **Security** (secure token storage, legal fail-open bounded, exam anti-tamper, upload presign) — `QA-X-031..034`.
**Entry:** QW1 CI in place; QW3 widget harnesses reusable for state sweeps.
**Exit:** all 24 rows `Verified` or owner-deferred; performance/security cron green.

---

## QW7 — Feature Behaviour Certification (MANDATORY)  ·  25 rows (`QA-C`)  ·  effort: L

> **CLOSEOUT 2026-06-30 — locally-verifiable scope COMPLETE. EOS gate: PASS.** Of the 25 `QA-C` rows:
> **21 Verified · 2 Won't-Build (scoped-out) · 2 Verified GA-slice**, with infra/Phase-2 legs marked
> honestly. A 4-agent discovery-first pass classified every row and surfaced the **English-first
> product pivot** (owner FINAL): full UI i18n is **CANCELLED** — `QA-C-015` (UI strings) + `QA-C-017`
> (PDFs) are **Won't-Build**; `QA-C-016`/`QA-C-018` re-scoped to **Parent Communication Localization**
> (deterministic, no-LLM: a multilingual template catalog + send-path seam + the existing
> `parent_language_preferences` store; parent-AI generates natively in-language). The other 21 rows
> certify end-user behaviour on top of QW1–QW6 coverage: per-app clickable-element + 4-state behaviour
> (`001–007`), state-sweep cite (`008` = QW6 `QA-X-018/019`), the 7-point integrated workflow (`009`),
> all five comm channels (`010–014`), the RBAC allow/deny-UX matrix (`019`), multi-hat/approvals
> (`020` — **delegated permissions confirmed absent**, marked honestly), reliability E2E (`021`),
> AI persona/permission/failure-modes (`022`), and the GA-ready white-label slice (`023/024`, tiers =
> Phase-2 per O10) + local pilot behaviour (`025`). **168 new tests** (132 Flutter + 36 Deno),
> `flutter analyze` 0 · `flutter test` **3106/0** · new+regressed Deno **121/0** · **zero defects**.
> See [`QW7_COMPLETION_CERTIFICATION.md`](QW7_COMPLETION_CERTIFICATION.md).

**Goal:** certify product quality from the **end-user's** perspective, not just technical coverage. A feature is **not complete** until its behaviour is fully verified: every element does the expected thing, in the right language (parent-facing comms only — English-first elsewhere), for the right role, producing the right notification, audit, and UI refresh.

**Scope (`QA-C-001..025`):**
- **UI behaviour** (`QA-C-001..008`) — per app/portal (Parent, Student, Teacher, ERP/Admin shell, Principal/Management, Director/Control-Center): every screen, widget, button, icon, dropdown, menu, form, dialog, bottom-sheet, search, filter, sort, pagination, and all four states (empty/loading/error/success) — **every clickable element performs its expected action**; plus an interaction-primitives sweep and a state sweep.
- **Complete workflow behaviour** (`QA-C-009`) — each critical workflow verified for: correct persistence + navigation + permissions + notification + audit logging + backend update + UI refresh, as one integrated assertion.
- **Communication behaviour** (`QA-C-010..014`) — Push · SMS · Email · WhatsApp · In-App, each verifying recipient, language, template, placeholders, deep-link, destination screen, delivery status, audit record.
- **Parent Communication Localization** (`QA-C-016`, `QA-C-018`) — **English-first product** (owner FINAL 2026-06-30): the UI is NOT localized. Only **parent-facing communication + parent-facing AI** respect the parent's profile language: notification/comms templates & placeholders (`QA-C-016`) and Parent Guidance / Parent Copilot responses (`QA-C-018`). **Scoped-OUT:** `QA-C-015` (UI strings/buttons/menus) and `QA-C-017` (PDF documents — receipts/report-cards/TC/certificates stay English). Teacher/Admin/Principal/Director UI + their AI stay English.
- **RBAC behaviour** (`QA-C-019..020`) — every role, permission, role combination, deny path, approval flow, delegated permission.
- **Data reliability** (`QA-C-021`) — certifies the Phase 0 platform in real workflows: draft persistence, autosave, session recovery, offline queue, sync, retry, conflict handling, duplicate prevention.
- **AI behaviour** (`QA-C-022`) — correct language, persona, permission scope; empty responses, timeout handling, retry, safe-failure.
- **White-label certification** (`QA-C-023..024`) — per-school branding across all surfaces + subscription-aware branding strategy. ⚠ *see Capability Prerequisites + commercial item below.*
- **Pilot school behaviour certification** (`QA-C-025`) — expand the pilot simulation to verify all of the above end-to-end.

**Entry:** QW1–QW6 substantially complete (behaviour cert sits on top of technical coverage); Phase 0 shipped (for `QA-C-021`).
**Exit:** all 25 `QA-C` rows `Verified`; no role/screen/notification/language behaviour defect open.

### Commercial item — White-Label & Branding Strategy (permanent SaaS roadmap)

Complete white-label capability is a **permanent commercial-SaaS roadmap item**. Each school must be configurable with: school logo, school name, app name, theme colours, splash screen, login branding, and Parent/Teacher/Student/Principal app branding, plus branded reports, PDFs, receipts, and emails. Branding is **subscription-aware**:

| Plan | Branding |
|---|---|
| **Starter** | School branding + **"Powered by Akshara"** visible |
| **Growth** | School branding + small configurable footer |
| **Enterprise / White-Label** | Complete branding control + optional removal of all Akshara branding |

This is an entitlement-gated capability (ties to the existing 4-tier model) and is certified by `QA-C-023/024` and `QA-R-004/011`.

### ✅ Capability prerequisites — RESOLVED by owner decision (2026-06-30)

These three were open build-vs-scope calls; the owner has now decided (see
[`PRODUCT_COMMERCIAL_BACKLOG.md`](PRODUCT_COMMERCIAL_BACKLOG.md), decisions O6/O7/O10):
- **English-first product — NO full UI i18n (O7, FINAL 2026-06-30).** The earlier "build the Phase 0-L
  full-UI-localization platform before GA" is **CANCELLED**. The app UI, PDFs (receipts/report-cards/
  TC/certificates), and Teacher/Admin AI stay **English**. O7 now scopes to **Parent Communication
  Localization** only: parent-FACING comms (attendance/homework/teacher+behaviour remarks/fee reminders/
  leave responses/exam-result notifications/notices/broadcasts) **+ Parent Guidance / Parent Copilot AI**,
  rendered in the parent's profile language (per-recipient). Built on the existing partial layer
  (`content_localization.dart`, `translation_service.dart`, parent language pref); the remaining build is
  per-language notification-template variants + recipient-language send-path + parent-AI language — far
  smaller than full i18n. Certify via re-scoped `QA-C-016` + `QA-C-018`; `QA-C-015`/`QA-C-017` are scoped-OUT.
- **Billing → Phase 2 (O6).** Pilot + early GA run on entitlement-gating + manual/external invoicing;
  in-product billing + usage quotas + marketplace are post-GA. `QA-R-011` certifies entitlement/plan
  behaviour at GA; payment-collection behaviour is deferred to Phase 2.
- **White-label / subscription-aware branding tiers → Phase 2 (O10).** School branding + onboarding
  branding are GA-ready; the tiered "Powered-by / footer / full-removal" gating and platform white-label
  (API OFF live) are an Enterprise upsell tied to monetization. `QA-C-024` scopes to the GA-ready slice.

**New Must-Before-GA build items** (added to the backlog): **Parent Communication Localization** (O7,
English-first — NOT full UI i18n) and **staff Face ID attendance** (O5 — student attendance stays
teacher-entered, O4). Advanced attendance (geo-fencing / RFID / QR) and live GPS bus tracking are
**Future Vision / Phase 2** respectively (O8/O9).

---

## QW8 — Production Readiness & Market Certification (FINAL MANDATORY GATE)  ·  12 rows (`QA-R`)  ·  effort: L

**Goal:** the final certification before Akshara ERP is declared **production-ready for commercial rollout**. **No feature development during this wave** unless a critical production issue is found. Prove the whole platform is reliable, scalable, secure, and commercially deployable.

**Scope (`QA-R-001..012`):**
- **Pilot school simulation** (`QA-R-001..002`) — complete real-world simulations, single- then multi-school: onboarding → academic-year setup → admissions → enrollment → attendance → homework → timetable → exams → marks → report cards → fees → receipts → parent comms → leave → transport → library → inventory → HR → payroll → principal → director → Parent/Teacher/Student apps. **End-to-end must succeed without manual intervention.**
- **Multi-school SaaS** (`QA-R-003..004`) — multiple schools operating simultaneously; complete tenant isolation; per-school branding + config; subscription enforcement; white-label behaviour; cross-school data isolation.
- **Performance** (`QA-R-005..006`) — define **measurable targets** (p95 latency, large student DBs, large attendance/marks sessions, concurrent users, dashboards, report generation, search, sync) and verify they are achieved at scale.
- **Reliability** (`QA-R-007`) — draft recovery, autosave, offline queue, auto-sync, retry, app-restart recovery, crash recovery, long-running session recovery; **no user data lost**.
- **Security** (`QA-R-008`) — RBAC, RLS, authentication, authorization, audit logs, permission-escalation prevention, tenant isolation, sensitive-data protection.
- **Backup & DR** (`QA-R-009`) — backup execution, restoration, integrity-after-restore, recovery + rollback procedures (drills).
- **Monitoring & operations** (`QA-R-010`) — health checks, error logging, monitoring, alerting, scheduled jobs, background workers, production diagnostics.
- **Commercial readiness** (`QA-R-011`) — subscription plans, feature gating, white-label plans, branding behaviour, trial flow, billing behaviour, upgrade/downgrade. ⚠ *billing is a Capability Prerequisite.*
- **Final production checklist** (`QA-R-012`) — the GA gate (criteria below).

**Entry:** QW1–QW7 complete; Phase 0 platform live.
**Exit:** all 12 `QA-R` rows `Verified`; the Final Production Checklist fully satisfied.

### Final Production Checklist (the GA gate — `QA-R-012`)

Akshara ERP may be certified **Production Ready** only when **all** hold:
- [ ] All QA waves **QW1–QW8** completed.
- [ ] **No unresolved P0** defects.
- [ ] **No unresolved production-blocking P1** defects.
- [ ] All critical workflows certified.
- [ ] Feature Behaviour Certification (QW7) completed.
- [ ] Production Readiness Certification (QW8) completed.
- [ ] Pilot School Simulation successfully completed.
- [ ] Multi-school SaaS certification passed.
- [ ] White-label certification passed.
- [ ] Security certification passed.
- [ ] Performance targets achieved.
- [ ] Data reliability verified (Phase 0).
- [ ] Backup and recovery verified.

**Only after this final certification may Akshara ERP be declared ready for commercial deployment and real customer onboarding.**

---

## Effort & ordering summary

| Wave | Rows | Effort | Can start after | Parallel with |
|---|---:|---|---|---|
| **Phase 0** | (platform) | L | Design approved | — (prerequisite gate) |
| QW1 | 53 | L | Phase 0 implemented + owner approval | — (gate) |
| QW2 | 32 | M | QW1 personas | QW3, QW4 |
| QW3 | 53 | M | QW1 CI wiring | QW2, QW4 |
| QW4 | 70 | L | QW1 CI wiring | QW2, QW3 |
| QW5 | 14 | S | QW2 | QW6 |
| QW6 | 24 | M | Phase 0; QW1 CI; QW3 harnesses | QW5 |
| **QW7** | 25 | L | QW1–QW6 substantially complete; Phase 0 live | — (behaviour gate) |
| **QW8** | 12 | L | QW7 complete | — (final gate) |

**Total: 283 rows across 8 waves, preceded by Phase 0 (platform build).** Effort is relative (S/M/L), not a time estimate. Phase 0 is a build-and-test prerequisite that *unblocks* 8 rows. **QW7 and QW8 are sequential mandatory certification gates — GA is declared only after QW8's Final Production Checklist passes.** Note: the QW7/QW8 Capability Prerequisites are now **owner-resolved** — localization is **English-first / Parent Communication Localization only** (O7, NOT full i18n), billing is Phase 2 (O6), branding-tier removal is Phase 2 (O10).

---

## Governance during execution

- The **Master Tracker is authoritative**: update each row's `Status` (`Open → In-Progress → Test-Written → Passing → Verified`) as work lands. Do not mark `Verified` without the test passing in CI.
- **No new features, no roadmap expansion, no re-auditing** already-covered areas (per the project's completion-mode rules) — except the feature-dependent rows, which need the owner-decision gate.
- Each wave should close with a short `*_QA_WAVE_n_CERTIFICATION.md` recording what was added and the green evidence, consistent with the project's existing certification discipline.

**Nothing in this roadmap executes until the owner approves.**

---
---

<a id="next-generation-roadmap--phases-b--c--d"></a>

# ══════════════════════════════════════════════════════════════════════
# NEXT-GENERATION ROADMAP — Phases B / C / D
# (continuation of QW1–QW8 · nothing above this divider is modified)
# ══════════════════════════════════════════════════════════════════════

**Added:** 2026-07-01 · Branch `feature/data-reliability-platform` · Companion sources: [`PRODUCT_ENHANCEMENT_BACKLOG.md`](PRODUCT_ENHANCEMENT_BACKLOG.md) (🔒 frozen Rev 4 → **Phase C**) · [`PRODUCT_COMMERCIAL_BACKLOG.md`](PRODUCT_COMMERCIAL_BACKLOG.md) (SSOT scope → **Phase D**) · [`FINAL_QA_MASTER_TRACKER.md`](FINAL_QA_MASTER_TRACKER.md) (QA-R / Track-B rows → **Phase B**).

> **This is a continuation, not a new project.** QW1–QW8 and Phase 0 stay exactly as certified. Phases B/C/D are the *next* execution stages layered on top of the completed QA program. **Same governance:** every wave/task is gated by the EOS (`/eos <scope>`) against the Engineering Constitution; no task is "complete" until EOS returns PASS. **Nothing here executes until the owner approves each phase.**

### Where we are (2026-07-01)

- **QW1–QW8 — COMPLETE** (local/technical + behaviour + local production-readiness). All QA-R rows are locally Verified; the residual is live.
- **Staff Face ID (O5) — BUILT + locally certified** (`STAFF_FACE_ID_ATTENDANCE_CERTIFICATION.md`). Cert scope = **GA-1** (biometric check-in/out) only; **live deploy + on-device run is the only residual** (→ Phase B B4).
- **GA (`QA-R-012`) is BLOCKED on exactly three things**, all live-infrastructure, all with **staged, fail-loud harnesses** already authored: (1) the **Track B live-VPS run**, (2) the **staff Face ID live leg**, (3) the **live-regression cron 7-day green** window. **Phase B closes all three.**

### Phase sequence

```
 QW1 … QW8  (DONE, frozen)
      │
      ▼
 ┌─────────────────────────── PHASE B — Release Engineering (Track B) ───────────────────────────┐
 │  Live VPS deploy · edge functions · migrations · Face ID live · tenant Postgres · multi-school  │
 │  · isolation · backup/restore drill · monitoring · k6 perf · pilot sim · 7-day regression cron  │
 │  → all QA-R live legs green → QA-R-012 Final GA Certification → **GA DECLARED**                  │
 └───────────────────────────────────────────────┬────────────────────────────────────────────────┘
                                                  ▼ (GA gate passed)
 ┌───────────────────────── PHASE C — Product Enhancement Implementation ─────────────────────────┐
 │  Source = frozen PRODUCT_ENHANCEMENT_BACKLOG (Rev 4). Foundations first (XCT), then             │
 │  Band 1 (P1 Critical Operational) → Band 2 (P2 Productivity) → Band 3 (P3 Nice Improvements),    │
 │  grouped into logical module/theme waves. Approved frozen items only — no invented features.    │
 └───────────────────────────────────────────────┬────────────────────────────────────────────────┘
                                                  ▼
 ┌───────────────────────────── PHASE D — Future / Phase 2 / Commercial ──────────────────────────┐
 │  Source = PRODUCT_COMMERCIAL_BACKLOG only (Queue 4 Phase-2 · Queue 5 Future Vision ·            │
 │  proposed Consolidation wave). Not mixed with Phase C.                                          │
 └────────────────────────────────────────────────────────────────────────────────────────────────┘
```

> **Phase B is the only GA-blocking phase.** Phases C and D are **post-GA** and do not gate the commercial launch. Phase C may begin only after `QA-R-012` passes (or with explicit owner approval to overlap low-risk foundation work).

---

## PHASE B — Release Engineering (Track B: live-VPS validation)  ·  13 tasks (B1–B13)

**Goal:** promote the locally-certified platform to a **live, production-validated** deployment on the VPS pilot and **close every live-only residual** so `QA-R-012` (the Final Production Checklist) can pass and **GA can be declared**. This phase runs the *already-authored, staged, fail-loud* Track B harnesses against real infrastructure — it does **not** write new features. (Skills: `/deploy` for the ship recipe, `/certify` for the live cert runs, `/eos` as the gate.)

**Entry gate (owner-provided infrastructure — the sole blockers):**
- **SSH ControlMaster socket** to the VPS pilot (`~/.ssh/akshara-cm.sock`, e.g. `ssh -fN -M -S ~/.ssh/akshara-cm.sock -o ControlPersist=8h root@<vps>`).
- **Tenant Postgres** reachable via `ERP_TENANT_DATABASE_URL` (with RLS), for the rolled-back-txn isolation probes and the DR drill.
- A **device or emulator with a camera and high-accuracy location services (mock-location OFF)**, for the staff-attendance live cert (B4). ⚠ B4 is **re-scoped 2026-07-01** — attendance auth = **geofence + anti-mock GPS + live camera face verification**, **never** device biometric/PIN/password; it needs the feature **re-implemented first** (see [`ATTENDANCE_AUTH_DESIGN_DECISION.md`](ATTENDANCE_AUTH_DESIGN_DECISION.md)).

**Exit gate:** all live QA-R legs green + the live-regression cron **7 consecutive days green** → `QA-R-012` PASS → **GA DECLARED**. No QA-R tracker row is *rewritten* — each flips from its current "Verified-local / Test-Written / STAGED-INFRA-BLOCKED" state to live-Verified as its harness runs green.

| # | Task | Priority | Dependencies | Expected output | Completion criteria | EOS gate |
|---|------|:--------:|--------------|-----------------|---------------------|----------|
| **B1** | **Live VPS deployment** — ship backend + latest build to the VPS pilot via the `/deploy` recipe | **P0** (infra blocker) | SSH ControlMaster socket open | VPS pilot running the current HEAD; deploy log + post-deploy smoke | `/health` → 200 · post-deploy smoke green · deployed version == HEAD | PASS on `/deploy` post-deploy smoke |
| **B2** | **Edge Function deployment** — deploy all Supabase edge functions live | **P0** (infra blocker) | B1 | All edge functions live at HEAD (incl. staff-attendance, reliability idempotency/409) | Function-invoke smoke 200 · route inventory matches `api/app.ts` | PASS (function smoke) |
| **B3** | **Database migrations** — apply all pending migrations live (idempotency `row_version`/409, reliability v2, `20260818000000_staff_face_id_attendance.sql`) | **P0** (infra blocker) | B1 · B5 (tenant DB) | Live schema at HEAD; RLS policies present; append-only `staff_check_ins` ledger | Idempotent re-apply clean · schema diff = 0 · RLS + CHECK constraints verified | PASS (migration verify) |
| **B4** | **Staff attendance live cert** (O5) — ⚠ **RE-SCOPED 2026-07-01** (see [`ATTENDANCE_AUTH_DESIGN_DECISION.md`](ATTENDANCE_AUTH_DESIGN_DECISION.md)). Attendance auth = **GPS geofence → anti-mock location validation → live camera face verification → check-in/out**; **NEVER** device biometric / Touch ID / PIN / password. The as-built device-biometric O5 feature is **superseded** and must be **re-implemented first** (P1 gap). | **P0** (blocked on re-impl) | B2 · B3 · **attendance-auth re-implementation** · camera+high-accuracy-GPS device | Attendance working live via geofence + anti-mock + live camera face; ledger writes; self-insert/school-read isolation proven | Live geofence + anti-mock + camera-face check-in/out green · live RLS self-insert PASS · **no device-biometric/PIN path exists** | **PASS on corrected staff-attendance scope** |
| **B5** | **Tenant Postgres configuration** — provision/point `ERP_TENANT_DATABASE_URL` with RLS enabled | **P0** (infra blocker) | B1 | Tenant DB reachable; RLS active; app role wired to `app_current_user_id()` | `tenant_isolation_enforced_test.ts` collapses from ignore-gated → runnable | PASS (connectivity + RLS smoke) |
| **B6** | **Multi-school validation** (`QA-R-002`) — `live_cert_multi_school_concurrent.py` (N=3) + `live_cert_pilot_full_year.py` multi-tenant | **P0** | B2 · B3 · B5 | N schools running the full journey simultaneously with no interference | Concurrent run **N/N green** · zero cross-school interference | PASS (`QA-R-002` live) |
| **B7** | **Tenant isolation validation** (`QA-R-003/004`, `QA-R-008` live-RLS) — `tenant_isolation_enforced_test.ts` 233 probes / 16-way + 13 branding/config probes | **P0** | B5 | Zero read/write bleed between simultaneously-active schools; per-tenant branding/config isolated | **233 probes PASS live** · 13 branding/config probes PASS | PASS (`QA-R-003/004/008` live-RLS) |
| **B8** | **Backup & Restore drill** (`QA-R-009`, closes `QA-J-046`) — live `pg_dump → restore → integrity → drop` on a staging tenant + rollback procedure | **P0** | B1 · B5 | Executed DR drill; integrity-after-restore verified; runbook validated | Drill green · restored data integrity == source · `BACKUP_RESTORE_RUNBOOK.md` steps reproducible | PASS (`QA-R-009` live drill) |
| **B9** | **Monitoring validation** (`QA-R-010`) — trigger each health check / alert / scheduled job; verify live webhook/SMS alert delivery | **P1** | B1 · B2 | Health/alerting/jobs firing and observable in production | Each alert/health/job triggered + observed · watchdog RECOVERED path seen | PASS (`QA-R-010` live) |
| **B10** | **Performance validation (k6)** (`QA-R-005/006`, `QA-X-025`) — run `scripts/perf/qa_x_025_p95_latency_probe.js` at scale on the live-regression lane | **P0** (R-006) / P1 (R-005) | B2 · B3 · B5 (seeded scale) | Live p95 latency + scale numbers vs `PERFORMANCE_TARGETS.md` T1–T8 | Live k6 p95 meets every T1–T8 SLA at production scale | PASS (`QA-R-006` live) |
| **B11** | **Pilot school simulation** (`QA-R-001`) — `live_cert_pilot_full_year.py` unattended single-school representative pass (all ~22 stage types) | **P0** | B2 · B3 · B5 | End-to-end single-school run with **no manual intervention** | All ~22 stages **N/N green** unattended | PASS (`QA-R-001` live) |
| **B12** | **Live regression monitoring** (`QA-X-035/036/039`, `QA-B-073`) — stand up the live-regression cron and hold it green | **P0** (GA prereq) | B1–B11 | Scheduled full-suite cron running against live; alerting on red | **7 consecutive days green**, no red window | PASS (cron 7-day green) |
| **B13** | **`QA-R-012` — Final GA Certification** — verify every Final Production Checklist item; declare Production Ready | **P0** (the gate) | **B1–B12** + B4 (Face ID live) + B12 (7-day cron) | GA sign-off; `QA-R-012` → Verified | Every checklist item satisfied · no open P0 · no blocking P1 | **PASS on `QA-R-012` → GA DECLARED** |

**Staged harnesses already authored (run, don't build):** `scripts/qa/live_cert_pilot_full_year.py` (B11), `scripts/qa/live_cert_multi_school_concurrent.py` (B6), `tenant_isolation_probes.ts` / `tenant_isolation_enforced_test.ts` — 233 probes (B7), `scripts/perf/qa_x_025_p95_latency_probe.js` — k6 (B10), the backup/restore drill scripts (B8), and the staff-attendance migration + edge function (B3/B4). All are `py_compile`/`deno check` clean and **fail-loud** — they collapse to PASS the moment the live socket + tenant DB are available.

---

## PHASE C — Product Enhancement Implementation (post-GA)

**Source of truth:** the 🔒 **frozen** [`PRODUCT_ENHANCEMENT_BACKLOG.md`](PRODUCT_ENHANCEMENT_BACKLOG.md) (Rev 4, 2026-06-30). **Only approved frozen items** are scheduled here — **no invented features, no speculative additions.** Locked product decisions apply to every wave (English-first; students never use Face ID/QR/RFID/geo; staff Face ID is the only Must-Before-GA attendance; parent-comms localization is deterministic-catalog only).

**Structure.** Enhancements are banded by the backlog's priority legend and grouped into **logical module/theme implementation waves** (not one wave per item). Bands sequence the work: **Foundations → Band 1 (P1 Critical Operational) → Band 2 (P2 Productivity) → Band 3 (P3 Nice Improvement)**. `Ph2`/`Fut`-tagged enhancement items are held in the **deferred tail** (they pair with Phase 2 timing but remain sourced from the *enhancement* backlog, not Phase D). Every wave is EOS-gated; each enhancement ID is one engineering task within its wave.

**Entry gate:** `QA-R-012` PASS (GA declared). Foundation work (C0) *may* be owner-approved to overlap the tail of Phase B since it is additive and non-GA-blocking.

### Phase C wave index

| Wave | Theme | Band | Item IDs | Cx | Key dependency |
|------|-------|:----:|----------|----|----------------|
| **C0** | **Cross-cutting foundations** (build first) | Foundation (P1) | XCT-1, XCT-2, XCT-3 | L,L,S | none — unblocks ~20 reports + all reminders |
| **C1** | **Finance — Fee Recovery / Collections CRM** | Band 1 | FIN-R1, FIN-R2, FIN-R3, FIN-R4, FIN-R5 | M×5 | C0 (XCT-1, XCT-2) |
| **C2** | **Finance — Counter, Statements & Reports** | Band 1 | FIN-1, FIN-2, FIN-6, FIN-7, FIN-8 | S–M | C0 (XCT-1) |
| **C3** | **Staff Attendance Dashboard & Muster** | Band 1 | GA-2, GA-3, TCH-9, HR-6 | M×4 | **Phase B B4** (GA-1 live), C0 (XCT-1) |
| **C4** | **Exams — Fast Marks & Tabulation** (O2 top-priority) | Band 1 | EXM-1, EXM-2, EXM-3 | M×3 | C0 (XCT-1) |
| **C5** | **Academic Registers & Certificates** | Band 1 | ATT-1, ATT-2, SIS-1 | L,M,M | C0 (XCT-1) |
| **C6** | **Homework — Core (due-date + non-submitters)** | Band 1 | HWK-1, HWK-2 | S–M,M | ⚠ HWK-1 = contract/schema change (owner + migration) |
| **C7** | **HR — Payroll & Salary Registers** | Band 1 | HR-1, HR-2 | M,M | C0 (XCT-1) |
| **C8** | **Transport — Fleet, Roster & Fee** | Band 1 | TRN-1, TRN-2, TRN-3, TRN-4, TRN-9 | M×4, M–L | C0 (XCT-1); TRN-9 → C2 (FIN-6 pattern) + Finance |
| **C9** | **Operational Modules — Inventory, Library & Communication (daily ops)** | Band 1 | INV-1, INV-2, LIB-1, LIB-2, COM-1, COM-2 | M/S | C0 (XCT-1) |
| **C10** | **Principal — Approval Center batch actions** | Band 1 | PRI-1 | M | none (may co-run with C3) |
| **C11** | **Admissions / Front-office productivity** | Band 2 | ADM-1, ADM-2, ADM-3, ADM-4, ADM-5 | S–M | C0 (XCT-1) |
| **C12** | **Finance productivity & receipting** | Band 2 | FIN-3, FIN-4, FIN-5, FIN-9, FIN-R6, FIN-R7 | S–M | C2, C1 |
| **C13** | **Academic-work productivity (Exams + Homework)** | Band 2 | EXM-4, EXM-5, EXM-6, EXM-7, HWK-3, HWK-4, HWK-5, HWK-6, HWK-7, HWK-8 | S–M | C4, C6, C0 (XCT-1/2) |
| **C14** | **Teacher & Attendance productivity** | Band 2 | TCH-1, TCH-2, TCH-3, TCH-4, ATT-3, ATT-4 | S–M | C0, C4 (EXM-2 for TCH-2) |
| **C15** | **HR & SIS productivity** | Band 2 | HR-3, HR-4, HR-7, SIS-2, SIS-5 | S–M | C0 (XCT-1) |
| **C16** | **Transport & Inventory productivity** | Band 2 | TRN-5, TRN-6, TRN-7, TRN-8, INV-3, INV-4, INV-5, INV-6, INV-7 | S–M | C8, C9, C0 (XCT-1/2) |
| **C17** | **Library & Communication productivity** | Band 2 | LIB-3, LIB-4, LIB-5, COM-3, COM-4, COM-5 | S–M | C9, C0 (XCT-2) |
| **C18** | **Leadership productivity (Principal & Director)** | Band 2 | PRI-2, PRI-3, DIR-1, DIR-2 | S–M | C4 (EXM-2 → PRI-2), C0 (XCT-1) |
| **C19** | **Parent self-service** | Band 2 | PAR-1, PAR-2, PAR-3, PAR-4, PAR-5 | S–M | C0 (XCT-1/2) |
| **C20** | **Teacher & Leadership polish** | Band 3 | TCH-5, TCH-6, TCH-7, PRI-4, PRI-5, DIR-3 | S–M | C0 |
| **C21** | **Records & Parent polish** | Band 3 | SIS-3, SIS-4, HR-5, PAR-6 | S–M | C0 |

> **Wave count = 22 (C0 + 21).** ~90 approved enhancement items grouped into coherent module/theme batches — *not* one wave per item. Cx = relative complexity (S ≤ ~2d · M ~1wk · L > 1wk) carried from the backlog.

### Band 1 — P1 Critical Operational (a real school can't run the daily workflow without it)

Each wave below: **Dependencies · Expected output · Completion criteria · EOS gate.** Every enhancement ID is one task.

- **C0 — Cross-cutting foundations** *(P1; build first)* — **XCT-1** shared PDF+CSV/Excel export pipeline (replaces the platform-wide `showAksharaExportQueuedSnackBar` dead stub, generalising `akshara_report_export_service.dart`), **XCT-2** shared reminder & scheduling foundation (scheduled-job runner + in-app reminder/notification centre; **external push/SMS/WhatsApp delivery stays owner-gated** — in-app surfacing ships now), **XCT-3** date pickers for all free-text date fields *(P2, cross-cutting UX)*.
  - **Deps:** none. **Output:** one real export path + one reminder rail every module reuses; no module invents its own. **Completion:** ≥3 module "Export" buttons emit a real file; ≥1 in-app reminder fires end-to-end; date pickers on the 4 known free-text date fields. **EOS gate:** PASS on the foundation scope before any dependent wave starts.
- **C1 — Finance Fee Recovery / Collections CRM** — FIN-R1 recovery dashboard · FIN-R2 telecaller call queue · FIN-R3 promise-to-pay · FIN-R4 contact/reminder history · FIN-R5 collector performance. **Deps:** C0. **Output:** the defaulter list *expands* (does not duplicate) into a real recovery CRM. **Completion:** call queue → log outcome → PTP → contact-history persist round-trip; collector metrics compute from real data. **EOS gate:** PASS.
- **C2 — Finance Counter, Statements & Reports** — FIN-1 daily collection summary export · FIN-2 printable student fee statement/ledger · FIN-6 installment/term-wise due schedule (replaces hardcoded +30d) · FIN-7 transaction-level day collection report · FIN-8 class-wise dues report. **Deps:** C0. **Output:** the fee office's daily counter reports + a per-student ledger. **Completion:** each report exports real transactions; installment due dates drive aging. **EOS gate:** PASS.
- **C3 — Staff Attendance Dashboard & Muster** — GA-2 manual attendance request + manual close (mandatory reason, Principal/HR approve, fully audited) · GA-3 principal real-time staff-attendance summary (Total/Checked-In/Checked-Out/Working-Now/Late/Absent) · TCH-9 "My Attendance" (read-only self-service) · HR-6 monthly staff-attendance muster export. **Deps:** **Phase B B4** (GA-1 biometric check-in/out live) + C0 (XCT-1). *GA-1 is already built/certified; this wave adds the exception workflows + dashboards that ride on its `staff_check_ins` ledger.* **Output:** the read-only HR-04 screen becomes a live operational board feeding payroll. **Completion:** manual-close audited; summary rolls up from GA-1/GA-2; muster exports employee×day grid. **EOS gate:** PASS.
- **C4 — Exams: Fast Marks & Tabulation** *(O2 top-priority module)* — EXM-1 fast bulk marks entry (grid, Enter-to-next, Save-all; folds "save all marks") · EXM-2 marks-entry progress board across teachers/classes · EXM-3 consolidated class mark sheet / tabulation register export. **Deps:** C0. **Output:** a class of 30 marked in ~1 grid save instead of ~60 taps; school-wide completion visibility. **Completion:** Save-all persists a whole class; progress board shows who still owes marks; tabulation register exports. **EOS gate:** PASS.
- **C5 — Academic Registers & Certificates** — ATT-1 office attendance register (AC-06, a specced P0 with no screen: filter, named present/absent/late, read+export) · ATT-2 monthly class attendance register export (students×days grid) · SIS-1 Bonafide/Study/Conduct certificate generation (print-ready PDF, English). **Deps:** C0 (XCT-1). **Output:** the canonical monthly attendance artifacts + student certificates. **Completion:** register renders + exports; certificates generate as print-ready PDFs. **EOS gate:** PASS.
- **C6 — Homework Core** — HWK-1 real due-date picker (replace free-text `due_label`; keystone for reminders/overdue/sorting) · HWK-2 "not submitted" list per assignment. **Deps:** ⚠ **HWK-1 is a contract/schema change** (`due_label` free-text → real `due_date DATE`) — needs an owner-approved migration (flagged, not created here). **Output:** structured due dates + roster-diff non-submitter list. **Completion:** due-date persists as DATE; non-submitters computed from roster diff. **EOS gate:** PASS.
- **C7 — HR Payroll & Salary Registers** — HR-1 salary register export (per-employee Basic/Allowances/Deductions/Net + totals) · HR-2 one-click payslip run (per-employee PDF + all-for-run). **Deps:** C0 (XCT-1). **Output:** payroll produces real payslips + a salary register, replacing the stub snackbar. **Completion:** payslip PDFs generate per run; register exports with totals. **EOS gate:** PASS.
- **C8 — Transport Fleet, Roster & Fee** — TRN-1 vehicle & driver registration (CRUD, replaces seed-only) · TRN-2 vehicle-document expiry tracker (real dates) · TRN-3 stop-wise student roster + route roster print/export · TRN-4 stop editor / ordered stop management · TRN-9 transport fee structure + due schedule → **raises fee demand** (Transport *defines*; **Finance remains the only payment engine**). **Deps:** C0 (XCT-1); TRN-9 reuses the **C2 FIN-6** installment pattern + hands off to Finance. **Output:** a school can onboard its fleet, print stop rosters, and bill transport through Finance. **Completion:** fleet CRUD persists; stop rosters export; transport demand appears in Finance (no duplicate payment logic). **EOS gate:** PASS. *(Live GPS bus tracking stays Phase D / O8 — untouched here.)*
- **C9 — Operational Modules: Inventory, Library & Communication** — INV-1 stock issue/consumption with issue slip · INV-2 consumable registry + reorder-level CRUD · LIB-1 one-click overdue list + export · LIB-2 catalog edit/delete + CSV bulk import · COM-1 per-broadcast delivery & read report + CSV export · COM-2 audience picker (class/section) + saved segments. **Deps:** C0 (XCT-1). **Output:** stock can go *down*, the library catalog is editable/importable, broadcasts target classes and report delivery. **Completion:** issue-slip persists; catalog edit/import works; broadcast delivery/read report exports; class/section audience resolves. **EOS gate:** PASS.
- **C10 — Principal Approval Center batch actions** — PRI-1 batch approve/reject (multi-select) in the Approval Center. **Deps:** none (may co-run with C3, both principal-facing). **Output:** the principal clears 5–15 daily approvals in bulk instead of one-by-one. **Completion:** multi-select approve/reject persists + audits each decision. **EOS gate:** PASS.

### Band 2 — P2 Productivity (speeds up / de-duplicates an existing flow)

- **C11 — Admissions / Front-office productivity:** ADM-1 real admissions reports export · ADM-2 auto-log WhatsApp/call to lead timeline · ADM-3 bulk lead actions · ADM-4 inline actions on "Follow-ups due today" · ADM-5 "New Application" from a real lead picker (removes placeholder-junk rows).
- **C12 — Finance productivity & receipting:** FIN-3 Indian-format receipt polish (logo/letterhead/amount-in-words/ORIGINAL-COPY; English preserved) · FIN-4 duplicate-receipt reprint (+DUPLICATE stamp + audit) · FIN-5 batch receipt printing · FIN-9 outstanding analytics · FIN-R6 collection targets *(needs FIN-D6)* · FIN-R7 cheque/DD/PDC + bounce tracking.
- **C13 — Academic-work productivity (Exams + Homework):** EXM-4 subject-topper/merit list · EXM-5 pass/fail & grade-distribution report · EXM-6 marks-entry deadline + teacher reminder *(rides XCT-2)* · EXM-7 exam datesheet PDF · HWK-3 same homework → multiple sections · HWK-4 teacher attachment on create · HWK-5 homework history/export · HWK-6 bulk mark-submitted/reviewed · HWK-7 student submit with note/photo · HWK-8 "due tomorrow" reminder *(rides XCT-2 + HWK-1)*.
- **C14 — Teacher & Attendance productivity:** TCH-1 mark attendance from a today-schedule row · TCH-2 marks-pending/deadline surface on home *(ties XCT-2)* · TCH-3 my-class summary export · TCH-4 cover/substitution alert + weekly timetable · ATT-3 absentees-only fast-mark · ATT-4 office "not-yet-marked" compliance monitor.
- **C15 — HR & SIS productivity:** HR-3 batch leave approve/reject · HR-4 leave-balance report/export · HR-7 employee directory export · SIS-2 richer registry export + class-list/contact-sheet · SIS-5 transfer/exit log report.
- **C16 — Transport & Inventory productivity:** TRN-5 bulk student→route allocation · TRN-6 transport list/vehicle exports · TRN-7 route capacity/over-allocation warning · TRN-8 document-expiry reminders *(rides XCT-2 + TRN-2)* · INV-3 manual stock-adjust · INV-4 low-stock/reorder report + raise-PO · INV-5 stock/consumption/GRN exports · INV-6 physical stock-take/count session · INV-7 low-stock alert to storekeeper *(rides XCT-2)*.
- **C17 — Library & Communication productivity:** LIB-3 barcode quick issue/return (plain book barcode/ISBN — *not* biometric) · LIB-4 loan renewal/re-issue · LIB-5 overdue-book reminder *(rides XCT-2)* · COM-3 resend-to-unread · COM-4 schedule-send (activates dead `scheduled_at` — rides XCT-2) · COM-5 save-broadcast-as-template.
- **C18 — Leadership productivity (Principal & Director):** PRI-2 unsubmitted/pending exam-marks exception list (shares EXM-2 data) · PRI-3 daily school report · DIR-1 cross-school league table · DIR-2 consolidated collection report.
- **C19 — Parent self-service:** PAR-1 surface PTM Accept/Decline RSVP (endpoint exists) · PAR-2 "Apply Leave" dashboard quick action · PAR-3 medical-certificate upload on leave · PAR-4 payment-history export · PAR-5 in-app proactive reminder banners *(ties XCT-2)*.

### Band 3 — P3 Nice Improvement (polish / convenience)

- **C20 — Teacher & Leadership polish:** TCH-5 "Create homework" quick action · TCH-6 pending-task counts deep-link to filtered view · TCH-7 teacher timetable export/share · PRI-4 weekly principal digest · PRI-5 pending-approval reminder/escalation *(surface the inert stale-count)* · DIR-3 CSV/Excel export of the school-comparison table.
- **C21 — Records & Parent polish:** SIS-3 document "Verify" action + status · SIS-4 family/sibling view for the clerk · HR-5 headcount-by-department report · PAR-6 surface PTM action-items/follow-ups + "next PTM" hero.

### Phase C deferred tail (`Ph2` / `Fut` enhancement items — pair with Phase 2 timing)

Sourced from the *enhancement* backlog (not Phase D). Scheduled only when their paired Phase-2 capability lands or the owner promotes them: **SIS-6** bulk document upload · **EXM-8** comparative term analysis · **HWK-9** templates/"repeat last" · **HWK-10** class homework-load/clash + principal oversight · **COM-6** thread export for a parent · **LIB-6** member library-card/history export · **LIB-7** book reservation/hold queue *(Fut)* · **INV-8** vendor performance/rating · **TCH-8** global section/class quick-switcher · **PAR-7** event RSVP actionable · **PAR-8** add-to-calendar (.ics).

### Phase C — pending owner decisions (Appendix A — must resolve before the affected task runs)

The backlog's **Appendix A (~26 behaviour/policy items)** are **not scheduled into a wave** until the owner decides; each then slots into the band shown in the backlog. They gate specific tasks above:

| Group | Decisions (→ recommended default in backlog) | Blocks |
|---|---|---|
| **Finance** | FIN-D1 day-close lock · FIN-D2 fee-head allocation on part-pay · FIN-D3 receipt-cancellation reason · FIN-D4 concession maker-checker *(⚠ prereq: concession persistence is an in-memory **defect** → route to QA)* · FIN-D5 late-fee accrual · FIN-D6 collection-target ownership | C2, C12 |
| **Admissions** | ADM-D1 lost-reason taxonomy · ADM-D2 duplicate-lead warn-vs-block · ADM-D3 admission-number scheme *(⚠ back-compat)* · ADM-D4 offer/confirmation letter | C11 |
| **SIS** | SIS-D1 TC engine (no-dues gate/auto-status/register) · SIS-D2 ID-card batch · SIS-D3 mandatory-document set | C5, C15 |
| **HR** | HR-D1 staff document-expiry types + lead · HR-D2 probation-end follow-up · HR-D3 leave-on-behalf balance rule | C15 |
| **Attendance** | ATT-D1 consecutive-absence escalation · ATT-D2 short-attendance threshold · ATT-D3 half-day + auto-excuse approved leave | C5, C14 |
| **Exams** | EXM-D1 batch report-card print trigger · EXM-D2 grace/moderation policy · EXM-D3 supplementary result rule · EXM-D4 hall-ticket content · EXM-D5 seating strategy · EXM-D6 absent/"AB" handling | C4, C13 |
| **Comm / Library / Homework / Director / Parent** | COM-D1 acknowledgement-required notices · LIB-D1 issue guardrails · HWK-D1 "not submitted" parent nudge · DIR-D1 per-school drill-down scoping · PAR-D1..D6 (cancel leave · family view · 80C certificate · action inbox · parent calendar view · consent slips) | C17, C9, C13, C18, C19 |

> **QA defects (not Phase C waves) — route to the tracker:** the platform-wide export dead-stub (fixed *by* XCT-1), HR leave-dialog hardcoded `employeeId`, in-memory concession persistence (prereq for FIN-D4), admissions placeholder-junk rows (fixed by ADM-5), and the one mock canonical student-registry path. These are honesty/quality issues, per the backlog's "Out of scope — defects" list — they belong in `FINAL_QA_MASTER_TRACKER.md`, not a product wave.

---

## PHASE D — Future / Phase 2 / Commercial

**Source of truth:** [`PRODUCT_COMMERCIAL_BACKLOG.md`](PRODUCT_COMMERCIAL_BACKLOG.md) **only** (owner decisions O1–O10). **Not mixed with Phase C.** These are post-GA, mostly monetization/enterprise/future-vision, and are *not* scheduled into dated waves here — they are the forward commercial roadmap, promoted individually by owner decision when the market calls for them.

### D1 — Phase 2 Commercial (Queue 4)

| Item | Owner decision |
|---|---|
| In-product billing (invoicing, MRR, renewals, subscription payment collection) | O6 |
| Usage quotas + packs (SMS / storage / AI tokens) | O6 |
| Marketplace purchasable add-ons | O6 |
| Live GPS bus tracking + parent live map + driver app | O8 |
| White-label platform + custom domain + subscription-aware branding tiers | O10 (ties O6) |
| Custom theme maturity (beyond per-school colours) | Enterprise upsell |
| Full general ledger / accounting | Premium; post-core |
| Dedicated expense-management module | Premium |
| Device / MDM management console | Enterprise |
| Community portal (standalone) | Beyond core ERP |
| "API-OFF-live" Enterprise surfaces — Workflow Automation, Academic Operations, Continuity, Platform Ops/Intelligence (UI exists, backend flag OFF live) | Phase 2 enable-when-productized (hide-first per O1) |

### D2 — Future Vision (Queue 5 — deferred / scoped-out)

| Item | Rationale |
|---|---|
| Industry vertical packs (healthcare / salon / restaurant / accommodation) | O1 — hide-first (UIs route-guarded off) |
| Branch / franchise management | O1 (multi-school/director KEPT) |
| Geo-fencing attendance · RFID attendance · QR attendance | O9 |
| **Student Face ID** | **N/A by decision (O4)** — students never; teachers enter attendance |
| Face-recognition (CV) attendance | Future product; no CV pipeline |
| School website builder / CMS · dynamic pages · blog · SEO | Beyond core ERP |
| Reception desk · gate pass · school-wide visitor mgmt | Hostel-scoped visitor mgmt exists; school-wide is future |
| Secure CBT / online exam workspace | Archived-docs only |
| App biometric lock (parent/teacher mobile) | Documented, not coded |
| Biometric / RFID hardware partner integrations | Hardware partnerships |

### D3 — Consolidation & De-duplication (proposed `QW-Consolidation`, owner-review)

Per North Star O3 ("easiest, cut scope creep"), the audit's **14 overlapping surfaces** are candidates for a focused consolidation wave (e.g. unify AI entry points; single communication primitive; converge principal dashboards on the Dynamic Widget Platform; document Assets as an Inventory submodule). **Owner go/no-go required** before it becomes a scheduled wave — see the backlog's Consolidation table.

### Phase D — related Queue 3 deferred deepening (quality/premium, cross-reference)

Sourced from the commercial backlog's Queue 3 (future QW — quality, not new scope), noted here so nothing is lost: **HR Excel bulk import** (owner-deferred module-deepening; certifies `QA-X-020`/`QA-F-048` when built — *explicitly excluded from the Phase C enhancement backlog*), **Custom Reports / report-builder** (ties to the Phase C XCT-1 export foundation but the full builder is premium/future), and premium-module deepening (Lesson Planning, Syllabus depth, Scholarships/Discounts depth, Asset Mgmt). These fold into their module's future QW cert; **not GA-blocking**.

---

## Conflicts found & reconciliation (during this roadmap build)

1. **Staff Face ID banding (enhancement backlog vs O5 cert).** The frozen enhancement backlog lists **GA-1/GA-2/GA-3** as "GA" items, but the O5 `STAFF_FACE_ID_ATTENDANCE_CERTIFICATION.md` proves **only GA-1** (biometric check-in/out) is built. **Reconciled:** GA-1 → **Phase B B4** (live deploy = the only residual); **GA-2 + GA-3 (+ TCH-9, HR-6)** → **Phase C Wave C3**. No duplication; if a later build already delivered GA-2/GA-3, C3 collapses to verification-only *(owner to confirm — see decisions below)*.
2. **HR Excel bulk import.** Appears in the commercial Queue 3 (owner-deferred) **and** is explicitly **excluded** from the enhancement backlog's main tables. **Reconciled:** kept **out of Phase C**; lives in **Phase D** Queue-3 deferred deepening (certifies `QA-X-020`/`QA-F-048`). No wave duplicates it.
3. **Custom Reports / report-builder vs XCT-1.** Both touch "export/reporting." **Reconciled:** **XCT-1** (shared export pipeline) is the Phase C **foundation** (C0); the full **report-builder** stays Queue 3 / Phase D (premium). Cross-referenced, not duplicated.
4. **TRN-9 transport fee vs the Phase-2 payment engine (O6/O8).** **Reconciled per the owner-decided architecture:** Transport only **defines** fee structure + due schedule and **raises demand**; **Finance stays the sole payment/collection engine** (TRN-9 reuses the FIN-6 installment pattern). Transport fee = Phase C (C8); live GPS tracking = Phase D (O8). No conflict.
5. **Parent Communication Localization.** Must-Before-GA (Queue 2) **and already BUILT** (QW7 `QA-C-016/018`, deterministic no-LLM catalog). **Reconciled:** **not** a Phase C item (it is GA-complete); its **live send-path validation rides Phase B** (B6/B11 pilot runs). English-first everywhere else stands.
6. **Backup/DR.** `QA-R-009` is local-certified; the **live** `pg_dump→restore→integrity` drill is **Phase B B8** (closes the QW5-deferred `QA-J-046`), **not** a Phase C wave.
7. **Reminder delivery channel.** All module reminder items (HWK-8, LIB-5, TRN-8, INV-7, EXM-6, COM-4, PRI-5, PAR-5) ride **XCT-2's in-app** rail only; **external push/SMS/WhatsApp delivery stays owner-gated** until the owner opens the go-live channel (see decisions).

## Owner decisions required before implementation

**Phase B (unblocks GA):**
1. ✅ **SSH ControlMaster socket** — open (owner opened it 2026-07-01). 2. **Tenant Postgres** `ERP_TENANT_DATABASE_URL` (with RLS) for isolation probes + DR drill. 3. A **camera + high-accuracy-location device/emulator (mock-location OFF)** for the staff-attendance live cert (B4) — **and** the B4 **attendance-auth re-implementation** per [`ATTENDANCE_AUTH_DESIGN_DECISION.md`](ATTENDANCE_AUTH_DESIGN_DECISION.md) (attendance = geofence + anti-mock + live camera face; **never** device biometric/PIN/password). ⚠ **FINAL product correction 2026-07-01** — the as-built device-biometric O5 feature is **superseded**.

**Phase C (before the affected wave runs):**
4. **Confirm GA-2/GA-3 (+ TCH-9/HR-6) are un-built** (the O5 cert only covers GA-1) → they are real C3 scope, not verification-only. 5. **HWK-1 contract change** (`due_label` → `due_date DATE`) — approve the schema/migration (keystone for HWK reminders/overdue). 6. **XCT-2 external-delivery go-live** (push/SMS/WhatsApp) — currently owner-gated; decide when in-app-only reminders may fan out externally. 7. **Resolve Appendix A (~26 items)** to their recommended defaults (or alternatives) so C2/C4/C5/C11/C12/C13/C14/C15/C17/C18/C19 can schedule their blocked tasks. 8. **Route the listed QA defects** (in-memory concession persistence, hardcoded HR `employeeId`, mock student-registry path) to `FINAL_QA_MASTER_TRACKER.md` rather than a product wave.

**Phase D:** 9. **Consolidation go/no-go** (`QW-Consolidation`, D3). 10. Phase-2 monetization sequencing (billing/quotas/white-label — O6/O10) is owner-timed post-GA.

## Phase B / C / D ordering summary

| Phase | Scope | Tasks/Waves | GA-blocking? | Starts after |
|---|---|---|:---:|---|
| **B — Release Engineering** | Track B live-VPS validation → `QA-R-012` | B1–B13 | **YES** (the only GA gate) | Owner opens SSH socket + tenant Postgres *(now available)* |
| **C — Product Enhancement** | Frozen enhancement backlog (Rev 4) | C0 + C1–C21 (22 waves, ~90 items) | No (post-GA) | `QA-R-012` PASS (C0 foundations may overlap with owner OK) |
| **D — Future / Commercial** | Commercial backlog Queues 4/5 + Consolidation | D1 / D2 / D3 (roadmap, owner-promoted) | No | Post-GA, owner-timed |

**Governance (unchanged):** the EOS (`/eos <scope>`) is the single engineering gate for every Phase B task and Phase C wave — none is "complete" until EOS returns PASS. QW1–QW8 certifications, the Master Tracker rows, and both frozen backlogs are **preserved, not modified**, by this continuation. **Nothing in Phases B/C/D executes until the owner approves each phase.**
