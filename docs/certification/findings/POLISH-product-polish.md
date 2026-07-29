# WS9 — Product Polish Certification

**Workstream 9** · branch `release/v1.0-playstore` · READ-ONLY audit, nothing fixed.
Companion register entries use the prefix `POLISH-`.

## The question this workstream answers

> **Would a principal paying for this believe it is finished?**

Not "does it work" — Workstreams 2–8 answer that. This one asks whether the
product *reads* as a finished commercial article: whether the spacing, type,
states, motion and affordances hold together, and whether anything on screen is
visibly scaffolding.

The judgement standard follows WS6's discovery that 9 of 10 module dashboards
ship filter chips the data fetch never reads. **A control that responds visually
but changes no outcome is the single clearest signal a product is unfinished**,
and it is treated here as polish-critical rather than cosmetic — a principal who
taps a chip, sees it highlight, and sees the numbers not move has learned
something about the whole product, not just that chip.

## Method

1. Verify the five polish fixes the RC phase claims (contrast, 48dp tap targets,
   text-scale clipping, day-one empty states, Admin Hub dead gutter) still hold
   *and* were not applied to one file while the class of bug survived elsewhere.
2. Sweep production screens for loading / empty / error state quality.
3. Sweep for "looks functional, does nothing" affordances **outside** the ten
   dashboards WS6 already registered.
4. Sweep for design-system bypass: spacing, typography, colour, radius,
   responsiveness, dark mode, motion.

Evidence is `file:line` in every case. Test files, `qa_*`, and dev-only surfaces
are excluded unless they leak into a release build.

---

## Section A — Verified on the release path by direct trace

These were traced by hand rather than delegated, because each turns on what a
release build actually resolves.

### A1. No staff persona can log out of NIKSHA OS

This is the most serious polish finding in the workstream, and it is not
cosmetic.

The Admin shell's app-bar profile affordance is defined once, at
`lib/features/admin/admin_content_scaffold.dart:88-111`, and it branches:

```dart
onProfileTap: onProfileTap ??
    () {
      if (ref.read(isQaLoginEnabledProvider)) {
        showModalBottomSheet(... ListTile(title: Text('Log out') ...));
        return;
      }
      _showPlaceholderSnackBar(context, 'Profile menu coming soon.');
    },
```

`isQaLoginEnabledProvider` reads `Environment.enableQaLogin`
(`lib/core/config/environment_provider.dart:21-23`), and `guardForRelease`
forces it to `false` in a release build
(`lib/core/config/environment.dart:161`). **So the log-out branch is dev-only.
In the shipping build every staff user who taps their avatar gets a snackbar
reading "Profile menu coming soon."**

The method that renders it is literally named `_showPlaceholderSnackBar`
(`admin_content_scaffold.dart:57`).

Tracing every log-out affordance in `lib/` confirms there is no alternative
route. `confirmAndLogout` (`lib/features/auth/auth_logout.dart:11`) has exactly
three call sites:

| Call site | Reachable in release? |
|---|---|
| `lib/features/admin/admin_content_scaffold.dart:100` | **No** — inside the `isQaLoginEnabledProvider` branch |
| `lib/features/parent/profile/parent_profile_screen.dart:246` | Yes — parents only |
| — | — |

The only other session-clearing paths are
`lib/app/app.dart:152` (fires only from the biometric App Lock overlay's
recovery button, which requires App Lock to be enabled *and* engaged) and
`lib/features/legal/legal_acceptance_screen.dart:64` (declining the legal gate).

Checked and found to contain no log-out:
`lib/features/teacher/profile/teacher_profile_screen.dart` (its "Account"
section at :157 offers only Settings :166 and Legal :173),
`lib/features/teacher/settings/teacher_settings_screen.dart`,
`lib/features/student_app/profile/student_profile_screen.dart`,
`lib/features/sis/profile/sis_profile_screen.dart` (the `Icons.logout_outlined`
at :137 is the **Transfer Certificate** button, not a log-out).

**What this means in a real school.** Indian schools run shared devices — the
front-office tablet, the staff-room device, the principal's phone handed to the
vice-principal. A teacher who finishes marking attendance cannot end their
session; the next person to pick up the device inherits authenticated access to
student PII, fee collection, and marks entry. A staff member who leaves the
school keeps a live session until the token expires. And a principal evaluating
the product will tap their own avatar within the first minute and be told the
profile menu is coming soon.

### A2. The admin notification bell opens the parent inbox, and its badge is永 zero

`lib/features/admin/admin_content_scaffold.dart:83-84`:

```dart
onNotificationsTap: onNotificationsTap ??
    () => context.push(RouteNames.parentNotifications),
```

Nothing in the admin shell overrides it. `RouteNames.parentNotifications` is
`/parent/notifications` (`lib/router/route_names.dart:36`,
`lib/router/app_router.dart:284-288`). The screen itself is role-neutral — the
router comment at `app_router.dart:290-292` records that the *teacher* bell was
already moved off the parent path for exactly this reason (F-128, giving
`/teacher/notifications` at `app_router.dart:292-296`) — but the admin shell was
not given the same treatment. A principal who taps the bell and glances at the
URL-shaped breadcrumb is in the parent persona's route.

Separately, the badge is dead. `unreadNotifications` exists on
`AdminAppBar` (`lib/features/admin/admin_app_bar.dart:19,29,101-102`) and is
piped through `AdminContentScaffold` (`:31,48,81`) with a default of `0` — and
**none of the 20 `AdminContentScaffold(` call sites in `lib/` passes it.** The
student shell wires the equivalent correctly
(`lib/features/student_app/dashboard/student_dashboard_screen.dart:57`,
`student_app/notices/student_notices_screen.dart:44`), which is what makes the
admin omission legible as an oversight rather than a decision. Every staff role
sees a bell that can never indicate anything.

### A3. Placeholder copy shipped on reachable release surfaces

Four "coming soon" strings survive on routes a release build can open. The
codebase is otherwise remarkably disciplined — a full sweep of `lib/` returns
only **two** `TODO`/`FIXME` comments
(`lib/features/academics/exam_admin/exam_marks_entry_screen.dart:648`,
`lib/features/support/report_issue_screen.dart:24`), both properly ticketed —
which is precisely why the placeholder copy stands out as the exception:

| Surface | Copy | File:line |
|---|---|---|
| Admin shell, every staff role | "Profile menu coming soon." | `lib/features/admin/admin_content_scaffold.dart:109` |
| Student profile → App settings | "Notifications, language, and privacy — coming soon" | `lib/features/student_app/profile/student_profile_screen.dart:192` (Semantics label at :174) |
| Support → Report an issue | "Add screen recording (coming soon)" | `lib/features/support/report_issue_screen.dart:477` |
| Legal acceptance gate | "'<policy>' will be available online soon." | `lib/features/legal/legal_acceptance_screen.dart:45` |

The student one is handled honestly — the row is non-tappable and the Semantics
label announces "coming soon" to a screen reader, which is the correct way to
ship an unfinished affordance. The support one is a genuine, scoped Phase-2
marker. The admin one is neither: it is the *only* thing behind that control.
The legal one is the more delicate case — it appears on the mandatory
policy-acceptance gate, where a user is being asked to accept a document the app
then declines to show them.

### A4. The shell's default filter bar is a hard-coded triple

`lib/features/admin/admin_content_scaffold.dart:113-119`:

```dart
if (showFilterBar)
  AdminFilterBar(
    filters: filters ?? const ['All', 'This period', 'Active'],
    ...
```

This is the *source* of the pattern WS6 registered as WIDGET-009 (hard-coded
filter chip labels unrelated to the tenant). Any screen that turns on
`showFilterBar` without supplying `filters` inherits three chips — "All", "This
period", "Active" — that are not derived from anything in the school. Recorded
here as the upstream cause so the WIDGET-008/009/010 remediation is aimed at the
shell default and not only at the ten dashboards downstream of it.

---

## Section B — Loading, empty and error states

**Baseline: 310 screen/page files.** The honest headline first, because it
changes how the rest of this section should be read: **the state system here is
good.** `ErpAsyncBody` (`lib/shared/async/erp_async_state.dart:77`) is used by
**97** screens and *requires* both `onRetry` and `emptyMessage` at the type
level, so a screen that adopts it cannot ship without a retry and an empty
message. `AksharaErrorState.fromFailure` already models permission, offline and
session-expiry as distinct states with their own tone and copy. Zero `.when()`
calls anywhere in `lib/features/` are missing an `error:` branch, and there is
exactly one `FutureBuilder` in the entire feature tree.

**So the defects below are not "the team didn't think about states". They are
outliers that escaped a working system** — concentrated in platform,
intelligence and the non-school verticals — plus two gaps that are systemic
because they live in shared code.

### B1. Pull-to-refresh: 1 of 78 admin list screens (P1)

This is the sharpest "half-finished" tell in the product.

There are **19 `RefreshIndicator`s in the entire app. 18 of them are in the
parent, student, teacher, notifications and support surfaces** — the
mobile-facing half. Of the **78 admin list screens** (finance, SIS, HR,
admissions, academics, transport, hostel, library, inventory, alumni, director,
management, complaints, gate pass, certificate desk, clearance), **exactly one**
has pull-to-refresh:
`lib/features/management/school_calendar/school_calendar_screen.dart:79`.

There is no alternative affordance either. Only two admin screens carry an
`Icons.refresh` action (`school_calendar_screen.dart:55`,
`lib/features/intelligence/student_success/student_success_screen.dart:167`),
and `lib/shared/widgets/akshara_app_bar.dart` has no built-in refresh.

**What the principal experiences:** they are on Finance → Collections while the
accountant posts a receipt at the counter. They pull down. Nothing happens.
There is no refresh button. The only way to see the new receipt is to navigate
away and come back. They will do this on defaulters, admissions leads, hostel
rooms, library circulation, inventory, gate pass and the certificate desk too.

What makes this a polish defect rather than a feature request: **every one of
those screens already passes `onRetry` to `ErpAsyncBody`.** The invalidate
callback exists on all 78. It is simply not attached to a gesture. The gap is
one wrapper, not a data-layer change — which is also why its absence reads as
unfinished rather than as a decision.

### B2. Permission-denied is a bare sentence on a blank white screen — 17 screens (P1)

`AksharaErrorState.fromFailure` already models `AksharaFailureKind.permission`
with its own icon, tone and copy. **None of these 17 screens use it.** Each
renders a centred sentence on an otherwise empty `Scaffold` — no icon, no "ask
your administrator", no back action, no branding:

`lib/features/platform/platform_operations/platform_operations_hub_screen.dart:56` ·
`lib/features/platform/white_label/white_label_hub_screen.dart:18` ·
`lib/features/platform/branch/branch_screen.dart:19` ·
`lib/features/platform/franchise/franchise_screen.dart:19` ·
`lib/features/platform/control_center/intelligence/platform_intelligence_screen.dart:46` ·
`lib/features/intelligence/student_success/student_success_screen.dart:53` ·
`lib/features/intelligence/exam/exam_intelligence_screen.dart:59` ·
`lib/features/intelligence/intelligence_screen.dart:228,297,367` ·
`lib/features/intelligence/trust/trust_intelligence_hub_screen.dart:51` ·
`lib/features/industry/industry_hub_screen.dart:24` ·
`lib/features/verticals/{restaurant,salon,healthcare,accommodation}/*_dashboard_screen.dart:19`.

**This is the state a principal is most likely to hit while exploring**, because
exploring means opening things you are not entitled to. And a blank white screen
with one grey sentence is indistinguishable from a crash. The product has a
purpose-built widget for exactly this and 17 screens route around it.

### B3. Platform Operations hub dumps 22 raw exceptions (P1)

`lib/features/platform/platform_operations/platform_operations_hub_screen.dart`
renders the raw exception string in **22 places** — lines
`212, 231, 250, 279, 298, 330, 354, 372, 472, 483, 502, 562, 582, 601, 619, 638,
667, 686, 736, 762`, plus `:143` (`subtitle: Text('Unavailable: $error')`).
No retry on any of them, no styling.

The user sees `App health error: DioException [connection error]: ...` inline in
a card. The RC phase closed exactly this defect class on the day-one import
screen ("Raw `DioException` text incl. internal endpoint URLs",
`docs/roadmap/RC_EXECUTION_LOG.md:71`) — this screen has 22 instances of it and
was not swept.

### B4. Errors swallowed into blank space — no signal at all (P2)

Worse than an ugly error is no error. These screens catch a failure and render
nothing, so the user cannot distinguish "failed" from "empty":
`lib/features/finance/defaulters/finance_defaulters_screen.dart:225` ·
`lib/features/finance/intelligence/finance_copilot_screen.dart:63` ·
`lib/features/communication/broadcast_admin_screen.dart:490,515` ·
`lib/features/inventory/intelligence/inventory_lifecycle_screen.dart:64` ·
`lib/features/employee/employee_360_screen.dart:71` ·
`lib/features/intelligence/management/intelligence_hub_screen.dart:433,526,543` ·
`lib/features/evolution/teacher_assistant_screen.dart:68` ·
`lib/features/parent/academics/parent_academic_report_screen.dart:41` ·
`lib/features/copilot/copilot_screen.dart:170` ·
`lib/features/education/education_bank_item_form.dart:137`.

The **defaulters** one deserves separate emphasis: a fee-defaulters list that
silently renders empty on failure tells a principal that nobody owes money.

A further **17 screens are SnackBar-only** — the error toasts away after four
seconds, the page stays blank, and there is no retry:
`lib/features/admin/backup/backup_restore_screen.dart`,
`lib/features/school_config/school_discovery_screen.dart`,
`lib/features/platform/multi_school/school_onboarding_wizard_screen.dart`,
`lib/features/teacher/leave_approvals/teacher_leave_approvals_screen.dart`,
`lib/features/achievement_promotion/achievement_promotion_preview_screen.dart`,
`lib/features/onboarding/unified_onboarding_flow_screen.dart` among them.

### B5. Loading treatments — 6 of them, and the good one is used 11 times (P2)

| Treatment | Count |
|---|---|
| `AksharaLoadingState` (shared, chip-framed ring + caption) | **257** |
| `AksharaSkeleton.dashboard()` | **11** — all dashboards |
| Bare full-page `CircularProgressIndicator()` | **17** |
| `loading: () => const SizedBox.shrink()` — silent, content pops in | **35** |
| `LinearProgressIndicator()` as the entire loading state | platform ops hub `:211,229,248,277,296` |
| Nothing at all | **25** |

92% conform, which is the point — but the 17 bare spinners are on screens a
principal reaches:
`lib/features/finance/collection_detail/finance_collection_detail_screen.dart:310`,
`lib/features/sis/registry/sis_registry_screen.dart:590`,
`lib/features/legal/legal_acceptance_screen.dart:89`,
`lib/features/platform/branch/branch_screen.dart:68`,
`lib/features/platform/multi_school/multi_school_portfolio_screen.dart:60`,
`lib/features/platform/organization_builder/organization_builder_hub_screen.dart:77`,
`lib/features/inventory/intelligence/inventory_copilot_screen.dart:89`,
`lib/features/dynamic_widgets/dynamic_widget_registry_screen.dart:75,92`.

### B6. The shared async body was forked three times, and the forks lost a parameter (P3 mechanically, P1 in consequence)

`lib/features/finance/finance_async_state.dart:77`,
`lib/features/sis/sis_async_state.dart:77` and
`lib/features/admissions/admissions_async_state.dart:77` are byte-identical
copies of `lib/shared/async/erp_async_state.dart:77`, differing only in a doc
comment — **and each dropped the `errorMessage` parameter the canonical version
carries at `erp_async_state.dart:35`.**

The consequence is the thing to record: **a future fix to the canonical async
body will not reach Finance, SIS or Admissions** — the three highest-traffic
admin modules in the product. This is the polish equivalent of the shared-state
defect WS10 is chartered to find, and it is why it is worth more than its P3
mechanical severity.

### B7. Built, tested, never wired (P2)

The RC phase found that the parent-dashboard skeleton was unreachable code. That
was not an isolated case:

- **`AksharaSkeleton` has 6 builders; only `.dashboard()` ships.** `.list()`,
  `.row()`, `.card()`, `.line()`, `.circle()` have **zero production call
  sites** — `.list(rows:)` exists only in
  `test/widgets/akshara_skeleton_test.dart:36,60,110`. A list skeleton was
  designed, built and unit-tested, and all **78 admin list screens** fall back
  to a spinner (`erp_async_state.dart:110`).
- **`AksharaAnimatedSwitcher`** (`lib/shared/widgets/akshara_motion.dart:121`) —
  defined, unit-tested (`test/widgets/akshara_motion_test.dart:31`), **zero
  production uses**.
- **`akshara_mount_fade.dart`** — zero uses, and it is the **only widget in the
  repo that honours `MediaQuery.disableAnimations`** (`:55`). See B9.
- **`akshara_premium_empty_state.dart`** — used exactly once
  (`lib/features/evolution/parent_insights_screen.dart:167`), so two parallel
  empty-state visual languages coexist.

A tested widget with no call site is a specific kind of unfinished: the work was
done and the last step was skipped. It also means the golden suite is proving
the appearance of things nobody sees.

### B8. Developer-grade empty states (P2/P3)

130 files use the shared empty-state widgets
(`akshara_empty_state.dart`, `akshara_section_empty.dart`). About 20 do not. The
ones that matter:

- `lib/features/intelligence/intelligence_screen.dart:139` — `Text('No class
  summaries yet. Compute risks to populate.')` and `:154` `Text('No student risk
  snapshots yet.')`. Both sit in the *same* `.when()` as a proper
  `AksharaLoadingState` and `AksharaErrorState` — so the loading and error
  states are designed and the empty state, **which is the one a school hits on
  day one**, is a bare left-aligned sentence.
- `lib/features/entitlements/organization_plan_assignment_screen.dart:94` —
  `Center(child: Text('No organizations available.'))`.
- `lib/features/dynamic_widgets/dynamic_widget_runtime_screen.dart:96` —
  `Center(child: Text('No widgets visible for your permissions.'))`.
- `lib/features/platform/organization_builder/organization_builder_hub_screen.dart:172`
  — `Text('No interview drafts yet.')`, with **no call to action on a screen
  whose entire purpose is creating drafts**.

Plus P3 instances in `substitute_manager_screen.dart:328`,
`teacher_reassignment_screen.dart:279,362`, `onboarding_hub_screen.dart:53,83`,
`school_memory_event_screen.dart:217`, `control_center_providers_screen.dart:123`,
`hr_employee_profile_screen.dart:256,305`, `finance_discounts_screen.dart:595`,
`alumni_profile_screen.dart:217`, `teacher_parent_communication_screen.dart:297`.

### B9. Motion: tokens are respected, but the whole app ignores reduce-motion (P1 a11y)

The token side is genuinely clean and should be recorded as a pass:
`lib/theme/motion.dart` defines instant/fast/standard/slow with enter/exit
curves, wired at `lib/theme/app_theme.dart:334` and
`lib/theme/page_transitions.dart`. There are only **12 hard-coded
`Duration(milliseconds:)` values in all of `lib/features/`** across 7 distinct
values. That is a design system being used.

The defect is in the gate. `lib/theme/motion.dart:33`:

```dart
animationsEnabledInEnvironment => !bool.fromEnvironment('FLUTTER_TEST')
```

It **never reads `MediaQuery.disableAnimations`.** Every entrance animation in
the product runs through `AksharaMotionAppear` (which wraps all loading, empty
and error states) and every page transition through `page_transitions.dart:17`,
so **the OS-level "Reduce motion" accessibility setting has no effect anywhere in
NIKSHA OS.** The correct check is already written — in the dead
`akshara_mount_fade.dart:55` (B7).

Separately (P2): `AnimatedSwitcher`, `AnimatedOpacity`, `AnimatedCrossFade`,
`AnimatedPadding` and `TweenAnimationBuilder` have **zero uses in
`lib/features/`**; `AnimatedContainer` has two. Every loading→data transition
and every filter change on all 310 screens is a hard cut. `AksharaMotionAppear`
animates the placeholder in, but the data body that replaces it does not
animate — so the polish is applied to the state nobody looks at and not to the
swap the user actually watches.

### Section B verdict

A principal would believe **finance, SIS, HR, admissions, academics, hostel,
library, inventory, alumni, gate pass, certificate desk and clearance** are
finished — those ride `ErpAsyncBody` and are consistent.

They would stop believing it at one of three moments: opening a module they lack
permission for and getting a bare sentence on a white screen (B2, 17 screens);
opening Platform Operations and seeing 22 Dio exceptions (B3); or pulling to
refresh any admin list and having nothing happen (B1, 77 of 78 screens).

## Section C — Do the RC polish fixes hold?

Each of the five claims was re-verified against the current tree. **All five
fixes are real.** In four of the five, the *class* of bug survives elsewhere —
and in one case, inside the very file the fix was made in.

### C1. Contrast — HOLDS, and the test is honest (PASS)

`test/theme/rendered_contrast_audit_test.dart:46` asserts
`AksharaAccessibility.minContrastNormalText` = **4.5**
(`lib/theme/accessibility.dart:6`), not the 3.0 large-text floor the RC audit
caught it using. It also carries a **premise guard** at `:134` that fails if the
chip's default size stops being `compact` — i.e. the test defends its own
assumption, which is the thing the charter's honesty rules ask for.

The "14 pairs" claim is arithmetically exact: `KpiAccent` has exactly 7 values
(`lib/theme/theme_extensions.dart:246` — primary, success, warning, error,
neutral, tertiary, indigo) × 2 themes, looped at
`rendered_contrast_audit_test.dart:51-60`. **Recorded as a genuine pass.**

But the fix stopped at that one widget:

- **P2 — the KPI trend chip's neutral state measures ~4.04:1 and is untested.**
  `onSurfaceVariant` (#64748B) on `surfaceContainerHigh` (#E8EDF3), 11px
  `labelSmall` w600 → normal text → needs 4.5. Two independent copies:
  `lib/shared/widgets/akshara_kpi_card.dart:213` (`_KpiTrendChip`, class at
  `:186`) and `lib/shared/widgets/akshara_executive_kpi_card.dart:165`. This is
  the "no change / flat" delta label under **every KPI on the parent, teacher,
  student and management dashboards** — it washes out in daylight, which is
  where an Indian school principal reads their phone.
- **P2 — hint/placeholder text measures ~3.42:1.** `lib/theme/app_theme.dart:698-700`
  paints `onSurfaceVariant.withValues(alpha: 0.85)` on
  `fillColor: surfaceContainerLow` (`:687`). Every search box and every form
  field in the app. No test covers it.
- **P3 — chart legend labels pass at ~4.55:1 by 0.05**
  (`lib/shared/widgets/akshara_chart.dart:145-153`) and are untested, so any
  token nudge breaks them silently.
- **P3 — `onSurfaceVariant on surface` is gated at only 3.0**
  (`lib/theme/accessibility.dart:80`) even though it is the app's default
  secondary *body* colour. It currently measures 4.76:1 — so the assertion is
  1.76 points looser than reality and would green-light a real regression. This
  is the same defect shape the RC phase closed on the status chip, still open
  one line away.
- No contrast coverage at all for on-accent text
  (`lib/shared/widgets/workspace_switcher.dart:227`), snackbar/tooltip text,
  badges outside `_MarkBadge`, or severity labels.

### C2. 48dp tap targets — the fix did not hold inside its own file (P2)

`lib/shared/navigation/akshara_navigation.dart:667` — `AksharaNavSearchField`
is an `InkWell` wrapped around `Container(height: 40)`. **This is the same file
the RC log records as fixed 40→48dp.** Three other sites in it correctly use
`AksharaSpacing.minTouchTarget` (`:241, :464, :611`); the search field was
missed. It sits in the admin app bar, so it is on every admin and module screen.

Five more production violations:

| File:line | Control | Size |
|---|---|---|
| `lib/features/parent/dashboard/widgets/hero_card.dart:145-147` | Tappable school avatar — top of the first screen a parent ever opens | `SizedBox(40×40)` |
| `lib/features/parent/fees/installment_timeline.dart:167` | "View receipt" per installment | `minimumSize: Size(40,40)` — **explicitly overrides** the theme's 48dp floor |
| `lib/features/teacher/dashboard/widgets/attendance_summary_card.dart:160` | "Check in now" — a daily-use primary action | `minimumSize: Size(0, 36)` |
| `lib/features/adaptive_ai/widgets/adaptive_search_results.dart:98-99` | "Load more" in AI search | `Size.zero` + `MaterialTapTargetSize.shrinkWrap` |
| `lib/features/academics/timetable/timetable_hub_screen.dart:487-488` (P3) | only `shrinkWrap` + `VisualDensity.compact` combo | — |

A further **24 `VisualDensity.compact` sites** shave ~8dp each across transport
(drivers, vehicles, routes, allocation), hostel students, library issues,
finance discounts (`:422`), notifications (`:381`) and the approval queue table
(`:483, :496`).

**Why none of this was caught:** `test/theme/tap_target_lint_test.dart` asserts
only the *theme defaults* and pumps exactly two widgets. It cannot see a
per-call-site override. That is a test asserting a premise weaker than the
claim it appears to defend — the charter's stated worst case.

### C3. Text-scale clipping — fix is real, class survives (P2)

`lib/shared/widgets/akshara_section_header.dart:98-103` is now
`ConstrainedBox(minHeight: 32)`, not `SizedBox(height: 32)`. Correct.

**There is no global `textScaleFactor` clamp** — `lib/app/app.dart:107`'s
`builder:` does not override MediaQuery, and clamping is confined to two
legitimately dense grids (`lib/theme/accessibility.dart:58`,
`lib/shared/marks_grid/marks_grid.dart:145`). So every layout must survive large
type on its own merits. Three do not:

- `lib/features/admissions/dashboard/widgets/admissions_dashboard_kpi_row.dart:34`
  — `SizedBox(height: 120, child: AksharaKpiCard(...))`. The fixed height
  **defeats `AksharaKpiCard`'s own text-scale growth**
  (`lib/shared/widgets/akshara_kpi_card.dart:33-36`). The Admissions dashboard
  KPI row is precisely the bug the shared fix was written to cure, reintroduced
  by a wrapper.
- `lib/features/director/widgets/director_shared_widgets.dart:31,45` — hard
  `SizedBox(height: 140)` KPI tiles on both the phone and wrap paths.
- P3, worth naming as a known ceiling: `akshara_kpi_card.dart:34` and
  `lib/shared/widgets/akshara_progress_ring.dart:43` clamp growth at 1.6×/1.5×
  and fall back to `maxLines:1 + ellipsis`. Above ~1.6× a principal on maximum
  system font sees a **truncated money value** — "₹12,4…" — which is degraded
  but at least honest.

### C4. Day-one empty states — 4 dashboards fixed, 6 still broken (P2)

Verified present and rendering a real bordered `AksharaSectionEmpty` card:
HR (`lib/features/hr/dashboard/hr_dashboard_screen.dart:141,186`), SIS
(`sis/dashboard/widgets/sis_recent_enrollments_table.dart:24`,
`sis/widgets/sis_enrollment_queue.dart:31`), Finance
(`finance/dashboard/widgets/finance_recent_payments_table.dart:24`,
`finance/widgets/finance_handoff_queue.dart:36`), Admissions
(`admissions/dashboard/widgets/admissions_pipeline_preview.dart:29`,
`admissions_counselor_leaderboard.dart:24`).

The class was not swept. Six dashboards still render headed holes on day one:

- **Admissions is only 2 of 3** — and this is the most visible instance in the
  product, because it sits *between* two now-polished empty cards. The
  "Follow-ups due today" header
  (`lib/features/admissions/dashboard/admissions_dashboard_screen.dart:115`)
  renders `admissions_followups_table.dart:22` with **no `isEmpty` guard**: on
  desktop, a bare 7-column DataTable of headers with zero rows; on mobile
  (`:23-31`), a zero-height gap.
- **Hostel — 3 sections**, and `_HealthAlertsList`
  (`lib/features/hostel/dashboard/hostel_dashboard_screen.dart:90` → `:202`)
  renders an **empty bordered Card with no content at all** — a blank box with
  no explanation, the worst visual of the set. Plus "Block occupancy"
  (`:126`→`:106`) and "Attendance by session" (`:184`→`:159`).
- **Transport — 2 sections:** "Live fleet assignments"
  (`transport/dashboard/transport_dashboard_screen.dart:77`→`:109`) and "Route
  performance" (`:274`→`:255`).
- **Library:** "Recent issues"
  (`library/dashboard/library_dashboard_screen.dart:95`→`:147`).
- **Inventory:** "Recent activity"
  (`inventory/dashboard/inventory_dashboard_screen.dart:125`→`:157`), plus
  `_IntegrationLinksCard` (`:274`).
- **Alumni:** "Recent SIS graduates"
  (`alumni/dashboard/alumni_dashboard_screen.dart:69`→`:99`).
- P3: Management (`management/dashboard/management_dashboard_screen.dart:338`)
  has a *visible* plain-text empty state — correct in substance, inconsistent
  with `AksharaSectionEmpty` styling.

### C5. Admin Hub dead gutter — HOLDS (PASS), sparse interior confirmed (P3)

`lib/features/admin/screens/admin_hub_screen.dart:76-99` now uses a
`LayoutBuilder` computing `columns = floor((maxWidth+16)/236).clamp(1,4)` and
divides available width evenly; `_ModuleCard` takes its `width` from the parent
(`:84-85, :124-125`). At ~411dp phone width this gives one full-width column.
**The dead gutter is gone. Recorded as a genuine pass.**

The RC log's own admission that the interior is now sparse is still accurate.
`admin_hub_screen.dart:138-174` is a `Column(crossAxisAlignment: .start)`
holding a ~48dp gradient icon tile, a `titleSmall` label, and an "Open →" row.
**What a principal actually sees on a phone:** a vertical stack of ~379×138dp
white cards, each with its content hugging the left edge and roughly the right
60–70% blank — one short word ("Finance", "HR") floating in a wide empty
rectangle, repeated 8–12 times down the page. This is the principal's home
screen. It is functionally correct and visually unfinished. The fix direction is
already implied: at one column, use a horizontal ListTile-shaped row (icon left,
label plus a live count centre, chevron right) instead of the vertical column
that was designed for 220dp tiles.

---

## Section D — Design-system integrity

**The DS V2 migration claim holds where it matters and fails at the seam.**

The screens a principal opens daily — finance defaulters, payroll, SIS registry,
exam reports, management dashboard, director dashboard, admissions dashboard —
return **zero** raw layout literals. Adoption baseline across `lib/features/`:
3,497 `AksharaSpacing.*`, 373 theme text styles, 149 `AksharaRadius.*`, 90
`AksharaBreakpoints` references. **Zero raw `Color(0x…)` in all 954 feature
files.** One icon family, no Cupertino mixing, no custom icon set (1,567
`Icons.*`, 0 `CupertinoIcons.*`).

Every bypass found is concentrated in modules bolted on **after** DS V2 landed:
`platform/`, `school_completion/`, `intelligence/`, `education/`,
`staff_attendance/`, `communication/`, `verticals/`.

### D1. 177 screens bypass the shared page shell — 40 of them inexcusably (P2)

Twelve module scaffolds correctly delegate to `AdminContentScaffold`
(`finance/widgets/finance_module_scaffold.dart:36` and its HR, SIS, admissions,
library, inventory, alumni, hostel, transport, management, director and
control-center siblings). **This is the strongest part of the system.**

But 177 of 310 screens use a bare `Scaffold` and inherit none of it — no 1440
grid, no `AdminAppBar`, no breadcrumbs, no filter bar. The persona shells
legitimately account for ~50. The remainder that matters:

- **`lib/features/school_completion/**` — 20 screens, 28 router references.**
  `substitute_manager_screen.dart`, `teacher_reassignment_screen.dart`,
  `lesson_analytics_screen.dart`, `pilot_dashboard_screen.dart`,
  `communication_analytics_screen.dart` each hand-roll their own page. **These
  sit beside HR and Academics in the navigation and look nothing like them.**
- `lib/features/verticals/**` — 20 screens, 20 router references, zero shared
  shell (these are non-school verticals; see the status note below).
- `lib/features/platform/**` — 14 · `intelligence/**` — 7 · `academics/**` — 5 ·
  `management/**` — 3.

Page gutters are mostly consistent (104× `EdgeInsets.all(AksharaSpacing.s4)`)
but **21 screens deviate**: 14× `s6`, 3× `s5`, 3× raw `16`, one
`symmetric(horizontal: 16.0, vertical: 16.0)`. Sibling screens at 16dp and 24dp
gutters is the classic "assembled by different people" tell.

### D2. Unguarded fixed-width `Wrap` — the RC Admin Hub bug, still live in 6 places (P1)

`lib/theme/breakpoints.dart` is well designed (mobile 767 / tablet 1199,
`narrowMobileMaxWidth: 360`, `useCardLayout(w,h)`) and genuinely used — 47 files,
93 `useCardLayout` call sites. But the exact pattern RC fixed on the Admin Hub
survives unguarded:

| Sev | File:line | Screen | Fixed width in a `Wrap` |
|---|---|---|---|
| **P1** | `lib/features/academics/exam_admin/exam_reports_screen.dart:448,469,490` | **Exam Reports** filter bar | 160+160+220 = **540dp of dropdowns**, no guard |
| **P1** | `lib/features/school_completion/substitute_manager_screen.dart:271,293` | Substitute Manager filter bar | 220 + 240 side by side, no guard |
| P2 | `lib/features/platform/organization_builder/organization_builder_hub_screen.dart:104` | Org Builder pack grid | 280 — exceeds 320dp minus gutters |
| P2 | `lib/features/platform/multi_school/multi_school_portfolio_screen.dart:101` | Multi-school portfolio KPIs | 220, no guard |
| P2 | `lib/features/intelligence/trust/trust_intelligence_hub_screen.dart:312` and `platform/control_center/intelligence/platform_intelligence_screen.dart:338` | Trust / Platform Intelligence KPIs | 260, no guard |

Exam Reports is the one that will actually bite: an examinations officer on a
phone gets a 540dp filter bar in a 360dp viewport.

The correct pattern already exists twice and should be the fix template —
`lib/features/director/widgets/director_shared_widgets.dart:38-47` and
`director/director_school_snapshot_screen.dart:188-194` both fall back to a
`Column` before the `Wrap`; `admissions/settings/admissions_settings_screen.dart:73`
guards its 540dp sections.

Related:
- P2 — `lib/features/memories/school_memory_event_screen.dart:225` hard-codes
  `crossAxisCount: 3` (5 of 6 GridViews compute columns). Media tiles go ~100dp
  wide on a 360dp phone.
- P2 — `lib/features/director/widgets/director_shared_widgets.dart:44-45` pins
  KPI cards to `width: 240, height: 140`; text scale 1.3 overflows them (also C3).
- **P3 / genuine pass — DataTable responsiveness is real.** All 88 instances are
  either `AksharaVirtualizedDataTable` or wrapped in a horizontal
  `SingleChildScrollView`, **and** gated behind `AdminLayout.useCardLayout` with
  an `AksharaKeyValueCard` fallback (verified at
  `trust_intelligence_hub_screen.dart:127-141`,
  `platform_intelligence_screen.dart:191-205`). No unguarded phone overflow
  found.

### D3. Mixed corner radii on a daily screen (P2)

Eleven distinct raw `BorderRadius.circular()` values against a 7-value token
set. Off-token: 2, 3, 4, 10, 14.

- `lib/features/admissions/dashboard/widgets/admissions_assistant_card.dart:160,162,174`
  — radius **14**, three times, on the Admissions dashboard, where adjacent
  cards use `AksharaRadius.lg` (16). **This is the visible "different corner
  radius on the same screen" symptom, on a screen an admissions counsellor opens
  every morning.**
- Radius `4` appears 13× as a copy-paste clone: `*_segment_panel.dart:73` is
  byte-identical across **8 modules** (`management`, `library`, `inventory`,
  `hr`, `alumni`, `hostel`, `transport`,
  `platform/control_center/widgets/control_center_segment_panel.dart:73`). One
  template forked eight ways, all off-token — a single fix kills 13 of the 18
  off-token radii.
- Elevation is clean (182 of 193 are `0`); strays at
  `copilot/dock/copilot_floating_dock.dart:44` (**6**, not on the
  `AksharaElevation` ladder at all), `parent/fees/pay_now_bottom_bar.dart:30` (8),
  `support/support_incident_detail_screen.dart:491` (2).

### D4. Raw status colours on the daily Office Attendance screen (P2)

51 genuine `Colors.<name>` uses survive (148 raw hits minus 60
`Colors.transparent` and ~37 false matches on `AksharaColors.grey600`). The
concentration that matters:

- `lib/features/management/attendance/office_attendance_screen.dart:452-457,946-949`
  — **9 raw status colours in two `switch` maps** (Present / Absent / Late /
  half_day). Office Attendance is a screen the principal opens daily, and its
  status chips do not shift with the persona accent, so they read slightly
  "off" beside their tokenised siblings.
- `lib/features/school_completion/branding_screen.dart:102` —
  `return Colors.blue;` as the fallback when **a school's own brand colour fails
  to parse**. The white-label screen falls back to Material blue.
- `platform/control_center/providers/control_center_providers_screen.dart:177-179,377-380`
  (7) · `platform/organization_builder/organization_provisioning_screen.dart:94-150`
  (6) · `intelligence/management/intelligence_hub_screen.dart:593-595` (3, risk
  pills).

### D5. Dark mode is well defended — with one live hole (P2)

Recorded as a substantial pass: the dark theme is fully built
(`lib/theme/app_theme.dart:39`, `color_tokens.dart:210`,
`premium_tokens.dart:68`) and **regression-locked by goldens** —
`test/golden/dark_mode_render_test.dart` plus dark PNGs for the parent
dashboard, finance dashboard (390 and 834), office attendance, teacher
exams/homework/settings and student attendance. There are **zero**
`Theme.of(context).brightness` or `isDark` checks in `lib/features/`, which is
*correct* — the tokens resolve it.

Ten hard light-mode sites remain; two matter:
- `lib/features/management/approval/widgets/approval_queue_table.dart:524` —
  `const onTone = Colors.white;` painted on a token-resolved fill. It will fail
  contrast on a light accent in dark mode. **The approval queue is a daily
  principal screen.** Two adjacent comments in
  `office_attendance_screen.dart:383-384,871` document this exact
  `Colors.white`-on-token WCAG failure being fixed once already — the class was
  not swept.
- `lib/features/admissions/widgets/admissions_chart_panel.dart:134` —
  `color: Colors.white` on chart segment labels; breaks when the segment fill
  lightens in dark theme.
- (`staff_attendance/device/mlkit_face_capture.dart:310-345` is a camera surface
  — intentional, not a defect.)

### D6. Typography — low volume, but the same element typed five ways (P2)

86 `fontSize:` literals, but **52 are inside 7 `*_pdf_service.dart` files** and
are legitimate (`pw.TextStyle` has no Flutter theme). The real screen count is
**34 literals across 12 distinct sizes** (8, 9, 10, 11, 12, 13, 14, 15, 16, 18,
20, 22) — more than 10 distinct sizes means the scale is not being respected,
though the volume is small.

The telling one: `fontSize: 10` micro-labels on KPI cards appear in **five
persona files** — `parent/dashboard/parent_dashboard_screen.dart:434`,
`teacher/dashboard/widgets/attendance_summary_card.dart:233`,
`teacher/exams/teacher_exams_screen.dart:267`,
`student_app/exams/student_exams_screen.dart:185`,
`parent/attendance/attendance_kpi_strip.dart:68`. The same visual element, hand-
typed five times instead of tokenised once.

Worst cluster: `lib/features/platform/` hand-rolls
`TextStyle(fontSize: 16, fontWeight: w600)` as an ersatz section header in 6
places (`organization_builder_hub_screen.dart:53,71`,
`multi_school_portfolio_screen.dart:54,71`,
`organization_provisioning_screen.dart:83`,
`organization_builder_preview_screen.dart:116`). Orphan sizes:
`evolution/growth_platform_screen.dart:389` (22, the only 22 in the app),
`sis/profile/sis_profile_edit_sheet.dart:112` (18 on a sheet title whose
siblings use `titleMedium`).

Spacing is close to clean: raw `EdgeInsets.all(N)` uses only 3 values (8/12/16),
all on-scale, with **no odd 7/13/18/22 anywhere**. The drift is in
`EdgeInsets.symmetric` (12 distinct values, 6 off-scale) and raw
`SizedBox(height:)` (6 off-scale: `2`×31, `6`×9, `10`×4, 72, 120, 140). The
`16` vs `16.0` duplication is a lint-level tell. P3.

### D7. Emoji used as production UI iconography (P2)

In a product with 1,567 `Icons.*` and a locked design system, four screens
render emoji as interface elements:

- `lib/features/school_completion/timetable_automation_screen.dart:77` —
  `Text('⚠ $w')` renders timetable warnings with an emoji instead of
  `Icons.warning_amber`.
- `lib/features/achievement_promotion/achievement_promotion_screen.dart:130` —
  `'👁 ${views} · ↗ ${shares}'` as the analytics row.
- `lib/features/platform/platform_operations/platform_operations_hub_screen.dart:575`
  — `' ⚠'` appended to a user count. P3.

(A fourth hit, `student_app/dashboard/student_dashboard_provider.dart:141`
`'Hey Ravi! 👋'`, is a **hard-coded student name in a provider**, not a design
issue — it belongs to the fabricated-data class WIDGET-001 covers and is noted
here only so it is not lost.)

---

## Section E — "Looks functional, does nothing"

This is the section the workstream's standard was written for. WS6 found ten
module dashboards shipping filter chips the data fetch never reads
(WIDGET-008/009/010). **Those ten are not re-reported here.** This is everything
else.

**First, the honest frame:** the codebase is far cleaner on this axis than a
sweep of 310 screens usually finds. Verified genuinely wired and *not* defects:
every search field traced (`finance_student_accounts_screen.dart:72`,
`sis_registry_screen.dart:255`, `teacher_attendance_screen.dart:392`,
`parent_receipts_screen.dart:87`, `global_search_overlay.dart:140`) reaches a
query; all 11 `AksharaPaginationBar` page providers are read by their fetch
layer; sort menus in exam reports, lesson logs, parent insights and finance
collections all dispatch; `notificationFilterProvider` genuinely filters
(`notifications_screen.dart:23`); Appearance and App Lock settings persist. There
are **no** `onPressed: () {}` stubs, **no** `debugPrint`-only callbacks, **no**
`Placeholder(` widgets and **no** lorem text in production. `AdminModulePlaceholderScreen`
exists but no route builds it.

So the findings below are specific, not endemic.

### E1. The staff profile avatar — confirmed independently (P0, = A1)

Reached separately by this sweep, which is worth recording: the release-build
branch of `admin_content_scaffold.dart:88-110` is the placeholder snackbar, none
of the 20 `AdminContentScaffold(` callers passes `onProfileTap`, and the avatar
renders as an enabled control with
`Semantics(button: true, label: 'Staff profile')`
(`lib/features/admin/admin_app_bar.dart:120-131`). It affects **every screen
behind the Finance, SIS, HR, Admissions, Transport, Library, Hostel, Inventory,
Management, Director, Control Center, Timetable, Copilot and Admin Hub module
scaffolds.** See Section A1 for the log-out consequence.

### E2. Every AI Copilot quick action opens an empty chat (P1)

`lib/features/copilot/widgets/copilot_ai_quick_actions.dart:132` —
`executeCopilotQuickAction` stages the chosen action's prompt into
`copilotMessageDraftProvider` and then opens the assistant.

**`copilotMessageDraftProvider` (`lib/features/copilot/copilot_provider.dart:19`)
is never read anywhere in the repository.** The composer
(`copilot_screen.dart:29`, `_messageController`) is constructed empty.

A principal long-presses the AI dock, picks "Explain fee defaulters", the chat
opens — blank. The prompt they selected was written to a provider with no
reader. This is the WS6 defect shape exactly (state written, never consumed),
and it is on the product's flagship AI surface, reachable from
`copilot_floating_dock.dart:63`, `copilot_bottom_nav_ai_slot.dart` and
`admin_navigation_rail.dart:204` — i.e. from every persona.

### E3. Parent navigation dispatches on hard-coded demo IDs (P1)

`lib/router/parent_navigation.dart`:

- `:33-36` and `:115-118` — "Pay fee" from the parent dashboard always routes to
  a **hard-coded `installmentId=term_2`**, and `handleParentFeesNavigation`
  defaults `installmentId ?? 'term_2'`. (JOURNEY-015 registers the symptom; this
  is the second call site.)
- `:86-93` — notice and event taps are dispatched off **hard-coded mock IDs**
  (`notice_n1`, `event_e2`, `notice_n3`). Against real data no ID matches, so
  every notice tap falls through to the generic list: **the tap looks like a
  drill-down and is not.** Worse, `notice_n1` and `event_e2` target `/parent/ptm`,
  which is a **blocked route prefix**
  (`lib/core/config/school_build_scope.dart:82-83`) — so the two IDs that *do*
  match navigate to a gated screen (compare JOURNEY-016).
- `:133-134` — `default: break;` silently swallows any unmapped `actionId`. A
  dead tap with no feedback.

### E4. Eleven more filter bars that never reach the query, plus two period pickers (P2)

Same defect as WIDGET-008/009/010 but on **list and detail screens** rather than
dashboards, so they are outside that entry's scope. In each case the provider is
`watch`ed only to paint `selectedFilterIndex:` and written on tap; a repo-wide
grep finds no other reader — no `.where`, no query parameter, no view-state
provider.

| Screen (user path) | file:line (watch / write) | Chips that do nothing |
|---|---|---|
| Admissions → Applications | `lib/features/admissions/applications/admissions_applications_screen.dart:36,42` | All statuses, All classes |
| Admissions → Documents | `lib/features/admissions/documents/admissions_documents_screen.dart:35,43` | All types / statuses / classes |
| Admissions → Leads | `lib/features/admissions/leads/admissions_leads_screen.dart:36,62` | All sources / stages / scores |
| **HR → Payroll** | `lib/features/hr/payroll/hr_payroll_screen.dart:36,43` | **Current month / Last month / All runs** |
| Library → Resources | `lib/features/library/resources/library_resources_screen.dart:34,43` | All / Student app / Teacher app / Staff only |
| Management → Academics | `lib/features/management/academics/management_academics_screen.dart:36,43` | Current term / All classes / All subjects |
| Management → Finance | `lib/features/management/finance/management_finance_screen.dart:37,44` | FY 2026-27 / This quarter / All campuses |
| Management → Performance | `lib/features/management/performance/management_performance_screen.dart:34,41` | Current term / All classes / All metrics |
| Management → Analytics | `lib/features/management/analytics/management_analytics_screen.dart:36,43` | This year / All classes / All sections |
| Management → Admissions | `lib/features/management/admissions/management_admissions_screen.dart:35,42` | This month / All sources / All counselors |
| Control Center → CRM | `lib/features/platform/control_center/crm/control_center_crm_screen.dart:32,39` | All stages / Demo / Proposal / Won |

Plus **Finance → Executive Dashboard**
(`lib/features/finance/intelligence/finance_executive_dashboard_screen.dart:37-41`,
provider at `:143`): `_periodFilters = ['This month','This quarter','YTD']`
(`:19`) while `financeExecutiveProvider` (`:23`) **takes no period argument at
all**. Distinct from JOURNEY-009, which covers the Management dashboard's FY.

**The HR → Payroll one is the most dangerous of the set.** "Current month / Last
month / All runs" on a payroll screen is not a convenience filter — an
accountant switching to "Last month" and seeing the current month's runs,
unchanged and unlabelled, is being actively misled about which payroll they are
looking at.

The Management module contributes five of the eleven. Together with
JOURNEY-009's dashboard, **every screen in the Management workspace has a filter
bar that does nothing** — and Management is the principal's own workspace.

### E5. Six Export/Print buttons that produce nothing (P2)

`showAksharaReportExportPreviewSnackBar`
(`lib/shared/widgets/operational_action_feedback.dart:17-30`) emits *"preview
only. Export pipeline not connected yet."* The **copy is honest** — that is worth
crediting. The **control is not**: it is a full-size, permission-gated
Export/Download/Print button, visually indistinguishable from the real exporters
used elsewhere in the same module.

- Transport → Dashboard, "Export" — `lib/features/transport/dashboard/transport_dashboard_screen.dart:41`
- Hostel → Dashboard, "Export" — `lib/features/hostel/dashboard/hostel_dashboard_screen.dart:41`
- Control Center → Dashboard, "Export" — `lib/features/platform/control_center/dashboard/control_center_dashboard_screen.dart:44`
- Control Center → Analytics, "Export" — `lib/features/platform/control_center/analytics/control_center_analytics_screen.dart:30`
- **Library → Reports, "Download report"** — `lib/features/library/reports/library_reports_screen.dart:179`. The *same screen's* overdue tab has a real CSV/PDF export at `:161-174`, so a librarian sees a working download on one tab and a stub on the next, with identical affordances.
- Intelligence → parent guidance report, "Print" (rendered whenever `report.printable`) — `lib/features/intelligence/intelligence_screen.dart:586-592`

(The same stub appears at `alumni/dashboard/alumni_dashboard_screen.dart:41` and
`alumni/reports/alumni_reports_screen.dart:152`, but Alumni is route-blocked in
the school build — not reachable, no action needed.)

The correct pattern is one line away: `hostel/reports/hostel_reports_screen.dart:168-169`
uses `onPressed: null` with the tooltip "Export not available yet" — visibly
disabled, honest, and impossible to mistake for a working control.

### E6. Written-but-never-read state (P3, cleanup not polish)

Recorded so the class is closed rather than because any of it is user-visible.
Declared with zero call sites: `financeDiscountsTabProvider`,
`parentPreferredLanguageProvider`, `transportSelectedRouteIdProvider`,
`financeAssignmentDraftProvider`, `sisAssignmentDraftProvider`,
`parentComposeDraftProvider`, `hrExportRunIdProvider`. Two journey breadcrumbs
are written and never read: `financeLastReceiptNumberProvider`
(`finance_workflow_actions.dart:1409`) and `admissionsLastApprovalIdProvider`
(`admissions_enrollment_provider.dart:111`).

---

## Section F — WS9 verdict

**Would a principal paying for this believe it is finished? Not yet — but the
distance is short, and it is not where you would expect.**

The foundations are real and should be stated plainly, because they change what
the remediation is: the design system is genuinely adopted (zero raw hex colours
in 954 files, 3,497 spacing-token uses, one icon family, dark mode golden-
locked); the async-state system is well designed and *enforces* retry and empty
copy at the type level; the motion tokens are respected; the contrast test is
honest and its 14-pair claim is exact; the Admin Hub gutter fix holds; DataTable
responsiveness is real across all 88 instances; and the codebase carries **two
`TODO`s in total**.

**What breaks the belief is narrower and sharper than a quality problem — it is
a finishing problem.** Three things a principal will hit in the first session:

1. **They tap their own avatar and are told the profile menu is coming soon —
   and discover they cannot log out at all** (A1). This is the first personal
   affordance in the product and it is empty.
2. **They pull to refresh a list and nothing happens** — on 77 of 78 admin list
   screens (B1), while the parent app their customers use refreshes correctly.
3. **They open a module they lack rights to and get a bare sentence on a white
   screen** (B2, 17 screens), which is indistinguishable from a crash.

Behind those sit the pattern that gives this workstream its standard: **things
that were built, tested, and never connected.** The list skeleton
(`AksharaSkeleton.list()`), the animated switcher, the reduce-motion-aware mount
fade, the notification badge on every admin screen, the `dynamic_widgets`
registry, the Copilot quick-action draft provider (E2) — each is finished work
whose last wire was never run. WS6's ten dead dashboard filter bars, the eleven
more found here (E4), and the six inert Export buttons (E5) are the same
phenomenon seen from the front.

The concentration matters more than the count. **Every screen in the Management
workspace — the principal's own — has a filter bar that changes nothing** (E4
plus JOURNEY-009). The AI quick actions all open an empty chat (E2). The payroll
period selector silently lies to an accountant (E4). None of these fail loudly;
each teaches the user, correctly, that controls in this product are decorative
until proven otherwise. That lesson is what costs the sale, and it is why this
class was treated as polish-critical rather than cosmetic.

**A product where the polish exists but is not plugged in reads, correctly, as
one that stopped just short.** That is the accurate summary of WS9: not a
quality problem, a finishing problem — which is good news, because the
remediation is mostly wiring, not design.

**Recommended order** (highest visible-quality return first):
A1/E1 log-out · B1 pull-to-refresh (one wrapper, 78 screens, `onRetry` already
present) · E4 twelve dead filter bars, HR Payroll first · B2 permission state
(the widget already exists) · E2 Copilot draft provider (one read) ·
E5 six Export stubs → `onPressed: null` (one line each) · B3 Platform Ops
exception dumps · E3 parent navigation hard-coded IDs · C4 six remaining
day-one holes · D2 two unguarded filter bars · B9 reduce-motion · B7 wire the
list skeleton · C5 Admin Hub card interior.

