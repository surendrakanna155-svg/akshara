# UXR — Student Journey Log (Design System V2, Phase 4 module migration)

Presentation-only migration of the **student module screens**
(`lib/features/student_app/**`) to the DS V2 flagship look: the persona **premium
canvas** (`AksharaPremiumBackground`, emerald student accent) behind every screen,
and the signature **`AksharaProgressRing`** wherever a screen has a natural
headline **percentage** metric. One screen (or tight cluster) per independently
certified commit. The student **dashboard** was already migrated in Phase 3 and is
out of scope here.

Branch: `worktree-agent-a6f906daace262087` (branched from the tip of
`feature/uxr-flutter-remediation` — see base-correction note below).

Goldens: all student module goldens live in the single new file
`test/golden/ds_v2_flagship_student_modules_golden_test.dart` (student persona
theme, Light + Dark, tall `390x1280`). Each PNG was visually confirmed premium and
overflow-free before locking.

## Base-correction note
The isolation worktree was initially branched from the wrong lineage — the Jul-20
backend/ICA freeze commit `a806ee2c`, which lacks every DS V2 prerequisite
(`akshara_progress_ring.dart`, the premium-background barrel export,
`persona_accents.dart`). Caught **before any commits, tree clean**; re-pointed the
worktree branch onto the correct uxr tip (`7e53b5df`) with `git reset --hard`
(own branch only — no switch/merge). All slices below sit on that correct lineage;
`7e53b5df` is an ancestor of the current uxr tip, so they merge cleanly.

## Slices

| # | Screen(s) | Change | Ring? | Verification | Commit |
|---|-----------|--------|-------|--------------|--------|
| 1 | Attendance (ST-02) | Premium canvas on all 3 Scaffold states | Yes — inherited (shared `AttendanceKpiStrip` already a ring) | analyze clean; attendance widget + sync + qa_c_002 + module + resp/stress; golden 98 | `84bd25d3` |
| 2 | Homework (ST-04) | Premium canvas | No — 3 honest counts, no headline % | analyze clean; homework widget + provider + module + qa_c_002 + resp/stress; golden 100 | `ec9eb60c` |
| 3 | Exams (ST-05) | Premium canvas + restructured KPI strip → `_ExamsSummaryCard` with a class-average % ring + upcoming/results stats | Yes — class-average % | analyze clean; exams widget + provider + module + qa_c_002 segment cert + resp/stress; golden 102 | `37db15bb` |
| 4 | Timetable (ST-03) | Premium canvas on the state switch | No — period counts, no % | analyze clean; timetable provider + module + resp/stress; golden 104 | `75dbb484` |
| 5 | Notices (ST-06) + Profile (ST-07) | Premium canvas (notices ternary body; profile all 3 states) | No — counts / detail views | analyze clean; notices + profile providers + module + qa_c_002 + resp/stress; golden 108 | `f1b65589` |
| 6 | My Progress (ST-07) + Report Card (ST-06) | Premium canvas on both ListView bodies; dropped an unused import | No — see note | analyze clean; full student_app suite + report-card export + resp/stress; golden 112 | `f8eb77c1` |

Total: **8 screens** migrated (attendance, homework, exams, timetable, notices,
profile, progress, report card). Dashboard skipped (Phase 3). No screens needed a
redesign beyond canvas + ring.

## Ring decisions (honest-state)
- **Exams** class-average % → ring. Reads **0%** in the demo because the demo
  student has no published results yet (same value the old flat KPI card showed);
  the emerald arc fills once results land.
- **Report Card** keeps its `Average: X.X%` as **text** (no ring): the demo average
  is 0 until results publish, and a large 0% gauge on a *report card* would read as
  a zero-score. Candidate for a ring once real published data flows.
- **Homework / Timetable / Notices** headline tiles are honest **counts**, not
  percentages — canvas-cohesion only, per the "don't force a ring" rule.
- **My Progress** shows per-subject scores with no single headline metric card;
  canvas only. A student overall-average ring is a future candidate (would need a
  derived metric, so deferred to keep this pass presentation-only).

## Preserved (presentation-only)
Navigation, workflows, providers, honest-state messaging, `QaTestKeys`,
semantics/a11y, 48dp targets, responsive behavior, and every asserted widget
type/text. No parent (`lib/features/parent/**`) or shared file was touched.

## Shared-file changes needed (deliberately NOT made)
None. The student attendance ring came for free from the parent-owned
`AttendanceKpiStrip` (migrated in the parent lane), so no shared-widget change was
required.
