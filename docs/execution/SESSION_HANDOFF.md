# Session Handoff — 2026-07-09 (fresh session starts here)

**Canonical reference:** `docs/execution/CANONICAL_EXECUTION_BASELINE.md` (read it first). Registry: `docs/execution/AGENT_REGISTRY.md`. This handoff = what's in-flight + the exact next steps.

## 0. Steps 1–4 + 7 DONE (2026-07-09, commit `db54ed0c`) — resume at the SSH-gated live lane
Local work is COMPLETE and regression-green. The gap-remediation wave (3 P0 + 7 P1) is built + integrated; **re-cert caught + fixed one DS-enforcement regression** the wave had introduced (raw `TextStyle` in `onboarding_hub_screen.dart` — the earlier "~3800/0 green" claim was optimistic; the real result was `+3765 -1`). **P2 cleanup CLOSED**, cert + baseline + pilot-readiness written. Regression: deno `_shared` **2409/0** · `flutter analyze` **0** · full `flutter test` **3766/0** (1 skipped) · goldens 70/70.

Done this session: (1) ✅ full flutter confirmed green after DS fix · (2) ✅ `docs/GAP_SWEEP_CERTIFICATION.md` (EOS gate PASS) · (3) ✅ P2 — new RLS migration `20260866` (student-scope read on `student_profiles`/`student_guardians`), report-card real school-name, education-only vertical-pack gate, orphaned `DynamicDashboardScreen` removed; verify-first KEPT 6 reachable/no-UI "dead code" candidates · (4) ✅ baseline updated · (7) ✅ `docs/PILOT_READINESS_REPORT.md`.

## 1. Resume here — PROD DEPLOY is the one remaining action (owner-go-gated)
**Socket was opened 2026-07-09; the test-tenant rehearsal + live cert are DONE. Prod is intentionally PAUSED (owner chose test-tenant-first).**

What happened this session on the live lane:
- **Scope correction:** prod `akshara_db` + edge are **44 migrations / 8 days behind HEAD** (`20260818` / `bcebbf12`), so the deploy is the **full backlog** (`20260819…20260866`), not just this session's 4.
- **Deploy blocker caught + FIXED:** `20260838` dropped `'all_staff'` from `comm_broadcasts_audience_check` (violated by existing prod rows → halts a sequential run). Fixed in `ab11db99`. Full backlog then applied cleanly on `akshara_tenant_test` (now at `20260866`, a faithful mirror).
- **`finance_fee_reductions` DB-level live cert PASSED** on `akshara_tenant_test` (non-destructive, rolled back): RLS school-scope + all CHECK + partial-unique enforce live. See `docs/FINANCE_FEE_REDUCTIONS_LIVE_CERTIFICATION.md` + harness `scripts/qa/live_cert_fee_reductions.sql`.
- **PROD untouched** (still `20260818`, no fee_reductions table; edge still `bcebbf12`).

Remaining (needs owner GO for prod, socket may need reopening):
- **Prod deploy** — `GAP_SWEEP_DEPLOY_AND_LIVECERT_CHECKLIST.md` Part B: apply the full backlog to `akshara_db` (a predeploy backup is taken), copy `supabase/functions` → `/opt/akshara/functions`, restart `akshara-edge`, health smoke (version==HEAD). The tenant_test rehearsal already de-risks this.
- **Post-deploy:** app-level E2E of fee-reductions approve/reverse/clamp through the live edge (the one cert item DB-level can't cover); COM-4 cron + off-site R2 activation (owner token + creds); Face ID on-device cert; then pilot run → GA.

## 2. STANDING RULES (do not violate)
- **Curriculum lane = SEPARATE session — HANDS-OFF.** Never touch `curriculum/` or `scripts/acquisition/run_acquisition.py`. It owns that working state (leaving `curriculum/*` uncommitted is expected). Wording: **"Acquisition engine complete. Curriculum repository still incomplete"** (matrix 10.1%, 74/736 — authoritative in `curriculum/reports/COVERAGE_MATRIX.md`). When committing, `git add` SPECIFIC ERP files only — never `-A` (it would stage the curriculum lane's state).
- **P3 Adaptive AI = GATED** until gap-sweep closed + live deploy prep + live cert + pilot readiness verified. Do NOT open it.
- **Policies:** verify-first (caught 4 false positives this session — Management placeholder, mgmt-resolve, SIS academic-assignment, admissions generate-number; a "gap" must trace to a REACHABLE broken behavior) · recovery-first · worktree isolation (base-verify onto the tip, never `main`) · model tiering (sonnet for builds; opus only for money/architecture) · non-destructive production verification · **report only meaningful milestones**.
- **VPS (shared production):** `ssh -S ~/.ssh/akshara-cm.sock root@46.28.44.46 '<cmd>'` (needs `dangerouslyDisableSandbox: true`). Co-hosts velora-salon/n8n/redis — **Akshara-only, never touch them.** Tenant DB `akshara-postgres` (`akshara_db` prod, `akshara_tenant_test` for rolled-back/non-destructive certs). No secrets in the repo. See `[[vps-access-live-lane]]`.

## 3. What this session delivered (all committed, green)
Gap-sweep waves 1+2 (SoD P0s, money-math, attendance-% canonical, wiring, Inventory Replacement, discounts→billing maker-checker) · live RLS all-pass (zero leaks) · backup GREEN · off-site R2 + COM-4 token staged · canonical baseline · final gap-discovery (found 3 P0 + 7 P1 + P2 → the in-flight fix wave). HEAD at handoff-write: `ad28f603`.

## 4. Owner-gated / tracked follow-ups
P3 Adaptive AI · P1-CODE-4/6/7/8 · Assessment Intelligence Platform + Amendment A2 · fee-reduction live-cert + client propose-award flow + Approval-Center type · COM-4 per-school scheduled-broadcast RLS (P2) · exam-override client polish · off-site R2 creds + COM-4 deploy activation.
