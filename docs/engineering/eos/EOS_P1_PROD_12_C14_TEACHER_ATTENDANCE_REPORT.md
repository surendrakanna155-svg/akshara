# EOS Report — P1-PROD-12 · C14 Teacher & Attendance productivity

- **Date:** 2026-07-06
- **Commit:** `9e5602a`
- **Scope:** FEATURE (Teacher/Attendance) — C14 (TCH-1, TCH-2, TCH-3, TCH-4, ATT-3, ATT-4)
- **Verdict:** **PASS** — attendance integrity intact; no automatic-failure condition.
- **Standard:** `docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md` (Part 7B / Part 8). Not restated here.

---

## 1. Method — discovery-first

A read-only discovery pass mapped the teacher workspace + attendance surfaces
before writing. Three of the six items were already complete; only the three
genuine gaps were closed, all client-only.

## 2. Per-item outcome

| Item | Verdict | Evidence |
|---|---|---|
| **TCH-4** cover alert + weekly timetable | **Verified built** | `TeacherTimetableScreen`; `CoverAlertCard` + `teacherTodayCoverProvider` over `daily_substitutions` (migration `20260845000000`). |
| **ATT-3** absentees-only fast-mark | **Verified built** | `fillRemainingAsPresent` + "Fill remaining present" (`teacher_attendance_screen.dart:304`). |
| **ATT-4** office not-yet-marked monitor | **Verified built** | `/attendance/pending` → `handleAttendancePending` / `attendance_office_repository`; `_PendingTab` (Draft/Missing per class+date). |
| **TCH-1** schedule-row → mark attendance | **Gap closed** | see §3. |
| **TCH-2** marks-pending/deadline on home | **Gap closed** | see §3. |
| **TCH-3** my-class summary export | **Gap closed** | see §3. |

## 3. Gaps closed (client-only)

- **TCH-1** — the primary teacher-home today-schedule row tapped through to the
  *weekly timetable*, not attendance. Added a dedicated
  `schedule_attendance_<classLabel>` action resolving to
  `teacherAttendance?class=<label>` (the attendance screen already honoured the
  `?class=` preselect). The pending-banner's `mark_attendance_<pendingClassId>`
  path was deliberately left untouched — its suffix is a pendingClassId, not a
  class label, so overloading the same branch would have mis-preselected.
- **TCH-2** — the home "Marks to enter" tile was a raw count that ignored the
  deadline. It now reuses the EXM-6 `MarksEntryProgress.isOverdue` signal to draw
  an urgent (error) tone + "Marks overdue" label once any exam is past its
  marks-entry deadline (`PendingTask.overdue`).
- **TCH-3** — added a my-class marks-summary export
  (Class/Subject/Entered/Total/Pending/Status, Status ∈ Complete/Pending/Overdue)
  on the shared XCT-1 grid pipeline (`TeacherReportExporters`), surfaced as an
  export action on the teacher exams screen.

## 4. Regression evidence

- `flutter analyze` → **0 issues**.
- Full `flutter test` → **no NEW failures**; the 2 failing tests are the known
  UX-7 `TeacherDashboardScreen` 360×640 overflow pair (unrelated).
- **Teacher-dashboard golden UNCHANGED** — the demo marks-entry data has no past
  deadline, so TCH-2's overdue styling does not trigger, and TCH-1 is
  navigation-only; no pixel delta.
- Client-only — **no `supabase/functions/**`** touched, so no deno leg.
- New tests: **4** — TCH-1 nav route + `?class=` param, TCH-2 overdue-tone
  widget, TCH-3 `marksSummaryRows` status unit + export-button render.

## 5. Tripwire check

No automatic-failure condition: **attendance integrity is untouched** — TCH-1
changes only a navigation destination; no register/marking mutation, no
double-count/overwrite, no new scheduler. **PASS.**

## 6. Next

C15 — HR & SIS productivity (HR-3 batch leave approve/reject, HR-4 leave-balance
report, HR-7 employee directory export, SIS-2 richer registry/contact-sheet,
SIS-5 transfer/exit log). Tracked optional: an ATT-4 one-tap teacher reminder
(the monitor is complete per the criterion; a nudge is a future XCT-2 reuse).
