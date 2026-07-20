# Akshara ERP — NEXT ACTIVE WAVE

**This is the ONLY file the executor reads before each autonomous wave** — together with its state companion [`../execution/EXECUTION_DASHBOARD.md`](../execution/EXECUTION_DASHBOARD.md). Keep it small — current work only.
**Updated by:** the executor at each wave boundary (on EOS PASS + commit → advance to the next wave; refresh the dashboard at the same moment).
**Authority:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) · run per [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) · journal to [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md).

> **Previous waves:** full history in the journal + roadmap §0/§0b. Headline state: **P0 W1/W2 ✅ · P1 ✅ · P2 ✅ · P3 ✅ (W1 CERTIFIED · W2+AI-3 hardening exit 2026-07-11) · K-1 ✅ local · LIVE-1 ① prod deploy 2026-07-14.**

---

## ▶ CURRENT — 🔧 RECON-2 CORRECTION → **PRC-A is the true current wave** (2026-07-14)

> ### ⚠ RECON-2 (2026-07-14): execution-order drift corrected — see [`../execution/RECON-2_EXECUTION_ORDER_CORRECTION.md`](../execution/RECON-2_EXECUTION_ORDER_CORRECTION.md)
> The ERP branch carried a **stale roadmap missing the owner-authorized 2026-07-11 PRC integration** (it lives only on the K-lane branch). The lane drifted to **CFC-1 → FREEZE-1 → "P4-RT"** and **SKIPPED the mandatory PRC-A → PRC-B gates.** Corrected now:
> - **FREEZE-1 = RESCINDED** (declared before PRC ran). **P4 = NOT open.** The "P4-RT-0/RT-1 rounds 1–3 + perf wave" = **PRE-FREEZE ADVERSARIAL HARDENING (PFH)** — valid fixes PRESERVED, wrong label.
> - **Canonical order restored:** P3 exit → **PRC-A → PRC-B** → CFC-1 → FREEZE-1 → P4 → P5 → P6 → P7 → P8.
> **Preserved (do NOT revert):** the round-1 money/document fixes (deployed to prod edge `67f57ef2`), round-3 defect-class guards S1–S4, RT-5-3/RT-6-1, RT-4-1, migrations `20260879`–`20260881` (deploy-pending), RT-11-2 late-fee. These stay as valid hardening.

**Active wave: PRC-A — Product Reality & Correctness, Wave A (Real School Operations Capability & Cross-Module Gap Audit).**
- **148 mandatory capabilities** across 15 domains (transport/finance-integration · storage quota · AI credit wallet · central AI provider keys · SaaS plan-limit runtime enforcement · syllabus progress · fee-structure bulk assignment · marketing-AI wiring · social-media integration · cross-module cost intelligence · complaints/ticketing · gate-pass/early-pickup · health/infirmary · staff-workload intelligence · certificate-request desk). Per-capability 13-step method → classify (`WORKING/LIVE · PARTIAL · MISSING · WRONG UX · MOCK/STUB · DEVICE-GATED · N/A`) → fix verified gaps → regression → prove journeys. Dependency rule: never certify a dashboard/metric independent of the data lifecycle feeding it.
- **Owner-future-ideas reconciliation is a PRC-A input:** classify every item in [`../owner/OWNER_FUTURE_PLATFORM_IDEAS_AND_RECONCILIATION_QUEUE.md`](../owner/OWNER_FUTURE_PLATFORM_IDEAS_AND_RECONCILIATION_QUEUE.md) vs current code / roadmap / PRC / prior owner decisions (IMPLEMENTED · PARTIAL · ALREADY-ROADMAPPED · COVERED-BY-PRC · CURRENT-SCOPE-MISSING · OWNER-GATED · POST-GA · REJECTED · DUPLICATE); genuinely-missing current-scope capabilities → roadmap + implement here (pre-freeze).
- **Authority:** tracker [`PRODUCT_REALITY_CORRECTNESS_PROGRAM_TRACKER.md`](PRODUCT_REALITY_CORRECTNESS_PROGRAM_TRACKER.md) (502 reqs) + source `../AKSHARA_PRODUCT_REALITY_AND_CORRECTNESS_CERTIFICATION.md` (frozen). Exit: all 148 classified with evidence + gaps fixed + journeys proven + EOS PASS → **then PRC-B**.

**Then (canonical, strict):** PRC-B (249 invariant/edge-case items) → CFC-1 (re-run at canonical position) → FREEZE-1 (declared only when scope + pre-freeze implementation genuinely complete) → **P4 (the REAL Global Red Team, against the stable frozen surface)** → P5 → P6-VAL → PILOT → BETA → P7 → P8.

**Then (strict order):** **PRC-A → PRC-B** (Product Reality & Correctness Certification — **auto-begins when P3 exits + EOS passes**, if no higher-priority blocking production gate; two sequential waves, never merged; 502 tracked requirements in [`PRODUCT_REALITY_CORRECTNESS_PROGRAM_TRACKER.md`](PRODUCT_REALITY_CORRECTNESS_PROGRAM_TRACKER.md); **scheduled, NOT started** — integrated 2026-07-11) → CFC-1 Code Freeze Checklist (10 items, evidence per item) → FREEZE-1 Feature Freeze (entry now also requires PRC complete) → P4 → P5 → P6-VAL-1 → P6-PILOT-1 → P6-BETA-1 (5–10 real schools) → P7 → P8.
**Parallel / owner lanes (do not block PRC-A):**
- **K-2 rounds** (Knowledge lane, `curriculum/**` — HANDS-OFF; runs independently).
- **P0-LIVE-1 remainder** (owner-provisioned): off-site R2 · cron token · CI runner · 7-day clock (gates P7).
- **Deploy-pending (VPS down):** the PFH round-3 edge fixes + migrations `20260879`/`20260880`/`20260881` ride the next edge/migration window when the owner re-establishes the SSH control-master.

### 👤 Owner-decision batch (surface; none pauses P4)
- **PRC slotting** (above) · **P0-LIVE-1 provisioning** (R2 · cron token · CI runner · 7-day clock) · **P6-BETA-1 cohort** (5–10 schools) · K-3 promotion timing · pgvector provisioning (optional, enables W2.8) · signed pilot build (owner keystore, at P6).

### EOS gate (per P4 round)
- Each RT round closes on its audit artifact + fixes + full regression (`flutter analyze` 0 · `flutter test` no NEW failures · `deno test`+`deno check` green for touched `supabase/**`) — commit only after the round's EOS PASS.
- **Freeze tripwire (new):** any change in P4/P5 must be classifiable as bug/regression/perf/security/quality/stability — a feature-shaped diff is BLOCKED and routes to P8-GA-5.
- **Standing tripwires:** no behaviour/governance/money/RBAC/isolation regression; goldens deliberate; never start the next wave with an open P0 or EOS BLOCKED.

### Regression required (per wave)
- `deno test` + `deno check` green for touched `supabase/functions/**` · `flutter analyze` 0 · `flutter test` no NEW failures · goldens deliberate-only.

> **Rule:** never begin the next wave with an open P0 or an EOS BLOCKED. Owner-decision (👤) tasks surface in a batch and do not pause the pipeline; live-lane (⏳) items run the moment the owner provisions them.
