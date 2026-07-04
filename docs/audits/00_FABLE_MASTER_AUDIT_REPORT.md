# Akshara ERP — Fable Final Independent Audit — MASTER REPORT

**Auditor:** Fable (independent Product Review Board) · **Model:** claude-fable-5
**Date:** 2026-07-03 · **HEAD:** `68f15cb` · **Branch:** `feature/data-reliability-platform`
**Mandate:** the final comprehensive independent audit before Pilot School Simulation.
**Method:** evidence-first, cross-validated (docs ↔ code ↔ tests ↔ behaviour), independent, adversarial where warranted. ~20 parallel read-only deep-dives + direct verification. `flutter analyze` run live (0 issues). **Live VPS verification** completed 2026-07-03 (read-only) — see [`11_LIVE_VPS_VERIFICATION_ADDENDUM.md`](11_LIVE_VPS_VERIFICATION_ADDENDUM.md); several repo-based Unknowns are now resolved (some favorably), and one initial DR finding was **corrected** (backups + tested restore DO exist).

> This is the definitive reference. It supersedes prior audits (the 2026-07-02 UI/UX audit is reconciled,
> not discarded). Ten specialized reports sit alongside it in `docs/audits/`; each stands on its own.
> The rebuilt roadmap is [`FABLE_FINAL_ROADMAP.md`](FABLE_FINAL_ROADMAP.md).

---

## 1. The verdict in five sentences

Akshara ERP is a **genuinely engineered, real product** — not a prototype and not (any longer) a mock backend: ~289K Dart LOC + ~144K TS LOC, real end-to-end handlers, a disciplined multi-tenant RLS model, correct money handling, real maker-checker governance, real Claude AI over a deterministic spine, and a clean-compiling codebase with meaningful test coverage. **Its greatest strength is a strong engineering *foundation*; its greatest weakness is a *scoreboard* that runs ahead of the substance** — "237 Verified / QW1–QW8 complete / PRODUCTION CERTIFIED" collectively imply a live, CI-enforced, end-to-end-proven system, whereas the reality is mostly local/contract/mock proof, CI that has essentially never run on the working branch, and the two hardest guarantees (cross-tenant RLS isolation and the live-regression cron) **never executed even once**. The product's *daily academic + fee loop is real and shippable*; several peripheral modules are thin or backend-less; and the reliability, AI-cost, DR, and identity-permanence stories are advertised as further along than they are. None of the gaps require re-architecture — they require **honest re-scoping, live proof, and ergonomic finishing**, in that order. **Pilot-readiness: close but not yet — a focused 3–5 week hardening pass closes it; commercial/GA-readiness is a further, larger step.**

---

## 2. Maturity scorecard (independent, evidence-based)

| Dimension | Score /10 | Basis |
|---|:--:|---|
| **Product (feature completeness of the core)** | **7.0** | Core academic+fee loop real; peripheral modules (Hostel/Alumni/HR-payroll) thin; ~8 backend-less surfaces reachable |
| **Engineering (code/architecture quality)** | **7.5** | Clean compile, real handlers, disciplined modules; single-isolate shared-fate + fragile route ordering as watch-items |
| **Database & tenant isolation** | **8.5** ⬆ | Strong RLS (185/185 policied, non-bypass role) — **now live-verified**: cross-tenant/cross-school/parent read+write isolation all PASS as `erp_tenant` (report 11 §3b). Docked for migration-shipped DB password + phone-as-identity + doc-only audit retention |
| **Security & RBAC** | **7.0** | Sound auth (no backdoor), server-side RBAC + denied-audit; docked for release-discipline traps + plaintext PII + unproven session-revoke |
| **QA / certification integrity** | **5.5** ⬆ | Real test rigor where it runs, but "Verified" over-claims; **RLS-isolation now live-proven** (was the biggest unknown), yet CI + live-regression still never ran on the branch |
| **Data reliability / offline** | **5.5** | Real, high-quality platform; but "universal" idempotency ≈4%, marks-save bypasses it, 2/4 pilot screens lack drafts |
| **AI architecture** | **7.0** | Real Claude, determinism-first, safe; docked for no cache/rate-limit/timeout + silent no-key degradation |
| **UX** | **5.5** | Strong foundation (tokens, shells, offline honesty); friction on the 5 daily tasks; feedback layer absent (unchanged from 2026-07-02) |
| **Deployment / Ops / DR** | **6.0** ⬆ | *Live-verified (report 11):* automated encrypted nightly backups **succeeding**, **restore drill tested + passing monthly**, watchdog green every 5 min. Real gaps: no off-site copy, no WAL/PITR (~24h RPO), alert-delivery unwired, shared box. (Repo-only estimate was 4.5; live evidence raised it) |
| **Scalability (to thousands of schools)** | **4.0** | Model is coherent but horizontal-scale machinery (registry, fleet runner, HA) is design-only |
| **Commercial readiness** | **4.0** | Honestly Phase-2 (billing/quotas/white-label); entitlement enforcement even ships OFF |
| **Documentation & roadmap integrity** | **5.5** | Voluminous + honest, but ProjectStatus stale, cleanup uncommitted, roadmap ≠ execution order |
| **Pilot readiness** | **6.0** | Achievable in 3–5 focused weeks; blocked today on live proof + DR + a few P0/P1 fixes |
| **Production / commercial readiness** | **3.5** | A further, larger step beyond pilot |

**Overall weighted maturity: ~6.0/10** — a strong foundation with a credible, no-re-architecture path to pilot, and a longer road to commercial scale.

*(For calibration: the prior June-2026 internal audit put "real-school readiness" at ~4.5/10 with "mock backend, fake exams." That critique is now largely obsolete — the backend is real and exams are real. The remaining gap is proof, finishing, and ops, not fabrication.)*

---

## 3. Top 10 risks (ranked by business impact)

| # | Risk | Sev | Where | Why it matters |
|---|---|:--:|---|---|
| 1 | ~~Cross-tenant RLS isolation never tested~~ → **LIVE-VERIFIED PASS (2026-07-03)** — read+write, cross-tenant+cross-school+parent-scope isolation all hold as the real `erp_tenant` role (report 11 §3b) | ~~P0~~→closed | QA-2, LV-11 | *The* table-stakes multi-tenant guarantee is now proven live; wire the 233-probe suite into CI for regression |
| 2 | **Hardcoded tenant DB password in the migration** (live box was rotated — but new provisioning inherits the git default) | ~~P0~~→P2 | DB-1 (live-corrected, report 11) | The live pilot rotated it; the *migration* still ships the default → fix so new schools don't inherit it |
| 3 | **No off-site backup + no WAL/PITR** (backups + tested restore DO exist; ~24h RPO, single-site) | ~~P0~~→P1 | LV-1/LV-3 (live-corrected) | Automated encrypted nightly backups run and restore-test passes; the real gap is a single-site local-only posture — fix before real fee data |
| 4 | **"Universal idempotency / exactly-once" is ~4% real**; the money table's concurrency guard is inert | P0/P1 | REL-1, ENG-1 | Retried/offline writes can duplicate fees; concurrent edits can lose money silently |
| 5 | **CI + live-regression have (almost certainly) never run on the QW branch**; GA gate's 7-day-green clock hasn't started | P0 | QA-3 | The project's own GA gate is BLOCKED and unprovable until this runs |
| 6 | **Release-discipline traps** — mis-built release = demo auth + mock OTP→superAdmin + cleartext; debug-signing fallback | P1 | SEC-1/2 | A single build mistake ships an insecure binary |
| 7 | **Identity-permanence invariant is false** — `users.phone` immutable, no change-phone flow | P1 | DB-3 | Contradicts the frozen identity platform; a parent number change requires DB surgery |
| 8 | **~8 backend-less UI surfaces are reachable and serve mock data** in production | P1 | ENG-3/MOD-4 | A real user hitting a mock/404 surface is a credibility hit |
| 9 | **No AI cost controls** (no cache/rate-limit/spend-cap/timeout) | P1 | AI-1/2/3 | Unbounded Claude spend; the Adaptive-AI vision has zero cost foundation |
| 10 | **Documentation drift** — ProjectStatus stale, cleanup uncommitted, roadmap ≠ execution | P1 | DOC-1/2/3 | Diligence/onboarding draws wrong conclusions from the top-level docs |

---

## 4. Top strengths (what NOT to change)

1. **The multi-tenant RLS model** — non-bypass `erp_tenant` role, 185/185 tables policied, server-derived scope. Genuinely strong; protect the deploy-time invariant.
2. **The real, well-built core academic + fee loop** — attendance (with draft/resume), marks/exams (with the frozen absent-student exclusion rule), fee collection (idempotent, row-locked, maker-checker refund/concession, real receipt PDF). This is exactly the right thing to have working first.
3. **Determinism-first AI** — numbers from DB, model rewrites prose only, validated, safe fallback, never on a write path. The correct pattern; keep it.
4. **Genuine test rigor where it runs** + **radical honesty in the docs** — the project documents its own gaps. Cultural strengths worth preserving.
5. **The design system** — real, token-driven, live in dashboards, white-label-ready.
6. **Money-safety discipline** — NUMERIC(12,2), CHECK constraints, FOR UPDATE locking, maker-checker SoD.

---

## 5. Cross-cutting themes (the root causes)

- **Theme A — "Verified" vocabulary inflation.** The single recurring pattern: real work is labelled with claims one grade stronger than the evidence (Verified vs contract-only; universal vs 4%; certified vs no run artifacts; complete vs 34 P0 open). *Root cause:* no evidence-grade taxonomy; "PASS" is binary. *Fix:* an evidence-grade column + honest claim-scoping (cheap, high-trust).
- **Theme B — local proof ≠ live proof.** Nearly everything is proven locally/by-contract/on-mock; the live legs (RLS isolation, DR drill, perf, cron, on-device) are staged but never executed. *Root cause:* the live infrastructure (SSH socket, tenant DB) was gated behind owner action; CI never ran on the branch. *Fix:* stand up the live lane once; it unblocks a dozen rows.
- **Theme C — foundation strong, finishing incomplete.** Reliability platform, identity platform, AI platform, DR plan — each has a strong core and an unfinished edge (idempotency coverage, change-phone flow, cost controls, WAL/off-site). *Root cause:* additive/non-invasive integration that stopped at the seam. *Fix:* finish the seams before advertising the platform.
- **Theme D — peripheral scope creep vs North-Star.** Hostel billing, Alumni, and ~8 backend-less surfaces exist but aren't real. *Root cause:* breadth-first building. *Fix:* hide-first (the owner's own O1/O3), ship the real core.

---

## 6. Strategic recommendations (if this were my company)

1. **Do not chase GA. Chase a *provable* pilot.** The fastest value is standing up the live lane (tenant DB + SSH + CI on the branch) and running the staged harnesses for real — RLS isolation, DR drill, perf, the money loop end-to-end. This converts a dozen "Verified-local" claims into real ones and is the single highest-ROI work available.
2. **Re-scope the over-claims before the Red Team, not after.** Fix the idempotency framing, the row_version money guard, the identity-permanence invariant, and the tracker evidence-grades now — a Red Team that starts from honest claims is far more valuable.
3. **Ship the real core; hide the rest.** Turn off (route-guard) the ~8 backend-less surfaces and the thin peripherals (Alumni, Hostel billing/leave) for the pilot. Fewer, real, delightful surfaces beat many half-built ones — this is the owner's own North Star.
4. **Then finish the daily-task ergonomics** (the prior UX audit's Tier 1–2). Adoption is won on attendance/marks/approvals/fee speed and the feedback layer, not on feature count.
5. **Close the ops P0s before a real school touches it** — WAL/off-site DR, a tested restore, alerts that reach a human, the DB password rotated, entitlement enforcement on.
6. **Sequence Adaptive-AI *after* its cost foundation** (cache + rate-limit + timeout), not before.
7. **Highest long-term moat:** the combination of *offline honesty + governance visibility + determinism-first AI + genuinely-easy mobile-first UX*. These are already differentiators in the codebase — the work is to *finish and show* them, per the prior UX audit. Don't dilute the North Star ("easiest, not biggest") by re-enabling the deferred verticals/experimental surfaces.

---

## 7. Confidence & unknowns

- **High confidence:** engineering foundation, DB/RLS, security/auth, QA-integrity, reliability, AI (all code-verified with citations).
- **Medium confidence:** Transport/Inventory/Admissions-SIS/Communication/leadership-dashboard depth (recently-shipped waves verified as *code shipped*, not *live E2E*); mobile UX deltas since 2026-07-02 (agent session-limited).
- **Unknown (needs live-VPS access):** live env config (entitlement flag, AI key, rotated password, WAL/off-site/alerts), live-cert reproducibility today, real performance at scale. **Everything gated on the live lane is the audit's largest blind spot — and the project's.**

---

## 8. Deliverables in this package

| # | Report |
|---|---|
| 00 | **This master report** |
| 01 | Engineering & Architecture |
| 02 | Database, Identity & RLS |
| 03 | Security & RBAC |
| 04 | **QA & Certification Integrity** (the flagship finding) |
| 05 | Data Reliability & Offline |
| 06 | AI Architecture |
| 07 | Product & Module Readiness |
| 08 | UX & Design-System Reconciliation |
| 09 | Deployment, Ops, Scaling & DR |
| 10 | Documentation & Roadmap Integrity |
| — | [`FABLE_FINAL_ROADMAP.md`](FABLE_FINAL_ROADMAP.md) — the rebuilt path to pilot → GA |

---

*Fable's final-question test ("would I be proud to sign this if my name were permanently attached?"): Yes — with the explicit caveat that the live-lane items (§7 Unknown) could not be verified from the audit environment and must be proven on the VPS before pilot. Every conclusion above is evidence-cited or clearly labelled as inference.*
