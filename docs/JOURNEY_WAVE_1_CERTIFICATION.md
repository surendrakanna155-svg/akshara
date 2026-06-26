# AKSHARA — Journey Wave 1 Completion Certification

**Status:** 🟡 **CODE-COMPLETE · ALL GATES GREEN · LIVE CERT + DEPLOY PENDING (owner SSH socket)**
**Wave:** MODULE_JOURNEY_ROADMAP **Wave 1** — "Data-integrity & money/identity correctness — silent failures that corrupt or hide real records."
**Scope source of truth:** `docs/MODULE_JOURNEY_AUDIT.md` (issue IDs) + `docs/MODULE_JOURNEY_ROADMAP.md` (Wave 1). No new features, no roadmap expansion — this only closes the audit's Wave-1 findings.
**Live cert script (ready):** `scripts/qa/live_cert_journey_wave1.py` — real VPS, real pilot OTP (teacher/student/admin/parent), real write→read cycles. **Not yet run** — the backend changes (+1 migration) must be deployed to the VPS first, which requires the owner's SSH control socket (my key is not authorised on the VPS).

---

## 1. Verdict

**Code-complete and gate-certified.** All **7 Wave-1 findings** (2 Critical, 4 High, 1 Medium) are fixed at the true root cause with real data, real persistence, and RBAC/RLS preserved. The three quality gates are green with **zero regression** vs the pre-wave baseline. The work was executed by four parallel agents over disjoint file sets, then integrated and reviewed centrally.

**Remaining to reach PRODUCTION CERTIFIED:** (1) deploy the edge functions + the one new migration to the live VPS pilot; (2) run `scripts/qa/live_cert_journey_wave1.py` against the live backend; (3) flip this header to ✅ with the live N/N. Both (1) and (2) are blocked only by VPS access (owner opens the SSH control socket I reuse — see `akshara-vps-deploy-ssh-blocked`).

**Headline trust win:** the silent data-integrity failures are closed — a teacher can now actually **see and grade** student homework (it was invisible in live), a graded homework now **reaches the student** with its grade, homework is delivered to the **target class** instead of the whole school, an approved attendance correction now **actually updates the record** (the old 0-row UPDATE is fixed), every HR employee profile shows that **person's real data** instead of one shared fabricated template, a logged hostel visitor now **appears** on the Visitors screen, and the Razorpay confirm path is now **fail-closed** so it can never capture a payment without gateway proof if stub mode is ever disabled.

---

## 2. Gate results

| Gate | Result | Baseline | Δ |
|------|--------|----------|---|
| `flutter analyze --fatal-infos` | **0 issues** | 0 | — |
| `flutter test` | **2389 passed / 1 skipped / 0 failed** | 2389 | no regression |
| `deno test _shared/` | **707 passed / 0 failed / 2 ignored** | 680 | **+27 new Wave-1 tests** |
| Live cert (`live_cert_journey_wave1.py`) | ⏳ **pending deploy + SSH socket** | — | — |

The +27 deno tests cover: teacher-homework submissions overlay + pendingReviews, grade write-back to the student entity, class-targeted fan-out (+ zero-enrollment fallback), `applyAttendanceCorrection` real-record update, Razorpay fail-closed live mode + stub path, HR per-employee distinctness, and hostel visitor recompute.

---

## 3. Item-by-item closure

| ID | Module | Sev | What was wrong | Fix | Evidence |
|----|--------|-----|----------------|-----|----------|
| **MJ-C2** | Homework | 🔴 Critical | `GET /teacher/homework` did a plain entity-list read of `homework_assignment` and never joined `homework_submissions`, so the teacher saw every assignment with an empty `submissions[]` and could never grade real work. | Added `overlayTeacherHomeworkSubmissions()` joining `homework_submissions`→`students`/`sis_student_enrollments`; the teacher read now returns real `submissions[]` (each with the submission's **real UUID**, student name, status, grade, comment) and a recomputed `pendingReviews`. Teacher handler routes through a new `handleListWithOverlay` (RBAC unchanged). | `pilot_operations_repository.ts` `overlayTeacherHomeworkSubmissions`; `teacher_handlers.ts handleHomework`; `mobile_read_handlers.ts handleListWithOverlay`. deno: "teacher read returns submissions[] with real ids + pendingReviews". Flutter `teacher_mapper.dart`/`teacher_homework_screen.dart` already render `submissions` + wire the review sheet to each submission id. |
| **MJ-H7** | Homework | 🟠 High | `reviewHomework` updated only `homework_submissions`; the student's `homework_item` was never updated and there was no read overlay, so a graded item stayed `pending` to the student. | `reviewHomework` now (a) jsonb-merges `status='reviewed'` + `reviewGrade` + `reviewComment` onto the student's own `homework_item`, and (b) a belt-and-suspenders read overlay (`overlayStudentHomeworkFromSubmissions`) reconciles the student list against `homework_submissions`. The API mapper now populates `reviewGrade`/`reviewComment` (previously silently dropped). | `pilot_operations_repository.ts reviewHomework` + `overlayStudentHomeworkFromSubmissions`; `mobile_read_handlers.ts` student `homework_item` overlay; `student_mapper.dart toHomeworkItem`. deno: "reviewHomework writes status/grade back to student_entities homework_item". |
| **MJ-H8** | Homework | 🟠 High | When no student was named, the fan-out delivered `homework_item` to **every** active student in the school (the `students` table has no class column), so an 8-A assignment landed in every child's list. | Fan-out now targets only students whose **current** `sis_student_enrollments` row matches the parsed class label (`class_name` + optional `section_name`). `parseClassLabel("8-A")→{8, A}`. Back-compat safety: if a school has **zero** enrollment rows, it falls back to the full active roster (so un-enrolled pilots aren't starved). Returns the real `deliveredCount`. | `pilot_operations_repository.ts insertHomeworkAssignment` + `parseClassLabel`. deno: targets matching class when enrollments exist; falls back to all when none; named-student targets one. |
| **MJ-H9** | Attendance | 🟠 High | Approving a correction ran a 0-row UPDATE: it matched `attendance_sessions.class_label = '8-A'` (but sessions store the **raw class_id** e.g. `class_8a`) AND `session_date = COALESCE(ac.session_date, CURRENT_DATE)` (but `session_date` is never persisted). So the correction flipped to `approved` while the student's mark was unchanged — and parent/student reads (which overlay from `attendance_records`) still showed the old mark. | Rewrote the UPDATE to target by **student identity** in the latest **submitted** session (optionally constrained to `correction.session_date` when non-null), dropping the broken `class_label` string equality entirely. Captures the affected-row count and `console.warn`s on a 0-row match (no silent no-op) without throwing (the correction row remains the audit trail). | `attendance_correction_repository.ts applyAttendanceCorrection`. deno: "applyAttendanceCorrection updates the real record mark and approves"; "already-approved correction is a no-op". Verified against `attendance_records.id` PK + columns. |
| **MJ-H10** | HR | 🟠 High | `employeeDetailToApi` injected the **same** fabricated `reportingManager` ('Rajesh Iyer (Principal)'), `address`, `emergencyContact`, leave balances, 'Verified' documents, and a single hardcoded attendance row into **every** employee. | Every field now derives from that employee's **own** real data: `recentAttendance` filtered from `snapshot_attendance.records` by `employeeId`; `leaveBalances` = a genuine org `leavePolicy` entitlement with per-person `used/available` computed from that employee's **approved** leave in `snapshot_leave.requests`; `reportingManager` derived from the real role hierarchy (backfilled by migration); `address`/`emergencyContact`/`documents` read from the employee's own payload or show an honest **"Not on record"**/empty state — never a shared fabricated value. | `hr_read_repository.ts employeeDetailToApi`; `hr_handlers.ts handleEmployeeDetail` (loads attendance/leave/settings snapshots in-txn); migration `20260805000000_wave1_hr_employee_profile.sql` (idempotent, UPDATE-only); `hr_employee_profile_screen.dart` empty states. deno: per-employee distinctness + no-constants asserts (13/13). |
| **MJ-H11** | Finance | 🟠 High | `confirmPayment` only verified the Razorpay signature when `!stubMode && paymentId && signature && order_id` were **all** present. With stub mode off but no SDK (the app sends no payment id/signature), the whole verification branch was skipped → capture proceeded with **zero proof of payment**. | Made it **fail-closed**: in live mode (`!stubMode`), a missing `razorpayPaymentId`/`razorpaySignature`/`gateway_order_id` or an invalid signature now **throws before any capture/collection/receipt**. Stub mode (the current VPS default, no real money) is unchanged. **Real-money capture remains owner-gated** (needs Razorpay merchant keys + app SDK) — this fix only prevents capture-without-proof. | `payment_service.ts confirmPayment`. deno: "confirmPayment fails closed in live mode without Razorpay payment id/signature"; "stub mode still captures without a gateway signature". |
| **MJ-M1** | Hostel | 🟡 Medium | `GET /hostel/visitors` returned a **frozen** seeded `snapshot_visitors`, while `POST /hostel/visitors` inserts a `visitor` **list** entity — so a just-logged visitor (201 + success) never appeared on the screen. | `handleVisitors` now **recomputes** the screen payload from the live `visitor` entities (newest-first), split into `activeVisitors` (active / not checked-out) and `visitorLog`, reading `qrPlaceholderLabel`/`parentAppRoute` from the seed (or safe defaults). Same `viewHostel` RBAC + tenant context. Also fixed a secondary gap: the seed had no qr/parent-route fields (previously blank). | `hostel_read_repository.ts recomputeVisitors`; `hostel_handlers.ts handleVisitors`. deno (6/6): "recomputeVisitors surfaces a just-logged visitor in activeVisitors". |

---

## 4. What changed

**Backend (Supabase edge — Deno):**
- `supabase/functions/_shared/pilot/pilot_operations_repository.ts` — `overlayTeacherHomeworkSubmissions`, `overlayStudentHomeworkFromSubmissions`, `parseClassLabel`, class-targeted `insertHomeworkAssignment`, write-back in `reviewHomework`.
- `supabase/functions/_shared/pilot/pilot_operations_handlers.ts` — pass org/school to `reviewHomework`.
- `supabase/functions/_shared/teacher/teacher_handlers.ts` — `handleHomework` overlay.
- `supabase/functions/_shared/entity_read/mobile_read_handlers.ts` — teacher `handleListWithOverlay` + student `homework_item` overlay.
- `supabase/functions/_shared/attendance/attendance_correction_repository.ts` — `applyAttendanceCorrection` rewrite.
- `supabase/functions/_shared/hr/hr_read_repository.ts` + `hr_handlers.ts` — per-employee real derivation.
- `supabase/functions/_shared/payment/payment_service.ts` — fail-closed confirm.
- `supabase/functions/_shared/hostel/hostel_read_repository.ts` + `hostel_handlers.ts` — visitor recompute.

**Migration (1):** `supabase/migrations/20260805000000_wave1_hr_employee_profile.sql` — idempotent, UPDATE-only (org leave policy + derived per-employee reportingManager). No new grants (`hr_entities` already granted to `erp_tenant`). No other item needed a migration (homework/attendance/hostel reuse existing tables + RLS; Razorpay is code-only).

**Client (Flutter):** `lib/core/repositories/api/student/mapper/student_mapper.dart` (populate review grade/comment); `lib/features/hr/employees/hr_employee_profile_screen.dart` (honest empty states). No new Dart logic for the teacher homework / hostel screens — they already parsed the now-real shapes.

**New deno tests:** `pilot/pilot_homework_test.ts`, `attendance/attendance_correction_repository_test.ts`, `hostel/hostel_read_repository_test.ts`, plus additions to `hr/hr_read_repository_test.ts` and `payment/payment_service_test.ts`.

---

## 5. Persistence, RBAC & RLS

- **Persistence verified by tests** against real tables: `homework_submissions`, `student_entities` (`homework_item`), `attendance_records`/`attendance_sessions`, `hr_entities`, hostel `visitor` entities. The homework/attendance/hostel fixes need **no schema change** — they reuse existing tenant-scoped, RLS-enforced tables. The only DDL is the HR backfill migration.
- **RBAC unchanged / preserved:** teacher homework read keeps `viewAdminHub`-or-school-scope; student/parent reads keep student/parent scope; HR + hostel reads keep their module permissions; attendance correction create stays `manageSis`-gated; payment confirm stays parent-scope. No gate was widened.
- **Tenant isolation:** every new query runs under `withTenantContext`/RLS with `app_current_*` scoping.

---

## 6. Out-of-scope residuals (correctly deferred — not Wave-1 blockers)

- **Parent homework grade visibility** — the parent reads `snapshot_homework`, which teacher-create does not yet write; wiring the parent homework list is **Wave 2 (HOMEW-3)**. MJ-H7 here delivers the grade to the **student**; the same overlay will surface to parents once Wave 2 builds the parent homework path.
- **Razorpay real-money capture** — remains **owner-gated** (Razorpay merchant keys + app SDK). This wave only makes the backend fail-closed.
- **Hostel attendance/mess write paths, dashboard/report recompute** — separate Wave-4 items (HOSTE-1/3); only the Visitors screen was in Wave-1 scope.
- **Attendance: parent correction 403, class_label-as-class_id storage, marking permission gate** — ATTEN-2/3/7 are later-wave items.

---

## 7. Live certification plan (run once the VPS socket is open)

1. Deploy edge functions + apply `20260805000000_wave1_hr_employee_profile.sql` to the VPS (standard `/deploy` recipe; edge with `--no-deps` to dodge the known pg healthcheck quirk).
2. Run `python3 scripts/qa/live_cert_journey_wave1.py` — expects all checks green:
   - homework create→student-receives→submit→teacher-sees-real-UUID→grade→student-sees-grade,
   - class targeting (non-existent class delivers to 0),
   - HR two-employee distinctness + no shared constants,
   - hostel visitor log→appears,
   - attendance correction approve→reads-back-present,
   - Razorpay fail-closed guard present.
3. On green, flip §1 status to ✅ **PRODUCTION CERTIFIED (live N/N)** and record the count here.
