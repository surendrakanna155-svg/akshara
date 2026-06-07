# Akshara ERP — Shared Widget Inventory

**Generated:** v0.5.1 stabilization  
**Source:** `lib/shared/widgets/`  
**Method:** ripgrep import/reference count across `lib/`

---

## Core Shared Widgets (`lib/shared/widgets/`)

| Widget | Files Using | Modules | Notes |
|--------|-------------|---------|-------|
| `AksharaKpiCard` | 24 | Parent, Teacher, Student, Admissions, Finance, SIS | Canonical KPI tile |
| `AksharaStatusChip` | 36 | All modules | Status / tone chips |
| `AksharaLoadingState` | 49 | All modules | Loading placeholder |
| `AksharaErrorState` | 44 | All modules | Error placeholder |
| `AksharaEmptyState` | 41 | All modules | Empty placeholder |
| `AksharaSectionHeader` | 34 | All mobile + ERP modules | Section titles |
| `AksharaAppBar` | 29 | Parent, Teacher, Student dashboards | Mobile app bar |
| `AksharaInsightCard` | 11 | Dashboards (mobile + ERP) | AI insight panels |
| `AksharaWarningBanner` | 11 | Admissions, Finance, Leads | Warning strips |
| `AksharaQuickActionCard` | 4 | Student dashboard | Quick actions |
| `AksharaContextChip` | 3 | Teacher, Student app bars | Context labels |
| `AksharaPeriodPill` | 2 | Timetable rows | Period indicators |
| `AksharaChildSelectorChip` | 1 | Parent app bar | Child switcher |
| `AksharaVirtualizedDataTable` | 3 | Admissions, Finance, SIS | Paginated virtualized tables (v3.1) |
| `AksharaPaginationBar` | 6 | Admissions, Finance, SIS, HR, Transport | Page controls for paginated lists (v3.1–v4.1) |
| `AksharaManageAction` | 0 | — | Mutation button RBAC wrapper (v4.0) |
| `AksharaApproveAction` | 5 | Admissions, Finance, SIS | Approve/mutation RBAC wrapper (v4.5) |

---

## Module-Specific Duplication Opportunities

These patterns duplicate shared-widget composition. Consolidation candidates for a future `lib/shared/module/` package:

| Pattern | Copies | Locations | Consolidation |
|---------|--------|-----------|---------------|
| `*KpiRow` | 3 | Admissions, Finance, SIS | Extract `AksharaKpiRow<T>` generic |
| `*ResponsiveGrid` | 3 | Admissions, Finance, SIS | Move to `lib/shared/layout/` |
| `*SubNav` + `*ModuleScaffold` | 3 | Admissions, Finance, SIS | Generic `ErpModuleScaffold` |
| `*HandoffQueue` / `*EnrollmentQueue` | 2 | Finance, SIS | Shared `ErpHandoffTable` |
| `*ChartPanel` / `*TrendChart` / `*DistributionPanel` | 3 | Admissions, Finance, SIS | Shared chart primitives |
| Status chip wrappers | 12+ | Per-module `_*StatusChip` | Map enums → `AksharaStatusChip` helper |
| DataTable + mobile card fallback | 20+ | All ERP tables | `AksharaResponsiveTable` |

---

## Admin Shell Widgets (`lib/features/admin/`)

| Widget | Usage | Modules |
|--------|-------|---------|
| `AdminShell` | Router | All ERP |
| `AdminContentScaffold` | Module scaffolds | Admissions, Finance, SIS |
| `AdminAppBar` | Content scaffold | ERP desktop/tablet |
| `AdminFilterBar` | Module scaffolds | ERP screens with filters |
| `AdminNavRail` | Admin shell | ERP navigation |

---

## Widgets That Should Stay Module-Specific

| Widget | Module | Reason |
|--------|--------|--------|
| `AdmissionsChartPanel` | Admissions | Funnel/donut chart types |
| `FinanceCollectionTrendChart` | Finance | Bar trend visualization |
| `SisDistributionPanel` | SIS | Progress-bar distribution |
| `NoticeCarousel` | Parent | PA-01 carousel layout |
| `HeroCard` / `HeroGreetingCard` | Parent / Student | Role-specific hero |

---

## Usage Guidelines

1. **Always use** `AksharaKpiCard`, `AksharaStatusChip`, loading/empty/error states for new screens.
2. **Do not create** new KPI card or status chip variants — extend shared widgets.
3. **Prefer** `AksharaSectionHeader` over raw `Text` for section titles.
4. **New ERP modules** should reuse `ErpModuleScaffold` pattern (to be extracted) rather than copying Finance/Admissions scaffolds.

---

## Export Barrel

`lib/shared/widgets/widgets.dart` exports 12 public widgets. Not exported but used via direct import:

- `AksharaChildSelectorChip` (in `akshara_app_bar.dart`)
- `AksharaQuickActionGrid` / `AksharaQuickActionRow` (in `akshara_quick_action_card.dart`)

Consider expanding barrel exports in v0.6.
