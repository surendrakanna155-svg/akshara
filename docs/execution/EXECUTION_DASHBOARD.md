# Akshara ERP — EXECUTION DASHBOARD

**Status:** 🟢 Live operational dashboard · **Created:** 2026-07-04 (post-planning-freeze, post-final-review) · **HEAD at creation:** `68f15cb`
**Role:** the at-a-glance state of execution. **Consult this file + [`../roadmap/NEXT_ACTIVE_WAVE.md`](../roadmap/NEXT_ACTIVE_WAVE.md) before every autonomous wave.** This dashboard **summarizes** the roadmap — it defines nothing. Authority order: [`../roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md`](../roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md) (what) → [`../roadmap/AUTONOMOUS_EXECUTION_PLAN.md`](../roadmap/AUTONOMOUS_EXECUTION_PLAN.md) (how) → `NEXT_ACTIVE_WAVE.md` (now) → this file (state summary) → [`IMPLEMENTATION_PROGRESS.md`](IMPLEMENTATION_PROGRESS.md) (permanent journal).
**Maintenance rule:** the executor refreshes this dashboard at **every wave boundary** (same moment `NEXT_ACTIVE_WAVE.md` is rewritten). It must always agree with the journal and the roadmap §0 dashboard — disagreement = drift = halt and reconcile (Autonomous Plan §9). If any conflict is found, the roadmap wins.

---

## 1. Where we are

| Field | Value |
|---|---|
| **Current Phase** | **P1 — Remaining Backend & Code Fixes** 🟠 (P0 code/security ✅ 14/19; 5 live-lane tasks ⏳ owner-deferred) |
| **Current Wave** | **P1-PROD-1 — C1 · Finance Fee Recovery / Collections CRM (FIN-R1..R5)** — 🔵 next up. **P2-UX-1 ∥-eligible** (disjoint ownership). P1-CODE-4 identity stays 👤-gated. |
| **Wave Status** | **P1-CODE-1 ✅ + P1-CODE-2 ✅ + P1-CODE-3 ✅ + P1-CODE-5 ✅ + P1-PROD-0 ✅** — reliability REL-1..9, backend hardening (ENG-4/5/7/8/9/10, DB-6), HR payroll engine (MOD-2/3), XCT foundations (export pipeline / reminder rail / date pickers) closed. P0: 14/19 ✅; 5 live-lane ⏳ owner-deferred. |
| **Planning** | 🔒 FROZEN 2026-07-04 → **AUTONOMOUS EXECUTION UNDER WAY** (P1 code + PROD waves; live lane deferred) |
| **Last commit-gated wave** | **P1-PROD-0** (`83bc267`) — XCT foundations: shared `buildGridTable` PDF primitive (3 bespoke builders consolidated onto the ONE export pipeline ~15 modules ride); reminder/scheduling rail (`scheduleReminder` + one `runDueReminders` runner; due reminder fires end-to-end into a pending in-app delivery, test-proven); shared read-only `AksharaDateField` picker (HR leave/probation + intelligence). EOS FOUNDATION PASS, suite 3611 pass (0 new fails) |

## 2. Wave arithmetic

Waves as the roadmap + Autonomous Plan group them (a "wave" = one EOS-gated commit unit; P0 groups its 19 tasks into 3 waves per `NEXT_ACTIVE_WAVE.md`; P5 is variable by Red-Team findings).

| Phase | Wave units | Detail |
|---|---:|---|
| P0 | 3 | W1 Documentation Truth · W2 Safety Fixes (SEC ∥ INFRA ∥ CODE) · W3 Live Proof/CI (19 tasks total; P0-DOC-3 already ✅ in planning) |
| P1 | 35 | 13 base tasks (CODE-1..8, PROD-0, SEC-1, TEST-1/2, INFRA-1⏸) + 22 PROD waves (C1–C21 + P1-PROD-22 staff-attendance GA track) |
| P2 | 5 | P2-UX-1 → 2 → 3 → 4 → 5 |
| P3 | 15 | W1.1–W1.5 (P3-AI-1) + W2.0–W2.9 (P3-AI-2, 👤 timing) |
| P4 | 2 | P4-RT-0 prep · P4-RT-1 12-domain assault |
| P5 | 1 (var) | P5-FIX-1 — expands per confirmed finding |
| P6 | 1 | P6-PILOT-1 (single + 3-school concurrent, stages 0–16) |
| P7 | 1 | P7-CERT-1 (gates T/S/O/U/A/P/B/D + `QA-R-012`) |
| P8 | 5 | P8-GA-1..5 |
| **Total** | **≈68** | **Completed: P0·W1 + W2 non-blocked legs (14/19 P0) + P1-CODE-1 (REL-1..5) + P1-CODE-2 (REL-6..9) + P1-CODE-3 (ENG-4/5/7/8/9/10,DB-6) + P1-CODE-5 (MOD-2/3) + P1-PROD-0 (XCT-1/2/3), 2026-07-04** · **Remaining:** P0 live-lane tail (INFRA-1/3, TEST-1/2/3) then ≈61 (P5 variable) |

## 3. Current Blockers

| # | Blocker | Blocks | Owner action needed |
|---|---|---|---|
| 1 | ~~Owner approval to begin implementation~~ | ~~everything~~ | ✅ **RESOLVED 2026-07-04** — execution approved; W1 done |
| 2 | **Live-lane access** — VPS SSH socket, tenant Postgres, CI runner on the branch | P0-INFRA-1..6, P0-TEST-1..3 (and the 7-day cron clock → P7) | **Now needed for P0 · W2 (INFRA legs).** SEC + CODE legs of W2 proceed without it. |
| 3 | No other blockers for W2's SEC/CODE legs | — | — |

## 4. Current Owner Decisions (👤 — batched; each gates only its own task, never the pipeline)

From the roadmap's Deferred/Owner register (+ ledger §C):

| Decision | Gates |
|---|---|
| ~~Hide-list for backend-less/thin surfaces~~ | P0-CODE-2 — ✅ **RESOLVED 2026-07-04: hide all 8** |
| ~~DR RPO acceptance (WAL ≤15 min vs ~24h pilot)~~ | P0-INFRA-2 — ✅ **RESOLVED 2026-07-04: accept ~24h nightly** |
| Module scope: Finance-posting (MOD-1) / Hostel / Alumni | P1-CODE-6 / 7 / 8 (MOD-1 also gates the P3 recovery-CRM scope) |
| PLAT-0 non-student Public-ID scheme | P1-CODE-4 (partial) |
| **Appendix A ~26 behaviour/policy items** (frozen backlog) | P1-PROD module waves |
| Adaptive-AI W2 timing | P3-AI-2 |
| Consolidation wave (DOC-8, 14 overlapping surfaces) | P8-GA-5 |
| `APP_ENV=staging` intent on the live pilot backend (LV-5) | P0-INFRA / pilot |
| Shared-box strategy (LV-4/OPS-4) | P1-INFRA-1 / scale |
| UX candidate batch (Product Excellence Master Plan §6: B5 premium wave, Approvals-Inbox read-model, exam-workspace slice, C1/C3/C5/C6, PAR-D4, Student/HR AI) | P2 sub-items / P3-AI-2 extensions |
| Peer-benchmark consent (N7) | W3 / post-GA |

**Rule:** surface these in batches at natural boundaries; a 👤 task pauses, its siblings proceed.

## 5. Next 10 Waves (execution order per the Autonomous Plan; ∥ = parallel-eligible under disjoint file ownership)

| # | Wave | Scope | Hard dependency |
|---|---|---|---|
| 1 | **P0 · W1 — Documentation Truth** | P0-DOC-1/2/4/5 (ProjectStatus, cleanup commit, evidence-grade tracker, stale docs + runbook) | none |
| 2 | **P0 · W2 — Safety Fixes** | P0-SEC-1/2/3 ∥ P0-INFRA-1..6 ∥ P0-CODE-1 (money row_version) + P0-CODE-2 (👤 hide-list) | W1 done; live lane for INFRA |
| 3 | **P0 · W3 — Live Proof / CI** | P0-TEST-1 → P0-TEST-2/3 (CI green, isolation suite in CI, **7-day cron clock starts**) | W2 done |
| 4 | **P1-CODE-1** — Reliability finish | idempotency-all-mutations, marks via ReliableWriter, drafts, boot-flush, first-write row_version | P0 exit |
| 5 | **P1-CODE-3** — Backend hardening ∥ | error-leak (154 sites), bulk caps, error codes, route lint, audit retention | P0 exit |
| 6 | **P1-CODE-4** — Identity finish ∥ | change-phone (PLAT-4), ledger triggers, integrity, SECURITY DEFINER authz | P0 exit; 👤 PLAT-0 partial |
| 7 | **P1-CODE-5** — HR payroll engine ∥ | salary structure + run generation, un-hide payroll, employeeId fix | P0 exit |
| 8 | **P1-PROD-0** — XCT foundations (C0) | XCT-1 export pipeline · XCT-2 reminder/scheduling rail · XCT-3 date pickers | P0 exit — unblocks all C-waves + P3 W1.4 |
| 9 | **P1-CODE-2** — Reliability polish | transactional dequeue, TTL, telemetry, ordering | P1-CODE-1 |
| 10 | **P1-PROD-1 (C1)** — Finance Recovery CRM (FIN-R1..R5) · with **P2-UX-1** (feel & trust pack) eligible to start ∥ once P0 exits | C-wave table (`FINAL_QA_ROADMAP.md` §Phase C) | P1-PROD-0 |

*(P1-SEC-1 and P1-TEST-1 run continuously through P1; P1-PROD-22 staff-attendance GA track schedules with the PROD waves — it must land before P6 Stage 12.)*

## 6. Estimated Completion Order (macro)

```
P0 (fully, 3 waves)
  → P1 (module waves ∥ by ownership) ∥ P2 (UX-1→5; UX-2 needs P1-CODE-1) ∥ P3-W1 (AI foundation)
    → P3-W2 (adaptive, 👤 timing; needs XCT-2/HWK-1/FIN-6/TRN-2/COM-1/MOD-1👤/P2-hub as pulled)
      → P4 (Red Team prep → 12-domain assault)
        → P5 (fix every P0/blocking-P1, live re-verify)
          → P6 (Pilot sim, stages 0–16, single + 3-school; needs P3-AI-1) → PILOT-READY
            → P7 (Production Certification: gates T/S/O/U/A/P/B/D + QA-R-012 + 7-day cron green)
              → P8 (go/no-go → launch → GA DECLARED → post-GA handoff)
```
Hard gates: P0 gates P4/P6/P7/P8 · P1-CODE-1 → P2-UX-2 · P3-AI-1 → P3-AI-2 **and P6** · 7-day clock → P7 · P4→P5→P6→P7→P8 strictly sequential.

## 7. Progress Tracking Table (mirror of journal §2 — the two must agree)

| Phase | Wave units | ✅ Done | 🔵 In progress | ⚪ Pending | Gate |
|---|---:|---:|---:|---:|---|
| Planning | — | 🔒 FROZEN + reviewed | — | — | audit + final review |
| P0 — Truth/Docs/Live-Verify | 3 (19 tasks; **14 ✅**) | **2** (W1 ✅ · W2 non-blocked legs ✅) | 0 | 1 (W3 + INFRA-1/3 — ⏳ live-lane) | EOS per task |
| P1 — Backend & Code Fixes | 35 | 5 (CODE-1/2/3/5, PROD-0) | 0 | 30 (next: PROD-1 · C1; CODE-4 👤) | EOS per wave |
| P2 — UI/UX | 5 | 0 | 0 | 5 | EOS UX per wave |
| P3 — Adaptive AI | 15 sub-waves | 0 | 0 | 15 | EOS AI per sub-wave |
| P4 — Red Team | 2 | 0 | 0 | 2 | RED-TEAM verdict |
| P5 — Red Team Fixes | 1 (var) | 0 | 0 | 1 | EOS per fix |
| P6 — Pilot Simulation | 1 | 0 | 0 | 1 | QA-R-001/002 live |
| P7 — Production Cert | 1 | 0 | 0 | 1 | QA-R-012 |
| P8 — GA | 5 | 0 | 0 | 5 | RELEASE |
| **Total** | **≈68** | **1** | **0** | **≈67** | — |

## 8. EOS Status

- **Gate protocol:** every wave ends with `/eos <scope>`; **commit only on PASS**; CONDITIONAL PASS only with P1s tracked *and* roadmap permission; BLOCKED = fix and re-run, never advance. Verdicts append to `docs/engineering/eos/EOS_RUN_LEDGER.md` + the journal.
- **Implementation EOS runs so far:** **13** — P0·W1 DOCS PASS · P0·W2 legs (SEC-1/2/3, CODE-1/2, INFRA-4/5/6) PASS · P1-CODE-1 RELIABILITY PASS · P1-CODE-2 RELIABILITY PASS · P1-CODE-3 SECURITY+ARCH PASS · P1-CODE-5 FEATURE PASS · **P1-PROD-0 FOUNDATION PASS (2026-07-04, latest)**. See `docs/engineering/eos/EOS_RUN_LEDGER.md`.
- **Open P0 findings:** none known at baseline (audit P0s are scheduled tasks, not open gate failures).
- **Automatic-failure tripwires** (instant BLOCKED): data loss · security breach · escalation · tenant-isolation failure · critical crash · duplicate financial transaction · broken auth/sync · critical regression · failed backup verification · production blocker.
- **Pre-execution baseline (verified live 2026-07-03, do NOT redo):** RLS isolation PASS · edge = `erp_tenant` NOBYPASSRLS · entitlement ON · encrypted backups + monthly restore drill green · watchdog green · AI live via OpenRouter · live DB password rotated · `flutter analyze` 0.

## 9. Current Risks (accepted, tracked — from the final review §6)

1. **Live lane is the long pole** — owner-provisioned VPS/SSH/tenant-DB/CI gates all LIVE-graded evidence; the 7-day cron clock (P7 prerequisite) starts only when P0-TEST-3 runs for real.
2. **Owner-decision latency** — ~26 Appendix-A items + hide-list + module scope + W2 timing progressively narrow the executor's runway if left undecided.
3. **P1-PROD breadth** — 22 waves / ~90 items is the largest phase; schedule variance concentrates here (bounded by per-wave EOS + the C-table criteria).
4. **Red-Team outcome open by design** — P5 is variable; a bad verdict re-opens earlier phases.
5. **Executor discipline** — the system is self-verifying only if the wave loop is followed every session; owner should spot-check journal ↔ commits periodically.

## 10. Current Focus

> **P1 lane through P1-PROD-0 ✅ (2026-07-04).** Done since planning freeze: P0·W1 docs truth + W2 non-blocked legs (14/19 P0) · P1-CODE-1/2 (reliability platform REL-1..9) · P1-CODE-3 (backend hardening ENG-4/5/7/8/9/10 + DB-6) · P1-CODE-5 (HR payroll engine MOD-2/3) · **P1-PROD-0 (XCT foundations `83bc267`: XCT-1 shared `buildGridTable` PDF primitive — 3 bespoke tabular-PDF builders consolidated onto the ONE export pipeline ~15 modules ride; XCT-2 reminder/scheduling rail `_shared/reminders` — `scheduleReminder` + one `runDueReminders` runner, a due reminder fires end-to-end into a pending in-app delivery, test-proven; XCT-3 shared read-only `AksharaDateField` picker across HR leave/probation + intelligence).** analyze 0 · suite 3611 pass (2 known UX-7 → P2-UX) · deno touched 108/1-known-ISO-COUNT.
>
> **▶ NEXT: P1-PROD-1 (C1 — Finance Fee Recovery / Collections CRM, FIN-R1..R5)** — discovery-first (a `finance_recovery_crm` migration + actions already exist; verify/expand, don't duplicate). **P2-UX-1 ∥-eligible** under disjoint ownership. Still owner-gated: the identity-decision batch (P1-CODE-4), module-scope 👤s (P1-CODE-6/7/8), and the live lane (`P0-INFRA-1/3`, `P0-TEST-1/2/3` — VPS SSH + tenant Postgres + branch CI; the 7-day cron clock → P7 starts only when P0-TEST-3 runs for real).

---

*Summary only — this file adds no tasks, changes no scope, and yields to the roadmap on any conflict. One wave, one EOS gate, one commit, one journal row — repeated until GA.*
