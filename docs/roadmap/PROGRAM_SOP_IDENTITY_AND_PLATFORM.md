# PROGRAM SOP — School Operating Platform: Identity Governance + Operational Feature Suite  🔴 P0

**Status:** 📋 **RECORDED (owner-stated 2026-07-17)** — captured as roadmap items + audit findings,
reconciled against current code and the existing roadmap. **Implementation not started. Final product
decisions will be confirmed by the owner after all audits complete** (owner instruction, 2026-07-17).

> ⛔ **TWO OWNER DECISIONS ARE PENDING AND NOT APPROVED — do NOT implement on either assumption:**
> **D1 (Smart OMR — SOP-F1/F2/F3)** and **D2 (execution placement / sequencing).** Everything else is
> recorded as audit findings + roadmap items only. See the Decision Register (§4).
>
> 📋 **PROPOSED SCOPE — not in completion metrics.** Per owner instruction (2026-07-17), Program SOP is
> **excluded from the Wave-Ledger completion metrics** until the owner finalizes its placement; it is
> tracked only as proposed scope. No implementation until the complete post-audit roadmap review is done.
**Authority:** owner directive of 2026-07-17 (three-part: *Feature Governance Update* + *Identity
Architecture Review* + *Identity Ownership & User Lifecycle Governance*).
**Grounded on current code** via three read-only audits (2026-07-17); companion evidence doc:
[`IDENTITY_AND_LOGIN_ARCHITECTURE_AUDIT.md`](IDENTITY_AND_LOGIN_ARCHITECTURE_AUDIT.md).
**Roadmap home:** Program SOP section of `FINAL_EXECUTION_MASTER_ROADMAP.md`.

> **Program principle (owner):** *"The goal is not to build more modules. The goal is to build a
> seamless School Operating Platform where all existing modules work together naturally."* Prefer
> **extending** existing architecture (Student 360, Universal Search, RBAC, Approvals, Audit,
> Certificates, Dynamic Widgets, Workflow Engine) over new standalone modules. Avoid duplicate
> functionality.

---

## 0. Governance — the Definition-of-Done (mandatory, EOS-enforced)

Every SOP feature is **implemented end-to-end**. No partial implementations, no placeholder UI, no
mock-only paths. A feature is **COMPLETE only when all 15 checkpoints pass** and are then certified by
the **existing EOS gate** (per `CLAUDE.md`). This 15-point list is the per-feature **Definition-of-
Done that EOS enforces** — it is **not a new competing gate**. There is one standard (the Engineering
Constitution) and one engine (EOS); SOP items are ordinary EOS-gated work.

**A SOP item may never be marked DONE until every applicable checkpoint is green:**

1. Functional implementation
2. UI/UX completion (Flutter design-system parity; light + dark)
3. Backend integration (real edge functions/services — no stubs)
4. Database integration (migrations; RLS; tenant isolation)
5. Role permissions (RBAC — server-authoritative + RLS)
6. Audit logging (identity/security events where applicable)
7. Notifications (where applicable)
8. Search integration (Universal Search / Student 360 where applicable)
9. Reports / exports (where applicable; totals consistent across UI/PDF/CSV)
10. Mobile **and** Web verification (where applicable)
11. Automated tests (unit + contract + regression)
12. Manual QA
13. Regression verification (full affected regression green)
14. Documentation update (this doc + roadmap + certification report)
15. Production certification (live evidence — the only place 🟩 is granted, per P7)

**Standing laws inherited from the roadmap:** frozen owner decisions respected everywhere ·
anti-duplication (extend, never fork) · anti-disappearance (no SOP row silently removed/re-scoped —
changes go to the Decision Register §4) · Creator ≠ Approver where applicable · soft-delete only ·
complete audit trail · no manual role selection at login.

---

## TRACK A — Identity, Login & User-Lifecycle Governance  🔴 (identity/security-foundational)

*The login philosophy is already implemented (Mobile → OTP → auto-resolution; backend decides
role/school/landing — see the audit companion §0). Track A closes the **gaps**, not the philosophy.
It is security- and identity-foundational; a **proposed** (not adopted) placement is before P4 Red
Team and P6 Pilot — but **execution placement is OWNER DECISION D2 (pending)**, so this is recorded,
not scheduled.*

### A.1 — Corporate identity-ownership hierarchy (owner-locked)

Ownership descends: **Platform Super Admin → School Owner/Management → Principal → Vice-Principal/
Academic Coordinator → HR → Finance Manager → Office Administration → Department Heads → Teachers →
Parents → Students.** Ownership/authorization rules (who may create/approve/modify/deactivate/
transfer/reset each identity) are specified in the owner directive and summarized below; they must be
enforced by RBAC + Creator≠Approver, **reusing the existing `role_definitions`/`role_permissions`/
`membership_permission_overrides` engine** (`rbac_foundation.sql`) — no parallel permission system.

| Actor | May create/manage | May NOT |
|---|---|---|
| Platform Super Admin | Organizations, activate schools, School Owner, emergency recovery, global audits | day-to-day school users |
| School Owner / Management | Principal, transfer ownership, view all users, lock school, high-level perms | — |
| Principal | VP, HR, Finance, Office, Coordinators, HODs, Teachers, non-teaching staff; approve admissions | platform ownership |
| HR | Teacher/staff records, onboarding, exit, documents | create Principals; change Finance perms; manage students |
| Finance Manager | Finance staff (cashier, accountant), Finance perms only | create teachers/students |
| Office Administration | Admissions, parent mobile numbers, profile corrections, TC, transfers | assign staff permissions |
| Academic Coordinator / HOD | Recommend teacher assignments, academic mapping, subject allocation | create users |
| Teachers | Invite parents (optional), verify student info, request corrections | create accounts |
| Parents | — (receive access after admission) | self-register |
| Students | — (identity auto-created via admission) | self-register |

### A.2 — Mandatory identity account fields (owner-locked)

Every user must carry: **Identity · School Membership · Role · Permission Set · Status · Audit
History · Created By · Approved By · Last Modified By.** Current gap: `users` has none of
`status/created_by/approved_by/last_modified_by`; memberships have `status` only (audit companion G6).

### A.3 — Mandatory identity audit events (owner-locked)

Log, each with **Time · User · Operator · Device · IP (where applicable) · Reason**:
User Created · User Approved · Mobile Changed · Role Changed · Department Changed · School Changed ·
Login Enabled · Login Disabled · User Locked · User Unlocked · Transfer · Exit · Account Deleted
(logical only). Current gap: none of these exist in the audit catalog (audit companion §7). **Extend
the existing `audit_events` engine** — do not build a second audit store.

### A.4 — Track A work items (reconciled — no duplicates)

| ID | Item | Current state | Disposition | DoD focus |
|---|---|---|---|---|
| **SOP-ID-1** | **Identity & Login Architecture Audit** (Phase 1) | ✅ **DONE 2026-07-17** — audit companion doc | Complete | 14 (doc) |
| **SOP-ID-2** | **Student Transfer / Exit Identity Lifecycle (LOCKED):** TC/transfer/exit **deactivates** old `school_membership` + student-side login entitlement; archives academic history (immutable); same mobile reactivatable at new school after admission; no duplicate active memberships; full transfer audit trail | ⚠ Partial — TC engine exists (SIS-D1) but leaves membership/guardian active, no archival flag, no inter-school path (audit G3/G4) | **Extend** TC/SIS engine; **elevate `PRA-P2-28`** | 1-6,11-15 |
| **SOP-ID-3** | **Multi-School Identity Support (LOCKED):** OTP → auto-resolution → **school selection only when >1 active membership** → role resolution → dashboard; teacher/parent/admin across multiple schools; branch-add + chain consolidation | ⚠ Scaffolding only — `context/switch` unused, `.limit(1)` silent pick, no `school_groups`, Org Builder makes disconnected tenants (audit G1/G8) | **Wire** existing `context/switch`; **elevate `PRA-P1-04`, `PRA-P1-51/52`, `PRA-P2-27`** | 1-6,10-15 |
| **SOP-ID-4** | **Parent & Student Login Review + fixes:** student-login-via-parent-mobile; student own-mobile where applicable; parent w/ multiple children; parent across multiple schools; promotion/transfer/parent-change/mobile-update/guardian-change all seamless | ⚠ Parent multi-child ✅; **student-via-parent-mobile MISSING** (audit G2, contradicts frozen *Student Identity Architecture Decision*) | **New path** toward the frozen identity decision; extend auth-context | 1-6,10-15 |
| **SOP-ID-5** | **Identity-Ownership & Lifecycle Governance:** corporate hierarchy A.1 enforced via RBAC + Creator≠Approver; account fields A.2 (status/created_by/approved_by/last_modified_by); mandatory audit events A.3; dedicated create-employee/create-finance/create-staff onboarding flows; mobile-number change (Identity-Permanence invariant); guardian/custody change; login enable/disable/lock/unlock; logical delete only | ⚠ Partial — RBAC/approvals/audit engines exist but ownership fields, identity audit events, change-phone, guardian-change, create-employee endpoint all missing (audit G5/G6) | **Extend** RBAC + Approvals + Audit; **elevate/extend `P1-CODE-4`** (change-phone/PLAT-4) | 1-6,11-15 |

**Track A exit:** all SOP-ID items pass the 15-point DoD + EOS; the frozen *Student Identity
Architecture Decision* and *Attendance-Auth Decision* remain honored; backward-compatible (audit §4).

---

## TRACK B — Operational Feature Suite (12 locked product decisions)

*Current-state from the 2026-07-17 feature audit. **Verdict** = today's reality; **Disposition** =
build/extend. Every item still owes the full 15-point DoD before DONE.*

| ID | Feature (owner-locked) | Verdict today | Evidence | Disposition |
|---|---|---|---|---|
| **SOP-F1** | **Smart OMR Evaluation System** — Universal OMR · Smart Akshara OMR · Mixed Mode | ❌ **MISSING** — and **explicitly excluded** by frozen *Assessment-Intelligence D2* | `\bOMR\b` = 0 hits; `Assessment-Intelligence-Platform.md:34` (D2 "OCR/OMR **not pursued**", Marks-Grid instead); `GAP_ANALYSIS.md` C7 "no workstream may build per-student answer-sheet capture" | **⛔ OWNER DECISION D1 — PENDING, NOT approved (see §4-D1). Do NOT build F1/F2/F3 until confirmed.** *If confirmed:* build new; retain Marks-Grid as "Mixed Mode" |
| **SOP-F2** | **Continuous Auto Capture & Auto Scan** — auto sheet detection, capture, score, continuous loop | ❌ MISSING | no camera/scan pipeline in exam/assessment code | New (depends on F1) |
| **SOP-F3** | **OMR Profile Engine** — per-exam answer key, marks/question, negative marking, sections | ❌ MISSING (for evaluation) | `edu_exam_profiles` is a **QP-generation** profile, not scoring; `negative_marking` = 0 hits | New (evaluation profile ≠ existing generation profile) |
| **SOP-F4** | **School-level Evaluation Workflow** — any authorized staff evaluates | ✅ **EXISTS** | marks entry→verify→submit→publish, RBAC across many staff roles (`exam_marks_entry_screen.dart:432-940`, `20260628000000_exam_governance_authz.sql:34-39`) | **Extend** to feed F1/F5; likely mostly DONE — verify against DoD |
| **SOP-F5** | **Question Heatmap** — auto question-wise correctness stats after evaluation | ❌ MISSING (data spine dormant) | `edu_student_item_responses` exists but **zero callers** (`20260853000000_*.sql:12-34`); reports aggregate only at student/subject/class level | New — **activate the dormant response spine**, then build item-analysis |
| **SOP-F6** | **Teacher-controlled Timed Online Exams** — optional, teacher-enabled, timed | ❌ MISSING | only schedule-display + results-view (`exam_models.dart:1-92`); no exam-taking/timer engine | New |
| **SOP-F7** | **Weak Concept Analysis Enhancement** — "Repeated Weakness" indicator + concept history + better remedials in **existing Student 360 / QIE** (no separate AI module) | ⚠ **PARTIAL** | Student 360 real (`student_360_screen.dart`); weak-topic analysis coarse (`homework_intelligence_service.ts:44-90` uses `exam_title` as "topic"); **no "repeated weakness" indicator** | **Extend** Student 360 + intelligence services; add concept-level history + repeated-weakness flag |
| **SOP-F8** | **Dynamic Workspace / Workflow Builder** — school-configurable pages/workflows from reusable components | ⚠ PARTIAL | dashboard-widget layout editor real (`dynamic_widget_layout_editor_screen.dart`); `WorkflowEngine` real but **hardcoded seed** definitions (`workflow_registry.dart:6-90`); no form/page builder | **Extend** — make workflow definitions admin-configurable; add configurable pages/fields |
| **SOP-F9** | **Dynamic Approval Engine** — audit existing; improve if partial; implement if missing | ⚠ PARTIAL | generic `approval_requests` + adapters + SoD real, but **fixed 14-value enum + hardcoded routing**, no multi-level/threshold, no admin config (`approval_request_type.dart`, `approval_permissions.dart:5-23`) | **Extend to dynamic** — configurable types/routing/multi-level chains; keep SoD |
| **SOP-F10** | **Dynamic Certificate Builder** — audit existing; improve if partial; implement if missing | ⚠ PARTIAL | 4 fixed cert types (bonafide/study/conduct/transfer) with real TC engine + serials; **PDF layout hardcoded, no template abstraction** (`sis_certificate_pdf_service.dart`) | **Extend** — add configurable template/field builder + custom types |
| **SOP-F11** | **Smart Dynamic Filters** — saved/reusable filters & lists across modules | ❌ MISSING | only per-screen non-persisted chips (`admin_filter_bar.dart:10-25`); zero saved-filter/saved-list code | New — cross-module saved-filter/saved-list primitive |
| **SOP-F12** | **Advanced Search Filters** — extend existing Universal Search with rich filters + saved searches | ✅ EXISTS (partial breadth) | Universal Search entity resolver real (W2.S, `search_repository.ts`), **6/12 categories built, Flutter-only**; web ⌘K is nav-only; no saved searches | **Extend** existing Universal Search (breadth + web parity + saved searches via F11) — never a new search stack |

**Track B exit:** every SOP-F item passes the 15-point DoD + EOS; extensions layered onto existing
engines (no duplicate modules); F1–F3 gated on the Decision Register §4-D1 resolution.

---

## 4. Decision Register (owner sign-off required where flagged)

- **D1 — ⛔ PENDING, NOT approved. Smart OMR vs frozen Assessment-Intelligence D2.** D2 (product law,
  2026-07-02) says *"per-student answer-sheet OCR/OMR is **not pursued** — Marks-Grid instead"*; D2's
  own text says *"Changes require an explicit owner decision."* SOP-F1/F2/F3 would reverse it.
  **Recorded as a PROPOSED owner override awaiting explicit confirmation — the override is NOT adopted
  and F1/F2/F3 must NOT be built on this assumption.** *If* the owner confirms, the intended shape is:
  build new; retain Marks-Grid as one capture mode ("Mixed Mode"); and only then amend the
  Assessment-Intelligence decision doc + memory to record the supersession (not before).
- **D2 — ⛔ PENDING, NOT approved. Execution placement / sequencing.** A *proposed* (not adopted) shape
  is: Track A (SOP-ID) before P4 Red Team / P6 Pilot; Track B (SOP-F) before CFC-1/FREEZE-1, parallel
  to / after PRC — which **would extend the pre-GA timeline.** This placement is **not adopted**; SOP
  items remain recorded roadmap items / audit findings only, to be sequenced by the owner **after all
  audits complete.** Implementation must not assume this order.
- **D3 — Student-login-via-parent-mobile (SOP-ID-4)** must be reconciled with the frozen *Student
  Identity Architecture Decision* (student phone NEVER required; login = OTP-to-parent). The current
  code deviates; SOP-ID-4 closes the gap **toward** the frozen decision. No conflict — confirming
  alignment.
- **D4 — Anti-duplication reconciliation (applied):** SOP-ID-2↔`PRA-P2-28`; SOP-ID-3↔`PRA-P1-04/51/52`,
  `PRA-P2-27`; SOP-ID-5↔`P1-CODE-4`. These existing items are **elevated/extended**, not duplicated.
  SOP-F4/F12 largely exist and are extended; SOP-F7/F8/F9/F10 are partial and extended; SOP-F1/F2/F3/
  F5/F6/F11 are net-new.

## 5. Traceability

Owner directive (2026-07-17) → this spec (SOP-ID-1..5, SOP-F1..12) → master roadmap Program SOP
section → per-item EOS gates + 15-point DoD. Audit evidence →
[`IDENTITY_AND_LOGIN_ARCHITECTURE_AUDIT.md`](IDENTITY_AND_LOGIN_ARCHITECTURE_AUDIT.md). No SOP row may
be silently removed/re-scoped — changes route through §4.
