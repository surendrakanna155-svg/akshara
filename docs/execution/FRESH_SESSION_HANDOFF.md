# Fresh Session Handoff — 2026-07-14 (rev 2 · post CFC-1 / FREEZE-1 / P4-RT-0 / P4-RT-1 round 1)

**Branch:** `feature/data-reliability-platform` (ERP lane, worktree `Akshara_ERP-drp`) · **Tip:** `d5255c62` · **Tree:** CLEAN (this lane).
**Read this + [`../roadmap/NEXT_ACTIVE_WAVE.md`](../roadmap/NEXT_ACTIVE_WAVE.md) first. Recovery-first — recover, don't recreate.**

---

## 1. What this session did (5 gated waves, all committed)
1. **CFC-1 Code Freeze Checklist — PASS 10/10** (`d59b5762`). Fresh per-item sweep on one commit ([`../engineering/eos/CFC1_CODE_FREEZE_CHECKLIST_EVIDENCE.md`](../engineering/eos/CFC1_CODE_FREEZE_CHECKLIST_EVIDENCE.md)). Fixed 10 real `unnecessary_import` lint-drift infos in `test/**` a prior "analyze 0" had missed. Regression: flutter **+3957 ~1** (exit-0 captured), analyze **0**, deno **2864/0**.
2. **FREEZE-1 Feature Freeze — DECLARED** (`533a0437`) under the owner-approved **K-lane carve-out** ([`../engineering/eos/FREEZE1_FEATURE_FREEZE_DECLARATION.md`](../engineering/eos/FREEZE1_FEATURE_FREEZE_DECLARATION.md)). ERP scope = bug/regression/perf/security/quality/stability ONLY; features → P8-GA-5. Recomputed the overdue §0b Wave Ledger → **73.5%**. **Preserved the PRC program into git** (was stranded uncommitted on the K checkout); deferral recorded in the tracker's §7 conflict register.
3. **P4-RT-0 Red Team prep — READINESS PASS** (`76dcb5d7`, [`../strategy/RED_TEAM_P4_RT0_READINESS.md`](../strategy/RED_TEAM_P4_RT0_READINESS.md)): honest-claims baseline frozen, 12 domains scoped, post-W2 attack seeds refreshed (anchored to real code).
4. **P4-RT-1 round 1 (static surface) + P5 fixes** (`d5255c62`, [`../strategy/RED_TEAM_P4_RT1_ROUND1_REPORT.md`](../strategy/RED_TEAM_P4_RT1_ROUND1_REPORT.md)). 5 model-tiered operators, orchestrator-verified. **3 P0/P1 found + FIXED + regression-locked** (edge code, no migration): refund double-approve **P0**, duplicate zero-dues TC **P1**, collection-cancel double-reverse **P1**. +3 race tests, deno **2867/0**. Domains 1+2 clean.

## 2. Roadmap state now
- **Phase:** 🔒 FREEZE-1 in force → **P4 Red Team, RT-1 round 1 done, round 2 pending.** Derived progress **73.5%** (61/83, §0b).
- **P4-RT-1 round 2 (round law — needs *consecutive* clean rounds):** re-audit the fixed money/TC paths + statically-unrun domains (UX/workflow/ops/DR/perf/human-error), **plus the live legs** (concurrent cross-tenant / DR / ops on `akshara_tenant_test`) — those need the owner to re-establish the SSH control-master.
- Then P5 (close remaining findings) → P6-VAL → PILOT → BETA → P7 → P8. **PRC-A/PRC-B** (deferred) must slot before P6-VAL-1.

## 2b. RT-1 round 2 — LIVE legs DONE (2026-07-14, VPS restored) — `7cc70397`
Isolation/Ops/DR confirmed live on prod, **0 new P0/P1** (report §Round 2): edge NOBYPASSRLS + 8 new tables FORCE-RLS; backups healthy (11 nightly/2 weekly/1 monthly, all success) — a candidate ops finding was refuted (my `ORDER BY uuid` query bug); off-site LOCAL-ONLY + empty DR drill.log tracked. New tables EMPTY on prod → the data-bearing positive cross-tenant probe + live money-race re-verify are deferred until (a) the pilot has data and (b) the fixes deploy. **SSH control-master is now UP** (`~/.ssh/akshara-cm.sock`, owner-established; use `ssh -S ~/.ssh/akshara-cm.sock root@46.28.44.46` + dangerouslyDisableSandbox).

## 3. Open items carried forward
**✅ RT-1 fixes DEPLOYED to prod edge (2026-07-14, owner GO)** — edge `9bbf8630`→**`67f57ef2`**, surgical 3-file no-migration deploy, verified (guards live, `database:true`, n8n untouched). See `DEPLOY_CHECKPOINT_20260714_RT1_FIXES.md`. The P0 refund double-approve + 2 P1s are closed on prod. Rollback point: `/opt/akshara/functions_bak_predeploy_20260714_rt1`.
**Still pending (next window / owner):** RT-9-2 waiver FK/CHECK migration (P2, latent — the only pending schema change) · RT-4-1 parent_insights AI number-guard (P2) · the data-bearing isolation positive probe + live money-race re-verify once the pilot has data · off-site R2 backup + 7-day cron clock (LIVE-1 owner items).

**Tracked findings (not yet fixed):**
- **RT-4-1 (P2, parent-facing, fix-before-GA):** `parent_insights_ai.ts` calls the model with no determinism number-guard. **Correct fix = enable the percent-checking guard (NOT `allowDerivedPercents:true`, which skips it) after verifying the injected context carries the percents verbatim, with a dedicated test.** → P5.
- **RT-9-2 (P2, latent):** `student_clearance_waivers` missing FK on `student_id` + FK/CHECK on `maker_id`/`checker_id` → corrective migration in the next deploy window.
- **RT-4-2 (P3):** copilot per-role daily quota TOCTOU (cost hard-bounded) → pilot quota tuning.
- Informational: reservations org-only RLS (add school clause if a school-scoped API is ever added); empty-actor SoD short-circuit (defense-in-depth).

## 4. Owner decisions pending (none block round-2 static work)
1. **Re-establish the SSH control-master** — `ssh -fN -M -S ~/.ssh/akshara-cm.sock -o ControlPersist=12h root@46.28.44.46` (key-only auth is refused; the socket was password-established). Gates RT-1 round-2 live legs + the next edge deploy.
2. **PRC slot** — where PRC-A/PRC-B run (recommended with/after P4-RT-1, before P6-VAL-1). Tracker §7 records the deferral.
3. **P0-LIVE-1 provisioning** — off-site R2 (backup LOCAL-ONLY), `INTERNAL_CRON_TOKEN`, CI runner, **7-day cron clock** (gates P7).
4. **P6-BETA-1 cohort** (5–10 schools) · pgvector (optional, W2.8) · signed pilot build (owner keystore, P6).

## 5. Standing rules
- **K lane HANDS-OFF** — `curriculum/**` + branch `feature/qp-content-readiness` (main worktree, local-only) is the carved-out parallel lane. Never touch it from here; `git add` specific ERP files only.
- **VPS = shared prod** — Akshara namespace only; never touch velora-salon/n8n/redis. Destructive RT probes on `akshara_tenant_test` ONLY.
- One wave, one EOS gate, one commit, one journal row. Never start the next wave with an open P0. Post-freeze: any feature-shaped diff is BLOCKED → P8-GA-5.
