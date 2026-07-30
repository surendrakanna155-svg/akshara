# W1 — CANONICAL EVIDENCE LEDGER (the single status source of truth)

**Wave:** W1 (Re-baseline Reality Audit on the Converged Trunk) · Constitution-Aligned Master Roadmap §5.
**SSOT:** `integration/w0-trunk` @ `5003934b` (= `main` = `release/w0-converged`). This ledger supersedes all per-branch, per-cert, and per-tracker status as the **one** disposition of record.
**Method (per owner):** reconcile + dedupe existing evidence — do NOT rediscover the repo, do NOT re-audit certified paths unless W0-affected. The **current source code is the authority** over commit-note labels and prior certs.
**Date:** 2026-07-20 · Autonomous Execution Mode · built from three parallel read-only extractions (PRA / PRC / cert-validity) + targeted trunk spot-verification.

---

## 0. HEADLINE

The converged trunk is **regression-green** (backend `deno test` 3650/0 · `flutter analyze` clean · `flutter test` 4110/0) and carries every lane's real work. Against the three big evidence programs:

- **PRA (117 reality gaps):** **65 CLOSED-MERGED · 5 OWNER-GATED · 47 DEFERRED (Tier-2, non-GA) · 0 OPEN.** Every one of the 24 P0s is addressed; every Tier-1 pre-GA item is closed. (The prior "1 OPEN — P1-15" was resolved by trunk verification: it is fixed under the EXM-1/REL-3 ReliableWriter wiring.)
- **PRC (~502 correctness requirements):** program is **owner-accepted FROZEN/complete** (tip `671d07a3`, merged). ~450 satisfied-on-trunk · **~33 genuinely-open operational residual (→ W4)** · ~19 owner/device-gated activations. 12/12 PRC-B invariant categories certified (5 carry optional depth-extension tails, not gaps).
- **Certifications (94 docs):** reconciled into VALID-ON-TRUNK vs SUPERSEDED-BY-PRA. The QW1–8 / Gap-Sweep module certs are **superseded** — the merged PRA fix + its test is now the evidence, not the old green cert.

**Nothing on the trunk is "production-certified" yet** — per Constitution Part 15, production cert (🟩) is granted only at **W13**. Everything below is *implementation-complete + regression-green + evidence-graded*.

---

## 1. PRA — 117 reality gaps (final disposition)

| Severity | CLOSED-MERGED | OWNER-GATED | DEFERRED (Tier-2) | OPEN | Total |
|---|---|---|---|---|---|
| P0 | 22 | 2 | 0 | 0 | 24 |
| P1 | **39** | 3 | 13 | 0 | 55 |
| P2 | 4 | 0 | 31 | 0 | 35 |
| P3 | 0 | 0 | 3 | 0 | 3 |
| **Total** | **65** | **5** | **47** | **0** | **117** |

**5 OWNER-GATED** (each gates only itself; all named in §5): P0-02 payment-gateway SDK · P0-15 staff GPS/face **device adapters** (hardware) · P1-34 leave accrual · P1-35 statutory payroll (PF/ESI/PT/TDS) · P1-41 library accession scheme.

**Honesty caveats (recorded — do NOT read as feature-complete):**
- **P1-40** (library fine→Finance): the *false* sync claim was deleted; a real fine-collection/audit path is **not** built → a genuine W6/finance-posting follow-up.
- **P1-50** ("Email report"): the lying buttons were removed; a real report-email/schedule pipeline does **not** exist → **W6** (P1-50 report scheduling).
- **P1-55** (tenant data export): deferred (real export = Tier-2/W9); confirm the lying "Export package" button is gone on the trunk (button-removal not separately evidenced).
- **Partial-but-honest:** P0-14 (reshuffle/section-balance deferred), P1-04 (multi-school *selector* = D2), P1-13 (client grade-scale sync tracked), P1-48 (revenue/expense/enrollment trend panels honestly empty — no data source). W2–W10 must not treat these as whole-feature-complete.

**W0-affected re-verify (union-merged files) — all confirmed intact on trunk (W0 §3–§4 + this pass):** finance_refunds (P0-03/P1-11), sis_certificates (P1-20 + deferred cert rows), rbac_route_inventory (P0-12/P1-53), audit completeness (P1-53/P0-10/P2-34), staff_check_in_card (P0-15 interim), surface_backend_gate (P0-14/N-7/N-8).

---

## 2. PRC — ~502 correctness requirements (frozen program; reconciled to reality)

The PRC tracker is "done-by-banner" (owner-accepted complete) with per-cell "scheduled" markers (anti-disappearance law). Reconciled split:

| Bucket | ~Count | Composition |
|---|---:|---|
| **(a) Satisfied / merged on trunk** | **~450** | 98 process/method/mandate rows + ~96 PRC-A caps (10 LIVE-CERTIFIED DRP batches + money-P0 fixes) + 256 PRC-B IDs certified at floor |
| **(b) Genuinely open (→ W4)** | **~33** | the STILL-TO-BUILD PRC-A caps (§below) |
| **(c) Owner/device/external-gated** | **~19** | central AI keys (VAULT_ENC_KEY + `erp_platform` DB path), FB/IG (Meta App Review), marketing image (paid provider), GPS (hardware), + dark-flag activations |

**PRC-A 10 batches SATISFIED-BY-MERGED — DO NOT re-audit/re-build:** storage-quota (Batch 4), AI-credit-wallet (Batch 3), complaint/ticket (Batch 2), gate-pass (Batch 2), health/infirmary (Batch 2), certificate-request-desk (Batch 2), marketing-internal (Batch 10), transport cost/expense (Batch 8), fee-bulk/concession, money-P0 fixes. All LIVE-CERTIFIED on real prod Postgres, merged.

**Genuine W4 operational tail (~33 caps):**
- **Transport:** admission→transport propagation (cap 2), requirement enum own/parent-pickup (3), effective-date architecture / proration / temporary assignments (5,6,23), driver/bus→route write path + capacity guard (8,20), distance-derived fee (10), service-history/leave/substitute-driver (16,21,22), per-vehicle/route cost rollups + odometer + Flutter expense UI.
- **SaaS plan limits:** SMS limits (53), staff/user limits (54), grace/suspension enforcement (57).
- **Syllabus progress:** functional daily-capture UI (58–61), School-Completion hub inbound nav, homework link (62), photo evidence (63).
- **Cross-module cost intelligence:** asset/repair (93), event (94), marketing (96) cost feeds, budget-vs-actual (99), anomaly (100), the cost-aggregation layer (`expenseBreakdown` hardcoded `[]`).
- **Staff workload:** free periods (130), substitution burden (131), non-teaching + exam/event duties (132,133), department dimension.
- **Client fast-follows:** parent-facing UIs (cert-desk/gate-pass/complaints) + self-cancel; Flutter panels for storage-quota/AI-wallet/channel-policy/Tally/transport-expense/marketing; low-balance alert (40); upload metering + malware-scan wiring.

**PRC-B:** 12/12 categories certified at floor; 5 (Date-Time, Boundary, Concurrency-non-money, Cross-module-full-matrix, Export-render) carry **depth-extension tails** — optional deepening (W10/W11 hardening), classified open-but-not-gaps.

**DEDUP (counted once, not per-ID):** money-P0 fixes ≡ PRA money remediation ≡ DRP red-team race pattern · fee-concession ≡ FIN-D4 engine (client rewire) · storage-quota ≡ SaaS-storage-limit (one model) · AI-wallet ≡ SaaS-AI-limit (one model) · cert-desk TC ≡ SCE-1 no-dues gate · PRC-B concurrency/idempotency ≡ DRP rounds + webhook replay · PRC-B AI-boundary ≡ W2 Adaptive-AI gateway.

---

## 3. Certification validity (reuse the valid, retire the superseded)

**VALID-ON-TRUNK (genuine current evidence):**
- **DATA_RELIABILITY_PLATFORM** — exactly-once/idempotency/optimistic-concurrency + 4 pilot write-paths; live 20/20 + red-team 26/26.
- **FINANCE_FEE_REDUCTIONS_LIVE** — fee-reduction DB guardrails + maker-checker SoD, live-prod E2E (self-approve→403). Scope = fee reductions only.
- **QA_R_008_SECURITY** (scoped) — coarse role×route RBAC matrix + server audit-completeness (re-unioned+re-passed in W0). Caveat: authorization-*depth* (P0-11/12/13) was closed by PRA, not this cert; live RLS pen-test still infra-blocked.
- **ADAPTIVE_AI_W1** — governed-gateway sole-path + isolation-probe foundation (local 2533/0). Residual: live isolation run + outbox drain (owner/VPS-gated).
- **QW1_CI_ENFORCEMENT** — the CI backbone (orthogonal to PRA module defects).

**SUPERSEDED-BY-PRA (prior green ≠ production evidence; the merged PRA fix + test is the evidence):** QW1/QW2/QW3/QW4/QW5/QW7 completion + QW1-persona-RBAC-money + GAP_SWEEP. These are the exact modules the PRA proved hid the 24 P0s.
**SUPERSEDED (other):** STAFF_FACE_ID (auth model replaced by GPS+camera-face ATTENDANCE_AUTH decision; + P0-15 device-gated) · QW8 GA gate `QA-R-012` (BLOCKED by design → production cert now only at W13).
**NEEDS-REVERIFY:** QW6 (resilience; green on trunk, but live p95-latency cron leg infra-blocked/unrun since convergence).
**Historical:** `docs/archive/completed/` B1–B11 / Journey Waves / Live-Backend batches — not standalone production evidence.

**Cross-cutting caveat:** the three *live* certs (DRP, Finance fee-reductions, QA-R-008-RLS) ran against the **pre-convergence deployed edge** (DRP tip `606c79a5`, which W0 proved == the trunk's runtime source, 508/508). A clean **redeploy-from-trunk + `production_launch_verify.sh` smoke is outstanding** (W0 step 3, owner-deferred: "verify only").

---

## 4. SOP-Identity + SOP-Features + Web (forward-wave routing)

**Identity (→ W2):** SOP-ID-1 DONE · ID-2 transfer/exit lifecycle OPEN (elevate P2-28) · ID-3 multi-school identity OPEN/scaffolding (elevate P1-04/51/52, P2-27; owner D2) · ID-4 student-login-via-parent-mobile MISSING (reconcile toward frozen Student-Identity D3) · ID-5 ownership/audit-events/change-phone OPEN (extend P1-CODE-4).
**Features:** F1/F2/F3 Smart-OMR ⛔ **OWNER-GATED D1 — DO NOT BUILD** (reverses frozen Assessment Marks-Grid) · F4 evaluation workflow EXISTS (→ W5/EIP verify) · F5 question-heatmap MISSING (activate dormant `edu_student_item_responses` — EIP-6 spine) · F6 timed-online-exams MISSING (→ W5/EIP) · F7 weak-concept PARTIAL (→ EIP-7) · F8 workspace/workflow-builder PARTIAL · F9 approval-engine PARTIAL · F10 certificate-builder PARTIAL (→ W6; ties PRA P1-21/22, P2-02/03) · F11 smart-filters MISSING · F12 advanced-search EXISTS-partial (→ W6, +web parity). **D2 sequencing ⛔ OWNER-GATED, PENDING.**
**Web (→ W8):** still a **read-only viewer, no write layer**. Backend API gaps (ERP-WT-001…011 / WEB-001…011) all delivered EXCEPT GPS. Single reconciled open list: (1) web write layer (whole functional ERP, server-authoritative RBAC), (2) token refresh (`/auth/refresh` unused), (3) kill fake "Settings saved" toast + demo-blank default, (4) P2-UX a11y (P2-UX-4)/DS-lints/dark-theme, (5) live GPS (Phase-2), (6) merge the two web registers into one.

---

## 5. CONSOLIDATED OWNER-DECISION BATCH (from W1 reconciliation — supersedes scattered lists)

| # | Decision | Gates |
|---|---|---|
| 1 | Payment-gateway SDK choice + credentials (PRA-P0-02) | W3 |
| 2 | Staff device-build scope (PRA-P0-15 GPS/face adapters) — hardware | W4/W12 |
| 3 | Statutory payroll schedule (P1-35) · Leave accrual (P1-34) · Library accession scheme (P1-41) | W3/W4 |
| 4 | **D1 Smart OMR (SOP-F1/2/3)** — reverses frozen Assessment decision — **DO NOT BUILD until confirmed** | W5 |
| 5 | **D2 SOP placement/sequencing** | W2/W5/W6 |
| 6 | Multi-school identity cluster (ID-3, P1-51/52, PLAT-0) · Hostel/Alumni scope · cross-module finance posting | W2/W3/W9 |
| 7 | Vault own-provider-keys + real encryption (P1-54 + P2-30, ship together) · central-AI-keys VAULT_ENC_KEY + `erp_platform` path | W6/W7 |
| 8 | Live provisioning: R2 creds · `INTERNAL_CRON_TOKEN` · CI runner (7-day clock) · dark-flag activations (AI_WALLET/STORAGE_QUOTA/MALWARE_SCAN enforcement) · FB/IG Meta App Review | W10/W11 |
| 9 | K-3 QIE→ERP promotion timing · Decision-C adoption · Amendment A2 ratification · Assessment-Intelligence live-promotion timing | W5/EIP/K |
| 10 | Beta cohort (5–10 schools) | W12 |

---

## 6. DEDUPED FORWARD SCOPE (what each wave actually does — no re-audit of closed paths)

- **W2 Identity:** verify PRA-merged identity/lifecycle (P0-01, P1-01…07, P2-34) + finish SOP-ID-2/3/4/5 tail (owner D2/PLAT-0 gated). *Mostly verify-merged + identity-governance build.*
- **W3 Money:** verify PRA-merged money integrity (P0-03/04/24, P1-08…11/37/38) + **owner: payment SDK, statutory payroll** + honesty follow-ups (P1-40 fine-posting, P1-50 report email → W6).
- **W4 Ops-completeness:** the **~33 PRC-A still-to-build caps** (transport effective-dates/write-path/propagation dominant, cross-module cost-aggregation, syllabus capture UI, SaaS 53/54/57, staff-workload 130–133) + PRA ops verify + device features (owner/hardware).
- **W5/EIP:** F4 verify · F5 heatmap = EIP-6 spine · F6 online exams · reconcile the two QI systems · **D1 OMR owner-gated**.
- **W6 Dynamic services:** F8/F9/F10/F11/F12 extend-not-fork · vault (P1-54+P2-30) · report email (P1-50) · owner-queue provider layers (reconcile-first).
- **W7 AI:** finish P3-AI hardening + consolidate; embeddings already routed (P1-46 closed).
- **W8 Web:** the entire web write layer + token refresh + honest states + a11y (all open).
- **W9 Enterprise:** multi-school branch-vs-tenant (P1-51/52, P2-27/28/29), export (P1-55), audit-read UI (P1-53 done).
- **W10 Hardening:** central RBAC chokepoint, RLS completion, `service_role` hardening, CI-gate, PRC-B depth-extension tails.
- **W11 Red-team:** reconcile DRP Rounds 1–7 + re-run on converged trunk for the post-W2 surface.

---

## 7. W1 VERDICT

One canonical, evidence-graded status ledger now exists for the converged trunk. Prior per-branch/per-cert status is reconciled and deduped. **Zero genuine unaddressed P0s; every Tier-1 pre-GA PRA item closed; the genuine remaining build is the ~33 PRC-A ops caps (W4) + the web write layer (W8) + the SOP/identity/dynamic-services tails, with a named owner-decision batch.** No path is claimed above its evidence grade. **W2–W10 inherit a deduped scope and must not re-audit any CLOSED-MERGED / SATISFIED path.** EOS DOCS scope: **PASS** (audit/tracking wave; gates the build waves).
