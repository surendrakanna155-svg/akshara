# EXAM WORKSPACE DESIGN — Akshara ERP

> **Date:** 2026-06-18 · **Base commit:** `1b39a60` · **Type:** Audit + design (NO implementation)
> **Why this exists:** Before building a "Slice 2 Exam Setup screen", confirm we aren't adding *another* overlapping screen to a product that already has too many. This audit maps every exam surface that exists today and recommends the simplest workspace.
> **Headline finding:** **Do NOT build a new standalone Exam Setup screen.** "Create exam" already exists as a dialog inside `ExamAdministrationScreen`, and there are **two competing marks-entry flows**. The right move is to *consolidate* the existing surfaces into one **Exam Workspace**, not add to them.

---

## 1. The complete exam lifecycle

```
1. Exam Setup        — define the exam (term, classes, subjects, max marks, dates)
2. Blueprint         — the paper "recipe" (marks per chapter/type/difficulty)        ⟵ FUTURE (Question Intelligence)
3. Question Paper     — assemble/print the actual paper + answer key                  ⟵ FUTURE (Question Intelligence)
4. Schedule          — lock dates/rooms; provision student mark slots
5. Marks Entry       — teachers enter marks per student per subject
6. Verification      — exam coordinator checks marks before they go up
7. Approval          — principal approves (durable gate)
8. Publish           — results become visible to parents & students
9. Report Card       — per-student card: marks + grade + total + rank + remark + attendance
10. Analytics        — weak chapters, subject trends, rank movement, forecasts
```

**Scope note for the current build (exam cycle first):** Steps **2–3 (Blueprint, Question Paper) are PARKED** — they are the future "Question Intelligence Platform". The exam cycle we are building now = **1, 4, 5, 6, 7, 8, 9** (+ light **10**). The workspace should leave an obvious, labelled *slot* for 2–3 so they drop in later without redesign.

---

## 2. Which screens already exist?

Every step except Blueprint and a true admin Report-Card builder already has a surface. (File paths for engineers.)

| Lifecycle step | Screen / surface today | File |
|----------------|------------------------|------|
| **Setup (create exam)** | A **dialog**, not a screen | `lib/features/academics/exam_admin/widgets/exam_create_dialog.dart` |
| Exam list + schedule | `ExamAdministrationScreen` (+ `ExamLifecycleActions`) | `…/exam_admin/exam_administration_screen.dart`, `…/widgets/exam_lifecycle_actions.dart` |
| Blueprint | **MISSING** (implicit in Education paper generation) | — |
| Question Paper / Bank / Answer Key | `EducationScreen` (4 tabs) + PDF service | `lib/features/education/education_screen.dart`, `education_pdf_service.dart` |
| **Marks Entry (admin)** | `ExamMarksEntryScreen` | `…/exam_admin/exam_marks_entry_screen.dart` |
| **Marks Entry (teacher)** | `TeacherExamsScreen` (own parallel flow) | `lib/features/teacher/exams/teacher_exams_screen.dart` |
| Verification (coordinator) | Buttons inside the two marks screens | (same as above) |
| Approval (principal) | `PrincipalApprovalCenterScreen` + adapter | `lib/features/management/approval/principal_approval_center_screen.dart`, `lib/core/approvals/adapters/exam_results_approval_adapter.dart` |
| Publish | Buttons inside the marks screens / on approval | (same) |
| **Report Card** | `StudentReportCardScreen` (only true one) | `lib/features/student/progress/student_report_card_screen.dart` |
| Result views (parent/student) | `ParentExamsScreen`, `StudentExamsScreen` | `lib/features/parent/exams/…`, `lib/features/student/exams/…` |
| Report-style (parent) | `ParentAcademicReportScreen` | `lib/features/parent/academics/parent_academic_report_screen.dart` |
| Analytics (school) | `ExamIntelligenceScreen` (6 tabs) | `lib/features/intelligence/exam/exam_intelligence_screen.dart` |
| Analytics (per student) | `StudentProgressScreen` | `lib/features/student/progress/student_progress_screen.dart` |

**Reachability today:** the admin exam-admin screen has **no top-level menu item** — it's only reached from the School Completion hub and a Management → Academics insight link. Teachers reach marks entry through their own Exams tab, bypassing exam-admin entirely.

---

## 3. Which screens overlap?

1. **🔴 Two full marks-entry → verify → publish chains (the big one).** `ExamMarksEntryScreen` (admin, via `examMarksMutationProvider`) and `TeacherExamsScreen` (teacher, via `teacher_exams_provider`) both enter marks, process, submit for verification/approval, and publish — through **different providers and repositories**. Same job, two code paths. This is a data-integrity risk (which one is the source of truth?) and the #1 thing to converge.
2. **🟠 Result viewing duplicated 3×.** `ParentExamsScreen`, `StudentExamsScreen`, and `StudentReportCardScreen` all read published results (the last two already share `studentExamsProvider`).
3. **🟠 "Report card" split across 3 surfaces.** `StudentReportCardScreen` (student marksheet), `ParentAcademicReportScreen` (narrative report), and Education's **Report Remarks** PDF (`printReportCardRemark`). Three different ideas of "report card", none unified.
4. **🟡 Analytics split.** `ExamIntelligenceScreen` (school-wide) vs `StudentProgressScreen` (per-student) — fine to keep separate, but they should share one data spine.

---

## 4. Which screens should be merged?

| Merge | Into | Benefit |
|-------|------|---------|
| `TeacherExamsScreen` marks flow + `ExamMarksEntryScreen` | **One marks-entry component** used by both teacher and admin (same provider/repo, same source of truth) | Kills the duplicate chain; teacher and office see the same marks |
| `ExamAdministrationScreen` + `exam_create_dialog` + lifecycle actions | **One "Exam Workspace" hub** (list + setup + schedule + status, with a settings section) | One home for running exams; no new standalone screen |
| Education **Report Remarks** PDF + `StudentReportCardScreen` data | **One Report Card builder/renderer** (shared template; teacher remark feeds it) | One report card, many viewers |
| `ParentExamsScreen` + `ParentAcademicReportScreen` | Keep as **two tabs of one parent "Academics" view** (results vs report card) | Less parent nav clutter |
| Blueprint + Question Paper (future) | A **single "Paper" entry point** off an exam (parked) | Clean slot for Question Intelligence later |

**Net:** the ~9 exam surfaces collapse toward **one admin Exam Workspace + one shared marks component + one report card + persona views + analytics**. No new standalone screens; fewer, not more.

---

## 5. What the final Exam Workspace looks like, per persona

The Exam Workspace is **one concept, filtered by role** (the first real instance of the USER→ROLE→WORKSPACE→TASK model). Each person sees only their slice.

### 👩‍🏫 Teacher
- **Lands on:** "My Exams" (their classes/subjects only).
- **Does:** enter marks (the shared component), save drafts, submit for verification. Sees status (draft → submitted → approved → published).
- **Never sees:** other teachers' classes, school-wide setup, approvals.
- *Today:* `TeacherExamsScreen` — keep as the teacher entry point, but back it with the shared marks component.

### 🧑‍💼 Exam Coordinator (a role to formalize)
- **Lands on:** the **Exam Workspace hub** — all exams + their phase.
- **Does:** **set up exams** (the create dialog), **schedule**, monitor marks-entry progress, **verify** completed marks, then forward for principal approval. Owns the school's **exam settings** (grading style, rank toggle, term names).
- *Today:* `ExamAdministrationScreen` + `exam_create_dialog` — this *is* the coordinator workspace; just elevate and complete it.

### 🧑‍⚖️ Principal
- **Lands on:** the **unified Approval Center** (already exists) — exam results appear as one approval card with class/subject/marks-completion/coordinator-verified detail.
- **Does:** approve or reject (durable gate) → on approve, results publish. Optionally views school-wide **Exam Analytics**.
- **Never:** enters marks or sets up exams.
- *Today:* `PrincipalApprovalCenterScreen` — keep; it's the right pattern. Reuse, don't duplicate.

### 👪 Parent
- **Lands on:** child's **Academics** → two simple tabs: **Results** (published exam scores) and **Report Card** (term marksheet: subjects, marks, %, grade, rank *if the school enabled it*, remark, attendance).
- **Never:** sees school-wide data, marks entry, or other children's data.
- *Today:* `ParentExamsScreen` + `ParentAcademicReportScreen` — combine into the two-tab Academics view; the report card is the new piece (Slice 6).

*(Student mirrors Parent: `StudentExamsScreen` + `StudentReportCardScreen` → one Results/Report view.)*

---

## 6. How grading style & rank settings fit

These are **school-level settings, set once — not per-exam clutter.** (Slice 1 already built the engine: `ExamReportSettings` = grading scale + rank toggle + term hints, in `lib/core/exams/exam_grading.dart`.)

- **Where they live:** an **"Exam Settings" section inside the Exam Workspace hub** (owned by the Exam Coordinator / school admin), seeded from the school's board. *Not* on every exam-create form.
- **When they apply:**
  - **Grading style** → applied automatically at **Publish** (marks → grade) and shown on the **Report Card**. The teacher/coordinator never re-picks it per exam.
  - **Rank toggle** → rank is always computed for the school; it appears on the parent/student **Report Card only if the school turned it on**.
  - **Term names** → offered as quick-pick hints in the create-exam dialog (terms stay free text).
- **Per board (mix of CBSE/State/ICSE):** each school picks its scale once (Standard / CBSE / Percentage-Division presets exist; editable later). This is the one place "mix of boards" is configured.

---

## 7. Can Exam Setup be integrated into an existing screen instead of a new one?

**Yes — and it should be. There is no need for a new standalone screen.**

- "Create exam" is **already** a dialog (`showExamCreateDialog`) launched from the **`ExamAdministrationScreen`** FAB. Setup is *already integrated*.
- **Recommendation for "Slice 2":** instead of building a new screen, **elevate `ExamAdministrationScreen` into the Exam Workspace hub** and **enhance the existing create dialog**:
  - Make the hub reachable from a clear menu entry (today it's buried).
  - Add an **"Exam Settings"** section/sheet to the hub for grading style + rank toggle + term hints (Slice 1 engine plugs in here).
  - Improve the create dialog for mobile (it's a dense dialog) — possibly a bottom-sheet/stepped form using the shared form components.
- This keeps the screen count flat (reuse 1, add 0) and directly serves the "easiest ERP / no screen sprawl" goal.

---

## RECOMMENDED UX (the decision)

**Build the Exam Workspace by consolidating, not adding.** Concretely:

1. **One Exam Workspace hub** = today's `ExamAdministrationScreen`, elevated: exam list + phase filters + **Create exam** (enhanced dialog) + an **Exam Settings** section (grading style, rank toggle, term hints). Owner: Exam Coordinator / admin. Give it a real menu entry.
2. **One shared Marks-Entry component** used by both the teacher tab and the hub — ending the two-chain duplication and the "which marks are real?" risk.
3. **Reuse the existing Approval Center** for the principal step (do not build an exam-specific approval screen).
4. **One Report Card** (the new piece) rendered for parent + student from published results, honoring the school's grading style and rank toggle; the teacher remark feeds it.
5. **Keep analytics** (`ExamIntelligenceScreen` school-wide, `StudentProgressScreen` per-student) on a shared data spine; no new screens.
6. **Leave a labelled "Paper" slot** (Blueprint + Question Paper) wired to nothing yet — the future Question Intelligence drop-in point.

**Revised Slice 2, therefore:** *not* "build a new Exam Setup screen", but **"elevate `ExamAdministrationScreen` into the Exam Workspace hub + add the Exam Settings section + polish the create-exam dialog."** Same visible outcome (a place to set up exams), zero new screen sprawl, and it lands the Slice 1 settings engine in the UI.

---

*No code was changed by this audit. Awaiting owner direction before implementing.*
**STOP.**
