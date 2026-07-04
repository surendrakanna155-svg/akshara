# Akshara ERP — Autonomous Execution Plan

**Status:** 🟢 Authoritative execution protocol · **Program Manager:** Fable (CPM) · **Date:** 2026-07-03
**Governs execution of:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) (the only roadmap).
**Journal:** [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md).
**Executor:** Opus 4.8 (a later session). **This document is the plan; it performs no work itself.**

> **Prime directive.** The roadmap advances **one wave at a time**. A wave is not "done" until `/eos`
> returns **PASS** for its scope. **No phase continues while any P0 is open or the EOS gate is BLOCKED.**
> Every completed wave automatically updates progress, updates docs, runs EOS, fixes findings, and
> commits only after PASS.

---

## 1. The universal wave loop (applies to every task/wave)

```
 for each wave W in the current phase (respecting dependencies):
   1. PLAN     — restate W's scope, finding refs, evidence-required, EOS gate, done-when
   2. IMPLEMENT — smallest correct change; reuse existing abstractions; disjoint file ownership
   3. VALIDATE — flutter analyze (0) · flutter test (green) · deno test (green) · new tests for W
   4. REGRESSION — run the affected suites + coverage floor; no drop
   5. DOCUMENT — update the module/architecture doc + inline docs the change touches
   6. EOS      — run `/eos <W scope>`
   7. GATE:
        if EOS = PASS            → go to step 8
        if EOS = CONDITIONAL     → record P1s tracked; proceed only if roadmap allows, else fix first
        if EOS = BLOCKED         → FIX every finding, return to step 3 (do NOT proceed, do NOT commit)
   8. ROADMAP  — flip W's status in FINAL_EXECUTION_MASTER_ROADMAP.md (⚪→🔵→✅) + progress dashboard
   9. PROGRESS — append a row to IMPLEMENTATION_PROGRESS.md (date, commit, phase, files, EOS, evidence, finding, roadmap-id)
  10. COMMIT   — commit ONLY after EOS PASS (message references W id + finding + EOS verdict)
```

**Hard rule:** steps 7→10 are inviolable — **commit only after EOS PASS**, and **never start the next wave with an open P0.**

---

## 2. Per-phase execution definition

For each phase: **execution order · validation · EOS verification · documentation · roadmap · regression · commit.** (Live-infrastructure steps in P0/P6/P7/P8 are executed by the designated later session with the appropriate tooling; this plan defines *what* and *in what order*, not a live action taken now.)

### Phase 0 — Truth · Documentation · Live Verification 🔴
- **Order:** DOC tasks (P0-DOC-1/2/4/5) → SEC tasks (P0-SEC-1/2/3) ∥ INFRA tasks (P0-INFRA-1..6) ∥ CODE (P0-CODE-1/2) → TEST (P0-TEST-1 → 2/3). DOC-3 already ✅.
- **Validation:** docs reconcile against code; release-build fail-closed test; money-concurrency test (P0-CODE-1); CI green (P0-TEST-1).
- **EOS:** DOCS · SECURITY · OPS · RELIABILITY · CI scopes each PASS.
- **Documentation:** ProjectStatus, tracker (evidence-grade), TD-P0-01, AuditArchitecture, backup runbook.
- **Regression:** full analyze+test suites via the new CI (P0-TEST-1).
- **Commit:** per task after PASS.
- **Gate to Phase 1:** all P0 tasks ✅ or explicitly owner-deferred; CI green; isolation suite in CI; cron clock started.

### Phase 1 — Remaining Backend & Code Fixes 🟠
- **Order:** P1-CODE-1 (reliability) → P1-CODE-3 (backend hardening) ∥ P1-CODE-4 (identity) ∥ P1-CODE-5 (HR); P1-PROD-0 (XCT) → P1-PROD-1..21 by dependency; P1-SEC-1; P1-TEST-1 continuous; P1-CODE-6/7/8 after owner scope; P1-TEST-2, P1-INFRA-1 as scheduled.
- **Parallelism:** by module with **disjoint file ownership** (owner rule: never two implementation streams on the same module; read-only analysis may parallelize).
- **Validation:** per-wave unit/widget/contract/integration tests; persistence asserted under the correct persona.
- **EOS:** FEATURE / RELIABILITY / SECURITY / ARCHITECTURE per wave.
- **Documentation:** module spec + `RouteInventory`/`PermissionCoverageInventory` refresh where routes change.
- **Regression:** full suites + coverage floor per wave.
- **Commit:** per wave after PASS.

### Phase 2 — UI/UX 🟠
- **Order:** P2-UX-1 (feedback pack) → P2-UX-2 (daily-task ergonomics; needs P1-CODE-1 for marks) → P2-UX-3 (DS enforcement) → P2-UX-4 (a11y) → P2-UX-5 (dark theme).
- **Validation:** widget/golden tests; DS lint; contrast + a11y checks in CI; rubric re-score.
- **EOS:** UX (+ CI for lint/contrast) per wave. **Docs:** FlutterDesignSystem / VISUAL_DESIGN_SYSTEM deltas. **Regression:** golden baselines. **Commit:** per wave after PASS.

### Phase 3 — Adaptive AI 🟡  (execute from `docs/design/adaptive-ai/` — doc 09 is the wave contract)
- **Order:** **P3-AI-1 = W1 FIRST** — W1.1 gateway hardening → W1.2 memory+cache → W1.3 context engine → W1.4 Signal Refinery → W1.5 fingerprint cache + cost panel. Then **P3-AI-2 = W2** (👤 owner timing) — W2.0 engines → W2.1 brief/digest → personas W2.2 Teacher → W2.3 Parent → W2.4 Principal → W2.5 Director → W2.6 Student → W2.7 ops worklists → W2.8 pgvector → W2.9 truth-in-naming. Each sub-wave = one EOS-AI-gated commit.
- **Cross-phase deps (verify before the sub-wave):** W1.4 needs XCT-2 (P1-PROD-0); homework/fee/transport intelligence needs HWK-1/FIN-6/TRN-2 (P1 backlog); recovery CRM needs MOD-1 (👤); delivery-timing needs COM-1; W2.4 needs the P2 Principal-hub consolidation; live T3 needs the P0 live-AI-key.
- **Validation (standing AI test assets, run every AI wave):** injection corpus; determinism validator (T3 numbers == injected facts); `ai_*` isolation probes (extend the 233-probe suite); cost-regression (no surface below its tier); fallback drills (no-key/timeout/over-cap/over-rate). **Metrics gate:** ≥90% zero-model-call impressions (per-persona targets), cache-hit ratios, spend ≤ cap, latency, ≥3 learned-threshold divergences per school.
- **EOS:** AI per sub-wave (W1 exit gate + W2 exit gate per doc 09). **Docs:** mark the suite's wave "implemented"; blueprint section status. **Regression:** AI suites + cost logging. **Commit:** per sub-wave after PASS.

### Phase 4 — Global Red Team Prep 🔴
- **Order:** P4-RT-0 (prepare: freeze honest claims, seed attacks, ready fixtures) → P4-RT-1 (execute 12 domains, adversarially verify, loop-until-dry).
- **Validation:** every finding independently reproduced/refuted. **EOS:** RED-TEAM verdict. **Docs:** Red-Team report per `GLOBAL_RED_TEAM_FRAMEWORK.md` templates. **Commit:** report artifacts (no product code in P4).

### Phase 5 — Red Team Fixes 🔴
- **Order:** by severity (P0 first). **Validation:** each fix re-verified against its reproduction; affected EOS category re-run.
- **EOS:** per fix + overall RED-TEAM flips to PASS. **Docs:** finding→fix mapping. **Regression:** full suites. **Commit:** per fix after PASS. **Gate:** no open P0/blocking-P1 → Phase 6.

### Phase 6 — Pilot Simulation 🔴
- **Order:** single-school full-year → 3-school concurrent (per `PILOT_SCHOOL_SIMULATION_MASTER.md` stages 0–16).
- **Validation:** unattended; per-stage machine-readable artifacts committed. **EOS:** `QA-R-001/002` live. **Docs:** pilot results + ProjectStatus. **Commit:** artifacts. **Gate:** §4 success criteria all green → **PILOT-READY**.

### Phase 7 — Production Certification 🔴
- **Order:** gather evidence per GA gate (T/S/O/U/A/P/B/D) → `/eos <gate>` each → independent sign-off → Final Checklist.
- **Validation:** evidence-grade rule (LIVE for Critical gates). **EOS:** `QA-R-012`. **Docs:** certification bundle. **Gate:** all gates PASS → production-certified.

### Phase 8 — GA Readiness & Launch 🔴
- **Order:** P8-GA-1 (go/no-go) → P8-GA-3 (launch) → P8-GA-4 (declare GA) ; P8-GA-2 (commercial pack) as owner-timed; P8-GA-5 (post-GA forward plan handoff).
- **Validation:** no open P0/blocking-P1 project-wide; prod health + rollback proven. **EOS:** RELEASE. **Docs:** ProjectStatus + release notes + roadmap progress → 100%. **Commit:** release tag per governance. **Gate:** **GA DECLARED.**

---

## 3. EOS verification standard (every wave)

- Run `/eos <scope>` scoped to the wave (Part 8 — Release Decision; Part 7B — Certification Categories).
- **PASS** → proceed + commit. **CONDITIONAL PASS** → allowed only if the named P1s are tracked into a later wave *and* the roadmap permits; otherwise treat as fix-first. **BLOCKED** (any open P0 or automatic-failure condition) → **stop, fix, re-run**; never commit, never advance.
- Append the EOS verdict to `docs/engineering/eos/EOS_RUN_LEDGER.md` and to the progress journal.
- **Automatic-failure conditions** (instant BLOCKED): data loss · security breach · permission escalation · tenant-isolation failure · critical crash · duplicate financial transaction · broken auth/sync · critical regression · missing/failed backup verification · production blocker.

---

## 4. Documentation & roadmap auto-update (every completed wave)

1. **Roadmap progress:** flip the wave's Status in `FINAL_EXECUTION_MASTER_ROADMAP.md` (⚪→🔵→✅) and update the §0 progress dashboard.
2. **Implementation progress:** append a journal row (§ below) in `IMPLEMENTATION_PROGRESS.md`.
3. **Documentation:** update the touched module/architecture/design docs; refresh inventories on route/permission changes; mark the relevant strategy-doc section "implemented."
4. **EOS ledger:** one line per wave (date · scope · verdict · open P0/P1 · report path).
5. **Findings ledger:** flip the mapped finding to Fixed/Verified.

---

## 5. Regression policy

- Every wave runs: `flutter analyze` (0) · `flutter test` (green, no count drop) · backend `deno test` (green) · coverage floor (no drop) · the affected golden/contract/route suites.
- Post-Phase-0, CI runs these on every push/PR (P0-TEST-1); the live-regression cron runs nightly (P0-TEST-3).
- A regression that drops test count or coverage, or reddens CI, is a **BLOCKED** condition — fix before proceeding.

---

## 6. Commit strategy

- **Commit only after EOS PASS** for the wave. Never commit on BLOCKED.
- **Branching:** work on `feature/*` per wave/module; open a PR so CI gates run; merge on green + EOS PASS. Never force-push shared branches.
- **Message format:** `feat|fix|docs(<module>): <wave-id> — <summary> · closes <finding-id> · EOS PASS`. End with the project's `Co-Authored-By` trailer.
- **One logical wave per commit/PR** where practical; disjoint file ownership avoids cross-wave conflicts.
- **Tag** only at Phase 8 GA per `ReleaseGovernance.md`.

---

## 7. Parallelization & ownership rules

- **Read-only analysis** may parallelize freely. **Implementation streams must own disjoint files/modules** — never two on the same module at once; sequence when they share files (owner rule).
- Phases 4→5→6→7→8 are **strictly sequential gates** (no parallelism across them).
- Within Phase 1, module waves parallelize by ownership; within Phase 2/3, waves are mostly ordered by dependency.

---

## 8. Stop / escalate conditions

- **Owner-decision gate reached** (👤 in the roadmap) → pause that task, surface the decision in a batch, continue other non-blocked waves. Never guess a frozen-scope decision.
- **EOS BLOCKED and un-fixable within scope** → stop the phase, report the blocker.
- **Automatic-failure condition discovered** → stop, treat as P0, fix before anything else.
- **Ambiguous product behaviour** → STOP and ask (standing owner rule), don't invent behaviour.

---

## 9. Definition of "the roadmap is being followed"

At any point, an observer can verify: the progress dashboard matches the journal; every ✅ wave has an EOS-PASS ledger row + a commit; no phase advanced with an open P0; every finding's status in the ledger matches its wave's status; no parallel roadmap exists. If any of these is false, execution has drifted — halt and reconcile.

*This plan makes execution deterministic and self-verifying: one wave, one EOS gate, one commit, one journal row — repeated until GA.*
