# Certification & Stabilization — Program State

**Mode:** autonomous. Report and roadmap are internal artifacts, NOT stop points.
**Updated:** 2026-07-29

## 🚩 PRE-LAUNCH GATE — APP_ENV (owner-ratified 2026-07-29)

`APP_ENV=staging` on the pilot, **deliberately, by owner decision**. It is to be
switched to `production` only at final production rollout, after pilot completes.

**This is a hard gate before ANY real pupil data is loaded.** Flipping it also
enables `requireTls` + `requireAuthentication` and disables demo-auth, which
stops OTP-in-response for the 6 allowlisted pilot testers — they will need real
SMS delivery from that moment. Plan that switchover; do not discover it.

Current exposure is bounded and accepted: `AUTH_OTP_DEV_MODE=false` (so the OTP
path is limited to those 6 numbers, not general) and the database holds 10
schools / 5 students — demo scale.

After flipping, run `deploy/akshara-vps/verify-deployment-security.sh
https://api.nikshaos.in` and confirm login still works before announcing.

## Lifecycle position

```
Engineering RC ✓ → Certification cycle 1 (IN PROGRESS) → Root cause analysis →
Remediation roadmap → Implement → Regression per wave →
FULL re-certification (cycle 2) → repeat until a cycle passes clean →
PRODUCT CERTIFICATION COMPLETE
```

## Cycle 1 workstreams

| WS | Status | Verdict |
|---|---|---|
| 1 Feature inventory | ✅ | 28 modules / 350 features · 283 LIVE · 44 HIDDEN · 19 DEAD |
| 3 Role journeys | ✅ | NOT CERTIFIED |
| 3A School simulation | ✅ | NOT CERTIFIED |
| 4 Cross-module | ✅ | NOT CERTIFIED |
| 5 DAI | ✅ | NOT CERTIFIED |
| 6 Widgets | ✅ | NOT CERTIFIED |
| 2 End-to-end features | ✅ | NOT CERTIFIED |
| 7 API | ✅ | see findings |
| 8 AI suite (6 sub-suites) | ✅ | see findings |
| 9 Polish | ✅ | see findings |
| 10 School-OS coherence | ✅ | see findings |

**CYCLE 1 CERTIFICATION COMPLETE — all 11 workstreams done. NOT CERTIFIED.**
Register: **196** (36 P0 · 104 P1 · 50 P2 · 6 P3) — counts recomputed
mechanically from headings, not incremented by hand (the table had drifted
under concurrent appends; the method is documented inline in the register).

### Fifth systemic item — one truth per quantity does not exist
Canonical shared state is the **exception, not the rule**: 1 of 13 cross-module
quantities (attendance-%, whose own header says it was a one-off remediation).
Against that: **4 definitions of "student count" — and billing uses the
unfiltered one**; two grading scales that disagree at 35% (server says F, the
report card says D); 3 definitions of "collected"; and **no academic-year
resolver at all** — 66 hard-coded literals, in two different dash characters.
This is the root of the School-OS verdict. Fix the resolver and the canonical
counts before wiring anything new on top of them.

### ⚠️ LIVE PRODUCTION SECURITY — verify before any pilot use (API-105/107/108)
Found by read-only probes against the deployed pilot, NOT inferred from code:
* **API-105** — the deployed pilot has **no central auth chokepoint**. Anonymous
  requests get 404/422, not 401. `eng4_5_forced_auth_test` asserts ICA-F1 makes
  these 401 — that is a REPO property, not a production one. The deployed build
  is behind the repo.
* **API-107** — `/health/*` answer the internet unauthenticated, leaking school
  count, backup SHA-256 and the isolation matrix. The guard keys off the SAME
  `APP_ENV` flag that puts login OTPs in the response body. Needs an owner env
  check — could not be tested from here.
* **API-108** — the pilot's own isolation matrix is **RED NOW**: 4 student-scope
  probes fail. School-to-school and parent-to-child pass, so it is a persona
  boundary failure, not a tenant leak.
These three are the only findings in the whole register about the RUNNING
system rather than the code. Treat accordingly.

### Fourth systemic item — the RBAC inventory is not a gate
**97 mutating routes absent** from `rbac_route_inventory.ts` (incl.
`POST /finance/collections`, `/finance/refunds`, every `/approvals/:id/approve`,
all exam mark writes) and **91 stale rules**. The RBAC suite only calls
`requirePermission()` on the inventory itself — it never dispatches a route — so
an unlisted ungated route passes silently. The two attendance routes found in RC
were not an outlier; they were a sample.

### ⚠️ REMEDIATION ORDERING CONSTRAINT — do not lose this (AI-001)
**DAI-005 and DAI-016 are load-bearing on each other.** `openPerson` being
structurally unreachable is the ONLY thing currently hiding 34 wrong answers —
the `_person` rule is last and swallows the whole out-of-vocabulary space
(`payroll`, `timetable`, `gate pass` → "Looking for Payroll…"). **Fixing DAI-005
alone makes the product visibly worse.** The AI harness enforces this ordering
and fails if `openPerson` gains a route while the drawer is still open. Fix them
together or not at all.

### Third systemic item (from WS2)
**Dates stored as display labels.** Five modules persist a human string where a
real date column sits unused on the same row — the shared root of E2E-004,
E2E-008, E2E-014, E2E-018, E2E-020. The fee counter literally sends `'Today'`,
so the closed-day guard compares lexically and never fires, and parents' receipts
read `SCH/NaN-NaN/000042`. One remediation item, not five.

### Honest coverage gap
WS2 did not reach alumni, control centre, director, multi-school. Cycle 2 must.

## THE systemic finding — treat as ONE remediation item, not many

**Fabricated data reaching production renders. Seven independent discoveries:**
the `SUP-####` support ticket (RC) · `/parent/fees` ₹23,000 statement (CERT-001)
· parent + teacher dashboards rendering `.mock()` on EVERY load (WIDGET-001/002)
· principal health score 51 from hard-coded parts (WIDGET-011) · `/admin` hero
"1,248 Students · ₹4.2L Collected" to 6 of 15 roles (JOURNEY-001) ·
`/parent/payment` fabricating a child's name and ₹4,200 **and sending it to the
initiate endpoint** (JOURNEY-007).

It is a habit — demo data used as a production fallback — not seven bugs. The
root-cause analysis must address the pattern, and remediation should establish a
mechanical guard so it cannot return, not just fix six screens.

## Second-priority systemic item

**Privilege fallback inverts.** An unrecognised server role resolves to
`ErpRole.superAdmin` (`auth_mapper.dart:63-66`), with a contradictory
`?? ErpRole.parent` on the restore path. Server defines 29 roles, client 15. A
fallback must default to LESS access. Pull forward with CERT-001.

## Standing rules (do not relitigate)

- Fabricated financial / attendance / exam / certificate / legal data = **always P0**.
- Defects are RECORDED during certification; only obviously-correct production-safe
  fixes inline.
- Never record a check that did not run. "Could not verify X" is a valid finding.
- Corrections to earlier findings are recorded, never silently amended.

## ⛔ PAUSED — Critical Security Finding on the live pilot (2026-07-29)

Remediation has NOT started. API-105/107/108 were verified by unauthenticated
read-only probe and are **CONFIRMED on the deployed pilot**: four `/health/*`
endpoints answer the internet with operational data, `/attendance/register/monthly`
validates before authenticating, and `/health/tenant-access` reports
`isolation.pass: false` right now.

Whether that instance holds REAL school data could not be determined without
authenticating, which was not attempted. That answer sets the severity and is an
owner decision. See `CRITICAL_SECURITY_FINDING_LIVE.md`.

Per instruction, the program pauses here for owner review before any
infrastructure decision. Phase 1 Wave 1 is ready to start on that signal.

## Roadmap complete — remediation is the next action

`SYSTEMIC_REMEDIATION_ROADMAP.md` (2,760 lines, 42 waves, Phases 1–4).
Mechanically verified: all 196 register IDs assigned exactly once — 190 to
waves, 4 to the owner track, 2 excluded. Zero duplicates, zero unassigned.

**Correction to my own framing, recomputed not asserted:** the five systemic
causes account for **84 of 196** entries and **21 of 36 P0s** — not the 95/31
I implied when naming them. The other 15 P0s are residual security / data /
financial defects scheduled by severity. Every P0 lands in Phase 1–3 or the
owner track; **none** is in Phase 4.

**Third ordering constraint, found while sequencing:** POLISH-011 must precede
POLISH-003/004/012/017/021, or Finance, SIS and Admissions are silently
excluded from every Phase 4 fix by the three forked async bodies.

**Every wave must ship a guard** (lint / invariant / contract test). This is
non-negotiable and is the lesson of cycle 1: the RC phase fixed one skeleton
of six, one exception dump of 23, one tap target in a file with three more,
and four dashboard holes of ten. A wave that fixes instances without a guard
has not closed its class.

## Resume instructions

1. `git add docs/certification/ && git commit` — pick up any agent output written
   after the last commit.
2. Read this file, then the charter, then `DEFECT_REGISTER.md`.
3. Finish any workstream still marked running.
4. Then: root cause analysis → roadmap → remediate → regression → full cycle 2.

## Verification boundaries (unchanged, inherited)

No Postgres lane · SSH owner-bound · release binaries cannot run locally
(`guardForRelease`) · payments stubbed · no live SMS/push in dev.
