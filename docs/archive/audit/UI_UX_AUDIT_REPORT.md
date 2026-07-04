# UI / UX AUDIT REPORT — Akshara ERP

> **Audit date:** 2026-06-18 · **Base commit:** `70194d6`
> **Lens:** "This ERP must feel simple." Audited Parent, Student, Teacher, Principal, Finance, SIS, Inventory, HR, Hostel, Library, Transport, Management, Director.
> **Headline:** The *consumer* apps (Parent/Teacher/Student) are genuinely simple and modern. The *admin* surfaces are where complexity hides — too many menu items, dead buttons, and a flat "see-everything" structure. The design system itself is excellent.

---

## Overall UX grade by persona

| Persona | Surface | Grade | One-line reason |
|---------|---------|:-----:|-----------------|
| Parent | dedicated app | **A−** | Clean 3-tab nav; but ~10 destinations crammed behind 3 tabs |
| Teacher | dedicated app | **A** | Best-in-repo; attendance flow is exemplary |
| Student | dedicated app | **A−** | Clean; minor breakpoint inconsistencies |
| Principal / Management | admin shell | **B** | Responsive, but 9-item nav + approval tables |
| Finance | admin shell | **B−** | Good tables→cards, but **14** sub-nav items |
| Inventory | admin shell | **B** | 10 sub-nav items; otherwise fine |
| HR / Transport / Hostel / Library / SIS | admin shell | **B** | Responsive; nav density the main issue |
| Control Center | admin shell | **C+** | **15** sub-nav items — densest in app |
| Director | admin shell | **C** | Weakest mobile adaptation; fixed-width cards |

---

## The good (don't lose this)

- **Material 3 design system is real and consistent** (`lib/theme/`, `lib/shared/widgets/widgets.dart` — ~36 components). Tokens for color/type/spacing/radius; `AksharaKpiCard`, `AksharaSectionHeader`, `AksharaQuickActionGrid`, standardized loading/empty/error states.
- **Consumer dashboards follow a clear pattern:** hero card → KPI row → quick actions → today/list → insights.
- **Admin tables degrade gracefully:** dense `DataTable`s fall back to card lists via `AdminLayout.isMobile(context)` across finance, transport, inventory, management, library.
- **Forms are componentized** (`lib/shared/forms/`): `AksharaFormField`, sticky `AksharaFormActions`, `AksharaUnsavedChangesGuard`, searchable dropdowns.

---

## Top UX problems (the simplicity killers)

### 1. "See everything" admin structure 🔴
The admin home is a **flat grid of up to 22 module cards** (`lib/features/admin/admin_navigation_provider.dart`). Even filtered by permission, broadly-granted roles see the entire ERP. This is the opposite of "see only your job." → Fixed by the workspace model (`WORKSPACE_ARCHITECTURE_AUDIT.md`).

### 2. Sub-navigation overload 🟠
Control Center **15**, Finance **14**, Inventory **10**, most admin modules **9** sub-nav items in a horizontally-scrolling tab strip. On a phone most items are off-screen with no scroll affordance (`lib/features/control_center/`, `lib/features/finance/`). Rule of thumb: **≤5 primary items**, the rest under "More".

### 3. Too many destinations behind too few tabs 🟠
Parent app has ~10 real destinations (academics, fees, PTM, transport, certificates, messages, notices, events, profile) but only **3 bottom-nav slots**; everything else is reached indirectly and many routes collapse to "Home" so the **selected tab is wrong** while you're deep in Messages/Transport (`lib/features/parent/shell/parent_shell.dart`). → Add a **"More" tab** and fix selected-state mapping.

### 4. Dead buttons 🟠
~28 screens have `onPressed: () {}` placeholders (export buttons in HR settings, library, hostel, etc. — per `RED_TEAM_OPERATIONAL_AUDIT.md`). A button that does nothing is worse than no button.

### 5. QA-only chrome shipped in app shells 🟠
`QaPersonaSwitcherBar()` renders at the top of **all three consumer shells** (`parent/teacher/student_shell.dart`). If it reaches production it wastes prime top space and confuses real users. Strip it from production builds.

### 6. Director portal not phone-adapted 🟡
Fixed `SizedBox(width: 320)` school cards in a `Wrap`, no `isMobile` branch → cramped/overflow on phones <360px (`lib/features/director/director_dashboard_screen.dart`).

### 7. Inconsistent breakpoints 🟡
At least three systems coexist: `AksharaBreakpoints` (768/1200), `MobileDashboardLayout` (768), and ad-hoc per-screen constants (360/428/480/640). Reflow happens at different widths on different screens. → One breakpoint source of truth.

### 8. Design-token drift 🟡
46 feature files still use raw `Theme.of(context).textTheme` instead of the standard `context.aksharaText` (used in 333 places). Causes subtle visual inconsistency.

### 9. Long single-column dashboards 🟡
Parent dashboard stacks ~9 full-width sections; notices/events sit far below the fold with no prioritization or collapse.

### 10. Placeholder/hardcoded labels 🟡
e.g. teacher attendance subtitle hardcoded `'Priya Sharma · Mathematics'` (`teacher_attendance_screen.dart:36`); fixed KPI card heights risk truncation with Indic fonts / large accessibility text.

---

## Duplicate / confusing actions

- **Two "promotion" screens** mean different things (grade promotion vs achievements) — see `SCREEN_CONSOLIDATION_REPORT.md` D2.
- **Timetable appears in 4 modules** with overlapping UX (D3).
- **Inventory has its own copilot screen** that duplicates the central copilot surface.
- **Filter patterns are inconsistent** — some screens use bottom-sheet filters (the documented standard), others inline filter bars (`notices_filter_bar.dart`, `homework_filter_bar.dart`).

---

## Role confusion (UX symptom of the architecture gap)

Because there's no workspace model and roles are over-granted, a **principal's menu currently includes Salon, Restaurant, Healthcare, and Accommodation** (`role_permissions.dart:279-379`). Users see modules that make no sense for their job — the clearest "this doesn't feel simple" signal in the product.

---

## Recommendations (priority-ordered)

| # | Fix | Effort | Impact |
|---|-----|--------|--------|
| 1 | Adopt workspace-scoped navigation (kills "see everything") | High | 🔴 Highest |
| 2 | Cap primary nav at ≤5 items; add "More"; fix selected-state | Med | 🟠 High |
| 3 | Strip vertical/SaaS modules from school roles & menus | Low | 🟠 High |
| 4 | Wire or hide the ~28 dead buttons | Low | 🟠 High |
| 5 | Remove QA persona switcher from prod builds | Low | 🟠 High |
| 6 | One breakpoint system; finish `context.aksharaText` migration | Med | 🟡 Med |
| 7 | Make Director portal phone-responsive | Low | 🟡 Med |
| 8 | Standardize filters (bottom-sheet) and timetable source | Med | 🟡 Med |

**Bottom line:** the *visual* layer is already modern and clean. "Feeling simple" is now blocked mostly by **structure** (see-everything menus, over-granted roles) and **polish debt** (dead buttons, QA chrome, nav density) — not by the design system. Fix structure first; it removes whole categories of UX complaints at once.

→ Mobile-specific deep dive: `MOBILE_FIRST_AUDIT.md`.
