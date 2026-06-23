# Batch 3 — Core School Loop (verified end-to-end on live)

Date: 2026-06-23. Live edge: **https://akshara.veloraunisexsalon.com**.

Goal: make the everyday cycle **Students → Attendance → Exams → Results-to-parent**
actually persist on the live backend, end-to-end, durably.

## Result: the full loop works on live
Verified with the real seed tenant (Admin / Teacher A / Parent / Student personas):

1. **Student**: `POST /sis/students` → `POST /sis/enrollments` (class 5 / sec A / 2026-27). Persists to `students`, `student_profiles`, `sis_student_enrollments`. ✅
2. **Attendance**: Teacher A `POST /teacher/attendance/submit` (`{class_id, entries:[{student_id, mark}]}`) → persists to `attendance_sessions`/`attendance_records`, audits, and enqueues absence alerts to guardians. ✅
3. **Exams + marks**: `POST /academics/exams` → `/schedule` → `/open-marks` (auto-provisions mark entries from enrollments) → `PATCH /academics/exams/marks/{id}` → `/process`. ✅
4. **Governance**: publish is gated. `POST /approvals` (type `examResults`, entity `exam_session:{examId}`) → `POST /approvals/{id}/approve` → `POST /academics/exams/{examId}/publish`. ✅
5. **Results-to-parent**: parent `GET /parent/exams` now returns the **real** published results for the correct child. ✅

## What was actually broken (and fixed)
**Results never reached the parent.** `/parent/exams` returned a stale seed snapshot
("Ravi Kumar / 8-A", empty results) because the parent exams handler returned the
snapshot as-is — unlike `/parent/attendance` and `/parent/fees`, which overlay real
data. Two fixes:

1. **Exam overlay** — new `overlayExamsSnapshotFromResults()` in
   `pilot/pilot_operations_repository.ts`, wired into `handleSnapshot` for
   `snapshot_exams` in `entity_read/mobile_read_handlers.ts` (parent **and** student
   scopes). Pulls real published results via `listPublishedResultsForStudent` and
   corrects child identity from real records.
2. **RLS read access** — migration `20260703100000_parent_student_exam_read_rls.sql`.
   The published-results query JOINs `exam_sessions`, which was **school-scope only**,
   so the JOIN wiped all rows under parent context. Added SELECT policies:
   - `exam_sessions`: readable by `parent`/`student` scope (metadata only, no marks).
   - `sis_student_enrollments`: readable by parent for their linked children / by a
     student for their own record (so `childClass` resolves correctly).
   (`exam_mark_entries` already had a correct per-guardian parent policy.)

## Separation-of-duties (real governance, confirmed)
The coordinator who runs `verify-coordinator` on an exam **cannot** also approve its
results (`exam_sessions.coordinator_verified_by` = approver → blocked). In the seed,
only the admin holds verify+approve+publish, so a single admin must either avoid
self-verifying or rely on role separation. **Production recommendation:** give a
coordinator role `verifyExamResults` and a principal role `approveExamResults`.

## Open follow-ups (not blocking the loop)
- **Cosmetic**: `/parent/dashboard` and `/parent/attendance` still show the seed
  snapshot name ("Ravi Kumar"); only `/parent/exams` was given the identity fix.
  Apply the same childName overlay to those snapshots later.
- **Privacy (Batch 5/7)**: `attendance_records` RLS allows any parent/student in the
  school to read any student's attendance (no guardian-linkage check). The app path is
  safe (always queries the caller's own child), but the policy should be tightened.
- `/parent/experience/summary` requires a `studentId` query param (app passes it).
- Test data left in staging: `ZZ B3 *` students/exams; STU-001 has a published
  Science result + one absent day from this verification.

## Tests
27 backend unit tests green (incl. Batch 2 sms/rate-limit). Changed files typecheck
clean (`deno check`). Loop verified live; results persist across edge restart.
