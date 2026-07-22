# UXR — Teacher Journey Log (Design System V2, Phase 4 module migration)

Presentation-only migration of the **teacher module screens**
(`lib/features/teacher/**`) to the DS V2 flagship look: the persona **premium
canvas** (`AksharaPremiumBackground`, teacher **indigo** accent `#6366F1`) behind
every screen, and the signature **`AksharaProgressRing`** wherever a screen has a
natural headline **percentage** metric. One screen (or tight cluster) per
independently certified commit. The teacher **dashboard** was already migrated in
Phase 3 (present-rate ring) and is out of scope here; the **conversation** (chat)
screen intentionally stays plain (a canvas hurts pale chat-bubble contrast — the
same call the parent/student lanes made).

Branch: `worktree-agent-abc831d856fcfc205` (branched from the tip of
`feature/uxr-flutter-remediation` — see base-correction note below).

Goldens: all teacher module goldens live in the single new file
`test/golden/ds_v2_flagship_teacher_modules_golden_test.dart` (teacher persona
theme, Light + Dark, tall `390x1280`). Each PNG was visually confirmed premium and
overflow-free before locking.

## Base-correction note
The isolation worktree was initially branched from the wrong lineage — the Jul-20
backend/ICA freeze commit `a806ee2c`, which lacks every DS V2 prerequisite
(`akshara_progress_ring.dart`, the premium-background barrel export,
`persona_accents.dart`). Caught **before any commits, tree clean**; re-pointed the
worktree branch onto the correct uxr tip (`19c47710`) with `git reset --hard`
(own branch only — no switch/merge). All slices below sit on that correct lineage;
`19c47710` is the current uxr tip, so they merge cleanly.

## Slices

| # | Screen(s) | Change | Ring? | Verification | Commit |
|---|-----------|--------|-------|--------------|--------|
| 1 | Attendance marking (TA-02) + My Attendance (TCH-9) | Premium canvas on all states of both; My Attendance gains a signature month attendance-rate ring above the count chips | Marking: **No** (live present/absent/late are counts). My Attendance: **Yes** — monthly rate (present+late over working days) | analyze clean; attendance suite + tch_client_wiring + class-scope + module-screens **+55**; goldens 4 | `c0c4e9ce` |
| 2 | Homework Review (TA-04) + Create (HWK) + History (HWK-5) | Premium canvas on all states of the review queue, the create form, and the history list | **No** — review KPIs are honest counts (Pending review / Submissions); create is a form; history is a list | analyze clean; homework suite + homework_review_loop + module-screens **+22**; goldens 6 | `72eef45f` |
| 3 | Exams (TA-05) | Premium canvas + the three-up KPI strip restructured into a premium `_ExamsSummaryCard` — class-average % ring with Upcoming + Pending-marks adjacent stats (same three metrics) | **Yes** — class-average % (mirrors the student exams card) | analyze clean; exams suite + marks-submit + exam-admin-chain + module-screens **+41**; goldens 2 | `185629a2` |
| 4 | Weekly Timetable (TA-03) + Today's classes (TCH-1/TCH-4) | Premium canvas on all states of both (dropped a now-unused import on the timetable screen) | **No** — period lists / counts, no headline % | analyze clean; timetable suite + today-schedule + tch1/3/4 + module-screens **+18**; goldens 4 | `0cfaae00` |
| 5 | My Leave (TA-07) + Student Leave Approvals | Premium canvas on all states of the leave balance/history and the class-teacher approval list | **No** — leave balances are day counts (Casual/Sick/Earned); approvals is a list | analyze clean; leave suite + leave-approvals + module-screens **+22**; goldens 4 | `18502c45` |
| 6 | Parent Communication (workflow) + Messages inbox (TA-06) | Premium canvas on the communication workflow and the messages inbox/compose. **Conversation/chat left plain** (canvas hurts pale chat-bubble contrast). Also fixed a latent 6px horizontal overflow on the "Select student" dropdown (`isExpanded` + item ellipsis, matching the homework dropdown) surfaced by the golden | **No** — form / list, no headline % | analyze clean; communication + messages suites + governance + module-screens **+30**; goldens 4 | `b944922e` |
| 7 | Student Risk 360 | Premium canvas behind the risk 360 detail | **No** — see ring decision below | analyze clean; qw5 intervention authz **+3**; goldens 2 (`SIS-STU-10421`) | `eb42a520` |
| 8 | Profile + Settings | Premium canvas behind the identity/detail profile and the preferences list (dropped a now-unused import on settings) | **No** — identity / preferences, no headline % | analyze clean; profile + settings screen tests **+5**; goldens 4 | `46d55f15` |
| 9 | Class-teacher Dashboard (TA-01 variant) | Premium canvas (with the book motif, matching the main teacher dashboard) behind the class-teacher overview; added a `SingleChildScrollView` so the canvas fills + the dashboard is overflow-safe (dropped a now-unused import) | **No** — a navigation/quick-actions overview, no headline % (the main teacher dashboard already carries the present-rate ring, Phase 3) | analyze clean; navigation-pilot + persona-nav-map **+71**; goldens 2 | `<pending>` |

**Total: 16 screens migrated** across 9 certified slices — attendance marking,
my-attendance (ring), homework review/create/history, exams (ring), timetable,
today, my-leave, leave-approvals, parent-communication, messages inbox, student
risk, profile, settings, class-teacher dashboard. **2 signature rings** added
(my-attendance rate + exams class-average). The **conversation/chat** screen was
deliberately left plain, and the **teacher dashboard** was already done in Phase 3.
Golden file: **32 goldens** (16 screens × Light+Dark).

## Ring decisions (honest-state)
- **My Attendance** monthly rate → ring. Derived only from data already loaded
  (`presentDays + lateDays` over `workingDaysInMonth`); reads a healthy ~85–90% in
  the demo month. The four count chips (Present / Late / Absent / Avg hours) are
  kept **unchanged** below the ring as the raw breakdown — so `find.text('Avg
  hours')` / `'Present'` assertions stay green and no info is lost. The ring
  contextualises the rate; it does not duplicate the chips.
- **Attendance marking** headline is the live **counts** tally
  ("N present · M absent · K late") — not a %, so no ring (rule: counts stay
  counts). Canvas cohesion only; the submit gate / summary bar / bulk-mark / fill-
  remaining / search / correction flows and every `QaTestKeys.teacherAttendance*`
  are preserved.
- **Exams** class-average % → ring (mirrors the student exams card). Reads a real
  non-zero class average in the demo (marks settle), and the arc is honest.
- **Student Risk 360** → **no ring**. The screen's headline is a **categorical
  risk LEVEL** (low/medium/high — `riskLevel.name`), not a percentage; a progress
  ring encodes a 0..1 value, so forcing one onto a category would misread. The
  attendance-% and homework-completion-% are secondary detail *rows*, not a single
  headline metric — so the honest call is canvas cohesion only, no ring.
- **Homework / Timetable / Today / Leave / Communication / Messages / Profile /
  Settings / Class-teacher dashboard** — honest counts, lists, forms, or
  navigation overviews with no headline %; canvas cohesion only, per the
  "don't force a ring" rule.

## Preserved (presentation-only)
Navigation, workflows, providers, honest-state messaging, `QaTestKeys`,
semantics/a11y, 48dp targets, responsive behavior, and every asserted widget
type/text. No parent (`lib/features/parent/**`), student (`lib/features/student_app/**`),
management, theme, or shared widget file was touched.

## Shared-file changes needed (deliberately NOT made)
None. Every ring/canvas reuses the existing shared primitives
(`AksharaProgressRing`, `AksharaPremiumBackground`, `AksharaPersonaAccent.teacher`) —
no `lib/shared/**`, theme, `lib/features/parent/**`, `lib/features/student_app/**`,
or `lib/features/management/**` file was touched. The two small latent-bug fixes
(the communication dropdown overflow, and the class-teacher dashboard scroll/
overflow-safety) live entirely inside teacher-owned files.
