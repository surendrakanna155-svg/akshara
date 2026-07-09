# Pilot Readiness Report — Akshara ERP

**Date:** 2026-07-09 · **Branch:** `feature/data-reliability-platform` · **Governing law:** `docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md` (Part 7B/8) · **Canonical state:** `docs/execution/CANONICAL_EXECUTION_BASELINE.md`

**Verdict: CONDITIONAL-GO for a controlled pilot — pending a live deploy + live money-flow cert that are currently blocked on one owner action (open the SSH socket).** The ERP is functionally feature-complete and regression-green locally; what remains before real-school data flows are live-lane activation steps, not feature work.

---

## 1. What is READY (green, evidence-backed)

- **ERP functional surface** — Phase-C modules C0–C21 (Finance, Attendance, Exams, HR, SIS, Transport, Inventory, Library, Communication, Admissions, Parent/Teacher/Principal/Director) built, discovery-closed, tested.
- **Final gap-sweep CLOSED** — 3 P0 + 7 P1 found, **built** (no stubs) + tested + integrated; verify-first discarded 4 false positives. See `docs/GAP_SWEEP_CERTIFICATION.md`.
- **P2 cleanup done** — student-scope RLS read policy (`20260866`), education-only pack-picker gate, report-card real school name, orphaned-screen removal, DS-enforcement regression fixed.
- **Regression green (local):** deno `_shared` 2409/0 · `flutter analyze` 0 · full `flutter test` green (see cert) · targeted module suites green.
- **Live RLS cross-tenant isolation** — previously verified on the VPS: all QA-B rows + 233/233 enforced probes, **zero leaks** (non-destructive).
- **Nightly backup** — verified restorable/GREEN; nightly-cron shell bug fixed earlier.
- **Money-math integrity** — discounts/scholarships reach billing only via finance-owned two-person maker-checker (`finance_fee_reductions`: lockstep + clamp + idempotent), full financial-flow regression passed locally.

## 2. Pilot BLOCKERS (must clear before real-school data)

| # | Blocker | Why it blocks pilot | Owner action to unblock | Severity |
|---|---|---|---|---|
| B1 | **Live deploy** of this session's backend + migrations `20260863–20260866` to `akshara-edge` | The gap-fix endpoints (student 404 fix, timetable-workforce, operations-hub, parent ack, fee-reductions) and their RLS aren't live yet | Open `~/.ssh/akshara-cm.sock` → run `GAP_SWEEP_DEPLOY_AND_LIVECERT_CHECKLIST.md` Part B | **P0** |
| B2 | **Live cert of `finance_fee_reductions`** on `akshara_tenant_test` | Real money reductions must be proven live (RLS/CHECK/partial-unique/FOR-UPDATE + concurrent approve/reverse/clamp) — currently pattern-matched only | Same socket → checklist Part C (non-destructive, rolled back) | **P0** |
| B3 | **Staff Face ID attendance cert** (GPS geofence + anti-mock + live camera face) | If staff attendance is in the pilot's day-1 scope, its live/on-device cert is a Must-Before-GA track | Provide a biometric-enrolled device/emulator + open socket | **P1 (scope-dependent)** |
| B4 | **7-day regression cron green** + COM-4 scheduled-broadcast/reminder cron + off-site R2 (3-2-1) | Reliability/DR completeness for a live tenant | Provide `INTERNAL_CRON_TOKEN` + R2 creds; install crons | **P1** |

**All four are external-dependency blockers (owner/infra), not engineering gaps.** B1/B2 collapse to a single gate: **open the authenticated SSH ControlMaster socket** — the deploy and cert are staged one-command-ready.

## 3. Explicitly NOT a pilot blocker

- **Curriculum repository convergence** (Coverage Matrix, live SSOT owned by the separate acquisition lane) is a dependency of the **Assessment / Curriculum-Intelligence** program (post-pilot, P3-gated), **not** of the ERP pilot. *Reporting law:* "Acquisition engine complete. Curriculum repository still incomplete." The ERP pilot (attendance/fees/exams/comms) runs without it.
- **P3 Adaptive AI**, **P1-CODE-4/6/7/8**, **Assessment Intelligence Platform + Amendment A2** — all post-pilot / owner-gated.

## 4. Critical path to pilot

1. **Owner opens the SSH socket.**
2. Run deploy checklist Part B (migrations → edge → health smoke). ~1 gate.
3. Run live-cert checklist Part C on `akshara_tenant_test` → write `FINANCE_FEE_REDUCTIONS_LIVE_CERTIFICATION.md`.
4. Re-affirm live RLS + `/health/backup` post-deploy.
5. (If staff attendance in scope) run Face ID on-device cert.
6. Activate COM-4 + off-site R2 (owner supplies token + creds); start the 7-day cron watch.
7. **Representative-pass pilot run** on the live lane → then GA gate.

## 5. Bottom line

Engineering is **done and green** for the pilot scope. The gate is **operational, not code**: one owner action (SSH socket) unblocks the deploy + money-flow cert; two credential handoffs (cron token, R2) and one device (Face ID) clear the remaining reliability/attendance items. No feature work stands between here and a controlled pilot.
