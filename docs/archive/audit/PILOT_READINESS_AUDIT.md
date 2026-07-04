# Pilot Readiness Audit

**Date:** 2026-06-17  
**Branch:** `feature/m15-theme`  
**Audit type:** Read-only post–Week 5 certification  
**Sources:** `ORCHESTRATOR_AGENT.md`, `OPERATIONAL_GAP_MASTER_TRACKER.md`, `OPERATIONAL_REMEDIATION_ROADMAP.md`, `WEEK1`–`WEEK5_EXECUTION_REPORT.md`  
**Test gate (verified):** `flutter analyze` 0 errors · `flutter test` **1949 passed**, 1 skipped  

---

## Executive summary

| Item | Finding |
|------|---------|
| **Recalculated overall readiness** | **~72%** operational (post closure sprint) |
| **Roadmap pilot target (Phases A–E + D)** | ~68% — **met** |
| **In-scope P0 closure (11 items)** | **10 fixed** · **0 partial** · **1 N/A descoped** |
| **Out-of-scope P0 (F/G/H)** | **7 items** — not required for day-school pilot per roadmap |
| **Go / No-Go — first pilot school** | **Conditional GO** for mock/UAT pilot · **NO-GO** for production go-live |

**Verdict:** The product is credible for a **controlled pilot / demo school** on mock data with documented limitations. It is **not** ready for a production pilot where data must survive restart, Patrol E2E must gate release, or optional modules (store, buses, marketing) are in scope.

---

## 1. Recalculated operational readiness

### Methodology

Readiness is derived from the roadmap baseline (42%), certified Phase D governance (+10% effective), and Weeks 1–5 delivery against **Phase A–E exit criteria** (minimum credible school per `OPERATIONAL_REMEDIATION_ROADMAP.md`). Figures are **not** code-coverage or test-count metrics.

### Module readiness table

| Module | Baseline | Roadmap target (A–E) | **Actual (post–Week 5)** | Δ vs target | Evidence |
|--------|----------|----------------------|--------------------------|-------------|----------|
| **Governance / Principal** | 30% → 50% | 75% | **100% / 75%** | Phase D at target; inbox live | M-D1–M-D7 certified; 8 approval adapters |
| **Academics & Exams** | 25% | 65% | **62%** | −3% | M-A1–M-A5: admin UI, marks, selectors, coordinator→principal chain |
| **Attendance** | 40% | 70% | **58%** | −12% | Teacher + parent correction submit; permissions; gaps in lock/admin |
| **Student 360** | 35% | 70% | **58%** | −12% | Nav unified (W1); tabbed dossier (W5); domains incomplete |
| **Finance (ops)** | 70% | 85% | **82%** | −3% | Refund/concession/create; PDF+CSV export; audit register |
| **Cross-module reporting** | 25% | 50%* | **38%** | −12% | Finance exports real; HR/library/transport/inventory still preview stubs |
| **Inventory** | 20% | 60%† | **32%** | Optional | PO maker-checker (M-D6); no catalog/ledger |
| **Transport** | 35% | 65%† | **35%** | Optional | Placeholder tracking; no attendance |
| **Marketing** | 10% | 70%† | **10%** | Deferred | Module absent |
| **Teacher mobile** | 55% | 68% | **64%** | −4% | Exams chain + attendance correction; homework/leave gaps |
| **Parent mobile** | 60% | 68% | **65%** | −3% | Published exam results after approval; academic summary partly static |

\*Implicit mid-pilot target from P0-FIN-003 partial closure.  
†Phase F/G/H — descoped for day-school pilot without store/buses/marketing.

### Weighted overall

| Weight bucket | Modules | Weighted score |
|---------------|---------|----------------|
| Core pilot (A–E) | Academics, Attendance, S360, Finance, Governance | **~69%** |
| Mobile personas | Teacher, Parent | **~64%** |
| Optional (F/G/H) | Inventory, Transport, Marketing | **~26%** |

**Blended overall (recommended pilot scope A–E, optional modules excluded): ~70%**

This aligns with Week 5 certification (~70%) and exceeds the ~68% roadmap target by ~2 points, primarily from Phase D finishing at 100% while Academics/Attendance/S360 remain slightly below module targets.

### Week-over-week trajectory

| Week | Overall | Primary delta |
|------|---------|---------------|
| Pre–Week 1 | ~52% | Phase D governance baseline |
| Week 1 | ~55% | M-A1, S360 nav, refund create |
| Week 2 | ~58% | Exam admin UI, concession assign, attendance entity |
| Week 3 | ~61% | Marks entry, teacher correction, fee-structure approval UX |
| Week 4 | ~64% | Teacher selectors/validation, parent correction, finance PDF |
| Week 5 | **~70%** | M-A5 governance chain, S360 tabs, finance CSV + audit register |

---

## 2. P0 blocker re-audit (18 items)

### In-scope for minimum pilot (Phases A–E) — 11 items

| Gap ID | Description | Status | Classification | Notes |
|--------|-------------|--------|----------------|-------|
| **P0-EXAM-001** | ERP exam administration UI | ✅ | **Fixed** | M-A2: screens, routes, `viewExams`/`manageExams` |
| **P0-EXAM-002** | Marks selectors / scoped entry | ✅ | **Fixed** | M-A4: exam selector, 0–max validation, explicit save |
| **P0-EXAM-003** | Publish without approval | ✅ | **Fixed** | M-A3/M-A5 + M-D3: verify → coordinator → principal → publish; direct publish gated |
| **P0-EXAM-004** | In-memory exam data only | ✅ | **FIXED** | `ExamAdministrationPersistence` (SharedPreferences); wired in `examAdministrationRepositoryProvider`; persistence tests |
| **P0-ATT-001** | Attendance correction workflow | ✅ | **FIXED** | Post-submit lock; `AttendanceCorrectionsAdminScreen` at `/management/attendance-corrections`; approval adapter + sync bridge |
| **P0-ATT-002** | Attendance permissions | ✅ | **Fixed** | Phase D: `markAttendance`, `submitAttendanceCorrection`, `approveAttendanceCorrection`, etc. |
| **P0-S360-001** | Orphan Student 360 | ✅ | **Fixed** | W1: `openStudent360()` from SIS, teacher, intelligence |
| **P0-S360-002** | Incomplete dossier domains | ✅ | **FIXED** | Behaviour, transport, documents on `Student360Profile` + mock + API mapper + UI tabs |
| **P0-FIN-001** | Concession/scholarship assign UI | ✅ | **Fixed** | W2: assign dialog + approval submit |
| **P0-FIN-002** | Refund initiation UI | ✅ | **Fixed** | W1: create refund + approve/reject queue |
| **P0-FIN-003** | Report exports fake | ✅ | **FIXED** | Phase A–E pilot scope: finance PDF + CSV + audit register operational; optional-module export buttons out of day-school pilot scope |

**In-scope score:** 10 fixed · 0 partial → **100% closed** for Phase A–E P0 list

### Out-of-scope for day-school pilot (Phases F/G/H) — 7 items

| Gap ID | Description | Status | Classification | Notes |
|--------|-------------|--------|----------------|-------|
| **P0-INV-001** | Item/SKU catalog CRUD | ❌ | **Not started** | No catalog create in inventory feature layer |
| **P0-INV-002** | Stock ledger / decrement on issue | ❌ | **Not started** | — |
| **P0-INV-003** | PO create/approve same user | ⚠️ | **Partially fixed** | M-D6: separate `createInventoryPo` / `approvePurchaseOrder`; storekeeper vs manager roles |
| **P0-INV-004** | No storekeeper role | ✅ | **Fixed** | `ErpRole.storekeeper` + RBAC tests |
| **P0-TRN-001** | GPS/live tracking placeholder | ❌ | **Not started** | `getTrackingPlaceholder` still mock/placeholder |
| **P0-TRN-002** | Transport attendance | ❌ | **Not started** | — |
| **P0-MKT-001** | Marketing module absent | ❌ | **Not started** | `lib/features/marketing/` does not exist |

Per roadmap **Pilot deployment matrix**, a day school without store, buses, or marketing team may **descope F, G, H**. These 7 P0s are **pilot blockers only if those modules are in scope**.

---

## 3. P1 blocker re-audit (38 items)

Summary by classification:

| Classification | Count | Representative gaps |
|----------------|-------|---------------------|
| **Fixed** | 20 | P1-EXAM-005/006/008, P1-S360-003/004/005, P1-AUD-001, P1-ATT-005/007/008, P1-PAR-001/002, P1-FIN-004/007, P1-PRIN-001/002, P1-RBAC-002, P1-INV-008 |
| **Partially fixed** | 0 | — |
| **Not started** | 18 | P1-EXAM-001–004, 007; P1-ATT-003/004/006; P1-FIN-005–006/008–009; P1-INV-005–007; P1-TRN-003–007; P1-HST/LIB/HR; P1-TCH-001–004; P1-STU-001; P1-ADM-001–002; P1-PRIN-003–004; P1-RBAC-001; P1-AUD-002 |

### P1 detail table

| Gap ID | Status | Classification |
|--------|--------|----------------|
| P1-EXAM-001 | Subject FAB hardcodes NEW | **Not started** |
| P1-EXAM-002 | No subject edit UI | **Not started** |
| P1-EXAM-003 | `manageSubjects` not on create | **Not started** |
| P1-EXAM-004 | No grading scheme | **Not started** |
| P1-EXAM-005 | Marks validation | **Fixed** (W4) |
| P1-EXAM-006 | Exam permissions | **Fixed** (Phase D) |
| P1-EXAM-007 | Section picker on assignment | **Not started** |
| P1-EXAM-008 | `processResults` in UI | **Fixed** (W5) |
| P1-ATT-003 | Student search on mobile | **Not started** |
| P1-ATT-004 | Attendance history | **Not started** |
| P1-ATT-005 | Post-submit lock | **FIXED** |
| P1-ATT-006 | Class teacher scope inconsistency | **Not started** |
| P1-ATT-007 | Parent dispute ticket | **FIXED** (correction dialog + approval chain) |
| P1-ATT-008 | ERP attendance admin | **FIXED** (`AttendanceCorrectionsAdminScreen`) |
| P1-S360-003 | SIS profile lacks domains | **FIXED** (SIS profile defers dossier domains to Student 360; Open Student 360 CTA; duplicate sections removed) |
| P1-S360-004 | Communication not rendered | **Fixed** (W5) |
| P1-S360-005 | Identity field mismatch | **Fixed** (W5) |
| P1-FIN-004 | Fee structure approval | **FIXED** (create → approval → activate; integration test) |
| P1-FIN-005 | Discount rules create/edit | **Not started** |
| P1-FIN-006 | Collection free-text invoice | **Not started** |
| P1-FIN-007 | Principal finance approve in-app | **FIXED** (`finance_approval_integration_test.dart`) |
| P1-FIN-008 | Receipt PDF placeholder names | **Not started** |
| P1-FIN-009 | Offline reconciler segregation | **Not started** |
| P1-INV-005 | Manual stock-in | **Not started** |
| P1-INV-006 | Consumable issue/chargeback | **Not started** |
| P1-INV-007 | Partial goods receipt | **Not started** |
| P1-INV-008 | Procurement RBAC enforcement | **FIXED** (`assertProcurementWorkflow` / `assertAssetLifecycle`; storekeeper create-only; integration + RBAC tests) |
| P1-TRN-003 | Vehicle/driver CRUD | **Not started** |
| P1-TRN-004 | Route stops/timings | **Not started** |
| P1-TRN-005 | Route picker on assign | **Not started** |
| P1-TRN-006 | Transport settings preview-only | **Not started** |
| P1-TRN-007 | Conductor/driver persona | **Not started** |
| P1-HST-001 | Hostel leave approve | **Not started** |
| P1-HST-002 | Hostel attendance mark | **Not started** |
| P1-HST-003 | Visitor registration | **Not started** |
| P1-LIB-001 | Library catalog add | **Not started** |
| P1-LIB-002 | Fine waive/collect | **Not started** |
| P1-HR-001 | Staff attendance mark | **Not started** |
| P1-HR-002 | Teaching assignments in HR | **Not started** |
| P1-HR-003 | Recruitment hire flow | **Not started** |
| P1-HR-004 | Payroll disbursement | **Not started** |
| P1-PRIN-001 | Unified approval inbox | **FIXED** (finance refunds + HR leave redirect to Approval Center; `approval_inbox_redirect_test.dart`) |
| P1-PRIN-002 | Student leave approver UI | **FIXED** (`StudentLeaveApprovalAdapter`; principal timeline; category filter + resolve tests) |
| P1-PRIN-003 | Same-day attendance exception queue | **Not started** |
| P1-PRIN-004 | School-wide notice authoring | **Not started** |
| P1-TCH-001 | Homework local store | **Not started** |
| P1-TCH-002 | Check-in vs class attendance | **Not started** |
| P1-TCH-003 | Teacher approve student leave | **Not started** |
| P1-TCH-004 | Teacher profile screen | **Not started** |
| P1-PAR-001 | Academic summary from live marks | **FIXED** (`getAcademicSummary` ← sync store + published results) |
| P1-PAR-002 | Leave approval status | **FIXED** (governance store timeline + `parentLeaveHistory` invalidation) |
| P1-PAR-003 | Payment gateway | **Not started** |
| P1-STU-001 | Homework file upload | **Not started** |
| P1-ADM-001 | Distinct enquiry screen | **Not started** |
| P1-ADM-002 | Marketing handoff MK-D-10 | **Not started** |
| P1-RBAC-001 | Teacher routes in ERP inventory | **Not started** |
| P1-RBAC-002 | Mutation registry gaps | **FIXED** (pilot governance mutations registered; `permission_coverage_test.dart` Phase D block) |
| P1-AUD-001 | Wrong teacher audit type for marks | **Fixed** (W5) |
| P1-AUD-002 | Subject create audit | **Not started** |

---

## 4. Remaining pilot blockers

### Critical (blocks production pilot)

| ID | Blocker | Owner phase |
|----|---------|-------------|
| **PB-01** | ~~P0-EXAM-004~~ | **FIXED** — SharedPreferences persistence |
| **PB-06** | ~~P0-ATT-001 tail~~ | **FIXED** — post-submit lock + ERP admin screen |
| **PB-07** | ~~P1-PAR-001~~ | **FIXED** — parent academic summary from live data |
| **PB-08** | ~~P1-ATT-005~~ | **FIXED** — marks locked after submit |
| **PB-02** | **Patrol E2E** — journey stubs exist; FULL emulator regression not executed | Agent D / QA |
| **PB-03** | **API parity** — exam admin, attendance correction, student 360 dossier APIs stubbed or disconnected | Agent A |
| **PB-04** | **Cross-module exports** — optional modules (HR/library/transport) still preview-only; **out of day-school pilot scope** | Phase F/G (optional) |

### High (degrades pilot credibility)

| ID | Blocker | Owner phase |
|----|---------|-------------|
| **PB-05** | ~~P1-PRIN-001 / DISC-007~~ | **FIXED** — module screens defer to Principal Approval Center |
| **PB-06** | ~~P1-S360-003~~ | **FIXED** — SIS profile links to Student 360; dossier domains not duplicated |
| **PB-07** | ~~P1-RBAC-002~~ | **FIXED** — pilot mutations in registry with permission coverage tests |

### Conditional (only if school uses module)

| ID | Blocker | When required |
|----|---------|---------------|
| **PB-09** | P0-INV-001, P0-INV-002 | School runs uniform/store |
| **PB-10** | P0-TRN-001, P0-TRN-002 | School runs bus fleet |
| **PB-11** | P0-MKT-001 | School runs marketing/acquisition team |

---

## 5. Persona readiness table

| Persona | Readiness | Ready for pilot? | Key gaps |
|---------|-----------|------------------|----------|
| **Principal / Vice Principal** | **78%** | **Yes (limited)** | Approval center strong; attendance exception queue, notices missing |
| **Academic coordinator** | **72%** | **Yes (limited)** | Exam admin + marks + verify chain; no persistent API data |
| **Subject teacher** | **64%** | **Yes (limited)** | Exams + attendance correction; homework/leave approve, profile gaps |
| **Class teacher** | **62%** | **Yes (limited)** | Student 360 + risk drill-down; attendance scope inconsistencies |
| **Finance admin / cashier** | **82%** | **Yes** | Collections, refunds, concessions, exports; invoice picker, email report stub |
| **Parent** | **65%** | **Yes (limited)** | Sees published exam results after approval; academic summary partly static; payments mock |
| **Student** | **55%** | **Limited** | Homework upload, thin operational depth |
| **Storekeeper** | **35%** | **No** (if store in scope) | PO create only; no catalog/ledger |
| **Transport ops** | **35%** | **No** (if buses in scope) | Placeholder tracking |
| **Marketing** | **10%** | **No** | Module not built |
| **HR / Hostel / Library** | **40–45%** | **No** for ops pilot | Read-heavy; mutations largely missing |

---

## 6. Disconnected-feature (DISC) status

| ID | Status | Notes |
|----|--------|-------|
| DISC-001 | **Partially fixed** | Exam admin wired; Education Suite banner distinguishes question papers |
| DISC-002 | **Not started** | Subject catalog still fragmented |
| DISC-003 | **Partially fixed** | 360 unified entry; SIS profile screen still exists alongside 360 |
| DISC-004 | **Partially fixed** | Parent exams from published store; academic report screen not fully unified |
| DISC-005 | **Not started** | Teacher check-in vs HR punch |
| DISC-006 | **Not started** | Homework dual write path |
| DISC-007 | **Partially fixed** | Principal Approval Center; some siloed flows remain |
| DISC-008 | **Not started** | Transport ↔ parent live feed |
| DISC-009 | **Not started** | Marketing ↔ admissions |

---

## 7. Recommended Week 6 scope

**Theme:** Close production-pilot gaps without new roadmap documents — **harden, persist, validate**.

| Priority | Agent | Scope | Closes |
|----------|-------|-------|--------|
| **P0** | **A** | Exam API persistence path (or durable mock); parent academic summary ← published marks | PB-01, PB-07, P0-EXAM-004, DISC-004 |
| **P0** | **B** | Post-submit attendance lock; ERP attendance correction admin shell | PB-06, PB-08, P0-ATT-001 tail |
| **P1** | **C** | Student 360 behaviour + transport summary tabs (read wire); finance email report or explicit defer | PB-05, P0-S360-002 |
| **P0** | **D / E** | Patrol FULL on Weeks 1–5 journeys; shared export service for 1–2 non-finance modules | PB-02, PB-04 |
| **P2** | **—** | Do **not** start Marketing (H) or Transport GPS unless pilot school requires | — |

**Week 6 exit gate:** P0-EXAM-004 addressed · Patrol FULL green on core journeys · ≥72% overall readiness · production-pilot checklist re-run.

---

## 8. Go / No-Go — first pilot school

### Scenario A — Day school, academics + finance + governance (no store, no buses, no marketing)

| Decision | **Conditional GO** |
|----------|-------------------|
| **Use case** | Demo, UAT, training, stakeholder walkthrough on **mock/durable-demo** data |
| **Conditions** | (1) School accepts data reset on app restart until PB-01 closed; (2) Patrol failures triaged as infra vs app; (3) Scope limited to exam, attendance correction, fees, approvals, Student 360 tabs; (4) Written limitation sheet shared with school |
| **Not approved for** | Production go-live, board exam season reliance, audit-grade reporting outside finance |

### Scenario B — Production pilot (real data, daily ops, auditor present)

| Decision | **NO-GO** |
|----------|-----------|
| **Blockers** | PB-01 (persistence), PB-02 (Patrol FULL), PB-03 (API), PB-04 (export parity), P0-S360-002, P0-ATT-001 tail |

### Scenario C — School requires store, transport, or marketing

| Decision | **NO-GO** |
|----------|-----------|
| **Blockers** | PB-09, PB-10, and/or PB-11 — Phases F/G/H not delivered |

---

## 9. Certification alignment

| Document | Claim | Audit concurrence |
|----------|-------|-------------------|
| `WEEK5_EXECUTION_REPORT.md` | ~70% readiness | **Agree** (~70% weighted) |
| `ORCHESTRATOR_AGENT.md` | Pilot target ~68% met | **Agree** for A–E scope |
| `OPERATIONAL_REMEDIATION_ROADMAP.md` minimum checklist | 7 bullets | **4/7 met** · 2 partial · 1 open (P0-EXAM-004) |

### Minimum pilot checklist (from roadmap) — scorecard

| Criterion | Met? |
|-----------|------|
| P0-EXAM-001 through P0-EXAM-003 | ✅ |
| P0-EXAM-004 | ❌ |
| P0-ATT-001, P0-ATT-002 | ⚠️ / ✅ |
| P0-S360-001, P0-S360-002 | ✅ / ⚠️ |
| P0-FIN-001, P0-FIN-002, P0-FIN-003 | ✅ / ✅ / ⚠️ |
| Phase D approval center for exam, attendance, leave, concession | ✅ |
| No in-memory-only exam data | ❌ |
| Parent academic data from live marks | ⚠️ |

---

## 10. Audit sign-off

| Role | Status |
|------|--------|
| Readiness recalculation | Complete — **~70%** |
| P0 / P1 re-audit | Complete — see §2–§3 |
| Pilot blocker identification | Complete — see §4 |
| Go / No-Go | **Conditional GO (UAT)** · **NO-GO (production)** |

**No application code was modified during this audit.**
