# Exams Slice 4 — Approve + Publish

**Status:** Complete
**Depends on:** Slice 3 — marks entry wiring (`8685c06`); reuses the F4 + M-D3 approval-gated publish backend
**Deployment:** None — mock/in-memory store; durable backing tracked with F6/F7

---

## Summary

Slice 4 of the [exams build plan](../EXAMS_BUILD_PLAN.md) (Phase 4 — *Approve + publish*) closes the
loop on the existing approval gate by **surfacing each exam's approve → publish status inside the
Exam Workspace hub**, so coordinators and principals can see what every exam is waiting on without
leaving the workspace (the Slice 2 "one workspace, filtered by role" goal).

The approval mechanics themselves already shipped earlier: the F4 backend
(`ExamAdministrationStore.publishExamResults`), the M-D3 `ExamResultsApprovalAdapter`
(`onApproved → publishExamResults`, `onRejected → recordRejectionComment`), the teacher submit flow
in the Results panel, the coordinator verification UI, the principal approval center, and
parent/student consumption. Slice 4 makes that chain **visible at a glance** and **adds the missing
test coverage** for the teacher-facing approve/publish UI.

## Deliverables

| Area | Change |
|------|--------|
| Status model | `ExamApprovalStatus` enum + pure `examApprovalStatus(ExamSession)` / `examApprovalStatusLabel` in `exam_admin_models.dart` |
| Workspace hub | `_ExamApprovalStatusRow` on each exam card — tone-coded chip (awaiting verification / awaiting approval / returned / published) + principal feedback on returned exams |
| QA key | `QaTestKeys.examAdminApprovalStatusChip(examId)` |
| Tests (hub) | Unit tests for all `examApprovalStatus` branches + widget tests asserting each status renders on the hub |
| Tests (teacher) | New `teacher_exam_results_panel_test.dart` driving the previously-untested Results panel: submit-for-verification, awaiting-coordinator, submit-for-approval, and returned-feedback states |

## Status derivation

Derived purely from the lifecycle phase plus the `coordinatorVerified` / `rejectionComment` flags the
repository already enriches onto each `ExamSession` — no approval-center round-trip:

| Phase / flag | Status | Chip tone |
|--------------|--------|-----------|
| draft, scheduled | none (hidden) | — |
| marksEntry | marks in progress (hidden — phase chip suffices) | — |
| processed, not verified | Awaiting coordinator verification | warning |
| processed, verified | Awaiting principal approval | warning |
| any phase + rejection comment | Returned by principal | error |
| published | Published to students & parents | success |

`published` takes precedence over a lingering rejection comment; a rejection comment otherwise
overrides the processed phase.

## Gate

- `flutter analyze lib/features/academics/exam_admin lib/core/exams` = clean (pre-existing unused-import
  warnings in unrelated exam-admin files untouched)
- `flutter test test/features/academics/exam_admin/ test/features/teacher/exams/ test/integration/exam_administration/` = all passing

## Deferred

- Slice 5 — clean in-app results view for parents/students
- Slice 6 — in-app report card (subjects, %, grade, total, rank per school setting)
- Durable server backing for results persistence (F6/F7)
