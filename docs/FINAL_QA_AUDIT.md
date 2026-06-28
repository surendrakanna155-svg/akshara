# AKSHARA ERP — Final QA Completion Audit

**Date:** 2026-06-27
**Branch HEAD:** `0f33c6a` (Legal & Compliance layer)
**Status of GA Certification:** ⏸ **PAUSED** — the product is **not** GA-ready until this program completes.
**Phase:** Audit + coverage analysis + gap identification only. **No code, tests, or fixes were written.** Test creation and fixing happen in the QA waves *after* owner approval.

This document is the analytical companion to:
- [`docs/FINAL_QA_MASTER_TRACKER.md`](FINAL_QA_MASTER_TRACKER.md) — the single source of truth (246 itemised gaps).
- [`docs/FINAL_QA_ROADMAP.md`](FINAL_QA_ROADMAP.md) — the 6 grouped QA waves.

---

## 1. Objective

Prove that **every existing production feature works correctly through complete end-to-end testing**, exactly as real schools will use it — login to completion, across all 9 roles. This is **not** a feature-building program and **not** a redesign. The work is: testing, verification, coverage analysis, gap identification, test creation, and documentation.

This phase delivers the **analysis and plan**. It does **not** fix anything. We stop after the three documents and await approval before executing the waves.

---

## 2. Method (journey-first)

We inventoried the **entire** existing test estate before proposing any new test, to avoid duplication:

| Inventory pass (parallel agents) | What it read |
|---|---|
| Flutter test suite | `test/**` (511 `.dart` files) + `coverage/lcov.info` |
| Patrol + Maestro journeys | `patrol_test/**` (127 files) + `qa/journeys/**` (128 YAML) + manifests |
| Backend tests + cert scripts | `supabase/functions/**` (150 Deno `*_test.ts`) + `scripts/**` (~50 smoke/live-cert) |
| App surface map | `lib/features/**` (44 modules) — screens, routes, dialogs, forms, actions |
| Routes + RBAC + API | `lib/router/**` (286 routes), `lib/core/security/**` (148 permissions, 15 ErpRoles), `openapi/**` |
| Test execution / CI model | `.github/workflows/**`, `qa/run_all_qa.sh`, `scripts/qa/run_ci_gates.sh` |

We then cross-referenced **surface vs. coverage** per role and per module (4 parallel gap-analysis passes) to produce 246 itemised gaps with a uniform severity + wave rubric.

---

## 3. Inventory at a glance

| Asset | Count |
|---|---:|
| Feature modules (`lib/features/`) | 44 |
| App routes (`route_names.dart`) | 286 unique paths |
| Roles / personas (product) | 9 (over 15 `ErpRole` values) |
| Permissions (`Permission` enum) | 148 |
| UI mutation guards | 49 actions across 44 screens |
| Backend API endpoints | ~446 (50 module routers) |
| **Flutter tests** | 511 files (~480 real, ~1,683 cases) |
| **Patrol E2E tests** | 389 cases / 31 source files |
| **Maestro journeys** | 128 YAML flows |
| **Backend Deno tests** | 150 files / 874 cases |
| **Smoke / live-cert scripts** | ~50 (all LIVE-targeted) |

**The headline numbers look strong. The depth behind them does not.** Sections 4–5 explain why.

---

## 4. Coverage calculation — the honest picture

### 4.1 Flutter line coverage is a *partial subset*, not whole-app
`coverage/lcov.info` reports **76.56% (9,569 / 12,499 lines)** — but it instruments only **272 of 1,598 `lib/` files (~17%)**, concentrated in parent / admissions / finance / teacher / student / sis. The remaining **~83% of `lib/` is not measured at all** (platform, intelligence, copilot, verticals, hostel, library, hr, inventory, transport, director, evolution, achievement_promotion, …). The lcov file is also dated **Jun 6**, before many shipped batches. **Treat 76.56% as a subset floor, not the app's coverage.** The project's own prior reports (Routes 20% / Screens 35%) are consistent with this.

### 4.2 The "screen-pump" gap — providers tested, screens never rendered
The single biggest *measurable* Flutter gap: business logic (providers/repositories/RBAC) is broadly unit-tested, but the **screens that render it are never pumped**. Confirmed **0% line coverage** on pilot-critical UI including the entire parent fees surface (`parent_fees_screen`, `fee_summary_hero`, `fee_breakdown_card`, `installment_timeline`, `payment_history_card`, `pay_now_bottom_bar`), `parent_attendance_screen`, the **auth `otp_verification_screen`**, `leave_apply_form`, and `notifications_screen` (0.6%).

### 4.3 Journey depth — high count, shallow reality
Of 128 Maestro flows, **~73 are NAV-only** (`login → tap → screenshot`, no assertion) and 10 are explicit `*_nav` stubs. The Patrol `*_workflows_test.dart` files (parent 14, teacher 11, student 9, …) are mostly **READ** (assert-visible after navigation). The real WRITE / PERSISTENCE / APPROVAL depth lives in a smaller set of `*_e2e_test.dart` + `patrol_batch*` + `pilot_closure` + `finance_full_journey` files. **"Coverage" credited to journey count overstates verified-workflow coverage.**

### 4.4 Backend — contracts and RBAC largely unasserted
Only **165 of ~446 endpoints (~37%)** are in the validated `RBAC_ROUTE_INVENTORY`; the other **281 have zero automated permission/scope assertion**. Only **9 of 50 routers** have a path-match/404 contract test. Cross-tenant (RLS) isolation for hr, hostel, library, alumni, inventory, transport, finance, control_center, director, school_completion is asserted **only in manual live waves**, never in a unit test.

### 4.5 The coverage that exists is not enforced
- The primary CI gate (`flutter_ci.yml`) runs only **4 of 127** Patrol E2E tests.
- `deno test` in CI runs **`_shared/` only** — the `api/` handlers (money/RBAC endpoints) are never executed in CI.
- **129 Maestro journeys** and **~50 live smoke/cert scripts** run **manually only** — in no workflow.
- `run_ci_gates.sh` emits `lcov.info` but **enforces no minimum threshold** (CI only checks the file exists).

---

## 5. Systemic findings (root causes)

These ten themes explain the 246 gaps. The Master Tracker groups every row under one of them.

| # | Finding | Evidence | Risk |
|---|---|---|---|
| **F1** | **Depth illusion** — large suite count, shallow assertions | 73/94 `biz_*` are nav-only; workflow `*_test.dart` mostly READ | Regressions in *completion* (not navigation) ship undetected |
| **F2** | **4 of 9 roles have no test persona** — HR, Staff(generic), School Admin, Director all run as `superAdmin` | Only 7 Patrol personas exist | Per-role RBAC isolation is structurally **unverified** for 4 roles |
| **F3** | **1:1 messaging send is untested in every direction** | All `*_messages`/`*_conversation` screens are inbox-READ; only admin broadcast sends | Parent↔teacher↔student comms could be broken and no test would catch it |
| **F4** | **Screen-pump gap** — money/auth/notifications screens at 0% widget coverage | §4.2 | The exact surfaces a parent/teacher touches daily are unrendered in tests |
| **F5** | **Backend route-contract & RBAC matrix gap** | 281/446 endpoints unasserted; 41/50 routers untested; RLS live-only | A permission/tenant regression on an unlisted route is invisible to CI |
| **F6** | **CI does not run the suites that guard money & RBAC** | §4.5 | Verified flows can silently rot between manual certifications |
| **F7** | **No offline stack and no 5xx-retry** | `pubspec.yaml` has no `connectivity_plus`/`hive`/`sqflite`; `api_error_interceptor` maps but does not retry | Attendance/fee writes on a flaky pilot network risk **silent data loss** — ⚠ see §7 |
| **F8** | **FCM push entirely untested; audit-row persistence never asserted** | `push_messaging_service.dart` has 0 referencing tests; journeys assert export *buttons*, not audit rows | A silent push-registration failure = parents never notified; money/exam writes lack a *verified* audit trail |
| **F9** | **OpenAPI is not a contract source** | 46 documented operations vs ~446 real; writes mostly absent | Contract testing cannot lean on the spec; it must be derived from routers |
| **F10** | **Pay-fee completion & academic year-end ops stop short of commit** | parent `pay_fee` only navigates; promote/reshuffle/balance are preview-only | The money loop and the grade-progression loop are never **persistence-verified** end-to-end as the real persona |

---

## 6. Per-role coverage assessment

| Role | Test persona? | Journey depth today | Headline gaps |
|---|---|---|---|
| **Parent** | ✅ | Results = strong; fees/messaging = shallow | Pay-fee completion + receipt persist; message teacher (send); child-switch reload; fees/attendance screens 0% widget |
| **Student** | ✅ | READ-strong; writes shallow | Homework *submit* (persist); cross-shell RBAC deep-link; message/leave send |
| **Teacher** | ✅ | Attendance = strong; rest shallow | Create-homework form submit; enter-marks as teacher; message parent (incl. AI send); grade homework |
| **HR** | ❌ (runs as superAdmin) | CRUD/payroll deep but god-login | No HR-scoped RBAC; Excel employee import; payroll PDF |
| **Staff (functional)** | ⚠ partial (finance, inventory only) | Finance = deepest | No persona for transport/hostel/library/counselor/storekeeper → cross-module RBAC unverified |
| **Principal** | ✅ | Approvals = strong | Explicit admission approve; broadcast as principal; reject-with-comment persist; longest-prefix anti-escalation |
| **School Admin** | ❌ (runs as superAdmin) | Onboarding = richest | No schoolAdmin RBAC scope; promote/reshuffle/balance commit-verify; transfer/TC |
| **Director** | ❌ (runs as superAdmin) | Dashboards READ | No director org-scope; ChainScope isolation; metric-input → margin/ROI persist; board-pack PDF |
| **Super Admin** | ✅ | Best-covered | ControlCenterGuard negative cases (schoolAdmin/director/finance denied); plan-assign → entitlement effect |

---

## 7. ⚠ Findings that imply *platform* work → resolved as Phase 0

These gaps are genuine coverage-goal items ("offline behaviour", "retry behaviour") whose underlying capability **does not exist yet**, so a test cannot be written without first building the capability:

- **No offline stack** (QA-X-001..005): no connectivity layer, banner, read-cache, or write-queue. Offline attendance/fee entry = silent data-loss risk.
- **No 5xx/429 retry/backoff** (QA-X-008): `api_error_interceptor` maps errors but never retries.
- **Double-submit / unsaved-guard** (QA-X-006/009): guards exist but are untested at real sites; belong in the same platform.

> **Owner decision (2026-06-27): BUILD.** These are **core platform reliability requirements**, not optional features — a teacher who enters 35/50 marks and is interrupted, or loses signal mid-attendance, must never lose work (WhatsApp-draft UX). They are resolved by a reusable **Data Reliability Platform** (Draft Persistence + Sync Engine + Repository Integration) built in **Phase 0**, before any QA wave. No row is `Won't-Build`. Architecture is reviewed/approved before implementation — see [`DATA_RELIABILITY_PLATFORM_DESIGN.md`](DATA_RELIABILITY_PLATFORM_DESIGN.md). Until the platform ships, QW1 does not begin.

---

## 8. Coverage-goal scorecard

The program's stated coverage goal, scored against reality:

| Coverage dimension | Status | Note |
|---|---|---|
| Every screen | 🟡 Partial | Many screens never pumped (parent fees, auth OTP, notifications, operations, onboarding, employee, school_config) |
| Every button / action | 🟡 Partial | Write-actions covered in deep e2e; thousands of dialog/sheet actions unasserted |
| Every menu / nav path | 🟢 Mostly | Route guards + nav smoke broad; per-persona nav-builder route map untested |
| Every dialog / bottom sheet | 🔴 Weak | Finance/transport/HR/education dialogs open+confirm largely untested |
| Every form | 🟡 Partial | Validation tested for some; HR/education/onboarding/teacher forms not pumped |
| Every search / filter | 🔴 Weak | Finance search bar (only real one) untested; filter flows shallow |
| Every import / export | 🟡 Partial | Student onboarding importer rich; HR Excel / education CSV / board-pack PDF untested |
| Every dashboard / widget | 🟡 Partial | Goldens for 4 dashboards only; finance/admissions/director/control-center ungoldened |
| Every role | 🔴 Weak | 4 of 9 roles have no test persona (F2) |
| Every API contract | 🔴 Weak | 281/446 endpoints unasserted; 41/50 routers untested (F5) |
| Every persistence path | 🟡 Partial | Strong in finance/attendance e2e; pay-fee + promote/reshuffle commit unverified (F10) |
| Loading / error / empty states | 🟡 Partial | Ad-hoc per module; no systematic sweep |
| Offline behaviour | 🔴 None → **Phase 0** | Feature absent (F7, §7); now a build prerequisite, not a Won't-Build |
| Retry behaviour | 🟡 Partial → **Phase 0** | Auth-refresh exists (untested); no 5xx retry; double-submit guard untested — folded into the platform |
| RBAC paths | 🟡 Partial | Client guards exist; server-side per-route matrix + cross-shell isolation largely unasserted |
| Notifications / audit trail | 🔴 Weak | FCM untested; audit-row persistence never asserted (F8) |
| CI enforcement | 🔴 Weak | Suites exist but mostly don't run in CI (F6) |

Legend: 🟢 strong · 🟡 partial · 🔴 weak/none.

---

## 9. Gap totals

| | P0 | P1 | P2 | Total |
|---|---:|---:|---:|---:|
| End-to-end journeys (`QA-J`) | 23 | 32 | 14 | **69** |
| Flutter widget/UI/state (`QA-F`) | 10 | 36 | 17 | **63** |
| Backend API/RBAC/RLS (`QA-B`) | 22 | 39 | 14 | **75** |
| Cross-cutting / non-functional (`QA-X`) | 9 | 18 | 12 | **39** |
| **Total** | **64** | **125** | **57** | **246** |

Severity: **P0** = pilot-critical workflow or security/RBAC/data-integrity path with no/shallow coverage · **P1** = important operational module workflow, partial/nav-only · **P2** = secondary / advanced / display-only.

---

## 10. What this audit deliberately does NOT do

- It does **not** duplicate existing tests — every recommended test is a confirmed gap.
- It does **not** fix, refactor, or add features.
- It does **not** change the product roadmap or invent scope.
- It does **not** re-litigate areas already covered by an existing certification *except* to record where a certification asserted a button/value but not the underlying **persistence/RBAC/audit** path (those are real coverage gaps, not re-certification).

Next: the [Master Tracker](FINAL_QA_MASTER_TRACKER.md) itemises all gaps; the [Roadmap](FINAL_QA_ROADMAP.md) sequences them. **Update (2026-06-27):** the program now spans **283 rows across 8 waves** — the original 246 technical-coverage gaps (QW1–QW6) plus **37 mandatory certification rows**: **QW7 Feature Behaviour Certification** (`QA-C`, end-user behaviour: UI/comms/i18n/RBAC/reliability/AI/white-label) and **QW8 Production Readiness & Market Certification** (`QA-R`, the final commercial go-live gate). All preceded by **Phase 0 — Data Reliability Platform** (owner-approved build). GA is declared only after QW8's Final Production Checklist passes.
