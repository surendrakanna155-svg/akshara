# Future Vision Master Index

> **⏭ SUPERSEDED FOR EXECUTION (2026-07-04, planning review).** This index and its SSOT chain
> (`AKSHARA_MASTER_FEATURE_REGISTRY.md` → `AKSHARA_FINAL_ROADMAP.md` → `MASTER_MILESTONE_TRACKER.md`)
> reference **archived** documents (`docs/archive/`) and a pre-consolidation milestone system (M1–M13)
> that no longer governs anything. The **only** execution plan is
> [`docs/roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md`](../roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md)
> (Future-Vision scope is parked there under 🔮 Future Version / P8-GA-5, per owner decisions O1/O3/O4/O9),
> and the **only** gate is the EOS (`/eos`) — the "Agent G release gates" below are obsolete.
> Retained solely as a historical capability inventory; do not plan or track from this file.

**Version:** 1.1  
**Date:** June 2026  
**Purpose:** Permanent master index for every Akshara capability — feature name, milestone, status, completion %, dependency chain  
**SSOT chain (historical):** This index → `AKSHARA_MASTER_FEATURE_REGISTRY.md` → `AKSHARA_FINAL_ROADMAP.md` → `MASTER_MILESTONE_TRACKER.md` → `DOCUMENTATION_SYNC_REPORT.md` *(all archived)*

**Rule:** No FutureVision item may exist without a row here. No row here may exist without a registry entry and roadmap milestone.

---

## Index legend

| Status | Meaning |
|--------|---------|
| ✅ Shipped | End-to-end with tests |
| 🔄 Partial | Code exists; gaps remain |
| 📐 Design | Architecture doc only |
| ⏳ Planned | Roadmapped, not started |
| ❌ Blocked | Dependency or product decision pending |

| Priority | Tier |
|----------|------|
| P1 | Core school revenue drivers |
| P2 | School differentiators |
| P3 | Platform expansion |
| P4 | Multi-industry / infrastructure |

---

## P1 — Core school revenue drivers

| ID | Feature | Milestone | Status | Completion % | Test | Prod | Depends on | Blocks |
|----|---------|-----------|--------|:------------:|:----:|:----:|------------|--------|
| FV-21 | Academic Year Transition Engine | M1 ✅ | ✅ Shipped | 100 | Yes | Partial | Academic catalog, SIS | Reshuffle, continuity |
| FV-13 | Unified Payment Request Engine | M6 | 🔄 Partial | 55 | Yes | No | v7.0 payments | FV-14, FV-15, FV-16 |
| FV-14 | Online Payment Enhancements | M6 | 🔄 Partial | 60 | Yes | No | FV-13 | Parent conversion |
| FV-15 | QR Payment Support | M6 | ⏳ Planned | 0 | No | No | FV-13, Razorpay | Counter speed |
| FV-16 | Offline Payment Tracking | M6 | ⏳ Planned | 0 | No | No | Finance collections | India reality |
| FV-01 | AI Communication Assistant | M8 | 🔄 Partial | 55 | Partial | No | Comm hub, Copilot | FV-02, FV-29 |
| FV-02 | Communication Hub Expansion | M6 | 🔄 Partial | 45 | Partial | No | FV-01, FV-P4-05 | Broadcast admin |
| FV-P4-05 | WhatsApp Business Integration | M6/M8 | 🔄 Partial | 35 | Contract | No | FV-02, MSG91 | Scale delivery |

---

## P2 — School differentiators

| ID | Feature | Milestone | Status | Completion % | Test | Prod | Depends on | Blocks |
|----|---------|-----------|--------|:------------:|:----:|:----:|------------|--------|
| FV-03 | Student Risk Intelligence | M8 | 🔄 Partial | 60 | Yes | No | Attendance, finance, analytics | Workflow triggers |
| FV-04 | Parent Guidance Assistant | M8 | 🔄 Partial | 50 | Partial | No | FV-01, SIS read | Parent satisfaction |
| FV-05 | Principal Copilot | M8 | 🔄 Partial | 65 | Partial | No | Analytics v7.6 | FV-29 |
| FV-06 | Teacher Copilot | M8 | 🔄 Partial | 50 | Partial | No | Timetable, attendance | Teacher adoption |
| FV-22 | AI Education Suite (umbrella) | M7 ✅ | ✅ Shipped | 95 | Yes | No | Syllabus, Copilot | FV-PLAT-07 |
| FV-23 | AI Question Paper Generator | M7 ✅ | ✅ Shipped | 95 | Yes | No | FV-24, syllabus | Academic diff |
| FV-24 | AI Question Bank | M7 ✅ | ✅ Shipped | 95 | Yes | No | Academic catalog | FV-23, FV-25 |
| FV-25 | AI Homework Generator | M7 ✅ | ✅ Shipped | 90 | Yes | No | FV-24 | Teacher time save |
| FV-26 | AI Worksheet Generator | M7 ✅ | ✅ Shipped | 90 | Yes | No | FV-25 | Practice sheets |
| FV-27 | AI Report Card Remarks | M7 ✅ | ✅ Shipped | 90 | Yes | No | SIS, academics | Report season |
| FV-28 | AI Parent Meeting Summary | M8 | ⏳ Planned | 0 | No | No | Analytics, SIS, FV-PLAT-07 | PTM prep |
| FV-PLAT-07 | AI Content Generation (platform) | M8 | 📐 Design | 15 | No | No | FV-22, Copilot | FV-28, lesson planner |
| FV-08 | Smart Timetable Expansion | M7 | 🔄 Partial | 85 | Yes | Partial | v7.5 timetable | FV-09, publish |
| FV-09 | Workload Engine Expansion | M7 | 🔄 Partial | 35 | Contract | No | FV-08 | Fair scheduling |
| FV-17 | School Memories | M7 | 🔄 Partial | 70 | Partial | No | Storage, comms | Alumni engagement |
| FV-18 | Akshara Growth Platform | M7 | 🔄 Partial | 45 | Partial | No | Analytics, CRM | School acquisition |
| FV-19 | Achievement Promotion Engine | M7 | 🔄 Partial | 65 | Partial | No | SIS, comms | Marketing loop |
| FV-20 | School Branding System | M13 | ⏳ Planned | 0 | No | No | Tenant config | White label pilot |

---

## P3 — Platform expansion

| ID | Feature | Milestone | Status | Completion % | Test | Prod | Depends on | Blocks |
|----|---------|-----------|--------|:------------:|:----:|:----:|------------|--------|
| FV-07 | Multi-Role Employee System | M10 | 🔄 Partial | 40 | Contract | No | RBAC v9.6 | FV-PLAT-01 |
| FV-PLAT-01 | Universal Employee System | M10 | 📐 Design | 10 | No | No | FV-07, v9.9 intel | Multi-industry HR |
| FV-10 | Inventory & Asset Expansion | M6 | 🔄 Partial | 60 | Yes | No | v7.2 inventory | FV-12 |
| FV-11 | Book Distribution System | M7 | 🔄 Partial | 75 | Partial | No | Inventory, SIS | Textbook ops |
| FV-12 | Inventory Replacement Workflow | M7 | ⏳ Planned | 0 | No | No | FV-10 | RMA lifecycle |
| FV-29 | Universal AI Assistant | M8 | ⏳ Planned | 20 | Partial | No | FV-01–06 copilots | FV-30, NL router |
| FV-PLAT-10 | Live AI Inference | M8 | ⏳ Planned | 15 | Partial | No | Copilot infra | FV-03, FV-29 |
| FV-PLAT-05 | Resource Optimization Engine | M8 | ⏳ Planned | 5 | No | No | FV-03, inventory intel | School-wide ops |
| FV-30 | Universal Organization Builder | M10 | 📐 Design | 10 | No | No | FV-29, provisioning | FV-31, verticals |
| FV-31 | Dynamic Widget Platform | M11 | 📐 Design | 15 | No | No | FV-30, Ops Hub schema | Setup UX |
| FV-A | AI School Setup Wizard | M10 | 📐 Design | 25 | Partial | No | v7.15 onboarding | Declarative provision |
| FV-P4-06 | Universal Workflow Engine | M3 ✅ | ✅ Shipped | 90 | Yes | Partial | Achievement, inventory patterns | Vertical packs |

---

## P4 — Multi-industry foundation

| ID | Feature | Milestone | Status | Completion % | Test | Prod | Depends on | Blocks |
|----|---------|-----------|--------|:------------:|:----:|:----:|------------|--------|
| FV-32 | Multi-Industry Vertical Framework | M13 | ✅ Shipped | 85 | Yes | No | FV-30, FV-31 | FV-33–36 |
| FV-33 | Salon ERP Foundation (Velora) / Healthcare (mission) | M13 | ✅ MVP | 75 | Yes | No | FV-32 | New vertical |
| FV-34 | Hospital ERP Foundation / Salon (mission) | M13 | ✅ MVP | 75 | Yes | No | FV-32 | New vertical |
| FV-35 | Restaurant ERP Foundation | M13 | ✅ MVP | 75 | Yes | No | FV-32 | New vertical |
| FV-36 | Hostel ERP Foundation (full) | M13 | ✅ MVP | 80 | Yes | No | Hostel + accommodation pack | Residential ops |
| FV-PLAT-11 | White Label Platform Expansion | M13 | ✅ Shipped | 85 | Yes | No | ACC-08 + white_label module | FV-20 |
| FV-P4-01 | Security & Penetration Testing | M12 | 📐 Design | 5 | No | No | v1.0 GA | Production launch |
| FV-P4-02 | Observability Platform | M12 | ✅ Shipped | 90 | Yes | No | Production traffic | SLOs, tracing |
| FV-PLAT-09 | Monitoring & Alerting | M12 | ✅ Shipped | 85 | Yes | No | FV-P4-02 | Incident response |
| FV-PLAT-06 | Production Readiness Program | M12 | ✅ App layer | 85 | Yes | Partial | All modules | GA gate |
| FV-PLAT-12 | Security Hardening | M12 | ✅ Foundation | 88 | Yes | Partial | v2.7 baseline | FV-P4-01 |
| FV-PLAT-08 | Tenant Isolation Verification | M12 | ✅ Shipped | 90 | Yes | Partial | 213 probes | Multi-school |
| FV-PLAT-13 | RLS Enforcement | M12 | 🔄 Partial | 65 | Yes | Partial | TD-P0-01 | Authoritative data |
| FV-PLAT-02 | Multi-School SaaS Operations | M9 | ✅ Shipped | 85 | Yes | No | First school success | FV-P4-03, FV-P4-04 |
| FV-PLAT-03 | Director Portal (DR-01–09) | M9 | ✅ Shipped | 90 | Yes | No | FV-PLAT-04, Control Center | Chain operators |
| FV-PLAT-04 | Organization / Trust Intelligence | M4/M9 | ✅ Shipped | 90 | Yes | No | Control Center | FV-PLAT-03 |
| FV-P4-03 | Franchise Management | M9 | ✅ MVP | 70 | Yes | No | FV-PLAT-02 | Org governance |
| FV-P4-04 | Multi-Branch Management | M9 | ✅ MVP | 70 | Yes | No | Branch RLS | Branch ops |

---

## Post-RT — Operational Hardening (June 2026)

| ID | Feature | Milestone | Status | Completion % | Test | Prod | Depends on | Blocks |
|----|---------|-----------|--------|:------------:|:----:|:----:|------------|--------|
| FV-POST-01 | Exam Administration Publish Workflow | Post-RT | ✅ Shipped | 85 | Yes | No | Teacher exams, sync store | API persistence |
| FV-POST-02 | Parent Communication Governance | Post-RT | ✅ Shipped | 80 | Yes | No | Class teacher role | FV-POST-11 |
| FV-POST-03 | Class Teacher Governance | Post-RT | ✅ Shipped | 75 | Yes | No | FV-POST-12 | FV-POST-02 |
| FV-POST-04 | Subject Teacher Escalation | Post-RT | ✅ Shipped | 80 | Yes | No | FV-POST-02 | Notifications |
| FV-POST-05 | Student 360 Risk View (mobile) | Post-RT | ✅ Shipped | 75 | Partial | No | FV-03, mock registry | ERP unify |
| FV-POST-06 | Students Requiring Attention Today | Post-RT | ✅ Shipped | 75 | Partial | No | FV-POST-05 | API dashboard |
| FV-POST-07 | Unified Onboarding Wizard | Post-RT | 🔄 Partial | 70 | Yes | Partial | v7.15 onboarding | FV-POST-13 |
| FV-POST-08 | Translation Framework | Post-RT | 🔄 Partial | 65 | Partial | No | i18n catalog | FV-POST-08b |
| FV-POST-08b | Translation Rollout (app-wide) | Post-RT | 🔄 Partial | 25 | No | No | FV-POST-08 | Parent UX |
| FV-POST-09 | Backup & Restore Architecture | Post-RT | 🔄 Partial | 40 | No | No | Admin RBAC | Object storage |
| FV-POST-10 | Red Team Remediation (#1–#25) | Post-RT | ✅ Shipped | 95 | Yes | Partial | RC baseline | Patrol E2E |
| FV-POST-11 | Parent Inbox Integration | Post-RT | 🔄 Partial | 60 | Partial | No | FV-POST-02 | API inbox |
| FV-POST-12 | HR/SIS Teacher Assignment Mapping | Post-RT | 🔄 Partial | 35 | No | No | HR API, SIS | FV-POST-03 |
| FV-POST-13 | School Config Sync (remote) | Post-RT | 🔄 Partial | 30 | Partial | No | FV-POST-07 | Cross-device |
| FV-M15-01 | M15 Theme Modernization | M15 | ⏳ Planned | 5 | No | No | RC lock lift | Visual polish |
| FV-DEF-01 | Academic Assessment Platform | Deferred | 📐 Design | 10 | No | No | Product decision | FV-DEF-02/03 |
| FV-DEF-02 | Formal Question Paper Generation | Deferred | ⏳ Planned | 0 | No | No | FV-DEF-01 | Exam ops |
| FV-DEF-03 | Assessment AI | Deferred | ⏳ Planned | 0 | No | No | FV-DEF-01 | Academic diff |

---

## Completion program (M1–M4) — indexed for traceability

| ID | Feature | Milestone | Status | Completion % | Test | Prod |
|----|---------|-----------|--------|:------------:|:----:|:----:|
| M1-01 | Student promotion engine | M1 ✅ | ✅ | 100 | Yes | Partial |
| M1-02 | Student reshuffle | M1 ✅ | ✅ | 100 | Yes | Partial |
| M1-03 | Section balancing | M1 ✅ | ✅ | 100 | Yes | Partial |
| M1-04 | Performance balancing | M1 ✅ | ✅ | 100 | Partial | Partial |
| M2-01 | Teacher continuity | M2 ✅ | ✅ | 100 | Yes | Partial |
| M2-02 | Timetable continuity | M2 ✅ | ✅ | 100 | Yes | Partial |
| M2-03 | Parent/notification/message continuity | M2 ✅ | ✅ | 100 | Yes | Partial |
| M2-04 | Continuity migration wizard | M2 ✅ | ✅ | 100 | Yes | Partial |
| M3-01 | Workflow rule engine | M3 ✅ | ✅ | 90 | Yes | Partial |
| M3-02 | Triggers, auto-approve, routing, escalation | M3 ✅ | ✅ | 90 | Yes | Partial |
| M4-01 | Platform Owner intelligence | M4 ✅ | ✅ | 100 | Yes | No |
| M4-02 | Organization/Trust intelligence tab | M4 ✅ | ✅ | 55 | Yes | No |
| M4-03 | School comparison, revenue, growth, risk | M4 ✅ | ✅ | 100 | Yes | No |

---

## Dependency chains (critical path)

### Chain A — AI platform moat

```
FV-01 (AI Comms) → FV-04/05/06 (role copilots) → FV-PLAT-10 (Live AI) → FV-29 (Universal AI)
                                                              ↓
                                                    FV-30 (Org Builder) → FV-31 (Widgets)
```

### Chain B — Multi-school SaaS

```
FV-PLAT-08 (Tenant isolation) → FV-PLAT-13 (RLS) → FV-PLAT-02 (Multi-school ops)
                                                              ↓
                              FV-PLAT-04 (Org intel) → FV-PLAT-03 (Director Portal)
                                                              ↓
                              FV-P4-03 (Franchise) + FV-P4-04 (Multi-branch)
```

### Chain C — Multi-industry expansion

```
FV-30 (Org Builder) + FV-PLAT-01 (Universal Employee) → FV-32 (Multi-industry kernel)
                                                              ↓
                              FV-33/34/35/36 (vertical packs) + FV-PLAT-11 (White label)
```

### Chain D — Production hardening

```
FV-PLAT-12 (Security hardening) → FV-PLAT-08 (Tenant verification) → FV-PLAT-13 (RLS)
                                                              ↓
                              FV-P4-02 (Observability) → FV-PLAT-09 (Alerting)
                                                              ↓
                              FV-PLAT-06 (Prod readiness) → FV-P4-01 (Pen test)
```

### Chain E — Academic AI content

```
FV-24 (Question Bank) → FV-23 (Papers) → FV-25/26 (HW/Worksheet) → FV-27 (Remarks)
                                                              ↓
                              FV-PLAT-07 (Content platform) → FV-28 (PTM Summary)
```

---

## Milestone mapping summary

| Milestone | Feature count | Avg completion % |
|-----------|:-------------:|:----------------:|
| M1–M4 (Complete) | 13 | 95 |
| M6 — Remaining P1 ERP | 8 | 35 |
| M7 — Advanced Academic | 10 | 55 |
| M8 — AI Evolution | 12 | 30 |
| M9 — Multi-School SaaS | 6 | 25 |
| M10 — Organization Builder | 4 | 15 |
| M11 — Dynamic Widget Platform | 1 | 15 |
| M12 — Infrastructure & Security | 8 | 45 |
| M13 — Multi-Industry Expansion | 7 | 10 |

---

## Orphan check (last validated June 2026)

| Direction | Orphans found | Action |
|-----------|:-------------:|--------|
| FutureVision → Index | 0 | — |
| Index → Registry | 0 | v1.2 registry sync |
| Registry → Roadmap | 0 | M6–M13 added |
| Roadmap → Master Tracker | 0 | Sections added |

---

## Maintenance

| Event | Update |
|-------|--------|
| New capability proposed | Add row here first; then registry; then roadmap |
| Milestone ships | Status → ✅; bump completion % |
| Design doc created | Status → 📐; link design path |
| Test/Prod gate passes | Update Test/Prod columns |

**Owner:** Agent F · **Validation:** Agent G release gates

**Related:** `FUTURE_VISION_PRESERVATION_AUDIT.md` · `AKSHARA_MASTER_FEATURE_REGISTRY.md` · `docs/Vision/FutureVision.md`
