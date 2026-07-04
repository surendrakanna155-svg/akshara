# Akshara UX Modernization Plan

**Program:** M14 Phase 3 — UX Modernization  
**Date:** 2026-06-16  
**Inspiration:** Stitch design patterns (reference only — **do not copy**)  
**Constraint:** No layout redesign of business logic; improve hierarchy, density, and consistency

---

## Goals

1. Unified visual rhythm across ERP admin, director portal, and mobile apps  
2. Clear KPI → action hierarchy on all dashboards  
3. Consistent AI entry points (INTEL-05 access modes)  
4. Mobile-first usability for parent/teacher/student  
5. Reduced cognitive load on dense admin screens

---

## Screen inventory & priority

| Surface | Current score (UX audit) | Priority | Phase |
|---------|-------------------------:|----------|-------|
| Owner / Management Dashboard | 92 | P1 | 1 |
| Director Portal | 90 | P1 | 1 |
| Intelligence Hub | 88 | P1 | 2 |
| Copilot (dock + full screen) | 85 | P1 | 2 |
| Principal Dashboard | 85 | P2 | 2 |
| Parent App | 85 | P1 | 3 |
| Teacher App | 83 | P2 | 3 |
| Student App | 82 | P2 | 3 |
| Platform Operations | 88 | P3 | 4 |
| Industry vertical MVPs | 80 | P3 | 4 |

---

## Design principles (Akshara-native)

### Spacing

- Use `AksharaSpacing` tokens only — no magic numbers except chart heights  
- Section rhythm: `s4` between related blocks, `s6` between major sections  
- Mobile dashboard padding via `MobileDashboardLayout.screenPadding`

### Card hierarchy

| Level | Use | Style |
|-------|-----|-------|
| L1 — Hero | Greeting, primary KPI | `HeroCard`, elevated surface |
| L2 — KPI | Metric tiles | `ManagementKpiRow`, 3-col desktop / 2-col tablet |
| L3 — Detail | Lists, queues | `Card` + `ListTile`, no double elevation |
| L4 — Insight | AI recommendations | `AksharaInsightCard` with single CTA |

### KPI presentation

- Value first (large numeral), label second, trend third  
- Drillable KPIs: chevron + `onTap` only when route exists (`managementKpiIsDrillable`)  
- Hide KPIs for disabled modules (FV-PLAT-14 `SchoolCapabilityRegistry`)

### Dashboard density

| Breakpoint | KPI columns | Chart layout |
|------------|-------------|--------------|
| Mobile `<768` | 2 | Stacked |
| Tablet `768–1024` | 3 | Side-by-side when width allows |
| Desktop `>1024` | 3–4 | Row layout with 3:2 flex |

### Navigation clarity

- ERP: permission + capability filtered rail (`adminNavDestinationsProvider`)  
- Mobile: max 3 bottom-nav items + center AI slot when `bottomNavCenter` mode  
- Director: tab scaffold with consistent filter chips  
- Breadcrumbs on all ERP module scaffolds

### AI entry consistency

| Mode | Surface | Roles |
|------|---------|-------|
| Floating bubble | `CopilotFloatingDock` | QA + optional overlay |
| Bottom nav center | `CopilotBottomNavAiSlot` | Parent, teacher, student |
| Sidebar entry | Admin rail AI button | Management, principal, module admins |
| App bar action | `AksharaAppBar.showAi` | Finance, admissions |

Settings: `AiAssistantSettingsScreen` — persisted per user per device.

---

## Phase 1 — Executive surfaces (P1)

**Targets:** Management dashboard, Director portal

| Task | Change |
|------|--------|
| KPI row alignment | Equal height tiles, consistent icon size 24dp |
| Approval queue preview | Max 5 items, "View all" CTA |
| Director filter chips | Sticky on scroll for reports/growth screens |
| Export actions | Icon + label, success snackbar pattern |

**Status:** Baseline shipped in v1.0-preprod; M14 adds capability-filtered KPIs.

---

## Phase 2 — Intelligence & AI (P1)

**Targets:** Intelligence hub, Copilot dock, Copilot screen

| Task | Change |
|------|--------|
| Context banner | Show school type + curriculum from FV-PLAT-14 |
| Quick actions | Role-filtered, max 4 visible |
| Dock collapse | 56dp FAB → 280dp panel, no overflow |
| Loading states | `AksharaLoadingState` on all intelligence tabs |

**Status:** Copilot context metadata shipped M14; visual polish backlog.

---

## Phase 3 — Mobile apps (P1–P2)

**Targets:** Parent, teacher, student

| Task | Change |
|------|--------|
| School branding banner | Already in parent shell — extend to teacher/student |
| Quick actions grid | 4 items max on dashboard |
| Transport notices | Hidden when transport disabled (FV-PLAT-14) |
| Bottom nav AI | Center slot per INTEL-05 |

**Status:** Parent adaptation shipped M14; teacher/student adapter pending.

---

## Phase 4 — Platform & verticals (P3)

**Targets:** Platform ops, industry packs, white label

| Task | Change |
|------|--------|
| Vertical MVP scaffolds | Shared `IndustryHubScreen` pattern |
| Tab hub consistency | Match platform operations 9-tab pattern |
| White label theme | `school_branding_theme_provider` on all shells |

---

## Stitch inspiration mapping (do not copy)

| Stitch pattern | Akshara equivalent |
|----------------|-------------------|
| Card-based dashboard | `ManagementKpiRow` + `HeroCard` |
| Floating action | `CopilotFloatingDock` (not FAB for mutations) |
| Bottom navigation | Parent/teacher/student shells |
| Settings list | `AiAssistantSettingsScreen` |
| Onboarding steps | `SchoolDiscoveryScreen` (FV-PLAT-14) |

---

## Success metrics

| Metric | Target |
|--------|--------|
| Widget stress tests | 0 overflow at 390/428/834 widths |
| Golden tests | Pass on macOS for mobile dashboards |
| Patrol navigation suites | 0 product failures post-M14 |
| AI settings persistence | Unit test coverage |

---

## Execution order (post-M14)

1. Teacher/student dashboard adapters (FV-PLAT-14 extension)  
2. Intelligence hub spacing pass  
3. Director portal card width normalization (360dp → responsive)  
4. Golden expansion to director + platform ops (UX-02)  
5. Vertical mobile layout pass (UX-01)
