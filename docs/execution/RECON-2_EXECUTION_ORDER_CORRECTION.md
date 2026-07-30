# RECON-2 — Execution-Order Correction (PRC-before-FREEZE drift)

**Date:** 2026-07-14 · **Trigger:** owner "STOP AND RECONCILE" directive · **Type:** governance correction (no code reverted) · **Branch:** `feature/data-reliability-platform` (ERP lane)
**Verdict:** **execution drifted — mandatory gates PRC-A and PRC-B were skipped; FREEZE-1 was declared prematurely; the "P4-RT-1" work was mis-classified as the canonical Global Red Team.** All valid bug fixes + regression tests produced during that work are **preserved** (they are legitimate pre-freeze adversarial hardening).

---

## The 7 checkpoint answers (evidence-backed)

### 1. Was P4 started early? **YES.**

### 2. Exact reason the execution reached P4
The ERP working branch (`feature/data-reliability-platform`) carried a **stale copy of the master roadmap that never received the owner-authorized 2026-07-11 PRC integration.** That integration ("PROGRAM PRC — Product Reality & Correctness Certification", PRC-A + PRC-B, inserted before CFC-1) was committed **only on the Knowledge-lane branch** (`feature/qp-content-readiness`, main worktree `Akshara_ERP`), whose roadmap has **13 PRC references**. The ERP-branch roadmap has **0**. Consequently the ERP lane's roadmap, dashboard, `NEXT_ACTIVE_WAVE`, and session handoff all showed the sequence as **CFC-1 → FREEZE-1 → P4** with **no PRC gate**.
This session then (a) followed that stale ERP roadmap and the literal first-message directive ("Complete CFC-1 … proceed to FREEZE-1 and then begin P4"), and (b) compounded it by citing "PRC-X-01" to *defer* PRC — a **misread**: PRC-X-01 is an entry-*timing* clause that defers PRC-A's auto-start only for a *higher-priority blocking production gate*; a red-team round is not that, and PRC completion is an **explicit FREEZE-1 entry condition** (canonical roadmap line 303). The conflict between the PRC tracker ("must complete before CFC-1/FREEZE-1") and the stale ERP roadmap should have been surfaced as a blocker **before** declaring FREEZE-1; it was not.
**Classification: C (skipped mandatory gates) + B (useful hardening mis-labelled as canonical P4).** NOT A — there was no legitimate roadmap amendment.

### 3. Which mandatory work was skipped or is still pending
- **PRC-A** (Wave A — Real School Operations Capability & Cross-Module Gap Audit): **148 capabilities** across 15 domains (transport/finance-integration, storage quota, AI credit wallet, central AI provider keys, SaaS plan-limit runtime enforcement, syllabus progress, fee-structure bulk assignment, marketing-AI wiring, social-media integration, cross-module cost intelligence, complaints/ticketing, gate-pass/early-pickup, health/infirmary, staff-workload intelligence, certificate-request desk) — the 13-step per-capability method, classify → fix verified gaps → regression → prove journeys. **NOT STARTED** (PRC tracker: "⚪ SCHEDULED — DO NOT EXECUTE YET").
- **PRC-B** (Wave B — Product Correctness, Invariant & Edge-Case Certification): **249 items / 12 categories** (money/paise precision, date/time, proration, calculator-truth across all layers, boundaries, idempotency, concurrency, cross-module propagation, delete/archive integrity, export/report consistency, AI-truth boundary, failure/recovery). **NOT STARTED.**
- **Owner-future-ideas reconciliation** (`docs/owner/OWNER_FUTURE_PLATFORM_IDEAS_AND_RECONCILIATION_QUEUE.md`, ~35 items): **NOT STARTED** — the file lives only on the K-lane branch; the ERP lane never saw it.
- **Any genuinely-missing current-scope capability** that PRC-A surfaces must be roadmapped + implemented **before** FREEZE-1.
- **CFC-1** must re-run at its *canonical* position (after PRC); its 2026-07-14 evidence is preserved but does not satisfy the gate out of order.

### 4. Was the owner-future-ideas queue fully reconciled? **NO — not started.** (Structure: ~35 platform/provider-abstraction + production-readiness items; first-pass classification runs as an input to PRC-A — see §Owner-Ideas below.)

### 5. Exact corrected current wave
**PRC-A** (Product Reality & Correctness — Wave A), which auto-begins at the P3-AI-3 hardening exit + EOS AI PASS (both satisfied 2026-07-11). This is the true current wave. FREEZE-1 is **RESCINDED**; P4 is **NOT open**.

### 6. Safe parallel lanes (see §Parallelization)

### 7. What must finish before the REAL Global Red Team (P4)
`PRC-A (148 caps, incl. owner-idea reconciliation + missing-capability implementation) → PRC-B (249 invariant/edge-case items) → CFC-1 (canonical position) → FREEZE-1 (declared only when product scope + pre-freeze implementation are genuinely complete)`. **Only then** does the canonical Global Red Team (P4) run against the stable, frozen, PRC-certified surface.

---

## What is corrected vs preserved

**PRESERVED (valid — do NOT revert):**
- All bug fixes + regression tests from "RT rounds 1–3" and the perf wave: the 3 round-1 money/document races (deployed to prod edge `67f57ef2`), the 4 round-3 defect-class money/status guards (S1–S4), RT-5-3 (branch/franchise mock-as-real gate), RT-6-1 (exam-publish completeness), RT-4-1 (parent-AI number guard), RT-9-2 + RT-11-6/7 (migrations `20260879`–`20260881`), RT-11-2 (late-fee set-based), the waiver SoD hardening. These are legitimate **pre-freeze adversarial hardening** and stay.
- The round-2 live-leg evidence (isolation/ops/DR) and the LIVE-1 ① prod deploy.

**CORRECTED (classification / governance):**
- The "P4-RT-0 / P4-RT-1 rounds 1–3" are **re-labelled PRE-FREEZE ADVERSARIAL HARDENING (PFH)** — they are NOT the canonical Global Red Team and do not count toward P4.
- **FREEZE-1 is RESCINDED** — it was declared without the mandatory PRC gate.
- **CFC-1's PASS is scoped to "code-hygiene evidence captured"** — it does not satisfy the canonical CFC-1 gate, which sits *after* PRC-B.
- The ERP roadmap is corrected to carry the PRC gate; dashboard / NAW / journal / handoff are corrected to show **PRC-A as the current wave**.
- The prior "PRC-X-01 deferral" recorded at FREEZE-1 is **withdrawn** (superseded by this RECON-2).

## Root-cause remediation
- The PRC program (source + tracker) was already brought into the ERP branch at the FREEZE-1 commit; **RECON-2 additionally integrates the PRC gate into the ERP-branch roadmap** (FREEZE-1 entry + execution order + PROGRAM PRC section) so the ERP lane's governance matches canonical.
- The owner-future-ideas file is brought into the ERP branch for reconciliation.
- **Branch-hygiene lesson:** canonical governance docs (master roadmap, owner queue) diverged across the ERP and K-lane branches. Roadmap/governance edits must land on (or be merged into) every active execution branch. Recorded to `[[shared-worktree-branch-rule]]`.
