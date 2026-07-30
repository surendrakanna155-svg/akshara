# WS6 — Dashboard & Widget Certification

**Workstream 6** · Branch `release/v1.0-playstore` · 2026-07-29
**Scope:** every dynamic widget on every persona dashboard (parent, teacher,
student, principal/management, director) plus the ten admin module dashboards.

**Verdict: NOT CERTIFIED.** 18 defects — 3 P0 · 8 P1 · 6 P2 · 1 P3 — recorded as
`WIDGET-001…018` in `docs/certification/DEFECT_REGISTER.md`.

Each widget was checked against the eight required axes: **correct data ·
refresh · visual quality · wording · priority/ordering · usefulness · empty
state · loading state.**

---

## 0. Method and boundaries

Source-traced end to end: screen → widget → provider → repository → release
flag. Widget/provider files were read in full; empty and loading branches were
traced by reading the actual `build()` bodies, not by trusting a section
comment. Filter wiring was verified by checking whether the `*FutureProvider`
**watches** the filter state, not by whether the chips render.

**Boundaries.** No device run — the release binary requires production + a live
API (`guardForRelease`), so nothing here is a screenshot; every rendering claim
is derived from the widget tree. Golden tests exist and pass, but they pin the
**mock** data path (`test/golden/golden_test_helpers.dart` overrides all nine
dashboard loading/error providers to `false`), which is precisely the state
WIDGET-001/002 shows is unreachable in production — a green golden asserting a
premise the app never enters.

---

## 1. The headline finding — two dashboards ship fabricated data on the loading path

The **student** dashboard does this correctly and is the reference:

```dart
// student_dashboard_screen.dart:36-39
final isLoading = ref.watch(studentDashboardLoadingProvider) || async.isLoading;
final hasError  = ref.watch(studentDashboardErrorProvider)  || async.hasError;
// student_dashboard_provider.dart:283-285
return data ?? future.value ?? StudentDashboardData.empty();
```

The **parent** and **teacher** dashboards do not:

```dart
// parent_dashboard_screen.dart:39-41  /  teacher_dashboard_screen.dart:31-33
final isLoading = ref.watch(parentDashboardLoadingProvider);   // manual only
final hasError  = ref.watch(parentDashboardErrorProvider);     // manual only
// parent_dashboard_provider.dart:312-314
final raw = data ?? future.value ?? ParentDashboardData.mock();
```

`parentDashboardLoadingProvider` and its siblings are `StateProvider<bool>` that
default to `false` and — verified by grep across `lib/` — are **never written
outside tests**. `watchRepositoryFuture` returns `null` while the future is
pending (`repository_future.dart:13` is `whenOrNull(data:)`), and
`AsyncValue.value` is also null then. So on **every cold open**, for the whole
duration of the network fetch, the parent and teacher dashboards render
`.mock()`:

| Persona | What is shown before real data arrives, and permanently on failure |
|---|---|
| Parent | Child **"Ravi Kumar", class 8-A**, school "Akshara Public School" · status chip **"₹4,200 due"** · today row **"Present · Marked 9:12 AM"** · **"2 homework due today"** · **"Term 2 installment due 12 Jun"** · AI bar **"Fee due in 5 days — pay early to avoid late fee"** · 3 fabricated notices · 3 fabricated events |
| Teacher | **"Good morning, Priya" / "Priya Sharma"** · staff check-in **"9:02 AM · Geo+Face verified"** · **"34 of 38 present"** · **"Attendance not marked for Class 8-A · Period 1"** · a 3-period fabricated timetable |

The skeleton passed to `MobileAsyncBody` (`AksharaSkeleton.dashboard()`) is
therefore **unreachable code on both screens** — it can only render if a test
sets the manual provider.

This is the register's standing-rule case three times over: fabricated
**financial** data to a parent, fabricated **attendance** to a parent, and
fabricated **staff attendance with a "Geo+Face verified" assertion** to a
teacher — a claim about a biometric check-in that did not happen, on the record
that feeds payroll.

`FEATURE_INVENTORY.md` already flags these two screens as **CERT-002**, worded
as "falls back to fabricated demo data **on failure**". That understates it: the
failure path is the *permanent* case, and the loading path is the *every-launch*
case. Recorded separately as **WIDGET-001 (P0)** and **WIDGET-002 (P0)** because
the mechanism (dead manual state providers + dead skeleton) is a different fix
from the fallback constant.

## 2. Day-one emptiness — what a brand-new school sees

The RC phase fixed several headed sections that rendered zero-height holes. Those
fixes **hold** where they were applied. Verified still-correct:

| Widget | Empty behaviour | Evidence |
|---|---|---|
| `NoticeCarousel` | proper empty state | `notice_carousel.dart:27` |
| `EventCardList` | proper empty state | `event_card.dart:166` |
| `ParentReminderBanners` | self-hides | `parent_reminder_banners.dart:31` |
| `CoverAlertCard` | self-hides | `cover_alert_card.dart:19` |
| `PendingTasksSection` | header + empty state | `pending_tasks_section.dart:38` |
| `TodayScheduleCard` | header + empty state | `today_schedule_card.dart:39` |
| `HomeworkDueList` | header + empty state | `homework_due_list.dart:38` |
| `DailyScheduleStrip` | header + empty state | `daily_schedule_strip.dart:45` |
| `_StudentsNeedingAttentionSection` | self-hides when nothing pending | `teacher_dashboard_screen.dart:275-277` |
| `AdaptivePriorityFeedSection` | self-hides | `adaptive_priority_feed.dart:46-49` |
| `FinanceCollectionTrendChart` | dedicated `emptyState` + legend suppression | `finance_collection_trend_chart.dart:32-67` |
| `FinanceRecentPaymentsTable` | empty state, with an explicit day-one comment | `finance_recent_payments_table.dart:21-25` |
| `FinanceHandoffQueue` | empty state | `finance_handoff_queue.dart:36-40` |
| `_ApprovalQueuePreview` | empty text (weak, see WIDGET-014) | `management_dashboard_screen.dart:338-348` |

**The ones that were missed:**

### 2.1 `ManagementSegmentPanel` — a 240–320px blank box under a title

`management_segment_panel.dart:37-86` wraps a `ListView.separated` in a
**fixed-height `SizedBox`** with no empty branch. With `segments: []` — every
new school, and any school not using expense categorisation — the principal's
dashboard renders a bordered card containing the words *"Expense breakdown"* and
then 240–300px of nothing. Its sibling on the same row, `ManagementTrendChart`,
delegates to `FinanceCollectionTrendChart` which **does** have an empty state, so
day one shows a correct empty chart next to a large blank box. **WIDGET-003.**

### 2.2 Parent `_TodaySummarySection` — headed section, zero-height body

`parent_dashboard_screen.dart:538-575`: `AksharaSectionHeader('Today', 'See all')`
followed by a `Column` built from `items` with no `isEmpty` branch. On a school
with no timetable, homework or attendance yet, the parent sees the word **"Today"**,
a **"See all"** link, and then the next section. The exact defect class the RC
phase closed elsewhere, on the highest-traffic screen in the product. **WIDGET-004.**

### 2.3 Teacher `_QuickActionsSection` — same shape

`teacher_dashboard_screen.dart:312-344`: `AksharaSectionHeader('Quick Actions')`
+ `AksharaQuickActionGrid(children: [...for actions])`, no empty guard. The
mock always supplies four actions, so this is invisible until the backend
returns an empty list. **WIDGET-004** (same entry).

### 2.4 `ExamReminderCard` — a card about an exam that does not exist

`student_dashboard_screen.dart:152` renders `ExamReminderCard` unconditionally,
and `exam_reminder_card.dart` has **no empty guard**. `StudentDashboardData.empty()`
supplies `ExamReminder(id:'', title:'', subject:'', dateLabel:'', daysUntil:0)`.
A brand-new student therefore sees a full secondary-tinted card with a calendar
icon, an **"Exam"** badge, the text **"In 0 days"**, and three blank lines — and
tapping it fires `'exam_'`. The card asserts an exam is 0 days away. **WIDGET-005.**

### 2.5 `AksharaAiSuggestionBar` — a premium gradient card that says nothing

`akshara_ai_suggestion_bar.dart` has no empty-message guard. On the **student**
dashboard (`student_dashboard_screen.dart:200`) and the **teacher** dashboard
(`teacher_dashboard_screen.dart:189`) it is rendered unconditionally. With
`.empty()`'s `StudentAiInsight(message:'', actionLabel:'')`, the student sees the
brand-gradient bar with a sparkle icon, the eyebrow **"AKSHARA SUGGESTS"**, a
blank message line, and — because `actionLabel` is `''` and not `null`
(line 114 checks `!= null`, not `.isNotEmpty`) — a **blank action button**.
The **parent** dashboard guards it correctly (`parent_dashboard_screen.dart:174`,
`if (data.aiInsight.message.isNotEmpty)`), which proves the guard is understood
and was simply not applied to the other two. **WIDGET-006.**

### 2.6 Director dashboard — empty state explicitly disabled

`director_dashboard_screen.dart:41` passes
`resolveErpAsync(state, isDataEmpty: (_) => false)` — the empty branch is
**turned off by construction**, so `emptyMessage: 'No dashboard data available.'`
on the very next line is dead. A director with zero schools onboarded gets
`DirectorKpiRow(kpis: [])`, then the header **"School portfolio health"**, then
zero cards, then the executive summary. **WIDGET-007.**

## 3. Placeholder feel — widgets that read as scaffolding

### 3.1 Nine dashboards ship filter chips that filter nothing

The most systemic finding in this workstream. Every admin module dashboard
renders a prominent filter chip row. Verified by checking whether the data
fetch **watches** the filter state:

| Dashboard | Chips it offers | Fetch watches the filter? |
|---|---|---|
| Management | `FY 2026-27` · `Q1` · `All quarters` | **YES** — `managementDashboardQueryProvider` maps to `period`/`quarter` params (`management_providers.dart:16-25`) |
| Finance | `This month` · `All classes` · `All modes` | **NO** |
| SIS | `2026–27` · `All classes` · `All statuses` | **NO** |
| HR | `All departments` · `Academics` · `Administration` | **NO** |
| Admissions | `This month` · `All counselors` · `All sources` | **NO** |
| Transport | `AM shift` · `PM shift` · `All shifts` | **NO** |
| Library | `This week` · `This month` · `All time` | **NO** |
| Hostel | `Block A` · `Block B` · `All blocks` | **NO** |
| Inventory | `All departments` · `IT` · `Hostel` · `Science` | **NO** |
| Alumni | `All batches` · `2024–25` · `2022–23` | **NO** |

In all nine "NO" rows the `*DashboardFilterProvider` is read **only** by the
screen, to paint which chip looks selected; the `*DashboardFutureProvider` calls
`getDashboard(query: ref.watch(repositoryQueryProvider))` — the unfiltered
base query. A user taps **"This month"**, the chip highlights, the numbers do
not change, and nothing tells them why. Management proves the wiring is a
one-provider change, so this is drift, not a design decision. **WIDGET-008 (P1).**

Two of those rows have a second problem. **The chip labels are hard-coded
constants with no relationship to the tenant**: a school whose hostel has five
blocks is offered `Block A` and `Block B`; a school whose stores are organised by
subject is offered `IT / Hostel / Science`; an alumni office is offered the
batches `2024–25` and `2022–23` and no others; SIS offers the single academic
year `2026–27`. **WIDGET-009 (P2).**

Third problem, on Finance and SIS and Admissions: the three chips are a
**single-select group spanning three different dimensions**. Selecting "All
classes" necessarily deselects "This month". Even fully wired, the control
cannot express "this month AND all classes". **WIDGET-010 (P2).**

### 3.2 The principal's School Health Score is computed from hard-coded fallbacks

`management_principal_overview_panel.dart:24-39`:

```dart
final feeRate = int.tryParse(
      data.feeSnapshot.collectionRate.replaceAll(RegExp(r'[^0-9]'), '')) ?? 68;
final margin  = int.tryParse(
      data.kpis.where((k) => k.id == 'net_margin')...?.replaceAll(...) ?? '31') ?? 31;
return ((feeRate * 0.55) + (margin * 0.45)).round().clamp(0, 100);
```

Rendered as a large premium progress ring labelled **"School health score"** with
the subtitle **"Blends fee collection and margin trends"**.

- On a school with no fee data (`collectionRate` = `''`, `'—'`, `'N/A'`),
  `feeRate` falls back to the literal **68**.
- A school that does not use the finance-intelligence module has **no
  `net_margin` KPI at all**, so `margin` is *always* the literal **31**.
- Both together give `(68×0.55)+(31×0.45) = 51`. A brand-new school with zero
  data is shown **"School health score 51 / Blends fee collection and margin
  trends"** — a number derived entirely from two constants in the widget.
- The parse is `replaceAll(non-digits)` over a **money-or-percent string**. If
  the backend returns `collectionRate` as an amount (`₹12,45,000`) rather than a
  percentage, `feeRate` becomes `1245000` and the score pegs at **100**.
- The weights 0.55 / 0.45 appear nowhere else, are undocumented, and are not
  configurable.

A single headline number about a school's health, derived from finance figures,
computed in a widget from undocumented weights over hard-coded defaults.
**WIDGET-011 (P0** under the standing rule — a fabricated financial claim the
owner cannot check from the screen showing it**).**

### 3.3 The same sentence, twice, on one screen

`data.aiInsight` renders in **two** places on the management dashboard:

1. as an amber `AksharaWarningBanner` inside "Alert center"
   (`management_principal_overview_panel.dart:219-220` pushes `aiInsight` into
   `_alerts`), with a **"Review"** button hard-wired to `/management/approvals`;
2. as `AksharaInsightCard` at the bottom (`management_dashboard_screen.dart:257-263`),
   with a **"View approvals"** button, also hard-wired to `/management/approvals`.

An insight about fee collection is therefore shown twice, both times styled as
something to approve. `dai_brief.dart:14-19` refused to surface the morning brief
specifically because it would be a *third* copy of "what matters today" on this
screen — the second copy is already there. **WIDGET-012 (P2).**

Pending approvals fare no better: they appear in `_priorities` (top 3, as
"Approve X · ₹Y" cards), in `_alerts` ("N items waiting in approval queue", only
above 5), and in `_ApprovalQueuePreview` (top 5, as a table). Up to three
representations of one queue on one scroll. **WIDGET-012** (same entry).

### 3.4 Hard-coded severity thresholds

`defaulters > 40` gates the fee warning banner on **both** the management
dashboard (`management_dashboard_screen.dart:149,156`) and the finance dashboard
(`finance_dashboard_screen.dart:69,76`); `defaulters > 20` gates the Alert-Centre
version (`management_principal_overview_panel.dart:211`); `approvalQueue.length > 5`
gates the approvals alert (`:216`). All four are absolute counts.

A 200-student school with 38 defaulters — nearly a fifth of its roll — is told
nothing. A 3,000-student school with 41 is escalated. And because the two fee
thresholds differ (20 vs 40), a school with 25 defaulters sees the Alert-Centre
banner but **not** the dashboard banner, on the same screen, about the same fact.
**WIDGET-013 (P2).**

### 3.5 Dead dashboard widgets still in the tree

`FEATURE_INVENTORY.md` §M28 lists three dashboard widget files with no reachable
entry point, all still shipping in the release build:

- `lib/features/parent/dashboard/widgets/hero_card.dart` (158 lines)
- `lib/features/teacher/dashboard/widgets/greeting_header.dart`
- `lib/features/student_app/dashboard/widgets/hero_greeting_card.dart`

All three are superseded by `AksharaGradientHero`. Also dead per M28 and
dashboard-adjacent: `lib/features/student_health/care_alert/care_alert_widget.dart`
— a teacher-facing care alert bound to a **live** backend endpoint
(`GET /student-health/care-alerts`) with **no rendering site anywhere**. That is
the inverse of a placeholder: a real data source with no widget. **WIDGET-015 (P2).**

## 4. Per-widget certification results

### 4.1 Parent dashboard (`/parent/dashboard`)

| Widget | Data | Refresh | Empty | Loading | Verdict |
|---|---|---|---|---|---|
| `AksharaGradientHero` + `_SchoolBadge` | greeting/chips | pull-to-refresh ok | n/a | **mock** | **WIDGET-001** — greets "Ravi Kumar" |
| `_ChildSummaryKpiRow` | derived | ok | `'—'` fallback, honest | **mock** | **WIDGET-016** — homework KPI is wrong (below) |
| `ParentReminderBanners` | real modules | ok | self-hides | own async | **PASS** |
| `AdaptivePriorityFeedSection` | backend | ok | self-hides | self-hides | PASS with a caveat (§5) |
| `AksharaSurfaceListTile` ×4 (Action Needed / My Children / Experience Hub / Parent Insights) | static entry points | n/a | n/a | n/a | PASS — legitimately static navigation |
| `_AcademicHeroCard` | `parentAcademicSummaryProvider` | own retry | `'—'` → **ring renders 0%** | `SizedBox.shrink()` | **WIDGET-017** |
| `AksharaAiSuggestionBar` | `data.aiInsight` | ok | **guarded** ✓ | **mock** | WIDGET-001 |
| `AksharaQuickActionGrid` | `data.quickActions` | ok | grid collapses (ungated but unheaded) | **mock** | acceptable |
| `_TodaySummarySection` | `data.todaySummary` | ok | **headed hole** | **mock** | **WIDGET-004** |
| `NoticeCarousel` | `data.notices` | ok | proper | **mock** | PASS (empty state) |
| `EventCardList` | `data.events` | ok | proper | **mock** | PASS (empty state) |

**WIDGET-016** — `_ChildSummaryKpiRow` (`parent_dashboard_screen.dart:314-315`)
computes the "Homework pending" KPI as
`todaySummary.where((t) => t.id.contains('homework')).length` — the number of
*summary rows whose id mentions homework*, which is 0 or 1. The mock's row reads
"2 homework due today" and the KPI beside it reads **1**. Two numbers about the
same fact, both on screen, disagreeing. The attendance and fees KPIs on the same
row are scraped by substring from chip **labels**
(`c.label.toLowerCase().contains('attendance')`), so a re-worded chip silently
turns those cards into `'—'`.

**WIDGET-017** — `_AcademicHeroCard` (`:374-378`) does
`attendance = summary.attendanceSummary['ratePercent'] ?? '—'` and then
`attendanceFraction = (double.tryParse('$attendance') ?? 0) / 100.0`. When the
value is missing, the `AksharaProgressRing` renders an **empty ring at 0%** with
the caption **"—%" / "Present"** and the semantic label reads
*"Attendance — percent"*. A 0%-filled ring is a strong visual claim of near-zero
attendance; the correct rendering for "not computed yet" is not a zero-valued
gauge. Same pattern for `Grade '—'` and `Homework '—%'`, and the homework
`LinearProgressIndicator` sits at 0.

### 4.2 Teacher dashboard (`/teacher/dashboard`)

| Widget | Data | Empty | Loading | Verdict |
|---|---|---|---|---|
| `AksharaGradientHero` | greeting | n/a | **mock** | **WIDGET-002** — "Good morning, Priya" |
| `AttendanceSummaryCard` / `_StaffCheckInCard` | check-in + class attendance | n/a | **mock** | **WIDGET-002** — asserts "9:02 AM · Geo+Face verified" |
| `CoverAlertCard` | own provider | self-hides | own async | **PASS** |
| `TodayScheduleCard` | `todaySchedule` | proper | **mock** | PASS (empty state) |
| `_StudentsNeedingAttentionSection` | risk + pending | self-hides | **mock** | PASS (empty state) |
| `AdaptivePriorityFeedSection` | backend | self-hides | self-hides | PASS |
| `PendingTasksSection` | `pendingTasks` | proper | **mock** | PASS (empty state) |
| `_QuickActionsSection` | `quickActions` | **headed hole** | **mock** | **WIDGET-004** |
| `ClassTeacherCard` | `classTeacher` | `if (!= null)` ✓ | **mock** | PASS |
| `AksharaAiSuggestionBar` | `aiInsight` | **unguarded** | **mock** | **WIDGET-006** |

Ordering note: the teacher's most time-critical item — *"Attendance not marked
for Class 8-A · Period 1"* — sits inside `_StudentsNeedingAttentionSection`,
**below** today's schedule and above the AI feed, while the staff check-in card
(a once-a-day action) is pinned at the very top. The one action with a bell
attached is the third thing on the screen. Recorded as an ordering observation,
not a defect — see §6.

### 4.3 Student dashboard (`/student/dashboard`)

The **only** persona dashboard with a correct async contract. `.empty()`,
`|| async.isLoading`, `|| async.hasError`, `async.hasValue` guards on the app-bar
chip and the notification badge (`:50,57`) so a stale badge never shows during
load. This is the pattern the other two owe.

| Widget | Empty | Verdict |
|---|---|---|
| `AksharaGradientHero` | greeting from `.empty()` | PASS |
| `DailyScheduleStrip` | proper | PASS |
| `AksharaQuickActionRow` | collapses (ungated, unheaded) | acceptable |
| `_StatusKpiRow` (`AttendanceKpiCard` + `HomeworkCountKpiCard`) | 0-valued | acceptable — a real 0 |
| `AdaptivePriorityFeedSection` | self-hides | PASS |
| `ExamReminderCard` | **none** | **WIDGET-005** |
| `HomeworkDueList` | proper | PASS |
| `AksharaAiSuggestionBar` | **none** | **WIDGET-006** |

### 4.4 Principal / management dashboard (`/management/dashboard`)

| Widget | Empty | Verdict |
|---|---|---|
| `_HealthScoreCard` | falls back to 68/31 → **51** | **WIDGET-011 (P0)** |
| `_SummaryStrip` (3 `AksharaKpiCard`) | 0-valued | **WIDGET-018** — "At-risk fees" shows a *student count* |
| `_priorities` (top-3 approvals + defaulters) | `if (isNotEmpty)` ✓ | PASS, but duplicated (WIDGET-012) |
| `AdaptivePriorityFeedSection` | self-hides | PASS |
| `AksharaQuickActionGrid` (4 static) | static | PASS |
| `_alerts` (Alert center) | `if (isNotEmpty)` ✓ | **WIDGET-012 / WIDGET-013** |
| fee `AksharaWarningBanner` | `> 40` | **WIDGET-013** |
| `ManagementKpiRow` | collapses | acceptable |
| `ManagementTrendChart` | proper empty state | **PASS** |
| `ManagementSegmentPanel` | **blank 240–320px box** | **WIDGET-003** |
| `_AttendancePendingWidget` | full loading / error / ok / warn | **PASS — best widget in this workstream** |
| School calendar tile | RBAC-gated, static | PASS |
| `_ApprovalQueuePreview` | naked sentence | **WIDGET-014** |
| `_AdmissionsSnapshotCard` / `_FeeSnapshotCard` | 0-valued | PASS |
| `AksharaInsightCard` | `actionLabel.isEmpty → null` ✓, message unguarded | **WIDGET-006 / WIDGET-012** |

`_AttendancePendingWidget` (`management_dashboard_screen.dart:273-329`) is worth
naming as the standard: it handles loading ("Checking attendance…" with a
spinner), error ("Attendance status unavailable"), the good state ("All classes
have submitted attendance today.") **and** the bad state with correct
singular/plural. Every other widget in this workstream should be measured
against it.

**WIDGET-018** — `_SummaryStrip` (`:311-318`) renders
`value: '${data.feeSnapshot.defaulters}'` under the subtitle **"At-risk fees"**.
The value is a count of students; the label names money. Beside it sits
"Fee collection" showing a percentage. Three tiles, three different units, one
of them mislabelled.

### 4.5 Director dashboard (`/director/dashboard`)

| Widget | Empty | Verdict |
|---|---|---|
| `DirectorKpiRow` | collapses | acceptable |
| "School portfolio health" + `_SchoolHealthCard` list | **headed hole**, empty branch disabled | **WIDGET-007** |
| `AdaptivePriorityFeedSection` | self-hides | PASS |
| `DirectorExecutiveSummaryCard` | not verified in depth | — |

`_filters = ['All schools', 'Region', 'Quarter']` — same dead-chip pattern; the
labels are not even values ("Region" and "Quarter" name a *dimension*, not a
selection). **WIDGET-008 / WIDGET-009.**

### 4.6 Module dashboards — summary

Finance is the best of them (real empty states on the trend chart, the payments
table and the handoff queue, with an explicit day-one comment in the source) and
still ships three dead filter chips. SIS, HR, Admissions, Transport, Library,
Hostel, Inventory, Alumni and Control Center all carry the dead-chip defect;
`grep -c isEmpty` over their screen files returns **0** for eight of the ten,
so their headed sections were not audited for day-one emptiness during the RC
sweep and were not audited exhaustively here either — stated as a boundary
rather than implied as a pass. HR additionally carries **CERT-006** (a
hard-coded `'142 active staff · 96.2% attendance MTD'` headline), already
recorded.

## 5. Widgets bound to a DEAD or HIDDEN source

Cross-checked against `FEATURE_INVENTORY.md`:

- **`care_alert_widget.dart`** — live endpoint, no rendering site. **WIDGET-015.**
- **`hero_card.dart`, `greeting_header.dart`, `hero_greeting_card.dart`** — dead
  dashboard widgets still compiled into the release. **WIDGET-015.**
- **`AdaptivePriorityFeedSection`** — source is LIVE (`ADAPTIVE_AI_ENABLED=true`),
  but the widget renders `SizedBox.shrink()` on **loading and error as well as
  empty** (`orElse:` at `adaptive_priority_feed.dart:49`). A principal whose
  priority feed failed cannot distinguish "the AI has nothing for you" from "the
  AI did not answer". For a self-hiding section that is a defensible trade, but
  it means the feed can never report its own failure. Recorded as an observation,
  not a defect.
- No dashboard widget was found bound to a MOCK-in-release repository: the 18
  providers without a `live_release.json` key back verticals, franchise, branch
  and white-label surfaces, all of which are HIDDEN and none of which render on a
  persona dashboard.

## 6. Ordering, usefulness and wording — observations short of defects

Recorded for the remediation roadmap; none is individually release-blocking.

- **Parent dashboard is long.** Hero → KPI row → reminders → AI feed → Action
  Needed → (My Children) → academic card → Experience Hub → Parent Insights →
  AI bar → quick actions → Today → Notices → Events. Four separate "here is what
  matters" surfaces (reminders, AI feed, Action Needed, Today) before the parent
  reaches today's actual schedule.
- **Teacher ordering** puts a once-daily check-in above the "attendance not
  marked" alert (§4.2).
- **"AKSHARA SUGGESTS"** is the eyebrow on every AI bar
  (`akshara_ai_suggestion_bar.dart:16`) while the app is renaming to **NIKSHA OS**.
  A user-visible string carrying the old brand.
- **`AksharaInsightCard` action labels are hard-coded per screen** —
  "View approvals" on management, "Review defaulters" on finance — regardless of
  what the insight says. Folded into WIDGET-012.
- **`filterLabels[0] = 'FY 2026-27'`** on management is a hard-coded fiscal year
  that will be wrong in April 2027, and it is passed verbatim into the Copilot
  context (`management_dashboard_screen.dart:140`), so the AI assistant is told
  the period is FY 2026-27 whatever the tenant's year. Folded into WIDGET-009.
- **`_ApprovalQueuePreview`'s empty state** is a bare grey sentence with no icon
  or frame, directly under a section header, while every other empty state in
  the product uses `AksharaEmptyState`. **WIDGET-014 (P3).**

## 7. What is genuinely good

- **`_AttendancePendingWidget`** — the complete four-state widget (§4.4).
- **The student dashboard's async contract** — `.empty()`, real loading, real
  error, `hasValue`-gated app-bar chrome. It is the fix for WIDGET-001/002,
  already written and shipping ten metres away.
- **Finance's day-one work** — three real empty states, one with a source comment
  explaining *why* ("No payments is a real day-one state, not a rendering
  failure").
- **`FinanceCollectionTrendChart`** — suppresses the legend and the fixed height
  as well as the plot when empty, which is what stops it becoming
  `ManagementSegmentPanel`.
- **`AdaptivePriorityFeedSection`, `CoverAlertCard`, `ParentReminderBanners`** —
  all three self-hide rather than render a titled void.
- **RBAC and capability gating on dashboard entry points** (school calendar tile,
  `AksharaManageAction` on Export) is applied consistently.

The RC-phase empty-state work was real and it held. What it did not reach is a
short, enumerable list — one panel, three headed sections, one card and one bar —
and the two async-contract regressions in §1, which are a different class of
problem and the reason this workstream does not certify.
