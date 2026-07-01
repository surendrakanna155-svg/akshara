# EOS Finding — Exam mark-provisioning 500s on NULL roll_number

**Date:** 2026-07-01 · **Found by:** Track B B11 pilot full-year sim (first live exercise of the exam marks path) · **Severity: P1** (a single data gap breaks a core workflow for a whole class) · **Type:** product robustness defect (NOT a harness gap).

## Defect

`provisionMarkSlots` (opened by `POST /academics/exams/{id}/open-marks`) inserts one `exam_mark_entries` row per enrolled student, computing the primary key as:

```sql
-- supabase/functions/_shared/academics/exam_administration/exam_administration_repository.ts:285
INSERT INTO exam_mark_entries (id, …)
SELECT  $3 || '_' || e.roll_number,  …            -- id = exam_id || '_' || roll_number
FROM sis_student_enrollments e JOIN students s …
WHERE e.class_name = session.grade AND e.section_name = session.section_name AND e.is_current;
```

`exam_mark_entries.id` has **no column default** (verified in both `akshara_db` and the clone). In SQL `'x' || NULL = NULL`, so for any enrolled student whose `sis_student_enrollments.roll_number` is **NULL**, the computed `id` is NULL → **`null value in column "id" … violates not-null constraint` → HTTP 500**.

`roll_number` is **optional** on the student onboarding import (`onboarding_user_provisioning.ts:14,210` — `row.rollNumber ?? null`), so students without a roll number are a legitimate, reachable state. Because the provision is a single `INSERT … SELECT` over the whole class, **one roll-number-less student fails the batch and breaks opening marks for the entire class/section.**

## Impact

A real school that imports students without roll numbers (or before assigning them) cannot open exam marks — `open-marks` 500s. This live path appears to have never been exercised before (route-contract tests are DB-free; this sim is the first live provision).

## Fix direction (not applied — logged for a QA wave)

Make the mark-entry id independent of `roll_number`: use `gen_random_uuid()` (or `$3 || '_' || e.student_id`, which is always non-null and already unique per exam+student), or add a `DEFAULT gen_random_uuid()` to `exam_mark_entries.id` and drop `id` from the insert column list. Optionally coalesce `roll_number` for the derived id. Keep the roster match (`class_name`/`section_name`/`is_current`) unchanged.

## Sim status

B11 works around this with **realistic data** (the seeded student is given a roll number — a real student has one), so the happy-path pilot cert is green (24/24). This is not a faked pass.

## RESOLUTION — 2026-07-01 (owner-approved, fixed + deployed + verified)

**Fixed.** `exam_administration_repository.ts:285` mark-entry id changed from `$3 || '_' || e.roll_number` → **`$3 || '_' || e.student_id::text`** — `student_id` is always non-null and unique per exam+student, so the id can never be NULL, and it stays deterministic (the `ON CONFLICT (id) DO NOTHING` idempotency is preserved). No schema/migration change; no other code reconstructs the id from roll_number (line 372 only *orders* by it).

**Verified live** on the isolated stack: with the seeded student given **no roll number**, `open-marks` succeeds and `exam-publish` returns `published=1` (previously a 500). `deno check` clean; deployed to both edges. `roll_number` stays a first-class column (still stored + displayed) — only the surrogate id no longer depends on it.

