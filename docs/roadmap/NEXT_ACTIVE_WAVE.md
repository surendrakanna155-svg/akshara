# Akshara ERP — NEXT ACTIVE WAVE

**This is the ONLY file the executor reads before each autonomous wave** — together with its state companion [`../execution/EXECUTION_DASHBOARD.md`](../execution/EXECUTION_DASHBOARD.md). Keep it small — current work only.
**Updated by:** the executor at each wave boundary (on EOS PASS + commit → advance to the next wave; refresh the dashboard at the same moment).
**Authority:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) · run per [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) · journal to [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md).

> **Previous waves:** full history in the journal + roadmap §0/§0b. Headline state: **P0 W1/W2 ✅ · P1 ✅ (PROD-22 Face ID 2026-07-12 · CODE-6/7/8 2026-07-13 · SCE-1 2026-07-12 · SEC-1 runnable slice 2026-07-13; CODE-4 deferred; TEST-1/2 gated) · P2 ✅ · P3 ✅ (W1 CERTIFIED · W2+AI-3 hardening exit 2026-07-11) · K-1 ✅ local · LIVE-1 ① prod deploy 2026-07-14 (live head `20260878`, edge `9bbf8630`) · CFC-1 ✅ 10/10 (`d59b5762`) · 🔒 FREEZE-1 DECLARED 2026-07-14 (K-lane carved out).**

---

## ▶ CURRENT — 🔒 POST-FREEZE · P4 RED TEAM (opened 2026-07-14)

**FREEZE-1 is in force** ([declaration](../engineering/eos/FREEZE1_FEATURE_FREEZE_DECLARATION.md)): in the ERP scope, ONLY bug/regression/perf/security/quality/stability work. Feature requests → post-GA register (P8-GA-5). The K lane (K-2/K-3/K-4, `curriculum/**`) is **carved out** (owner 2026-07-14) and runs its own program in parallel — never blocks ERP phases. **Do NOT touch `curriculum/**` from the ERP lane.**

**Active wave: P4-RT-0 — Global Red Team Preparation** (framework: `docs/strategy/GLOBAL_RED_TEAM_FRAMEWORK.md`)
- Freeze honest re-scoped claims (P0-DOC-4 basis) · stand up the 12 domain operators · ready staging/throwaway tenants + fixtures.
- **Refresh the attack seeds for the post-W2 surface:** persona feeds (Teacher/Parent/Student/Principal/Director) · Universal Search RBAC scoping · per-role copilot quotas + atomic reservation (A5) · prompt-injection on EVERY AI entry point (incl. injection fences A6) · Domain-Gate bypass attempts · **new surfaces since the last seed set: Staff Face ID (enroll/verify/manual-request SoD) · SCE-1 clearance + waiver maker-checker (transferred gate) · Biometric App Lock (lifecycle/re-lock/sign-out escape) · LIVE-1-deployed W2 endpoints on prod edge**.
- Exit = **READINESS PASS**: 12 domains scoped, operators + fixtures ready, seeds current.

**Then: P4-RT-1 — 12-domain adversarial assault** (security · isolation · money · AI abuse · UX · workflow · ops · DR · corruption · concurrency · performance · human-error), per-subsystem **audit → fix (P5) → regression → re-audit**, loop-until-dry under the round law (exit only when repeated audits stop finding meaningful production issues).

**Parallel / owner lanes (do not block P4):**
- **K-2 rounds** (carved-out Knowledge lane; exit = 2 consecutive clean audits → K-4 re-cert; K-3 promotion owner-timed).
- **P0-LIVE-1 remainder** (owner-provisioned): ② outbox drain · ③ cron token · ④ reminder crons · ⑤ live `ai_*` probes · ⑥ off-site R2 (backup currently LOCAL-ONLY) · ⑦ alert delivery · ⑧⑨ CI + isolation-in-CI · ⑩ **7-day cron clock (calendar-critical — gates P7, not P4)**. ①⑪⑫⑬ ✅.
- **PRC-A → PRC-B (deferred program, owner slot pending):** owner-mandated 2026-07-11 (502 tracked requirements, [tracker](PRODUCT_REALITY_CORRECTNESS_PROGRAM_TRACKER.md)); deferred at the 2026-07-14 CFC/FREEZE directive under PRC-X-01 (higher-priority blocking gate). **Recommended slot: with/after P4-RT-1, before P6-VAL-1** — awaiting owner ruling; deferral recorded in tracker §7.

### 👤 Owner-decision batch (surface; none pauses P4)
- **PRC slotting** (above) · **P0-LIVE-1 provisioning** (R2 · cron token · CI runner · 7-day clock) · **P6-BETA-1 cohort** (5–10 schools) · K-3 promotion timing · pgvector provisioning (optional, enables W2.8) · signed pilot build (owner keystore, at P6).

### EOS gate (per P4 round)
- Each RT round closes on its audit artifact + fixes + full regression (`flutter analyze` 0 · `flutter test` no NEW failures · `deno test`+`deno check` green for touched `supabase/**`) — commit only after the round's EOS PASS.
- **Freeze tripwire (new):** any change in P4/P5 must be classifiable as bug/regression/perf/security/quality/stability — a feature-shaped diff is BLOCKED and routes to P8-GA-5.
- **Standing tripwires:** no behaviour/governance/money/RBAC/isolation regression; goldens deliberate; never start the next wave with an open P0 or EOS BLOCKED.

### Regression required (per wave)
- `deno test` + `deno check` green for touched `supabase/functions/**` · `flutter analyze` 0 · `flutter test` no NEW failures · goldens deliberate-only.

> **Rule:** never begin the next wave with an open P0 or an EOS BLOCKED. Owner-decision (👤) tasks surface in a batch and do not pause the pipeline; live-lane (⏳) items run the moment the owner provisions them.
