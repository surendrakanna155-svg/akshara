# Akshara ERP — EXECUTION DASHBOARD

**Status:** 🟢 Live operational dashboard · **Created:** 2026-07-04 (post-planning-freeze) · **Reconciled:** 🔄 **RECON-1, 2026-07-10** (tip `7224782d`)
**Role:** the at-a-glance state of execution. **Consult this file + [`../roadmap/NEXT_ACTIVE_WAVE.md`](../roadmap/NEXT_ACTIVE_WAVE.md) before every autonomous wave.** This dashboard **summarizes** the roadmap — it defines nothing. Authority order: [`../roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md`](../roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md) (what) → [`../roadmap/AUTONOMOUS_EXECUTION_PLAN.md`](../roadmap/AUTONOMOUS_EXECUTION_PLAN.md) (how) → `NEXT_ACTIVE_WAVE.md` (now) → this file (state summary) → [`IMPLEMENTATION_PROGRESS.md`](IMPLEMENTATION_PROGRESS.md) (permanent journal).
**Maintenance rule:** the executor refreshes this dashboard at **every wave boundary** (same moment `NEXT_ACTIVE_WAVE.md` is rewritten). It must always agree with the journal and the roadmap §0/§0b — disagreement = drift = halt and reconcile (Autonomous Plan §9). If any conflict is found, the roadmap wins.
**Progress law:** every % on this dashboard is **derived from the roadmap §0b Wave Ledger** (✅=1.0 · 🔶=0.5 · else 0) — never hand-estimated.

---

## 1. Where we are  (states: ✅ Complete · 🔶 Impl-Complete/Hardening · 🟩 Production-Certified · 👤 Owner-Gated · 🔮 Future)

| Field | Value |
|---|---|
| **Derived progress** | **53.5%** (45.5 / 85 wave units — roadmap §0b; denominator grew by 2 at the PRC integration, 2026-07-11) |
| **Current Phase** | **Twin hardening programs (post-RECON-1):** **P3-AI-3** W2 Hardening & Closure 🔶 ∥ **K-2** QP Engine Hardening 🔶 — plus **P1-PROD-22 Face ID** (Must-Before-GA, open now) and **P0-LIVE-1** (owner-provisioned live checklist). Then **PRC-A → PRC-B (Product Reality & Correctness Certification — auto-begins at P3 exit + EOS)** → CFC-1 → FREEZE-1 → P4. |
| **Completed** | RECON-1 ✅ · P0 W1+W2 (14/19 tasks; live legs ⑪⑫⑬ verified 2026-07-09) · P1 non-gated lane ✅ (CODE-1/2/3/5 · PROD-0 · C1–C21 · CI-0 · **GS-1..3 gap-sweeps**) · **P2 ✅ (UX-1..5)** · **P3-AI-1 ✅ CERTIFIED** (cert v2, 2026-07-10) · **K-1 KIE ✅ (local: Phases 1–7 + 360-corpus cert + Intake Center)** · acquisition engine ✅ (Coverage Matrix = SSOT, 14.1%) |
| **🔶 Hardening (NOT complete, NOT production-ready)** | **P3-AI-2 (W2):** engines/gates/search/quotas/client/persona-feeds built; audit loop OPEN (P0-1/P1-1/P1-2 fixed; more rounds required; W2.1/2.7/2.8/2.9 open; migrations `20260867`+ **not deployed**). **K-2 (QP engine):** Q1–Q8 + R1–R9 + prod-readiness GO (scoped); template/blueprint/OCR/validation program continues; exit = 2 consecutive clean audits. |
| **🟩 Production-certified (interim, task-scope)** | live RLS isolation (233/233 zero-leak) · nightly backup (restorable) · `finance_fee_reductions` live cert. *Phase-wide 🟩 is granted only by P7.* |
| **👤 / ⏳ open** | P0-LIVE-1 provisioning (R2 creds · cron token · CI runner · **7-day clock**) · P1-CODE-4/6/7/8 · FREEZE-1 K-lane carve-out · P6-BETA-1 cohort · K-3 promotion · PAR3-UPLOAD · PRI-4/5 · HWK-1/C6 · A2 ratification |
| **Planning** | 🔒 FROZEN 2026-07-04 → **RECONCILED at RECON-1 (2026-07-10)** — structure unchanged; additions: LIVE-1 · GS record · AI-3 · K-lane · CFC/FREEZE · VAL/BETA · Wave Ledger |
| **Last commit-gated wave** | **RECON-1 (2026-07-10)** — reconciliation, tracking-only, EOS DOCS PASS. Last substantive: W2 audit-round fixes `7224782d` (🔶 open) · QP Phase-1 hardening `835f39e4` (🔶 open) · W1 cert `56f780a1` ✅. |

## 2. Wave arithmetic  (= roadmap §0b Wave Ledger — the single source for every %)

| Lane | Units | ✅ | 🔶 | Credit |
|---|---:|---:|---:|---:|
| Gates (RECON-1 ✅ · CFC-1 · FREEZE-1) | 3 | 1 | 0 | 1.0 |
| P0 (W1 ✅ · W2 ✅ · LIVE-1) | 3 | 2 | 0 | 2.0 |
| P1 (13 base + 22 PROD + GS-1..3) | 38 | 27 | 0 | 27.0 |
| P2 (UX-1..5) | 5 | 5 | 0 | 5.0 |
| P3 (W1.1–1.5 ✅ · W2.0/GATE/S + W2.2–2.6 🔶 · W2.1/2.7/2.8/2.9 + AI-3 ⚪) | 18 | 5 | 8 | 9.0 |
| K (K-1 ✅ · K-2 🔶 · K-3 👤 · K-4 ⚪) | 4 | 1 | 1 | 1.5 |
| PRC (PRC-A · PRC-B — Product Reality & Correctness, added 2026-07-11) | 2 | 0 | 0 | 0 |
| P4 (RT-0 · RT-1) | 2 | 0 | 0 | 0 |
| P5 (FIX-1, variable) | 1 | 0 | 0 | 0 |
| P6 (VAL-1 · PILOT-1 · BETA-1) | 3 | 0 | 0 | 0 |
| P7 (CERT-1) | 1 | 0 | 0 | 0 |
| P8 (GA-1..5) | 5 | 0 | 0 | 0 |
| **Total** | **85** | **41** | **9** | **45.5 → 53.5%** |

## 3. Current Blockers

| # | Blocker | Blocks | Owner action needed |
|---|---|---|---|
| 1 | **P0-LIVE-1 provisioning** — R2 creds, `INTERNAL_CRON_TOKEN`, CI runner | off-site backup · crons · CI · isolation-in-CI · **7-day clock (gates P7 — calendar-critical)** | Provide creds/token/runner; the deploy pipeline itself is proven (2026-07-09) |
| 2 | **W2 flag/migration sequencing** — release config enables W2 (`ce1e886f`) but migrations `20260867`+/`20260873` are NOT deployed | any live build with W2 on | Deploy LIVE-1 ① before any release build ships (guarded at CFC-1 item 5) |
| 3 | **Owner decisions batch** (see §4) | P1-CODE-4/6/7/8 · FREEZE-1 entry · BETA cohort | Decide in batch at the next boundary |
| 4 | In-flight uncommitted work — `priority_engine.ts` (W2 round) · `qpgen/templates.py` (K-2 round) · acquisition-strategy doc set | CFC-1 item 9 (clean tree) | Lanes land them with their rounds (no action if rounds close normally) |

## 4. Current Owner Decisions (👤 — batched; each gates only its own task, never the pipeline)

| Decision | Gates |
|---|---|
| P0-LIVE-1 provisioning (creds/token/CI) | LIVE-1 ③⑥⑧⑨⑩ + the 7-day clock |
| FREEZE-1 K-lane carve-out (does K-2 block the ERP freeze?) | FREEZE-1 entry |
| P6-BETA-1 cohort recruitment (5–10 real schools) | P6-BETA-1 |
| K-3 promotion timing (`kie.intake`→Postgres; NOT GA-gating) | K-3 |
| Module scope: Finance-posting (MOD-1) / Hostel / Alumni | P1-CODE-6/7/8 |
| Identity cluster (PLAT-0 · C5/ADM-D3 · IC-1..6 change-phone · SIS-D1 · admissions SoD) | P1-CODE-4 |
| PAR3-UPLOAD (real file bytes vs reference-only) · PRI-4/5 scheduled-send · HWK-1/C6 basis re-check | tracked residuals |
| Appendix A ~26 items · Consolidation DOC-8 · `APP_ENV=staging` (LV-5) · shared-box (LV-4/OPS-4) · A2 ratification | respective waves |

## 5. Next waves (execution order; ∥ = parallel-eligible under disjoint file ownership)

| # | Wave | Scope | Hard dependency |
|---|---|---|---|
| 1 | **P3-AI-3 round 2** ∥ | W2 audit round 2 → fix → regression → re-audit | rounds continue until clean |
| 2 | **K-2 rounds** ∥ | QP hardening (templates · blueprints · OCR · validation) → audits | exit = 2 consecutive clean |
| 3 | **P1-PROD-22** ∥ | Staff Face ID attendance (GA-1/2/3 per frozen design) | must precede P6-PILOT-1 Stage 12 |
| 4 | **P0-LIVE-1** ∥ | 13-item live checklist; ① AI migrations FIRST; ⑩ starts the 7-day clock | 👤 provisioning |
| 5 | **P1 owner-gated tail** | CODE-4/6/7/8 as decisions land; SEC-1; TEST-1/2 | 👤 |
| 6 | **PRC-A** (Wave A — Real School Operations Capability & Cross-Module Gap Audit) | 148 capabilities / 15 domains; 13-step method; classify → fix verified gaps → regression → prove journeys; dependency rule | **auto-begins at P3 exit + EOS** (tracker: `PRODUCT_REALITY_CORRECTNESS_PROGRAM_TRACKER.md`) |
| 7 | **PRC-B** (Wave B — Product Correctness, Invariant & Edge-Case Certification) | derive exhaustive inventory from codebase; 12 invariant categories; fix verified defects; regression | PRC-A exit (regression + EOS) — **never merged with Wave A** |
| 8 | **CFC-1** | 10-item Code Freeze Checklist (evidence per item) | P3-AI-3 + K-2 exits (or carve-out) + **PRC complete** + LIVE-1 ① |
| 9 | **FREEZE-1** | Feature Freeze declared — bug/regression/perf/security/quality/stability only | CFC-1 PASS |
| 10 | **P4-RT-0 → P4-RT-1** | seeds refreshed for post-W2 AI surface; 12 domains; per-subsystem audit→fix→regression→re-audit | FREEZE-1 |
| 11 | **P5-FIX-1** | close every finding; live re-verify; **round law: repeat until audits stop finding meaningful issues** | P4 verdict |
| 12 | **P6-VAL-1 → P6-PILOT-1 → P6-BETA-1** | full E2E validation (rounds) → internal pilot stages 0–16 → 5–10 real beta schools | P5 exit; then P7 → P8 |

## 6. Estimated Completion Order (macro)

```
(P3-AI-3 ∥ K-2 ∥ P1-PROD-22 ∥ P0-LIVE-1 ∥ owner-gated P1 tail)
  → PRC-A (Wave A: real-school ops capability & cross-module gap audit — 148 capabilities, auto-begin at P3 exit + EOS)
   → PRC-B (Wave B: correctness, invariant & edge-case certification — 12 categories from the live codebase)
  → CFC-1 (Code Freeze Checklist: TODO/mocks/stubs/debug/flags/bypasses/migrations/clean-tree/no-P0P1)
    → FREEZE-1 (feature freeze — no new features beyond this point)
      → P4 (Red Team: seeds refreshed → 12-domain assault; per-subsystem audit cycles)
        → P5 (fix every P0/blocking-P1, live re-verify; repeat rounds until dry)
          → P6-VAL-1 (final E2E validation — all personas/journeys/load/stress/recovery/offline/a11y/security; rounds until clean)
            → P6-PILOT-1 (internal pilot, stages 0–16) → PILOT-READY
              → P6-BETA-1 (5–10 REAL schools; feedback → fix → repeat) → BETA PASS
                → P7 (Production Certification: gates T/S/O/U/A/P/B/D + QA-R-012 + 7-day cron green) → 🟩
                  → P8 (go/no-go → launch [VPS/migrations/smoke/monitoring/cron/backup/security/perf/cost/AI-quota/rollback] → GA DECLARED)
```
Hard gates: P0-LIVE-1 gates P7's clock · P3-AI-1 ✅ feeds P6 · **P3 exit (+EOS) auto-starts PRC-A → PRC-B (sequential, never merged; complete before FREEZE-1)** · CFC-1 → FREEZE-1 → P4 · P4→P5→P6-VAL→PILOT→BETA→P7→P8 strictly sequential · PROD-22 before Pilot Stage 12 · K-lane never blocks ERP (K-3 owner-timed, not GA-gating).

## 7. Progress Tracking Table (mirror of journal §2 — the two must agree)

| Phase | Units | ✅ | 🔶 | ⚪/👤 | Gate |
|---|---:|---:|---:|---:|---|
| Gates (RECON/CFC/FREEZE) | 3 | 1 | 0 | 2 | DOCS/RELEASE |
| P0 — Truth/Docs/Live | 3 | 2 | 0 | 1 (LIVE-1) | EOS per task |
| P1 — Backend & Code | 38 | 27 | 0 | 11 | EOS per wave |
| P2 — UI/UX | 5 | 5 | 0 | 0 | ✅ |
| P3 — Adaptive AI | 18 | 5 | 8 | 5 | EOS AI per sub-wave |
| K — Knowledge Lane | 4 | 1 | 1 | 2 | K gates |
| PRC — Product Reality & Correctness | 2 | 0 | 0 | 2 | EOS per wave |
| P4 — Red Team | 2 | 0 | 0 | 2 | verdict |
| P5 — Fixes | 1 | 0 | 0 | 1 | per fix |
| P6 — VAL·Pilot·Beta | 3 | 0 | 0 | 3 | VAL/QA-R/BETA |
| P7 — Production Cert | 1 | 0 | 0 | 1 | QA-R-012 → 🟩 |
| P8 — GA | 5 | 0 | 0 | 5 | RELEASE |
| **Total** | **85** | **41** | **9** | **35** | **45.5 → 53.5%** |

## 8. EOS Status

- **Gate protocol unchanged:** every wave ends with `/eos <scope>`; **commit only on PASS**; CONDITIONAL PASS only with P1s tracked *and* roadmap permission; BLOCKED = fix and re-run, never advance. Verdicts append to `docs/engineering/eos/EOS_RUN_LEDGER.md` + the journal.
- **RECON-1 finding (recorded, not repeated):** waves executed 2026-07-08→10 (W1/W2/KIE/QP/gap-sweeps) ran **outside the recording loop** — reconstructed in the journal's catch-up block. From RECON-1 forward the loop is mandatory again: one wave, one EOS gate, one commit, one journal row.
- **Round law (new, mandatory):** hardening/audit phases exit only when **repeated audits stop finding meaningful production issues** — never on a fixed round count.
- **Open P0 findings:** none known. **Open 🔶 loops:** P3-AI-2/AI-3 (W2) · K-2 (QP).
- **Automatic-failure tripwires** (instant BLOCKED): data loss · security breach · escalation · tenant-isolation failure · critical crash · duplicate financial transaction · broken auth/sync · critical regression · failed backup verification · production blocker.

## 9. Current Risks (accepted, tracked)

1. **W2 flag vs migrations** — release config enables W2 while `20260867`+ are undeployed; guarded at LIVE-1 ① + CFC-1 item 5. Do not ship a live build before that deploy.
2. **7-day clock not started** — every week LIVE-1 stays unprovisioned pushes P7/GA a week, regardless of coding pace.
3. **PROD-22 Face ID** — largest un-started Must-Before-GA build; a late start collides with P6-PILOT-1 Stage 12.
4. **Audit-loop fatigue** — both 🔶 lanes are finding real issues each round (by design); the round law forbids declaring victory early.
5. **Owner-decision latency** — identity cluster + module scope + beta cohort narrow the runway if left undecided.
6. **Red-Team outcome open by design** — P5 is variable; a bad verdict re-opens earlier phases.

## 10. Current Focus

> **RECON-1 ✅ (this commit).** Twin hardening programs run in parallel under disjoint ownership: **P3-AI-3** (W2 audit rounds — next: round 2) and **K-2** (QP quality program — next: template/blueprint expansion + round). **P1-PROD-22 Face ID opens now.** Owner batch: LIVE-1 provisioning (starts the 7-day clock), FREEZE carve-out, beta cohort. Everything downstream (CFC-1 → FREEZE-1 → P4 → P5 → P6-VAL → Pilot → Beta → P7 → P8) is sequenced and gated; nothing is skipped, nothing renamed, nothing weakened.

---

*Summary only — this file adds no tasks, changes no scope, and yields to the roadmap on any conflict. One wave, one EOS gate, one commit, one journal row — repeated until GA.*
