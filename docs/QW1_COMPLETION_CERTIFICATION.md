# QW1 — Critical Path & CI Enforcement · COMPLETION CERTIFICATION

**Date:** 2026-06-28 · **Branch:** `feature/data-reliability-platform`
**Gate:** Engineering Operating System (`/eos`) per [`engineering/ENGINEERING_GATE_POLICY.md`](engineering/ENGINEERING_GATE_POLICY.md).
**Companion:** [`FINAL_QA_MASTER_TRACKER.md`](FINAL_QA_MASTER_TRACKER.md) · [`FINAL_QA_ROADMAP.md`](FINAL_QA_ROADMAP.md) · [`engineering/eos/EOS_RUN_LEDGER.md`](engineering/eos/EOS_RUN_LEDGER.md).

---

## Verdict

> **EOS gate: PASS** for all locally-verifiable QW1 work. The wave is **CONDITIONAL at the
> program level** pending 5 genuinely infrastructure-dependent P0 rows, each tracked to a
> named CI lane. **No locally-fixable P0/P1 remains open.**

**QW1 row status (53-row wave): 44 Verified · 5 Open (all INFRA-BLOCKED) · 1 Passing · 3 Test-Written.**

---

## What this closeout added (2026-06-28)

This session closed the **last locally-verifiable P0 rows** and reconciled tracker drift.
Everything below is additive; `flutter analyze` is clean; no regressions.

### 1. ChainScope POSITIVE — QA-J-048 (the originally-requested item)
- **`QaLoginPersona.chainDirector`** — director scope + the 4 chain perms
  (`viewFranchiseOperations`/`viewBranchOperations`/`viewMultiSchoolOperations`/`viewOrganizationBuilder`)
  + `isChainOrganization = true`, threaded persona → `signInQaPersona` → `signInStaff` →
  `AuthClaims.isChainOrganization` → `isChainOrgProvider`.
- **Patrol:** `qw1_rbac_negatives_e2e_test` `qw1-rbac-pos` — chain director reaches
  `/franchise` + `/multi-school/portfolio` + `/organization-builder` (no Access-Denied). Green on emulator.
- **Deterministic:** `qa_login_test.dart` proves the full wiring (chain flag flips
  `isChainOrgProvider` → routes granted; control-center still denied); `qa_persona_permissions_test.dart`
  proves the scoping. Together with the existing negative, the full matrix is proven:
  **single-school denied, chain allowed.**

### 2. Newly-built locally-verifiable P0 rows
| Row | What | Evidence (all green) |
|---|---|---|
| **QA-J-003** | Parent multi-child switch → dashboard reloads | `qw1_parent_child_switch_e2e_test` (Patrol): greeting flips "Ravi's…" → "Priya's Day at a Glance" (proves the dashboard *future* re-keyed, not just the chip) + 2 QA keys added |
| **QA-J-009** | Student cross-shell RBAC isolation | `qw1_student_cross_shell_e2e_test` (Patrol 2/2): student deep-linking `/parent/dashboard` + `/teacher/dashboard` is redirected home to `/student/dashboard` |
| **QA-F-026** | Legal-acceptance screen render + gate | `legal_acceptance_screen_widget_test.dart` (6/6): Accept GATED behind the agree checkbox (disabled→enabled), submitting spinner, loading, review/empty |
| **QA-F-036** | Teacher attendance mark-all gate | `teacher_attendance_submit_gate_test.dart` (3/3): Submit disabled while any student unmarked, enables once all marked, re-disabled after submit |
| **QA-F-038** | Teacher exam marks-entry grid + validation | `teacher_exam_marks_entry_test.dart` (4/4): grid renders editable field per student, out-of-range + non-numeric rejected, valid accepted (persistence proven by QA-J-014) |
| **QA-B-014** | `POST /finance/collections` route contract | `finance_collections_route_contract_test.ts` (5/5): 403 FORBIDDEN for non-finance, passes gate WITH `manageFinance`, 422 on bad body, 401 unauth (persist+receipt via repo test; **cross-tenant RLS leg → live-Postgres batch**) |
| **QA-B-066** | Per-route 403 FORBIDDEN envelope | `rbac_route_403_envelope_test.ts` (2/2): every permissioned route's deny branch returns `{data:null, error.code:"FORBIDDEN", message names the perm}` at 403; holder not denied |

### 3. Tracker-lag reconciliation (already certified — flipped to Verified)
These rows were **already covered by passing tests** but never flipped:
- **QA-F-001 / QA-F-002** — `auth_screens_widget_test.dart` (`QA-F-001 · OtpVerificationScreen`,
  `QA-F-002 · LoginScreen`); inside the QA-F widget-surfaces EOS PASS.
- **QA-X-001 / QA-X-002 / QA-X-006** — Phase 0b Data Reliability Platform:
  `airplane_mode_attendance_test`, `airplane_mode_fee_test`, `mutation_gateway_test`
  (Phase 0b CLOSED + live-cert + EOS PASS).

---

## Evidence base (this closeout)

- **`flutter analyze`:** 0 issues across all changed lib/test/patrol files.
- **Flutter tests:** new widget tests 13/13 (legal 6 · attendance 3 · marks 4) + auth/parent/config
  regressions green (136 in the final consolidated run; 175 auth+security+config and 153 router+RBAC
  earlier — no regressions from the new persona / chip QA keys).
- **Deno tests:** 10/10 (finance route contract 5 · 403 envelope 2 · full RBAC matrix 3).
- **Patrol on emulator (Medium_Phone_API_36):** RBAC negatives+positive 4/4 · journeys 3/3 — **Failed: 0**.

---

## Remaining QW1 rows — genuinely infrastructure-dependent (NOT locally fixable)

These are correctly left **Open** with explicit reasons; each maps to a named CI lane.

| Row(s) | Why blocked | Lane |
|---|---|---|
| **QA-B-051 / QA-B-052 / QA-B-057** (+ QA-B-014 isolation leg) | RLS cross-tenant rolled-back-txn probe needs a **live tenant Postgres** (`ERP_TENANT_DATABASE_URL` with RLS) — not runnable from the dev env | live-regression DB cron |
| **QA-X-010 / QA-X-012** | FCM token register/refresh + push-tap deep-link need **FCM + Google Play services on a device** — not exercisable headlessly | device/FCM CI lane |
| **QA-X-035 (Passing) · QA-X-036 / QA-X-039 / QA-B-073 (Test-Written)** | CI workflows authored + YAML-valid; flip to Verified on **first scheduled run** | nightly/cron CI (VPS) |

---

## Bottom line

Every QW1 row that can be proven on local hardware (emulator + `flutter test` + `deno test`) is
**Verified**. The only rows still open require a live multi-tenant Postgres, FCM-on-device, or a
first scheduled CI/cron run — exactly the three environment dependencies expected for this wave.
**QW1's locally-verifiable scope is COMPLETE.**
