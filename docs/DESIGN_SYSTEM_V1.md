# Akshara Design System V1

**Program:** Release Candidate — Design System Consolidation  
**Branch:** `release/v1.0-preprod`  
**Date:** June 2026  
**Code source of truth:** `lib/theme/`, `lib/shared/widgets/`  
**Extended spec:** `docs/DesignSystem.md`, `docs/FlutterDesignSystem.md`

---

## Purpose

One consistent visual language across ERP admin, director portal, intelligence hub, and mobile apps (parent, teacher, student). V1 codifies **implemented** tokens and shared components — not a redesign.

---

## Typography

| Token | Role | Implementation |
|-------|------|----------------|
| `headlineMedium` | Page titles | `AksharaTextStyles.headlineMedium` |
| `headlineSmall` | Section heroes, health scores | `AksharaTextStyles.headlineSmall` |
| `titleLarge` | KPI values (comfortable) | `AksharaTextStyles.titleLarge` |
| `titleMedium` | Card titles, subsections | `AksharaTextStyles.titleMedium` |
| `titleSmall` | Compact KPI values | `AksharaTextStyles.titleSmall` |
| `bodyLarge` / `bodyMedium` / `bodySmall` | Body copy | `AksharaTextStyles` |
| `labelLarge` / `labelMedium` / `labelSmall` | Labels, chips | `AksharaTextStyles` |
| `monoBody` | IDs, receipts | `RobotoMono` |

**Rules:** Use `context.aksharaText` — never raw `Theme.of(context).textTheme` on product screens. Regional fonts via `AksharaTextStyles.withFontFamily`.

---

## Spacing scale (`AksharaSpacing`)

| Token | Value | Use |
|-------|------:|-----|
| `s1` | 4 | Tight inline gaps |
| `s2` | 8 | Icon–text, chip padding |
| `s3` | 12 | Card inner compact |
| `s4` | 16 | Standard card padding, section gap |
| `s6` | 24 | Major section separation |
| `mobileMargin` / `tabletMargin` / `desktopMargin` | 16 / 24 / 32 | Screen gutters |

**Rules:** No magic numbers except chart heights. Section rhythm: `s4` related blocks, `s6` major sections.

---

## Elevation (`AksharaElevation`)

| Level | Material elevation | Use |
|-------|-------------------|-----|
| 0 | 0 | Flat surfaces, lists |
| 1 | 1 | KPI cards on tap, subtle tiles |
| 2 | 2 | Director portfolio cards |
| 3 | 3 | Dialogs |
| 4 | 4 | Modals, drawers |

Use `AksharaElevation.boxShadow(context, level)` or `materialElevation(level)`.

---

## Colors

**Primitives:** `AksharaColorPrimitives` (blue, neutral, semantic, chart)  
**Semantic:** `AksharaColorTokens` → `ColorScheme` + `AksharaThemeExtension`

| Semantic | Use |
|----------|-----|
| `primary` / `primaryContainer` | Brand, KPI accent |
| `success` / `warning` / `error` + containers | Status, alerts |
| `chart1`–`chart4`, `chartGrid` | Analytics |
| `surfaceContainerLow` | Page background, KPI tile fill |
| `outlineVariant` | Card borders |

**KPI accents:** `KpiAccent` enum (`primary`, `success`, `warning`, `error`, `neutral`) → `accent.resolve(context)`.

---

## Radius (`AksharaRadius`)

| Token | Use |
|-------|-----|
| `card` | Cards, KPI tiles, insight cards |
| `chip` | Status chips, icon boxes |
| `dialog` | Modals |

---

## KPI cards (`AksharaKpiCard`)

| Style | Surface | Height guidance |
|-------|---------|-----------------|
| `strip` | Bordered, icon box | 88px fixed |
| `filled` | Accent container | Comfortable ≥120px; compact &lt;120px auto |
| `status` | Teacher/student status | Configurable `height` |
| `count` | Homework counts | Configurable `height` |

**Hierarchy:** Value → label → trend/detail. Chevron only when `onTap` and comfortable layout.

**Shared rows:** `ManagementKpiRow` (132px), `FinanceKpiRow`, `DirectorKpiRow` (132px).

---

## Charts

- Colors: `context.colors.chart1`–`chart4`, `chartGrid`
- Section headers: `AksharaSectionHeader`
- Intelligence hub KPIs: bordered tiles, label above value

---

## Tables

- ERP: `AksharaDataTable` patterns in finance/SIS modules
- Mobile: card lists instead of tables &lt;768px
- Pagination: `PaginatedResult` + virtualized lists

---

## Dialogs & forms

- `AksharaFormField` family in `lib/shared/forms/`
- Wizards: step indicator + **sticky action bar** (enrollment pattern)
- `AksharaUnsavedChangesGuard` on multi-step flows
- `scrollToFirstFormError` on validation failure

---

## AI components

| Component | Use |
|-----------|-----|
| `AksharaInsightCard` | Single CTA recommendations |
| `CopilotFloatingDock` | Overlay bubble |
| `CopilotBottomNavAiSlot` | Mobile center nav |
| `AiAssistantSettingsScreen` | Per-device access mode |

Access modes: `floating`, `bottomNavCenter`, `sidebar`, `appBar` — `ai_access_preferences_provider.dart`.

---

## Breakpoints (`AksharaBreakpoints`)

| Breakpoint | Width | KPI columns |
|------------|-------|-------------|
| Mobile | &lt;768 | 2 |
| Tablet | 768–1024 | 3 |
| Desktop | &gt;1024 | 3–4 |

---

## Component inventory (shared)

See `docs/SharedWidgetInventory.md`. V1 mandates these on all new screens:

- `AksharaSectionHeader`, `AksharaSectionEmpty`, `AksharaSectionError`
- `AksharaLoadingState`, `AksharaErrorState`, `AksharaEmptyState`
- `AksharaSurfaceCard`, `AksharaWarningBanner`
- `AksharaQuickActionGrid` / `AksharaQuickActionCard`
- `AksharaStatusChip`, `AksharaSurfaceListTile`

---

## Compliance checklist (RC)

- [x] Typography via `AksharaTextStyles`
- [x] Spacing via `AksharaSpacing` only
- [x] KPI hierarchy unified (`AksharaKpiCard` + rows)
- [x] Intelligence hub tiles aligned with ERP KPI pattern
- [x] Mobile hero cards use `surfaceContainerLowest` + border
- [x] Director executive summary uses primary tint + border

---

## References

- `lib/theme/typography.dart`, `spacing.dart`, `elevation.dart`, `color_tokens.dart`, `radius.dart`
- `lib/shared/widgets/akshara_kpi_card.dart`
- `docs/AKSHARA_UX_MODERNIZATION_PLAN.md`
