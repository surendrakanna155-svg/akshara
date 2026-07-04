# Akshara ERP — Fable Final Rebuilt Roadmap

> **⏭ SUPERSEDED / FOLDED IN (2026-07-03).** This roadmap (waves W0–W9) is consolidated into the **single
> authoritative** roadmap [`docs/roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md`](../roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md)
> (Phases 0–8). Use that as the only source of truth for execution; this document is retained for its
> rationale/narrative. The W0–W9 waves map to final Phase 0 (W0–W4) → **Phase 6 Pilot/PILOT-READY (W5 — note: the final roadmap re-sequences it AFTER the Red Team)** → Phases 1–3 (W6–W7) → Phases 4–8 (W8–W9).

**Auditor:** Fable (independent) · **Date:** 2026-07-03 · **HEAD:** `68f15cb`
**Derived entirely from** the Fable Final Audit (`docs/audits/00`–`10`). Companion to, and reconciled with, the existing `FINAL_QA_ROADMAP.md` (whose Phase B/C/D structure is preserved where still valid, re-sequenced where the audit found drift).

> **Principle:** this roadmap is ordered so that **proof and safety come before finishing, and finishing
> before breadth.** It replaces "declare GA" with "earn a provable pilot." Every wave is EOS-gated. Frozen
> owner decisions (O1–O10, identity freeze, attendance-auth) are respected. Nothing here re-enables
> deferred verticals/experimental surfaces.

---

## Sequencing at a glance

```
 W0  Truth & Honesty        (docs/claims match reality)         ~3–5 days   ── unblocks trust
  │
 W1  Live Proof Lane        (stand up live infra, run harnesses) ~1 wk      ── unblocks a dozen "Verified" rows
  │
 W2  P0 Safety Fixes        (RLS-isolation, DB pwd, DR, money)   ~1–1.5 wk  ── makes a real school safe
  │
 W3  Reliability & AI Finish(idempotency, drafts, AI cost)       ~1–1.5 wk  ── makes the platform claims true
  │
 W4  Scope Discipline       (hide backend-less/thin surfaces)    ~3–5 days  ── ship real, hide unreal
  │
 W5  Pilot Hardening Cert   (re-run pilot sim honestly)          ~1 wk      ── PILOT-READY gate
  ├───────────────────────────────────────────────────────────────────────
 W6  Product Excellence (UX)(the 5 daily tasks + feedback layer) ~2–3 wk    ── adoption
 W7  Identity & Ops Finish  (change-phone, DR automation, scale)  ~2–3 wk    ── durability
 W8  ONE Global Red Team    (adversarial, on honest claims)      ~1 wk      ── confidence
 W9  Red-Team Fixes → GA    (close findings → live 7-day green)  ~1–2 wk    ── PRODUCTION-CERT gate
```

**W0–W5 = the pilot track (do first).** W6–W9 = the road to commercial GA. This differs from `FINAL_QA_ROADMAP.md` deliberately: that plan sequenced GA (Phase B) before product work (Phase C), but the audit found (a) the "GA-ready" claims aren't proven, and (b) product/module work already happened pre-GA. This roadmap fixes the order.

---

## W0 — Truth & Honesty pass (≈3–5 days, no new features)

*Goal: make the top-level docs and claims match the code, so every later decision rests on truth.* (Audit: DOC-1/2/3/4, QA-1, ENG-1, REL-1.)

| Task | From | Done when |
|---|---|---|
| Rewrite `ProjectStatus.md` to HEAD reality | DOC-1 | Reflects shipped modules + QA-local-complete + GA-blocked-on-live |
| Commit (or revert) the ~600-file doc cleanup + track PROJECT_INDEX/README/CLAUDE | DOC-2 | Working tree clean; start-here files version-controlled |
| Reconcile the active roadmap to the real execution order | DOC-3 | `FINAL_QA_ROADMAP.md` matches this sequence or references it |
| Add an **evidence-grade column** to the QA tracker (LIVE/LOCAL-LOGIC/CONTRACT/RENDER-MOCK/STAGED) | QA-1 | Every "Verified" row carries its true grade |
| Re-scope over-claims (idempotency ~4%, row_version 1/4, "certified" pass-counts) | REL-1, ENG-1, QA-5 | Docs state actual coverage |
| Fix stale `TD-P0-01` + `AuditArchitecture` retention claims | DB-6/9 | Docs match implementation |

**EOS exit:** no top-level doc contradicts the code; no "universal/certified/complete" claim exceeds its evidence.

---

## W1 — Live Proof Lane (≈1 wk) — the highest-ROI wave

*Goal: stand up the live infrastructure once and run the already-staged harnesses for real.* (Audit: QA-2/3/5, OPS.) **Owner action required:** SSH ControlMaster socket + tenant Postgres URL + CI trigger on the working branch (or merge to a gated branch).

| Task | Closes |
|---|---|
| Point CI at the working branch (or merge); capture first green run IDs | QA-3 |
| Run the **233 cross-tenant RLS isolation probes** on a real tenant DB | QA-2 (P0) |
| Run the money-loop, multi-school concurrency, and pilot-sim harnesses **live** (real gateway, real DB) | QA-4/5 |
| Stand up the live-regression cron; **start the 7-day-green clock** | QA-3 |
| Commit machine-readable run artifacts (JSON: timestamp+counts) per live cert | QA-5 |

**EOS exit:** RLS isolation proven live; CI green on the branch; live-regression cron running; real run artifacts committed. *This wave converts ~a dozen "Verified-local" claims into real ones.*

---

## W2 — P0 Safety Fixes (≈1–1.5 wk)

*Goal: make it safe for a real school's real data.* (Audit: DB-1/2, OPS-1/2/3, ENG-1, SEC-1/2.)

| Task | Sev | From |
|---|---|---|
| Rotate the tenant DB password out of git → vault | P0 | DB-1 |
| Deploy-time assertion that edge fns use `erp_tenant`, not `service_role` | P0 | DB-2 |
| Wire WAL/PITR + off-site backup bucket → real RPO ≤15min (or accept 24h in writing) | P0 | OPS-1 |
| Run the live backup→restore→integrity drill on a staging tenant | P0 | OPS-2 |
| Alert sinks reach a human (webhook/SMS) | P1 | OPS-3 |
| Wire the `finance_collections` row_version check into collect/refund (money lost-update) | P1 | ENG-1 |
| Release-build fail-closed guard (no prod build on dev-config; no debug-signing fallback) | P1 | SEC-1/2 |
| Turn on `ENTITLEMENT_ENFORCEMENT` (or document dark) | P1 | ENG-2/OPS-5 |

**EOS exit:** no P0 open; a real school's data is durable, isolated, recoverable, and correctly gated.

---

## W3 — Reliability & AI Finish (≈1–1.5 wk)

*Goal: make the platform claims true.* (Audit: REL-1..5, AI-1..4.)

| Task | From |
|---|---|
| Mint `Idempotency-Key` in a Dio interceptor for **all** mutating verbs | REL-1 (P0) |
| Route marks "Save all" through `ReliableWriter` + add draft autosave to marks + fee | REL-2/3 |
| Auto-flush the outbox on boot + app-resume when online | REL-4 |
| Send base `row_version` on first write of high-risk ops (finance/marks) | REL-5 |
| AI: add per-user/per-org rate-limit + monthly spend cap | AI-1 |
| AI: add a response/semantic cache (TTL, keyed on surface+inputs+school+lang) | AI-2 |
| AI: add request timeout/AbortController → deterministic fallback | AI-3 |
| AI: emit a health signal when no key configured (kill silent degradation) | AI-4 |

**EOS exit:** idempotency covers all mutations; drafts on all 4 pilot-critical screens; AI has cost controls + a cache foundation.

---

## W4 — Scope Discipline (≈3–5 days) — hide-first

*Goal: ship real, hide unreal (owner's North Star O1/O3).* (Audit: ENG-3/MOD-4/5/6.)

| Task | From |
|---|---|
| Route-guard OFF the ~8 backend-less surfaces (Workflow/Academic-Ops/Continuity/Platform-Intel/Ops/Multi-School-Ops/Verticals/White-label) | ENG-3 |
| Hide Alumni for pilot (manual-only, disconnected) | MOD-5 |
| Ship Hostel "residence-lite" (hide billing + leave/gate-pass) or hide Hostel | MOD-6 |
| Hide HR payroll-run (no salary-structure engine) until W7 | MOD-2 |
| Fix hardcoded `employeeId:'HR-EMP-102'` leave defect | MOD-3 |

**EOS exit:** every reachable surface is real; nothing serves mock data to a pilot user.

---

## W5 — Pilot Hardening Certification (≈1 wk) — **PILOT-READY gate**

*Goal: re-run the pilot simulation honestly, end-to-end, on the live lane, with the fixes in.* (Audit: QA, MOD, OPS.)

- Full single-school + 3-school-concurrent live pilot sim (real auth/DB/RBAC/gateway), unattended.
- Live-verify the recently-shipped module waves (Transport/Inventory/Admissions-SIS certificates/TC).
- Confirm: money loop end-to-end, RLS isolation, DR drill, alerts, no mock surface reachable, AI cost controls active.
- **Gate:** all P0 closed; live pilot sim green; 7-day regression cron green; evidence-graded tracker.
- **Declare: PILOT-READY** (not GA — GA is W9).

---

## W6 — Product Excellence (UX) wave (≈2–3 wk, post-pilot-ready)

*Goal: win adoption on the daily tasks.* (Audit: UX-1..6; prior UI/UX audit Tiers 1–2.)

- Tier 1 feedback pack: skeletons, pull-to-refresh, haptics, success views, freshness chip (offline "as of…"), copy/error-dictionary pass, draft-chip everywhere.
- Tier 2 workhorses: exception-grid attendance, inline marks/grading ergonomics, generalize bulk-operations, cross-module Approvals Inbox, responsive `AksharaDataTable`, form-kit + 5-field doctrine, keyboard/date-picker sweep.
- Design-system enforcement in CI (lints, contrast, golden baselines).
- **Accessibility pass** (added by the EOS verification gate): WCAG contrast audit, screen-reader labels/semantics on the core flows, dynamic-type/large-font support, tap-target sizing — with a contrast checker wired into CI. (Audit gap disclosed in the EOS verification report §4.)
- **Gate:** re-run the prior audit's rubric → target ≥8/10.

## W7 — Identity & Ops Finish (≈2–3 wk)

- **Change-phone flow** (`PLAT-4`): OTP-verify → re-point credential → keep UUID/PSID/links → audited. Makes the identity-permanence invariant *true*. (DB-3)
- Append-only reject triggers on true ledgers (audit/receipts/stock). (DB-5)
- Audit retention/partitioning (or correct the doc). (DB-6)
- HR salary-structure + payroll-run generation (un-hide payroll). (MOD-2)
- Scale machinery: School Registry + migration-fleet-runner + read-replica/HA plan + PgBouncer + observability (Sentry/Prometheus). (OPS-4/7/8)
- Cross-module Finance posting for Library fines / Hostel fees (or keep out-of-Finance, labelled). (MOD-1)

## W8 — ONE Global Red Team (≈1 wk)

*On honest, re-scoped claims (post W0).* Adversarial security + data-integrity + multi-tenant isolation + money-correctness + abuse/cost + failure-injection. Perspective-diverse (security, correctness, ops, abuse).

## W9 — Red-Team Fixes → Production Certification (≈1–2 wk) — **GA gate**

- Close every Red-Team finding; re-verify live.
- Full `QA-R-012` Final Production Checklist — now with real evidence.
- 7-consecutive-day live-regression green.
- Commercial prerequisites decided (billing/quotas/white-label = Phase-2 per O6/O10, or promoted).
- **Declare: PRODUCTION-CERTIFIED / GA.**

---

## What changed vs `FINAL_QA_ROADMAP.md` (and why)

| Change | Why (audit finding) |
|---|---|
| Added **W0 Truth pass** before everything | Docs/claims drifted from code (DOC-1/2/3); a Red Team on inflated claims wastes effort |
| Moved **Live Proof (W1)** to the top of execution | The single highest-ROI work; unblocks a dozen unproven "Verified" rows (QA-2/3) |
| Split "GA" into **PILOT-READY (W5)** then **GA (W9)** | "GA-ready" claims are unproven; pilot must be earned first (QA, OPS) |
| Inserted **Scope Discipline (W4)** | ~8 backend-less surfaces are reachable-mock; hide-first per O1/O3 (ENG-3) |
| Kept the **UX wave (W6)** as its own post-pilot program | Prior UX audit's Tier 1–2 still ~90% open and still correct (UX audit §2) |
| Made **Red Team (W8) depend on honest claims (W0)** and follow the finishing waves | A Red Team is only as valuable as the claims it tests |

## Owner decisions needed to start

1. **Open the live lane** (SSH socket + tenant Postgres + CI-on-branch) — unblocks W1, the highest-ROI wave.
2. **Accept the DR posture** for pilot (fix to ≤15min RPO, or sign off on 24h) — W2.
3. **Confirm hide-list** for W4 (Alumni, Hostel billing/leave, HR payroll, the 8 surfaces).
4. **Confirm the split**: earn PILOT-READY (W5) before pursuing GA (W9); UX wave (W6) post-pilot.
5. Everything else (Phase-2 monetization, Adaptive-AI wave, Consolidation) stays owner-timed and is *unchanged* by this roadmap.
