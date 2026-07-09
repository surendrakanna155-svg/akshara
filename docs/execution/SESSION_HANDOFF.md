# Session Handoff — 2026-07-09 (fresh session starts here)

**Canonical reference:** `docs/execution/CANONICAL_EXECUTION_BASELINE.md` (read it first). Registry: `docs/execution/AGENT_REGISTRY.md`. This handoff = what's in-flight + the exact next steps.

## 0. FIRST ACTION on resume — recovery-first (a fix wave is in flight)
6 worktree fix agents were launched (base `ad28f603`) for the gap-remediation wave (`docs/execution/GAP_REMEDIATION_WAVE.md`). They may have finished or been killed mid-run when the session ended. Do this:
1. `git worktree list` and `git branch --list 'worktree-agent-*'` — find the fix-wave worktrees/branches.
2. For each that has a **committed** result (`git log <branch>`), **cherry-pick it onto the current feature tip** (`feature/data-reliability-platform`), verify (`deno test`/`flutter analyze` on the touched module), then `git worktree remove` + delete the branch. They are DISJOINT modules → cherry-picks should be clean.
3. For any that did NOT finish (no commit / partial), **re-run that one item** as a fresh worktree agent from the spec in `GAP_REMEDIATION_WAVE.md`.
4. The 6 items (module → gap): entity_read/pilot → student-snapshot P0 · school_completion → 5 timetable endpoints P0 · inventory_distribution → replacement-RLS P0 · admissions+alumni → fee-structures + reports P1 · communication/parent/whatsapp → parent msg/ack + WhatsApp honesty P1 · operations+onboarding → dismiss/complete + invite P1.

## 1. Sequence after the fix wave is integrated
1. **Re-run full regression** (Step 6 re-cert): `cd supabase/functions && deno test -A _shared/` (expect ~2331+/0) · `flutter analyze lib` (0) · `flutter test test/golden/` (70/0) · optionally full `flutter test`.
2. **Gap-sweep CERTIFICATION** — write the cert; the sweep is CLOSED only when all P0+P1 fixed + regression green.
3. **P2 cleanup pass** — the ~13 P2 items listed in `GAP_REMEDIATION_WAVE.md` (dead-code removals, report-card PDF school-name, gate the vertical-pack picker, honest KPIs, etc.). Remove dead code / fix cosmetics; build only what's cheap.
4. **Update the baseline** — ERP status was over-optimistic; downgrade with the fix-wave evidence.
5. **Priority 3 — live deploy prep:** fee-reductions migration (`20260863`) + COM-4 token path deploy to `akshara-edge`; off-site backup activation (R2 creds pending); migration verification. Runbooks staged in `docs/engineering/eos/` (COM4_CRON_ACTIVATION_RUNBOOK, OFFSITE_BACKUP_R2_RUNBOOK).
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
