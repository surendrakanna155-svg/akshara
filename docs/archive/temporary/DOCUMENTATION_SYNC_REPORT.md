# Akshara Documentation Synchronization Report

**Version:** 1.0  
**Date:** June 2026  
**Branch:** `release/v1.0-preprod`  
**Purpose:** Single source of truth after Red Team remediation, operational hardening, and post-M14 work  
**Audience:** New developers, release managers, agent coordinators

---

## Executive summary

Documentation was **out of sync** with code following Red Team remediation, teacher–parent communication governance, exam publish chain, student risk views, translation framework, unified onboarding, and backup architecture work. This report records the June 2026 synchronization pass and remaining gaps.

### Documentation Health Score: **Mostly Aligned**

| Dimension | Score | Notes |
|-----------|-------|-------|
| Roadmap ↔ code | Mostly aligned | Post-RT milestone added to `Roadmap.md` |
| FutureVision ↔ code | Mostly aligned | Sections H–O added |
| Architecture ↔ code | Mostly aligned | New `v1.0-Post-RedTeam-Operational-Hardening.md` |
| Operations ↔ code | Mostly aligned | Five workflow docs created |
| Registry ↔ code | Mostly aligned | New FV-POST rows added |
| Patrol / QA docs | Mostly aligned | Pre-M15 certification 8/8 Patrol green (June 2026) |
| Duplicate / stale docs | Needs work | See § Archive Candidates |

A new developer can onboard from: **`Roadmap.md` → `Vision/FutureVision.md` → `DOCUMENTATION_SYNC_REPORT.md` → `ArchitectureReview/v1.0-Post-RedTeam-Operational-Hardening.md` → `Operations/workflows/`**.

---

## Phase 1 — Discovery Summary

### A. Implemented Features (were undocumented or under-documented)

| Feature | Code evidence | Now documented in |
|---------|---------------|-------------------|
| Exam Administration Publish Workflow | `exam_administration_store.dart` | Architecture §1 · Exam-Publish-Workflow |
| Parent Communication Governance | `parent_communication_governance.dart` | Architecture §2 · Communication workflow |
| Class Teacher Governance | `teacher_assignment_registry.dart` | Architecture §9 · Communication workflow |
| Subject Teacher Escalation | `subject_teacher_concern_store.dart` | Architecture §3 · Escalation workflow |
| Student 360 Risk View | `teacher_student_risk_screen.dart` | Architecture §4 · Student-Risk workflow |
| Students Requiring Attention Today | `attentionForClass()` | Architecture §4 · FutureVision §K |
| Unified Onboarding Wizard | `unified_onboarding_flow_screen.dart` | Architecture §6 · Onboarding workflow |
| Translation Framework | `translation_service.dart` | Architecture §5 · FutureVision §J |
| Backup & Restore (architecture + UI stub) | `backup_restore_screen.dart` | Architecture §7 · FutureVision §M |
| Red Team Remediation (#1–#25) | `RED_TEAM_REMEDIATION_REPORT.md` | Roadmap Post-RT · Architecture review |
| Parent Inbox (mock) | `parent_communication_inbox_provider.dart` | Communication workflow |
| Hybrid write fallbacks | `hybrid_*_repository.dart` | RED_TEAM_REMEDIATION_REPORT |
| Admin Hub | `admin_hub_screen.dart` | RED_TEAM_REMEDIATION_REPORT |
| Copilot capability filter | `copilot_capability_filter.dart` | RED_TEAM_REMEDIATION_REPORT |

### B. Future Vision Items (approved, now documented)

| Item | Location |
|------|----------|
| Communication Vision (class teacher ownership, escalation, audit, receipts) | `FutureVision.md` §H |
| Communication Intelligence (template-first, AI custom-only, tokens) | `FutureVision.md` §I |
| Translation Vision (preferred language, auto-translate, notifications) | `FutureVision.md` §J |
| Student Intelligence (360, attention today, prioritization) | `FutureVision.md` §K |
| Startup Onboarding (unified wizard, go-live, automation) | `FutureVision.md` §L |
| Backup Vision (managed backups, exports, Drive/OneDrive) | `FutureVision.md` §M |
| M15 Vision (premium theme, glass, KPI, illustrations) | `FutureVision.md` §N |
| Academic Assessment Platform (deferred) | `FutureVision.md` §O |

### C. Outdated Documentation (corrected)

| Document | Issue | Correction |
|----------|-------|------------|
| `Roadmap.md` header | Listed v18.1 as current; no Post-RT milestone | Updated to v1.0-preprod + Post-RT table |
| `FutureVision.md` | Missing post-RT vision sections | Added §H–O |
| `FUTURE_VISION_MASTER_INDEX.md` | No Post-RT capability rows | Added FV-POST-* rows |
| `AKSHARA_MASTER_FEATURE_REGISTRY.md` | Post-RT features absent | Added registry rows |
| `AKSHARA_FINAL_ROADMAP.md` | No Post-RT program section | Added program table |
| `MASTER_MILESTONE_TRACKER.md` | Stopped at M14 / stabilization | Added Post-RT milestone |
| `BACKUP_RECOVERY_ARCHITECTURE.md` | Said "no in-app UI by design" | Superseded note added |

---

## Phase 2 — Roadmap Classification

### Implemented (mock-first, unit-tested)

| Item | ID |
|------|-----|
| Exam Administration Publish Workflow | FV-POST-01 |
| Parent Communication System | FV-POST-02 |
| Class Teacher Governance | FV-POST-03 |
| Subject Teacher Escalation | FV-POST-04 |
| Student 360 Risk View | FV-POST-05 |
| Students Requiring Attention Today | FV-POST-06 |
| Red Team Remediation (#1–#25) | FV-POST-10 |
| Translation Framework (core) | FV-POST-08 |

### In Progress

| Item | ID | Blocker |
|------|-----|---------|
| Parent Inbox Integration | FV-POST-11 | API returns empty inbox |
| Translation Rollout | FV-POST-08b | App-wide surfaces English |
| HR/SIS Mapping | FV-POST-12 | Static registry |
| Onboarding Supabase Persistence | FV-POST-07 | `ONBOARDING_API_ENABLED` off |
| School Config Sync | FV-POST-13 | Local prefs only |
| Backup & Restore execution | FV-POST-09 | No object storage / OAuth |
| Unified Onboarding go-live provision | FV-POST-07b | No declarative saga |

### Deferred

| Item | ID | Reason |
|------|-----|--------|
| Academic Assessment Platform | FV-DEF-01 | Red Team scope exclusion |
| Question Paper Generation (formal) | FV-DEF-02 | Requires assessment platform |
| Assessment AI | FV-DEF-03 | Depends on FV-DEF-01 |

### Not Started

| Item | ID | Readiness |
|------|-----|-----------|
| M15 Theme Modernization | FV-M15-01 | `M15_THEME_MODERNIZATION_READINESS.md` — READY TO BEGIN |

---

## Phase 6 — Gap Analysis

### Implemented But Undocumented (before this sync)

All items in §A above — **now documented**.

### Documented But Not Implemented

| Document claim | Reality |
|----------------|---------|
| `FutureVision.md` FV-23–27 as formal exam assessment | Evolution homework/remarks — not formal assessment chain |
| `AKSHARA_FINAL_ROADMAP.md` M8 "Live AI Inference ✅" | Copilot remains stub; capability filter only |
| `BACKUP_RECOVERY_ARCHITECTURE.md` "no in-app UI" | `backup_restore_screen.dart` now exists (stub) |
| Various M8 rows at 100% | Intelligence layer partial; mobile risk not unified with ERP |
| `FUTURE_VISION_MASTER_INDEX` FV-03 at 60% | Mobile teacher risk exists; ERP intelligence separate |

### Future Ideas Not Documented (before this sync)

All items in §B — **now in FutureVision §H–O**.

### Duplicate Documents

| Pair | Recommendation |
|------|----------------|
| `BACKUP_RESTORE_ARCHITECTURE.md` vs `BACKUP_RECOVERY_ARCHITECTURE.md` | **Keep both** — app export vision vs infra PITR; cross-linked |
| `AKSHARA_FINAL_ROADMAP.md` vs `Roadmap.md` | **Keep both** — program view vs release history; sync via this report |
| `docs/AKSHARA_V1_FINAL_STATUS.md` vs `AKSHARA_V1_FINAL_SIGNOFF.md` | Review for merge after pilot |
| `UX_STABILIZATION_REPORT.md` vs `UX_STABILIZATION_FINAL.md` | Archive report; keep FINAL |
| `PERFORMANCE_REVIEW.md` vs `PERFORMANCE_REVIEW_FINAL.md` | Archive review; keep FINAL |

### Archive Candidates

| File | Reason |
|------|--------|
| `docs/UX_STABILIZATION_REPORT.md` | Superseded by `UX_STABILIZATION_FINAL.md` |
| `docs/PERFORMANCE_REVIEW.md` | Superseded by `PERFORMANCE_REVIEW_FINAL.md` |
| `docs/FINAL_PRE_PATROL_STATUS.md` | Point-in-time; superseded by `PATROL_FINAL_CERTIFICATION.md` |
| `docs/QA/overnight_progress.md` | Session log; not SSOT |
| `docs/QA/autonomous_progress.md` | Session log; not SSOT |

**Action:** Add `<!-- ARCHIVE: superseded by X -->` header when archiving; do not delete without release manager sign-off.

---

## Phase 7 — Deliverables

### Updated Files

| File | Change |
|------|--------|
| `docs/Roadmap.md` | v2.1 header; Post-RT milestone table |
| `docs/Vision/FutureVision.md` | v2.1; sections H–O; related docs |
| `docs/FUTURE_VISION_MASTER_INDEX.md` | Post-RT capability rows |
| `docs/AKSHARA_MASTER_FEATURE_REGISTRY.md` | Post-RT registry rows |
| `docs/AKSHARA_FINAL_ROADMAP.md` | Post-RT program section |
| `docs/MASTER_MILESTONE_TRACKER.md` | Post-RT milestone tracker |
| `docs/BACKUP_RECOVERY_ARCHITECTURE.md` | Cross-link to app backup doc |

### New Files

| File | Purpose |
|------|---------|
| `docs/DOCUMENTATION_SYNC_REPORT.md` | This report |
| `docs/ArchitectureReview/v1.0-Post-RedTeam-Operational-Hardening.md` | Architecture SSOT for Post-RT |
| `docs/Operations/workflows/Teacher-Parent-Communication-Workflow.md` | Communication process |
| `docs/Operations/workflows/Exam-Publish-Workflow.md` | Exam publish process |
| `docs/Operations/workflows/Student-Risk-Workflow.md` | Risk / attention process |
| `docs/Operations/workflows/Escalation-Workflow.md` | Subject teacher escalation |
| `docs/Operations/workflows/Unified-Onboarding-Workflow.md` | Onboarding process |

### Archived Files

None moved in this pass — archive candidates listed above for release manager review.

### Future Vision Additions

Sections H–O in `FutureVision.md` (see §B).

### Roadmap Changes

Post-RT milestone with Implemented / In Progress / Deferred / Not Started classification (see Phase 2).

### Remaining Documentation Gaps

| Gap | Owner | Priority |
|-----|-------|----------|
| Run Red Team Patrol E2E suites | Agent E | P1 |
| API persistence docs for comm/exam/risk stores | Agent A | P1 |
| `Teacher.md` spec update for new comm/risk screens | Agent F | P2 |
| `Parent.md` spec update for inbox/acknowledge | Agent F | P2 |
| Consolidate M8 "shipped" claims in FINAL_ROADMAP | Agent F | P2 |
| Academic Assessment Platform — keep deferred banner in design doc | Agent F | P3 |
| M15 execution doc (when branch opens) | Agent B/G | P3 |

---

## SSOT Chain (canonical read order)

```
docs/Roadmap.md                          → What shipped + what's next
docs/Vision/FutureVision.md              → Why + long-term vision
docs/FUTURE_VISION_MASTER_INDEX.md       → Capability index (58+ Post-RT rows)
docs/AKSHARA_MASTER_FEATURE_REGISTRY.md  → Feature-level traceability
docs/MASTER_MILESTONE_TRACKER.md         → Milestone execution board
docs/DOCUMENTATION_SYNC_REPORT.md        → Gap analysis (this file)
docs/ArchitectureReview/v1.0-Post-RedTeam-Operational-Hardening.md
docs/Operations/workflows/              → How operators use the system
AGENTS.md                                → Agent ownership
```

---

## Documentation Health Score

**Mostly Aligned**

- Core post-RT capabilities are documented with architecture and operational flows.
- Roadmap and FutureVision reflect current `release/v1.0-preprod` state.
- Remaining gaps are explicit: production persistence, Patrol validation, module spec updates, and stale duplicate docs pending archive review.

**Path to Fully Aligned:** Run Red Team Patrol → document API persistence layer → update Teacher/Parent module specs → archive superseded session logs.
