# Session Handoff — 2026-07-09 (fresh session starts here)

**Canonical reference:** `docs/execution/CANONICAL_EXECUTION_BASELINE.md` (read it first). Registry: `docs/execution/AGENT_REGISTRY.md`. This handoff = what's in-flight + the exact next steps.

## 0. Fix wave is DONE — start at step 1
The gap-remediation wave (3 P0 + 7 P1, `docs/execution/GAP_REMEDIATION_WAVE.md`) is **fully built + integrated** onto the feature tip (all 6 agent commits cherry-picked; worktrees cleaned; the two duplicate `20260864000000` migrations were split — inventory-replacement keeps it, operations-hub-item-actions became `20260865000000`). Re-cert GREEN: deno `_shared` **2409/0**, `flutter analyze` 0, goldens 70/70. Verify on resume: `git rev-parse HEAD` is a descendant of `bea918c2`; `git worktree list` = main only. If a full `flutter test` was still running at handoff, confirm `/tmp/recert_flutter.log` ended "All tests passed!".

## 1. Sequence from here
1. **Confirm the full `flutter test`** (should be ~3800/0) — the wave touched onboarding/operations client + tests.
2. **Gap-sweep CERTIFICATION** — the sweep is now CLOSED (all P0+P1 fixed + regression green); write the cert doc.
3. **P2 cleanup pass** — the ~13 P2 items in `GAP_REMEDIATION_WAVE.md` **P2 list** (dead-code removals: vault-rotate/school-calendar/widgets-refresh/DynamicDashboardScreen/orphaned catalog widgets/social-router/memories-analytics/setup-wizard-session · report-card PDF school-name (parent+student_app) · gate the Salon/Hospital vertical-pack picker · honest alumni KPI already done · **new: `student_profiles`/`student_guardians` need a student-scope RLS read policy** so student profile fields populate). Remove dead code / fix cosmetics; build only what's cheap.
4. **Update the baseline** (`CANONICAL_EXECUTION_BASELINE.md`) — the wave restored ERP wiring; re-affirm with evidence, keep qualitative labels (no subjective %).
5. **Priority 3 — live deploy prep:** deploy this session's new backend to `akshara-edge` (fee-reductions `20260863` + COM-4 token + the gap-wave migrations `20260864`/`20260865`); off-site backup activation (R2 creds pending); migration verification. Runbooks in `docs/engineering/eos/`.
6. **Priority 4 — live-cert checklist (non-destructive VPS):** apply+cert `finance_fee_reductions` on `akshara_tenant_test` (concurrent approve/reverse/clamp); re-affirm RLS + backup.
7. **Priority 5 — Pilot Readiness report** with remaining blockers.

## 2. STANDING RULES (do not violate)
- **Curriculum lane = SEPARATE session — HANDS-OFF.** Never touch `curriculum/` or `scripts/acquisition/run_acquisition.py`. It owns that working state (leaving `curriculum/*` uncommitted is expected). Wording: **"Acquisition engine complete. Curriculum repository still incomplete"** (matrix 10.1%, 74/736 — authoritative in `curriculum/reports/COVERAGE_MATRIX.md`). When committing, `git add` SPECIFIC ERP files only — never `-A` (it would stage the curriculum lane's state).
- **P3 Adaptive AI = GATED** until gap-sweep closed + live deploy prep + live cert + pilot readiness verified. Do NOT open it.
- **Policies:** verify-first (caught 4 false positives this session — Management placeholder, mgmt-resolve, SIS academic-assignment, admissions generate-number; a "gap" must trace to a REACHABLE broken behavior) · recovery-first · worktree isolation (base-verify onto the tip, never `main`) · model tiering (sonnet for builds; opus only for money/architecture) · non-destructive production verification · **report only meaningful milestones**.
- **VPS (shared production):** `ssh -S ~/.ssh/akshara-cm.sock root@46.28.44.46 '<cmd>'` (needs `dangerouslyDisableSandbox: true`). Co-hosts velora-salon/n8n/redis — **Akshara-only, never touch them.** Tenant DB `akshara-postgres` (`akshara_db` prod, `akshara_tenant_test` for rolled-back/non-destructive certs). No secrets in the repo. See `[[vps-access-live-lane]]`.

## 3. What this session delivered (all committed, green)
Gap-sweep waves 1+2 (SoD P0s, money-math, attendance-% canonical, wiring, Inventory Replacement, discounts→billing maker-checker) · live RLS all-pass (zero leaks) · backup GREEN · off-site R2 + COM-4 token staged · canonical baseline · final gap-discovery (found 3 P0 + 7 P1 + P2 → the in-flight fix wave). HEAD at handoff-write: `ad28f603`.

## 4. Owner-gated / tracked follow-ups
P3 Adaptive AI · P1-CODE-4/6/7/8 · Assessment Intelligence Platform + Amendment A2 · fee-reduction live-cert + client propose-award flow + Approval-Center type · COM-4 per-school scheduled-broadcast RLS (P2) · exam-override client polish · off-site R2 creds + COM-4 deploy activation.
