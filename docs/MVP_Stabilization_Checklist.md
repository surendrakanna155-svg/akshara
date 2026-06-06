# Akshara ERP — MVP Stabilization Checklist

**Document ID:** `AKS-MVP-STAB-v1.0`  
**Scope:** Flutter parent app MVP — theme, routing, dashboard, attendance, fees  
**Codebase snapshot:** 36 Dart files under `lib/` · no `test/` · no `l10n/` · no `shared/widgets/`  
**Purpose:** Pre-release stabilization audit — checklist only (no code changes in this pass)

---

## Executive Summary

| Area | Maturity | Blocker? |
|------|----------|----------|
| Theme system | Strong foundation | No |
| Routing | Minimal viable | **Partial** — incomplete cross-screen navigation |
| Parent Dashboard | Feature-complete (mock) | No |
| Parent Attendance | Feature-complete (mock) | No |
| Parent Fees | Feature-complete (mock) | No |
| Shared layer | Missing | **Yes** — duplication risk |
| Tests / l10n / error UX | Not started | **Yes** for production MVP |

**Estimated stabilization effort:** ~80–120 h (P0: ~24 h · P1: ~40 h · P2: ~40 h)

---

## Inventory Analyzed

```
lib/
├── main.dart
├── app/app.dart
├── core/constants/app_constants.dart
├── core/providers/router_provider.dart
├── router/ (app_router, route_names, parent_navigation)
├── theme/ (7 files — full M3 token layer)
└── features/parent/
    ├── shell/parent_shell.dart
    ├── dashboard/ (screen + 5 widgets + provider)
    ├── attendance/ (screen + 5 widgets + provider + models)
    └── fees/ (screen + 6 widgets + provider)
```

**Figma alignment:** PA-01, PA-02, PA-03 implemented against mock providers.  
**Not in codebase:** `shared/widgets/`, auth, API layer, `l10n/`, tests, `theme/breakpoints.dart`, `white_label` provider.

---

## 1. Code Quality

| # | Item | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 1.1 | Consistent feature folder structure (screen + widgets + provider) | ✅ Done | — | Dashboard, attendance, fees follow same pattern |
| 1.2 | Theme tokens used instead of raw hex in features | ✅ Done | — | Features use `context.colors` / `context.akshara` |
| 1.3 | No `shared/` widget layer per `TechnicalArchitecture.md` | ❌ Gap | **P0** | All UI lives inside `features/` — cross-feature drift likely |
| 1.4 | Zero unit/widget tests | ❌ Gap | **P0** | No `test/` directory |
| 1.5 | `debugLogDiagnostics: true` in `app_router.dart` | ❌ Gap | **P1** | Should be flavor-gated (dev only) |
| 1.6 | Nested `Scaffold` (shell + each screen) | ⚠️ Review | **P1** | `ParentShell` + per-screen `Scaffold` — verify safe-area / FAB / drawer behavior |
| 1.7 | Private widget classes duplicated across screens | ❌ Gap | **P1** | See § Duplicate Widgets |
| 1.8 | Mock providers use `Provider` not `AsyncValue` pattern | ⚠️ Review | **P1** | Loading flags exist but are never toggled — misleading API shape |
| 1.9 | `analysis_options.yaml` present, no CI enforcement | ⚠️ Partial | **P2** | Add `flutter analyze` + `dart format` to CI |
| 1.10 | Documented architecture (`FlutterDesignSystem.md`) ahead of code | ⚠️ Drift | **P1** | Spec references `shared/widgets/`, `breakpoints.dart`, Riverpod theme providers not built |

---

## 2. Reusable Widgets Extraction

### Duplicate widgets identified

| Widget pattern | Locations | Extract to (proposed) | Priority |
|----------------|-----------|----------------------|----------|
| **Status chip** (container + label) | `hero_card._StatusChip`, `attendance_summary_card._StatusChip`, `installment_timeline._StatusChip` | `shared/widgets/chips/akshara_status_chip.dart` | **P0** |
| **Section header** (title + optional link) | `parent_dashboard_screen._SectionHeader` | `shared/widgets/layout/akshara_section_header.dart` | **P1** |
| **Parent app bar** (3 variants) | `_ParentDashboardAppBar`, `_AttendanceAppBar`, `_FeesAppBar` | `shared/widgets/navigation/parent_app_bar.dart` with `ParentAppBarVariant` | **P0** |
| **Child context chip** | `_ChildChip` (dashboard), attendance subtitle inline | `shared/widgets/parent/child_context_chip.dart` | **P1** |
| **KPI compact card** | `attendance_kpi_strip._AttendanceKpiCompactCard` | `shared/widgets/data/akshara_kpi_compact.dart` per design system | **P1** |
| **Warning banner** | `parent_attendance_screen._WarningBanner` | `shared/widgets/feedback/akshara_banner.dart` | **P1** |
| **Surface card** (border + radius 12) | Repeated in fees, attendance, dashboard widgets | `shared/widgets/cards/akshara_card.dart` | **P1** |
| **Loading overlay / skeleton** | 3× `CircularProgressIndicator` center | `shared/widgets/feedback/akshara_loading.dart` | **P1** |
| **Empty state** | Not implemented anywhere | `shared/widgets/feedback/akshara_empty_state.dart` | **P0** |
| **Currency formatter** | `fees_provider.formatInr` only | `core/utils/currency_utils.dart` | **P1** |
| **Tone → color resolver** | `DashboardChipTone`, `AttendanceDayStatus`, `FeeInstallmentStatus` each map colors separately | `theme/status_tone.dart` unified enum + resolver | **P1** |

### Extraction checklist

| # | Task | Priority |
|---|------|----------|
| 2.1 | Create `lib/shared/widgets/` per architecture doc | **P0** |
| 2.2 | Extract `AksharaStatusChip` (success/warning/error/primary/neutral) | **P0** |
| 2.3 | Extract `ParentAppBar` with props: title, subtitle, childChip, actions | **P0** |
| 2.4 | Extract `AksharaSectionHeader` | **P1** |
| 2.5 | Extract `AksharaKpiCompact` (used by attendance; future finance/admin) | **P1** |
| 2.6 | Extract `AksharaBanner` (warning/info/error variants) | **P1** |
| 2.7 | Extract `AksharaPageScaffold` (background + responsive scroll wrapper) | **P1** |
| 2.8 | Move `formatInr` to `core/utils/currency_utils.dart` | **P1** |
| 2.9 | Publish widget catalog in `shared/widgets/widgets.dart` barrel export | **P2** |

---

## 3. Navigation Consistency

| # | Item | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 3.1 | Default route → `/parent/dashboard` | ✅ Done | — | `initialLocation` + redirects |
| 3.2 | Shell bottom nav: Home · Academics · Fees | ✅ Done | — | Matches MVP subset of PA specs |
| 3.3 | Bottom nav missing **Messages** + **More** (PA-01 §3) | ❌ Gap | **P2** | Spec has 5 tabs; MVP uses 3 |
| 3.4 | Dashboard `onNavigate` wired via `handleParentDashboardNavigation` | ⚠️ Partial | **P0** | Only `pay_fee`, `fees`, `attendance`, `today_see_all` route; 10+ actions are no-ops |
| 3.5 | Attendance screen: `onAiTap` / `onNotificationsTap` are empty `() {}` | ❌ Gap | **P0** | Dead navigation hotspots |
| 3.6 | Fees screen: `onPayNow` not wired in `app_router.dart` | ❌ Gap | **P0** | Pay Now / receipt / PA-10 flow stubbed |
| 3.7 | Fees `onNotificationsTap` empty | ❌ Gap | **P1** | Same as attendance |
| 3.8 | Dashboard quick actions `contact_teacher`, `report_card` not routed | ❌ Gap | **P1** | PA-01 prototype links unimplemented |
| 3.9 | Notice / event taps use string ids (`notice_n1`) — no routes | ❌ Gap | **P1** | |
| 3.10 | No `go_router` named-route navigation (`context.goNamed`) | ⚠️ Partial | **P1** | Paths duplicated as strings across files |
| 3.11 | No auth / role / tenant guards (`route_guards.dart`) | ❌ Gap | **P2** | Expected per `TechnicalArchitecture.md` |
| 3.12 | `parent_navigation.dart` switch missing `break` style — uses Dart 3 switch (OK) but many cases silently `break` | ⚠️ Review | **P1** | Document unimplemented routes or show "Coming soon" snackbar |
| 3.13 | Double bottom bar risk: sticky Pay CTA + shell nav on fees | ✅ OK | — | Intentional per PA-03; verify safe-area on iOS |
| 3.14 | Scroll bottom padding inconsistent (fees: 88 for CTA; dashboard/attendance: 24) | ⚠️ Review | **P1** | Dashboard/attendance may need padding above bottom nav |

### Navigation wiring matrix (current)

| Source | Target spec | Wired? |
|--------|-------------|--------|
| Dashboard → Fees | PA-01 `pay_fee` | ✅ |
| Dashboard → Attendance | PA-01 `attendance` row | ✅ |
| Dashboard → Messages | PA-01 `contact_teacher` | ❌ |
| Dashboard → Notifications | PA-01 bell | ❌ |
| Attendance → Day sheet | PA-02 cell tap | ✅ (bottom sheet) |
| Fees → Pay Now | PA-03 → PA-10 | ❌ (callback exists, router silent) |
| Fees → Receipt | PA-03 → PA-11 | ❌ |
| Bottom nav 3 tabs | PA-01/02/03 | ✅ |

---

## 4. Accessibility

| # | Item | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 4.1 | `Semantics` on primary tappable widgets | ⚠️ Partial | **P1** | Good on dashboard chips, KPI, calendar cells, fee hero; not universal |
| 4.2 | Icon-only buttons have `tooltip` | ⚠️ Partial | **P1** | Dashboard + fees; verify all `IconButton`s |
| 4.3 | Status never color-only (icon + text) | ✅ Mostly | — | Chips include text labels per design system |
| 4.4 | Min touch target 48dp | ⚠️ Partial | **P1** | Most targets OK; some `TextButton`/`IconButton` use `shrinkWrap` |
| 4.5 | `Badge` accessibility (notification count) | ❌ Gap | **P1** | Badge label may not merge into screen reader announcement |
| 4.6 | Calendar cells announce status + day | ✅ Done | — | `attendance_calendar._CalendarDayCell` |
| 4.7 | Focus visible / keyboard navigation (web) | ❌ Gap | **P1** | No custom focus decoration beyond theme defaults |
| 4.8 | `MediaQuery.disableAnimations` respected | ❌ Gap | **P2** | Shimmer/skeleton not built yet |
| 4.9 | Chart/table fallback links (design system §19) | N/A | — | No charts in parent MVP screens |
| 4.10 | Contrast audit on warning/error containers | ⚠️ Review | **P1** | Run automated contrast check before release |

---

## 5. Responsive Behavior

| # | Item | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 5.1 | `AksharaBreakpoints` / `layoutBreakpointProvider` per design doc | ❌ Missing | **P0** | Duplicated inline constants instead |
| 5.2 | Tablet max content width 480px centered | ✅ Done | — | All 3 screens |
| 5.3 | Breakpoint 768 duplicated 3× | ❌ Gap | **P1** | `parent_dashboard_screen`, `parent_attendance_screen`, `parent_fees_screen` |
| 5.4 | Large mobile 428px (PA-02 day cell 52px) | ⚠️ Partial | **P1** | Only attendance implements `428`; dashboard/fees do not |
| 5.5 | Fees sticky CTA hidden on tablet | ✅ Done | — | Pay moves to hero inline button |
| 5.6 | Quick action grid 3-up → 2×2 tablet | ✅ Done | — | `QuickActionGrid` in dashboard |
| 5.7 | `AksharaResponsive` / `AksharaPagePadding` widgets | ❌ Missing | **P1** | Documented in `FlutterDesignSystem.md`, not implemented |
| 5.8 | Desktop/web admin layouts | N/A | **P2** | Parent MVP is mobile-first only |
| 5.9 | Bottom nav height from `AksharaThemeExtension` | ✅ Done | — | `context.akshara.bottomNavHeight` in shell |
| 5.10 | Text scaling / large font overflow | ❌ Untested | **P1** | Fixed heights (72, 88, 160) may clip with `textScaleFactor > 1.3` |

### Hardcoded layout values (extract to tokens)

| Value | Occurrences | Proposed token |
|-------|-------------|----------------|
| `768` (tablet breakpoint) | 3 screens + `QuickActionGrid` | `AksharaBreakpoints.tabletMin` |
| `480` (max content width) | 3 screens | `AksharaBreakpoints.parentMaxContentWidth` |
| `428` (large mobile) | 1 screen | `AksharaBreakpoints.largeMobileMin` |
| `88` (scroll bottom pad for CTA) | fees screen | `AksharaSpacing.stickyCtaClearance` |
| `160` / `72` / `88` / `320` (component heights) | fees, attendance | `AksharaComponentHeights.*` or per-widget const |

---

## 6. Error States

| # | Item | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 6.1 | GoRouter `errorBuilder` (404) | ⚠️ Minimal | **P1** | Plain text; not themed; no recovery CTA |
| 6.2 | API / network error UI | ❌ Missing | **P0** | No repository layer yet |
| 6.3 | Provider error state (`AsyncValue.error`) | ❌ Missing | **P0** | Mocks cannot demonstrate error UX |
| 6.4 | Retry affordance on failed loads | ❌ Missing | **P0** | Design system `AksharaErrorPage` not built |
| 6.5 | Payment failure state (PA-03 → PA-10 flow) | ❌ Missing | **P1** | `P-D-03 PaymentFailed` from Parent.md |
| 6.6 | Offline banner (`DesignSystem.md` §16) | ❌ Missing | **P1** | `connectivityProvider` not implemented |
| 6.7 | Form validation errors | N/A | — | No forms in MVP parent screens |

---

## 7. Empty States

| # | Item | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 7.1 | Dashboard: empty notices carousel | ❌ Missing | **P1** | `NoticeCarousel` returns `shrink` — no CTA |
| 7.2 | Dashboard: empty events list | ❌ Missing | **P1** | `EventCardList` returns `shrink` |
| 7.3 | Attendance: empty recent log | ❌ Missing | **P1** | Generic months return `recentLogs: []` with no UI |
| 7.4 | Fees: all-paid variant UI | ⚠️ Partial | **P1** | `ParentFeesData.allPaid()` exists; screen always uses `.mock()` |
| 7.5 | Fees: empty payment history sheet | ❌ Missing | **P2** | |
| 7.6 | Design system `AksharaEmptyState` component | ❌ Missing | **P0** | Illustration + title + description + CTA pattern |

---

## 8. Loading States

| # | Item | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 8.1 | `parentDashboardLoadingProvider` | ⚠️ Stub | **P1** | Never set `true` |
| 8.2 | `parentAttendanceLoadingProvider` | ⚠️ Stub | **P1** | Never set `true` |
| 8.3 | `parentFeesLoadingProvider` | ⚠️ Stub | **P1** | Never set `true` |
| 8.4 | Loading UI: center `CircularProgressIndicator` only | ⚠️ Minimal | **P1** | No skeleton/shimmer per PA specs |
| 8.5 | Skeleton placeholders for KPI, calendar, fee hero | ❌ Missing | **P1** | `DesignSystem.md` §16 `AksharaSkeleton` |
| 8.6 | Pull-to-refresh on parent screens | ❌ Missing | **P2** | Expected for rural connectivity narrative |
| 8.7 | Transition to `AsyncNotifier` when API lands | ❌ Planned | **P0** | Refactor providers before backend integration |

---

## 9. Localization Readiness

| # | Item | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 9.1 | `flutter gen-l10n` / ARB files | ❌ Missing | **P0** | No `l10n/` folder |
| 9.2 | All UI strings hardcoded English | ❌ Gap | **P0** | ~150+ user-visible strings across features |
| 9.3 | `MaterialApp` lacks `localizationsDelegates` | ❌ Gap | **P0** | `app.dart` has no l10n wiring |
| 9.4 | `intl` package for dates/currency | ❌ Gap | **P1** | Manual month names in `attendance_models.dart`; `formatInr` is custom |
| 9.5 | Regional fonts (Noto Telugu, etc.) | ❌ Gap | **P1** | `typography.dart` documents fonts; no assets in `pubspec.yaml` |
| 9.6 | RTL support (Urdu) | ❌ Gap | **P2** | Per SRS / architecture |
| 9.7 | Mock data strings in providers | ❌ Gap | **P1** | Move display strings to l10n; keep mock IDs in English |

### Hardcoded string hotspots (sample — not exhaustive)

| Category | Examples | Files |
|----------|----------|-------|
| Screen titles | `Fees`, `Attendance`, `School Notices` | All parent screens |
| Status labels | `Present`, `Absent`, `Paid`, `Overdue`, `Upcoming` | attendance, fees widgets |
| CTAs | `Pay Now`, `View payment history`, `See all` | fees, dashboard |
| Tooltips | `AI Copilot`, `Notifications`, `Payment history` | app bars |
| Mock content | `Ravi Kumar`, `Good morning`, fee terms | `*_provider.dart`, `*_models.dart` |
| Error/route | `Page not found` | `app_router.dart` |
| Bottom nav | `Home`, `Academics`, `Fees` | `parent_shell.dart` |

---

## 10. Performance

| # | Item | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 10.1 | `ListView` / `GridView` use `shrinkWrap` + `NeverScrollableScrollPhysics` | ⚠️ Review | **P1** | OK for small mock lists; revisit with real data |
| 10.2 | Notice carousel horizontal `ListView` | ✅ OK | — | Bounded item count (3) |
| 10.3 | Calendar grid builds all cells in `Column` | ✅ OK | — | Max ~42 cells |
| 10.4 | No `const` constructors maximized | ⚠️ Partial | **P2** | Run `dart fix --apply prefer_const_constructors` |
| 10.5 | Theme rebuilt every `AksharaApp` build | ⚠️ Review | **P1** | `AksharaAppTheme.light()` called inline — extract to provider |
| 10.6 | No image assets / network images yet | ✅ N/A | — | |
| 10.7 | Provider granularity (whole screen data) | ⚠️ Review | **P2** | Fine for MVP; split when API is large |
| 10.8 | Widget rebuild scope (`ConsumerWidget` at screen root) | ✅ OK | — | Acceptable for MVP |
| 10.9 | Golden tests for regression | ❌ Missing | **P1** | Per `FlutterDesignSystem.md` checklist |
| 10.10 | `debugLogDiagnostics` performance/log noise | ❌ Gap | **P1** | Disable in release builds |

---

## Theme System Review

| Component | File | Status | Notes |
|-----------|------|--------|-------|
| Color primitives + semantic tokens | `color_tokens.dart` | ✅ Complete | |
| `ColorScheme` mapping | `color_tokens.dart` | ✅ Complete | Light + dark placeholder |
| `AksharaThemeExtension` | `theme_extensions.dart` | ✅ Complete | success/warning/chart/nav |
| `AksharaTextStyles` | `typography.dart` | ✅ Complete | 12 M3 styles + mono |
| Spacing / radius / elevation | `spacing.dart`, `radius.dart`, `elevation.dart` | ✅ Complete | |
| `AksharaAppTheme` component themes | `app_theme.dart` | ✅ Complete | Buttons, inputs, nav, cards, dialogs |
| `KpiAccent` + context extensions | `theme_extensions.dart` | ✅ Complete | Used by attendance KPI |
| White-label override | `color_tokens.dart` | ⚠️ Unwired | `WhiteLabelThemeConfig` exists; `app.dart` does not use provider |
| `app_theme_provider` (Riverpod) | — | ❌ Missing | Theme instantiated inline in `app.dart` |
| `breakpoints.dart` | — | ❌ Missing | Documented in `FlutterDesignSystem.md` |
| Regional typography assets | — | ❌ Missing | Roboto only via system font |

---

## Routing Review

| Component | Status | Notes |
|-----------|--------|-------|
| `RouteNames` constants | ✅ | 4 parent paths |
| `goRouterProvider` | ✅ | Riverpod integration |
| `ShellRoute` + `ParentShell` | ✅ | Bottom nav |
| `NoTransitionPage` for tab switches | ✅ | Avoids flash between tabs |
| Dashboard navigation handler | ⚠️ | Partial action coverage |
| Fees/attendance router callbacks | ❌ | Not passed in `app_router.dart` |
| Deep links / notification routing | ❌ | Not implemented |
| Route error page | ⚠️ | Minimal |

---

## Feature Module Review

### Parent Dashboard (PA-01)

| Aspect | Status | Gaps |
|--------|--------|------|
| Layout vs Figma | ✅ Strong | — |
| Mock provider | ✅ | `parentDashboardProvider` |
| Widget decomposition | ✅ | 5 dedicated widgets |
| Navigation | ⚠️ | Fees + attendance only; 12 prototype links missing |
| Empty states | ❌ | |
| Tests | ❌ | |

### Parent Attendance (PA-02)

| Aspect | Status | Gaps |
|--------|--------|------|
| Layout vs Figma | ✅ Strong | Calendar, KPI, legend, banner, sheet |
| Mock provider | ✅ | Month navigation works |
| Hardcoded `today` | ❌ | `DateTime(2026, 6, 5)` in mock — not `DateTime.now()` |
| Navigation dead ends | ❌ | AI, notifications |
| Empty recent log (generic month) | ❌ | |

### Parent Fees (PA-03)

| Aspect | Status | Gaps |
|--------|--------|------|
| Layout vs Figma | ✅ Strong | Hero, progress, timeline, accordion, sticky CTA |
| Mock provider | ✅ | |
| `allPaid` variant | ⚠️ | Data factory exists; UI never consumes it |
| Payment flow | ❌ | `onPayNow` not connected |
| Router integration | ❌ | `ParentFeesScreen()` const, no callbacks |

---

## Refactoring Opportunities

| # | Opportunity | Benefit | Priority |
|---|-------------|---------|----------|
| R1 | Introduce `ParentScreenLayout` wrapper (responsive padding + max width + scroll) | Removes ~40 lines × 3 screens | **P0** |
| R2 | Unify tone enums: `DashboardChipTone`, `AttendanceDayStatus`, `FeeInstallmentStatus` → display layer | Single color/label mapper | **P1** |
| R3 | Convert mock `Provider` → `AsyncNotifierProvider` with simulated delay | Forces loading/error/empty UX | **P0** |
| R4 | Centralize parent mock child context (`childName`, `childClass`, `unreadNotifications`) | DRY — duplicated in 3 providers | **P1** |
| R5 | Wire `app_router.dart` to pass all screen callbacks | Single navigation composition root | **P0** |
| R6 | Add `parent_routes.dart` extension on `BuildContext` (`goParentFees()`, etc.) | Type-safe navigation | **P1** |
| R7 | Extract bottom sheet pattern (`_DayDetailSheet`, `PaymentHistorySheet`) | Reusable `AksharaBottomSheet` | **P1** |
| R8 | Theme via `appThemeProvider` + optional `whiteLabelConfigProvider` | Matches architecture doc | **P1** |
| R9 | Split `attendance_models.dart` mock builders from domain models | Cleaner data layer boundary | **P2** |
| R10 | Add `analysis_options` stricter rules (`prefer_single_quotes`, `always_declare_return_types`) | Consistency | **P2** |

---

## Prioritized Action Plan

### P0 — Must fix before MVP demo / backend integration

| ID | Action | Area |
|----|--------|------|
| P0-01 | Create `shared/widgets/` and extract `AksharaStatusChip`, `ParentAppBar`, `AksharaEmptyState` | Widgets |
| P0-02 | Wire `app_router.dart` callbacks for fees (`onPayNow`, `onViewReceipt`) and attendance notifications | Navigation |
| P0-03 | Complete dashboard `handleParentDashboardNavigation` or show user feedback for unimplemented routes | Navigation |
| P0-04 | Refactor providers to `AsyncValue` with loading + error + empty branches | State |
| P0-05 | Add `l10n/` scaffold + extract all user-visible strings | Localization |
| P0-06 | Add `theme/breakpoints.dart` + `AksharaPageLayout` — remove duplicated 768/480 | Responsive |
| P0-07 | Add widget tests for theme tokens + smoke tests for 3 parent screens | Quality |
| P0-08 | Implement API error state UI (even if mocked with toggle) | Error |

### P1 — Should fix before beta / pilot schools

| ID | Action | Area |
|----|--------|------|
| P1-01 | Extract `AksharaBanner`, `AksharaKpiCompact`, `AksharaSectionHeader`, `AksharaCard` | Widgets |
| P1-02 | Add skeleton loading states for dashboard, attendance, fees | Loading |
| P1-03 | Implement empty states for notices, events, recent logs, payment history | Empty |
| P1-04 | Themed 404 / error page with "Go Home" CTA | Error |
| P1-05 | Fix scroll bottom padding for bottom nav on dashboard + attendance | Layout |
| P1-06 | Wire `onAiTap` / `onNotificationsTap` to route stubs or placeholder screens | Navigation |
| P1-07 | `formatInr` + date formatting via `intl` | Localization |
| P1-08 | Disable `debugLogDiagnostics` in release; gate via flavor | Quality |
| P1-09 | `appThemeProvider` in Riverpod; optional white-label provider | Theme |
| P1-10 | Accessibility pass: badge labels, focus rings, large text overflow | A11y |
| P1-11 | Golden tests for PA-01, PA-02, PA-03 key frames | Quality |
| P1-12 | Fees `allPaid` UI variant toggle for QA | Fees |
| P1-13 | Centralize parent child context in shared session provider | State |

### P2 — Post-MVP / polish

| ID | Action | Area |
|----|--------|------|
| P2-01 | Add Messages + More bottom nav tabs + routes | Navigation |
| P2-02 | Auth guards + tenant context in router | Routing |
| P2-03 | Pull-to-refresh on parent screens | UX |
| P2-04 | Offline connectivity banner | Error |
| P2-05 | Regional Noto font assets + locale-driven `TextStyle` | Localization |
| P2-06 | RTL layout verification (Urdu) | Localization |
| P2-07 | Tablet attendance sidebar layout (PA-02 §9) | Responsive |
| P2-08 | `const` constructor sweep + CI format/analyze | Quality |
| P2-09 | Deep link + FCM notification routing | Navigation |
| P2-10 | Dark theme QA (theme exists but `themeMode: light` only) | Theme |

---

## Sign-off Checklist (MVP Ready)

Use this section for release gate review:

- [ ] **P0 items complete** (14/14)
- [ ] All 3 parent screens navigable end-to-end without dead taps on primary CTAs
- [ ] `flutter analyze` clean
- [ ] Widget smoke tests pass
- [ ] Strings externalized to ARB (English baseline)
- [ ] Error + empty + loading states demonstrated per screen
- [ ] Accessibility spot-check on iOS VoiceOver + Android TalkBack
- [ ] Responsive check: 390, 428, 768, 834 widths
- [ ] Figma parity sign-off: PA-01, PA-02, PA-03

---

## Related Documents

| Document | Relevance |
|----------|-----------|
| `docs/FlutterDesignSystem.md` | Target architecture (ahead of code) |
| `docs/figma-screens/PA-01-*.md` | Dashboard acceptance criteria |
| `docs/figma-screens/PA-02-*.md` | Attendance acceptance criteria |
| `docs/figma-screens/PA-03-*.md` | Fees acceptance criteria |
| `docs/TechnicalArchitecture.md` | Folder structure, routing, l10n targets |
| `docs/FigmaImplementationRoadmap.md` | Remaining screens not yet built |

---

**End of MVP Stabilization Checklist v1.0**
