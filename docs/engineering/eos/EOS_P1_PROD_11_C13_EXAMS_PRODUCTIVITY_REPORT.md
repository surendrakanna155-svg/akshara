# EOS Report — P1-PROD-11 · C13 Academic-work productivity (Exams half)

- **Date:** 2026-07-06
- **Commit:** `0a8c2a3`
- **Scope:** FEATURE (Exams) — C13 Exams half (EXM-4, EXM-5, EXM-6, EXM-7). Homework half (HWK-3..8) deferred with C6.
- **Verdict:** **PASS** — exam-result governance intact; no automatic-failure condition.
- **Standard:** `docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md` (Part 7B / Part 8). Not restated here.

---

## 1. Method — discovery-first

A read-only discovery pass mapped the exams reports surface before writing. C4
had already built the tabulation foundation (present-only totals/%/rank/grade),
and the "Exam Reports" area already shipped merit/toppers, pass-fail, and
datesheet. Only the one genuine gap (EXM-6) was built.

## 2. Per-item outcome

| Item | Verdict | Evidence |
|---|---|---|
| **EXM-4** merit + subject topper | **Verified built** | `handleExamToppers`/`loadExamToppers` (`repository.ts:1103`), `handleMeritList`/`loadMeritList` (`:1185`, reuses the tabulation register, `rank != null`); client `_MeritToppersView` + CSV/PDF. Present-only. |
| **EXM-5** pass/fail + grade-distribution | **Verified built** | `handleExamDistribution`/`loadExamDistribution` (`repository.ts:1255`) → `passCount`/`failCount`/`gradeBreakdown`/`excludedCount`, present-only; client `_DistributionView` + export. |
| **EXM-6** deadline + teacher reminder | **Gap closed** (see §3) | deadline field + pending query existed; reminder was **not** wired. |
| **EXM-7** datesheet PDF | **Verified built** | `handleDatesheet`/`loadDatesheet` (`repository.ts:1361`); client `_DatesheetView` + CSV/PDF (distinct from EXM-3 hall tickets). |

**Noted, not a gap:** EXM-5's pass mark is hardcoded 40% (`DEFAULT_PASS_MARK_PERCENT`).
The report is complete; a *configurable* per-exam pass mark is a future config
item (the code is structured to read one when added). Not tracked as a wave gap.

## 3. EXM-6 — the first XCT-2 reminder-rail caller

**Before:** `exam_sessions.marks_entry_deadline` + a per-exam pending query
(`listMarksEntryProgress`) existed, but a grep for `scheduleReminder` returned
**zero** call sites — no reminder was ever raised, and the progress board did
not show the deadline.

**Built:**
- `listOverdueMarksEntry(asOf)` — exams in `marks_entry` phase whose deadline
  has passed (`marks_entry_deadline < asOf`) with marks still pending
  (`HAVING count > count FILTER (marks_entered)`).
- `handleRemindPendingMarks` (manageExams) — checks pending **at trigger time**
  so it never fires a false reminder, then schedules **one** in-app
  `all_teachers` reminder via the shared `scheduleReminder` rail. Recipients are
  resolved at fire time by the scheduled-broadcast runner
  (`POST /communications/broadcasts/run-scheduled`); delivery is in-app only
  (external channels stay owner-gated). Audited `exam.marks_reminder.sent`.
- Pure `buildMarksReminder` digest (subject · class · pending · due) — returns
  null when nothing is overdue (so nothing is scheduled). Unit-tested.
- Route `POST /academics/exams/marks/remind`, matched before the generic
  `/academics/exams/{examId}` matcher; route-contract RBAC verified.
- Client: the marks-progress board now surfaces the deadline + an "Overdue"
  badge (`MarksEntryProgress.isOverdue`), and a manageExams-gated "Remind
  teachers" action → count snackbar; repo interface/api/remote/mock + notifier.

**Design note:** the rail targets a broadcast *audience* (`all_teachers`), not an
individual, so the reminder is one digest to the teacher body naming the overdue
classes/subjects — consistent with how every other module rides XCT-2.

## 4. Regression evidence

- `flutter analyze` → **0 issues**.
- Full `flutter test` → **no NEW failures**; the 2 failing tests are the known
  UX-7 `TeacherDashboardScreen` 360×640 overflow pair (unrelated).
- `deno test` exam-administration → **124 / 0**; reminders + audit → **24 / 0**.
- `deno check` on all touched `supabase/functions/**` → green.
- New tests: **12** — EXM-6 digest builder ×4, route-contract ×2, `isOverdue`
  model ×4, progress-screen widget ×2.

## 5. Tripwire check

No automatic-failure condition: **no marks/results were mutated** (governance —
present-only exclusion of absent/ML/DB — untouched), the reminder itself is
audited, the route is RBAC-gated + route-contract-tested, and no new
scheduler/channel was introduced (rides the one XCT-2 rail). **PASS.**

## 6. Next

C14 — Teacher & Attendance productivity (TCH-1..4, ATT-3/4). TCH-2 can reuse the
EXM-6 marks-overdue signal. Homework half of C13 (HWK-3..8) stays deferred with
C6 pending the owner-approved HWK-1 migration.
