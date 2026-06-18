# MOBILE-FIRST AUDIT — Akshara ERP

> **Audit date:** 2026-06-18 · **Base commit:** `70194d6`
> **Standard:** A teacher, parent, or principal should complete their most common task in **≤3 taps, one-handed, on a mid-range Android phone**.
> **Headline:** Mobile-first quality is **above average for an ERP**. The consumer apps are purpose-built for phones; the admin shell is responsive. The remaining work is polish (nav density, breakpoints, one weak portal), not a rebuild.

---

## Verdict by persona

| Persona | Mobile quality | Notes |
|---------|:--------------:|-------|
| Teacher | ✅ **Excellent** | Attendance flow is the gold standard |
| Parent | ✅ Good | 3-tab app; "More" gap |
| Student | ✅ Good | minor breakpoint nits |
| Finance / HR / Transport / Inventory / Management | ✅ Good | tables → cards on mobile |
| Control Center | ⚠️ Needs work | nav density (15 items) |
| Director | ⚠️ Needs work | weakest adaptation |

---

## What's genuinely mobile-first (keep)

1. **Dedicated consumer app shells** with bottom `NavigationBar`:
   - Parent: 3 items (Home · Academics · Fees) + center AI slot — `lib/features/parent/shell/parent_shell.dart`
   - Teacher: 4 items (Home · Classes · Teach · Messages) — `lib/features/teacher/shell/teacher_shell.dart`
   - Student: 4 items (Home · Learn · Schedule · Results) — `lib/features/student/shell/student_shell.dart`
2. **The teacher attendance flow is exemplary** (`lib/features/teacher/attendance/teacher_attendance_screen.dart`): class selector strip, present/absent/late KPI row, **bulk "all present / all absent"**, per-student rows, draft save, **sticky bottom submit bar** gated on "$n unmarked." This is exactly the standard the rest of the app should meet.
3. **Responsive admin shell:** drawer (mobile) → collapsed rail (tablet) → expanded rail (desktop). Dense `DataTable`s fall back to card lists via `AdminLayout.isMobile(context)` — verified in finance, transport, inventory, management, library.
4. **Mobile-aware design tokens:** `minTouchTarget = 48`, `bottomNavHeight = 80`, 8pt spacing scale, tablet split-body variants on teacher/student dashboards.

---

## Mobile problems (priority-ordered)

### 1. Bottom-nav selected-state is wrong for deep routes 🟠
In all three consumer shells, many destinations (Messages, Transport, PTM, Profile) collapse to index 0, so the bar highlights **Home** while you're elsewhere (`parent_shell.dart` `_selectedIndex`). Breaks orientation — the user can't tell where they are.

### 2. Too few tabs for too many destinations → hidden depth 🟠
Parent has ~10 destinations behind 3 tabs. Everything beyond Home/Academics/Fees is reached indirectly. → Add a **"More"** tab (the standard mobile pattern) and map selected-state correctly.

### 3. Admin sub-nav overflows the screen 🟠
Control Center 15, Finance 14, Inventory 10 items in a horizontal tab strip; on a phone most are off-screen with no scroll cue. → Workspace-scoped nav + ≤5 visible items + overflow menu.

### 4. The center AI slot crowds thumb reach 🟡
`CopilotBottomNavAiSlot` overlaps the `NavigationBar` via a `Stack(clipBehavior: Clip.none)`; the floating notch can crowd edge labels and thumb targets on small devices.

### 5. Director portal not phone-guarded 🟡
Fixed-width (320px) school cards in a `Wrap`, no `isMobile` branch → overflow on phones <360px (`director_dashboard_screen.dart`). Sub-screens (revenue/schools/compliance) use `DataTable` — verify card fallback.

### 6. Three competing breakpoint systems 🟡
`AksharaBreakpoints` (768/1200) vs `MobileDashboardLayout` (768) vs ad-hoc constants (360/428/480/640). Screens reflow at different widths. → One source of truth in `lib/theme/breakpoints.dart`.

### 7. Fixed card heights risk truncation 🟡
KPI cards with hardcoded heights (112/88) + Indic fonts (Noto scripts are taller) + large accessibility text scaling → clipped text. Already using `truncateStressLabel`, which signals known pressure.

### 8. Some tablet-portrait tables still scroll horizontally 🟡
e.g. `library_catalog_screen.dart` wraps a `DataTable` in a horizontal scroll for non-mobile widths; ensure the card path covers tablet-portrait too.

### 9. Heavy hand-built forms 🟡
The admissions enrollment form (`admissions/enrollment/widgets/admissions_enrollment_form_steps.dart`, 441 lines, 10 fields multi-step) is hand-assembled rather than using a shared wizard component → keyboard-overlap and consistency risk on phones. → Build one shared multi-step wizard widget.

### 10. Inconsistent filter UX 🟡
Bottom-sheet filters (the documented mobile standard) vs inline filter bars on some lists. Standardize on bottom-sheet for phones.

---

## Thumb-reachability & one-handed use

- ✅ Primary actions are correctly **bottom-anchored** (bottom nav, sticky submit bars).
- ✅ 48px min touch targets enforced via tokens.
- ⚠️ Top-anchored child-selector / persona-switcher chips require a reach to the top-left on tall phones.
- ⚠️ Horizontal sub-nav strips on admin screens require precise taps on small off-screen tabs.

---

## Workflow walk-throughs (the tests that matter)

| Workflow | Taps today | Mobile verdict |
|----------|:----------:|----------------|
| Teacher marks attendance | 2–3 | ✅ Excellent (bulk + sticky submit) |
| Parent checks fees due | 2 | ✅ Good |
| Parent views child's attendance | 2–3 | ✅ Good |
| Student checks homework due | 1–2 | ✅ Good |
| Principal clears approval inbox | 2–3 | ✅ Good (cards on mobile) |
| Finance records a payment | 3–4 | 🟡 OK; nav density adds friction |
| Admissions enrolls a student | many | 🟡 Heavy multi-step form |

---

## Recommendations

| # | Fix | Effort | Impact |
|---|-----|--------|--------|
| 1 | Fix bottom-nav selected-state mapping | Low | 🟠 High |
| 2 | Add "More" tab to consumer apps | Low–Med | 🟠 High |
| 3 | Workspace nav + ≤5 items + overflow menu (admin) | High | 🟠 High |
| 4 | One breakpoint system | Med | 🟡 Med |
| 5 | Make Director portal responsive | Low | 🟡 Med |
| 6 | Shared multi-step wizard widget | Med | 🟡 Med |
| 7 | Standardize bottom-sheet filters | Med | 🟡 Med |
| 8 | Remove QA persona switcher from prod | Low | 🟠 High |

**Bottom line:** Mobile-first is a **strength, not a liability**. The consumer apps already feel like real mobile apps; the teacher attendance flow proves the team can hit a very high bar. Spread that bar to the admin shell (via workspaces + nav discipline) and fix the handful of polish items above, and Akshara will be genuinely more pleasant on a phone than any incumbent school ERP.
