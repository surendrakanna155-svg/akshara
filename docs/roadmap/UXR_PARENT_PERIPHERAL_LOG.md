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
| `leave/parent_leave_screen.dart` | ⏳ pending |
| `transport/parent_transport_screen.dart` | ⏳ pending |
| `profile/parent_profile_screen.dart` | ⏳ pending |
| `actions/parent_action_inbox_screen.dart` | ⏳ pending |
| `family/parent_family_view_screen.dart` | ⏳ pending |
| `experience/parent_experience_hub_screen.dart` | ⏳ pending (no `backgroundColor` line + no `widgets.dart` import — needs both added) |
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
