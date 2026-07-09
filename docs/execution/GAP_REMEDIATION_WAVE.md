# Gap Remediation Wave (final gap-discovery → fix) — 2026-07-09

Owner: fix ALL P0+P1 now, **build** the missing backends (complete the feature); then P2 cleanup. Verify-first each (the discovery already traced each to a reachable broken behavior + ruled out false positives). Re-certify after.

## P0 (broken production flows)
1. **Student app** — student dashboard/attendance/exams/timetable/profile 404 for every real student. `entity_read/mobile_read_handlers.ts` `createStudentScopedReadHandlers` returns hard 404 on `SnapshotNotFoundError`; parent (`resolveParentSnapshot`→`buildDefaultParentSnapshot`) + teacher have a default-snapshot fallback, student was missed. FIX: give student scope the same fallback (build from `students`/`sis_student_enrollments`, then overlay live data).
2. **School-completion** — 5 timetable endpoints missing (`/school/timetables/optimize/apply`, `/substitute/coverage`, `/substitute/assign`, `/reassign/options`, `/reassign`) → SubstituteManager/TeacherReassignment/TimetableOptimization screens 404. Client models exist (`TeacherReassignmentSlot/Candidate`, `SubstituteOpenSlot`). FIX: build the 5 handlers + register in `school_completion_router.ts` (RBAC `manageAcademicTimetable`/`viewTimetableOptimization` + audit).
3. **Inventory-replacement RLS** — parent-scope RLS blocks the `replacement_status`/status UPDATE on `inv_student_distributions` (FOR ALL policy requires scope='school') while a `payment_request` commits → inconsistent state; `updated[0]!` masks the empty result. FIX: verify-first who initiates; correct the RLS/scope or the write path so the state change and payment stay consistent.

## P1 (shipped actions that always fail)
4. Admissions Fee-Handoff picker → `GET /admissions/fee-structures` 404 (blocks admission→finance). FIX: add the GET (reuse `GET /finance/fee-structures` data), register in `admissions_router.ts`, `viewAdmissions`.
5. Alumni Reports key mismatch — backend emits `eventAttendance`; client reads `eventAttendanceTrend`+`engagementByBatch` (never emitted) → charts always empty. FIX: align keys + add `engagementByBatch` aggregation in `computeAlumniReports`.
6. Operations Hub Dismiss/Complete → `/operations/hub/alerts/:id/dismiss` + `/operations/hub/actions/:id/complete` 404. FIX: build both POST routes + handlers (RBAC `manageManagement`+`viewOperationsHub` + audit + persist state `buildOperationsHub` reads back).
7. Parent→teacher message → `POST /parent/messages` 404 (only `/parent/messages/send` exists). FIX: alias route or fix client path.
8. Parent communication acknowledge/read → `POST /parent/communication/:id/read`+`/acknowledge` 404 → consent never acknowledgeable. FIX: add both routes (persist + audit, mirror `handleParentAcknowledge`).
9. WhatsApp "stub" fabricates delivery success (unconfigured schools see 100% delivery). FIX: `sendWhatsAppMessage` returns success:false / "unconfigured" for the stub; don't record "sent".
10. Onboarding invite marks 'sent' but never delivers + `OnboardingHubScreen` orphaned. FIX: only set sent after real launch; wire a reachable invite action; add/retire the `/sis/onboarding` menu entry.

## P2 (cleanup, after P0/P1): alumni KPIs hardcoded-0 · vault-rotate no-UI · school-calendar no-callers · report-card PDF hardcoded school name (parent+student_app) · student seed contract · widgets/data/refresh + DynamicDashboardScreen + orphaned catalog widgets + vertical-pack picker · social router unreachable · memories/analytics + setup-wizard/sessions dead handlers.
