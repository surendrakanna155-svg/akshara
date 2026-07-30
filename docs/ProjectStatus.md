# Akshara ERP — Project Status

**Last updated:** 2026-07-04
**HEAD commit:** `68f15cb`
**Phase:** P0 — Truth · Documentation · Live Verification (autonomous execution, planning frozen)
**Single source of truth:** [`roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md`](roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md) ·
state in [`execution/EXECUTION_DASHBOARD.md`](execution/EXECUTION_DASHBOARD.md) ·
journal in [`execution/IMPLEMENTATION_PROGRESS.md`](execution/IMPLEMENTATION_PROGRESS.md).

> **Read this first.** An earlier version of this file (dated "June 2026", HEAD `42b7018`) listed
> Admissions / Finance / HR / Transport / SIS / Management etc. as *"not started in Flutter."* That
> was **stale by dozens of completed module waves** and has been corrected here (finding DOC-1). The
> project is far past the academic MVP: it is a broad, multi-module ERP whose **engineering is
> local-complete** and whose **remaining gate is live verification on real infrastructure** (Track B),
> followed by Red-Team → Pilot → Production Certification → GA.

---

## 1. Where the project actually is

| Dimension | State (HEAD `68f15cb`) |
|---|---|
| **Product surface** | 47 feature modules in [`lib/features/`](../lib/features/) (Admissions, Finance, HR, Transport, SIS, Academics, Exams, Attendance, Homework, Communication, Library, Inventory, Hostel, Alumni, Parent, Teacher, Student, Director, Management/Principal, Onboarding, Staff-Attendance, Adaptive-AI/Intelligence, Platform, …) — **885 Dart files**, ~**607 routed screens**. |
| **Backend** | Self-hosted Supabase edge (single `supabase/functions/api` request-router monolith) + `_shared` domain modules; **168 SQL migrations**; live on the VPS pilot (`api.nikshaos.in`). |
| **Tests** | **632 test files** (widget/unit/contract/route); backend Deno suites; live-cert Python scripts under `scripts/qa/`. `flutter analyze` = **0** (verified live 2026-07-03). |
| **Engineering maturity** | **Local-complete** across the module set (client + backend + migrations + RBAC + tests). Not yet **production-certified**. |
| **Readiness** | **Pre-pilot.** GA is **blocked** on live Track-B verification, one Global Red Team, a full pilot simulation, and Production Certification — see §4. |

**Honesty note (finding DOC-4).** This document uses **evidence grades** and does not restate the
older certification-era superlatives ("237 Verified", "universal idempotency", "PRODUCTION CERTIFIED
platform"). Where a capability is claimed, its grade says how strongly it is proven:

| Grade | Meaning |
|---|---|
| **LIVE** | Exercised against the live VPS + tenant Postgres with real auth/RBAC/RLS. |
| **LOCAL-LOGIC** | Business logic proven by local unit/widget/contract tests (no live DB). |
| **CONTRACT** | Route/permission contract asserted (e.g. 503-when-authorized), DB-free. |
| **RENDER-MOCK** | UI renders against a mock/in-memory source; backend wiring pending or thin. |
| **STAGED** | Harness/fixtures authored and ready, but not yet run for real (awaits live lane). |

The historical batch/QW certifications (B1–B11, QW1–QW8) remain in `archive/` as **frozen history**;
they are **not** re-asserted here. The live re-proof of every critical claim is scheduled work in
Phases P0/P6/P7, not a completed fact.

---

## 2. Module status (client · backend · evidence)

Grades reflect the strongest evidence currently on record; the P0/P6/P7 waves upgrade the critical
ones to **LIVE**. "Built" = client screens + providers + backend handlers + migrations present and
passing local suites.

| Domain | Client | Backend | Strongest evidence | Notes |
|---|---|---|---|---|
| Admissions / CRM | Built | Built | LOCAL-LOGIC + prior LIVE (archived) | Marketing→CRM→AI handoff wired. |
| Finance (fees/invoices/receipts/concession) | Built | Built | LOCAL-LOGIC | Money `row_version` guard hardening = **P0-CODE-1**; recovery CRM = P1-PROD-1. |
| Exams / Assessment | Built | Built | LOCAL-LOGIC | Result-status model frozen (AB/ML/DB = NULL, excluded from stats). |
| Attendance (student) | Built | Built | LOCAL-LOGIC | — |
| Staff Attendance (GA track) | Built | Built | STAGED | GPS geofence + anti-mock + live-camera face (P1-PROD-22). |
| HR / Payroll | Built | Partial | LOCAL-LOGIC | Payroll run-generation engine = **P1-CODE-5**. |
| Transport | Built | Built | LOCAL-LOGIC | Raises fee demand; Finance is sole payment engine. |
| SIS / Student identity | Built | Built | LOCAL-LOGIC | Public Student ID + admission-# (identity platform, frozen design). |
| Homework | Built | Built | LOCAL-LOGIC | Slice A/B complete. |
| Communication | Built | Built | LOCAL-LOGIC | Deterministic parent-comms localization (catalog, no LLM). |
| Library / Inventory / Hostel / Alumni | Built | Built / Partial | LOCAL-LOGIC / RENDER-MOCK | Cross-module Finance posting = **P1-CODE-6** (👤 real-vs-label). Hostel/Alumni scope = 👤 owner. |
| Parent / Teacher / Student apps | Built | Built | LOCAL-LOGIC | Beyond v0.2: messages, report cards, certificates, submissions, AI surfaces. |
| Director / Management / Principal | Built | Built | LOCAL-LOGIC | Multi-school aggregation, board packs. |
| Onboarding / Dynamic config | Built | Built | LOCAL-LOGIC + prior LIVE (archived) | Capability-gating drives per-school module set. |
| Adaptive AI / Intelligence | Built | Foundation pending | RENDER-MOCK / STAGED | Gateway hardening (cache/rate-limit/timeout/injection) = **P3-AI-1**; per-school adaptation = P3-AI-2. |
| Platform / Entitlements / Widgets | Built | Built | LOCAL-LOGIC | Capability + entitlement gating live-enforced (audit-verified). |

*A handful of thin/backend-less surfaces (~8, ENG-3/MOD-4) are reachable-mock and are handled by
**P0-CODE-2** (hide-list, 👤 owner). Do not read RENDER-MOCK as production-ready.*

---

## 3. Verified baseline (audit, live 2026-07-03 — do not re-run)

These were proven live during the Fable independent audit and recorded as the execution baseline
([`audits/11_LIVE_VPS_VERIFICATION_ADDENDUM.md`](audits/11_LIVE_VPS_VERIFICATION_ADDENDUM.md),
[`audits/AUDIT_FINDINGS_LEDGER.md §A`](audits/AUDIT_FINDINGS_LEDGER.md)):

- Cross-tenant **RLS isolation** (read + write, cross-tenant/cross-school/parent) — **PASS**.
- Edge connects as `erp_tenant` (`NOBYPASSRLS`) — confirmed.
- **Entitlement enforcement ON** (`ENTITLEMENT_ENFORCEMENT=true`).
- Automated **encrypted nightly backups** + monthly **restore drill** — running + passing (184 tables).
- **Watchdog** monitoring — running (5-min cadence, green).
- **AI live** via OpenRouter (key present).
- Live tenant DB password **rotated** (≠ git default).
- `flutter analyze` — **0 issues**.

*(Regression/hardening tasks exist to make these permanent — e.g. RLS suite into CI = P0-TEST-2,
`erp_tenant` deploy-assert = P0-INFRA-6 — but the facts above need no re-verification to proceed.)*

---

## 4. What stands between here and GA

Execution is autonomous, one EOS-gated wave at a time, per
[`roadmap/AUTONOMOUS_EXECUTION_PLAN.md`](roadmap/AUTONOMOUS_EXECUTION_PLAN.md). Phase order is strict:

```
P0  Truth · Docs · Live Verification   🔴 (gates everything)  ← current
P1  Backend & Code fixes + module waves 🟠
P2  UI/UX                               🟠
P3  Adaptive AI (foundation → adaptive) 🟡
P4  Global Red Team                     🔴
P5  Red Team Fixes                      🔴
P6  Pilot Simulation (single + 3-school)🔴 → PILOT-READY
P7  Production Certification            🔴 (QA-R-012 + 7-day cron green)
P8  GA Readiness & Launch               🔴 → GA DECLARED
```

**Current wave:** P0 · W1 — Documentation Truth (this pass). The long pole is the **owner-provisioned
live lane** (VPS SSH, tenant Postgres, CI runner on the branch): it gates every **LIVE**-graded item,
and the 7-day certification cron clock (a P7 prerequisite) only starts when P0-TEST-3 runs for real.

---

## 5. Release history (frozen)

| Version | Tag | Scope | Status |
|---|---|---|---|
| v0.1 Foundation | `v0.1-foundation` | Theme, auth, initial parent dashboard/fees/attendance | ✅ Released |
| v0.2 Academic MVP | `v0.2-academic-mvp` | Parent PA-01–12, Teacher TA-01–07, Student ST-01–07 | ✅ Released |
| — post-v0.2 module build-out | — | Full multi-module ERP (Admissions→Director), backend + migrations, QW1–QW8 QA waves, B1–B11 batches | ✅ Local-complete (see §2) |
| v1.0 GA | — | Live-verified, Red-Teamed, pilot-proven, production-certified platform | ⏳ Gated on P0→P8 |

*The v0.3–v0.6 "MVP" milestones in the old status file are **superseded** — those modules are built;
the remaining ladder is the P0→P8 phase plan above, not per-module MVP releases.*

---

## 6. Architecture summary

```
lib/
├── features/            # 47 domain modules (admissions, finance, hr, transport, sis, exams,
│                        #   academics, communication, library, inventory, hostel, alumni,
│                        #   parent, teacher, student_app, director, management, onboarding,
│                        #   staff_attendance, intelligence/adaptive-ai, platform, …)
├── router/              # GoRouter + role guards + navigation handlers (~607 routes)
├── shared/              # reusable Akshara widgets, offline read-cache, reliability writer
└── theme/               # M3 design tokens / design system

supabase/
├── functions/api        # single edge request-router monolith
├── functions/_shared    # domain backend modules (repositories, handlers, services)
└── migrations/          # 168 SQL migrations (RLS, identity, finance, capability gating, …)
```

---

## 7. Pointers

- **Forward plan (authoritative):** [`roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md`](roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md)
- **Now / next wave:** [`roadmap/NEXT_ACTIVE_WAVE.md`](roadmap/NEXT_ACTIVE_WAVE.md)
- **Live state dashboard:** [`execution/EXECUTION_DASHBOARD.md`](execution/EXECUTION_DASHBOARD.md)
- **Permanent journal:** [`execution/IMPLEMENTATION_PROGRESS.md`](execution/IMPLEMENTATION_PROGRESS.md)
- **Findings traceability:** [`audits/AUDIT_FINDINGS_LEDGER.md`](audits/AUDIT_FINDINGS_LEDGER.md)
- **Engineering standard / gate:** `docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md` + the EOS gate.
- **Frozen history:** `archive/` (QW1–QW8, B1–B11 certifications) — preserved, not re-asserted.
</content>
</invoke>
