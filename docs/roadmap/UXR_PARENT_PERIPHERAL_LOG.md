# DS V2 P4 — Parent Peripheral Screens Canvas-Cohesion Pass

Branch: `worktree-agent-ad374e80581c28d0f` (based on `feature/uxr-flutter-remediation`
tip `ca9b8644`).

Scope: wrap the **peripheral** parent screens' bodies in the persona **premium
canvas** (`AksharaPremiumBackground(showMotif: false, ...)`) for whole-journey
cohesion — **presentation only**, one small committed batch at a time. The CORE
parent journey (fees/payment/receipts/attendance/homework/exams/report-card/
timetable/messages/academic-report) was already migrated and is NOT touched here.

The exact edit per screen (copied from the committed examples 27b17ee3 / f815c977 /
ca9b8644): `backgroundColor` → `Colors.transparent` (or add it if absent), wrap the
`body:` value in `AksharaPremiumBackground(showMotif: false, child: <body>)`, add a
one-line `// DS V2 P4` comment. No rings, no content/logic changes.

## Worktree base correction (pre-work)

This worktree branch was created from `a806ee2c` (a Jul-20 IMPLEMENTATION FREEZE
commit) instead of the tip of `feature/uxr-flutter-remediation`. That base had none
of the DS V2 P4 prerequisites (unmigrated core screens; `AksharaPremiumBackground`
not exported; `AksharaPersonaAccent` absent; golden helper absent) and was not even
an ancestor of the uxr branch. Since the branch had zero commits of its own and a
clean tree, it was `git reset --hard` onto `feature/uxr-flutter-remediation`
(`ca9b8644`) — staying on this worktree branch (no switch/merge/rebase). Confirmed
with the coordinator (`main`).

## Target screens (10 named)

| Screen | Status |
|---|---|
| `events/parent_events_screen.dart` | ✅ wrapped (batch 1) |
| `notices/parent_notices_screen.dart` | ✅ wrapped (batch 1) |
| `ptm/parent_ptm_screen.dart` | ✅ wrapped (batch 1) |
| `leave/parent_leave_screen.dart` | ✅ wrapped (batch 2) |
| `transport/parent_transport_screen.dart` | ✅ wrapped (batch 2) |
| `profile/parent_profile_screen.dart` | ✅ wrapped (batch 2) |
| `actions/parent_action_inbox_screen.dart` | ✅ wrapped (batch 3) |
| `family/parent_family_view_screen.dart` | ✅ wrapped (batch 3) |
| `experience/parent_experience_hub_screen.dart` | ✅ wrapped (batch 3) — added `backgroundColor: Colors.transparent` + a direct `premium/akshara_premium_background.dart` import (the `widgets.dart` barrel would make its existing direct `akshara_empty_state` import redundant); TabBarView body wrapped |
| `evolution/parent_insights_screen.dart` | ⛔ SKIPPED — does not exist. No `evolution/` dir and no `*insight*`/`*evolution*` Scaffold screen anywhere under `lib/features/parent`. Confirmed with coordinator: "Parent Insights" is a dashboard link, not a standalone Scaffold. Nothing to migrate. |

## Golden coverage

New file `test/golden/ds_v2_flagship_parent_peripheral_golden_test.dart` — modeled on
`ds_v2_flagship_parent_modules_golden_test.dart` (same helpers, parent persona theme,
tall `Size(390, 1280)`, Light + Dark). A screen is added only if it settles with
default test providers.

## Batches

### Batch 1 — events + notices + ptm
- **Commit:** (see git log — `feat(dsv2-p4-parent-peripheral-1)`)
- Wrapped: events, notices (both `isLoading ? ... : ...` ternary bodies), ptm
  (`ErpAsyncBody` body; Scaffold keeps its `QaTestKeys.parentPtmScreen`).
- analyze: clean. dart format: applied.
- Tests green: `parent_more_screens_test.dart` (events/notices/profile),
  `par_client_widget_test.dart` (ptm/family/actions), `qa_c_001_parent_app_behaviour_cert_test.dart`,
  `mobile_screen_responsiveness_test.dart` — +30 passed.
- Goldens: parent events / notices / ptm (Light + Dark), 6 PNGs generated and
  visually confirmed (canvas visible, no overflow); golden test +6 passed.

### Batch 2 — leave + transport + profile
- **Commit:** (see git log — `feat(dsv2-p4-parent-peripheral-2)`)
- Wrapped: leave (`isLoading ? ...` ternary; draft-autosave form + timeline
  preserved), transport (`ErpAsyncBody`; keeps `QaTestKeys.parentTransportScreen`),
  profile (`isLoading ? ...` ternary; hero + contact/children/legal/logout preserved,
  `QaTestKeys.logoutButton` untouched).
- analyze: clean. dart format: applied.
- Tests green: `parent_fees_flow_screens_test.dart` (leave),
  `transport/qw5_parent_transport_view_test.dart` (transport),
  `parent_more_screens_test.dart` (profile), cert + responsiveness — +30 passed.
- Goldens: parent leave / transport / profile (Light + Dark), 6 PNGs generated and
  visually confirmed (canvas visible, no overflow); full peripheral golden +12 passed.

### Batch 3 — action inbox + family view + experience hub
- **Commit:** (see git log — `feat(dsv2-p4-parent-peripheral-3)`)
- Wrapped: action inbox (`actions.isEmpty ? ...` ternary; keeps
  `QaTestKeys.parentActionInboxScreen`), family view (`children.isEmpty ? ...`
  ternary; keeps `QaTestKeys.parentFamilyViewScreen`), experience hub (plain
  Material `AppBar` + `TabBar`/`TabBarView`; needed `backgroundColor:
  Colors.transparent` added after `return Scaffold(` and a direct import of
  `shared/widgets/premium/akshara_premium_background.dart` — it does not import the
  `widgets.dart` barrel, and adding the barrel would make its existing direct
  `akshara_empty_state.dart` import redundant).
- `AksharaPremiumBackground` is a loose `Stack` (child sizes it, bounded maxHeight
  preserved), so the experience hub's `TabBarView` body lays out correctly.
- analyze: clean. dart format: applied.
- Tests green: `par_client_widget_test.dart` (actions PAR-D4 + family PAR-D2),
  cert + responsiveness — +24 passed. Experience hub has no widget test in the repo;
  it is covered by the new golden + analyze.
- Goldens: parent action inbox / family view / experience hub (Light + Dark), 6 PNGs
  generated and visually confirmed (canvas visible, no overflow; experience hub
  renders real Overview-tab data). Full peripheral golden +18 passed.

## Result

All 9 existing peripheral parent screens wrapped in the persona premium canvas
across 3 committed batches. The 10th named target (`evolution/parent_insights_screen`)
does not exist and was skipped. No navigation / provider / business-logic /
honest-state / QaTestKeys / semantics / touch-target changes — presentation only.
New golden file `test/golden/ds_v2_flagship_parent_peripheral_golden_test.dart`
(18 goldens, Light + Dark) all green.
