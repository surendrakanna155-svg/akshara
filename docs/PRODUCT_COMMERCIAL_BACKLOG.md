# Akshara ERP — Product & Commercial Backlog (SINGLE SOURCE OF TRUTH)

**Date:** 2026-06-30 · **Owner:** surendrakanna155@gmail.com
**Reconciled from:** [`still_pending.md`](../still_pending.md) (Master Product & Commercial Audit, ~155 capabilities)
**Governed by:** the Engineering Operating System (`/eos`) per [`engineering/ENGINEERING_GATE_POLICY.md`](engineering/ENGINEERING_GATE_POLICY.md).
**Companions:** [`FINAL_QA_ROADMAP.md`](FINAL_QA_ROADMAP.md) · [`FINAL_QA_MASTER_TRACKER.md`](FINAL_QA_MASTER_TRACKER.md).

> **Purpose.** This is the authoritative product/commercial backlog. Every gap, commercial-readiness
> item, UX issue, architecture improvement, and future feature discovered by independent audits is
> classified here into one of five queues with its current evidence. **Future audits should find only
> genuinely NEW issues** — anything already known lives here. The QA waves (`FINAL_QA_ROADMAP.md`)
> prove *quality*; this backlog tracks *scope*. Where they overlap (i18n, billing, white-label,
> backup/DR) the two are cross-linked, not duplicated.
>
> `still_pending.md` is the read-only **audit input**; this file is the **reconciled output**. Do not
> re-file audit items as new work — reconcile them here.

---

## Owner decisions (LOCKED — preserve across all waves)

| # | Decision | Source |
|---|---|---|
| O1 | **Hide-first scope.** OUT (deferred to Future Vision): industry vertical packs (healthcare/salon/restaurant/accommodation), branch/franchise mgmt, experimental extras. **KEEP** multi-school (director/chain). | Scope decisions (Jun 2026) |
| O2 | **Exams = top priority** functional area; mix of boards supported. | Scope decisions |
| O3 | **North Star:** the *easiest* mobile-first school ERP, not the biggest. Cut scope creep; consolidate overlaps. | Product North Star |
| O4 | **Student attendance** is entered by **teachers** after students arrive at school. **Students do NOT use Face ID** for attendance. | Owner (2026-06-30) |
| O5 | **Staff attendance MAY use Face ID.** Staff Face ID is **Must Before GA**. | Owner (2026-06-30) |
| O6 | **Commercial monetization** (in-product billing, SMS/storage/AI-token quotas, marketplace add-ons) → **Phase 2** (after GA). Pilot + early GA run on entitlement-gating + manual/external invoicing. | Owner (2026-06-30) |
| O7 | **Multi-language / full UI i18n** → **Must Before GA** (regional-language parent/teacher/student UI). Partial content/AI localization already exists. | Owner (2026-06-30) |
| O8 | **Live GPS bus tracking** (live map + parent tracking + driver app) → **Phase 2**. Transport admin ships for GA without real-time tracking; do not market "live tracking" pre-Phase-2. | Owner (2026-06-30) |
| O9 | **Geo-fencing / RFID / QR attendance** → **Future Vision** (audit flags these as marketing liabilities if promised pre-GA). | Owner (2026-06-30) |
| O10 | **White-label platform + custom domain** → **Phase 2** (Enterprise upsell; API OFF live; ties to monetization O6). School Branding + onboarding branding are already GA-ready. | Derived from O1/O6, owner-review |

---

## Queue 1 — MUST BEFORE PILOT

The pilot is **already live and certified** (Phase 0b live-cert 20/20; QW1/QW2 closed). No NEW
feature items block the pilot — pilot-critical scope is the live-certified core (auth, RBAC,
admissions, SIS, attendance, exams, fees/payments, messaging) plus the in-flight QA closure.

| Item | Status | Evidence / action |
|---|---|---|
| Pilot-critical journey/RBAC/RLS correctness | ✅ In progress | QW1 (closed), QW2 (closed), QW4 (in progress) — see tracker |
| Data Reliability Platform (offline/draft/sync/idempotency) | ✅ Done | Phase 0a/0b live-certified |

---

## Queue 2 — MUST BEFORE GA

| Item | Audit status | Current evidence | Action |
|---|---|---|---|
| **Full UI i18n / multi-language** (O7) | 🟡 partial | `content_localization.dart`, RTL Urdu typography, multilingual AI parent guidance — but **no `.arb` / `flutter_localizations`**, English-only UI | **NEW build: "Phase 0-L" localization platform** (strings + templates + PDF/SMS/AI language plumbing) → then certify via QW7 `QA-C-015..018`. Resolves the roadmap's i18n "Capability Prerequisite". |
| **Staff Face ID attendance** (O5) | 🔴 planned | No biometric capture wired | **NEW build:** staff check-in via device Face ID/biometrics. Student attendance stays teacher-entered (O4). New feature + RBAC + audit + cert. |
| **Backup & Disaster Recovery (backend)** | 🟠 partial | Backup/restore screens are **UI-only**; backend "not confirmed live" | Build + drill real backup/restore/integrity; certify via QW8 `QA-R-009`. |
| **Behaviour & Production-Readiness certification** | n/a | — | QW7 (`QA-C`) + QW8 (`QA-R`) per roadmap — the GA gate. |
| Security / performance / multi-school SaaS certs | ✅ partial | QW1 RBAC + RLS legs; perf targets undefined | QW6/QW8 per roadmap. |

> **GA is declared only after QW8's Final Production Checklist passes** (see roadmap). i18n and staff
> Face ID are now hard GA-blockers per O5/O7.

---

## Queue 3 — FUTURE QW (QA waves — quality, not new scope)

| Item | Action |
|---|---|
| **QW3** Flutter widget/UI/state | ✅ COMPLETE (`QW3_COMPLETION_CERTIFICATION.md`) |
| **QW4** Backend API/RBAC/RLS/error-path | 🟢 in progress (this wave) |
| **QW5** Secondary/advanced/verticals journeys | Per roadmap (verticals legs scoped per O1) |
| **QW6** Resilience & non-functional (offline cache, audit, import/export, perf, golden, security) | Per roadmap |
| **QW7** Feature Behaviour Certification (incl. i18n cert once O7 built) | Per roadmap |
| **QW8** Production Readiness & Market Certification (incl. backup/DR, security, perf) | Per roadmap — GA gate |
| **NEW: QW-Consolidation** (proposed, owner-review) | Unify the 14 overlapping surfaces below (North Star O3). See "Consolidation" section. |
| Premium-module deepening: Lesson Planning, Syllabus depth, Scholarships/Discounts depth, Asset Mgmt | Fold into the relevant module's QW cert; not GA-blocking. |

---

## Queue 4 — PHASE 2 (post-GA)

| Item | Audit status | Rationale (owner decision) |
|---|---|---|
| **In-product billing** (invoicing, MRR, renewals, payment collection for subscriptions) | 🔴 planned | O6 — monetization after GA |
| **Usage quotas + packs** (SMS / storage / AI tokens) | 🔴 planned | O6 |
| **Marketplace purchasable add-ons** | 🔴 planned | O6 |
| **Live GPS bus tracking + parent live map + driver app** | 🟠 placeholder | O8 |
| **White-label platform + custom domain + subscription-aware branding tiers** | 🟠 partial | O10 (ties to O6) |
| **Custom theme maturity** (beyond per-school colours) | 🟠 partial | Enterprise upsell |
| **Full general ledger / accounting** | 🟠 partial | Premium; post-core |
| **Dedicated expense-management module** | 🟠 partial | Premium; currently via approvals |
| **Device / MDM management console** | 🟠 partial | Enterprise; FCM tokens only today |
| **Community portal (standalone)** | 🔴 planned | Beyond core ERP |

---

## Queue 5 — FUTURE VISION (deferred / scoped-out)

| Item | Rationale |
|---|---|
| Industry vertical packs (healthcare / salon / restaurant / accommodation) | O1 — hide-first, scoped OUT (UIs exist, route-guarded off) |
| Branch / franchise management | O1 — scoped OUT (multi-school/director KEPT) |
| **Geo-fencing attendance** | O9 |
| **RFID attendance** · **QR attendance** | O9 (finance QR is payments only) |
| **Student Face ID** | **N/A by decision (O4)** — students never; teachers enter attendance |
| Face *recognition* (CV) attendance | Future product; no hardware/CV pipeline |
| School website builder / CMS · Dynamic pages · Blog · SEO | Beyond core ERP (achievement promotion already publishes *to* a website) |
| Reception desk · Gate Pass · standalone (school-wide) Visitor Mgmt | Hostel-scoped visitor mgmt exists; school-wide is future |
| Secure CBT / online exam workspace | Referenced in archived docs only |
| App biometric lock (parent/teacher mobile) | Documented, not coded |
| Biometric / RFID hardware partner integrations | Hardware partnerships |

---

## Consolidation & De-duplication (Deliverable 5 — proposed QW-Consolidation, owner-review)

The audit found 14 overlapping surfaces. Per North Star O3 ("easiest, cut scope creep"), these are
candidates for a focused consolidation wave. **No code changes here** — flagged for an owner go/no-go.

| Overlap | Proposed direction |
|---|---|
| Admissions CRM vs Control Center CRM | Keep both (different buyers) — just rename to disambiguate (School Leads vs Platform Sales). |
| Homework vs Assignments vs Education papers | Define one academic-work-distribution boundary; fold "Assignments" into Homework. |
| Intelligence vs Copilot vs Evolution vs Predictions | Unify AI entry points under one "AI" surface with persona routing. |
| Management dashboard vs Principal Command vs Dynamic Dashboard | Converge on Dynamic Widget Platform as the principal dashboard. |
| Director marketing vs Growth vs Achievement promotion | Clarify org-level vs school-level marketing surfaces. |
| Reports vs Analytics vs Intelligence vs BI | Introduce a unified reporting layer. |
| Notices vs Announcements vs Circulars vs Broadcasts | Single communication primitive, one label. |
| Inventory assets vs Asset Management | Document Assets as an Inventory submodule (not a separate product). |
| Backup (Security) vs Backup (Media) | One backup screen, two narratives — clarify copy. |
| Multi-school vs Director vs Multi-school-ops vs Trust Org | Consolidate chain mgmt; reconcile live API status. |
| Onboarding wizards × 3 | Keep all (unified onboarding / setup wizard / org-builder) but document when each applies. |
| Student App vs Parent views | Intentional (different personas) — no change. |
| Hostel visitors vs Visitor Management | School-wide visitor mgmt is Future Vision; keep hostel-scoped today. |
| White Label vs School Branding vs Custom Theme | Three branding layers — see O10 (white-label Phase 2; branding GA-ready). |

---

## Already done — reconciled "completed with evidence" (no duplication)

Auth · OTP · RBAC (+ **QW4-INV-OR OR-fallback fix**, 29 sites) · Admissions · SIS · Exams · Marks ·
Report Cards · Fee Mgmt · Online + Offline Payments (Razorpay live) · Library · Inventory · Hostel ·
Transport admin · Audit Logs · Session Mgmt · Data Encryption · Subscription/Entitlement gating ·
Organization Builder · Tenant/RLS · Question Intelligence Platform · Dynamic Widgets · Achievement
Promotion · Student/Employee 360 · Operations Hub · Approval Engine · School Branding · Progress
Analytics. These are ✅/🟢 in the audit and covered by existing certifications — do not re-open.

---

## Doc corrections applied during reconciliation

- **Localization overstatement:** `FINAL_QA_ROADMAP.md` (QW7) said "no localization infrastructure".
  Reality: *partial* content/AI localization exists (`content_localization.dart`, RTL Urdu,
  multilingual AI guidance); only full UI-string `.arb`/`flutter_localizations` is missing. The i18n
  prerequisite is now **resolved to BUILD before GA** (O7), not an open build-vs-scope question.
- **Billing / white-label "Capability Prerequisites"** (roadmap QW7/QW8) are now **resolved**:
  billing → Phase 2 (O6); white-label → Phase 2 (O10).
