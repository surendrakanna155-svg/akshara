# M14 Product Evolution Plan

**Milestone:** M14 — Smart Configuration, UX Modernization & Final Certification  
**Feature ID:** FV-PLAT-14 (Smart School Discovery & Configuration Engine)  
**Date:** 2026-06-16  
**Branch:** `release/v1.0-preprod`  
**SSOT chain:** `FUTURE_VISION_MASTER_INDEX.md` → `AKSHARA_MASTER_FEATURE_REGISTRY.md` → this plan

---

## Purpose

Capture product ideas discussed across gap-closure and pre-Patrol sessions **permanently** — not only in chat history. Verify architectural fit. Implement high-value platform improvements before final Patrol certification.

**Constraint:** No new ERP modules. No placeholder features.

---

## Ideas captured (previously informal)

| ID | Idea | Architecture fit | M14 action |
|----|------|------------------|------------|
| M14-01 | **Smart School Configuration** — ERP configures itself from onboarding answers | Extends FV-30 Org Builder + FV-31 Dynamic Widgets + M9 multi-school | ✅ **Shipped** FV-PLAT-14 |
| M14-02 | **Capability-driven navigation** — hide transport/hostel/library when disabled | `SchoolCapabilityRegistry` + `adminNavDestinationsProvider` | ✅ Shipped |
| M14-03 | **Dynamic dashboard density** — owner/parent dashboards adapt to enabled modules | `school_dashboard_adapter.dart` | ✅ Shipped (owner + parent) |
| M14-04 | **Copilot school context** — board, type, capabilities in AI metadata | `CopilotScreenContext.filters` | ✅ Shipped |
| M14-05 | **Per-role AI access modes** — bubble / bottom nav / sidebar / app bar | INTEL-05 `AiAccessPreferences` | ✅ Completed |
| M14-06 | **UX modernization program** — spacing, KPI hierarchy, mobile density | Design system + screen inventory | 📋 Plan doc (`AKSHARA_UX_MODERNIZATION_PLAN.md`) |
| M14-07 | **Declarative widget layouts per role** — principal/teacher/parent/student | FV-31 dynamic widget platform | 🔄 Partial — config drives modules; full widget codegen post-M14 |
| M14-08 | **School setup wizard for ACC onboarding** | FV-A + ACC-03 | 🔄 Linked from Org Builder hub |
| M14-09 | **Vertical pack auto-selection** from school type (residential → hostel pack) | FV-32 industry framework | ⏳ Recommendation engine in discovery review step |
| M14-10 | **Multi-branch nav surfacing** when `multiBranch=true` | M9 branch operations | ✅ Via capability flag |
| M14-11 | **Trust/director surfacing** when `trustOrganization=true` | M9 director portal | ✅ Via capability flag |
| M14-12 | **Curriculum-aware copilot prompts** (CBSE vs IB) | Copilot metadata | ✅ Shipped in filters |
| M14-13 | **Offline-first config sync** when API connects | Tenant preferences API | ⏳ Local persistence only (pilot) |
| M14-14 | **Patrol certification gate** before expansion | `PATROL_RECERTIFICATION_PLAN.md` | 🔄 Phase 6 in progress |

---

## Architectural alignment

```
FV-PLAT-14 (School Config)
    ├── Organization Builder (FV-30) — interview pattern reused
    ├── Dynamic Widgets (FV-31) — module list → widget pack selection (future)
    ├── Industry Framework (FV-32) — vertical capability registry pattern
    ├── Multi-School (FV-PLAT-02) — branch/trust operations flags
    └── Copilot (INTEL-04/05) — school metadata in context
```

**New code surfaces (M14):**

| Path | Role |
|------|------|
| `lib/core/school_config/` | Models, registry, storage, providers |
| `lib/features/school_config/school_discovery_screen.dart` | Guided wizard UI |
| `lib/core/school_config/school_dashboard_adapter.dart` | Dashboard filtering |
| `lib/router/school_config_navigation.dart` | Route wiring |

---

## Registry update

| ID | Feature | Milestone | Status |
|----|---------|-----------|--------|
| FV-PLAT-14 | Smart School Discovery & Configuration Engine | M14 | ✅ Shipped |

---

## Post-M14 backlog (documented, not roadmap)

| Item | Priority | Notes |
|------|----------|-------|
| Teacher/student dashboard adaptation | P2 | Same adapter pattern as parent |
| Server-side config API + tenant sync | P1 | Production GA |
| Widget layout codegen from config | P2 | FV-31 depth |
| UX modernization execution | P2 | See UX plan phases 1–4 |
| Vertical auto-pack recommendations | P3 | Org builder integration |
| Config-driven RBAC module permissions | P2 | Server RLS alignment |

---

## Related docs

- `docs/AKSHARA_UX_MODERNIZATION_PLAN.md`
- `docs/M14_COMPLETION_REPORT.md`
- `docs/FINAL_GAP_INVENTORY.md`
- `docs/PATROL_RECERTIFICATION_PLAN.md`
