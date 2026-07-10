# Akshara ERP — NEXT ACTIVE WAVE

**This is the ONLY file the executor reads before each autonomous wave** — together with its state companion [`../execution/EXECUTION_DASHBOARD.md`](../execution/EXECUTION_DASHBOARD.md). Keep it small — current work only.
**Updated by:** the executor at each wave boundary (on EOS PASS + commit → advance to the next wave; refresh the dashboard at the same moment).
**Authority:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) · run per [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) · journal to [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md).

> **Previous waves:** the full history lives in the journal (`IMPLEMENTATION_PROGRESS.md` — incl. the RECON-1 catch-up block) and the roadmap §0/§0b. Headline state: **P2 ✅ · P1 non-gated lane ✅ (+GS-1..3) · P3-AI-1 ✅ CERTIFIED · P3-AI-2 🔶 hardening · K-1 KIE ✅ (local) · K-2 QP engine 🔶 hardening · prod deployed to `20260866` (2026-07-09) with live RLS zero-leak + backup GREEN.**

---

## ▶ CURRENT (post-RECON-1, 2026-07-10)

**RECON-1 ✅ COMPLETE (this commit)** — tracking reconciled to reality; derived progress **54.8%** (Wave Ledger §0b; ✅=1 · 🔶=0.5 · never estimated).

**Active waves (parallel, disjoint ownership — never two implementation agents on one module):**

1. **P3-AI-3 — W2 Hardening & Closure** (ERP/AI lane, `supabase/functions/_shared/intelligence/**` + `lib/features/**` AI surfaces).
   Pipeline (mandatory): Implementation → **Hardening → Repeated audit → Regression → Re-audit** → Production certification.
   Round status: round 1 fixes (`ce1e886f`/`cf32d1ab`/`7224782d`) → implementation tail landed 2026-07-11 (`3ac4b3aa`→`6e7cd8da`: subject scoping · **W2.7 ✅** · **A5 atomic reservation ✅** · **A6 fences ✅** · **cost-panel binding ✅**) → **audit round 2** (1 P0 + 4 P1 + 8 P2, all fixed `183dd71d`→`56513090`) → **round 3 verification: all 15 VERIFIED-FIXED, 0 new P0/P1/P2** = 1 consecutive clean round.
   Still open in this wave: W2.1 briefs/digests (auto-fire stays ops-gated) · W2.8 pgvector Stage-2 · W2.9 truth-in-naming · quick-action routing/accept-suppress UI (P2-1/6 + W2.7 deep-links) · search pagination + categories; then the next audit round.
   **Exit = consecutive rounds find no meaningful (P0/P1) issues.** (The earlier `priority_engine.ts` in-flight warning was stale — that work landed as `40118d6f`.)
2. **K-2 — QP Engine Hardening Program** (Knowledge lane, `curriculum/**` — disjoint from ERP).
   Round status: audit (2 P0 + 4 P1) → R1–R9 → prod-readiness cert **GO (scoped)** → Phase-1 sanitizer hardening landed (`835f39e4`).
   Continue: OCR artifact cleanup · **deterministic template expansion** · **Blueprint Library (CBSE·AP·TS·NEET·JEE Main·JEE Advanced)** · graph-degree · recency · difficulty/Bloom · MCQ + gated-AI validation.
   **Exit = 2 consecutive clean independent audits → K-lane feature freeze (K-4 re-cert).** ⚠ In-flight uncommitted: `qpgen/templates.py` — land with its round.
3. **P1-PROD-22 — Staff Face ID attendance** (Must-Before-GA; largest un-started build; must land before P6-PILOT-1 Stage 12). **Open now** per the frozen `docs/ATTENDANCE_AUTH_DESIGN_DECISION.md` (GPS geofence + anti-mock + live-camera face; NEVER OS biometric).
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
