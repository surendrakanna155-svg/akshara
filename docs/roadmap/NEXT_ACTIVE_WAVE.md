# Akshara ERP — NEXT ACTIVE WAVE

**This is the ONLY file the executor reads before each autonomous wave** — together with its state companion [`../execution/EXECUTION_DASHBOARD.md`](../execution/EXECUTION_DASHBOARD.md). Keep it small — current work only.
**Updated by:** the executor at each wave boundary (on EOS PASS + commit → advance to the next wave; refresh the dashboard at the same moment).
**Authority:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) · run per [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) · journal to [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md).

> **Previous waves:** the full history lives in the journal (`IMPLEMENTATION_PROGRESS.md` — incl. the RECON-1 catch-up block) and the roadmap §0/§0b. Headline state: **P2 ✅ · P1 non-gated lane ✅ (+GS-1..3) · P3-AI-1 ✅ CERTIFIED · P3-AI-2 🔶 hardening · K-1 KIE ✅ (local) · K-2 QP engine 🔶 hardening · prod deployed to `20260866` (2026-07-09) with live RLS zero-leak + backup GREEN.**

---

## ▶ CURRENT (post-RECON-1, 2026-07-10)

**RECON-1 ✅ COMPLETE (this commit)** — tracking reconciled to reality; derived progress **54.8%** (Wave Ledger §0b; ✅=1 · 🔶=0.5 · never estimated).

**Active waves (parallel, disjoint ownership — never two implementation agents on one module):**

1. **P3-AI-3 — W2 Hardening & Closure**: 🔶→**HARDENING EXIT MET 2026-07-11** (pending only P7 for 🟩).
   Full W2 surface landed: W2.0a/b · W2-GATE · W2.S · W2.2–2.6 · **W2.1** (briefs/digests, prewarm cron ops-gated) · **W2.7** (ops worklists + client deep-links) · **W2.8** (pgvector semantic cache, 3-layer dormant: guarded migration/runtime probe/env-gated embedder) · **W2.9** (truth-in-naming, closes AI-6) · full audit tail (atomic quota reservation A5 · injection fences A6 · cost-panel A2 · quick-action UX A3 · search pagination+categories A4 · teacher-exam scoping A1).
   Audit rounds: R2 (1 P0 + 4 P1 + 8 P2 → fixed) → R3 **clean** → new-batch R4 (1 P1 RBAC-cohort narrative + 1 P2 finance paging + 3 P3 → fixed `df47a768`) → R5 verify (all fixed; found P2 cron-cohort + P3 sweep-order → fixed `34ccbdbd`) → **R6 verify clean = 2nd consecutive clean round → EXIT**.
   Owner/ops residue on P0-LIVE-1 (not code): migrations `20260867`+…`20260876` deploy before W2 flag · pgvector provisioning + `AI_EMBEDDINGS_API_KEY` + Stage-2 name-swap threshold tuning · `INTERNAL_CRON_TOKEN` for brief-prewarm + drain crons.

1b. **P1-PROD-22 — Staff Face ID attendance**: 🔶→**HARDENING EXIT MET 2026-07-12** (pending only P7 + device residue for 🟩).
   Full build landed (slices 1–4, `3e46a87b`→`db4a6574`): enrollment backend (mig `20260877`) · unified server matcher (0.82 env-clamped, fail-closed) · Flutter device layer (geolocator anti-mock · mlkit blink-liveness · MobileFaceNet/tflite embedder, FAIL-LOUD until the model asset ships) · manual-request fallback end-to-end (list endpoint + staff CTA/dialog + approver queue + `approveStaffAttendance`).
   Audit rounds R1–R5 (7 P1 found+fixed: migration-abort · NaN fail-open · offline optimistic-lie→onlineOnly · dead prod 422-mapping · photo-swap still guard · client route guard · self-approval SoD + decide race); **R2+R3 clean → built-surface exit; R4 fixed; R5 verify clean → lane exit**.
   **Owner/device residue (⏳/👤, not code):** license-cleared `mobilefacenet.tflite` into assets/models/ (verify 192-d output shape) · on-device E2E run (design §8: iOS BGRA rows · EXIF-mirror tags · front-cam mirroring) · `FACE_MATCH_MIN_SIMILARITY` pilot tuning · mig `20260877` deploys with LIVE-1 batch.
   ⚠ ERP lane works in linked worktree `Akshara_ERP-drp` (shared-dir branch collisions ×2 on 2026-07-11).

1c. **SCE-1 — Student Clearance / No-Dues Engine** ← **NOW THE ACTIVE BUILD** (owner verdict 2026-07-02: NEXT roadmap item post module-completion — [[student-clearance-no-dues-engine]] memory). Cross-module clearance before year-close/promotion/TC/transfer: contributor-registry (Finance dues · Library returns · Inventory/asset returns · Hostel · Transport) + gate-transitions. 👤 open sub-decision to surface (do NOT pause): hard-block vs warn per gate — build BOTH modes configurable, default warn, owner flips per gate.
2. **K-2 — QP Engine Hardening Program** (Knowledge lane, `curriculum/**` — disjoint from ERP).
   Round status: audit (2 P0 + 4 P1) → R1–R9 → prod-readiness cert **GO (scoped)** → Phase-1 sanitizer hardening landed (`835f39e4`).
   Continue: OCR artifact cleanup · **deterministic template expansion** · **Blueprint Library (CBSE·AP·TS·NEET·JEE Main·JEE Advanced)** · graph-degree · recency · difficulty/Bloom · MCQ + gated-AI validation.
   **Exit = 2 consecutive clean independent audits → K-lane feature freeze (K-4 re-cert).** ⚠ In-flight uncommitted: `qpgen/templates.py` — land with its round.
4. **P0-LIVE-1 — Consolidated live checklist** (owner-provisioned): ① **AI migrations `20260867`+/`20260873` deploy — MUST precede the W2 release flag reaching any live build** · ② outbox drain · ③ COM-4 cron token · ④ reminder crons · ⑤ live `ai_*` probes · ⑥ off-site R2 creds · ⑦ alert delivery · ⑧⑨ CI + isolation-in-CI · ⑩ **7-day cron clock (calendar-critical — gates P7)**. Items ⑪⑫⑬ ✅ 2026-07-09.

**Then (strict order):** CFC-1 Code Freeze Checklist (10 items, evidence per item) → FREEZE-1 Feature Freeze → P4 → P5 → P6-VAL-1 → P6-PILOT-1 → P6-BETA-1 (5–10 real schools) → P7 → P8.

### 👤 Owner-decision batch (surface now; none pauses the active lanes)
- **P0-LIVE-1 provisioning:** R2 creds · `INTERNAL_CRON_TOKEN` · CI runner (starts the 7-day clock).
- **FREEZE-1 K-lane carve-out:** does K-2 block the ERP feature freeze, or run past it?
- **P6-BETA-1 cohort:** recruit 5–10 beta schools (timing + onboarding owner).
- Identity cluster (P1-CODE-4) · module scope (P1-CODE-6/7/8) · PAR3-UPLOAD · PRI-4/5 scheduled-send · HWK-1/C6 basis re-check · A2 ratification · K-3 promotion timing.

### EOS gate (per active wave)
- **P3-AI-3 / K-2 rounds:** each round closes on its audit artifact + fixes + full regression (`flutter analyze` 0 · `flutter test` no NEW failures · `deno test`+`deno check` green for touched `supabase/**` · KIE/QP 196-test regression green, KB SHA-identical) — commit only after the round's EOS PASS.
- **Tripwires unchanged:** no behaviour/governance/money/RBAC/isolation regression; goldens deliberate; **never start the next wave with an open P0 or EOS BLOCKED.**
- **State law:** 🔶 waves are never reported complete; W2 and the QP engine graduate only at their hardening exits (and 🟩 only via P7).

### Regression required (per wave)
- `deno test` + `deno check` green for touched `supabase/functions/**` · `flutter analyze` 0 · `flutter test` no NEW failures · K-lane: full engine+KIE regression, knowledge base unmutated.

> **Rule:** never begin the next wave with an open P0 or an EOS BLOCKED. Owner-decision (👤) tasks surface in a batch and do not pause the pipeline; live-lane (⏳) items run the moment the owner provisions them.
