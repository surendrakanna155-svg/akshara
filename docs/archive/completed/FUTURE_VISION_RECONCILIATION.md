# Future Vision Reconciliation

**Version:** 1.0  
**Date:** June 2026  
**Purpose:** Cross-check `FutureVision.md` against `AKSHARA_MASTER_FEATURE_REGISTRY.md`  
**Sources:** FutureVision v2.0 · Master Registry v1.0 · Vision Gap Analysis · Roadmap · Owner Dashboard Audit

---

## Executive summary

| Category | Count |
|----------|-------|
| FutureVision numbered capabilities (#1–#36) | 36 |
| Registry rows with direct traceability | 28 |
| **Missing from registry** | **12** |
| **Partial / under-represented** | **18** |
| **Duplicate clusters** | **8** |
| **Deprecated / misleading** | **2** |
| P4 unnumbered platform tracks missing | **5** |
| Section A–G gaps | **4** (A, B, C, G narrative) |

**Conclusion:** Core ERP and intelligence **shells** are well tracked. **Phase 5 evolution** (Book Distribution, School Memories, Growth, Branding, Org Builder, Widget Platform, vertical packs) and **operational continuity** features (reassignment migration) need registry rows added in v1.1.

---

## Features found only in FutureVision.md

These appear in FutureVision but had **no dedicated registry row** before this reconciliation pass:

| # | Capability | FutureVision tier | Action taken |
|---|------------|-------------------|--------------|
| 11 | Book Distribution System | P3 · shipped v10.1 | **Added** to registry (Evolution) |
| 12 | Inventory Replacement Workflow | P3 | **Added** (Inventory) |
| 17 | School Memories | P2 · shipped v10.2 | **Added** (Evolution) |
| 20 | School Branding | P2 | **Added** (Platform) |
| 28 | AI Parent Meeting Summary | P2 | **Added** (Intelligence) |
| 29 | Universal AI Assistant | P3 | **Added** (Intelligence) |
| 30 | Universal Organization Builder | P3 · design v10.4 | **Added** (Platform) |
| 31 | Dynamic Widget Platform | P3 · design | **Added** (Platform) |
| 32 | Multi-Industry Platform Foundation | P4 | **Added** (Platform) |
| 33–36 | Salon / Hospital / Restaurant / Hostel vertical packs | P3–P4 | **Added** (Platform) |
| — | AI School Setup Wizard (Section A) | v10.6 design | **Added** (Platform) |
| — | Security & Pen Testing | P4 | **Added** (Platform) |
| — | Observability & Monitoring | P4 | **Added** (Platform) |
| — | Multi-School SaaS Operations | P4 | **Added** (Platform) |
| — | Franchise / Multi-Branch Management | P4 | **Added** (Platform) |

---

## Features missing from registry (pre-update)

| Gap | Business impact | Priority |
|-----|-----------------|----------|
| Book Distribution (#11) | Textbook lifecycle — shipped but untracked | P1 |
| School Memories (#17) | Alumni engagement — shipped but untracked | P2 |
| School Branding (#20) | White-label pilot schools | P2 |
| Growth Platform (#18) | Referrals/campaigns — only AD funnel row | P1 |
| Universal Workflow Engine | Design complete; no registry row | P2 |
| Reassignment communication continuity | Not in FutureVision # but product-critical | P2 |
| Owner dashboard export / KPI drill-down | Audit gaps; partial MG rows | P1 |

---

## Duplicate features (consolidation guidance)

| Vision ID | Overlapping registry rows | Recommendation |
|-----------|---------------------------|----------------|
| #3 Student Risk | Student Risk Prediction · At-risk detection · Attendance predictions | Keep one parent row + sub-capabilities |
| #5 Principal Copilot | Principal Copilot · School health · Insight cards · Intelligence hub · Command Center | Single **Principal Intelligence** epic |
| #9 Workload | Timetable optimization · Teacher workload balancing | Single **Workload Engine** row |
| #13–16 Payments | Payment engine bundle · QR/offline row | Single **Unified Payment Engine** row |
| #22–27 Education Suite | Academic AI rows · Intelligence umbrella · Remark publish | One suite row + module children |
| #18 Growth | Marketing funnel · Campaign automation (F) | Restore Growth Platform row; deprecate AD-only row |
| Operations Hub | Management Operations Hub · Operations automation alerts | Merge under ROAD v10.0 |
| Finance AI | Finance Copilot · Fee collection insights | Merge under Finance intelligence |

---

## Deprecated ideas

| Item | Status | Notes |
|------|--------|-------|
| `Campaign automation` as AD-native | **Misclassified F** | FutureVision #18 still active as Growth Platform |
| Unified ERP Exam Admin | **F — scope undefined** | Product decision required; not in FutureVision # list |
| Legacy `ProjectStatus.md` metrics | **Superseded** | Use Roadmap v2.0 |

---

## Newly discovered requirements (not in original FutureVision # table)

From SRS, Owner Dashboard Audit, and completion program:

| Requirement | Source | Registry status |
|-------------|--------|-----------------|
| Student reshuffle / section balancing | SRS / Principal spec | Added (SIS) — Class D/E |
| Teacher reassignment continuity | Product vision | Added (Teacher) — Class D/E |
| Notification/message ownership migration | Product vision | Added (Communication) — Class E |
| Management dashboard export | Owner audit | **P1 — Phase E target** |
| KPI drill-down on MG-01 | Owner audit | P1 backlog |
| Admissions settings persistence | ERP P0→P1 | P1 backlog |
| Inventory PO approve | ERP P0→P1 | P1 backlog |

---

## Shipped in FutureVision but under-tracked in registry

| Release | Capability | Registry before | Registry after |
|---------|------------|-----------------|----------------|
| v10.1 | Book Distribution (#11) | Missing | **B** partial |
| v10.2 | School Memories (#17) | Missing | **B** partial |
| v10.3 | Achievement Promotion (#19) | D mock only | **B** partial |
| v10.0 | Operations Hub | B read-only | unchanged |
| v9.8 | Parent Experience Bridge | B partial | unchanged |

---

## Traceability matrix (FutureVision # → Registry module)

| # | Name | Module | Class |
|---|------|--------|-------|
| 1 | AI Communication Assistant | Notifications | D |
| 2 | Communication Hub Expansion | Notifications | D/E |
| 3 | Student Risk Intelligence | Intelligence | D |
| 4 | Parent Guidance Assistant | Parent mobile | D |
| 5 | Principal Copilot | Management / Intelligence | B/D |
| 6 | Teacher Copilot | Teacher | D |
| 7 | Multi-Role Employee | HR / Phase5 | D |
| 8 | Smart Timetable | Timetable | A/B |
| 9 | Workload Engine | Timetable / Teacher | D |
| 10 | Inventory & Asset Expansion | Inventory | B |
| 11 | Book Distribution | Evolution / Library | B |
| 12 | Inventory Replacement | Inventory | E |
| 13–16 | Payment engine family | Finance / Parent | B/E |
| 17 | School Memories | Evolution / Alumni | B |
| 18 | Growth Platform | Marketing / Growth | B/D |
| 19 | Achievement Promotion | Evolution | D |
| 20 | School Branding | Platform / Admin | E |
| 21 | Academic Year Transition | SIS | B/E |
| 22–27 | AI Education Suite | Education / Intelligence | A |
| 28 | Parent Meeting Summary | Intelligence | E |
| 29 | Universal AI Assistant | Platform | E |
| 30 | Organization Builder | Platform | E |
| 31 | Dynamic Widget Platform | Platform / Management | E |
| 32 | Multi-Industry Foundation | Platform | E |
| 33–36 | Vertical ERP packs | Platform | E |

---

## Maintenance

Re-run this reconciliation when:

1. `FutureVision.md` version bumps  
2. A release doc claims “shipped” for a # capability  
3. Registry version increments  

**Next registry version:** 1.1 (rows added in Phase D)

**Related:** `AKSHARA_MASTER_FEATURE_REGISTRY.md` · `ADVANCED_FEATURE_STATUS.md` · `AKSHARA_FINAL_ROADMAP.md`
