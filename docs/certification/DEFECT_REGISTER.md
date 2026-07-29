# NIKSHA OS — Product Certification Defect Register

**Single consolidated register for the certification phase.** Every workstream
appends here. Nothing is fixed from this file during certification — it feeds
the remediation roadmap produced at the end.

## Standing rule — fabricated authoritative data is ALWAYS P0

Any feature that presents **fabricated financial, attendance, examination,
certificate or legal information** to a user is release-blocking, without
argument and regardless of how it came about (demo fallback, mock repository,
optimistic UI, a placeholder nobody removed).

The reasoning is not severity arithmetic. These are the classes of data a school
and a parent *act on* and cannot independently check. A parent shown payments
they never made, a student shown marks nobody awarded, a certificate asserting
a fact that is not true — the product is not degraded in those cases, it is
lying, and the person it lies to is the one who most depends on it being true.

Precedents already closed under this rule: the fabricated `SUP-####` support
ticket (RC phase), and **CERT-001 ⭐PRIORITY-REMEDIATION-CANDIDATE** below.

## Priority Remediation Candidates

Placed at the TOP of the Product Remediation Roadmap when certification
completes, ahead of ordinary P0 ordering.

| ID | Why |
|---|---|
| **CERT-001** | `/parent/fees` renders a fabricated ₹23,000 statement and four fake "Paid" payments on the failure path. Fabricated financial data shown to a parent. |
| **WIDGET-001** | `/parent/dashboard` renders `ParentDashboardData.mock()` — "₹4,200 due", "Present · Marked 9:12 AM" — during **every** load, not only on failure. Same class as CERT-001, on a higher-traffic screen, and the skeleton meant to prevent it is unreachable code. |
| **WIDGET-002** | `/teacher/dashboard` asserts a staff check-in at "9:02 AM · Geo+Face verified" that did not happen, on the record that feeds payroll and the staff-attendance audit trail. |
| **WIDGET-011** | The principal's "School health score" is blended from hard-coded fallbacks (68 and 31) whenever the real figures are absent, so a school with no data is shown a confident **51**. A fabricated financial claim to the owner. |
| **JOURNEY-001** | The `/admin` landing hero — the first screen 6 of 15 staff roles see, every day — renders compile-time constants as live KPIs: "1,248 Students · 86 Staff · **96% Attendance**" and "**₹4.2L Collected today** · ₹1.8L Pending". Fabricated attendance and financial data, on day one at an empty school, with no failure required to trigger it. |
| **JOURNEY-007** | `/parent/payment` falls back to a fabricated payment summary — another child's name, "₹4,000 + ₹200 late fee", a due date — whenever the live summary call fails or is still loading, and sends that fabricated **amount** to `POST /parent/payments/initiate`. Fabricated money on the payment write path. |
| **POLISH-001** | **No staff persona can log out.** In a release build the only profile affordance for principal, teacher, accountant and every other staff role is a snackbar reading "Profile menu coming soon." On the shared school devices this product is designed for, a session cannot be ended — the next person inherits full access to student PII, fee collection and marks entry. It is also the first personal affordance a principal touches. One conditional away from fixed. |
| **OS-007** | Audit is **not transactional at any of its 305 call sites**: the mutation commits, the audit insert fails, and the caller is told the operation failed — so the money moved, the trail is missing, and the operator will do it again. The RC phase's stated guarantee of in-transaction auditing cannot hold, because there are no transactions. |
| **OS-009** | The notification rail reaches **9 of ~62 mutating modules**. `payment` moves money, `attendance` marks a child absent, and `library` records an overdue book — none of them tells anybody. 53 modules change state that no human ever learns about. This is the single strongest disproof of "operating system", and it generalises SIM-003, XMOD-019 and XMOD-023 from isolated misses into a population. |
| **API-119** | An in-flight `409 IDEMPOTENCY_CONFLICT` is classified by the reliability outbox as `confirmed`, but the backend releases that claim when the racing request fails. The app can therefore record a fee collection as **confirmed** — terminal, never retried — with nothing written to the books. A collection the school believes it took and the ledger never received. Fabricated financial state by the standing rule, on the money write path. |
| **E2E-017** | **There is no file picker in the product.** All four upload surfaces — SIS student documents, admissions documents, student homework submission, teacher homework attachment — post the same hard-coded blank PDF under a user-typed file name. A clerk can then mark that blank page **verified**, and an admission can be approved on a documents checklist made entirely of them. Fabricated records data, on the paths that hold a child's legal documents. |
| **E2E-008** | The counter's "Record collection" sends the literal string `'Today'` as the payment date. The FIN-D1 closed-day guard compares it lexically and returns "not locked" every time, so **closed and reported books silently take new money**; and `fiscalYearOf("Today")` returns `"NaN-NaN"`, so the receipt number handed to the parent reads `SCH/NaN-NaN/000042` and every fiscal year shares one sequence. |
| **E2E-011** | `/teacher/student-risk/:id` shows a class teacher a student's Attendance, Homework and **Fees** rows composed from constants — `92`, `80`, and `feeAccountId == 'acct_ravi' ? '₹4,200 due' : 'No dues'`. A teacher is shown "No dues" for a student who may owe fees, on the screen they open before a parent meeting. |
| **E2E-012** | The teacher's **Export marks summary** builds its CSV/PDF from the seeded demo exam (`exam_math_8a`, "Unit Test — Mathematics", mock roster) rather than the school's exams — a shareable document of examination data about an exam that does not exist. |

## Severity

| | Meaning |
|---|---|
| **P0** | Blocks release. Data loss, money error, security/privacy breach, a false claim shown to a user, or a core daily workflow that cannot complete. |
| **P1** | Materially degrades a real school's day. Workflow completes but wrongly, slowly, or confusingly. Fix before pilot. |
| **P2** | Noticeable quality gap. Does not block the workflow. |
| **P3** | Polish. |

## Required fields per entry

`ID · Severity · Module · Feature · Repro steps · Expected · Actual ·
Root cause (if known) · Recommended fix · Dependencies · Risk · Evidence`

## Status

| Total | P0 | P1 | P2 | P3 |
|---|---|---|---|---|
| 196 | 36 | 104 | 50 | 6 |

By workstream: **CERT** 6 (1 P0 · 5 P1) · **XMOD** 39 (10 P0 · 22 P1 · 7 P2) ·
**DAI** 16 (2 P0 · 7 P1 · 5 P2 · 2 P3) · **WIDGET** 18 (3 P0 · 8 P1 · 6 P2 · 1 P3) ·
**JOURNEY** 16 (3 P0 · 10 P1 · 3 P2) · **SIM** 4 (4 P1) ·
**E2E** 21 (6 P0 · 11 P1 · 4 P2) · **API** 25 (4 P0 · 9 P1 · 12 P2) ·
**AI** 6 (3 P1 · 3 P2) · **POLISH** 24 (1 P0 · 10 P1 · 10 P2 · 3 P3) ·
**OS** 21 (6 P0 · 15 P1).

> Counts recomputed mechanically from the `### <PREFIX>-<NNN> · <severity>`
> headings in this file, not carried forward by hand — several workstreams
> append concurrently and the running totals had drifted. Re-run the same
> extraction after any append.

*(Certification in progress.)*

---

## Entries

<!-- Appended by workstream. Newest last. Use the ID prefix of the workstream
     that found it: CERT / JOURNEY / SIM / XMOD / DAI / WIDGET / API / AI /
     POLISH / OS. -->

<!-- ═══════════════════════════════════════════════════════════════════════
     XMOD — Workstream 4, Cross-module synchronisation (2026-07-29)
     Full trace: docs/certification/findings/XMOD-cross-module-certification.md
     Paths below are repo-relative; `_shared/` = supabase/functions/_shared/.
     ═══════════════════════════════════════════════════════════════════════ -->

### XMOD-001 · P0 · Platform / Domain events · Cross-module event propagation

**Repro** Perform any audited mutation (mark attendance, collect a fee, publish exam
results). Inspect `domain_events`: the row exists with `status='published'`. Now call
`POST /domain-events/process-pending` — it returns `processed: 0` regardless of how many
events exist.
**Expected** A domain event written by one module is delivered to interested subscribers in
other modules, so a write in Attendance/Finance/Exams propagates without a human.
**Actual** No event is ever delivered. 368 write sites across 171 event types write into a
table nothing reads.
**Root cause** Two mutually exclusive statements. `enqueueDomainEvent` inserts the row
**already terminal** — `_shared/audit/audit_repository.ts:365` `VALUES (…, 'published',
timezone('utc', now()))` — while the drain selects only non-terminal rows —
`_shared/audit/domain_events_worker.ts:41` `AND status IN ('pending','failed')`. The drain's
result set is therefore structurally always empty, so `dispatchDomainEvent`
(`domain_events_worker.ts:73`) never runs. Independently, the subscriber registry is empty:
`registerDomainEventSubscriber` (`_shared/audit/domain_event_subscribers.ts:85`) is called
only from `domain_events_worker_test.ts:135,166,204,212`.
**Recommended fix** Insert with `status='pending'`, `published_at=NULL`; register real
subscribers; install a drain cron (see XMOD-016). Ship in that order — flipping the status
alone with an empty registry changes nothing but table churn.
**Dependencies** XMOD-016 (no scheduler). Blocks any future push-based propagation fix.
**Risk of fixing** Medium-high. Flipping the insert status makes ~171 event types suddenly
drainable; the first drain over a populated table could be large. Subscribers must be
idempotent (delivery is at-least-once by design, `domain_event_subscribers.ts:61-66`).
**Evidence** `_shared/audit/audit_repository.ts:365`;
`_shared/audit/domain_events_worker.ts:41,73,86`;
`_shared/audit/domain_event_subscribers.ts:70,85`; `_shared/audit/audit_router.ts:27`.

---

### XMOD-002 · P0 · Leave ↔ Attendance ↔ Timetable · Approved-leave date window never stored

**Repro** (a) As a parent, submit a leave for a child; approve it; mark that class's
attendance — the child is **not** auto-excused. (b) As a teacher, submit leave; approve it;
open Daily Substitutions for that date — the "teachers on leave" list is empty and no
substitute slots are offered.
**Expected** An approved leave with a date window auto-excuses the student
(ATT-D3 Part B) and marks the teacher unavailable so substitution can be planned.
**Actual** Both features are permanently inert for every leave created through the shipped
product.
**Root cause** `mobile_leave_requests.from_date` / `.to_date` were added **nullable, no
default, no backfill** (`supabase/migrations/20260830000000_attendance_half_day_and_leave_dates.sql:21-26`).
The only writer is `_shared/pilot/pilot_leave_repository.ts:57-58` (`input.fromDate ?? null`),
fed by `optionalIsoDate(body,"from_date")` at `_shared/pilot/pilot_operations_handlers.ts:307-308`
(teacher) and `:349-350` (parent). **No client ever sends the field** — the teacher DTO sends
only `type_label/from_date_label/to_date_label/reason`
(`lib/core/repositories/api/teacher/dto/teacher_write_request_dto.dart:128-133`), the parent
DTO likewise (`lib/core/repositories/api/parent/dto/parent_leave_submit_request_dto.dart:9-17`),
and the teacher form's "From date" is a free-text `TextField`
(`lib/features/teacher/leave/teacher_leave_screen.dart:206-214`). Approval does not backfill
it (`_shared/approval/leave_decision_effect.ts:37-42`). Both consumers require
`from_date IS NOT NULL`.
**Recommended fix** Replace the free-text date fields with date pickers, send ISO
`from_date`/`to_date`, validate server-side (reject a leave with no machine-readable window),
and backfill from the labels where parseable.
**Dependencies** None. Independent of XMOD-001.
**Risk of fixing** Low-medium. Turning the auto-excuse on retroactively changes historical
attendance percentages — backfill must be a deliberate, audited migration, not a side effect.
**Evidence** `_shared/timetable/substitution_repository.ts:339-344`;
`_shared/pilot/pilot_attendance_repository.ts:67-82,223`;
`_shared/timetable/timetable_workforce_service.ts:232`;
`lib/features/academics/timetable/substitutions/daily_substitutions_screen.dart:127-142`.

---

### XMOD-003 · P0 · HR / Leave → Staff attendance · Approved leave is recorded as absence

**Repro** Approve a staff leave for tomorrow. Tomorrow, that employee does not check in.
Open the HR attendance muster for the month.
**Expected** The day shows as leave, and the employee is not counted absent.
**Actual** The day prints **`A` (Absent)**. `'L'` in that report means *Late*, not Leave.
**Root cause** Approval writes no attendance record. There is no `POST /hr/attendance` route,
and `snapshot_attendance` has **zero writers** in `supabase/functions/**`. Production staff
attendance is the GPS/face ledger `staff_check_ins`, which has no `on_leave` status. The
muster infers "working day with no check-in → Absent"
(`_shared/hr/hr_reports_repository.ts:279-284`) and its handler never loads `snapshot_leave`
(`_shared/hr/hr_reports_handlers.ts:134-139`).
**Recommended fix** On approval, write an `on_leave` staff-attendance record for each covered
working day (holiday-aware), or make the muster left-join approved leave before inferring
absence. The second is smaller and reversible.
**Dependencies** Interacts with XMOD-011 (two leave stores) — a muster join must cover both.
**Risk of fixing** Medium — the muster feeds payroll-adjacent reporting; changing absence
inference changes historical reports.
**Evidence** `_shared/hr/hr_write_handlers.ts:738-783`;
`_shared/hr/hr_reports_repository.ts:279-284,338-352`;
`_shared/hr/hr_router.ts:53-120`; `_shared/staff_attendance/staff_check_in_repository.ts:133`.

---

### XMOD-004 · P0 · Transport → Finance · Bus allocation raises no fee demand

**Repro** Allocate a student to a transport route (`POST /transport/allocations`). Open the
student's fee account.
**Expected** A transport fee demand is raised against the student's per-year account
(TRN-9: Transport defines the fee, Finance collects it).
**Actual** No demand, no invoice, zero dues. The student rides free until an admin
independently remembers to open Transport Settings and press "Raise demand", re-picking a fee
structure by hand.
**Root cause** The allocate handler writes the allocation, the effective-dated history row and
an audit row, then returns 201 — it never calls `raiseTransportDemandFor`. The code concedes
the gap in a comment at `_shared/transport/transport_write_handlers.ts:1855-1858`.
**Recommended fix** Raise the demand inside the allocation transaction, using the existing
idempotent `raiseTransportDemandFor` and its `(student,route,year,term)` dedupe key
(`transport_write_handlers.ts:1780-1786`). Keep the bulk endpoint as a backfill.
**Dependencies** Needs a per-route default fee structure so no human input is required.
**Risk of fixing** Medium — this creates money. Must be idempotent and must not double-bill
students whose demand was already raised through the manual path.
**Evidence** `_shared/transport/transport_write_handlers.ts:321-433` (allocate), `:1716,1796`
(raise), `:1855-1858` (admission of the gap);
`lib/features/transport/transport_workflow_actions.dart:647,834`.

---

### XMOD-005 · P0 · Exams → Parent · Unpublished and unentered marks shown to parents

**Repro** Schedule an exam (do not enter any marks, do not publish). Open the parent app's
experience hub for a student in that class.
**Expected** Nothing appears until results are published — the publish gate is the school's
control over what parents see.
**Actual** The exam appears with **0%** and is listed among the child's "weak topics".
**Root cause** Two parent-reachable queries read `exam_mark_entries` with **no `published`
filter and no status filter**: `_shared/parent/parent_experience_service.ts:118-131`
(`weakMarks` → `homeworkIntelligence.weakTopics` at `:209`) and
`_shared/sis/student_360_service.ts:117-125` (`avg_pct` → `academics.recentExams` at
`parent_experience_service.ts:176-179`; `viewMode:"parent"` does not redact it). Compounded by
`provisionMarkSlots` inserting `marks_obtained = 0` rather than NULL
(`_shared/academics/exam_administration/exam_administration_repository.ts:434`), so an
un-marked paper reads as a genuine zero.
**Recommended fix** Add `AND published = true` to both queries and exclude non-`present`
statuses; change provisioning to NULL (see XMOD-032).
**Dependencies** XMOD-032 (provisioned zeros) — fixing only one still leaves a wrong number.
**Risk of fixing** Low. Both are read paths; the correct behaviour is strictly narrower.
**Evidence** `_shared/parent/parent_experience_service.ts:118-131,176-179,209`;
`_shared/sis/student_360_service.ts:117-125,305-307`;
`_shared/validation/rbac_route_inventory.ts:248`.

---

### XMOD-006 · P0 · SIS → Auth · Parent keeps full portal access after the child leaves

**Repro** Transfer a student out (TC issuance or `PATCH /sis/students/:id/status`). Log in as
that student's parent.
**Expected** The parent no longer resolves that child and cannot read the school's data for
them.
**Actual** The parent's session still includes the departed child in `childIds` and the app
works normally.
**Root cause** `resolveParentContext` selects `students(id,display_name,status)` but **never
filters on `status`** — `_shared/auth_context.ts:268-274`, `childIds` built at `:300`. The
sibling function `resolveStudentContext` *does* `.eq("status","active")` at `:335-339`, so the
student loses access while the parent does not. Compounding: the manual soft-unlink
(`_shared/sis/sis_guardians_repository.ts:168`) throws `LastGuardianError` (`:164`) and
refuses to deactivate the sole remaining active link, so the only parent of a departed
student cannot be de-authorized through the API at all.
**Recommended fix** Filter `students.status='active'` in `resolveParentContext`, matching
`resolveStudentContext`. Separately, allow last-guardian deactivation when the student is not
active.
**Dependencies** None.
**Risk of fixing** Medium — a status typo or an over-broad filter locks legitimate parents out.
Needs the RLS guard test (`_shared/guardian_active_link_rls_guard_test.ts`) extended to cover
student status, not only link status.
**Evidence** `_shared/auth_context.ts:268-274,300,335-339`;
`_shared/sis/sis_guardians_repository.ts:164,168`.

---

### XMOD-007 · P0 · SIS → Attendance · Class attendance cannot be submitted after a student exits

**Repro** Transfer one student out of class 7-A. Next day, a teacher opens 7-A attendance
(the student is correctly absent from the list), marks everyone and presses Submit.
**Expected** Submission succeeds.
**Actual** `AttendanceRosterMismatchError` — submission is hard-blocked. The teacher cannot
take attendance for that class at all, and has no way to fix it.
**Root cause** Two rosters disagree. The display roster filters
`AND s.status = 'active'` (`_shared/pilot/pilot_attendance_repository.ts:556`); the submit
validator `activeRosterStudentIds` (`:167-178`) filters **only** `e.is_current = true` with no
`students` join, so it still expects a mark for the departed child, and `:240-247` throws.
Nothing on any exit path sets `is_current = false` — the TC engine never touches it (whole
function `_shared/sis/sis_certificates_repository.ts:520-682`), and it is written only at
year rollover (`_shared/academic/academic_transition_repository.ts:375,408`) and re-enrolment
(`_shared/sis/sis_enrollments_repository.ts:296-311`).
**Recommended fix** Add the `students.status='active'` join to `activeRosterStudentIds` so the
two rosters share one definition; separately close the enrolment on exit (XMOD-022).
**Dependencies** XMOD-022. Either fix alone resolves the block; both are needed for correctness.
**Risk of fixing** Low for the roster join (it narrows an over-strict validator); medium for
enrolment closure, which many modules key on.
**Evidence** `_shared/pilot/pilot_attendance_repository.ts:167-178,240-247,556`;
`_shared/sis/sis_certificates_repository.ts:520-682`.

---

### XMOD-008 · P0 · Certificates · Fee certificate cannot be issued — DB CHECK rejects the type

**Repro** Issue a certificate of type `fee` via `POST /sis/students/{id}/certificates`.
**Expected** The certificate is recorded and returned.
**Actual** Postgres 23514 (check violation) → opaque `INTERNAL_ERROR` 500 to the user.
**Root cause** `certificate_type` is `'bonafide'|'study'|'conduct'|'transfer'|'fee'` in code
(`_shared/sis/sis_certificates_repository.ts:34,41`) and in the request-table CHECK
(`supabase/migrations/20260884000000_certificate_requests.sql:35`), but the **issues** table's
CHECK allows only four —
`supabase/migrations/20260849000000_sis_certificates.sql:33-34` — and no later migration
alters it (the only later touches are `20260878000000` at `:92-94` and `20260900000025`).
`issueCertificate` inserts `fee` at `sis_certificates_repository.ts:465-474`.
**Recommended fix** One migration adding `'fee'` to the CHECK. Also map 23514 to a structured
422 instead of a 500.
**Dependencies** None.
**Risk of fixing** Very low — widening a CHECK constraint.
**Evidence** `supabase/migrations/20260849000000_sis_certificates.sql:33-34`;
`_shared/sis/sis_certificates_repository.ts:34,465-474`;
`_shared/sis/sis_certificate_handlers.ts:155-156`.

---

### XMOD-009 · P0 · Exams → Parent · Parent report card counts Absent/Medical/Debarred as zero

**Repro** A student is marked Absent (AB) in one subject of a term exam. Publish. Open the
report card in the parent app.
**Expected** Per the frozen rule, AB/ML/DB are NULL + a status code, excluded from totals,
average and rank.
**Actual** The parent's overall percentage and grade are depressed: the absent subject
contributes 0 obtained **and its full `maxScore` to the denominator**.
**Root cause** The Flutter *parent/student* report card sums all lines with no
`countsTowardStats` filter — `lib/core/exams/exam_report_card.dart:166-168` — while the
*admin* card in the same file filters correctly at `:222-227`. The parent feed drops the
status code, delivering `scoreObtained: 0` (`_shared/pilot/pilot_snapshot_repository.ts:860`,
`Number(r.scoreObtained ?? 0)`).
**Recommended fix** Apply `countsTowardStats` in the parent path; carry the status code
through the parent overlay so the client can distinguish 0 from AB.
**Dependencies** None.
**Risk of fixing** Low — brings one code path into line with the other in the same file.
**Evidence** `lib/core/exams/exam_report_card.dart:166-168,222-227`;
`_shared/pilot/pilot_snapshot_repository.ts:860`;
`_shared/academics/exam_administration/exam_administration_repository.ts:1436-1505` (the
correct backend behaviour).

---

### XMOD-010 · P0 · Attendance → Parent / Ops · "No data" attendance rendered as 0%

**Repro** Open the parent app for a child on a day before any attendance has been marked, or
a window in which every marked day was excused.
**Expected** "—" / "no data". The canonical helper's contract is explicit: *"the percentage is
`null` — NEVER 0 and NEVER 100. Callers display this as —/no data, not as 0%"*
(`_shared/attendance/attendance_percentage.ts:24-26`).
**Actual** The parent sees **0%** attendance — a false statement about their child.
**Root cause** Two client mappers coerce the canonical null: `as int? ?? 0` at
`lib/core/repositories/api/parent/mapper/parent_mapper.dart:394` and
`lib/core/repositories/api/phase5/phase5_mapper.dart:150` (ops-hub KPI).
**Recommended fix** Make the model fields nullable and render the honest-state placeholder.
The design system already has the pattern.
**Dependencies** None.
**Risk of fixing** Low-medium — nullability ripples through the widgets that consume these
models.
**Evidence** `_shared/attendance/attendance_percentage.ts:24-26,100-113`;
`lib/core/repositories/api/parent/mapper/parent_mapper.dart:394`;
`lib/core/repositories/api/phase5/phase5_mapper.dart:150`.

---

### XMOD-011 · P1 · HR / Leave · Two disjoint leave stores; teacher-app leave never reaches payroll

**Repro** A teacher files leave in the teacher app; it is approved. Run payroll for that month.
**Expected** The leave is visible to HR and considered by payroll.
**Actual** It appears in no HR report and has no effect on pay.
**Root cause** HR-filed staff leave lives in the JSONB snapshot `snapshot_leave.requests[]`
(`_shared/hr/hr_write_handlers.ts:443,462-469`); teacher/parent-app leave lives in the table
`mobile_leave_requests` (`_shared/pilot/pilot_leave_repository.ts:39-59`). Nothing bridges
them; payroll reads only `snapshot_leave` (`_shared/hr/hr_write_handlers.ts:1592-1603`), and
the substitution engine reads only `mobile_leave_requests`.
**Recommended fix** One leave store. Migrate `snapshot_leave.requests[]` into
`mobile_leave_requests` (or a proper `staff_leave_requests` table) and point every consumer at it.
**Dependencies** XMOD-002, XMOD-003 — all three are symptoms of leave having no single home.
**Risk of fixing** High — a data migration out of JSONB touching payroll. Sequence behind a
read-compat shim.
**Evidence** `_shared/hr/hr_write_handlers.ts:443,462-469,1592-1603`;
`_shared/pilot/pilot_leave_repository.ts:39-59`;
`_shared/approval/leave_decision_effect.ts:36-64`.

---

### XMOD-012 · P1 · HR / Payroll · Absence-based LOP term is permanently zero

**Repro** An employee is absent (not on leave) for 5 working days. Generate payroll.
**Expected** Unauthorised absence reduces pay per policy.
**Actual** Deduction is ₹0.
**Root cause** `countLopDays` reads `attendance.records[]` with `status='absent'` from
`snapshot_attendance` (`_shared/hr/hr_write_handlers.ts:1352-1356`), and `snapshot_attendance`
has **no writer anywhere** in `supabase/functions/**`. The unpaid-leave half of the same
function works correctly (`:1309-1315,1467-1470`).
**Recommended fix** Point the absence term at the live `staff_check_ins` muster
(`_shared/hr/hr_reports_repository.ts:279-284`) instead of the dead snapshot — but only after
XMOD-003, or approved leave will be double-penalised as absence.
**Dependencies** **Hard dependency on XMOD-003.** Fixing this first would deduct pay for
approved leave.
**Risk of fixing** High — direct money impact on salaries.
**Evidence** `_shared/hr/hr_write_handlers.ts:1341-1373,1467-1470,1592-1603`.

---

### XMOD-013 · P1 · Timetable / Substitution · "Notified" and "timetable updated" are literals

**Repro** Assign a substitute teacher with all notify checkboxes ticked. Check the substitute's
notification inbox and the published timetable.
**Expected** The substitute, the class in-charge and the students are told; the timetable
reflects the change.
**Actual** Nobody is notified. The response's `notifiedAudience` is the caller's own booleans
echoed back, `timetableUpdated: true` is a hardcoded literal, and the success message
"Substitute assigned and timetable updated." is a string constant.
**Root cause** `assignSubstitute` contains no notification call —
`_shared/timetable/timetable_workforce_service.ts:336-347`.
**Recommended fix** Enqueue deliveries to the substitute, class in-charge and (per policy)
parents, and drain; or remove the claim from the response and the UI copy. Do not ship a UI
that says "notified" when nothing was sent.
**Dependencies** XMOD-002 (today nobody can reach this screen with real data anyway).
**Risk of fixing** Low.
**Evidence** `_shared/timetable/timetable_workforce_service.ts:336-347`.

---

### XMOD-014 · P1 · Finance · Five divergent definitions of "outstanding dues"

**Repro** For one student with several invoices, compare: the parent app's dues total, the
Student 360 pending amount, the dashboard total outstanding, the defaulter list, and the TC
no-dues gate.
**Expected** One number, one definition.
**Actual** Up to five different numbers, all defensible, none canonical.
**Root cause** Five independent bases: (1) stored `finance_student_accounts.outstanding_amount`
where `status='open'` — the **TC gate** (`_shared/clearance/clearance_contributors.ts:31`),
dunning (`_shared/finance/finance_recovery_repository.ts:183,494`), risk
(`_shared/intelligence/student_risk_repository.ts:143`); (2) invoice sum where status
`IN ('issued','partially_paid')` — dashboard
(`_shared/finance/finance_collections_repository.ts:1054`); (3) invoice rows where status
`NOT IN ('cancelled','draft')`, **`LIMIT 12`, no academic-year filter** — the **parent app**
(`_shared/pilot/pilot_snapshot_repository.ts:472-477`); (4) invoice sum where status
`NOT IN ('paid','cancelled')` — Student 360 (`_shared/sis/student_360_service.ts:159-166`);
(5) status `<> 'cancelled'` — monthly reports (`_shared/finance/finance_reports_repository.ts:38`,
`_shared/director/director_repository.ts:288`). The stored column is maintained only by
hand-written compensation at each write site — `_shared/finance/finance_invoices_repository.ts:286-311`
states "STORED aggregates … nothing re-derives them" — with no reconciliation job.
**Recommended fix** One `outstandingDuesSql()` helper on the model of the (successful)
`attendance_percentage.ts`, used by all five. Add a reconciliation check comparing the stored
column against the derived sum. Remove the parent view's `LIMIT 12`.
**Dependencies** None, but touches the TC gate — pair with XMOD-021.
**Risk of fixing** High — this is money shown to parents and money that gates a school-leaving
certificate.
**Evidence** the five sites above; `_shared/finance/finance_ledger_repository.ts:8-10`
("Nothing here writes" — there is no double-entry ledger).

---

### XMOD-015 · P1 · Finance ↔ Communication · Settings screen promises behaviour no code implements

**Repro** Open Finance → Settings. Set "Reminder Lead Time (days)" and switch on "Overdue
Reminders" and "Send Receipt SMS". Save. Let an invoice go overdue; collect a payment.
**Expected** Guardians are reminded before the due date and after it, and get an SMS when a
payment lands.
**Actual** Nothing happens, ever. The settings persist and are re-displayed, which makes the
school believe they are in force.
**Root cause** Five catalogue entries have **zero consumers** in `supabase/**` or `lib/**`:
`reminders.due_reminder_days` (`_shared/finance/finance_settings_repository.ts:75`),
`reminders.overdue_reminder` (`:82`), `receipts.auto_receipt_sms` (`:62`),
`payments.allow_partial` (`:95`), `receipts.invoice_prefix` (`:55`). The screen renders them
as editable with their descriptions (`lib/features/finance/settings/finance_settings_screen.dart:115-137`,
routed `lib/router/finance_navigation.dart:135`). Related: the shared XCT-2 reminder rail
documents the "Finance fee-reminder ladder (T-3/T0/T+7)" as a consumer
(`_shared/reminders/reminders_service.ts:10-20`) but finance never calls `scheduleReminder` —
the only four callers are exam administration, transport, library, inventory-finance.
**Recommended fix** Either implement the fee-reminder ladder on the existing XCT-2 rail and
honour `auto_receipt_sms`/`allow_partial`, or remove the five entries from the catalogue.
Shipping them as editable is a false claim to the school.
**Dependencies** XMOD-016 (a reminder ladder needs a scheduler).
**Risk of fixing** Low to remove; medium to implement (parent-facing messaging volume).
**Evidence** `_shared/finance/finance_settings_repository.ts:55,62,75,82,95`;
`lib/features/finance/settings/finance_settings_screen.dart:115-137`;
`_shared/reminders/reminders_service.ts:10-20`.

---

### XMOD-016 · P1 · Platform / Ops · Nine periodic jobs, zero schedulers

**Repro** Deploy per `deploy/akshara-vps/`. Wait. Observe that late fees never accrue, risk
scores never update, briefs never pre-warm, notifications sit pending, and the domain-event
drain never runs.
**Expected** Work described as periodic runs periodically.
**Actual** Every one is a button a human must press. The complete installed cron set is three
entries: broadcast sweep (`deploy/akshara-vps/communication-cron/install-communication-cron.sh:36`),
watchdog (`deploy/akshara-vps/monitoring/install-monitoring.sh:24`), nightly backup
(`deploy/akshara-vps/backup/install-ops-cron.sh:66`).
**Actual (unscheduled jobs)** `POST /domain-events/process-pending`
(`_shared/audit/audit_router.ts:27`) · `POST /finance/late-fees/accrue`
(`_shared/finance/finance_late_fee_handlers.ts:30`) · `POST /hr/payroll/run/generate`
(`_shared/hr/hr_write_handlers.ts:1568`) · `POST /hr/leave/accrual/run`
(`_shared/hr/hr_router.ts:134`) · `POST /intelligence/risk/students/compute`
(`_shared/intelligence/intelligence_handlers.ts:139`) · `POST /intelligence/briefs/prewarm`
(`_shared/intelligence/briefs/brief_handlers.ts:95`) ·
`POST /communications/notifications/process-queue` (`_shared/communication/communication_router.ts:130`) ·
`POST /parent/experience/summary/refresh` (`_shared/parent_experience/parent_experience_router.ts:48`) ·
transport document-expiry scan (`_shared/transport/transport_write_handlers.ts:1566`).
**Root cause** The `x-internal-cron-token` pattern exists and works
(`_shared/communication/communication_cron_auth.ts`) but was only ever installed for one job.
**Recommended fix** Extend the existing communication-cron installer to cover each job with an
appropriate cadence, reusing the same internal-token auth. Payroll should stay manual by design.
**Dependencies** Blocks XMOD-001, XMOD-015, XMOD-017, XMOD-019, XMOD-027, XMOD-028.
**Risk of fixing** Medium — several of these jobs write money (late fees) or send parent
messages; each needs its own idempotency and blast-radius review before it is automated.
**Evidence** all paths above; `supabase/migrations/20260920000130` records that there is no
pg_cron.

---

### XMOD-017 · P1 · Parent experience · Academic summary is a snapshot that is never recomputed

**Repro** Open the parent academic summary. Note the attendance rate. Mark a month of
attendance. Reopen it.
**Expected** The summary reflects current data.
**Actual** The original numbers, forever.
**Root cause** The GET returns the persisted row if one exists and only generates on a cold
miss — `_shared/parent_experience/parent_experience_router.ts:80-90` (`if (existing) return
existing`). The regenerate route `POST /parent/experience/summary/refresh` (`:48`) has **zero
non-test callers** in `supabase/**` or `lib/**`, and no cron.
**Recommended fix** Either recompute on read (the numbers are cheap live queries elsewhere) or
schedule the refresh; and stamp the summary with a generated-at that the UI surfaces as
freshness.
**Dependencies** XMOD-016 if the scheduled option is chosen.
**Risk of fixing** Low.
**Evidence** `_shared/parent_experience/parent_experience_router.ts:48,80-90,99,144`.

---

### XMOD-018 · P1 · Attendance → Communication · Absence alert is unlocalised and unidentifiable

**Repro** Mark a child absent and submit. Read the parent's notification.
**Expected** A localized message naming the child and the date.
**Actual** English only: *"Attendance alert / Student marked absent for class {class_id}"* —
no child name, no date, and `{class_id}` is the raw class identifier from the request body.
A parent with two children cannot tell which one.
**Root cause** The write path hardcodes the strings and passes **no `templateCode`** —
`_shared/pilot/pilot_operations_handlers.ts:258-260` → `enqueueNotificationRequested`
(`_shared/communication/notification_service.ts:218-236`). The five-language
`attendance_absence` template (`_shared/communication/parent_comms_localization.ts:69-105`) is
reachable only through `enqueueFromTemplate` (`notification_service.ts:57-68`), whose sole
caller is the WhatsApp bridge — so the template has **zero callers**. Coverage is also narrow:
only `mark === 'absent'` notifies (`pilot_operations_handlers.ts:245`); late, half-day,
auto-excused and later attendance-**correction** approvals notify nobody.
**Recommended fix** Route the absence alert through `enqueueFromTemplate` with
`templateCode: 'attendance_absence'` and variables `{studentName, date}`; extend coverage to
corrections at minimum.
**Dependencies** XMOD-019 (the message still has to be drained to actually send).
**Risk of fixing** Low.
**Evidence** `_shared/pilot/pilot_operations_handlers.ts:245-263`;
`_shared/communication/parent_comms_localization.ts:69-105`;
`_shared/communication/notification_service.ts:57-68,218-236`.

---

### XMOD-019 · P1 · Attendance → Communication · Absence alert is enqueued but not sent

**Repro** Mark a child absent on a quiet day with no other school activity. Watch the parent's
device.
**Expected** A push notification.
**Actual** The delivery row sits `pending`. It ships only when some **unrelated** action
happens to drain that organisation's queue, or an admin manually calls process-queue. It is
visible in the in-app inbox meanwhile (which selects `status IN ('sent','pending')`,
`_shared/communication/communication_repository.ts:327-331`) — but only if the parent opens
the app, which is exactly what the push was for.
**Root cause** The attendance write path never calls `processDeliveryQueue`. Its known callers
are transport (`_shared/transport/transport_write_handlers.ts:720`), gate pass
(`_shared/gate_pass/gate_pass_repository.ts:489`), teacher-parent messaging
(`_shared/teacher/teacher_parent_communication_handlers.ts:134`) and the communication handlers
(`:111,809`). No cron covers `/communications/notifications/process-queue`.
**Recommended fix** Drain after the attendance write (as transport and gate-pass already do),
and add the queue drain to the cron set as a safety net.
**Dependencies** XMOD-016.
**Risk of fixing** Low-medium — draining inline lengthens the attendance-submit request;
prefer post-commit, best-effort, as finance already does.
**Evidence** `_shared/communication/notification_service.ts:83`;
`_shared/communication/communication_router.ts:130`;
`deploy/akshara-vps/communication-cron/install-communication-cron.sh:36`.

---

### XMOD-020 · P1 · Analytics · Attendance risk uses a non-canonical formula

**Repro** A student with many *excused* days appears at risk in the intelligence hub while the
canonical attendance percentage on Student 360 is healthy.
**Expected** One attendance definition across the product (owner decision 2026-07-09).
**Actual** `absentRate = absent / total` — excused and half-day sit in the denominator, late
counts as neither — at `_shared/analytics/analytics_metrics_service.ts:26-31,98`. This feeds
`attendanceRiskScore` → intelligence hub → the principal's daily brief. Separately,
`_shared/parent/parent_experience_service.ts:53` uses `canonicalPct ?? 100`, treating "no data"
as perfect attendance when generating parent-facing grade/trend/alert text.
**Recommended fix** Use `attendancePercentSql()` (`_shared/attendance/attendance_percentage.ts:77`)
in both, as the other eleven consumers already do; propagate null rather than defaulting to 100.
**Dependencies** None.
**Risk of fixing** Low-medium — risk scores and the brief will shift; expected, and correct.
**Evidence** `_shared/analytics/analytics_metrics_service.ts:26-31,98`;
`_shared/parent/parent_experience_service.ts:53`;
`_shared/attendance/attendance_percentage.ts:63-107`.

---

### XMOD-021 · P1 · Clearance · "No dues" means fees only — hostel, transport and inventory never block

**Repro** A student owes hostel mess charges, has an unpaid transport month never invoiced,
and holds unreturned uniform stock. Fees are clear. Request a transfer certificate.
**Expected** The no-dues gate blocks, or at minimum reports what is outstanding.
**Actual** The TC is issued.
**Root cause** The clearance registry tracks fees only. `financeContributor` is
`tracked:true` and blocking (`_shared/clearance/clearance_contributors.ts:26-49`); library is
`tracked:false` (`:108-114`) and inventory advisory-only for a TC
(`_shared/clearance/clearance_engine.ts:99`) and not even executed at the gate
(`_shared/clearance/clearance_gate.ts:39`); hostel is `tracked:false` (`:119-125`); **transport
has no contributor at all** (`:129-134`). Library *is* blocking, but only inside the TC engine
(`_shared/sis/sis_certificates_repository.ts:299-331`, called at `:547`), keyed on
`payload->>'sisStudentId'` — a free-text field a librarian types with no FK
(`_shared/library/library_write_handlers.ts:207`). Two consequences: the read-only clearance
report never calls `libraryDuesForStudent` (`_shared/clearance/clearance_handlers.ts:60-72`)
and can therefore show "cleared" while the gate blocks; and `enforceTransferClearance`
(`_shared/sis/sis_students_repository.ts:838-861`) checks finance only, so a `PATCH`/`PUT` to
`status='transferred'` bypasses the library block the TC path enforces.
**Mitigating** The printed certificate is honest — `TC_FINANCE_CLEARANCE_STATEMENT`
(`_shared/sis/sis_certificates_repository.ts:56-57`) asserts only that *financial* dues are
cleared. This keeps it out of P0.
**Recommended fix** Add hostel and transport contributors; make library a first-class tracked
contributor with a real FK; route every path (TC engine, clearance report,
`enforceTransferClearance`) through the same registry.
**Dependencies** XMOD-014 (which dues number is authoritative).
**Risk of fixing** Medium-high — a wider gate blocks TCs that are being issued today, which is
a real operational change for a school mid-year.
**Evidence** `_shared/clearance/clearance_contributors.ts:26-49,108-134`;
`_shared/clearance/clearance_engine.ts:99,167`; `_shared/clearance/clearance_gate.ts:39`;
`_shared/sis/sis_students_repository.ts:838-861`; `_shared/clearance/clearance_handlers.ts:60-72`.

---

### XMOD-022 · P1 · SIS · Transfer does not close the enrolment

**Repro** Issue a TC. Then open the exam roster for that class, the year-end promotion
preview, and the transport bulk-allocation roster.
**Expected** The transferred student is gone.
**Actual** Still present in all three.
**Root cause** The TC engine never touches `sis_student_enrollments.is_current` (whole function
`_shared/sis/sis_certificates_repository.ts:520-682`). Enrolment-keyed consumers therefore keep
the student: exam roster seeding
(`_shared/academics/exam_administration/exam_administration_repository.ts:441-447`, joins
`students` with no status filter), promotion source
(`_shared/academic/academic_transition_repository.ts:142-150`), transport demand targets
(`_shared/transport/transport_read_repository.ts:228-235`). `_shared/sis/sis_students_repository.ts:374-376`
even assumes `is_current` "is typically already false" for transferred students — nothing makes
that true.
**Recommended fix** Close the current enrolment in the same transaction as the status flip, on
every exit path (TC, PATCH, PUT, year rollover). Add `s.status='active'` to the three
consumers as defence in depth.
**Dependencies** Resolves XMOD-007 as a side effect.
**Risk of fixing** Medium — `is_current` is load-bearing for year rollover; must not
double-close a student who is being re-enrolled.
**Evidence** the five paths above.

---

### XMOD-023 · P1 · Certificates · Issued certificate is never delivered to the parent

**Repro** Approve and issue a transfer certificate through the Certificate Desk. Check the
parent app.
**Expected** The parent is told and can download it.
**Actual** Nothing. The parent must physically visit the office.
**Root cause** Zero notification calls exist in `_shared/certificate_desk/`, `_shared/clearance/`,
`_shared/approval/` (for this type) or `_shared/sis/sis_certificate_handlers.ts`. The PDF is
rendered client-side on the **issuing staff device**
(`lib/features/sis/certificates/sis_certificate_pdf_service.dart:15-47`) and only from the
direct SIS path (`lib/features/sis/sis_workflow_actions.dart:339-347`) — the **certificate-desk
path returns only `issueId`/`serialNo` and has no PDF surface at all**
(`lib/features/certificate_desk/**`).
**Recommended fix** Notify the requesting parent on issue and expose the document (server-side
render or a signed download) on both paths.
**Dependencies** XMOD-039 (there is no parent-facing request surface either).
**Risk of fixing** Low-medium — a TC is a legal document; delivery needs an access-control review.
**Evidence** as above.

---

### XMOD-024 · P1 · SIS → Finance · Ex-students keep accruing fees and stay on the dunning list

**Repro** Transfer a student out with an open account. Run late-fee accrual. Open the
defaulter/recovery list.
**Expected** No new charges; the ex-student is not chased.
**Actual** Late fees accrue on their invoices and they remain on the defaulter list
permanently.
**Root cause** Three gaps. (1) The fee-assignment generator filters `AND s.status='active'`
**only** on the auto-resolve branch (`_shared/finance/finance_assignments_repository.ts:236`);
when the client sends `student_ids[]` — the normal UI flow — that branch is skipped
(`_shared/finance/finance_assignments_handlers.ts:375`) and `bulkAssignFeeStructureSetBased`
inserts straight from `unnest($3::uuid[])` (`:731-733`) with no re-check. (2) Late-fee accrual
joins only invoices→accounts, with no `students` join and no status predicate
(`_shared/finance/finance_late_fee_repository.ts:106-118`). (3) The recovery/dunning queries
`LEFT JOIN students` but filter only on `fsa.status='open' AND outstanding_amount > 0`
(`_shared/finance/finance_recovery_repository.ts:183-187,494-498`). A waiver-cleared transfer
keeps `outstanding_amount > 0` because the clearance contributor only *sums* and never zeroes
(`_shared/clearance/clearance_contributors.ts:31`) — a permanent defaulter ghost.
**Recommended fix** Add a student-status predicate to all three; close the finance assignment
and account as part of exit.
**Dependencies** XMOD-022 (exit orchestration).
**Risk of fixing** Medium — money. Existing accrued late fees on ex-students need a decision
(waive vs retain) before any cleanup.
**Evidence** the five paths above.

---

### XMOD-025 · P1 · SIS → Transport / Hostel / Library · Nothing is released when a student leaves

**Repro** Transfer a student out. Check the bus route allocation, the hostel room occupancy
and the library membership.
**Expected** Seat released, bed released, membership closed — and the driver told.
**Actual** All three persist. **Nobody tells the bus driver** — there is no code path that
could.
**Root cause** `stopStudentTransport` (`_shared/transport/transport_write_handlers.ts:553`) is
complete and correct — soft-stop, invoice cancel, dedupe-key release — but its **only** caller
is `DELETE /transport/allocations/{id}` (`:626-639`); no SIS path calls it. The only transport
notification in the codebase is `POST /transport/notify-delay` (`:666`). Hostel checkout
(`_shared/hostel/hostel_write_handlers.ts:156-194`) only flips the payload to `checkedOut`, and
`room.occupiedBeds` is incremented on assign (`:131,136`) and **never decremented** — the bed
is permanently consumed. Library has **no close/deactivate route** at all
(`_shared/library/library_router.ts:54,102` — only GET and POST members), so `status:"active"`
written at enrol (`_shared/library/library_write_handlers.ts:207`) is never changed. Inventory
distributions have no exit hook (`_shared/inventory_distribution/inventory_distribution_repository.ts:123-135`).
**Recommended fix** A single `deactivateStudent` orchestration invoked by every exit path,
calling the (already correct) transport stop, hostel checkout with a bed decrement, and a new
library-membership close; and notifying the route's driver/transport manager.
**Dependencies** XMOD-022. Requires a library close endpoint that does not exist.
**Risk of fixing** Medium-high — a cross-module cascade is exactly the kind of change that
needs maker-checker and a dry-run report first.
**Evidence** the six paths above.

---

### XMOD-026 · P1 · Academic · `sections.strength` is a counter nothing maintains

**Repro** Admit or transfer students in and out of a section. Read the section's strength.
**Expected** It tracks the roster.
**Actual** It shows whatever a human last typed.
**Root cause** `sections.strength` is a stored integer written only from the section
create/update request body — `_shared/academic/academic_handlers.ts:552,592`,
`_shared/academic/sections_repository.ts:229,269`. A repo-wide search finds **zero**
increment/decrement writers.
**Recommended fix** Derive it (`COUNT(*)` over current enrolments) as the dashboard headcount
already does correctly, or maintain it transactionally on enrol/exit.
**Dependencies** XMOD-022.
**Risk of fixing** Low.
**Evidence** as above; contrast `_shared/sis/sis_dashboard_repository.ts:101-108` (correct
live count).

---

### XMOD-027 · P1 · Intelligence · The Morning Brief cannot be seen by anyone

**Repro** Log in as a teacher or principal and look for the daily brief.
**Expected** A morning brief, as designed (`_shared/intelligence/briefs/brief_service.ts:1-23`).
**Actual** No surface exists. The backend is sound — T1 sections are computed live per request
(`brief_service.ts:176,186-191`), attendance is included for teachers
(`_shared/intelligence/priority/teacher_sources.ts:74-90,244`) — but **no client calls
`/intelligence/briefs/*`** (zero hits across `lib/` and `web/`), Flutter's own composer
`lib/core/dai/dai_brief.dart:22-30,140` has zero callers outside its own test, and there is no
pre-warm cron.
**Recommended fix** Either ship the client surface or mark the brief platform as out of scope
for v1 so it is not counted as a delivered feature.
**Dependencies** XMOD-016 for pre-warm (the T1 brief works without it).
**Risk of fixing** Low (removal) / medium (shipping a new persona surface).
**Evidence** `_shared/intelligence/briefs/brief_service.ts:176`;
`_shared/intelligence/intelligence_router.ts:81,84`; `lib/core/dai/dai_brief.dart:22-30`.

---

### XMOD-028 · P1 · Intelligence · Student-risk snapshots are stale until someone recomputes

**Repro** Let a student's attendance collapse. Open the principal's at-risk list.
**Expected** They appear.
**Actual** The list reflects whenever someone last pressed compute.
**Root cause** The read returns stored snapshots (`_shared/intelligence/intelligence_handlers.ts:92-98`);
recomputation happens only via `POST /intelligence/risk/students/compute` (`:139-152`). No cron.
**Recommended fix** Schedule the compute (XMOD-016) and stamp the list with its computed-at so
the UI can show freshness honestly.
**Dependencies** XMOD-016.
**Risk of fixing** Low.
**Evidence** as above.

---

### XMOD-029 · P1 · Exams / Analytics · Aggregates ignore publish state and AB/ML/DB

**Repro** Compare a class's pass rate on the management dashboard against the tabulation sheet.
**Expected** Identical — non-present students are excluded, unpublished exams are not counted.
**Actual** Pass rate under-reported; unpublished and unentered exams contribute.
**Root cause** Four aggregate surfaces omit both filters:
`_shared/management/management_aggregate_repository.ts:182,191,213,222` (`COUNT(*)` denominator
includes AB/ML/DB); `_shared/director/director_repository.ts:164-166,760-765` (no `published`,
no status); `_shared/intelligence/exam_intelligence_service.ts:96-101`
(`total_marks = count(*)`); `_shared/analytics/analytics_metrics_service.ts:33-38` (counts
unentered zeros as failures). The correct behaviour exists three times over — tabulation
(`_shared/academics/exam_administration/exam_administration_repository.ts:1436-1505`), backend
report card (`:2340-2394`), Flutter admin card (`lib/core/exams/exam_report_card.dart:222-227`).
**Recommended fix** Extract the present-only + published predicate into one shared SQL fragment
and use it in all seven places.
**Dependencies** XMOD-032 (unentered zeros).
**Risk of fixing** Low-medium — reported pass rates will move; that is the point.
**Evidence** the four sites above.

---

### XMOD-030 · P1 · Exams · Grading forks; the State-Board SSC scale is unreachable

**Repro** Configure a school on the State-Board SSC grading scale. Open a report card as an
admin, then as a parent.
**Expected** One scale, applied everywhere.
**Actual** The SSC preset cannot be selected at all, and the parent card silently uses the
`standard` scale regardless of the school's configuration.
**Root cause** Backend `gradeForPercent` (`_shared/academics/exam_administration/exam_administration_repository.ts:216-224`)
over `exam_grade_scales` is correctly shared. Flutter carries a **second** implementation
(`lib/core/exams/exam_grading.dart:37-42`), and inside Flutter the lookup forks: admin paths use
`store.reportSettings.gradingScale` (`lib/core/exams/exam_report_card.dart:227`,
`lib/features/.../exam_reports.dart:368`) while the **parent/student** card hardcodes
`ExamGradingScale.standard` (`exam_report_card.dart:179`). `stateBoardSsc`
(`exam_grading.dart:95-107`) is referenced only by its own declaration and the presets list
(`:113`) — no screen selects it and nothing PUTs `/academics/exams/grade-scale`.
**Recommended fix** Have the client consume the server-resolved `grade_letter` that publish
already bakes in (`exam_administration_repository.ts:966-971`) and delete the client-side
scale, or wire a real scale picker.
**Dependencies** None.
**Risk of fixing** Low-medium — grades shown to parents change where the school is not on
`standard`.
**Evidence** as above.

---

### XMOD-031 · P1 · Certificates · Library-blocked TC via the desk returns an opaque 500

**Repro** A student with an unreturned library book requests a TC through the Certificate Desk.
An approver approves it.
**Expected** `blocked_dues`, with the reason shown.
**Actual** HTTP 500, no explanation, and the approver cannot tell whether the approval took.
**Root cause** The desk's pre-flight checks **finance only**
(`_shared/certificate_desk/certificate_desk_approval_effect.ts:117-123`); the library throw at
`_shared/sis/sis_certificates_repository.ts:553` is deliberately not caught (`:136-141`), and
`mapApprovalError` has no branch for it (`_shared/approval/approval_handlers.ts:48-64`), so it
falls through to `throw error` at `:498`. The direct SIS route maps the same class of error
correctly to `409 DUES_PENDING` (`_shared/sis/sis_certificate_handlers.ts:225-229`).
**Recommended fix** Extend the desk pre-flight to the full clearance registry (XMOD-021) and
add a `mapApprovalError` branch.
**Dependencies** XMOD-021.
**Risk of fixing** Low.
**Evidence** as above.

---

### XMOD-032 · P1 · Exams · Mark slots are provisioned as 0, not NULL

**Repro** Schedule an exam. Before anyone enters a mark, open any exam analytics surface.
**Expected** "Not yet entered".
**Actual** Every student reads 0%, and every unfiltered average, pass rate and "weak topic"
computation treats it as a genuine score.
**Root cause** `provisionMarkSlots` inserts `marks_obtained = 0` with `marks_entered = false`
(`_shared/academics/exam_administration/exam_administration_repository.ts:434,439-440`). The
`marks_entered` flag exists but most aggregate consumers do not filter on it.
**Recommended fix** Provision `marks_obtained = NULL`; make every aggregate filter
`marks_entered = true`.
**Dependencies** Amplifies XMOD-005 and XMOD-029; fix together.
**Risk of fixing** Low-medium — a nullable column change plus a data backfill for
already-provisioned slots.
**Evidence** as above.

---

### XMOD-033 · P2 · Platform / Reminders · The shared reminder rail documents consumers it does not have

**Repro** Read `_shared/reminders/reminders_service.ts:10-20`, then grep for `scheduleReminder`.
**Expected** Documentation matches wiring.
**Actual** The header names eight consumers ("Homework HWK-8, library LIB-5, transport TRN-8,
inventory INV-7, upcoming exam EXM-6, communication COM-4, principal/parent digests PRI-5/PAR-5
and the Finance fee-reminder ladder"). Actual callers: **four** — exam administration
(`_shared/academics/exam_administration/exam_administration_handlers.ts:15`), transport
(`_shared/transport/transport_write_handlers.ts:20`), library
(`_shared/library/library_write_handlers.ts:14`), inventory-finance
(`_shared/inventory_finance/inventory_stock_handlers.ts:22`). Homework, communication digests
and finance are absent.
**Recommended fix** Correct the comment, or wire the missing consumers.
**Dependencies** XMOD-015 (finance ladder).
**Risk of fixing** Trivial (comment) / medium (wiring).
**Evidence** as above.

---

### XMOD-034 · P2 · Client / Reliability · Offline read cache is never invalidated by a mutation

**Repro** Offline, view a cached screen; perform a mutation that changes it; go online and let
the sync engine drain; return to the screen without pulling to refresh.
**Expected** The stale cached read is discarded once its underlying data changed.
**Actual** It is served until the same GET runs again and overwrites its own key.
**Root cause** The only caller of `deleteCache` in the whole app is the read interceptor
overwriting its own entry — `lib/core/network/interceptors/offline_read_cache_interceptor.dart:116`.
`ReliabilityStore` exposes `deleteCache`/`clearCache`
(`lib/core/reliability/store/reliability_store.dart:44,47`) and nothing in the sync engine calls
either.
**Mitigating** The freshness chip (`lib/shared/widgets/akshara_freshness_chip.dart`) surfaces
staleness honestly, which keeps this at P2.
**Recommended fix** Have the sync engine invalidate cache keys affected by a drained mutation.
**Dependencies** None.
**Risk of fixing** Low-medium — over-invalidation degrades the offline experience.
**Evidence** as above.

---

### XMOD-035 · P2 · SIS / Finance · Student 360 truncates paise on outstanding dues

**Repro** A student owes ₹1,234.56. Open Student 360.
**Expected** ₹1,234.56.
**Actual** ₹1,234 (or ₹1,235) — the value is cast `::int` from a `NUMERIC(12,2)` column.
**Root cause** `coalesce(sum(outstanding_amount), 0)::int AS pending_amount` —
`_shared/sis/student_360_service.ts:159-166`; column type
`supabase/migrations/20260612400000_finance_slice3_invoices.sql:17`.
**Recommended fix** Return the numeric as text and format client-side, as the finance mapper
does (`_shared/finance/finance_mapper.ts:342`).
**Dependencies** XMOD-014.
**Risk of fixing** Low.
**Evidence** as above.

---

### XMOD-036 · P2 · SIS · No exit date is recorded for a departed student

**Repro** Transfer a student out. Ask when they left.
**Expected** A date of leaving on the student record — a statutory field on Indian school
records.
**Actual** No such column exists anywhere in `supabase/migrations/` (searched
`exit_date|date_of_leaving|leaving_date`). The de-facto answer is `sis_certificate_issues.issued_at`,
which only exists if a TC was issued through the app.
**Recommended fix** Add `students.date_of_leaving`, set on every exit path.
**Dependencies** XMOD-022.
**Risk of fixing** Low (additive column).
**Evidence** `_shared/sis/sis_certificates_repository.ts:647-661`;
`supabase/migrations/20260849000000_sis_certificates.sql:28-38`.

---

### XMOD-037 · P2 · Finance · Receipts are randomly numbered unless a per-school flag is switched on

**Repro** Collect a fee on a fresh school. Look at the receipt number.
**Expected** A sequential, auditable receipt number.
**Actual** `RCPT-{year}-{random hex}`.
**Root cause** `receipts.receipt_sequencing` **defaults to `"false"`** —
`_shared/finance/finance_settings_repository.ts:47-52`. Gapless numbering is implemented and
correct (`_shared/finance/finance_collections_repository.ts:273-302`, in-transaction so a
rollback never burns a number) but is off out of the box.
**Recommended fix** Default it to `true` for new schools; keep the legacy path only for
existing tenants mid-year.
**Dependencies** None.
**Risk of fixing** Low — changing the default must not renumber existing receipts.
**Evidence** as above.

---

### XMOD-038 · P2 · HR · Staff attendance % does not use the canonical formula

**Repro** Compare a staff attendance percentage against the student attendance definition.
**Expected** One shared definition, or an explicit documented reason for two.
**Actual** `Math.round((presentCount / workingDays) * 100)` —
`_shared/hr/hr_reports_repository.ts:361` — ignores late and half-day entirely, and divides by
working days rather than marked days. Similarly `_shared/hr/hr_read_repository.ts:321`.
**Recommended fix** Reuse `attendedFromCounts`/`attendancePercentFromCounts`
(`_shared/attendance/attendance_percentage.ts:90-107`), or document the divergence in the
canonical file so the next reader does not assume it is a bug.
**Dependencies** XMOD-003 (leave must stop reading as absence first).
**Risk of fixing** Low.
**Evidence** as above.

---

### XMOD-039 · P2 · Certificates · No parent-facing certificate request surface

**Repro** As a parent, try to request a bonafide certificate.
**Expected** A request screen — the backend explicitly supports parent scope
(`_shared/certificate_desk/certificate_desk_handlers.ts:167-182`).
**Actual** None exists. The only surface is inside the admin shell
(`lib/router/app_router.dart:1560`), guarded by `Permission.requestStudentCertificate`
(`lib/router/route_guards.dart:36`). A search of `lib/features/parent` and
`lib/features/student_app` finds only the 80C fee certificate
(`lib/features/parent/fees/parent_fee_certificate_pdf_service.dart`). Staff must raise every
request on the parent's behalf.
**Recommended fix** Ship the parent request screen, or remove the parent scope from the backend
so the capability is not counted as delivered.
**Dependencies** XMOD-023 (delivery of the issued document).
**Risk of fixing** Low.
**Evidence** as above.

### CERT-001 · **P0** · Parent App · Fees & payment history

- **Repro steps:** Sign in as a parent on a release build (`config/live_release.json`,
  `PARENT_API_ENABLED=true`). Open **Fees** (`/parent/fees`). Cause `GET /parent/fees`
  to fail or return nothing (network drop, 5xx, tenant with no fee data).
- **Expected:** An honest error/empty state with a retry — the pattern already used by
  `studentDashboardProvider`, which falls back to `StudentDashboardData.empty()`.
- **Actual:** The screen renders `ParentFeesData.mock()` — a fabricated fee statement:
  ₹23,000 annual, ₹4,200 pending "Term 2", a tuition/transport/activity breakdown, and
  four "Paid" payment-history rows (`ph_1`…`ph_4`, ₹8,000 / ₹5,000 / ₹1,500 / ₹800).
  A real parent is shown money amounts and payment confirmations that do not exist.
- **Root cause:** `lib/features/parent/fees/fees_provider.dart:290-301` —
  `parentFeesProvider` = `watchRepositoryFuture(...) ?? future.value ?? ParentFeesData.mock()`.
  `watchRepositoryFuture` (`lib/core/providers/repository_future.dart:5-14`) returns
  `null` for BOTH loading and error, and `.value` is null on error, so the mock is the
  terminal fallback. The screen's error branch
  (`lib/features/parent/fees/parent_fees_screen.dart:42-69`) keys off
  `parentFeesErrorProvider`, a `StateProvider<bool>` that **no production code ever
  sets** — only `test/features/parent/parent_fees_screen_widget_test.dart:88` and
  `test/features/parent/qa_c_001_parent_app_behaviour_cert_test.dart:145` override it.
  The green "error state" tests therefore assert a state the live path cannot reach.
- **Recommended fix:** Replace the mock terminal fallback with an honest
  empty/error state driven by the real `AsyncValue` (mirror
  `studentDashboardProvider` → `StudentDashboardData.empty()`), and delete the
  manual `*LoadingProvider`/`*ErrorProvider` test hooks or wire them from the async
  state so the tests exercise the real path.
- **Dependencies:** none.
- **Risk of fixing:** low — an isolated provider change; the honest-state widget
  (`AksharaErrorState`) is already wired in the screen.
- **Evidence:** `lib/features/parent/fees/fees_provider.dart:106-210, 281-301`;
  `lib/features/parent/fees/parent_fees_screen.dart:42-97`;
  `lib/core/providers/repository_future.dart:5-14`;
  `lib/features/student_app/dashboard/student_dashboard_provider.dart:274-285`
  (the correct pattern).

### CERT-002 · **P1** · Parent App / Teacher App · Dashboard & homework

- **Repro steps:** Same as CERT-001 on `/parent/dashboard`, `/parent/homework`,
  `/teacher/dashboard` with the backing call failing.
- **Expected:** Honest error/empty state.
- **Actual:** Fabricated demo content is rendered as real: `ParentDashboardData.mock()`,
  `ParentHomeworkData.mock()`, `TeacherDashboardData.mock()` (fake children, fake
  homework items with due dates, fake class/period KPIs).
- **Root cause:** Identical terminal-mock fallback as CERT-001.
- **Recommended fix:** Same as CERT-001, applied to the three providers.
- **Dependencies:** shares a fix with CERT-001.
- **Risk of fixing:** low.
- **Evidence:** `lib/features/parent/dashboard/parent_dashboard_provider.dart:304-316`;
  `lib/features/parent/homework/parent_homework_provider.dart:21-33`;
  `lib/features/teacher/dashboard/teacher_dashboard_provider.dart:312-324`;
  screens at `parent_dashboard_screen.dart:39-40`, `teacher_dashboard_screen.dart:31-32`,
  `parent_homework_screen.dart:30-31` (all key off the never-set manual providers).

### CERT-003 · **P1** · Parent App · Fees → Receipt navigation

- **Repro steps:** Parent → Fees → tap any **payment-history** row, or tap
  "View receipt" on a paid installment, on a live build.
- **Expected:** Opens `/parent/receipts/<real receipt id>` for that payment.
- **Actual:** The router translates the tapped item id through a hard-coded demo map —
  `'ph_1' => 'rcpt_term_1'`, `'ph_2' => 'rcpt_ph_2'`, … else `'rcpt_${item.id}'`, and
  `_receiptIdForInstallment` maps `'term_1' => 'rcpt_term_1'`. With live data the ids
  are server-issued, so the synthesised `rcpt_<id>` will not resolve to a receipt.
- **Root cause:** `lib/router/app_router.dart:2353-2376` — demo-fixture id translation
  left in the production route builder. Contrast `parentReceiptsRouteBuilder`
  (`app_router.dart:2476-2483`), which correctly passes `receipt.id` straight through.
- **Recommended fix:** Carry the real receipt id on `PaymentHistoryItem` /
  `FeeInstallment` and pass it through unchanged; delete both id-translation maps.
- **Dependencies:** CERT-001 (the same screen's data source).
- **Risk of fixing:** low–medium — needs the receipt id present on the fee model.
- **Evidence:** `lib/router/app_router.dart:2340-2376`;
  `lib/features/parent/fees/fees_provider.dart:176-210` (source of the `ph_*` ids).

### CERT-004 · **P1** · Student App · Notifications bell is unreachable

- **Repro steps:** Sign in as a **student**. From the dashboard tap the notifications
  action, or tap the bell on any of Attendance / Timetable / Homework / Exams /
  Report card / Progress / Notices / Profile.
- **Expected:** The student's notifications inbox opens.
- **Actual:** The app navigates to `/parent/notifications` — a route the student does
  not own. `_canAccessRoute` resolves
  `isPersonaOwnedRoute(UserRole.student, '/parent/notifications')` → `false`, so
  `_authRedirect` bounces the user to `homeRouteForRole(student)` = `/student/dashboard`.
  The bell silently does nothing; the student can never read a notification, even
  though the backend surface is complete
  (`GET /student/notifications`, `POST /student/notifications/mark-read`,
  `/mark-all-read` in `supabase/functions/_shared/communication/communication_router.ts`).
- **Root cause:** `lib/router/app_router.dart:2678-2679` —
  `VoidCallback _studentNotificationsTap(BuildContext context) => () => context.push(RouteNames.parentNotifications);`
  and `lib/router/student_navigation.dart:36-37` (`case 'notifications': context.push(RouteNames.parentNotifications);`).
  This is the *same* bug that F-128 fixed for the teacher persona by adding a
  teacher-owned `/teacher/notifications` (`route_names.dart:66-69`); the student was
  never given the equivalent. The SEC P0-1 hardening of `isPersonaOwnedRoute` (which
  replaced bare `startsWith` with segment-precise ownership) is what turned the
  borrowed route from "works by accident" into "silently bounces".
- **Recommended fix:** Add `RouteNames.studentNotifications = '/student/notifications'`,
  register it in `app_router.dart` rendering the same role-neutral
  `NotificationsScreen` used by parent/teacher, and point `_studentNotificationsTap`
  and the `'notifications'` case in `handleStudentNavigation` at it.
- **Dependencies:** none — mirrors the existing teacher route exactly.
- **Risk of fixing:** low.
- **Evidence:** `lib/router/app_router.dart:2678-2732`, `2264-2295` (`_canAccessRoute`),
  `2211-2229` (`isPersonaOwnedRoute`); `lib/router/student_navigation.dart:36-37`;
  `lib/router/route_names.dart:66-69` (the teacher precedent);
  `supabase/functions/_shared/route_registry.ts:218-226`.

### CERT-005 · **P1** · Support (ASIP) · No user can reach "Report an issue"

- **Repro steps:** Sign in as any persona (parent, student, teacher, or any staff role).
  Look for a "Report an issue" / "Help & Support" affordance in Profile, Settings, the
  More sheet, the Admin Hub tile grid, the side rail, or the bottom nav. There is none.
  The only way in is to type `/support` as a deep link.
- **Expected:** A support entry point in at least one persona-reachable place — this is
  the school's only channel to the Akshara Support Team.
- **Actual:** `RouteNames.support` is referenced in exactly two places in `lib/`:
  its registration (`lib/router/app_router.dart:301`) and the permission map
  (`lib/router/route_guards.dart:66`). No widget anywhere calls `go`/`push` to it.
  `/support/new` and `/support/:id` are pushed only from inside
  `my_reported_issues_screen.dart` and `report_issue_screen.dart` — i.e. from the
  unreachable cluster itself, so they are second-order orphans.
- **Root cause:** The route was registered top-level and auth-gated
  (`_isSharedSettingsRoute`) so every persona *could* reach it, but no navigation
  affordance was ever added to any shell, profile screen or hub tile registry
  (`kAllAdminNavDestinations` in `lib/features/admin/admin_navigation_provider.dart:17-270`
  has no support entry).
- **Recommended fix:** Add a "Report an issue" entry to the shared settings/profile
  surface used by all four personas (alongside `/settings/appearance`, which is
  correctly reachable from parent/teacher/student profile and management settings),
  and an Admin Hub / side-rail entry for staff.
- **Dependencies:** none.
- **Risk of fixing:** low — the screens and the live backend already work.
- **Evidence:** `lib/router/app_router.dart:301-322`; `lib/router/route_guards.dart:66`;
  `lib/router/app_router.dart:2196-2208` (`_isSharedSettingsRoute` admits it for all
  personas); `lib/features/support/my_reported_issues_screen.dart:50,77,155`;
  `lib/features/support/report_issue_screen.dart:192`;
  `lib/features/admin/admin_navigation_provider.dart:17-270` (no support tile).
- **Note:** this is the reachability half of the RC-phase support finding. The data
  half (mock repository fabricating a `SUP-xxxx` reference) was fixed by adding
  `SUPPORT_API_ENABLED` to `config/live_release.json`; the surface is still
  unreachable, so the fix currently benefits nobody.

### CERT-006 · **P1** · HR · Reports screen shows a fabricated headline metric

- **Repro steps:** Sign in with `viewHr`. Open **HR → Reports** (`/hr/reports`) on a
  tenant whose `GET /hr/dashboard` response omits either the `total_employees` or the
  `avg_attendance` KPI (new school, partial data, or a failed KPI computation).
- **Expected:** No headline, or an honest "not available yet".
- **Actual:** The screen renders the hard-coded string
  `'142 active staff · 96.2% attendance MTD'` as if it were this school's data.
- **Root cause:** `lib/features/hr/reports/hr_reports_provider.dart:34` —
  `final headline = (activeStaff != null && attendance != null) ? '…' : HrReportsData.mock().headlineMetric;`
  with the constant at `lib/features/hr/hr_models.dart:628`.
- **Recommended fix:** Return a nullable headline and render an honest empty state when
  the KPIs are absent. (The report **catalog** on line 38 is also always the mock value,
  but that is a static list of report *types* — titles/descriptions/icons — which is
  legitimate configuration, not fabricated data.)
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** `lib/features/hr/reports/hr_reports_provider.dart:18-40`;
  `lib/features/hr/hr_models.dart:618-657`.
- **Severity note:** this meets the letter of the register's **P0** clause ("a false
  claim shown to a user"). Graded P1 because it is a single decorative headline rather
  than the report content or a money figure — flagging the judgement rather than hiding it.

---

<!-- ═══════════════════════════════════════════════════════════════════════
     DAI — Workstream 5, Digital Academic Intelligence (2026-07-29)
     Full trace: docs/certification/findings/DAI-certification.md
     Resolver behaviour below was EXECUTED (standalone harness over the
     shipping lib/core/dai/ source), not inferred. Router behaviour is derived
     from lib/router/app_router.dart guards — no device run (charter boundary).
     ═══════════════════════════════════════════════════════════════════════ -->

### DAI-004 · **P0** · DAI / Global search · Answer sentence claims a filter the destination never applies

- **Repro steps:** Sign in as principal. Open admin global search (search icon in the
  admin chrome). Type `students below 75% attendance`. A DAI card appears reading
  **"Showing students below 75% attendance."** Tap it.
- **Expected:** A list restricted to students below 75% attendance — or a sentence that
  does not promise one.
- **Actual:** You land on `/sis/students`, **the complete student roster with no
  attendance filter of any kind**. Nothing on the destination screen indicates a filter
  was requested and dropped. Same defect on every parameterised intent:
  `grade 10 fee defaulters` → "…for Class 10." → `/finance/defaulters` school-wide;
  `class 8a` → "Opening Class 8A students." → `/sis/students` unfiltered;
  `bus 5` → "Opening transport route 5." → `/transport/routes` full list.
- **Root cause:** `DaiResolver` extracts `className`, `section`, `threshold`,
  `routeNumber`, `receiptNumber` into the intent and interpolates them into `answer`
  (`lib/core/dai/dai_resolver.dart:139-148,161-171,180-190,277-287`), but the sole
  consumer navigates with the **bare route constant** —
  `context.go(_daiAnswer!.route!)` at
  `lib/features/admin/global_search/global_search_overlay.dart:170`. Every extracted
  parameter is discarded at the navigation boundary. The doc comment two lines below
  the offending call (`global_search_overlay.dart:277-278`) asserts the card "can never
  say something the system will not then do" — that invariant is not enforced anywhere.
- **Recommended fix:** Two options, in preference order. (a) Plumb the parameters:
  append query args and have the destinations honour them — the pattern already exists,
  `teacherAttendanceRouteBuilder` reads `?class=` at `lib/router/app_router.dart:2606`.
  (b) If (a) cannot be done for v1.0, weaken every sentence to match reality
  ("Opening the defaulters list — filter to Class 10 there") and add a resolver-level
  invariant test that fails when an intent carries an extracted field the route cannot
  consume. Do **not** ship (b) for `lowAttendance`: `/sis/students` cannot filter by
  attendance at all, so that intent should be re-pointed or withdrawn.
- **Dependencies:** none for (b). (a) needs a filter parameter on
  `FinanceDefaultersScreen`, the SIS student list and `TransportRoutesScreen`.
- **Risk of fixing:** low for (b); medium for (a) — touches four destination screens.
- **Evidence:** `lib/core/dai/dai_resolver.dart:111-125,128-149,152-172,175-191,273-288`;
  `lib/features/admin/global_search/global_search_overlay.dart:165-172,277-278`;
  `lib/router/finance_navigation.dart:96-100` (`return const FinanceDefaultersScreen();`
  — takes no argument); `lib/router/app_router.dart:2602-2612` (the parameter pattern
  that exists and is not used here).
- **Severity note:** graded **P0** under the standing rule. `lowAttendance` presents the
  full roster to a principal as the below-75% list. Attendance shortage drives exam
  eligibility and detention notices; a head of school acting on that screen acts on a
  false statement about attendance data that they cannot independently check from the
  screen they are looking at.

### DAI-001 · **P0** · DAI / Global search · "Today's attendance" passes the permission guard and then dead-ends

- **Repro steps:** Sign in as **principal** (`ErpRole.principal`, `UserRole.staff`, no
  `ErpRole.teacher` claim). Open admin global search. Type `today's attendance`. The DAI
  card renders: *"Opening today's attendance."* Tap it.
- **Expected:** Today's school attendance position.
- **Actual:** The sheet closes and the user is silently returned to `/admin`. No error,
  no explanation. The single most-typed principal query in the product produces a
  confident answer card that goes nowhere.
- **Root cause:** `_attendanceToday` routes to `RouteNames.teacherAttendance`
  (`/teacher/attendance`) — `lib/core/dai/dai_resolver.dart:203`. `_resolveDai` only
  checks the **permission** (`Permission.viewAttendance`), which `ErpRole.principal`
  **does hold** (`lib/core/security/role_permissions.dart:323,378`), so the card passes
  the filter and renders. On tap, `_authRedirect` → `_canAccessRoute`
  (`lib/router/app_router.dart:2125,2264`) finds `/teacher/attendance` is not an admin
  ERP route (verified: `RouteNames.adminErpRoutes` has 112 entries, none under
  `/teacher/`, `/student/` or `/parent/`) and applies the staff arm —
  `isPersonaOwnedRoute(UserRole.teacher, location) && claims.hasRole(ErpRole.teacher)`
  (`app_router.dart:2288-2289`) — which is false for a principal → redirect to
  `homeRouteForRole(staff)` = `/admin`.
- **Recommended fix:** Re-point `attendanceToday` at an admin-ERP attendance surface.
  `dai_brief.dart:216` already solved this exact problem for the same data
  (`RouteNames.managementAnalytics`, with the reasoning written out at
  `dai_brief.dart:211-216`) — reuse that destination and that reasoning. Then add a
  resolver invariant test asserting **every** `DaiIntent.route` is in
  `RouteNames.adminErpRoutes`, mirroring the assertion `dai_brief_test.dart` already
  makes for the brief.
- **Dependencies:** shares a root cause with DAI-002; fix together.
- **Risk of fixing:** low — a route constant change plus a test.
- **Evidence:** `lib/core/dai/dai_resolver.dart:194-212`;
  `lib/features/admin/global_search/global_search_overlay.dart:81-89,165-172`;
  `lib/router/app_router.dart:2264-2291`; `lib/core/security/role_permissions.dart:323,378`;
  `lib/core/dai/dai_brief.dart:211-216` (the same bug, already fixed in the dormant file).
- **Severity note:** graded **P0** as a core daily workflow that cannot complete from
  the surface that offers it, on the persona the surface exists for. It is not a data
  falsehood, so reviewers may argue P1 — the judgement is flagged rather than hidden.

### DAI-002 · **P1** · DAI / Global search · Four intents route outside the admin shell and silently bounce

- **Repro steps:** As any staff user, open admin global search and type each of:
  `pending homework` · `my exam schedule` · `my attendance` · `my fees`. A DAI card
  renders for all four. Tap any of them.
- **Expected:** No card for a destination this user cannot enter (the project already
  chose this remedy for the search registry — see the note below).
- **Actual:** Card renders → tap → bounce to `/admin`.
  `homework` → `/teacher/homework`; `exams`(own) → `/student/exams`;
  `myAttendance` → `/student/attendance`; `myFees` → `/parent/fees`.
- **Root cause:** All four carry `requiredPermission: null`
  (`dai_resolver.dart:225,240,250-255,263-268`), so the only guard in `_resolveDai`
  (`global_search_overlay.dart:86-87`) is a no-op for them. A **permission** cannot
  express "holds `ErpRole.teacher`", and staff can never enter `/student/*` or
  `/parent/*` at all under `_canAccessRoute` (`app_router.dart:2280-2290`).
- **Recommended fix:** Adopt the decision already recorded for the sibling surface.
  `lib/features/admin/global_search/global_search_registry.dart:193-212` (P1-7,
  2026-07-28) **removed** the Parent/Teacher/Student Dashboard entries for this exact
  reason, concluding "the correct fix is no tile rather than a tile that silently
  bounces". Apply the same conclusion: drop `myFees`/`myAttendance`/`exams(own)` from
  the admin-surfaced set and re-point `homework` at an admin-ERP homework surface (or
  drop it too). Enforce with the route-membership invariant test from DAI-001.
- **Dependencies:** DAI-001 (same root cause and same fix).
- **Risk of fixing:** low.
- **Evidence:** `lib/core/dai/dai_resolver.dart:215-228,231-244,247-257,260-270`;
  `lib/features/admin/global_search/global_search_overlay.dart:81-89`;
  `lib/router/app_router.dart:2264-2291`;
  `lib/features/admin/global_search/global_search_registry.dart:193-212`.

### DAI-003 · **P2** · DAI / Global search · Parent/student intents exist on a surface no parent or student can open

- **Repro steps:** Sign in as a parent. Try to reach the DAI card. There is no path.
- **Expected:** Either the parent/student intents are reachable by parents and students,
  or they are not built.
- **Actual:** `DaiResolver` has **one** production call site
  (`global_search_overlay.dart:83`), raised from **one** place —
  `lib/features/admin/admin_content_scaffold.dart:82`, the admin ERP chrome. Parent,
  teacher and student shells never build `AdminContentScaffold`. Three intents
  (`myFees`, `myAttendance`, `exams`(own)) and the whole "my child" vocabulary therefore
  serve personas that can never invoke them.
- **Root cause:** Surface placement, not resolver logic. The resolver was written for a
  cross-persona search; only the admin shell ever wired it.
- **Recommended fix:** Product decision. Either surface DAI in the parent/student/teacher
  shells (then DAI-002's routes become correct rather than broken), or remove the
  personal intents. Do not leave both halves in place.
- **Dependencies:** decides the shape of the DAI-002 fix.
- **Risk of fixing:** low to remove; medium to surface in three more shells.
- **Evidence:** `lib/features/admin/admin_content_scaffold.dart:82`;
  `lib/features/admin/global_search/global_search_overlay.dart:22-31,83`; no other
  reference to `DaiResolver` exists in `lib/`.

### DAI-005 · **P1** · DAI / Global search · `openPerson` — 1 of 12 intents — can never be shown

- **Repro steps:** Type `Rohan`, `teacher Ravi`, `staff Priya`, or any bare name. No DAI
  card ever appears, for any input, for any user.
- **Expected:** Either the intent surfaces, or the resolver does not claim to produce it.
- **Actual:** `openPerson` always sets `route: null` (by design —
  `dai_resolver.dart:332-339`), and `_resolveDai` discards any intent where
  `needsDirectoryLookup || route == null` (`global_search_overlay.dart:85`).
  `needsDirectoryLookup` is defined as `kind == openPerson && route == null`
  (`dai_intent.dart:126-127`), which is unconditionally true. The entire `openPerson`
  branch — the name extraction, the `DaiPersonHint` staff/student disambiguation, the
  `_nonNameTokens` rejection list, the `_titleCase` composer and every
  `'Looking for X…'` string — is **dead in production**.
- **Root cause:** The intent was designed to hand off to a directory lookup the consumer
  was never given. `AdaptiveSearchResults` (rendered directly beneath, line 175) does
  its own independent name search from the raw query and does not consume the intent's
  `personName` or `personHint` at all.
- **Recommended fix:** Either feed `personName`/`personHint` into `AdaptiveSearchResults`
  so the staff/student hint actually narrows the entity list (the useful outcome — the
  resolver already knows "teacher Ravi" means staff, and today that knowledge is thrown
  away), or delete the branch. Leaving ~60 lines of unreachable intent logic under test
  gives a false impression of coverage.
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** `lib/core/dai/dai_resolver.dart:290-350`; `lib/core/dai/dai_intent.dart:126-127`;
  `lib/features/admin/global_search/global_search_overlay.dart:85,175`.

### DAI-016 · **P1** · DAI / Global search · `_person` is a junk drawer — any unmatched short phrase becomes a confident person lookup

- **Repro steps:** Resolve `payroll`, `timetable`, `settings`, `alumni`, `notices`,
  `circular`, `apply leave`, `pending approvals`, `hostel rooms`, `library books issued`,
  `inventory stock`, `audit log`, `support ticket`, `fee structure`, `syllabus progress`,
  `lesson plan`, `urgent`, `help`, `summary`, `anything`, `defualters`, `feedefaulters`.
- **Expected:** `DaiIntentKind.unknown` — none of these is a person.
- **Actual:** All resolve to `openPerson` at confidence 60 with answers like
  *"Looking for Payroll…"*, *"Looking for Pending Approvals…"*,
  *"Looking for Support Ticket…"*. `add new student` resolves at confidence **88** to
  *"Looking for Add New…"*.
- **Root cause:** `_person` is the last rule and has no positive evidence requirement —
  it accepts any 1–3 token alphabetic residue (`dai_resolver.dart:295-340`). Its only
  rejections are digits, >3 words, <2 chars, and the 25-token `_nonNameTokens` list.
  Because it returns confidence 60 (≥ the 55 floor), `resolve()` returns it rather than
  `unknown`, so **the resolver's own contract — "never guesses" — is not met**; the user
  is protected only by the consumer discarding the result (DAI-005).
- **Recommended fix:** Require positive person evidence: an explicit qualifier
  (`teacher`/`student`/`staff`/…), or a capitalised token in the *raw* query, or a
  directory hit. Absent that, return `unknown`. This also unblocks DAI-007 — the system
  cannot say "I do not handle that" while `_person` is claiming everything.
- **Dependencies:** interacts with DAI-005 (if `openPerson` is ever surfaced, this
  becomes user-visible and jumps to P0-adjacent: a demo showing "Looking for Payroll…"
  is worse than showing nothing).
- **Risk of fixing:** low today (result is discarded); the fix is what makes DAI-005
  safe to implement.
- **Evidence:** `lib/core/dai/dai_resolver.dart:66-78,290-350`; harness output over 209
  queries, recorded in `docs/certification/findings/DAI-certification.md` §4.1, §5.

### DAI-006 · **P1** · DAI / Global search · "Ask anything" over-promises a 40-phrase keyword router

- **Repro steps:** Open admin global search. The field reads
  **"Ask anything — 'fee defaulters', 'Class 8A'…"**. Type any of the 27 module queries
  listed in the certification §5 (`pending approvals`, `who is on leave today`,
  `salary slip`, `send message to parents`, `admission enquiries`, …).
- **Expected:** Copy that sets the expectation the system can meet.
- **Actual:** Nothing happens — no card, no acknowledgement. DAI answers 7 of the
  inventory's 28 modules, three of those only partially. The two examples in the hint
  are the two things it does best, which makes the failure that follows feel like a bug
  rather than a boundary.
- **Root cause:** Copy written to the aspiration, not the implementation
  (`lib/features/admin/global_search/global_search_overlay.dart:137`).
- **Recommended fix:** Say what it does: *"Search or ask — 'fee defaulters',
  'Class 8A', 'bus 5'"*. A closed, well-executed vocabulary is a feature; claiming an
  open one and failing is not.
- **Dependencies:** pairs with DAI-007.
- **Risk of fixing:** trivial — one string.
- **Evidence:** `lib/features/admin/global_search/global_search_overlay.dart:135-139`;
  module coverage table in `docs/certification/findings/DAI-certification.md` §5.

### DAI-007 · **P1** · DAI / Global search · No "I cannot answer that" state — 21 of 28 modules fail silently

- **Repro steps:** Type `pending approvals` (Management), `salary slip` (HR),
  `admission enquiries` (Admissions), `send message to parents` (Communication) — the
  four modules a principal touches every morning.
- **Expected:** Either an answer, or an explicit acknowledgement that DAI does not
  handle that yet, so the user learns the boundary instead of concluding the product is
  broken.
- **Actual:** No DAI card. The user sees only the registry list, which matches on screen
  *titles* — so `pending approvals` surfaces nothing while an Approvals screen exists.
  DAI has **zero** coverage of M1, M2, M3, M7, M8 Admissions, M11 HR & Payroll,
  M12 Management, M14 Hostel, M15 Library, M16 Inventory, M18 Communication,
  M19 Intelligence, M20 Education, M21 PRC-A desks, M22 Alumni, M23 Control Center,
  M24 Director, M25 Multi-school, M26 Verticals, M27 Evolution.
- **Root cause:** `resolve()` returns `DaiIntent.unknown` and the consumer renders
  nothing (`global_search_overlay.dart:84`). There is no "understood the domain, no rule
  for it" tier between "confident answer" and "silence".
- **Recommended fix:** Add a small deterministic module-keyword map that renders a
  neutral card — *"I can't answer that yet. Opening Approvals."* — for domain terms with
  a known destination but no intent rule. Honest, still deterministic, and it converts
  the 21-module gap from a perceived defect into a stated boundary. Blocked by DAI-016
  until `_person` stops claiming these queries.
- **Dependencies:** DAI-016; pairs with DAI-006.
- **Risk of fixing:** low.
- **Evidence:** `lib/features/admin/global_search/global_search_overlay.dart:84,165-172`;
  `docs/certification/FEATURE_INVENTORY.md` module index M1–M28;
  probe results in `docs/certification/findings/DAI-certification.md` §5.

### DAI-009 · **P1** · DAI / Global search · Multi-intent and multi-scope queries silently drop half the question

- **Repro steps:** Type `fee defaulters and low attendance`. Then
  `fee defaulters class 8 and class 9`. Then `attendance and fees today`.
- **Expected:** Either both parts addressed, or an explicit "I answered the first part".
- **Actual:** Query 1 → `feeDefaulters` conf 90, *"Showing students with outstanding
  fees."* — the attendance half vanishes with no trace. Query 2 → conf **95**,
  *"…for Class 8."* — Class 9 dropped. Query 3 → `attendanceToday`, fees dropped.
  Confidence **rises** (90→95) on the query that drops more.
- **Root cause:** `resolve()` returns the first rule that clears the floor
  (`dai_resolver.dart:50-53`); rules never compete and no rule reports leftover input.
  `_classOf` (`:83-92`) takes the first regex match and ignores the rest of the string.
- **Recommended fix:** After a rule fires, check for a second rule that would also fire
  on the residue; when one exists, either lower confidence and say so ("Showing fee
  defaulters — attendance wasn't included") or offer two cards. Minimum viable fix:
  detect a second class match in `_classOf` and say "for Class 8 (first of 2 classes in
  your query)".
- **Dependencies:** none.
- **Risk of fixing:** low-medium.
- **Evidence:** `lib/core/dai/dai_resolver.dart:41-55,83-92`; harness output.

### DAI-010 · **P1** · DAI / Global search · `staff attendance today` opens *student* class attendance

- **Repro steps:** As principal or HR admin, type `staff attendance today`.
- **Expected:** HR staff attendance for today (`/hr/*`, M11 — the module that owns it).
- **Actual:** Resolves to `attendanceToday` conf 90, answer *"Opening today's
  attendance."*, route `/teacher/attendance` — the **student** class-attendance roster.
  Wrong module, and the sentence does not disclose which attendance it means. (It then
  also bounces, per DAI-001.) Related: `teacher attendance` resolves to `openPerson`
  → *"Looking for Attendance…"*.
- **Root cause:** `_attendanceToday` matches the bare word `attendance` plus a today
  word (`dai_resolver.dart:195-197`) with no staff/student discrimination; no rule
  covers HR staff attendance at all.
- **Recommended fix:** Add a staff-attendance discriminator (`staff`, `teacher`,
  `employee` + `attendance` → HR staff attendance) and make the student-attendance
  answer say "student attendance" explicitly.
- **Dependencies:** DAI-001 (destination must be an admin-ERP route either way).
- **Risk of fixing:** low.
- **Evidence:** `lib/core/dai/dai_resolver.dart:194-212,296`; harness output.

### DAI-011 · **P2** · DAI / Global search · `fee dues class 8` opens a class roster instead of the dues list

- **Repro steps:** Type `fee dues class 8`.
- **Expected:** Fee defaulters for Class 8.
- **Actual:** `openClass` conf 82 → *"Opening Class 8 students."* → `/sis/students`.
  A fee question confidently answered with a roster.
- **Root cause:** `_feeDefaulters` requires a fee word **and** a separate risk word
  (`dai_resolver.dart:129-131`). "dues" is classified only as a fee word, never as a
  risk word, so `fee dues` satisfies neither branch; the query falls through to
  `_classLookup`. `outstanding dues` works only because "outstanding" is on the risk
  list. Same shape: `who has not paid fees` → unknown; `fee collection this month`
  → unknown.
- **Recommended fix:** Put `dues`/`due` on the risk list as well as the fee list, and
  add negation phrasing (`not paid`, `unpaid by`, `yet to pay`).
- **Dependencies:** none.
- **Risk of fixing:** low — widening `_feeDefaulters` is safe because it is tried before
  `_classLookup` and `_person`.
- **Evidence:** `lib/core/dai/dai_resolver.dart:128-149,273-288`; harness output.

### DAI-012 · **P2** · DAI / Global search · Natural attendance phrasings fail

- **Repro steps:** Type `who is absent today` · `how many students are present today` ·
  `absentees today` · `low attendance students` · `poor attendance` ·
  `shortage of attendance` · `atendance below 75` (one typo).
- **Expected:** attendance intents.
- **Actual:** `who is absent today` and `how many students are present today` → unknown.
  The other four → dead `openPerson`. `atendance below 75` → unknown (no fuzzy match).
  "Attendance shortage" is the standard Indian-school term for exactly the report
  `lowAttendance` produces, and it does not resolve.
- **Root cause:** `_lowAttendance` requires a numeric threshold
  (`dai_resolver.dart:154-155`) so qualitative phrasings cannot match;
  `_attendanceToday` requires the literal word `attendance` (`:195`) so
  `absent`/`present`/`absentees` phrasings cannot match.
- **Recommended fix:** Accept qualitative low-attendance phrasings with a default
  threshold, state the default in the answer ("below 75% — the default threshold"), and
  add `absent`/`present`/`absentees` to the today-attendance trigger.
- **Dependencies:** DAI-004 (a stated threshold must actually be applied).
- **Risk of fixing:** low.
- **Evidence:** `lib/core/dai/dai_resolver.dart:152-172,194-212`; harness output.

### DAI-013 · **P2** · DAI / Global search · Alphanumeric receipt numbers cannot be resolved

- **Repro steps:** Type `receipt RCP-2024-19`. Then `receipt 1023`.
- **Expected:** Both resolve to `openReceipt`.
- **Actual:** `receipt 1023` works; `receipt RCP-2024-19` → **unknown**. Bare `receipt`
  → dead `openPerson` (*"Looking for Receipt…"*).
- **Root cause:** `_normalise` strips `-` to a space (`dai_resolver.dart:62`), then the
  capture group `(\w*\d[\w\d]*)` must start immediately after `receipt|no|number` and
  must contain a digit (`:113`). "rcp" has none, so the match fails and the whole rule
  returns null. Any prefixed receipt format is unresolvable.
- **Recommended fix:** Allow an optional alphabetic prefix and rejoin adjacent tokens
  (`receipt\s*#?\s*([\w-]*\d[\w-]*)`), matching on the raw query rather than the
  punctuation-stripped one. Confirm the tenant's actual receipt-number format first —
  the fixture data uses `rcpt_term_1`-style ids (`lib/router/app_router.dart:2350-2356`),
  which this rule also cannot parse.
- **Dependencies:** needs the live receipt-number format; not verifiable here (no
  Postgres lane, charter boundary).
- **Risk of fixing:** low.
- **Evidence:** `lib/core/dai/dai_resolver.dart:60-64,111-125`; harness output.

### DAI-008 · **P2** · DAI / Global search · The 55-confidence floor is unreachable dead code

- **Repro steps:** Inspect every `confidence:` literal in `dai_resolver.dart`.
- **Expected:** A meaningful floor — some inputs score below it and are rejected by it.
- **Actual:** The only values emitted are 60, 78, 82, 85, 88, 90, 92, 93, 94, 95. **No
  code path can produce 1–54**, so `hit.confidence >= minConfidence`
  (`dai_resolver.dart:52`) never rejects anything and the `minConfidence` guard in the
  `_person` doc contract is untestable. Actual rejection is done entirely by rules
  returning `null`.
- **Root cause:** Confidences are hand-assigned constants per rule rather than computed
  from match quality, so the floor and the scores were never connected.
- **Recommended fix:** Either compute confidence from evidence (token coverage, whether
  an entity was extracted, how much of the query went unconsumed) so the floor becomes
  live, or delete the floor and document that rejection is by rule. Do not keep a
  documented safety mechanism that cannot fire — `dai_resolver.dart:29-31` and
  `dai_intent.dart:119-120` both describe a branch that does not exist at runtime.
- **Dependencies:** a computed confidence would also give DAI-009 its ambiguity signal.
- **Risk of fixing:** medium if confidences become computed — the golden corpus pins
  exact values.
- **Evidence:** `lib/core/dai/dai_resolver.dart:36-39,50-54` and every `confidence:`
  literal at lines 122, 146, 169, 186, 207, 225, 241, 254, 267, 284, 330.

### DAI-014 · **P3** · DAI / Global search · No range validation on thresholds, class numbers or route numbers

- **Repro steps:** Type `students below 200% attendance` · `attendance below 0` ·
  `below -5% attendance` · `grade 0` · `class 99` · `bus 0`.
- **Expected:** Nonsense values rejected or clamped.
- **Actual:** All accepted verbatim. *"Showing students below 200% attendance."*
  *"Showing students below 0% attendance."* `below -5%` silently becomes **5** (the
  minus is stripped by `_normalise` and the sign is lost, inverting the meaning).
  `grade 0` → *"Opening Class 0 students."* `class 100` → unknown (the `\d{1,2}` bound),
  so the ceiling is arbitrary rather than domain-derived.
- **Root cause:** `_thresholdOf` (`dai_resolver.dart:95-103`) and `_classOf` (`:83-92`)
  parse with no domain bounds.
- **Recommended fix:** Clamp threshold to 1–100 and class to 1–12 (or the tenant's
  configured grade range); return null outside. Low user impact today because DAI-004
  means the number is discarded anyway — but that will stop being true when DAI-004 is
  fixed, at which point a 200% filter reaches a real query.
- **Dependencies:** should be fixed **with** DAI-004, not after.
- **Risk of fixing:** low.
- **Evidence:** `lib/core/dai/dai_resolver.dart:83-103`; harness output.

### DAI-015 · **P3** · DAI / Global search · Person rule is ASCII-only and caps at three tokens

- **Repro steps:** Resolve `Rohan Sharma Kumar Verma` (4 tokens) and `रोहन`.
- **Expected:** Both recognised as person queries.
- **Actual:** Both → **unknown**. Four-token names exceed the `words.length > 3`
  rejection (`dai_resolver.dart:314`); Devanagari input is stripped to empty by
  `_normalise`'s `[^\w\s%]` (`:62`), because Dart's `\w` is ASCII-only without the
  unicode flag. `Mary-Anne` → "Mary Anne", `D'Souza` → "D Souza".
- **Root cause:** ASCII-oriented normalisation and a heuristic token cap.
- **Recommended fix:** Raise the cap to 4–5 tokens (four-part names are common in
  Indian schools) and use a unicode-aware character class. Consistent with the
  English-first product decision, non-Latin *queries* are out of scope — but non-Latin
  *names* may still exist in SIS records, so the boundary should be a decision rather
  than an accident of regex.
- **Dependencies:** DAI-005 — worth nothing until `openPerson` surfaces.
- **Risk of fixing:** low.
- **Evidence:** `lib/core/dai/dai_resolver.dart:60-64,308-320`; harness output.

<!-- ═══════════════════════════════════════════════════════════════════════
     JOURNEY — Workstream 3, Complete role journeys (2026-07-29)
     Full trace: docs/certification/findings/JOURNEY-role-journeys.md
     ═══════════════════════════════════════════════════════════════════════ -->

### JOURNEY-001 · **P0** · Admin shell / Admin Hub · Landing hero shows fabricated attendance and money

- **Repro steps:** Sign in as any staff role and open `/admin` (the post-login
  landing for superAdmin, schoolAdmin, management, admissionsCounselor,
  transportManager, hostelManager, librarian, storekeeper). Do it on a brand-new
  tenant with zero students, zero staff, zero fee collections.
- **Expected:** Either real per-workspace figures, or no figures at all.
- **Actual:** The `AksharaWorkspaceLanding` hero renders compile-time constants as
  if they were live KPIs. School Administration: **"1,248 Students · 86 Staff ·
  96% Attendance"**. Finance: **"₹4.2L Collected today · ₹1.8L Pending · 92% This
  month"**. Library: "8,450 Titles · 214 On loan · 7 Overdue". Hostel: "312
  Residents · 96 Rooms · 88% Occupancy". Transport: "18 Routes · 22 Buses · 97%
  On-time". Front Office: "23 Open enquiries · 14 Admissions · 9 Visitors today".
  Inventory: "642 SKUs · 12 Low stock · 38 Issued today". Nothing in the UI marks
  them as demo data.
- **Root cause:** `lib/features/admin/workspace_landing_config.dart:27-84` is a
  `const Map<WorkspaceId, WorkspaceLandingConfig>` of hard-coded
  `AksharaWorkspaceStat` values; `lib/features/admin/screens/admin_hub_screen.dart:39-63`
  passes `landing?.stats` straight into the hero, which renders them whenever the
  list is non-empty (`shared/widgets/premium/akshara_workspace_landing.dart:85-94`).
  The file's own comment concedes it: *"Stats are curated demo figures consistent
  with the seeded school so demos read as live."*
- **Recommended fix:** Delete the `stats` from `kWorkspaceLandingConfig` (keep the
  motif/eyebrow) so the hero renders name-only until real per-workspace summary
  providers exist — the widget already accepts an empty list and the hub already
  handles `landing == null`. Do **not** substitute a different constant.
- **Dependencies:** none. Independent of CERT-001/002.
- **Risk of fixing:** very low — removal only, no data path involved.
- **Evidence:** `lib/features/admin/workspace_landing_config.dart:5-12,27-84`;
  `lib/features/admin/screens/admin_hub_screen.dart:28-63`;
  `lib/shared/widgets/premium/akshara_workspace_landing.dart:85-94`;
  `lib/core/workspace/workspace.dart:177-193` (which role maps to which workspace).

### JOURNEY-002 · **P0** · Auth / RBAC · An unrecognised server role is mapped to Super Admin

- **Repro steps:** Assign a user a server role the client enum does not contain —
  e.g. `officeStaff`, `hrManager`, `healthStaff`, `classTeacher`, `coordinator`,
  `counselor`, `financeManager`, `marketingManager`, `petTeacher`, `danceTeacher`,
  `musicTeacher`, `organizationOwner`, `organizationAdmin`, `schoolGroupDirector`
  (all seeded in `supabase/migrations/20260608100000_rbac_foundation.sql:166-193`,
  `20260851000000_…:33`, `20260887000000_student_health.sql:42`). Log in on a live
  build. Inspect the session claims and open `/admin/plan/assign`.
- **Expected:** An unknown role fails **closed** — least privilege, or an explicit
  "your role is not supported by this app version" state.
- **Actual:** The client resolves the role to **`ErpRole.superAdmin`**. The
  session's `claims.erpRoles` becomes `[superAdmin]`, so the user is placed in the
  School Administration workspace, shown the school-administration hero
  (JOURNEY-001), and passes every **role-keyed** gate. The most consequential is
  `canAssignOrganizationPlansProvider`, which is role-only with no permission
  conjunct — the organization plan-assignment screen and its Save action render
  for an office clerk or a school nurse. (Control Center is **not** exposed: both
  `ControlCenterGuard` and `RbacModuleRegistry.canAccessControlCenter` AND the
  role check with `viewControlCenter`.)
- **Root cause:** `lib/core/repositories/api/auth/mapper/auth_mapper.dart:63-66`
  — `erpRole: ErpRole.fromName(raw['role'] ?? raw['erpRole']) ?? ErpRole.superAdmin`.
  Repeated at `lib/core/auth/auth_session_manager.dart:172`. That value is copied
  verbatim into the session claims at `lib/features/auth/auth_provider.dart:309-311`.
  The backend sends a single `role: ctx.resolved.primaryRole` slug
  (`supabase/functions/_shared/auth_handlers.ts:126`) drawn from a 29-value server
  vocabulary against a 15-value client enum (`lib/core/security/erp_role.dart:2-17`).
- **Recommended fix:** Make the fallback fail closed. Introduce an explicit
  `ErpRole.unknown` (or make `AuthUser.erpRole` nullable) that grants no
  workspace, no role-keyed gate, and renders a clear "role not supported" state.
  Separately, add the missing school roles (`hrManager`, `officeStaff`,
  `healthStaff`, `classTeacher`, `coordinator`) to the enum and to
  `kRoleWorkspaces`. Add a permission conjunct to
  `canAssignOrganizationPlansProvider`.
- **Dependencies:** JOURNEY-003 (the contradictory second fallback must be fixed
  in the same change). JOURNEY-012 / JOURNEY-013 / JOURNEY-014 are the missing
  roles this defect exposes.
- **Risk of fixing:** medium. Failing closed will lock out any live user currently
  benefiting from the accidental super-admin mapping, so the enum additions must
  ship in the same release, and a live audit of assigned role slugs is needed
  first (not possible in this harness — SSH is owner-bound).
- **Evidence:** `lib/core/repositories/api/auth/mapper/auth_mapper.dart:56-72`;
  `lib/core/auth/auth_session_manager.dart:172`;
  `lib/features/auth/auth_provider.dart:303-320`;
  `lib/core/entitlements/subscription_admin_provider.dart:15-18`;
  `lib/core/workspace/workspace.dart:177-193`;
  `supabase/functions/_shared/auth_handlers.ts:119-138`;
  `supabase/migrations/20260608100000_rbac_foundation.sql:166-193`.

### JOURNEY-003 · **P1** · Auth · Two contradictory fallbacks for the same unknown role

- **Repro steps:** Compare the role resolved on the login path with the role
  resolved when a persisted session is rehydrated from JSON, for the same
  unrecognised slug.
- **Expected:** One deterministic answer.
- **Actual:** Login → `ErpRole.superAdmin`
  (`api/auth/mapper/auth_mapper.dart:63-66`). Session restore →
  `roles.add(ErpRole.fromName(json['role']) ?? ErpRole.parent)`
  (`lib/features/auth/auth_claims.dart:126-132`) — **`ErpRole.parent`**. The same
  user is a super admin in one code path and a parent in the other, which also
  means their workspace, landing route and hub tiles change between a fresh login
  and an app relaunch.
- **Root cause:** the fallback was written independently in two places, in
  opposite directions.
- **Recommended fix:** one shared resolver, failing closed (see JOURNEY-002).
- **Dependencies:** JOURNEY-002 — fix together.
- **Risk of fixing:** low once JOURNEY-002 defines the closed default.
- **Evidence:** `lib/features/auth/auth_claims.dart:107-145`;
  `lib/core/repositories/api/auth/mapper/auth_mapper.dart:63-66`.

### JOURNEY-004 · **P1** · Router · Post-login landing is an unfinished switch; six roles land on a launcher

- **Repro steps:** Sign in as librarian, transportManager, hostelManager,
  storekeeper, admissionsCounselor and management in turn.
- **Expected:** A single-module role lands in that module; a role that owns a
  dashboard lands on it.
- **Actual:** All six land on `/admin`. For librarian, transportManager,
  hostelManager and storekeeper the resulting tile grid contains **exactly one
  tile** — a one-item menu that costs a wasted screen and a wasted tap on every
  sign-in. `management` lands on `/admin` despite holding `viewManagement` and
  despite principal/vicePrincipal being routed to `/management/dashboard`.
  `storekeeper` and `inventoryManager` share the Inventory workspace and the same
  single module, yet `inventoryManager` is routed straight to
  `/inventory/dashboard` and `storekeeper` is not.
- **Root cause:** `homeRouteForStaffErp`
  (`lib/features/auth/qa_login_persona.dart:207-216`) enumerates only 5 of 15
  roles and sends the rest to `RouteNames.admin` via `_ =>`.
- **Recommended fix:** Derive the landing from the resolved workspace's
  `homeRoute` (`lib/core/workspace/workspace.dart:45,60-172` — every workspace
  already declares one) instead of a hand-written switch. That gives
  librarian → `/library/dashboard`, transport → `/transport/dashboard`,
  hostel → `/hostel/dashboard`, storekeeper → `/inventory/dashboard`,
  admissionsCounselor → `/admissions/dashboard`, and keeps `/admin` only for the
  multi-module School Administration workspace.
- **Dependencies:** none.
- **Risk of fixing:** low. Multi-hat users already land on their primary
  workspace's home by the same rule.
- **Evidence:** `lib/features/auth/qa_login_persona.dart:207-216`;
  `lib/router/app_router.dart:2295-2311`; `lib/core/workspace/workspace.dart:59-193`;
  `lib/features/admin/admin_navigation_provider.dart:325-337`.

### JOURNEY-005 · **P1** · Admin Hub · No empty state when the tile grid resolves to nothing

- **Repro steps:** Sign in as a user whose permissions unlock no workspace module
  — the seeded `officeStaff` role holds only `viewAdminHub`
  (`supabase/migrations/20260608100000_rbac_foundation.sql:238`). Open `/admin`.
- **Expected:** A message explaining that no modules are available and what to do
  (contact the school admin), or a route to the surfaces they can reach.
- **Actual:** The hero renders (with its fabricated stats, JOURNEY-001), the
  subtitle says *"Jump to a module you are authorized to access"*, and beneath it
  the `Wrap` renders zero children — a blank area with no explanation. The
  drawer, which is **not** workspace-scoped, does list what they can open, but
  nothing on screen points there.
- **Root cause:** `lib/features/admin/screens/admin_hub_screen.dart:86-97` has no
  `modules.isEmpty` branch; `:29-31` additionally strips `AdminModule.admin`, so a
  single-permission user always ends at zero.
- **Recommended fix:** Add an `AksharaEmptyState` branch naming the situation and
  offering the drawer / support contact. The product already has honest empty
  states to copy (`teacher_attendance_screen.dart:420-437`).
- **Dependencies:** worsened by JOURNEY-008 (six live modules are stripped from
  this grid for everyone).
- **Risk of fixing:** very low.
- **Evidence:** `lib/features/admin/screens/admin_hub_screen.dart:28-99`;
  `lib/features/admin/admin_navigation_provider.dart:277-337`.

### JOURNEY-006 · **P2** · Admin shell · Phone bottom-nav tabs are chosen by declaration order

- **Repro steps:** Sign in as principal or schoolAdmin on a phone-width layout.
  Read the four bottom-nav tabs.
- **Expected:** The four surfaces that role opens most.
- **Actual:** **Admin Hub · Admissions · Marketing · Finance** — the first four
  entries of `kAllAdminNavDestinations`. Management, SIS, Exams, HR and the
  approval queue are all two taps away behind "More", while Marketing (an
  entitlement-gated growth module that may render *locked*) holds a permanent slot.
- **Root cause:** `lib/features/admin/admin_bottom_nav.dart:31,50` —
  `destinations.take(_maxTabs)` over a list whose order is the source-file order
  of `kAllAdminNavDestinations` (`admin_navigation_provider.dart:17-274`).
- **Recommended fix:** Give `AdminNavDestination` an explicit priority/rank used
  for tab selection, or order per workspace. Locked destinations should never
  occupy a primary slot.
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** `lib/features/admin/admin_bottom_nav.dart:31-60`;
  `lib/features/admin/admin_navigation_provider.dart:17-49,294-301`.

### JOURNEY-007 · **P0** · Parent App · Fee-payment screen fabricates the amount, the child and the due date

- **Repro steps:** As a parent on a live build, open Fees → **Pay now** (or deep
  link `/parent/payment?installmentId=...`) while `GET /parent/payments/summary`
  fails or returns nothing — e.g. a brand-new school with no fee structure
  assigned, or any backend error.
- **Expected:** An honest error/empty state. Never a payable amount the school
  has not raised.
- **Actual:** The screen renders a complete fabricated payment summary — child
  **"Ravi Kumar"**, class **"8-A"**, *"Due 12 Jun 2026"*, base ₹4,000 + late fee
  ₹200 = **₹4,200**, with a four-line breakdown (Tuition ₹3,200 / Transport ₹600 /
  Activity ₹200 / Late fee ₹200). The app bar subtitle shows that other child's
  name and class. If the parent proceeds, `submitParentPayment` sends
  `amount: summary.totalAmount` — the fabricated ₹4,200 — to
  `POST /parent/payments/initiate`.
- **Root cause:** `lib/features/parent/payment/parent_payment_provider.dart:63`
  — `return data ?? async.value ?? _fallbackSummary(installmentId);` with
  `_fallbackSummary` (`:66-101`) returning hard-coded demo `PaymentSummary`
  objects. `watchRepositoryFuture` returns null for anything that is not
  `AsyncData` (`lib/core/providers/repository_future.dart:12-13`) and
  `AsyncError.value` is null, so the fallback is the **production** path on
  failure and while loading. The screen's `hasError` branch is driven by
  `parentPaymentErrorProvider`, a `StateProvider<bool>` set only by
  `test/features/parent/payment/parent_payment_provider_test.dart:62` — the same
  false-premise error-state pattern as CERT-001/CERT-002. The amount is then fed
  to the initiate mutation at `:134-145`.
- **Recommended fix:** Delete `_fallbackSummary`. Make `parentPaymentSummaryProvider`
  return `AsyncValue<PaymentSummary>` (or null) and let the screen render a real
  error/empty state; refuse to enable the pay action without a server-issued
  summary. Mirror `StudentDashboardData.empty()`
  (`student_dashboard_provider.dart:274-285`), the correct in-tree pattern.
  Keep the existing fail-closed `pendingGatewayVerification` state — that part is
  right.
- **Dependencies:** same family as CERT-001 (`/parent/fees`) and CERT-003
  (receipt-id mapping); JOURNEY-015 is the entry point that reaches it.
- **Risk of fixing:** low — removal plus an honest state; no server change.
- **Evidence:** `lib/features/parent/payment/parent_payment_provider.dart:39-101,120-150`;
  `lib/features/parent/payment/parent_payment_screen.dart:52-104`;
  `lib/core/providers/repository_future.dart:5-14`.

### JOURNEY-008 · **P1** · Admin shell · Five live school modules can never appear on the Admin Hub

- **Repro steps:** Sign in as any staff role holding `requestStudentCertificate`,
  `requestGatePass`, `raiseComplaint`, `viewStudentHealthRecord` or `viewSubjects`
  (server-seeded — principal, vicePrincipal, schoolAdmin, officeStaff…). Open
  `/admin` and look for Certificates / Gate Pass / Complaints / Infirmary /
  School Completion. Then open the drawer.
- **Expected:** A module the user is authorized to access appears on the hub the
  hub's own subtitle promises ("Jump to a module you are authorized to access").
- **Actual:** None of the five appears on the hub tile grid or (on a phone) the
  bottom nav. They appear **only** in the nav rail / drawer. Org Builder is in the
  same position.
- **Root cause:** the hub (`admin_hub_screen.dart:28`) and the bottom nav
  (`admin_bottom_nav.dart:47`) read `workspaceScopedNavDestinationsProvider`,
  which keeps a destination only if `workspace.containsModule(...)`
  (`admin_navigation_provider.dart:325-337`). `AdminModule.certificateDesk`,
  `gatePass`, `complaints`, `studentHealth`, `schoolCompletion` and
  `organizationBuilder` are absent from **every** `Workspace.modules` set in
  `lib/core/workspace/workspace.dart:59-173`. The rail
  (`admin_navigation_rail.dart:56`) reads the un-scoped
  `adminNavDestinationsProvider`, so the three surfaces disagree.
- **Recommended fix:** Add the five school desks to
  `WorkspaceId.schoolAdministration.modules` (and `schoolCompletion` too), create
  a front-office workspace membership for the desks, and make all three nav
  surfaces read one provider so they cannot drift again. A router/nav invariant
  test should assert that every non-hidden `AdminModule` belongs to at least one
  workspace.
- **Dependencies:** JOURNEY-005 (this is why some users reach zero tiles),
  JOURNEY-013 (the office role these desks were built for).
- **Risk of fixing:** low-medium — widening a workspace changes which tiles each
  role sees; permission filtering still applies on top.
- **Evidence:** `lib/features/admin/screens/admin_hub_screen.dart:28`;
  `lib/features/admin/admin_bottom_nav.dart:47`;
  `lib/features/admin/admin_navigation_rail.dart:56`;
  `lib/features/admin/admin_navigation_provider.dart:277-337`;
  `lib/features/admin/models/admin_nav_models.dart:6-38`;
  `lib/core/workspace/workspace.dart:59-173`. Note this refutes
  `FEATURE_INVENTORY.md` §3e, which lists all five as tile-reachable.

### JOURNEY-009 · **P2** · Management · Dashboard filter chips hard-code the financial year

- **Repro steps:** Open `/management/dashboard` in any year other than FY 2026-27.
- **Expected:** The filter reflects the tenant's configured academic/financial year.
- **Actual:** The chips are the constant list `['FY 2026-27', 'Q1', 'All quarters']`.
- **Root cause:** `lib/features/management/dashboard/management_dashboard_screen.dart:32-36`.
- **Recommended fix:** Derive from the active academic year
  (`GET /academic/years`), which the product already models.
- **Dependencies:** none. **Risk of fixing:** low.
- **Evidence:** `lib/features/management/dashboard/management_dashboard_screen.dart:32-36`.

### JOURNEY-010 · **P1** · Teacher App · Tapping a student on the class-teacher dashboard bounces the teacher to Home

- **Repro steps:** Sign in as a **class teacher**. Open
  `/teacher/class-teacher-dashboard`. Under "Students requiring attention", tap a
  student row (a normal tap, not a long-press). Also: open a student risk dossier
  and press **"Open Student 360"**.
- **Expected:** The student's dossier opens.
- **Actual:** The router silently redirects to `/teacher/dashboard`. No message,
  no Access Denied — the teacher is simply thrown back Home.
- **Root cause:** both call sites use `openStudent360`
  (`teacher_class_teacher_dashboard_screen.dart:122`,
  `teacher_student_risk_screen.dart:170-177`) → `context.push('/student-360/<id>')`
  (`lib/router/student360_navigation.dart:6-10`). `student360` is listed in
  `RouteNames.adminErpRoutes:644`, so `_canAccessRoute`
  (`lib/router/app_router.dart:2273-2275`) defers to `canAccessAdminErpShell`,
  which requires `auth.role == UserRole.staff` (`route_guards.dart:271-273`); a
  teacher is `UserRole.teacher`. `_authRedirect:2125-2127` then returns
  `homeRouteForRole(UserRole.teacher)`. The "Open Student 360" button is wrapped
  in `AksharaViewAction(permission: Permission.viewStudent360)` and the teacher
  **does** hold that permission (`role_permissions.dart:665`), so the button
  renders and then bounces — the permission and the shell wall disagree. The
  working route `/teacher/student-risk/:id` is bound to `onLongPress` only.
- **Recommended fix:** Same remedy already applied to lesson logs and syllabus
  progress (`teacher_shell.dart:74-81`): give the teacher shell a
  `/teacher/student-360/:id` sibling rendering `Student360Screen`, and point
  `openStudent360` at it when `auth.role == UserRole.teacher`. Failing that, hide
  the affordance for teachers. Promote the long-press destination to the tap.
- **Dependencies:** none. Same root cause class as the 15 teacher permissions that
  unlock only admin-shell routes.
- **Risk of fixing:** low.
- **Evidence:** `lib/features/teacher/dashboard/teacher_class_teacher_dashboard_screen.dart:116-127`;
  `lib/features/teacher/student_risk/teacher_student_risk_screen.dart:169-177`;
  `lib/router/student360_navigation.dart:6-10`; `lib/router/route_names.dart:644`;
  `lib/router/app_router.dart:2264-2292`; `lib/router/route_guards.dart:271-273`;
  `lib/core/security/role_permissions.dart:643-679`.

### JOURNEY-011 · **P1** · Finance / Transport · The daily money and operations screens are in the phone sub-nav overflow

- **Repro steps:** On a phone, sign in as financeAdmin and try to record a counter
  payment. Then sign in as transportManager and try to allocate a student to a
  route or mark bus attendance.
- **Expected:** The action a role performs dozens of times a day is at most one
  tap from its landing screen.
- **Actual:** Finance: **Collections** (which owns the "Record collection" dialog)
  and **Offline Payments** are the 5th and 6th sub-nav entries, so both fall into
  the "More" bottom sheet — 3 taps to the money-taking dialog, while Fee
  Structures (annual configuration) holds a permanent inline slot. The finance
  dashboard has no "Record collection" action of its own. Transport: **Allocation**
  and **Attendance** are the 5th and 6th entries and overflow the same way, while
  Vehicles and Drivers (registry screens) stay inline.
- **Root cause:** `AksharaModuleSubNav.maxInlineOnMobile = 4`
  (`lib/shared/widgets/akshara_navigation.dart:296,319-334`) applied to
  frequency-agnostic orderings — `kFinanceNavScreens`
  (`lib/features/finance/finance_navigation.dart:6-21`) and `kTransportNavScreens`
  (`lib/features/transport/transport_navigation.dart:6-16`).
- **Recommended fix:** Reorder both lists by daily frequency (Finance: Dashboard ·
  Collections · Offline Payments · Defaulters; Transport: Dashboard · Allocation ·
  Attendance · Tracking), and add a primary "Record collection" action to the
  finance dashboard.
- **Dependencies:** none.
- **Risk of fixing:** very low — list reordering; routes unchanged.
- **Evidence:** `lib/shared/widgets/akshara_navigation.dart:287-345`;
  `lib/features/finance/finance_navigation.dart:6-21`;
  `lib/features/finance/collections/finance_collections_screen.dart:116-120`;
  `lib/features/finance/dashboard/finance_dashboard_screen.dart:58-149`;
  `lib/features/transport/transport_navigation.dart:6-16`.

### JOURNEY-012 · **P1** · RBAC · There is no HR role; payroll can only be run by the principal or a school admin

- **Repro steps:** Try to give a school's HR manager access to HR/payroll and
  nothing else.
- **Expected:** An HR role exists.
- **Actual:** `ErpRole` has no HR value. `viewHr`/`manageHr` are held only by
  superAdmin, schoolAdmin, principal, vicePrincipal and management — so running
  payroll requires handing someone a 105–138-permission account that also opens
  every student record, every fee ledger and the approval queue. The server
  already seeds a correct narrow role (`hrManager` → `viewAdminHub`, `viewHr`,
  `manageHr`, `20260608100000_rbac_foundation.sql:228`); assigning it triggers
  JOURNEY-002 instead. The code documents the gap itself:
  *"HR and Director have no dedicated ErpRole"* (`qa_login_persona.dart:17-19`).
- **Root cause:** client `ErpRole` enum was never extended to the server role set.
- **Recommended fix:** Add `ErpRole.hrManager` with a `RolePermissionMatrix` entry
  matching the server grants, a `kRoleWorkspaces` entry (a new HR workspace, or
  School Administration scoped to `{admin, hr, employee}`), and a landing route.
- **Dependencies:** JOURNEY-002 (fallback), JOURNEY-004 (landing).
- **Risk of fixing:** low-medium.
- **Evidence:** `lib/core/security/erp_role.dart:2-17`;
  `lib/core/security/role_permissions.dart` (`viewHr` holders);
  `lib/features/auth/qa_login_persona.dart:16-19,68`;
  `supabase/migrations/20260608100000_rbac_foundation.sql:176,228`.

### JOURNEY-013 · **P1** · RBAC / Front office · No Office Staff or Reception role; the desks built for them are unreachable

- **Repro steps:** Try to give a school's front-desk clerk exactly the front-office
  job — raise certificate requests, issue gate passes, log complaints, handle
  visitors.
- **Expected:** A front-office role that lands on those desks.
- **Actual:** *Reception* exists in no layer at all. *Office Staff* exists only
  server-side (`officeStaff`) and is granted `viewAdminHub`,
  `requestStudentCertificate` and `approveCertificateRequest` — nothing for gate
  passes, complaints or visitors. Client-side the role does not exist, so the
  clerk is mapped to `superAdmin` (JOURNEY-002), lands on `/admin`, sees the
  fabricated school hero (JOURNEY-001) and an **empty tile grid** with no empty
  state (JOURNEY-005), because the Certificates desk belongs to no workspace
  (JOURNEY-008). The certificate-desk permission set was explicitly designed for
  this role — `20260884000000_certificate_requests.sql:134-140` grants
  `requestStudentCertificate` to `parent`, `officeStaff`, `classTeacher`,
  `coordinator`, principal, vicePrincipal, schoolAdmin — and **three of those
  seven slugs do not exist client-side** while `parent` has no screen at all.
- **Root cause:** the front-office persona was modelled in migrations and in the
  desk UIs, but never added to `ErpRole`, `RolePermissionMatrix`, `kRoleWorkspaces`
  or `homeRouteForStaffErp`.
- **Recommended fix:** Add `ErpRole.officeStaff` (front-office workspace: admin,
  certificateDesk, gatePass, complaints, admissions) and grant it
  `requestGatePass` and `raiseComplaint` server-side. Add a parent-facing
  certificate-request screen inside `ParentShell` so the server's parent grant is
  usable.
- **Dependencies:** JOURNEY-002, JOURNEY-005, JOURNEY-008.
- **Risk of fixing:** medium — new role plus new server grants plus a new parent
  surface.
- **Evidence:** `supabase/migrations/20260608100000_rbac_foundation.sql:189,238`;
  `supabase/migrations/20260884000000_certificate_requests.sql:123-149`;
  `lib/core/security/erp_role.dart:2-17`; `lib/core/workspace/workspace.dart:112-120`;
  `lib/features/admin/admin_navigation_provider.dart:74-108`;
  `supabase/functions/_shared/certificate_desk/certificate_desk_handlers.ts:167-182`.

### JOURNEY-014 · **P1** · Student health · The nurse role cannot be represented, and the teacher-facing half does not render

- **Repro steps:** Assign `healthStaff` to a school nurse
  (`supabase/migrations/20260887000000_student_health.sql:42-43`). Sign in. Look
  for the Infirmary tile. Separately, sign in as a teacher and look for a student
  care alert.
- **Expected:** The nurse lands on the Infirmary console; teachers see care alerts
  for children in their class.
- **Actual:** (a) `ErpRole` has no `healthStaff` value, so the nurse is mapped to
  `superAdmin` (JOURNEY-002) and placed in the School Administration workspace.
  (b) `AdminModule.studentHealth` belongs to no workspace, so the Infirmary tile
  can never render on the hub or the phone bottom nav (JOURNEY-008) — the console
  is drawer-only. (c) `lib/features/student_health/care_alert/care_alert_widget.dart`
  is imported nowhere in `lib/` (already catalogued DEAD in FEATURE_INVENTORY M28),
  so the teacher-facing care alert has no rendering site at all.
- **Root cause:** the module shipped server-first; the client role, workspace
  membership and the alert mount point were never added.
- **Recommended fix:** Add `ErpRole.healthStaff` + a health workspace whose
  `homeRoute` is `/student-health`; add `AdminModule.studentHealth` to it; mount
  `CareAlertWidget` on the teacher dashboard / class-teacher dashboard behind
  `Permission.viewStudentCareAlert`.
- **Dependencies:** JOURNEY-002, JOURNEY-008.
- **Risk of fixing:** medium — surfaces sensitive health data; the migration's
  need-to-know intent and its access-log audit must be preserved exactly.
- **Evidence:** `supabase/migrations/20260887000000_student_health.sql:42-43,444-495`;
  `lib/core/security/erp_role.dart:2-17`; `lib/core/workspace/workspace.dart:59-173`;
  `lib/features/student_health/care_alert/care_alert_widget.dart` (no importers);
  `lib/features/admin/admin_navigation_provider.dart:98-108`.

### JOURNEY-015 · **P1** · Parent App · "Pay now" from the dashboard always opens a hard-coded installment

- **Repro steps:** As a parent, tap the dashboard's Pay-now / pay-fee quick action.
- **Expected:** The next unpaid installment for the selected child.
- **Actual:** The router always navigates to
  `/parent/payment?installmentId=term_2` regardless of what is owed;
  `handleParentFeesNavigation` likewise defaults `installmentId ?? 'term_2'`.
  With live data no such id exists, so the payment summary lookup fails — and
  JOURNEY-007 then renders a fabricated ₹4,200 statement in its place.
- **Root cause:** `lib/router/parent_navigation.dart:33-36` and `:110-115` —
  demo-fixture ids left in the production router, the same residue class as
  CERT-003.
- **Recommended fix:** Pass the real installment id from the tapped model; if none
  is selected, open `/parent/fees` rather than guessing.
- **Dependencies:** JOURNEY-007, CERT-001, CERT-003.
- **Risk of fixing:** low.
- **Evidence:** `lib/router/parent_navigation.dart:29-45,96-116`;
  `lib/router/app_router.dart:2341-2376`.

### JOURNEY-016 · **P2** · Parent App · Two dashboard items route to the hidden PTM screen

- **Repro steps:** As a parent, tap the notice/event whose id is `notice_n1` or
  `event_e2` on the dashboard.
- **Expected:** The notice or event opens.
- **Actual:** Navigation goes to `RouteNames.parentPtm`, which
  `SchoolBuildScope.hiddenRoutePrefixes` blocks in a school build — the builder
  returns `AccessDeniedScreen`. The parent taps a school notice and is told access
  is denied.
- **Root cause:** `lib/router/parent_navigation.dart:83-85` maps two fixture ids
  to PTM and does not consult `SchoolBuildScope.isRouteHidden`. The "More" sheet
  does consult it (`lib/shared/navigation/persona_nav.dart:212-213`), so the tile
  is correctly hidden while this handler is not.
- **Recommended fix:** Delete the fixture-id special cases; route notices to
  `/parent/notices` and events to `/parent/events` as the generic branches
  already do. Any remaining PTM navigation should be guarded by
  `SchoolBuildScope.isRouteHidden`.
- **Dependencies:** none.
- **Risk of fixing:** very low.
- **Evidence:** `lib/router/parent_navigation.dart:82-92`;
  `lib/core/config/school_build_scope.dart` (`hiddenRoutePrefixes`);
  `lib/shared/navigation/persona_nav.dart:206-223`.

---

<!-- ═══════════════════════════════════════════════════════════════════════
     WIDGET — Workstream 6, Dashboard & widget certification (2026-07-29)
     Full trace: docs/certification/findings/WIDGET-dashboard-certification.md
     Source-traced screen → widget → provider → repository → release flag.
     No device run (release binary requires production + live API) — every
     rendering claim is derived from the widget tree, not a screenshot.
     ═══════════════════════════════════════════════════════════════════════ -->

### WIDGET-001 · **P0** · Parent · Dashboard renders fabricated fees and attendance during every load, and permanently on failure

- **Repro steps:** Sign in as a parent on any tenant. Cold-open `/parent/dashboard` and
  watch the first frames. Then repeat with `GET /parent/dashboard` failing (airplane
  mode, or a 500).
- **Expected:** A skeleton while loading; an honest empty/error state on failure. The
  screen already passes `skeleton: AksharaSkeleton.dashboard()`.
- **Actual:** Both paths render `ParentDashboardData.mock()` — child **"Ravi Kumar,
  8-A"**, school "Akshara Public School", status chip **"₹4,200 due"**, today rows
  **"Present · Marked 9:12 AM"**, **"2 homework due today"**, **"Term 2 installment due
  12 Jun"**, the AI bar **"Fee due in 5 days — pay early to avoid late fee"**, plus three
  fabricated notices and three fabricated events. On failure this is permanent. The
  skeleton is unreachable code.
- **Root cause:** Two independent gaps. (1) `parent_dashboard_screen.dart:39-41` derives
  `isLoading`/`hasError`/`isEmpty` **only** from `parentDashboardLoadingProvider`,
  `…ErrorProvider`, `…EmptyProvider` — `StateProvider<bool>` defaulting to `false` and,
  verified by grep across `lib/`, **never written outside tests**. The real
  `AsyncValue` state is never consulted. (2)
  `parent_dashboard_provider.dart:312-314` ends `data ?? future.value ?? ParentDashboardData.mock()`,
  and `watchRepositoryFuture` returns null while pending
  (`lib/core/providers/repository_future.dart:13` is `whenOrNull(data:)`), so the mock
  wins during the fetch as well as after a failure.
- **Recommended fix:** Copy the student dashboard verbatim — it is the same widget
  family and already correct: `student_dashboard_screen.dart:36-39` ORs
  `|| async.isLoading` / `|| async.hasError`, and
  `student_dashboard_provider.dart:283-285` falls back to `StudentDashboardData.empty()`,
  not a mock. Add `ParentDashboardData.empty()` and delete `.mock()` from the production
  path (keep it for tests only).
- **Dependencies:** none. Note that `test/golden/golden_test_helpers.dart:79-81,123-125`
  overrides all nine dashboard loading providers to `false`, so the golden suite pins the
  mock path; those goldens must be re-baselined against the honest states.
- **Risk of fixing:** low. The change is additive to the async read and swaps one
  fallback constructor.
- **Evidence:** `lib/features/parent/dashboard/parent_dashboard_screen.dart:38-41,67-72`;
  `lib/features/parent/dashboard/parent_dashboard_provider.dart:41-174,291-293,304-316`;
  `lib/core/providers/repository_future.dart:5-14`;
  `lib/features/student_app/dashboard/student_dashboard_screen.dart:34-39` and
  `…/student_dashboard_provider.dart:277-285` (the correct pattern).
- **Severity note:** the register's standing rule, twice — fabricated **financial** and
  fabricated **attendance** data shown to a parent. `FEATURE_INVENTORY.md` records this
  screen under **CERT-002** as failing "on failure"; this entry records the mechanism and
  the fact that the **loading** path is affected on every single cold open, which is a
  different fix from the fallback constant.

### WIDGET-002 · **P0** · Teacher · Dashboard asserts a staff check-in that did not happen

- **Repro steps:** Sign in as a teacher. Cold-open `/teacher/dashboard`. Repeat with
  `GET /teacher/dashboard` failing.
- **Expected:** Skeleton, then real data; honest error on failure.
- **Actual:** Both paths render `TeacherDashboardData.mock()`: greeting **"Good morning,
  Priya" / "Priya Sharma"**, a staff check-in card reading **"9:02 AM · Geo+Face
  verified"** with status `checkedIn`, class attendance **"34 of 38 present"**, a pending
  banner **"Attendance not marked for Class 8-A · Period 1"**, and a three-period
  fabricated timetable — to a teacher who may be called Anita, has not checked in, and
  does not teach 8-A.
- **Root cause:** Identical to WIDGET-001.
  `teacher_dashboard_screen.dart:31-33` reads only the manual state providers;
  `teacher_dashboard_provider.dart:314-323` ends `?? TeacherDashboardData.mock()`.
- **Recommended fix:** As WIDGET-001 — OR in `async.isLoading`/`async.hasError`, add
  `TeacherDashboardData.empty()`, remove `.mock()` from the production path.
- **Dependencies:** same golden re-baseline as WIDGET-001.
- **Risk of fixing:** low.
- **Evidence:** `lib/features/teacher/dashboard/teacher_dashboard_screen.dart:29-33,52-57,83-92`;
  `lib/features/teacher/dashboard/teacher_dashboard_provider.dart:159-193,304-323`.
- **Severity note:** worse than WIDGET-001 in kind rather than degree. **"Geo+Face
  verified"** is a specific claim about a biometric attendance event, on the record that
  feeds payroll and the staff-attendance audit trail. A teacher who sees "checked in
  9:02 AM" and does not then check in has been actively misled by the product about their
  own attendance.

### WIDGET-011 · **P0** · Management · "School health score" is computed from hard-coded fallback constants

- **Repro steps:** Sign in as principal on a **new** tenant with no fee data and no
  finance-intelligence KPIs. Open `/management/dashboard`. Read the ring at the top of
  the Principal overview panel.
- **Expected:** No score, or an explicit "not enough data yet".
- **Actual:** A large premium progress ring reading **51**, labelled **"School health
  score"**, subtitled **"Blends fee collection and margin trends"** — for a school that
  has recorded neither.
- **Root cause:** `lib/features/management/widgets/management_principal_overview_panel.dart:24-39`:
  `int.tryParse(collectionRate.replaceAll(RegExp(r'[^0-9]'),'')) ?? 68` and
  `int.tryParse(…net_margin… ?? '31') ?? 31`, blended
  `((feeRate*0.55)+(margin*0.45)).round().clamp(0,100)`. With no fee data `feeRate`
  becomes the literal **68**; a school without the finance-intelligence module has no
  `net_margin` KPI at all so `margin` is **always** the literal **31**; together they
  yield **51**. Two further problems in the same six lines: the weights 0.55/0.45 are
  undocumented and unconfigurable, and stripping non-digits from a **money-or-percent
  string** means a `collectionRate` returned as an amount (`₹12,45,000`) parses as
  `1245000` and pegs the score at **100**.
- **Recommended fix:** Make the score nullable and render an honest "Not enough data yet"
  when either input is absent — never substitute a constant. Move the computation out of
  the widget to a place where the weights can be reviewed and, ideally, to the backend
  that owns the figures. Parse a typed percentage, not a scraped string.
- **Dependencies:** needs a typed `collectionRate`/`netMargin` on
  `ManagementDashboardData` rather than display strings.
- **Risk of fixing:** low-medium — the panel is the first thing on the principal's
  dashboard, so the empty rendering needs design attention.
- **Evidence:** `lib/features/management/widgets/management_principal_overview_panel.dart:24-39,226-280`.
- **Severity note:** P0 under the standing rule. It is a single headline number, derived
  from financial inputs, presented as this school's health, that the viewer cannot check
  from the screen showing it — the same shape as **CERT-006**, but load-bearing rather
  than decorative, and shown to the owner.

### WIDGET-003 · **P1** · Management · `ManagementSegmentPanel` renders a 240–320px blank box on day one

- **Repro steps:** Open `/management/dashboard` on a tenant with no expense
  categorisation (every new school).
- **Expected:** An empty state, as its row-mate `ManagementTrendChart` already does.
- **Actual:** A bordered card containing the title **"Expense breakdown"** and then
  240–300px of nothing.
- **Root cause:** `lib/features/management/widgets/management_segment_panel.dart:37-86`
  wraps a `ListView.separated` in a **fixed-height `SizedBox`** with no `segments.isEmpty`
  branch, so the height is reserved whether or not there is anything to draw.
- **Recommended fix:** Mirror `FinanceCollectionTrendChart`
  (`lib/features/finance/widgets/finance_collection_trend_chart.dart:32-67`), which
  suppresses the fixed height **and** the legend and substitutes an empty state.
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** `lib/features/management/widgets/management_segment_panel.dart:21-93`;
  `lib/features/management/dashboard/management_dashboard_screen.dart:163-197`;
  contrast `lib/features/finance/widgets/finance_collection_trend_chart.dart:32-67`.

### WIDGET-004 · **P1** · Parent, Teacher · Headed dashboard sections render zero-height holes when empty

- **Repro steps:** (a) Parent: open `/parent/dashboard` on a school with no timetable,
  homework or attendance recorded — the **"Today"** header and its **"See all"** link
  render with nothing beneath them. (b) Teacher: a backend returning an empty
  `quickActions` list leaves the **"Quick Actions"** header above an empty grid.
- **Expected:** Header + empty state, or the whole section self-hides. This exact class
  was fixed elsewhere during RC — `PendingTasksSection:38`, `TodayScheduleCard:39`,
  `HomeworkDueList:38` and `DailyScheduleStrip:45` all do it correctly.
- **Actual:** Both sections render the header unconditionally and iterate a possibly
  empty list with no guard.
- **Root cause:** `lib/features/parent/dashboard/parent_dashboard_screen.dart:538-575`
  (`_TodaySummarySection`) and
  `lib/features/teacher/dashboard/teacher_dashboard_screen.dart:312-344`
  (`_QuickActionsSection`).
- **Recommended fix:** Add the same `if (items.isEmpty) return AksharaEmptyState(...)`
  used by the four widgets above. "Today" reads better self-hidden; "Quick Actions" with
  no actions is a configuration error and should say so.
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** `lib/features/parent/dashboard/parent_dashboard_screen.dart:198-202,538-575`;
  `lib/features/teacher/dashboard/teacher_dashboard_screen.dart:177-180,312-344`;
  correct precedents at `lib/features/teacher/dashboard/widgets/pending_tasks_section.dart:38`,
  `…/today_schedule_card.dart:39`,
  `lib/features/student_app/dashboard/widgets/homework_due_list.dart:38`,
  `…/daily_schedule_strip.dart:45`.

### WIDGET-005 · **P1** · Student · Exam reminder card announces an exam that does not exist

- **Repro steps:** Sign in as a student at a school with no exams scheduled. Open
  `/student/dashboard`.
- **Expected:** No card, or "No exams scheduled".
- **Actual:** A full secondary-tinted card with a calendar icon, an **"Exam"** badge, the
  text **"In 0 days"** and three blank lines where title, subject and date belong.
  Tapping it fires the action id `'exam_'`. The screen-reader label is
  *"Exam reminder: , , , in 0 days"*.
- **Root cause:** `lib/features/student_app/dashboard/student_dashboard_screen.dart:152-158`
  renders `ExamReminderCard` unconditionally, and
  `lib/features/student_app/dashboard/widgets/exam_reminder_card.dart:20` has no empty
  branch. `StudentDashboardData.empty()` supplies
  `ExamReminder(id:'', title:'', subject:'', dateLabel:'', daysUntil:0)`.
- **Recommended fix:** Return `SizedBox.shrink()` when `reminder.id.isEmpty`, and gate the
  render site on the same condition so the surrounding spacing collapses too.
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** `lib/features/student_app/dashboard/widgets/exam_reminder_card.dart:19-132`;
  `lib/features/student_app/dashboard/student_dashboard_provider.dart:251-262`;
  `lib/features/student_app/dashboard/student_dashboard_screen.dart:152-158`.

### WIDGET-006 · **P1** · Student, Teacher, Management · AI suggestion bar renders a branded card with no message

- **Repro steps:** Open `/student/dashboard` on a new tenant (`.empty()` supplies
  `StudentAiInsight(message:'', actionLabel:'')`). Same on `/teacher/dashboard` and
  `/management/dashboard` whenever the backend returns an empty insight.
- **Expected:** No bar. The **parent** dashboard already does exactly this —
  `parent_dashboard_screen.dart:174`, `if (data.aiInsight.message.isNotEmpty)`.
- **Actual:** The full brand-gradient bar renders: sparkle icon, drop shadow, the eyebrow
  **"AKSHARA SUGGESTS"**, a blank message line and — because the action guard tests
  `actionLabel != null` rather than `.isNotEmpty` — a **blank action button**. The most
  visually prominent element on the screen, saying nothing.
- **Root cause:** `lib/shared/widgets/premium/akshara_ai_suggestion_bar.dart` has no
  empty-message guard, and its action guard at line ~114 is
  `if (actionLabel != null && onAction != null)`. Render sites
  `lib/features/student_app/dashboard/student_dashboard_screen.dart:179-188,200-205` and
  `lib/features/teacher/dashboard/teacher_dashboard_screen.dart:189-193,253-257` are
  unconditional. (`AksharaInsightCard` on management gets the action label right —
  `akshara_insight_card.dart:39` uses `actionLabel.isEmpty ? null : actionLabel` — but
  still renders with an empty message.)
- **Recommended fix:** Guard inside the shared widget — `if (message.trim().isEmpty)
  return const SizedBox.shrink();` — so all three call sites are fixed at once, and
  change the action guard to test `isNotEmpty`. Also collapse the surrounding
  `SizedBox(height: s4)` at the render sites.
- **Dependencies:** none.
- **Risk of fixing:** low, but it is a shared premium widget — re-run the golden suite.
- **Evidence:** `lib/shared/widgets/premium/akshara_ai_suggestion_bar.dart:12-127`;
  `lib/features/student_app/dashboard/student_dashboard_provider.dart:261`;
  correct precedent at `lib/features/parent/dashboard/parent_dashboard_screen.dart:174-181`.
- **Note:** the eyebrow default is the string **"AKSHARA SUGGESTS"** while the app is
  renaming to NIKSHA OS — a user-visible legacy brand string on every persona dashboard.

### WIDGET-007 · **P1** · Director · Portfolio section is a headed hole and the empty state is disabled by construction

- **Repro steps:** Sign in as director on an org with no schools onboarded (or one where
  `schoolRows` returns empty). Open the director dashboard.
- **Expected:** The `emptyMessage` the screen already declares —
  "No dashboard data available."
- **Actual:** An empty KPI row, then the header **"School portfolio health"**, then
  nothing, then the executive summary. The empty state can never fire.
- **Root cause:** `lib/features/director/director_dashboard_screen.dart:41` passes
  `resolveErpAsync(state, isDataEmpty: (_) => false)` — the emptiness predicate is
  hard-coded false, making `emptyMessage` on line 43 dead. The portfolio list at
  `:72-93` then iterates `data.schoolRows` with no guard.
- **Recommended fix:** Supply a real predicate (`(d) => d.schoolRows.isEmpty && d.kpis.isEmpty`)
  and add an empty state under the portfolio header for the partial case.
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** `lib/features/director/director_dashboard_screen.dart:38-49,65-93`.

### WIDGET-008 · **P1** · Finance, SIS, HR, Admissions, Transport, Library, Hostel, Inventory, Alumni, Director · Dashboard filter chips do not filter

- **Repro steps:** Open `/finance/dashboard`. Tap **"This month"**, then **"All classes"**,
  then **"All modes"**. The selected chip changes. No figure on the page changes. Repeat
  on the SIS, HR, Admissions, Transport, Library, Hostel, Inventory, Alumni and Director
  dashboards — same result on all of them.
- **Expected:** The dashboard re-queries for the selected scope, as the **Management**
  dashboard does.
- **Actual:** The `*DashboardFilterProvider` is read **only** by the screen, to paint
  which chip looks selected. Every `*DashboardFutureProvider` calls
  `getDashboard(query: ref.watch(repositoryQueryProvider))` — the unfiltered base query.
  The chip row is an inert control that implies the numbers responded to it.
- **Root cause:** Missing query provider. Management shows the intended shape:
  `managementDashboardQueryProvider`
  (`lib/features/management/management_providers.dart:16-25`) maps the index to
  `{'period':…,'quarter':…}` and `managementDashboardFutureProvider:27-32` watches it.
  Nine dashboards never got the equivalent.
- **Recommended fix:** Either add the per-module query provider (mechanical, and the
  backend `getDashboard` already takes a `RepositoryQuery`), or — for any module where
  the backend cannot filter — **remove the chips**. Do not ship a control that does
  nothing; the register already has the precedent that a tile which silently does nothing
  should be removed rather than left in place
  (`global_search_registry.dart:193-212`, P1-7).
- **Dependencies:** each module's backend `GET /<module>/dashboard` must accept the
  filter params. Not verifiable from the client (no Postgres lane / owner-bound SSH).
- **Risk of fixing:** low to remove; medium to wire (touches 9 providers + 9 backends).
- **Evidence:** `lib/features/finance/dashboard/finance_dashboard_provider.dart:13-25`;
  `lib/features/sis/dashboard/sis_dashboard_provider.dart:12-18`;
  `lib/features/hr/hr_providers.dart:16-19`;
  `lib/features/admissions/dashboard/admissions_dashboard_provider.dart:13-16`;
  `lib/features/transport/transport_providers.dart:16-19`;
  `lib/features/library/library_providers.dart:16-19`;
  `lib/features/hostel/hostel_providers.dart:16-19`;
  `lib/features/inventory/inventory_providers.dart:16-19`;
  `lib/features/alumni/alumni_providers.dart:16-19`;
  `lib/features/director/director_dashboard_screen.dart:24`;
  contrast `lib/features/management/management_providers.dart:14-32`.

### WIDGET-009 · **P2** · All module dashboards · Filter chip labels are hard-coded constants unrelated to the tenant

- **Repro steps:** Open the Hostel dashboard at a school with five hostel blocks; open
  Inventory at a school whose stores are organised by subject; open Alumni in 2027.
- **Expected:** Options drawn from the school's own configuration.
- **Actual:** Hostel offers **`Block A` · `Block B` · `All blocks`**. Inventory offers
  **`All departments` · `IT` · `Hostel` · `Science`**. Alumni offers **`All batches` ·
  `2024–25` · `2022–23`** and no other batch, ever. HR offers **`Academics` ·
  `Administration`**. SIS offers the single year **`2026–27`**. Transport offers
  **`AM shift` · `PM shift`**. Management offers **`FY 2026-27` · `Q1`** — a fiscal year
  that will be wrong in April 2027, and a quarter selector that cannot select Q2, Q3 or
  Q4. Director's chips (**`All schools` · `Region` · `Quarter`**) name *dimensions*, not
  selections.
- **Root cause:** `static const List<String> filterLabels` in each dashboard screen.
- **Recommended fix:** Derive from `schoolCapabilitiesProvider` / the module's own
  configuration, or reduce to genuinely universal scopes (This month / This year / All).
  The management FY label must be computed from the tenant's academic year — it is also
  passed verbatim into the Copilot context
  (`management_dashboard_screen.dart:140`), so the AI assistant is currently told the
  period is "FY 2026-27" regardless of the real year.
- **Dependencies:** WIDGET-008 — pointless to fix the labels while the chips are inert.
- **Risk of fixing:** low.
- **Evidence:** `management_dashboard_screen.dart:32-36,140`;
  `finance_dashboard_screen.dart:25-29`; `sis_dashboard_screen.dart` filterLabels;
  `hr_dashboard_screen.dart`; `admissions_dashboard_screen.dart`;
  `transport_dashboard_screen.dart`; `library_dashboard_screen.dart`;
  `hostel_dashboard_screen.dart`; `inventory_dashboard_screen.dart`;
  `alumni_dashboard_screen.dart`; `director_dashboard_screen.dart:24`.

### WIDGET-010 · **P2** · Finance, SIS, Admissions · Three unrelated filter dimensions in one single-select group

- **Repro steps:** On `/finance/dashboard`, select **"This month"**. Now select
  **"All classes"** — "This month" deselects.
- **Expected:** Period, class and payment mode are independent; they should be separate
  controls (or a filter sheet).
- **Actual:** One single-select chip row spans three dimensions, so the control cannot
  express "this month AND all classes" even in principle. Finance:
  `This month / All classes / All modes`. SIS: `2026–27 / All classes / All statuses`.
  Admissions: `This month / All counselors / All sources`.
- **Root cause:** A single `StateProvider<int>` index backing a multi-dimensional filter.
- **Recommended fix:** Model the filter as a record of independent dimensions, or collapse
  to a single dimension per row.
- **Dependencies:** WIDGET-008.
- **Risk of fixing:** medium — a UX change, not just wiring.
- **Evidence:** `lib/features/finance/dashboard/finance_dashboard_screen.dart:25-42`;
  `lib/features/sis/dashboard/sis_dashboard_screen.dart:33-41`;
  `lib/features/admissions/dashboard/admissions_dashboard_screen.dart:37-44`.

### WIDGET-012 · **P2** · Management · The same insight and the same approval queue render two and three times on one screen

- **Repro steps:** Open `/management/dashboard` with a non-empty AI insight and more than
  five pending approvals. Scroll once.
- **Expected:** Each fact stated once, in the place it belongs.
- **Actual:** `data.aiInsight` renders **twice** — as an amber `AksharaWarningBanner`
  inside "Alert center" (pushed into `_alerts` at
  `management_principal_overview_panel.dart:219-220`, with a **"Review"** button hard-wired
  to `/management/approvals`) and again as `AksharaInsightCard` at the bottom
  (`management_dashboard_screen.dart:257-263`, **"View approvals"**, same destination).
  A fee-collection insight is therefore shown twice, both times styled as something to
  approve. Pending approvals render **three** times: `_priorities` (top 3, as "Approve X ·
  ₹Y" cards, `:145-175`), `_alerts` ("N items waiting in approval queue", `:216-218`), and
  `_ApprovalQueuePreview` (top 5, as a table, `management_dashboard_screen.dart:235`).
- **Root cause:** Two panels composed independently, each deciding what is urgent, with no
  shared "already surfaced" set. `lib/core/dai/dai_brief.dart:14-19` records the same
  observation and declined to ship the morning brief because it would be a **third**
  "what matters today" surface — the second is already present.
- **Recommended fix:** Pick one home for each fact. The insight belongs in the insight
  card; the alert centre should carry only what is not already a priority card. Derive the
  insight card's `actionLabel` from the insight rather than hard-coding "View approvals"
  (management) / "Review defaulters" (finance), so the button matches the sentence.
- **Dependencies:** none.
- **Risk of fixing:** low-medium — it is a layout/ordering decision.
- **Evidence:** `lib/features/management/widgets/management_principal_overview_panel.dart:143-223`;
  `lib/features/management/dashboard/management_dashboard_screen.dart:148,233-235,257-263`;
  `lib/features/finance/dashboard/finance_dashboard_screen.dart:95-101,135-141`;
  `lib/core/dai/dai_brief.dart:12-19`.

### WIDGET-013 · **P2** · Management, Finance · Hard-coded, inconsistent alert thresholds

- **Repro steps:** (a) A 200-student school with **38** fee defaulters — nearly a fifth of
  its roll — sees no warning banner anywhere. (b) A school with **25** defaulters sees the
  Alert-Centre banner but **not** the dashboard warning banner, on the same screen, about
  the same fact.
- **Expected:** Escalation proportional to the school, and one consistent threshold for one
  fact.
- **Actual:** `defaulters > 40` gates the fee banner on **both** the management dashboard
  (`management_dashboard_screen.dart:149,156`) and the finance dashboard
  (`finance_dashboard_screen.dart:69,76`); `defaulters > 20` gates the Alert-Centre entry
  (`management_principal_overview_panel.dart:211`); `approvalQueue.length > 5` gates the
  approvals alert (`:216`). All absolute counts, none configurable, two of them
  contradictory.
- **Root cause:** Magic numbers inline in widget build methods.
- **Recommended fix:** Make the fee threshold proportional (a share of enrolment or of the
  billed amount) and define it once. If absolute counts must stay for v1.0, at minimum
  reconcile 20 and 40 to a single constant.
- **Dependencies:** proportional thresholds need enrolment on `ManagementDashboardData`.
- **Risk of fixing:** low.
- **Evidence:** `lib/features/management/dashboard/management_dashboard_screen.dart:149,156`;
  `lib/features/management/widgets/management_principal_overview_panel.dart:209-223`;
  `lib/features/finance/dashboard/finance_dashboard_screen.dart:69,76`.

### WIDGET-014 · **P3** · Management · Approval-queue empty state is a bare sentence

- **Repro steps:** Open `/management/dashboard` with an empty approval queue.
- **Expected:** `AksharaEmptyState`, as used everywhere else in the product.
- **Actual:** The section header **"Approval queue"** followed by unframed grey body text
  **"No items in the approval queue."** — no icon, no card, no surface. Visually it reads
  as a rendering failure rather than a calm all-clear.
- **Root cause:** `lib/features/management/dashboard/management_dashboard_screen.dart:338-348`
  returns a bare `Text` in the empty branch.
- **Recommended fix:** Use `AksharaEmptyState` with an icon, matching
  `FinanceRecentPaymentsTable` and `FinanceHandoffQueue`.
- **Dependencies:** none.
- **Risk of fixing:** trivial.
- **Evidence:** `lib/features/management/dashboard/management_dashboard_screen.dart:331-348`;
  contrast `lib/features/finance/dashboard/widgets/finance_recent_payments_table.dart:21-25`
  and `lib/features/finance/widgets/finance_handoff_queue.dart:36-40`.

### WIDGET-015 · **P2** · Dashboards · Four dashboard widgets ship with no rendering site, one of them bound to a live endpoint

- **Repro steps:** Search `lib/` for imports of each file below. There are none.
- **Expected:** Widgets that ship are widgets that render.
- **Actual:** Four dashboard-family widgets are compiled into the release with no caller:
  `lib/features/parent/dashboard/widgets/hero_card.dart` (158 lines),
  `lib/features/teacher/dashboard/widgets/greeting_header.dart`,
  `lib/features/student_app/dashboard/widgets/hero_greeting_card.dart` — all three
  superseded by `AksharaGradientHero` — and
  `lib/features/student_health/care_alert/care_alert_widget.dart`, which is bound to the
  **live** `GET /student-health/care-alerts` endpoint and has no rendering site anywhere.
  The care alert is the inverse of a placeholder: a working data source with no widget on
  screen, so a teacher is never told a child in their class has an active care alert.
- **Root cause:** Superseded during the DS V2 migration (the three heroes) and never
  wired (the care alert). All four are already enumerated in `FEATURE_INVENTORY.md` §M28.
- **Recommended fix:** Delete the three superseded heroes. The care alert is a product
  decision, not a cleanup: either give it a rendering site on the teacher dashboard /
  class roster, or remove it and stop serving the endpoint.
- **Dependencies:** the care-alert decision needs a product owner.
- **Risk of fixing:** trivial for the deletions.
- **Evidence:** `docs/certification/FEATURE_INVENTORY.md` §M28 (rows "UI | 6 orphaned
  widgets" and "Student health | Care-alert widget"), verified by import search.

### WIDGET-016 · **P1** · Parent · "Homework pending" KPI counts summary rows, not homework

- **Repro steps:** Open `/parent/dashboard`. Compare the **"Homework pending"** KPI card
  with the "Today" row about homework directly below it.
- **Expected:** The same number.
- **Actual:** The KPI shows **1** while the row reads **"2 homework due today"**. Two
  numbers about one fact, on one screen, disagreeing.
- **Root cause:** `lib/features/parent/dashboard/parent_dashboard_screen.dart:314-315`:
  `todaySummary.where((t) => t.id.contains('homework')).length` — it counts *summary rows
  whose id mentions homework*, which is 0 or 1, not the homework count. The same widget
  derives the Attendance and Fees KPIs by substring-scraping chip **labels**
  (`c.label.toLowerCase().contains('attendance')` / `.contains('fee')`, `:306-313`), so
  any backend re-wording of a chip silently turns those cards into `'—'`.
- **Recommended fix:** Put a typed `homeworkPendingCount` (and typed attendance/fee
  values) on `ParentDashboardData` and read those. Presentation strings are not a data
  source.
- **Dependencies:** `GET /parent/dashboard` must expose the typed fields; the values are
  already computed server-side to build the strings.
- **Risk of fixing:** low-medium — a DTO change.
- **Evidence:** `lib/features/parent/dashboard/parent_dashboard_screen.dart:295-358`;
  `lib/features/parent/dashboard/parent_dashboard_provider.dart:102-127`.

### WIDGET-017 · **P1** · Parent · Academic progress ring renders 0% when attendance is unknown

- **Repro steps:** Open `/parent/dashboard` where `GET /parent/experience/…` returns a
  summary without `attendanceSummary['ratePercent']` (new school, term not started).
- **Expected:** A neutral "not computed yet" — not a gauge with a value.
- **Actual:** `AksharaProgressRing` renders **completely unfilled**, captioned **"—%"** and
  **"Present"**, with the screen-reader label *"Attendance — percent"*. An empty ring is a
  strong visual assertion of near-zero attendance. The same pattern applies to
  `Grade '—'` and `Homework '—%'`, and the homework `LinearProgressIndicator` beside them
  sits at 0.
- **Root cause:** `lib/features/parent/dashboard/parent_dashboard_screen.dart:374-378`:
  `attendance = …['ratePercent'] ?? '—'` then
  `attendanceFraction = (double.tryParse('$attendance') ?? 0) / 100.0`. The `?? 0` turns
  "unknown" into "zero" before it reaches the gauge.
- **Recommended fix:** Make the fraction nullable and render an indeterminate/greyed ring
  (or omit the ring and show "Attendance not available yet") when it is null. Never map
  unknown to 0 in a gauge.
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** `lib/features/parent/dashboard/parent_dashboard_screen.dart:360-481`.
- **Severity note:** attendance data under the standing rule, graded P1 rather than P0
  because the numeric caption honestly reads "—" — the falsehood is carried only by the
  gauge's visual position. Flagging the judgement rather than hiding it.

### WIDGET-018 · **P2** · Management · "At-risk fees" tile shows a student count

- **Repro steps:** Open `/management/dashboard`. Read the third tile of the summary strip.
- **Expected:** A money figure, given the label.
- **Actual:** The tile shows `data.feeSnapshot.defaulters` — a **count of students** —
  under the subtitle **"At-risk fees"**, immediately beside a "Fee collection" tile showing
  a percentage. Three tiles, three different units, one of them mislabelled. The
  outstanding **amount** (`feeSnapshot.outstanding`) exists on the same object and is not
  shown here.
- **Root cause:** `lib/features/management/widgets/management_principal_overview_panel.dart:311-318`.
- **Recommended fix:** Either relabel to "Fee defaulters" (a count) or show
  `feeSnapshot.outstanding` (an amount). Given this is the principal's money summary, the
  amount is the more useful figure.
- **Dependencies:** none.
- **Risk of fixing:** trivial.
- **Evidence:** `lib/features/management/widgets/management_principal_overview_panel.dart:282-323`.

<!-- ═══════════════════════════════════════════════════════════════════════
     SIM — Workstream 3A, Real school simulation (2026-07-29)
     Full trace: docs/certification/findings/SIM-real-school.md
     Only defects NOT already covered by XMOD / CERT / JOURNEY are recorded.
     ═══════════════════════════════════════════════════════════════════════ -->

### SIM-001 · **P1** · Communications / Ops · Nothing monitors the one path that carries every parent message

- **Repro steps:** On the VPS, run `install-communication-cron.sh` but do not
  complete the separate activation step that sets `INTERNAL_CRON_TOKEN` on the
  `akshara-edge` container. Mark a student absent, approve a gate pass, send a
  broadcast. Wait a day. Nothing is delivered, and no alert fires anywhere.
- **Expected:** A school (or Akshara) is told when parent-facing delivery stops.
- **Actual:** The failure is completely silent to every human. The cron writes
  `FAIL run-scheduled http=401` to `/var/log/akshara/communication-cron.log`
  (`deploy/akshara-vps/communication-cron/akshara-broadcast-cron.sh:47-50`) and
  the watchdog does not look at it: it checks `/health/ready`, `/health/backup`,
  `/health/storage` and container health only
  (`deploy/akshara-vps/monitoring/akshara-watchdog.sh:106-108,140-142`). There is
  no check on the cron's exit status, no check on `notification_deliveries`
  queue depth, and no check on the age of the oldest pending delivery. Nothing
  in the app raises it either.
- **Root cause / important nuance:** the 5-minute broadcast cron is in fact the
  **only** scheduled drain of the whole notification queue —
  `runScheduledBroadcastsForOrg` calls `scheduleNotificationDrain`
  (`_shared/communication/communication_handlers.ts:739`) →
  `drainNotificationQueue` (`:104-115`) → `processDeliveryQueue(db, orgId)`
  (`_shared/communication/notification_service.ts:83`), which claims **every**
  pending delivery for the org, not just the broadcast's. So all parent
  notification in the product hangs off one cron whose authentication the
  installer explicitly does not configure: *"It does NOT set `INTERNAL_CRON_TOKEN`
  on the akshara-edge container … leaves the cron firing 401s (safe — fails
  closed) until that step is done"*
  (`install-communication-cron.sh:6-12`). `verifyInternalCronToken` correctly has
  no "unset = open" mode (`_shared/communication/communication_cron_auth.ts:14-33`)
  — the defect is the absence of monitoring, not the fail-closed behaviour.
- **Recommended fix:** Add a watchdog check that (a) asserts the last
  `communication-cron.log` line is `OK` within the last 15 minutes, and (b) hits a
  health endpoint exposing pending-delivery count and oldest-pending age, alerting
  above a threshold. Surface the same two numbers on the Delivery Console so a
  school can see it too.
- **Dependencies:** XMOD-016 (no scheduler) — this is the monitoring half of it.
  Blocks any confidence in XMOD chain 1 hop 5c.
- **Risk of fixing:** low — additive ops checks; no product code path changes.
- **Evidence:** `deploy/akshara-vps/communication-cron/install-communication-cron.sh:6-12,26-38`;
  `deploy/akshara-vps/communication-cron/akshara-broadcast-cron.sh:29-51`;
  `deploy/akshara-vps/monitoring/akshara-watchdog.sh:90-108,140-149`;
  `supabase/functions/_shared/communication/communication_handlers.ts:104-132,710-751`;
  `supabase/functions/_shared/communication/notification_service.ts:83-130`;
  `supabase/functions/_shared/communication/communication_cron_auth.ts:1-33`.
  **Boundary:** whether the token is actually set on the pilot's edge container
  could not be verified — SSH is owner-bound.

### SIM-002 · **P1** · Attendance · Consecutive-absence and short-attendance alerts are pull-only

- **Repro steps:** Let a student be absent 3+ consecutive days, or fall below the
  75% threshold. Wait. Check whether the class teacher, the office, the principal
  or the parent is told.
- **Expected:** An alert reaches a human — a push, an in-app item, a digest, or at
  minimum a badge on a screen someone must open daily.
- **Actual:** Nobody is told. `GET /attendance/alerts/consecutive-absence` and
  `GET /attendance/alerts/short-attendance` are computed correctly but are read
  **only** by the office-attendance screen
  (`lib/features/management/attendance/office_attendance_screen.dart:33-36`) —
  a `/management/*` route reachable by `viewManagement` holders. There is no
  notification enqueue on either path, no cron, no digest, and no entry on any
  teacher or parent surface. A child missing for a week produces a row on a screen
  nobody is obliged to open.
- **Root cause:** the alerts were built as a report, not as a signal. Consistent
  with the XMOD finding that write-time cross-module propagation is absent.
- **Recommended fix:** Enqueue an `enqueueNotificationRequested` to the class
  teacher and the guardian when either threshold is first crossed (idempotent per
  student per threshold per term), and add the count to the teacher's
  class-teacher dashboard. The notification rail already exists and is used
  correctly by transport, gate pass and student health.
- **Dependencies:** SIM-001 (delivery must actually drain); XMOD-002 (an approved
  leave still counts as an absence, so the alert will fire on children who were
  legitimately away).
- **Risk of fixing:** medium — firing retroactively on historical data would flood
  parents; the first run must be watermarked.
- **Evidence:** `lib/core/repositories/api/attendance/remote/attendance_api_paths.dart:12-14`;
  `lib/features/management/attendance/office_attendance_screen.dart:33-36`;
  grep for `consecutive-absence` / `short-attendance` across `lib/` and
  `supabase/functions/_shared/` returns no notification or scheduler call site.

### SIM-003 · **P1** · Complaints · The SLA cannot breach into anyone's awareness

- **Repro steps:** Raise a complaint with category `safety`, severity `critical`
  (1-hour SLA per policy). Assign it. Wait two hours. Check whether the assignee,
  the module owner, the principal or the reporter was ever told anything.
- **Expected:** The assignee is notified on assignment; somebody is alerted when
  `sla_due_at` passes; the reporter is told when it is resolved.
- **Actual:** No notification is sent at any point in a complaint's life.
  Grepping `supabase/functions/_shared/complaints/` for
  `enqueueNotificationRequested`, `processDeliveryQueue`, `scheduleReminder`,
  `sendSms` or `notification_service` returns **zero** hits — while the sibling
  desks do it correctly (`gate_pass/gate_pass_repository.ts:21,479-489`;
  `student_health/student_health_operations.ts:21,174`). On-track/breached is
  derived at **read** time only, so a breach exists only while somebody has the
  complaints screen open.
- **Root cause:** `complaints_sla.ts` is a well-built deterministic policy
  (`SLA_POLICY_HOURS`, total over the DB's CHECK domain, `sla_due_at` stamped at
  raise time, `_sla.ts:42-51`) with no delivery half. There is no breach sweep
  and no cron.
- **Recommended fix:** Enqueue on raise (to the category owner), on assign (to the
  assignee) and on resolve (to the reporter); add an SLA-breach sweep to the same
  periodic lane as the other jobs, alerting the assignee and the principal.
- **Dependencies:** SIM-001; XMOD-016 (needs a scheduler for the breach sweep).
- **Risk of fixing:** low-medium.
- **Evidence:** `supabase/functions/_shared/complaints/complaints_sla.ts:1-60`;
  `supabase/functions/_shared/complaints/complaints_handlers.ts`,
  `complaints_repository.ts` (no notification import or call);
  contrast `supabase/functions/_shared/gate_pass/gate_pass_repository.ts:471-492`.

### SIM-004 · **P1** · Timetable / Substitution · The confirmation message is false on every use

- **Repro steps:** As principal / VP / school admin, open the Substitute Manager,
  assign a substitute for a period, tick the "notify" checkboxes, and submit.
- **Expected:** Either the named audience is notified, or the UI does not claim
  they were.
- **Actual:** The response reports `timetableUpdated: true` as a **hard-coded
  literal** and `notifiedAudience` as an **echo of the caller's own three
  booleans**, plus the literal string *"Substitute assigned and timetable
  updated."* — and there is **no notification call anywhere in that function**
  (`_shared/school_completion/timetable_workforce_service.ts:336-347`). The substitute,
  the class in-charge and the students are told nothing. This is not an edge case:
  it is what the screen says every single time.
- **Root cause:** the service composes a success payload describing intent rather
  than reporting effect.
- **Recommended fix:** Actually enqueue to the substitute, the class teacher and
  (optionally) guardians, and derive `notifiedAudience` from the enqueue result.
  Until that ships, the confirmation copy must not assert notification or a
  timetable update.
- **Dependencies:** XMOD-002 — the substitution engine's "teachers on leave" input
  is structurally empty, so this flow is entered manually today. Fixing the copy
  is independent and should not wait.
- **Risk of fixing:** low for the copy; medium for real notification (needs an
  audience resolver for a period's students/guardians).
- **Evidence:** `supabase/functions/_shared/school_completion/timetable_workforce_service.ts:326-349`;
  `lib/features/academics/timetable/substitutions/daily_substitutions_screen.dart:127-142`.

<!-- ═══════════════════════════════════════════════════════════════════════
     E2E — Workstream 2, End-to-end feature certification (2026-07-29)
     Full trace: docs/certification/findings/CERT-e2e-feature-certification.md
     Paths repo-relative; `_shared/` = supabase/functions/_shared/.
     ═══════════════════════════════════════════════════════════════════════ -->

### E2E-001 · **P1** · Attendance · A rejected attendance submit is reported as a data-entry mistake

- **Repro steps:** As a class teacher, mark every student, tap **Submit**, with the
  server returning any error — roster mismatch (a student was transferred this
  morning), holiday block, session already locked by a co-teacher, 401, or no
  network with the queue unavailable.
- **Expected:** The teacher is told what actually went wrong — "this class was
  already submitted", "today is a holiday", "the roster changed, reload".
- **Actual:** The snackbar reads **"Mark all students before submitting."** every
  time. `submitAttendance` returns `false` for *both* `unmarkedCount > 0` **and**
  `result == null` (the mutation-failed case), and the screen has only one
  branch for `!ok`. The teacher re-checks a grid that is already fully marked,
  taps submit again, gets the same message, and reasonably concludes the app is
  broken — or that the attendance went in. Nothing was written.
- **Root cause:** a boolean return collapses "invalid input" and "write failed"
  into one value (`teacher_attendance_provider.dart:206-229`), and the caller
  cannot distinguish them (`teacher_attendance_screen.dart:462-479`).
- **Recommended fix:** return a result type (or rethrow) so the screen can show
  `aksharaErrorMessage(error)` for a failure and keep the "mark all students"
  copy for the genuine validation case. The backend already returns precise,
  mapped errors (`AttendanceRosterMismatchError`, `AttendanceLockedError`,
  holiday block) — none of them reach the teacher.
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** `lib/features/teacher/attendance/teacher_attendance_provider.dart:206-229`;
  `lib/features/teacher/attendance/teacher_attendance_screen.dart:462-479`;
  server errors at `_shared/pilot/pilot_attendance_repository.ts:38-52,68-71`.

### E2E-002 · **P1** · Attendance · The correction dialog opens pre-filled with a fabricated date and reason

- **Repro steps:** As a class teacher open **My class → Attendance → Request
  attendance correction**. Read the form before typing anything.
- **Expected:** An empty date field (or today), and an empty reason.
- **Actual:** The date field is pre-filled with the literal **`'12 Jun 2026'`** and
  the reason with **"Biometric sync error — student was present"**. Both are
  demo-seed values left in the production dialog. A teacher who changes only the
  student and taps *Submit for approval* files a governance request asserting a
  specific date and a specific cause, neither of which they chose — and that text
  is what the principal reads on the approval card, what is stored in
  `attendance_corrections.date_label` / `.reason`, and what is written into the
  `correctionRequested` audit event.
- **Root cause:** seeded `TextEditingController(text: …)` defaults never removed
  (`teacher_attendance_workflow.dart:31-34`). The date default matches the demo
  exam seed date in `exam_administration_store.dart:1500`, confirming its origin.
- **Recommended fix:** empty both controllers; make the date a date picker
  (see E2E-004) defaulting to today and bounded by the current academic year;
  require a non-empty reason.
- **Dependencies:** E2E-004 (the date must also be *used*).
- **Risk of fixing:** low.
- **Evidence:** `lib/features/teacher/attendance/teacher_attendance_workflow.dart:31-34,63-67,100-104`.

### E2E-003 · **P1** · Attendance · The staff correction route trusts the body for who is asking

- **Repro steps:** Hold `manageSis`. `POST /attendance/corrections` with
  `{"sisStudentId": "...", "requesterId": "<someone else>", "requesterName":
  "Principal Sharma", "requesterRole": "principal", ...}`.
- **Expected:** Requester identity is derived from the token, as the parent route
  already does.
- **Actual:** `requesterId`, `requesterName` and `requesterRole` are read straight
  from the request body and only *fall back* to `claims.sub`. They are persisted
  onto the correction row, rendered to the approver as
  *"By {requesterName} ({requesterRole})"*, and copied into the
  `correctionRequested` audit event. So the approval card and the forensic trail
  can both name someone who did not file the request. The parent route
  (`handleParentCreateAttendanceCorrection:472-475`) does this correctly and
  documents why — the staff route was not brought in line.
- **Root cause:** `handleCreateAttendanceCorrection` treats identity as ordinary
  payload.
- **Recommended fix:** pin `requesterId = claims.sub` and `requesterRole` to the
  caller's role; keep `requesterName` server-resolved from the employee record.
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** `_shared/attendance/attendance_handlers.ts:400-403` vs
  `:472-475`; audit at `:427-445`.

  Related, same file, `attendance_correction_repository.ts:47-54`: `markToDb`
  maps **any** unrecognised mark string to `"present"` rather than rejecting it.
  A typo or a client-version skew silently becomes the most favourable value on
  both `from_mark` and `to_mark`.

### E2E-004 · **P0** · Attendance · An approved correction is applied to the wrong day, and no day but today can ever be marked

- **Repro steps:** A parent disputes an absence recorded on 3 June. The teacher
  files a correction with that date. The principal approves it in the Approval
  Center. Now look at 3 June, and at today.
- **Expected:** 3 June's mark changes.
- **Actual:** **Today's mark changes.** `applyAttendanceCorrection` selects the
  target session as *"the session matching `attendance_corrections.session_date`,
  or — when that is NULL — the most recent submitted session"*. `session_date` is
  **never written by anything**: the INSERT column list omits it, no UPDATE sets
  it, and a repo-wide grep finds writes nowhere. The NULL branch is therefore the
  only branch that ever runs, and every correction lands on the latest submitted
  session. The date the teacher typed survives in `date_label`, on the approver's
  card and in the audit event — so the audit asserts a date the write did not use.

  The same gap has a second face: `upsertAttendanceSession` matches and inserts
  on `session_date = CURRENT_DATE` only and the submit request carries no date, so
  **there is no way to enter attendance for a past day at all**. A teacher out
  sick on Monday cannot enter Monday's register on Tuesday, and the correction
  workflow — the obvious workaround — silently edits Tuesday instead.
- **Root cause:** `date_label` (free text, for display) was implemented; the
  machine-readable `session_date` it was supposed to accompany never was. The
  column and the query that consumes it were both written; the producer was not.
- **Recommended fix:** parse the correction's date into `session_date` at create
  time (reject an unparseable or out-of-year date, 422), and require it. Then the
  existing `applyAttendanceCorrection` query works as written. Separately, accept
  an explicit `sessionDate` on `/teacher/attendance/submit`, bounded to a
  configurable back-window and blocked past a closed period.
- **Dependencies:** E2E-002 (a date picker to produce a parseable value);
  E2E-007 (once the right session is targeted, a 0-row result must stop being
  reported as success).
- **Risk of fixing:** medium — changes which row an approval mutates. Needs a
  migration to backfill/annul `session_date` on existing rows so historic
  corrections are not re-interpreted.
- **Evidence:** `_shared/attendance/attendance_correction_repository.ts:157-181`
  (INSERT without `session_date`), `:231-262` (the dead branch);
  `supabase/migrations/20260618130000_f5_attendance_corrections.sql:13` (the
  column exists); `_shared/pilot/pilot_attendance_repository.ts:57-62,84-95`
  (`CURRENT_DATE` only); `lib/features/teacher/attendance/teacher_attendance_provider.dart:206-229`
  (no date in the submit body).

### E2E-005 · **P1** · Attendance · The corrections admin screen reports submission status from a mock store

- **Repro steps:** As principal / school admin open **Attendance corrections**
  (`/management/attendance/corrections`) on a live build, after the class teachers
  have submitted the day's attendance.
- **Expected:** Either the real submission status, or no such claim.
- **Actual:** The header card always reads **"No teacher submission yet — Marks
  unlock after first class submission."** It is driven by
  `MockAttendanceSyncStore.instance`, an in-memory QA store written **only** by
  `MockTeacherRepository.submitAttendance`. In a release build the teacher app
  resolves `ApiTeacherRepository`, so the store is never written and
  `hasTeacherSubmission` is permanently `false`. The screen states, as fact, that
  no teacher has submitted — on a day when every class has. Had the mock path run,
  the same card would instead show fabricated Present/Absent/Late counts.
- **Root cause:** a QA cross-persona sync shim left wired into a production screen.
- **Recommended fix:** delete the card, or source it from
  `GET /attendance/pending` (`handleAttendancePending` already exists and answers
  exactly this question: which classes have not submitted today).
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** `lib/features/management/attendance/attendance_corrections_admin_screen.dart:6,30,63-76`;
  `lib/core/repositories/mock/mock_attendance_sync_store.dart:19,50-58`;
  sole writer `lib/core/repositories/mock/mock_teacher_repository.dart:261`;
  unused real source `_shared/attendance/attendance_router.ts:39`.

### E2E-006 · **P2** · Attendance · A live route can approve a correction without applying it

- **Repro steps:** Hold `approveAttendanceCorrection`. `PATCH
  /attendance/corrections/{id}/status` with `{"status":"approved"}`.
- **Expected:** Either the mark changes, or the route does not offer "approved".
- **Actual:** The correction flips to `approved`, a `correctionDecided` audit
  event is written, and **`attendance_records` is not touched** — the handler
  calls `updateAttendanceCorrectionStatus`, never `applyAttendanceCorrection`.
  Only the approval-engine path (`approval_type_handlers.ts:143`) applies. The
  result is an approved correction that changed nothing, with an audit trail
  saying it was approved. `status` is also not validated against the allowed set
  before the UPDATE — an arbitrary string reaches the DB CHECK and surfaces as an
  unmapped 500 rather than a 422.
- **Root cause:** two decision paths for one governance action; only one carries
  the effect.
- **Recommended fix:** have the status route delegate to `applyAttendanceCorrection`
  for `approved`, or restrict it to `rejected`/`cancelled` and validate `status`
  against the four allowed values. No client calls it today
  (`attendance_correction_remote_datasource.dart:65-75` has no UI caller), so the
  change is safe.
- **Dependencies:** E2E-004, E2E-007.
- **Risk of fixing:** low.
- **Evidence:** `_shared/attendance/attendance_handlers.ts:519-593`;
  `_shared/approval/approval_type_handlers.ts:141-166`.

### E2E-007 · **P1** · Attendance · Approving a correction that matches no record reports success

- **Repro steps:** Approve a correction for a student who has no record in any
  submitted session (a new admission, a student whose class has not submitted, or
  — routinely, because of E2E-004 — any correction at all).
- **Expected:** The approver is told the mark could not be applied.
- **Actual:** The UPDATE affects 0 rows; the code logs
  `console.warn("… no attendance records row updated …")` and **continues** to
  flip the status to `approved` and return success. Nothing surfaces to the
  approver, the requester or the parent. The correction shows "Approved" on every
  screen; the attendance is unchanged. The comment in the source states the
  intent — "we surface that as a warning so the approval is not a silent no-op"
  — but a server log is not a surface any school user has.
- **Root cause:** the affected-row count is computed and then discarded.
- **Recommended fix:** carry `affected` into the approval effect payload and the
  audit event, and render it — the approval detail should say *"approved, but no
  attendance record matched"*. Preferably fail the approval so the request stays
  actionable.
- **Dependencies:** E2E-004 (fixing the day selection removes most instances).
- **Risk of fixing:** low for surfacing; medium if the approval is made to fail.
- **Evidence:** `_shared/attendance/attendance_correction_repository.ts:276-291`;
  effect payload at `_shared/approval/approval_type_handlers.ts:142-152`.

### E2E-008 · **P0** · Finance / Collections · The counter sends the word "Today" as the payment date — day-close lock bypassed, receipt numbers read "NaN"

- **Repro steps:**
  1. As finance admin, close the day (`POST /finance/day-close` for 2026-07-28).
  2. Open **Finance → Collections → Record collection**, pick an invoice, record
     ₹5,000 by UPI.
  3. Expected: rejected — the day is closed. Actual: accepted, posted into the
     closed day.
  4. Now turn on `receipts.receipt_sequencing` in Finance settings and record
     another payment. Read the receipt number printed for the parent.
- **Expected:** A collection dated on or before the last closed day is rejected
  (FIN-D1); receipts are numbered `<PREFIX>/2026-27/000001`.
- **Actual:** `showRecordCollectionDialog` sends the hard-coded literal
  `collectionDate: 'Today'`. The DTO forwards it verbatim as
  `collection_date: "Today"`; the handler reads it with `optionalStr` and does not
  validate it. Server-side that one string breaks two derived computations:
  - **Day lock bypassed.** `isDateLocked` compares ISO strings lexically —
    `collectionDate.slice(0,10) <= latest.slice(0,10)`. `"Today" <= "2026-07-28"`
    evaluates to `false` (`'T'`=84 sorts after `'2'`=50), so the guard returns
    "not locked" for **every** collection made from the app. Books that have been
    closed, reconciled and reported to the owner silently take new money.
  - **Receipt number contains "NaN".** `fiscalYearOf("Today")` builds
    `new Date("TodayT00:00:00Z")` → Invalid Date → `getUTCFullYear()` is `NaN` →
    the function returns the string `"NaN-NaN"`. The receipt handed to the parent
    reads `SCH/NaN-NaN/000042`, and because `fiscal_year` is part of the
    `finance_receipt_sequences` key, **every fiscal year shares one sequence** —
    the per-year reset that makes the numbering auditable never happens.

  The INSERT itself lands on the right date only by luck: PostgreSQL accepts
  `'today'` as a special date literal, so `collection_date` is correct while
  everything computed from the same value in TypeScript is wrong. The
  instrument-reconcile path passes a real ISO date and is unaffected — this is
  specific to the counter screen, which is where nearly all money is taken.
- **Root cause:** a display string (`'Today'`, meant for a label) was passed into
  a field the server treats as an ISO date, and neither side validates the format.
  Both consumers fail silently rather than throwing.
- **Recommended fix:** (1) send `DateTime.now()` as `yyyy-MM-dd` from the dialog;
  (2) validate `collection_date` in the handler against `^\d{4}-\d{2}-\d{2}$` and
  422 otherwise; (3) make `fiscalYearOf` throw on an unparseable date rather than
  returning `"NaN-NaN"`; (4) make `isDateLocked` compare parsed dates, not
  strings. Add a data check for existing `finance_receipt_sequences` rows with
  `fiscal_year = 'NaN-NaN'` and any receipt numbers already issued containing
  `NaN` — those are printed documents that will need reissue.
- **Dependencies:** none. Ships independently of everything else in this register.
- **Risk of fixing:** low in code; the migration/backfill for already-issued
  `NaN` receipt numbers is the careful part.
- **Evidence:** `lib/features/finance/finance_workflow_actions.dart:1366-1372`;
  `lib/core/repositories/api/finance/dto/create_collection_request_dto.dart:24-27`;
  `lib/core/repositories/api/finance/remote/finance_remote_datasource.dart:197`;
  `_shared/finance/finance_collections_handlers.ts:308` (no validation);
  `_shared/finance/finance_day_close_repository.ts:51-61` (lexical compare);
  `_shared/finance/finance_collections_repository.ts:221-227` (`fiscalYearOf`),
  `:273-302` (`allocateReceiptNumber`), `:625-630` (`isDateLocked` call site).
  Related but distinct: **XMOD-037** (receipts randomly numbered when sequencing
  is off) — the two together mean receipt numbering is wrong in *both* settings.

### E2E-009 · **P1** · Finance / Offline instruments · The register defaults to a demo invoice ID and validates nothing

- **Repro steps:** Finance → Offline payments → **Record offline payment**. Read
  the Invoice ID field. Now clear every field and tap **Record**.
- **Expected:** An invoice picker (as the main collection dialog has), a required
  amount, and a rejection if the invoice does not exist.
- **Actual:** Invoice ID is pre-filled `'inv_1'` — a fixture id. The dialog has no
  `Form`, no validator, and no required-field check on any field; amount is a bare
  `TextField`. Server-side, `invoiceId` is `optionalStr` — never checked for
  emptiness and **never checked to exist**. So an instrument can be recorded
  against `inv_1`, against a typo, or against nothing. Because
  `reconcileOfflinePayment` throws `OfflinePaymentNotInvoicedError` when
  `invoice_id` is null and `loadInvoiceForCollection` fails when it points at a
  non-existent invoice, such a record can **never** be reconciled — the cheque sits
  in Pending forever with no way to correct it (there is no edit action).
- **Root cause:** the dialog was not brought up to the standard of the main
  collection dialog, which builds a real invoice picker from loaded invoices.
- **Recommended fix:** reuse the invoice picker from `showRecordCollectionDialog`;
  make invoice + amount required client-side; validate on the server that the
  invoice exists and belongs to the school (422); add an edit/void action for a
  pending instrument.
- **Dependencies:** E2E-010 (same dialog).
- **Risk of fixing:** low.
- **Evidence:** `lib/features/finance/payments/finance_offline_payments_screen.dart:277-296,357-372`;
  `_shared/finance/finance_offline_payments_handlers.ts:80-95`;
  `_shared/finance/finance_offline_payments_repository.ts:296-306` (reconcile
  rejects a non-invoiced instrument).

### E2E-010 · **P1** · Finance / Offline instruments · Cash recorded in the register is never money

- **Repro steps:** Finance → Offline payments → Record offline payment → method
  **Cash**, ₹5,000, submit. Then look at the student's outstanding, the day's
  collection total, the parent app, and `finance_collections`.
- **Expected:** Either cash is not offered here (it belongs on the counter
  screen), or recording it posts a collection immediately — cash has no clearance
  event.
- **Actual:** The cashier sees *"Offline payment recorded."*. The row is written
  as `pending_reconciliation` with `collection_id` NULL. **No collection is
  posted, no receipt exists, the invoice outstanding is unchanged, the day's total
  is unchanged, and the parent still owes the full amount.** `createOfflinePayment`
  hard-codes `'pending_reconciliation'` for every method; the module's own header
  comment says the register is the single entry path for **cheque/DD/PDC**, yet
  `Cash` is both in the `OfflinePaymentMethod` union and first in the dropdown.
  Money physically in the drawer is absent from the books until somebody
  independently opens the Reconciled tab.
- **Root cause:** an instrument-clearance workflow given a payment method that has
  no clearance step.
- **Recommended fix:** remove `Cash` from this dialog and route it to the counter
  collection dialog (which posts immediately); or, if it must stay, post the
  collection at record time for cash and skip the pending state. Also make the
  success copy state the actual effect — "recorded, pending clearance; not yet
  posted to the ledger" — instead of an unqualified success.
- **Dependencies:** E2E-009.
- **Risk of fixing:** low-medium (touches the money-posting decision; the
  reconcile machinery itself is sound and should not be altered).
- **Evidence:** `_shared/finance/finance_offline_payments_repository.ts:14-20`
  (`Cash` in the union), `createOfflinePayment` (status hard-coded);
  `lib/features/finance/payments/finance_offline_payments_screen.dart:308-317`
  (Cash first in the dropdown), `:400-408` (unqualified success snackbar).

### E2E-011 · **P0** · Teacher / Student records · The student risk dossier fabricates attendance, marks, homework and fee dues

- **Repro steps:** Sign in as a class teacher. Open
  `/teacher/class-teacher-dashboard` and **long-press** a student under "Students
  requiring attention" (the short tap is JOURNEY-010). The Student risk screen
  opens. Read the Attendance, Homework, **Fees** and per-subject rows.
- **Expected:** The student's real figures, or an honest "not available".
- **Actual:** Every metric row is fabricated by
  `TeacherStudentRiskService._snapshotFor`, which composes:
  - **attendance** = `MockAttendanceSyncStore.attendancePercent()`, and when that
    is unset (always, in a release build — the store's only writer is
    `MockTeacherRepository`) falls back to the constant **`92`**, or to `88`/`74`
    depending on marks;
  - **marks** = the constant **`75`**, overridden only by
    `ExamAdministrationStore.instance..ensureSeeded()` — the *seeded demo exam*
    (`exam_math_8a`, "Unit Test — Mathematics", marks 42/45/40… for the mock
    class 8-A roster);
  - **homework** = `SchoolHomeworkStore`, else the constant **`80`**;
  - **fees** = `student.feeAccountId == 'acct_ravi' ? '₹4,200 due' : 'No dues'` —
    a hard-coded fee statement keyed on a fixture account id.

  The screen renders these directly (`_Row('Fees', snapshot.feePendingLabel)`,
  `'${snapshot.attendancePercent}% · …'`). The live `/intelligence/risk/*` merge
  replaces **only** the risk level, score and reasons; every displayed metric
  still comes from the fabricated base, and on any live failure the whole
  fabricated snapshot is returned.

  Two consequences, both bad: a class teacher preparing for a parent meeting is
  shown "No dues" and "92% attendance" for a student who may owe fees and be at
  55% — a fabricated financial and attendance claim, which the register's standing
  rule makes P0. And because the roster comes from
  `MockCanonicalStudentRegistry.byId`, a **real** student id is not found and
  `snapshotForStudent` throws `StateError`, so at a real school the screen shows
  an error state instead — the feature is fabricated where it works and broken
  where it does not.
- **Root cause:** a demo-era service that was never replaced when the intelligence
  backend landed; the live merge was bolted onto the mock rather than replacing it.
- **Recommended fix:** source every row from real endpoints — attendance from
  `/attendance/*`, marks from the exams feed, homework from the homework store,
  fees from `/finance/student-accounts` — and render an honest per-row unknown
  state where a value is missing. Until then the screen should not ship.
- **Dependencies:** JOURNEY-010 (the short-tap route is separately broken);
  WIDGET-002 (same service also feeds `TeacherDashboardData.mock()`).
- **Risk of fixing:** medium — needs four real data sources wired into one screen.
- **Evidence:** `lib/core/communication/teacher_student_risk_service.dart:95-140`;
  `lib/features/teacher/communication/teacher_teaching_context_provider.dart:65-95`;
  `lib/features/teacher/student_risk/teacher_student_risk_screen.dart:29-46,94-102`;
  route `lib/router/app_router.dart:518-524`; entry
  `lib/features/teacher/dashboard/teacher_class_teacher_dashboard_screen.dart:124`;
  seed `lib/core/exams/exam_administration_store.dart:1491-1520`.

### E2E-012 · **P0** · Exams · "Export marks summary" exports a seeded demo exam

- **Repro steps:** Sign in as any teacher. Open **Exams**. Tap the share icon →
  **Export marks summary** → CSV or PDF. Open the file.
- **Expected:** The teacher's own exams in the marks-entry phase, with real
  entered/total counts.
- **Actual:** The export is built from
  `ExamAdministrationStore.instance.marksEntryProgress()`, which calls
  `ensureSeeded()` and — in a release build, where nothing ever populates the
  singleton from the API — returns the **seeded demo data**: `exam_math_8a`,
  *"Unit Test — Mathematics"*, grade 8, section A, with entered/total counts
  derived from the hard-coded mock roster. The exam list on the same screen comes
  from the API and shows the school's real exams; the export button beside it
  produces a document about an exam that does not exist. The file is shareable —
  it leaves the app, and it is examination data, which the standing rule makes P0.
- **Root cause:** the export was wired to the in-memory store that the marks-entry
  screen used before the API repository landed; the screen was migrated, the
  export was not.
- **Recommended fix:** derive the progress rows from the same
  `examAdministrationListProvider` + marks data the screen renders, or add a
  `GET /academics/exams/progress` read (the route already exists per the feature
  inventory) and export that.
- **Dependencies:** E2E-016 (same singleton; fixing one does not fix the other).
- **Risk of fixing:** low.
- **Evidence:** `lib/features/teacher/exams/teacher_exams_screen.dart:59-70`;
  `lib/core/exams/exam_administration_store.dart:839-862` (`ensureSeeded` inside
  `marksEntryProgress`), `:621-632`, `:1491-1520` (the seed).

### E2E-013 · **P2** · Exams · The create-exam dialog pre-fills a date, a time, a room and a term

- **Repro steps:** Exam administration → **Create exam**. Read the form before
  typing.
- **Expected:** Empty scheduling fields, or values derived from the school's
  calendar and rooms.
- **Actual:** Term = `'Term 2'`, date = **`'15 Mar 2026'`**, time =
  `'9:00 AM - 10:30 AM'`, venue = `'Room 8A'`. A user who fills in only the title
  and subject schedules an exam on a fixed date in a room that may not exist. The
  values then appear on the datesheet, the seating plan and the student's exam
  card. Same class as E2E-002, lower severity because the exam list makes the
  mistake visible.
- **Root cause:** demo defaults in `TextEditingController(text: …)`.
- **Recommended fix:** clear them; source venue from `GET /school/rooms` and term
  from the academic-year config.
- **Dependencies:** E2E-014.
- **Risk of fixing:** low.
- **Evidence:** `lib/features/academics/exam_admin/widgets/exam_create_dialog.dart:21-26`.

### E2E-014 · **P1** · Exams · An exam has no machine-readable date

- **Repro steps:** Create two exams for the same class on the same morning. Try to
  sort the datesheet chronologically, detect the clash, or have the system remind
  anyone the day before.
- **Expected:** An exam carries a date the system can compare.
- **Actual:** `exam_sessions` stores only `date_label TEXT NOT NULL DEFAULT ''`
  and `time_label TEXT`. There is no `exam_date` column, the create handler does
  no date parsing (`String(body.dateLabel ?? …).trim()`), and the client field is
  free text. So nothing can order a datesheet, detect a two-exams-one-slot clash,
  bound an exam to the academic year, or schedule a reminder from the exam date.
  Notably `marksEntryDeadline` **is** a validated timestamp on the same table —
  the deadline is machine-readable and the exam date is not.
- **Root cause:** label-only scheduling that was never upgraded when the
  deadline field showed the pattern.
- **Recommended fix:** add `exam_date DATE` (+ optional `start_time`/`end_time`),
  parse and validate on create/schedule, keep `date_label` for display, and
  backfill where parseable.
- **Dependencies:** E2E-013 (a date picker to produce the value).
- **Risk of fixing:** medium — migration plus a backfill of free-text dates.
- **Evidence:** `supabase/migrations/20260618120000_f4_exam_sessions.sql:12-13`;
  `_shared/academics/exam_administration/exam_administration_handlers.ts:449-455`
  (no parsing) vs `:470-483` (`parseDeadline`, which does it correctly).

### E2E-015 · **P1** · Report cards · The overall grade ignores the school's grading scale

- **Repro steps:** Configure the school for the CBSE (or State-Board SSC) scale.
  Publish results. Open the parent or student report card and compare the overall
  grade with the per-subject grades.
- **Expected:** One scale across the document.
- **Actual:** `ExamReportCardBuilder.fromPublishedResults` computes
  `overallGrade: ExamGradingScale.standard.gradeFor(overallPercent)` — the
  **standard** scale, hard-coded, always. Per-subject grades come from the server
  and follow whatever scale the server applied. A report card can therefore carry
  subject grades on one scale and an overall grade on another, with no indication
  which is which. The source comment states the behaviour, so it is deliberate —
  but a report card is a document a parent keeps and shows to the next school.

  Related and in the same builder: `rankShown` is hard-coded `false`, so the
  school's `showRankToParents` setting has no effect on any surface.
- **Root cause:** the published-results feed does not carry the school's scale, so
  the builder substituted a default rather than fetching it.
- **Recommended fix:** carry the school's grading scale on the published-results
  response (or read `GET /academics/exams/grade-scale` — see E2E-016) and use it
  for the overall grade; carry rank + `rankShown` on the same response.
- **Dependencies:** E2E-016; **XMOD-030** (the grading fork this sits on top of).
- **Risk of fixing:** low-medium.
- **Evidence:** `lib/core/exams/exam_report_card.dart:137-141,176-182`.

### E2E-016 · **P1** · Exams · The grading-scale setting never leaves the device

- **Repro steps:** As principal, open Exam administration → settings sheet, switch
  the grading scale and turn rank visibility on. Sign in on another device, or as
  another user, and look at the same sheet. Then check `audit_events`.
- **Expected:** A school-level configuration change, persisted, audited, and
  visible to everyone.
- **Actual:** `ExamReportSettingsNotifier` reads and writes only
  `ExamAdministrationStore.instance` — an in-memory singleton with a local
  snapshot file. **No code in `lib/` calls `/academics/exams/grade-scale`**
  (grep for `grade-scale`/`gradeScale` across `lib/` returns nothing), even though
  the backend implements `GET` and `PUT` for it and writes an audit row on save.
  So the change is invisible to every other device and user, is never audited, and
  never reaches any server-side grade computation. The endpoint is orphaned from
  the client.

  Compounding it, `examReportSettingsProvider` is declared **twice** under the
  same name — a `NotifierProvider` in `exam_settings_provider.dart:9` and a
  dependency-free `Provider` in `exam_reports_provider.dart:116`. The settings
  sheet and create dialog import the former; the exam **reports** screen imports
  the latter, which reads the singleton once and, having nothing to watch, caches
  it for the app's lifetime — so a scale change does not reach tabulation, merit
  or distribution reports in the same session.
- **Root cause:** a local-first settings implementation that was never connected
  when the endpoint shipped, plus a duplicated provider name across two files.
- **Recommended fix:** back the notifier with `GET`/`PUT
  /academics/exams/grade-scale`; delete the duplicate `Provider` in
  `exam_reports_provider.dart` and have the reports screen watch the notifier.
- **Dependencies:** E2E-015 consumes the result.
- **Risk of fixing:** low.
- **Evidence:** `lib/features/academics/exam_admin/exam_settings_provider.dart:14-37`;
  `lib/features/academics/exam_admin/exam_reports_provider.dart:116-118`;
  `lib/core/exams/exam_administration_store.dart:604-614`;
  backend `_shared/academics/exam_administration/exam_administration_handlers.ts:1207-1290`;
  router `_shared/academics/exam_administration/exam_administration_router.ts:62-64`.

### E2E-017 · **P0** · SIS · Admissions · Homework · Every document "upload" in the product uploads a synthetic empty PDF

- **Repro steps:**
  1. **SIS:** open a student profile → **Upload student document**. Type
     "Birth Certificate" and "birth_certificate.pdf". Tap **Upload**. Then open
     the document from the profile.
  2. **Admissions:** open an application → upload a required document. Same.
  3. **Student app:** submit homework with an attachment. Open it as the teacher.
  4. **Teacher app:** attach a file to a homework. Open it as the student.
- **Expected:** A file chooser, and the chosen file stored.
- **Actual:** **There is no file picker on any of these screens.** Each dialog
  collects a *document type* and a *file name* as free text, and then uploads a
  hard-coded 5-line PDF — `%PDF-1.4 … MediaBox[0 0 200 200] … %%EOF`, a blank
  200×200 page — through the real presign → PUT → confirm Storage path. The
  document row is created with the name the user typed, the bytes are synthetic,
  and the school's record now asserts it holds a document it does not hold.
  `image_picker` is in `pubspec.yaml` but is used **only** by the support
  "Report an issue" screen (`report_issue_screen.dart:54`); `file_picker` is not
  a dependency at all.

  The severity is not the empty file — it is what the product does with it next:
  - a clerk can then open **Verify document** and mark that empty PDF
    **verified**, which is a governance decision recorded against a student;
  - an admission can be approved on a "documents complete" checklist satisfied
    entirely by blank pages;
  - a TC / no-dues clearance can cite verified documents that do not exist;
  - a teacher grades a homework "submission" that is a blank page;
  - a parent's medical-certificate reference for a leave is a file name only.

  Each source file documents the substitution as a deliberate stand-in — "no OS
  file picker dependency in the app", "wiring a native picker is a tracked UX
  follow-up" — but the substitution ships in the release build, on the paths a
  school uses to hold legally significant records. Fabricated records data
  reaching a production write; P0 by the standing rule.
- **Root cause:** the Storage path (presign/PUT/confirm) was built and tested with
  synthetic bytes so it could be exercised without a platform picker; the picker
  was never added and the synthetic payload became the shipping behaviour.
- **Recommended fix:** add `file_picker` (or extend the existing `image_picker`
  use) and pass the real bytes + real MIME type + real file name on all four
  paths. Until then, hide the upload actions rather than write blank documents,
  and treat any existing rows created by these paths as unverified.
- **Dependencies:** blocks any certification of Admissions document verification,
  SIS document verification, TC/clearance (**XMOD-021**) and homework grading.
- **Risk of fixing:** low-medium — the server side is already correct; this is a
  client capability gap plus a MIME/size validation pass on the presign endpoint.
- **Evidence:** `lib/features/sis/sis_mutations_provider.dart:136-160`;
  `lib/features/sis/sis_workflow_actions.dart:28-40,74-90` (and the verify dialog
  immediately below at `:98-130`);
  `lib/features/admissions/admissions_workflow_actions.dart:478-487`;
  `lib/features/student_app/student_mutations_provider.dart:60-90`;
  `lib/features/teacher/teacher_mutations_provider.dart:618-648`;
  `pubspec.yaml:58` (only `image_picker`, used solely at
  `lib/features/support/report_issue_screen.dart:54`).

### E2E-018 · **P1** · HR / Payroll · The payroll period is free text, so the statutory month is always null and a month can be run twice

- **Repro steps:**
  1. HR → Payroll → **Generate payroll run**. The period is pre-filled
     `"July 2026"` (helper text: *"Period (e.g. July 2026)"*). Generate.
  2. Configure a state with a special-month Professional Tax slab (e.g. the
     February slab used in several states) and generate that month's run. Compare
     the PT deducted with the configured special-month slab.
  3. Generate again, this time typing `"Jul 2026"`.
- **Expected:** One run per calendar month; the special-month PT slab applied in
  that month.
- **Actual:**
  - **The special-month PT slab can never be selected.** The handler computes
    `statutory.month = monthFromPeriod(period)`, and `monthFromPeriod` matches
    `/^\d{4}-(\d{2})/` — a `YYYY-MM` period. The app's own default and helper text
    produce `"July 2026"`, which never matches, so `month` is `null` on every run
    generated from the app. `computePtFromSlabs` then does
    `month != null ? inBand.find(s => s.month === month) : undefined`, falls
    through to the month-agnostic slab, and a school that configured a
    special-month slab silently never gets it. A statutory deduction, computed on
    the wrong slab, on every payslip in that month.
  - **A month can be run twice.** `payrollRunIdForPeriod` slugs the free text, so
    `"July 2026"` → `pay_run_july_2026`, `"Jul 2026"` → `pay_run_jul_2026`,
    `"2026-07"` → `pay_run_2026_07` — three distinct runs, each independently
    processable into payslips, for one month. `period` is `requireStr` on the
    server with no format check and no uniqueness constraint on the month.
- **Root cause:** two representations of a period — a human label in the client
  and `YYYY-MM` in the statutory engine — with no normalisation between them.
- **Recommended fix:** replace the text field with a month picker producing
  `YYYY-MM`; validate the format server-side (422 otherwise); derive the display
  label for the UI; and reject a second draft for a month that already has a
  processed run.
- **Dependencies:** **XMOD-012** (LOP term zero) and **XMOD-003** (approved leave
  counted as absence) affect the same run; all three should be fixed together
  before payroll is certified.
- **Risk of fixing:** medium — changes run ids, so existing runs need a mapping.
- **Evidence:** `lib/features/hr/hr_workflow_actions.dart:451,478-487,509-524`;
  `_shared/hr/hr_write_handlers.ts:1573,1609-1621`;
  `_shared/hr/statutory_payroll.ts:358-363` (the `YYYY-MM` parser),
  `:198-215` (special-month slab selection), `:356` (the comment that documents
  the null case without noticing the client never satisfies the parser).

### E2E-019 · **P0** · Inventory / Procurement · A purchase order cannot be created — the client sends the vendor's name where a UUID is required

- **Repro steps:** Inventory → Procurement → **Create purchase order**. Select a
  vendor from the dropdown, type items and a total, tap **Create draft PO**.
- **Expected:** A draft PO.
- **Actual:** An error. `ApiInventoryRepository.createProcurementOrder` builds the
  request body with **`'vendorId': request.vendorName.trim()`** — the vendor's
  human display name — discarding the `vendorId` the dialog carefully captured
  from the selected catalog row. `purchase_orders.vendor_id` is
  `UUID NOT NULL REFERENCES inventory_vendors (id)`, so Postgres rejects the
  INSERT with `invalid input syntax for type uuid` (22P02). The handler's catch
  maps only `PO_LINES_REQUIRED`, so the error rethrows as an unmapped **500** and
  the user sees a generic failure with no indication of what is wrong. Procurement
  — the module's primary write — is unusable on the live path.

  `withMockWriteFallback` does **not** rescue it: it catches only
  `ApiNotConnectedException`, which nothing in the codebase throws. So this fails
  loudly rather than silently, which is the one good thing about it.
- **Root cause:** the adapter that translates the app's free-text PO into the
  server's structured PO uses the wrong field. The adapter's own comment
  enumerates what the server needs ("requires a vendorId, a poNumber, and
  structured lines") and then supplies the name.
- **Recommended fix:** send `request.vendorId`. Separately: map 22P02 / FK
  violations in the handler to a 422 with a useful message; and consider whether
  the single synthetic line (`sku: 'GEN-<PO>'`, `quantity: 1`,
  `unitCost: <whole total>`) is acceptable — it makes per-item goods receipt
  against the PO impossible, and `total_amount INTEGER` drops any paise.
- **Dependencies:** blocks certification of goods receipt, the AP commitment and
  the inventory→finance reconciliation that consume the PO.
- **Risk of fixing:** low for the field; medium if a real line-item editor is
  added.
- **Evidence:** `lib/core/repositories/api/inventory/api_inventory_repository.dart:124-160`
  (line 143 is the defect);
  `lib/features/inventory/inventory_workflow_actions.dart:130-145` (the dialog
  does capture `vendor.id`);
  `supabase/migrations/20260614920000_inventory_finance_integration.sql:3-15`;
  `_shared/inventory_finance/inventory_finance_handlers.ts` (`handleCreatePurchaseOrder`,
  catch maps only `PO_LINES_REQUIRED`);
  `lib/core/repositories/api/hybrid_write_fallback.dart:4-13`.

### E2E-020 · **P2** · Admissions · A follow-up is "scheduled" for a string

- **Repro steps:** Admissions → a lead → **Add follow-up**. The Scheduled field is
  pre-filled `'Tomorrow 10:00 AM'`. Save. Wait until tomorrow at 10:00.
- **Expected:** The counsellor is reminded, or at least the lead list can be
  sorted by what is due.
- **Actual:** `FollowUpRequest.scheduledLabel` is a display string. Nothing parses
  it, nothing schedules from it, and the default means a counsellor who types only
  the task creates a follow-up nominally due "Tomorrow 10:00 AM" forever. The same
  literal is the default in the second scheduling dialog at
  `admissions_workflow_actions.dart:623`.
- **Root cause:** the label-instead-of-date pattern described in §7 of the finding
  document.
- **Recommended fix:** a date-time picker writing a real timestamp, with the label
  derived for display; then the follow-up can join the reminder rail
  (**XMOD-033**) once a scheduler exists (**XMOD-016**).
- **Dependencies:** XMOD-016.
- **Risk of fixing:** low.
- **Evidence:** `lib/features/admissions/admissions_workflow_actions.dart:216,247-254,623`.

### E2E-021 · **P2** · AI content · A failed generation is returned as generated content

- **Repro steps:** Open the AI content composer, enter a prompt, generate, with
  the AI gateway unavailable (no key, network failure, rate limit).
- **Expected:** An honest failure state.
- **Actual:** `AiContentService` catches **every** exception and returns an
  `AiGeneratedContent` whose body is the user's own prompt reformatted —
  `"Notice: <prompt>\n\nAudience: <audience>. Tone: <tone>."` — stamped
  `generatedAt: DateTime.now()`. The UI cannot tell this from a real generation.
  If that text is then sent as a broadcast, the school has published a machine's
  echo of its own instruction as if it were composed content.
- **Root cause:** a catch-all fallback that returns a success-shaped value.
- **Recommended fix:** rethrow, and let the composer show the failure; if a
  degraded template is wanted, mark it explicitly and block the send action.
- **Dependencies:** none. Belongs to the AI certification suite (workstream 8);
  recorded here because it was found while tracing the communication chain.
- **Risk of fixing:** low.
- **Evidence:** `lib/features/copilot/content/ai_content_service.dart:32-39`.

### AI-001 · **P1** · DAI / Global search · Fixing DAI-005 before DAI-016 turns 34 silent misroutes into 34 visible false answers

- **Repro steps:** Run `flutter test test/core/dai/` and read
  `build/dai_certification_report.txt` §WS8-1. Then, as a thought experiment the
  test makes concrete: give `DaiIntentKind.openPerson` a non-null route (the fix
  DAI-005 asks for) and re-run. Type `payroll`, `timetable`, `gate pass`,
  `audit log`, `settings`, `apply leave`, `hostel rooms` or `report card` into
  the admin search box.
- **Expected:** A query the product cannot answer produces no card, so the user
  falls through to plain directory search.
- **Actual:** `_person` is the last rule in the chain and accepts any unmatched
  one-to-three-word alphabetic phrase, so **34 of the 42 out-of-vocabulary
  queries in the certification corpus resolve to `openPerson` at confidence 60**
  — "Looking for Payroll…", "Looking for Gate Pass…", "Looking for Audit Log…".
  Honest refusal is **7/42 = 16.7%**. Today none of this is visible, *solely*
  because `openPerson` has a null route and the overlay filters it before render
  (DAI-005). The injection probes are worse: 12 of 46 become a person, including
  "Looking for Rm Rf…", "Looking for Etc Passwd…" and "Looking for Hr Payroll…".
- **Root cause:** two defects are load-bearing on each other. DAI-005 (dead
  intent) is currently *masking* DAI-016 (junk drawer). Each is filed as an
  independent defect, so a remediation wave that picks up DAI-005 alone — the
  smaller, more obviously-correct-looking change — makes the product visibly
  worse than it is today.
- **Recommended fix:** sequence it. **DAI-016 first**: give `_person` a positive
  admission test (an explicit qualifier such as `teacher`/`student`/`sir`, a
  directory hit, or a name-shaped token that is not a known module noun) instead
  of accepting everything the earlier rules declined. Add a module-noun stop
  list covering the 21 uncovered modules. **Only then** wire DAI-005's directory
  lookup. The harness enforces the order: `AI-002 · the junk drawer` asserts
  every swallowed query still has a null route, and fails the moment
  `openPerson` gains one while the drawer is still open.
- **Dependencies:** DAI-005, DAI-016. Interacts with DAI-007 (an "I don't handle
  that" state is the honest destination for these 34 queries).
- **Risk of fixing:** medium. Tightening `_person` will cost recall on genuine
  bare names ("Rohan" is currently confidence 60 with no qualifier); the
  directory fallback beneath the card already handles those, so the loss is
  smaller than it looks.
- **Evidence:** `lib/core/dai/dai_resolver.dart:295-350` (`_person`, last in
  `_rules` at :77); `test/core/dai/dai_certification_suite_test.dart`
  → `AI-002 · the junk drawer — and why DAI-005 must not be fixed alone`;
  `build/dai_certification_report.txt` §WS8-1 confusion pairs (`unknown ->
  openPerson`, 34) and §WS8-4 BLOCKLIST.

### AI-002 · **P1** · DAI / Global search · A query naming two modules is answered by whichever rule comes first, with a confident sentence from the wrong one

- **Repro steps:** In the admin search box type `attendance defaulters`. Then
  type `Rohan marks`.
- **Expected:** `attendance defaulters` → the attendance-shortage list.
  `Rohan marks` → that student's report card / dossier.
- **Actual:** `attendance defaulters` resolves to **`feeDefaulters`** at
  confidence 90, opens `/finance/defaulters`, and the card reads *"Showing
  students with outstanding fees."* — an attendance question answered with a
  **money** list. `Rohan marks` resolves to `exams` at confidence 88 and opens
  `/school/exam-administration`, the whole-school exam console, for a
  one-student question.
- **Root cause:** `DaiResolver.resolve` (`dai_resolver.dart:50-53`) returns the
  first rule that yields non-null; there is no head-noun/modifier analysis and
  no contest between rules. `_feeDefaulters` (`:131`) fires on the bare token
  `defaulters` with no fee word required, so the *attendance* modifier is never
  consulted. `_exams` fires on `marks` and discards the name entirely.
- **Recommended fix:** when two module keywords are present, prefer the head
  noun (the last content word) and require the earlier rule's own domain word;
  i.e. `_feeDefaulters` should not fire on `defaulters` when an attendance word
  is also present. Where a person name co-occurs with a module word, resolve to
  the person-scoped view of that module rather than the school-wide screen.
- **Dependencies:** related to DAI-009 (multi-intent silently drops half the
  question) and DAI-010 (`staff attendance today` opens student attendance) —
  same root cause, different pairs. Fixing rule precedence should address all
  three together.
- **Risk of fixing:** medium — precedence changes ripple across the whole rule
  chain. The golden corpus in `test/core/dai/dai_certification_suite_test.dart`
  pins the current chain (`homework attendance fees today` → attendanceToday;
  `fee dues class 8` → openClass) so any ripple is visible in the diff.
- **Evidence:** `lib/core/dai/dai_resolver.dart:50-53` (first-match-wins),
  `:128-149` (`_feeDefaulters`, `defaulters` alone suffices), `:231-244`
  (`_exams`); `build/dai_certification_report.txt` §WS8-1 MISSES.

### AI-003 · **P1** · DAI / SIS · Roll number and admission number — how Indian schools actually identify a student — cannot be resolved

- **Repro steps:** Type `roll number 23`, then `admission number 4471`, then
  `roll no 12 class 8a`.
- **Expected:** the student's dossier, or at minimum the class roster scrolled
  to that roll number.
- **Actual:** `roll number 23` → **unknown**, no card. `admission number 4471` →
  **unknown**, no card. `roll no 12 class 8a` → **openClass** at confidence 82:
  the roll number is silently dropped and the entire class roster opens.
- **Root cause:** there is no identifier rule. `_person` rejects any string
  containing a digit (`dai_resolver.dart:312`) precisely to stop
  "grade 10 fee defaulters" being read as a name, which also excludes every
  numeric identifier. `_receipt` is the only rule that parses a number, and it
  requires the literal token `receipt` first (`:112`).
- **Recommended fix:** add a `_studentIdentifier` rule ahead of `_classLookup`
  matching `roll (no|number)? <n>`, `adm(ission)? (no|number)? <n>` and a bare
  admission-number pattern, emitting `openPerson` with the identifier carried in
  a new field — or, once DAI-005 is wired, resolving through the RBAC-scoped
  directory by identifier rather than by name. Scope it with the class when both
  are present.
- **Dependencies:** DAI-005 (the person path must render before an identifier
  lookup has anywhere to land); AI-001 (do not widen `_person` to accept digits
  while it is still the catch-all).
- **Risk of fixing:** low-medium. A dedicated rule placed before `_classLookup`
  is additive; the risk is stealing queries from `_classLookup`, which the
  golden corpus pins.
- **Evidence:** `lib/core/dai/dai_resolver.dart:312` (digit rejection), `:111-124`
  (`_receipt` requires "receipt"), `:273-288` (`_classLookup` takes
  `roll no 12 class 8a`); `build/dai_certification_report.txt` §WS8-1 MISSES;
  `docs/certification/findings/AI-certification-suite.md` §1.4.

### AI-004 · **P2** · DAI / Test integrity · The shipping golden corpus certifies destinations no user can reach

- **Repro steps:** Read `test/core/dai/dai_resolver_test.dart:15-23` (the corpus
  doc comment), then rows `:41-44` and `:62-70`. Run `flutter test
  test/core/dai/dai_resolver_test.dart` — all green.
- **Expected:** a golden corpus described as "the NLU certification … with the
  destination it must resolve to" should pin outcomes a user can actually obtain.
- **Actual:** the file states it covers "every phrasing a principal, teacher,
  parent or student is expected to type", but **teacher, parent and student can
  never open the DAI surface at all** (one call site, admin shell only — WS5 §1,
  re-confirmed in WS8 §2.1 where all three personas score 100% `noSurface`). It
  pins `_Case('Has my child paid fees?', myFees, route: parentFees)`,
  `_Case('My attendance', myAttendance, route: studentAttendance)` and
  `_Case('My exam schedule', exams, route: studentExams)` as certified
  destinations that no reachable user can be delivered to, and four `openPerson`
  rows for an intent that never renders (DAI-005). The suite is green while
  asserting a false premise — the exact failure mode the charter's honesty rules
  single out.
- **Root cause:** the corpus was written against the resolver in isolation,
  before the single-call-site constraint and the shell guard were understood. It
  tests the function, and documents itself as testing the product.
- **Recommended fix:** do not delete the rows — they are correct assertions about
  the *resolver*. Correct the doc comment to say it certifies resolver output
  only, and annotate the four persona rows and four `openPerson` rows with the
  defect that makes them unreachable, as
  `test/core/dai/dai_certification_suite_test.dart` does. End-to-end reachability
  is certified there.
- **Dependencies:** DAI-002, DAI-003, DAI-005. Once those are fixed the rows
  become honest and the annotations can go.
- **Risk of fixing:** none — comments and test names only.
- **Evidence:** `test/core/dai/dai_resolver_test.dart:15-23, 41-44, 62-70`;
  `lib/features/admin/global_search/global_search_overlay.dart:83`;
  `lib/features/admin/screens/admin_content_scaffold.dart:82`;
  `build/dai_certification_report.txt` §WS8-2.

### AI-005 · **P2** · DAI / Global search · A two-character class label can never be answered, whatever the resolver does

- **Repro steps:** Open the admin search overlay and type `8A`. Then `9B`,
  `10`, `KG`.
- **Expected:** `8A` opens Class 8A — it is how staff refer to a section in
  speech and on paper.
- **Actual:** no DAI card, ever. `_resolveDai` returns before calling the
  resolver: `if (_query.length < 3) return null`
  (`global_search_overlay.dart:82`). `8A` is two characters, so is `9B`, so is
  `KG`. Even after `_classLookup` is taught bare labels (WS5 recorded `8A` →
  unknown), the card would still never appear.
- **Root cause:** a length heuristic in the consumer, intended to stop the card
  flickering on the first keystrokes, sitting in front of a vocabulary whose
  shortest valid terms are two characters.
- **Recommended fix:** lower the floor to 2, or bypass it for inputs matching a
  class-label shape (`\d{1,2}[a-e]?`). Debounce rather than length-gate if the
  concern is flicker.
- **Dependencies:** must be fixed together with the resolver-side gap (`8A` and
  `section B` do not resolve today) — fixing either alone changes nothing the
  user can see.
- **Risk of fixing:** low. Lowering the floor makes the card appear on
  two-character input; with the junk drawer still open (AI-001) that is a reason
  to sequence this after AI-001, not before.
- **Evidence:** `lib/features/admin/global_search/global_search_overlay.dart:82`;
  `test/core/dai/dai_certification_suite_test.dart` → `sub-3-character input
  never reaches the resolver in production`.

### AI-006 · **P2** · DAI / Homework · The same card delivers or bounces depending on hats the card never mentions

- **Repro steps:** As a **principal** (staff, no `ErpRole.teacher`), type
  `pending homework` and tap the card. Then repeat as a staff user who also
  holds `ErpRole.teacher` (e.g. Teacher + Inventory Manager).
- **Expected:** either both land, or the card is not offered to the user who
  cannot land.
- **Actual:** both see the identical card — *"Showing pending homework."*,
  confidence 92, no permission required. The teacher-hatted staff user lands on
  `/teacher/homework`. The principal and the accounts clerk are bounced to
  `/admin`. The card is identical in both cases and mentions nothing about
  teaching claims.
- **Root cause:** `_homework` carries `requiredPermission: null` by deliberate
  choice (`dai_resolver.dart:222-224`: "the teacher shell guards the route by
  persona, so leave requiredPermission null rather than invent a permission
  RBAC does not know about"). The reasoning is sound; the consequence is that
  the overlay's permission filter is a no-op for this intent, and the persona
  guard it defers to (`app_router.dart:2288-2290`) runs only *after* the user
  has tapped.
- **Recommended fix:** filter on shell reachability, not only on permission —
  the overlay should drop any intent whose route the current session cannot
  enter. That single change also closes DAI-001 and DAI-002 and would have
  prevented this class of defect at the source, exactly as removing the tiles
  did for the search registry on 2026-07-28.
- **Dependencies:** DAI-001, DAI-002 — same fix. **Corrects the scope of
  DAI-002**, which recorded `homework` as uniformly bouncing; it is conditional,
  so the remedy is to gate the card, not to delete the intent.
- **Risk of fixing:** low. A reachability predicate already exists in production
  (`isAdminErpRoute` + `isPersonaOwnedRoute`); the overlay needs to call it.
- **Evidence:** `lib/core/dai/dai_resolver.dart:215-228`;
  `lib/router/app_router.dart:2286-2292`;
  `lib/features/admin/global_search/global_search_overlay.dart:81-89`;
  `lib/router/global_search_registry.dart:193-212` (the same fix, already taken
  on the registry half of the sheet);
  `test/core/dai/dai_certification_suite_test.dart` → `REFINES WS5 · homework is
  dead for plain staff, live for a teacher-hat`.

<!-- ═══════════════════════════════════════════════════════════════════════
     POLISH — Workstream 9, Product polish (2026-07-29)
     Full trace: docs/certification/findings/POLISH-product-polish.md
     Standard applied: "would a principal paying for this believe it is
     finished?" A control that responds visually but changes no outcome is
     treated as polish-critical, per WS6's dead-filter-chip precedent.
     WIDGET-008/009/010 (ten dashboard filter bars) are NOT re-reported.
     ═══════════════════════════════════════════════════════════════════════ -->

### POLISH-001 · **P0** ⭐PRIORITY-REMEDIATION-CANDIDATE · Admin shell / Auth · No staff persona can log out; the only profile affordance says "coming soon"

- **Repro steps:** Build a release build (`APP_ENV=production`). Sign in as any
  staff role — principal, teacher, accountant, admissions counsellor. Tap the
  avatar in the top app bar, which renders as an enabled button
  (`Semantics(button: true, label: 'Staff profile')`). Then try to find any
  other way to end the session.
- **Expected:** A profile menu, or at minimum a log out action, reachable by
  every persona.
- **Actual:** A snackbar reading **"Profile menu coming soon."** — and there is
  no log-out anywhere else. `confirmAndLogout`
  (`lib/features/auth/auth_logout.dart:11`) has three call sites: the
  dev-only branch of the admin scaffold, the parent profile screen, and nothing
  else. Teacher profile (`teacher_profile_screen.dart:157`, whose "Account"
  section offers only Settings and Legal), teacher settings, student profile and
  SIS profile were each checked and contain none. **Parents can log out. Nobody
  else can.**
- **Root cause:** `lib/features/admin/admin_content_scaffold.dart:88-111`
  branches on `isQaLoginEnabledProvider`; the log-out bottom sheet is inside the
  QA branch, and `guardForRelease` forces `enableQaLogin: false` in a release
  build (`lib/core/config/environment.dart:161`). The fallback is
  `_showPlaceholderSnackBar` — a method whose name says what it is
  (`admin_content_scaffold.dart:57`). None of the 20 `AdminContentScaffold(`
  call sites passes `onProfileTap`. The only other session-clearing paths are
  the biometric App Lock recovery button (`lib/app/app.dart:152`, requires App
  Lock enabled *and* engaged) and declining the legal gate
  (`lib/features/legal/legal_acceptance_screen.dart:64`).
- **Why P0 and why a priority candidate:** Indian schools run shared devices —
  the front-office tablet, the staff-room device, the principal's phone handed
  to the VP. A teacher who finishes marking attendance cannot end their session,
  so the next person inherits authenticated access to student PII, fee
  collection and marks entry. A staff member who leaves the school keeps a live
  session until the token expires. It is simultaneously a privacy-breach vector,
  a core daily workflow that cannot complete, and the **first personal
  affordance a principal touches** — they will tap their own avatar within the
  first minute of an evaluation and be told the product is unfinished.
- **Recommended fix:** Move the log-out sheet out of the QA branch and give it a
  real profile menu (name, role, school, Appearance, Support, Log out). The
  sheet already exists and works — it is one conditional away.
- **Dependencies:** None. This is the cheapest P0 in the register.
- **Risk of fixing:** Low.
- **Evidence:** `lib/features/admin/admin_content_scaffold.dart:57,88-111`;
  `lib/core/config/environment.dart:161`;
  `lib/core/config/environment_provider.dart:21-23`;
  `lib/features/auth/auth_logout.dart:11`;
  `lib/features/admin/admin_app_bar.dart:120-131`;
  `lib/features/teacher/profile/teacher_profile_screen.dart:157,166,173`.

### POLISH-002 · **P1** · Admin shell / Notifications · The bell opens the parent inbox and its badge can never show a count

- **Repro steps:** Sign in as principal. Note the bell in the admin app bar. (a)
  Have anything at all become unread. (b) Tap the bell.
- **Expected:** (a) A badge count. (b) A staff-scoped notifications inbox.
- **Actual:** (a) The badge never appears. (b) The parent persona's route
  `/parent/notifications` opens.
- **Root cause:** `lib/features/admin/admin_content_scaffold.dart:83-84` defaults
  `onNotificationsTap` to `context.push(RouteNames.parentNotifications)` and no
  admin screen overrides it. Separately, `unreadNotifications` is declared on
  `AdminAppBar` (`admin_app_bar.dart:19,29,101-102`) and piped through
  `AdminContentScaffold` (`:31,48,81`) with a default of `0` — and **none of the
  20 `AdminContentScaffold(` call sites passes it.** The router comment at
  `app_router.dart:290-292` records that the *teacher* bell was already moved off
  the parent path for exactly this reason (F-128, giving
  `/teacher/notifications`); the admin shell was not given the same treatment.
  The student shell wires the badge correctly
  (`student_app/dashboard/student_dashboard_screen.dart:57`), which is what makes
  the admin omission an oversight rather than a decision.
- **Recommended fix:** Add `/admin/notifications` (or reuse
  `/teacher/notifications`, which is already role-neutral) and wire
  `unreadNotifications` from the notifications provider in the shell rather than
  per screen.
- **Dependencies:** None.
- **Risk of fixing:** Low.
- **Evidence:** `lib/features/admin/admin_content_scaffold.dart:31,48,81,83-84`;
  `lib/features/admin/admin_app_bar.dart:19,29,101-102`;
  `lib/router/app_router.dart:284-296`; `lib/router/route_names.dart:36`.

### POLISH-003 · **P1** · All admin modules · Pull-to-refresh exists on 1 of 78 admin list screens

- **Repro steps:** Open Finance → Collections while the accountant posts a
  receipt at the counter. Pull down. Repeat on defaulters, admissions leads,
  hostel rooms, library circulation, inventory, gate pass, certificate desk.
- **Expected:** The list reloads, as it does everywhere in the parent app.
- **Actual:** Nothing happens, and there is no refresh button either. The only
  way to see new data is to navigate away and come back.
- **Root cause:** There are **19 `RefreshIndicator`s in the app; 18 are in the
  parent / student / teacher / notifications / support surfaces.** The single
  admin exception is
  `lib/features/management/school_calendar/school_calendar_screen.dart:79`. Only
  two admin screens carry an `Icons.refresh` action (`school_calendar_screen.dart:55`,
  `intelligence/student_success/student_success_screen.dart:167`), and
  `lib/shared/widgets/akshara_app_bar.dart` has no built-in refresh.
- **Recommended fix:** Wrap the scroll body in `ErpAsyncBody` with a
  `RefreshIndicator` bound to the `onRetry` callback **every one of the 78
  screens already passes**. This is one shared wrapper, not 78 changes.
- **Dependencies:** None.
- **Risk of fixing:** Low — the invalidate path already exists and is exercised
  by the error-retry flow.
- **Evidence:** `lib/shared/async/erp_async_state.dart:77`;
  `lib/features/management/school_calendar/school_calendar_screen.dart:55,79`;
  `lib/shared/widgets/akshara_app_bar.dart`.

### POLISH-004 · **P1** · Platform, Intelligence, Verticals · Permission-denied renders as a bare sentence on a blank white screen (17 screens)

- **Repro steps:** As a principal exploring the product, open any module you do
  not hold the permission for — Platform Operations, White Label, Branch,
  Franchise, Platform Intelligence, Student Success, Exam Intelligence, Trust
  Intelligence, Industry Hub, or any of the four vertical dashboards.
- **Expected:** The permission state the design system already models —
  `AksharaErrorState.fromFailure` with `AksharaFailureKind.permission` has its
  own icon, tone and copy.
- **Actual:** A centred grey sentence on an otherwise empty `Scaffold`. No icon,
  no "ask your administrator", no back action, no branding. **Indistinguishable
  from a crash** — and this is the state a principal is most likely to hit,
  because exploring means opening things you are not entitled to.
- **Root cause:** 17 screens hand-roll the denial instead of calling the
  purpose-built widget.
- **Recommended fix:** Replace each with `AksharaErrorState.fromFailure(...)`.
  Mechanical; the widget takes the same information these screens already have.
- **Dependencies:** None.
- **Risk of fixing:** Low.
- **Evidence:** `lib/features/platform/platform_operations/platform_operations_hub_screen.dart:56`;
  `lib/features/platform/white_label/white_label_hub_screen.dart:18`;
  `lib/features/platform/branch/branch_screen.dart:19`;
  `lib/features/platform/franchise/franchise_screen.dart:19`;
  `lib/features/platform/control_center/intelligence/platform_intelligence_screen.dart:46`;
  `lib/features/intelligence/student_success/student_success_screen.dart:53`;
  `lib/features/intelligence/exam/exam_intelligence_screen.dart:59`;
  `lib/features/intelligence/intelligence_screen.dart:228,297,367`;
  `lib/features/intelligence/trust/trust_intelligence_hub_screen.dart:51`;
  `lib/features/industry/industry_hub_screen.dart:24`;
  `lib/features/verticals/{restaurant,salon,healthcare,accommodation}/*_dashboard_screen.dart:19`.

### POLISH-005 · **P1** · Platform Operations · The hub prints 22 raw exception dumps to the user

- **Repro steps:** Open Platform Operations with the backend unreachable.
- **Expected:** A styled error state with retry.
- **Actual:** `App health error: DioException [connection error]: ...` rendered
  inline in a card, in **22 places**, with no retry on any of them.
- **Root cause:** The screen interpolates `$error` directly into `Text` at lines
  `212, 231, 250, 279, 298, 330, 354, 372, 472, 483, 502, 562, 582, 601, 619,
  638, 667, 686, 736, 762`, plus `:143` (`subtitle: Text('Unavailable: $error')`).
  Its loading state is a bare `LinearProgressIndicator` (`:211,229,248,277,296`).
- **Why this matters beyond the screen:** the RC phase closed exactly this defect
  class ("Raw `DioException` text incl. internal endpoint URLs on the day-one
  import screen", `docs/roadmap/RC_EXECUTION_LOG.md:71`). The instance was fixed;
  the class was not swept, and this screen has 22 of them.
- **Recommended fix:** Route all 22 through `AksharaErrorState` / `ErpAsyncBody`.
- **Dependencies:** None.
- **Risk of fixing:** Low.
- **Evidence:** `lib/features/platform/platform_operations/platform_operations_hub_screen.dart:143,211-762`.

### POLISH-006 · **P1** · Copilot / AI · Every AI quick action opens an empty chat

- **Repro steps:** From the AI dock (or the bottom-nav AI slot, or the admin nav
  rail), pick a quick action such as "Explain fee defaulters".
- **Expected:** The assistant opens with that prompt staged in the composer.
- **Actual:** The assistant opens **blank**. Every quick action, every persona.
- **Root cause:** `lib/features/copilot/widgets/copilot_ai_quick_actions.dart:132`
  (`executeCopilotQuickAction`) writes the prompt into
  `copilotMessageDraftProvider` (`lib/features/copilot/copilot_provider.dart:19`)
  — **a provider that is never read anywhere in the repository.** The composer
  (`copilot_screen.dart:29`, `_messageController`) is constructed empty. This is
  the WIDGET-008 defect shape (state written, never consumed) on the product's
  flagship AI surface.
- **Recommended fix:** Seed `_messageController.text` from
  `copilotMessageDraftProvider` on mount and clear the provider after read.
- **Dependencies:** None.
- **Risk of fixing:** Low.
- **Evidence:** `lib/features/copilot/widgets/copilot_ai_quick_actions.dart:132`;
  `lib/features/copilot/copilot_provider.dart:19`;
  `lib/features/copilot/copilot_screen.dart:29`;
  entry points `copilot/dock/copilot_floating_dock.dart:63`,
  `copilot_bottom_nav_ai_slot.dart`,
  `lib/features/admin/admin_navigation_rail.dart:204`.

### POLISH-007 · **P1** · Accessibility / Motion · The OS "Reduce motion" setting has no effect anywhere in the app

- **Repro steps:** Enable Reduce Motion / Remove Animations in Android or iOS
  accessibility settings. Open NIKSHA OS and navigate between screens.
- **Expected:** Entrance animations and page transitions are suppressed.
- **Actual:** Every animation still runs.
- **Root cause:** `lib/theme/motion.dart:33` —
  `animationsEnabledInEnvironment => !bool.fromEnvironment('FLUTTER_TEST')`.
  It **never reads `MediaQuery.disableAnimations`**. Every entrance animation
  routes through `AksharaMotionAppear` (which wraps all loading, empty and error
  states) and every page transition through `page_transitions.dart:17`, so the
  gate is global. The correct check is already written in the codebase — in
  `lib/shared/widgets/premium/akshara_mount_fade.dart:55`, a widget with **zero
  production call sites** (see POLISH-017).
- **Recommended fix:** Add `MediaQuery.maybeDisableAnimationsOf(context)` to the
  gate. One expression, and it makes every animated surface compliant at once.
- **Dependencies:** None.
- **Risk of fixing:** Low — the suppressed path already exists and is exercised
  under `FLUTTER_TEST`.
- **Evidence:** `lib/theme/motion.dart:33`; `lib/theme/page_transitions.dart:17`;
  `lib/shared/widgets/premium/akshara_mount_fade.dart:55`.

### POLISH-008 · **P1** · HR, Management ×5, Admissions ×3, Library, Control Center, Finance · Twelve more filter bars and period pickers the fetch never reads

- **Repro steps:** On HR → Payroll, tap "Last month". On Management → Finance,
  tap "This quarter". On Admissions → Leads, tap a source. Repeat on the eleven
  screens below.
- **Expected:** The list narrows.
- **Actual:** The chip highlights and the data does not change.
- **Root cause:** The same defect as WIDGET-008/009/010, but on **list and detail
  screens rather than dashboards**, so it is outside that entry's scope. In each
  file the selection provider is `watch`ed only to paint `selectedFilterIndex:`
  and written on tap; a repo-wide grep finds no other reader — no `.where`, no
  query parameter, no view-state provider.
  `admissions/applications/admissions_applications_screen.dart:36,42` ·
  `admissions/documents/admissions_documents_screen.dart:35,43` ·
  `admissions/leads/admissions_leads_screen.dart:36,62` ·
  **`hr/payroll/hr_payroll_screen.dart:36,43`** ·
  `library/resources/library_resources_screen.dart:34,43` ·
  `management/academics/management_academics_screen.dart:36,43` ·
  `management/finance/management_finance_screen.dart:37,44` ·
  `management/performance/management_performance_screen.dart:34,41` ·
  `management/analytics/management_analytics_screen.dart:36,43` ·
  `management/admissions/management_admissions_screen.dart:35,42` ·
  `platform/control_center/crm/control_center_crm_screen.dart:32,39`.
  Plus **Finance → Executive Dashboard**
  (`finance/intelligence/finance_executive_dashboard_screen.dart:19,23,37-41,143`),
  where `_periodFilters = ['This month','This quarter','YTD']` and
  `financeExecutiveProvider` takes no period argument at all.
- **Why the HR one is worse than the rest:** "Current month / Last month / All
  runs" on a **payroll** screen is not a convenience filter. An accountant who
  selects "Last month" and is shown the current month's runs, unlabelled and
  unchanged, is actively misled about which payroll they are reading.
- **Why the Management cluster matters:** five of the eleven are in Management.
  Together with JOURNEY-009's dashboard, **every screen in the Management
  workspace has a filter bar that does nothing** — and Management is the
  principal's own workspace.
- **Recommended fix:** Per screen, either pass the selection into the query, or
  remove the bar. Removing it is the honest interim.
- **Dependencies:** WIDGET-008/009/010 — same class, same remediation wave.
- **Risk of fixing:** Low to remove; medium to wire (needs query parameters the
  backend may not accept yet).
- **Evidence:** file:line list above.

### POLISH-009 · **P1** · Exam Admin, School Completion, Platform, Intelligence · Unguarded fixed-width `Wrap` filter bars overflow on a phone

- **Repro steps:** Open Exam Reports on a 360dp phone. Then Substitute Manager.
- **Expected:** The filter controls stack.
- **Actual:** `exam_reports_screen.dart:448,469,490` puts three fixed-width
  dropdowns — 160 + 160 + 220 = **540dp** — in one `Wrap` with no narrow guard,
  in a 360dp viewport. `substitute_manager_screen.dart:271,293` does the same
  with 220 + 240.
- **Root cause:** Exactly the pattern the RC phase fixed on the Admin Hub
  (hard-coded card widths inside a `Wrap`), reintroduced in four more places:
  also `platform/organization_builder/organization_builder_hub_screen.dart:104`
  (280), `platform/multi_school/multi_school_portfolio_screen.dart:101` (220),
  `intelligence/trust/trust_intelligence_hub_screen.dart:312` and
  `platform/control_center/intelligence/platform_intelligence_screen.dart:338`
  (260).
- **Recommended fix:** Use the guard that already exists twice in the product —
  `director/widgets/director_shared_widgets.dart:38-47` and
  `director/director_school_snapshot_screen.dart:188-194` fall back to a `Column`
  before the `Wrap`; `admissions/settings/admissions_settings_screen.dart:73`
  guards its 540dp sections.
- **Dependencies:** None.
- **Risk of fixing:** Low — the template exists.
- **Evidence:** file:line list above; `lib/theme/breakpoints.dart`
  (`narrowMobileMaxWidth: 360`).

### POLISH-010 · **P1** · Parent app / Router · Notice and event taps dispatch on hard-coded demo IDs; two of them target a blocked route

- **Repro steps:** As a parent with real notices, tap any notice on the
  dashboard.
- **Expected:** That notice opens.
- **Actual:** The generic notices list opens. The tap *looks* like a drill-down
  and is not.
- **Root cause:** `lib/router/parent_navigation.dart:86-93` dispatches on the
  hard-coded mock ids `notice_n1`, `event_e2`, `notice_n3`. Against real data no
  id matches, so every tap falls through. The two ids that *do* match target
  `/parent/ptm`, which is a **blocked route prefix**
  (`lib/core/config/school_build_scope.dart:82-83`). And `:133-134`
  (`default: break;`) silently swallows any unmapped `actionId` — a dead tap with
  no feedback. Separately `:33-36` and `:115-118` route "Pay fee" to a hard-coded
  `installmentId=term_2` (second call site of JOURNEY-015).
- **Recommended fix:** Dispatch on the entity id carried by the tapped item;
  make the `default` arm surface an honest failure rather than returning silently.
- **Dependencies:** JOURNEY-015, JOURNEY-016.
- **Risk of fixing:** Low-medium.
- **Evidence:** `lib/router/parent_navigation.dart:33-36,86-93,115-118,133-134`;
  `lib/core/config/school_build_scope.dart:82-83`.

### POLISH-011 · **P1** · Finance, SIS, Admissions · The shared async body was forked three times and each fork lost a parameter

- **Repro steps:** Compare `lib/shared/async/erp_async_state.dart:35,77` with
  `lib/features/finance/finance_async_state.dart:77`,
  `lib/features/sis/sis_async_state.dart:77` and
  `lib/features/admissions/admissions_async_state.dart:77`.
- **Expected:** One shared async body.
- **Actual:** Four, byte-identical except a doc comment — and **the three forks
  dropped the `errorMessage` parameter** the canonical version carries at
  `erp_async_state.dart:35`.
- **Why this is P1 despite being mechanically trivial:** a future improvement to
  the canonical async body — the pull-to-refresh of POLISH-003, the permission
  state of POLISH-004, a skeleton — **will not reach Finance, SIS or
  Admissions**, the three highest-traffic admin modules in the product. It is a
  divergence that silently excludes the screens that matter most from every
  subsequent fix.
- **Recommended fix:** Delete the three forks; import the shared one.
- **Dependencies:** Should land **before** POLISH-003 and POLISH-004, or those
  fixes will need doing four times.
- **Risk of fixing:** Low.
- **Evidence:** `lib/shared/async/erp_async_state.dart:35,77`;
  `lib/features/finance/finance_async_state.dart:77`;
  `lib/features/sis/sis_async_state.dart:77`;
  `lib/features/admissions/admissions_async_state.dart:77`.

### POLISH-012 · **P2** · Finance, Communication, Inventory, Employee, Intelligence, Evolution, Parent, Copilot, Education · Errors swallowed into blank space, and 17 more that only toast

- **Repro steps:** Open Finance → Defaulters with the backend failing.
- **Expected:** An error state distinguishable from "nobody owes money".
- **Actual:** A blank screen. **A fee-defaulters list that renders empty on
  failure tells a principal that nobody owes money.**
- **Root cause:** The failure branch renders nothing:
  `finance/defaulters/finance_defaulters_screen.dart:225` ·
  `finance/intelligence/finance_copilot_screen.dart:63` ·
  `communication/broadcast_admin_screen.dart:490,515` ·
  `inventory/intelligence/inventory_lifecycle_screen.dart:64` ·
  `employee/employee_360_screen.dart:71` ·
  `intelligence/management/intelligence_hub_screen.dart:433,526,543` ·
  `evolution/teacher_assistant_screen.dart:68` ·
  `parent/academics/parent_academic_report_screen.dart:41` ·
  `copilot/copilot_screen.dart:170` · `education/education_bank_item_form.dart:137`.
  A further **17 screens are SnackBar-only** — the error toasts away after four
  seconds, the page stays blank, no retry — including
  `admin/backup/backup_restore_screen.dart`,
  `school_config/school_discovery_screen.dart`,
  `platform/multi_school/school_onboarding_wizard_screen.dart`,
  `teacher/leave_approvals/teacher_leave_approvals_screen.dart`,
  `achievement_promotion/achievement_promotion_preview_screen.dart`,
  `onboarding/unified_onboarding_flow_screen.dart`.
- **Recommended fix:** Route each through `ErpAsyncBody`, which cannot be
  constructed without `onRetry`.
- **Dependencies:** POLISH-011.
- **Risk of fixing:** Low.
- **Evidence:** file:line list above.

### POLISH-013 · **P2** · Transport, Hostel, Control Center ×2, Library, Intelligence · Six Export/Download/Print buttons that produce nothing

- **Repro steps:** Transport → Dashboard → Export. Then Library → Reports, and
  compare the overdue tab's Download with any other tab's.
- **Expected:** A file.
- **Actual:** A snackbar: *"preview only. Export pipeline not connected yet."*
- **Root cause:** `showAksharaReportExportPreviewSnackBar`
  (`lib/shared/widgets/operational_action_feedback.dart:17-30`). **The copy is
  honest — that deserves credit.** The control is not: it is a full-size,
  permission-gated button visually identical to the real exporters in the same
  module. `transport/dashboard/transport_dashboard_screen.dart:41` ·
  `hostel/dashboard/hostel_dashboard_screen.dart:41` ·
  `platform/control_center/dashboard/control_center_dashboard_screen.dart:44` ·
  `platform/control_center/analytics/control_center_analytics_screen.dart:30` ·
  **`library/reports/library_reports_screen.dart:179`** (whose own overdue tab has
  a real CSV/PDF export at `:161-174`, so a librarian sees a working download on
  one tab and a stub on the next) ·
  `intelligence/intelligence_screen.dart:586-592` ("Print", whenever
  `report.printable`).
- **Recommended fix:** Until the pipeline lands, use the pattern the product
  already has one directory away —
  `hostel/reports/hostel_reports_screen.dart:168-169` uses `onPressed: null` with
  the tooltip "Export not available yet": visibly disabled, honest, impossible to
  mistake for a working control. One line each.
- **Dependencies:** OS-011 (there is no backend report/export service).
- **Risk of fixing:** Trivial for the disable; the real export is a feature.
- **Evidence:** file:line list above.

### POLISH-014 · **P2** · Admissions, Hostel ×3, Transport ×2, Library, Inventory, Alumni · Six dashboards still render headed holes on day one

- **Repro steps:** On an empty school, open the Admissions, Hostel, Transport,
  Library, Inventory and Alumni dashboards.
- **Expected:** The `AksharaSectionEmpty` card the RC phase added to HR, SIS,
  Finance and Admissions.
- **Actual:** A section header followed by nothing — or, on Hostel's "Health
  alerts", **an empty bordered Card with no content at all**, which is the worst
  of the set.
- **Root cause:** The RC phase fixed four dashboards and did not sweep the class.
  Verified still broken: **Admissions "Follow-ups due today"**
  (`admissions/dashboard/admissions_dashboard_screen.dart:115` →
  `admissions_followups_table.dart:22`, no `isEmpty` guard — a bare 7-column
  header row on desktop, a zero-height gap on mobile at `:23-31`, **sitting
  between two now-polished empty cards**) · Hostel
  (`hostel/dashboard/hostel_dashboard_screen.dart:90`→`:202`, `:126`→`:106`,
  `:184`→`:159`) · Transport
  (`transport/dashboard/transport_dashboard_screen.dart:77`→`:109`,
  `:274`→`:255`) · Library (`library/dashboard/library_dashboard_screen.dart:95`→`:147`) ·
  Inventory (`inventory/dashboard/inventory_dashboard_screen.dart:125`→`:157`,
  `:274`) · Alumni (`alumni/dashboard/alumni_dashboard_screen.dart:69`→`:99`).
- **Recommended fix:** Apply the `AksharaSectionEmpty` guard already used by the
  four fixed dashboards. Add a widget test asserting every headed dashboard
  section renders something at zero rows, so the class cannot regress.
- **Dependencies:** WIDGET-003, WIDGET-004, WIDGET-007 — same class.
- **Risk of fixing:** Low.
- **Evidence:** file:line list above; fixed exemplars at
  `hr/dashboard/hr_dashboard_screen.dart:141,186`,
  `finance/dashboard/widgets/finance_recent_payments_table.dart:24`.

### POLISH-015 · **P2** · Shared navigation, Parent, Teacher, AI · Tap targets under 48dp — including inside the file the RC phase fixed

- **Repro steps:** Tap the admin app-bar search field; the parent dashboard
  school avatar; a "View receipt" icon on Parent → Fees; "Check in now" on the
  teacher dashboard.
- **Expected:** 48dp minimum.
- **Actual:** 40, 40, 40 and 36dp respectively.
- **Root cause:** `lib/shared/navigation/akshara_navigation.dart:667` —
  `AksharaNavSearchField` is an `InkWell` around `Container(height: 40)`. **This
  is the same file the RC log records as fixed 40→48dp**; three other sites in it
  use `AksharaSpacing.minTouchTarget` (`:241,464,611`) and the search field was
  missed. Also `parent/dashboard/widgets/hero_card.dart:145-147`
  (`SizedBox(40×40)`), `parent/fees/installment_timeline.dart:167`
  (`minimumSize: Size(40,40)`, an explicit override of the theme floor),
  `teacher/dashboard/widgets/attendance_summary_card.dart:160`
  (`minimumSize: Size(0,36)` on a daily primary action), and
  `adaptive_ai/widgets/adaptive_search_results.dart:98-99` (`Size.zero` +
  `MaterialTapTargetSize.shrinkWrap`). A further 24 `VisualDensity.compact` sites
  shave ~8dp each across transport, hostel, library, finance discounts (`:422`),
  notifications (`:381`) and the approval queue table (`:483,496`).
- **Why it was not caught:** `test/theme/tap_target_lint_test.dart` asserts only
  the **theme defaults** and pumps exactly two widgets. It cannot see a
  per-call-site override — a test whose premise is weaker than the claim it
  appears to defend.
- **Recommended fix:** Fix the six sites; then replace the lint with one that
  walks the rendered tree of representative screens and asserts every
  hit-testable target is ≥48dp.
- **Dependencies:** None.
- **Risk of fixing:** Low, with golden regeneration.
- **Evidence:** file:line list above; `test/theme/tap_target_lint_test.dart`.

### POLISH-016 · **P2** · Theme · Contrast coverage stops at the status chip; two live surfaces fail

- **Repro steps:** Read a KPI card's neutral "no change" delta chip in daylight.
  Read any form field's hint text.
- **Expected:** ≥4.5:1 for 11px normal text.
- **Actual:** ~4.04:1 and ~3.42:1 respectively, neither covered by any test.
- **Root cause:** The RC fix and its test are genuine — 4.5 asserted
  (`test/theme/rendered_contrast_audit_test.dart:46`,
  `lib/theme/accessibility.dart:6`), all 14 tone×scheme pairs enumerated
  (`KpiAccent` has exactly 7 values at `lib/theme/theme_extensions.dart:246` ×
  2 themes, `:51-60`), and a premise guard at `:134`. **The claim holds.** But it
  covers one widget. Uncovered and failing: the KPI trend chip's neutral state
  (`onSurfaceVariant` #64748B on `surfaceContainerHigh` #E8EDF3 at 11px w600), in
  two independent copies — `lib/shared/widgets/akshara_kpi_card.dart:186,213` and
  `lib/shared/widgets/akshara_executive_kpi_card.dart:165` — which is the delta
  label under **every KPI on the parent, teacher, student and management
  dashboards**; and hint text at `lib/theme/app_theme.dart:687,698-700`
  (`onSurfaceVariant` at 0.85 alpha on `surfaceContainerLow`), which is every
  search box and form field in the app.
  Two further gate weaknesses: chart legend labels pass at ~4.55:1 by 0.05 and
  are untested (`lib/shared/widgets/akshara_chart.dart:145-153`); and
  `onSurfaceVariant on surface` — the app's default secondary **body** colour —
  is asserted at only **3.0** (`lib/theme/accessibility.dart:80`) while measuring
  4.76:1, so the gate is 1.76 points looser than reality and would green-light a
  real regression. No coverage at all for on-accent text
  (`lib/shared/widgets/workspace_switcher.dart:227`), snackbar/tooltip text,
  badges outside `_MarkBadge`, or severity labels.
- **Recommended fix:** Darken the two failing pairs; raise the
  `onSurfaceVariant on surface` assertion to 4.5; extend the rendered-contrast
  audit to trend chips, hints, legends, on-accent and severity text.
- **Dependencies:** None.
- **Risk of fixing:** Low-medium (token change → golden regeneration).
- **Evidence:** file:line list above.

### POLISH-017 · **P2** · Shared widgets · Five skeletons, an animated switcher and a reduce-motion fade were built, tested, and never wired

- **Repro steps:** Open any of the 78 admin list screens and watch it load.
- **Expected:** The list skeleton that exists in the design system.
- **Actual:** A spinner (`lib/shared/async/erp_async_state.dart:110`).
- **Root cause:** `lib/shared/widgets/akshara_skeleton.dart` defines six
  builders; **only `.dashboard()` has production call sites (11).** `.list()`,
  `.row()`, `.card()`, `.line()` and `.circle()` have **zero** — `.list(rows:)`
  appears only in `test/widgets/akshara_skeleton_test.dart:36,60,110`. Likewise
  `AksharaAnimatedSwitcher` (`lib/shared/widgets/akshara_motion.dart:121`,
  unit-tested at `test/widgets/akshara_motion_test.dart:31`) has zero production
  uses, and `lib/shared/widgets/premium/akshara_mount_fade.dart` has zero uses
  **while being the only widget in the repo that honours
  `MediaQuery.disableAnimations`** (`:55` — see POLISH-007).
  `premium/akshara_premium_empty_state.dart` is used exactly once
  (`evolution/parent_insights_screen.dart:167`), so two parallel empty-state
  visual languages coexist.
- **Why it matters:** the RC phase already found one unreachable skeleton (the
  parent dashboard's). It was not one case. A tested widget with no call site is
  a specific kind of unfinished — the work was done and the last step skipped —
  and it means the golden suite is proving the appearance of things nobody sees.
- **Recommended fix:** Wire `.list()` into `ErpAsyncBody`'s list variant; adopt
  `akshara_mount_fade` or fold its `disableAnimations` check into
  `motion.dart:33`; retire whichever empty-state language is not chosen.
- **Dependencies:** POLISH-007, POLISH-011.
- **Risk of fixing:** Low-medium (visible change → golden regeneration).
- **Evidence:** file:line list above.

### POLISH-018 · **P2** · Admissions, Director · Fixed-height wrappers defeat the shared text-scale fix

- **Repro steps:** Set system font to ~1.6× and open the Admissions dashboard,
  then the Director dashboard.
- **Expected:** KPI tiles grow, as `AksharaKpiCard` is built to do
  (`lib/shared/widgets/akshara_kpi_card.dart:33-36`).
- **Actual:** They clip or overflow.
- **Root cause:** `admissions/dashboard/widgets/admissions_dashboard_kpi_row.dart:34`
  wraps the card in `SizedBox(height: 120)`, and
  `director/widgets/director_shared_widgets.dart:31,45` pin
  `SizedBox(height: 140)` on both the phone and wrap paths — each **overriding**
  the card's own growth. There is no global textScaleFactor clamp
  (`lib/app/app.dart:107` does not override MediaQuery; clamping is confined to
  two legitimately dense grids at `lib/theme/accessibility.dart:58` and
  `lib/shared/marks_grid/marks_grid.dart:145`), so layouts must survive on their
  own. Known ceiling, recorded not as a defect but as a fact: above ~1.6×
  `akshara_kpi_card.dart:34` and `akshara_progress_ring.dart:43` fall back to
  `maxLines:1 + ellipsis`, so a principal on maximum font sees a truncated money
  value ("₹12,4…").
- **Recommended fix:** Replace `SizedBox(height:)` with `ConstrainedBox(minHeight:)`
  — the same repair the RC phase made to `akshara_section_header.dart:98-103`.
- **Dependencies:** None.
- **Risk of fixing:** Low.
- **Evidence:** file:line list above.

### POLISH-019 · **P2** · School Completion, Verticals, Platform, Intelligence · 40 routed screens bypass the shared page shell; 21 more use a different page gutter

- **Repro steps:** Navigate from HR or Academics to a School Completion screen —
  Substitute Manager, Teacher Reassignment, Lesson Analytics, Pilot Dashboard,
  Communication Analytics.
- **Expected:** The same page frame as its neighbours.
- **Actual:** A different one. No 1440 content grid, no `AdminAppBar`, no
  breadcrumbs, no filter bar.
- **Root cause:** Twelve module scaffolds correctly delegate to
  `AdminContentScaffold` (`finance/widgets/finance_module_scaffold.dart:36` and
  its HR, SIS, admissions, library, inventory, alumni, hostel, transport,
  management, director and control-center siblings) — **this is the strongest
  part of the system.** But 177 of 310 screens use a bare `Scaffold`; the persona
  shells legitimately account for ~50, leaving `school_completion/` (**20
  screens, 28 router refs**), `verticals/` (20, MOCK/HIDDEN), `platform/` (14),
  `intelligence/` (7), `academics/` (5) and `management/` (3). Separately, page
  gutters are mostly consistent (104× `EdgeInsets.all(AksharaSpacing.s4)`) but 21
  screens deviate — 14× `s6`, 3× `s5`, 3× raw `16`, 1× `symmetric(16.0, 16.0)` —
  and sibling screens at 16dp vs 24dp gutters is the classic "assembled by
  different people" tell.
- **Recommended fix:** Adopt `AdminContentScaffold` in `school_completion/`
  first — it is the only cluster a school actually sees.
- **Dependencies:** None. Largest effort in the workstream.
- **Risk of fixing:** Medium — visible layout change on 20 routed screens.
- **Evidence:** `lib/features/admin/admin_content_scaffold.dart`;
  `lib/features/finance/widgets/finance_module_scaffold.dart:36`;
  `lib/features/school_completion/**`.

### POLISH-020 · **P2** · Management ×2, Admissions ×2, School Completion, Platform, Intelligence · Token bypass on daily screens: mixed radii, raw status colours, a dark-mode hole, emoji as iconography

- **Repro steps:** Open the Admissions dashboard and compare card corners. Open
  Office Attendance and read the status chips. Switch to dark mode and open the
  approval queue.
- **Expected:** One corner radius, tokenised status colours, tokenised
  foregrounds.
- **Actual:** Mixed corners on one screen; status chips that do not shift with
  the persona accent; white text on a token-resolved fill in dark mode.
- **Root cause:** Against a genuinely clean baseline — **zero raw `Color(0x…)` in
  all 954 feature files**, 3,497 `AksharaSpacing.*` uses, one icon family (1,567
  `Icons.*`, 0 `CupertinoIcons.*`), and a dark theme regression-locked by
  goldens (`test/golden/dark_mode_render_test.dart`) — the strays are:
  **Radius:** 11 distinct raw values against a 7-value token set (off-token 2, 3,
  4, 10, 14). `admissions/dashboard/widgets/admissions_assistant_card.dart:160,162,174`
  uses radius **14** three times beside cards at `AksharaRadius.lg` (16) — the
  visible mixed-corner symptom on a daily screen. Radius `4` appears 13× as one
  byte-identical `*_segment_panel.dart:73` forked across **8 modules**
  (management, library, inventory, hr, alumni, hostel, transport,
  platform/control_center), so a single fix kills 13 of 18 off-token radii.
  **Colour:** 51 genuine `Colors.<name>` uses, concentrated at
  `management/attendance/office_attendance_screen.dart:452-457,946-949` (**9 raw
  status colours** in two switch maps on a daily principal screen) and
  `school_completion/branding_screen.dart:102` (`return Colors.blue;` as the
  fallback when a **school's own brand colour** fails to parse).
  **Dark mode:** `management/approval/widgets/approval_queue_table.dart:524`
  (`const onTone = Colors.white;` on a token-resolved fill — will fail contrast
  on a light accent) and `admissions/widgets/admissions_chart_panel.dart:134`.
  Two comments at `office_attendance_screen.dart:383-384,871` document this exact
  `Colors.white`-on-token WCAG failure being fixed once already; the class was
  not swept.
  **Emoji as UI:** `school_completion/timetable_automation_screen.dart:77`
  (`Text('⚠ $w')` instead of `Icons.warning_amber`),
  `achievement_promotion/achievement_promotion_screen.dart:130`
  (`'👁 ${views} · ↗ ${shares}'`),
  `platform/platform_operations/platform_operations_hub_screen.dart:575`.
  Elevation strays: `copilot/dock/copilot_floating_dock.dart:44` uses **6**,
  which is not on the `AksharaElevation` ladder at all.
- **Recommended fix:** In order of return — the 8 `_segment_panel` clones (one
  change), the Admissions radius 14, the approval-queue white, the 9 office
  attendance colours, the emoji.
- **Dependencies:** None.
- **Risk of fixing:** Low, with golden regeneration.
- **Evidence:** file:line list above.

### POLISH-021 · **P2** · Intelligence, Entitlements, Dynamic Widgets, Org Builder, Finance, SIS, Legal, Platform · Developer-grade empty states and bare full-page spinners

- **Repro steps:** On an empty school open Intelligence; then Finance →
  Collection Detail and watch it load.
- **Expected:** The shared empty-state widget (used by 130 files) and the shared
  loading state (used by 257 screens).
- **Actual:** A bare left-aligned sentence, and an unframed spinner.
- **Root cause:** ~20 screens skip `akshara_empty_state.dart` /
  `akshara_section_empty.dart`. Worst:
  `intelligence/intelligence_screen.dart:139,154` — bare sentences sitting in the
  **same `.when()`** as a proper `AksharaLoadingState` and `AksharaErrorState`,
  so loading and error are designed and **the empty state, which is what a
  school sees on day one, is not** ·
  `entitlements/organization_plan_assignment_screen.dart:94` ·
  `dynamic_widgets/dynamic_widget_runtime_screen.dart:96` ·
  `platform/organization_builder/organization_builder_hub_screen.dart:172` ("No
  interview drafts yet." with **no call to action on a screen whose only job is
  creating drafts**). Plus P3 instances in `substitute_manager_screen.dart:328`,
  `teacher_reassignment_screen.dart:279,362`, `onboarding_hub_screen.dart:53,83`,
  `school_memory_event_screen.dart:217`, `control_center_providers_screen.dart:123`,
  `hr_employee_profile_screen.dart:256,305`, `finance_discounts_screen.dart:595`,
  `alumni_profile_screen.dart:217`, `teacher_parent_communication_screen.dart:297`.
  Loading treatments number six across the app — 257 shared, 11 skeleton, **17
  bare full-page spinners** (`finance/collection_detail/finance_collection_detail_screen.dart:310`,
  `sis/registry/sis_registry_screen.dart:590`,
  `legal/legal_acceptance_screen.dart:89`, `platform/branch/branch_screen.dart:68`,
  `platform/multi_school/multi_school_portfolio_screen.dart:60`,
  `platform/organization_builder/organization_builder_hub_screen.dart:77`,
  `inventory/intelligence/inventory_copilot_screen.dart:89`,
  `dynamic_widgets/dynamic_widget_registry_screen.dart:75,92`), **35
  `loading: () => const SizedBox.shrink()`** (content pops in with no feedback),
  and 25 with nothing at all.
- **Recommended fix:** Adopt the shared widgets. Both exist and are well built.
- **Dependencies:** POLISH-011, POLISH-017.
- **Risk of fixing:** Low.
- **Evidence:** file:line list above.

### POLISH-022 · **P3** · Admin shell · The Admin Hub card interior is sparse now that cards are full width

- **Repro steps:** Sign in as principal on a ~411dp phone and look at `/admin` —
  the first screen 6 of 15 staff roles see every day.
- **Expected:** A dense, informative home.
- **Actual:** A vertical stack of ~379×138dp white cards, each with its content
  hugging the left edge and roughly the right 60–70% blank — one short word
  ("Finance", "HR") floating in a wide empty rectangle, repeated 8–12 times.
- **Root cause:** `lib/features/admin/screens/admin_hub_screen.dart:138-174` is a
  `Column(crossAxisAlignment: .start)` — a layout designed for 220dp tiles — now
  rendered at full width by the (correct) responsive fix at `:76-99`. The RC log
  records this consequence honestly; it is confirmed still true.
- **Recommended fix:** At one column, use a horizontal ListTile-shaped row —
  icon left, label plus a live count centre, chevron right. The count would also
  address JOURNEY-005's empty-hub problem by giving each tile something to say.
- **Dependencies:** JOURNEY-005, JOURNEY-008.
- **Risk of fixing:** Low-medium (golden regeneration).
- **Evidence:** `lib/features/admin/screens/admin_hub_screen.dart:76-99,124-125,138-174`.

### POLISH-023 · **P3** · Platform, Evolution, SIS, and 5 persona dashboards · Type scale drift — 12 distinct sizes, and one element hand-typed five times

- **Repro steps:** Compare the micro-label under a KPI on the parent, teacher and
  student dashboards.
- **Expected:** One token.
- **Actual:** `fontSize: 10` typed by hand in five files —
  `parent/dashboard/parent_dashboard_screen.dart:434`,
  `teacher/dashboard/widgets/attendance_summary_card.dart:233`,
  `teacher/exams/teacher_exams_screen.dart:267`,
  `student_app/exams/student_exams_screen.dart:185`,
  `parent/attendance/attendance_kpi_strip.dart:68`.
- **Root cause:** 86 `fontSize:` literals, of which **52 are legitimate** (inside
  7 `*_pdf_service.dart` files using `pw.TextStyle`, which has no Flutter theme).
  The real count is 34 literals across 12 distinct sizes (8–22). Worst cluster:
  `lib/features/platform/` hand-rolls `TextStyle(fontSize: 16, fontWeight: w600)`
  as an ersatz section header six times
  (`organization_builder_hub_screen.dart:53,71`,
  `multi_school_portfolio_screen.dart:54,71`,
  `organization_provisioning_screen.dart:83`,
  `organization_builder_preview_screen.dart:116`). Orphan sizes:
  `evolution/growth_platform_screen.dart:389` (22, the only 22 in the app),
  `sis/profile/sis_profile_edit_sheet.dart:112` (18 on a sheet title whose
  siblings use `titleMedium`).
- **Recommended fix:** Add a `labelMicro` token for the KPI micro-label; replace
  the platform pseudo-headers with `AksharaSectionHeader`.
- **Dependencies:** None.
- **Risk of fixing:** Low.
- **Evidence:** file:line list above. (Spacing is near-clean by contrast: raw
  `EdgeInsets.all` uses only on-scale 8/12/16 with no odd 7/13/18/22 anywhere;
  drift is confined to `EdgeInsets.symmetric` and raw `SizedBox(height:)`.)

### POLISH-024 · **P3** · Finance, SIS, Admissions, Parent, Transport, HR · Nine providers written and never read

- **Repro steps:** Static — grep each identifier for a reader.
- **Expected:** Every provider has a consumer.
- **Actual:** Declared with zero call sites: `financeDiscountsTabProvider`,
  `parentPreferredLanguageProvider`, `transportSelectedRouteIdProvider`,
  `financeAssignmentDraftProvider`, `sisAssignmentDraftProvider`,
  `parentComposeDraftProvider`, `hrExportRunIdProvider`. Written and never read:
  `financeLastReceiptNumberProvider`
  (`lib/features/finance/finance_workflow_actions.dart:1409`) and
  `admissionsLastApprovalIdProvider`
  (`lib/features/admissions/admissions_enrollment_provider.dart:111`).
- **Root cause:** Residue. None is user-visible, so this is cleanup rather than
  polish — recorded so the "written but never read" class is closed rather than
  sampled. Note that the two journey breadcrumbs are the *same* pattern that made
  POLISH-006 and WIDGET-008 user-visible defects; the class is worth a lint.
- **Recommended fix:** Delete, or wire the two breadcrumbs into the confirmation
  surfaces they were plainly written for.
- **Dependencies:** None.
- **Risk of fixing:** Trivial.
- **Evidence:** identifiers and file:line above.

### API-100 · **P1** · Platform / RBAC · 97 mutating routes are absent from the RBAC route inventory

- **Repro steps:** extract every `(method, path)` from the 66 module routers under
  `supabase/functions/_shared/**` and diff against `RBAC_ROUTE_INVENTORY`
  (`_shared/validation/rbac_route_inventory.ts`, 315 rules).
- **Expected:** the inventory is the completeness surface for "is every mutating
  route gated?", so every mutating route appears in it exactly once.
- **Actual:** 232 literal routes are absent, **97 of them mutating**, plus ~250
  parameterised mutating routes. Absent money writes include
  `POST /finance/collections`, `POST /finance/refunds`, `POST /finance/day-close`,
  `POST /finance/discounts`, `POST /finance/fee-assignments` (+ `/bulk`),
  `POST /finance/late-fees/accrue`,
  `POST /finance/fee-reductions/{discount-applications,scholarship-awards}`,
  `POST /finance/recovery/{contacts,promises,targets}`. Absent governance writes
  include every `/approvals/:id/{approve,reject,cancel}`,
  `POST /approvals/audit`, all 26 `POST /school/*` school-completion writes, all
  `/academics/exams/*` mark-write routes, `/identity/roles{,/update,/delete}`,
  and `/staff-attendance/{enroll-face,manual-request,manual-request/decide}`.
  The RC phase's "two attendance routes missing" was a sample of this, not an
  outlier: the attendance router exposes 11 routes and the inventory holds one.
- **Root cause:** the inventory is a hand-maintained data file with no
  code-derived source and no test comparing it to the routers. Adding a route
  does not require touching it.
- **Recommended fix:** derive the route list mechanically (export a
  `(method, path, handler)` table from each router, as `MODULE_ROUTES` already
  does for prefixes) and add a test that fails when a mutating route has no
  inventory rule. Backfill the 97.
- **Dependencies:** none. Prerequisite for any future "every route is gated"
  claim, and for API-101.
- **Risk of fixing:** low — additive test + data. The backfill will surface
  genuine gate disagreements, which is the point.
- **Evidence:** `supabase/functions/_shared/validation/rbac_route_inventory.ts`
  (315 rules); `_shared/attendance/attendance_router.ts` (11 routes, 1 rule);
  `_shared/finance/finance_router.ts`; `docs/certification/findings/API-certification.md` §1.2.

### API-101 · **P1** · Platform / RBAC · The RBAC test suite validates the inventory against itself and never dispatches a route

- **Repro steps:** read `_shared/validation/rbac_route_validation_test.ts` and
  `rbac_full_matrix_test.ts`.
- **Expected:** a per-route RBAC matrix proves that *the route* denies a
  non-holder.
- **Actual:** both tests iterate `RBAC_ROUTE_INVENTORY` and call the pure
  function `requirePermission(claims, rule.permission)`. Neither constructs a
  `Request`, calls `matchModuleRoute`, or invokes a handler. The suite proves
  that a 20-line permission comparator works. A route added with no gate, or
  with the wrong gate, passes the entire RBAC suite by simply not being listed —
  and, per API-100, 97 mutating routes are not listed.
- **Root cause:** the matrix was built over the inventory data structure rather
  than over the dispatcher.
- **Recommended fix:** drive the matrix through `routeModuleRequest` with a
  synthetic `Request` and a claims fixture, asserting 403 for a non-holder and
  non-403 for a holder. Keep the pure-function tests as unit coverage of
  `requirePermission`.
- **Dependencies:** API-100 (needs a complete route list to be meaningful).
- **Risk of fixing:** medium — a dispatcher-level test needs a DB seam; the
  existing spy-DB harness is sufficient for status-code assertions.
- **Evidence:** `_shared/validation/rbac_full_matrix_test.ts:31-70`;
  `_shared/validation/rbac_route_validation_test.ts:86-100`.

### API-102 · **P2** · Platform / RBAC · 91 inventory rules describe routes that no longer exist

- **Repro steps:** diff `RBAC_ROUTE_INVENTORY` against the extracted route set in
  the other direction.
- **Expected:** every rule maps to a live route.
- **Actual:** 91 rules have no matching route. The load-bearing example:
  `{ method: "PUT", path: "/teacher/exams/marks/:id", permission: "manageExamMarks" }`
  — a route **deleted by PRA-P0-12** because it shadowed the governed exam-mark
  route — is still declared, while the governed replacement
  `PUT /academics/exams/marks/:id` is absent. Anyone consulting the inventory to
  answer "what gates a mark change?" reads a rule for a route that does not
  exist. `POST /parent/attendance/corrections` is the only attendance rule and it
  is also the only attendance route present.
- **Root cause:** same as API-100 — no reconciliation in either direction.
- **Recommended fix:** the same generated table; fail the build on an orphan rule.
- **Dependencies:** API-100.
- **Risk of fixing:** low.
- **Evidence:** `rbac_route_inventory.ts:146,147`; `_shared/route_registry.ts:176-184`
  (the PRA-P0-12 note).

### API-103 · **P2** · Attendance · The whole attendance office-read surface is undocumented in RBAC

- **Repro steps:** compare `_shared/attendance/attendance_router.ts` with the
  `module: "attendance"` rules in the inventory.
- **Expected:** 11 rules.
- **Actual:** one, and it is for a different router's route. Undocumented:
  `GET /attendance/sessions`, `GET /attendance/sessions/:id`,
  `GET /attendance/register`, `GET /attendance/register/monthly`,
  `GET /attendance/pending`, `GET /attendance/alerts/consecutive-absence`,
  `GET /attendance/alerts/short-attendance`, `GET /attendance/corrections`,
  `GET /attendance/corrections/:id`, `POST /attendance/corrections`,
  `PATCH /attendance/corrections/:id/status`. The last is the approval that
  changes a child's attendance record; it is gated on
  `approveAttendanceCorrection` in code and on nothing in the inventory.
- **Root cause:** API-100.
- **Recommended fix:** backfill with the gates the handlers actually apply
  (`viewSis` for reads, `manageSis` for the create, `approveAttendanceCorrection`
  for the decide).
- **Dependencies:** API-100.
- **Risk of fixing:** low.
- **Evidence:** `_shared/attendance/attendance_router.ts:17-77`;
  `_shared/attendance/attendance_handlers.ts:49-68`.

### API-104 · **P2** · Platform / Routing · The route registry's prefix table omits a route its own router owns

- **Repro steps:** compare `MODULE_ROUTES`'s `audit` entry with `routeAudit`.
- **Expected:** `prefixes` lists every path subtree the router claims — that
  table is the input to the single-ownership guard.
- **Actual:** `{ name: "audit", prefixes: ["/audit"] }`, but `routeAudit` also
  owns `POST /domain-events/process-pending`
  (`if (!path.startsWith("/audit") && path !== "/domain-events/process-pending") return null;`).
  A path the table does not know about cannot be checked for double-ownership, so
  the guarantee the registry exists to provide does not cover this mutating
  route.
- **Root cause:** the prefix was declared from the router's name rather than from
  its guard clause.
- **Recommended fix:** add `"/domain-events/process-pending"` to the entry, and
  add a guard test that every literal path a router accepts is covered by one of
  its declared prefixes.
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** `_shared/route_registry.ts:231`; `_shared/audit/audit_router.ts:36`.

### API-105 · **P0** · Platform / Security · The deployed build has no central auth chokepoint — an anonymous caller can enumerate the API, and ICA-F1's guarantee is not live

- **Repro steps (live, read-only, performed):**
  `curl https://akshara.veloraunisexsalon.com/zzz/nope` → **404**;
  `.../support/incidents/not-a-uuid` → **422 VALIDATION**;
  `.../support/platform/incidents/not-a-uuid` → **422**;
  `.../attendance/register/monthly` → **422 ATTENDANCE_VALIDATION "classLabel is required"**.
  All four with no `Authorization` header. All four carry `x-correlation-id` and
  the app's security headers, so they are produced by the application.
- **Expected:** `api/app.ts` authenticates **before** dispatch, and
  `api/eng4_5_forced_auth_test.ts` asserts "an unauthenticated request to ANY
  module path is 401 at the central gate … so even an unknown route returns 401
  (not 404) — unauthenticated callers cannot enumerate which routes exist."
- **Actual:** production routes and validates first and authenticates inside the
  handler. The only build that behaves this way predates ICA-F1 (`e0e98375`,
  2026-07-21). Corroborated by three routes that exist on this branch and 404
  live: `GET /audit/events`, `GET /audit/retention`, `GET /identity/roles`.
- **Root cause:** the pilot has not been redeployed since ICA-F1 (and later)
  landed. `GET /health` cannot confirm which commit is live (API-106).
- **Recommended fix:** deploy the release branch, then re-run the probe set and
  confirm every module path 401s. Until then, no ICA-F1-dependent property may be
  asserted about production, and every handler-level `authenticateRequest` is
  load-bearing with no backstop.
- **Dependencies:** owner — deploy access. Blocks all of Workstream 7's live
  conclusions and any release claim about API security.
- **Risk of fixing:** deploy risk only; the code is already correct in the repo.
- **Evidence:** `docs/certification/findings/API-certification.md` §2, probes
  P8/P9/P10/P12/P13/P14/P15; `supabase/functions/api/app.ts:48-56`;
  `supabase/functions/api/eng4_5_forced_auth_test.ts:89-98`.

### API-106 · **P1** · Platform / Ops · `/health` cannot identify the deployed commit

- **Repro steps:** `curl https://akshara.veloraunisexsalon.com/health`.
- **Expected:** the build stamp `_shared/build_info.ts` was written to provide —
  `AKSHARA_BUILD_SHA` from the container env, or a colocated `build_info.json`
  written at deploy time.
- **Actual:** `{"status":"ok","service":"akshara-api","version":"unknown","builtAt":null}`.
  Neither source is populated, so "which commit is live" is unanswerable by any
  black-box means — which is exactly the question API-105 forced, and it had to
  be answered by inference from route behaviour instead.
- **Root cause:** the deploy step never sets the env var or writes the file; the
  handler's "unknown" fallback is silent.
- **Recommended fix:** set `AKSHARA_BUILD_SHA`/`AKSHARA_BUILD_TIME` in the deploy
  recipe, and make the post-deploy smoke check assert that `/health` reports the
  SHA just deployed.
- **Dependencies:** owner — deploy pipeline.
- **Risk of fixing:** low.
- **Evidence:** live probe P1; `_shared/build_info.ts:20-55`.

### API-107 · **P0** · Platform / Security · Sensitive health endpoints answer the public internet, implying the pilot runs with `APP_ENV != production`

- **Repro steps (live, read-only, performed):** with no
  `x-internal-health-token` header —
  `GET /health/tenant-access` → 503 with the full RLS isolation matrix;
  `GET /health/operations` → 200 with queue depths;
  `GET /health/storage` → 200 with the bucket name;
  `GET /health/providers` → 200 with `vault:{configured:false}`;
  `GET /health/backup` → 200 with the nightly backup's **sha256, byte size,
  `offsite:false` and completion time**.
- **Expected:** `requireInternalHealthAccess` returns
  `403 FORBIDDEN "Internal health endpoints require INTERNAL_HEALTH_TOKEN in
  production"` when the token is unset and `environment === "production"`.
- **Actual:** the guard passes through, which requires **both**
  `INTERNAL_HEALTH_TOKEN` unset **and** `APP_ENV` not equal to `"production"`.
  The guard has shipped since the pilot build (`9057bfb8`, 2026-06-10), so its
  absence from the deployed code is unlikely.
  Anonymous disclosure today: the tenant's school count (`visible_schools=7`),
  the internal DB role name, which isolation tests fail, operational queue
  depths, storage bucket, vault state, and backup fingerprints.
  **The second-order risk is larger than the leak.** `APP_ENV != "production"` is
  the same flag `canReturnOtpInResponse` reads: outside production the login OTP
  is returned **in the response body** for any allowlisted pilot phone, and for
  *every* phone when `OTP_DEV_MODE` is on. That is account takeover with no SMS.
  **This was not tested** — it is a mutation and an authentication attempt, both
  out of scope for a read-only pass.
- **Root cause:** container environment configuration, not code. The repo test
  `ICA-B2: canReturnOtpInResponse is false in production` passes while asserting a
  premise the live environment may not satisfy.
- **Recommended fix:** owner to read `APP_ENV`, `OTP_DEV_MODE`, `OTP_PILOT_PHONES`
  and `INTERNAL_HEALTH_TOKEN` off the live container **before release**. Set
  `APP_ENV=production` and a real `INTERNAL_HEALTH_TOKEN`; re-probe to confirm the
  health endpoints 403. Add a startup assertion that refuses to boot a
  production-hostname deployment with `APP_ENV != production`.
- **Dependencies:** owner — SSH/container access (outside this harness).
- **Risk of fixing:** low for the token; setting `APP_ENV=production` will
  correctly disable OTP-in-response, which pilot logins may currently depend on —
  verify SMS delivery works first.
- **Evidence:** live probes P3–P7; `_shared/internal_health_auth.ts:6-20`;
  `_shared/auth_handlers.ts:112-117`; `_shared/config.ts:91`.

### API-108 · **P0** · Platform / Tenant isolation · The live pilot's own RLS isolation matrix is failing four student-scope probes

- **Repro steps (live, read-only, performed):**
  `GET https://akshara.veloraunisexsalon.com/health/tenant-access`.
- **Expected:** `status: "ok"`, `isolation.pass: true`.
- **Actual:** `status: "degraded"`, `isolation.pass: false`, `enforced: true`,
  role `erp_tenant`, `bypassRls: false`, with four failing probes:

  | Probe | Live detail | Expected |
  |---|---|---|
  | `student_denied_student_profiles` | `visible_profiles=1` | 0 |
  | `student_denied_sis_students_api` | `visible_directory_rows=1` | 0 |
  | `student_denied_sis_student_create` | `visible_profiles_for_create=1` | 0 |
  | `student_denied_sis_dashboard` | `visible_directory_rows=1` | 0 |

  Every school↔school and parent↔child probe passes
  (`school_a_cannot_see_school_b`, `school_a_cannot_see_school_b_students`,
  `parent_cannot_see_unlinked_student`, `org_scope_denied_raw_students`), so this
  is a **persona** isolation failure, not cross-tenant leakage between schools: a
  `student`-scope DB session sees rows through `student_profiles` and the SIS
  directory/create/dashboard query shapes that the probes assert it must not.
- **Root cause:** undetermined. Either an RLS policy grants `student` scope more
  than intended on `student_profiles`/the SIS directory views, **or** the visible
  row is the student's own record and the probe's premise is wrong — in which
  case the probe is the defect and the pilot has been reporting a false
  `degraded` for as long as it has been deployed. Distinguishing them needs a DB
  session; there is no Postgres lane and SSH is owner-bound.
- **Recommended fix:** owner to run the four probe SQL shapes under a
  `student`-scope session and report the row's identity. If it is another
  student's record, fix the policy; if it is the student's own, fix the probe and
  restore a green matrix.
- **Dependencies:** owner — DB access. Nothing else in this workstream can raise
  or lower this until it is answered.
- **Risk of fixing:** unknown until the cause is known.
- **Evidence:** live probe P3; `_shared/tenant_isolation_probes.ts:1092-1099,
  1218-1226, 1254-1262, 1400-1408`.

### API-109 · **P2** · Platform / CORS · Preflight omits `DELETE` while the API exposes `DELETE` routes

- **Repro steps:** `curl -X OPTIONS -H "Origin: https://evil.example"
  https://akshara.veloraunisexsalon.com/finance/collections` (performed).
- **Expected:** every method the API serves is advertised.
- **Actual:** `Access-Control-Allow-Methods: GET, POST, PUT, PATCH, OPTIONS`.
  The API serves `DELETE /academic/timetables/substitutions/:id`,
  `DELETE /sis/students/:id/guardians/:guardianUserId` and others — several
  declared in the RBAC inventory itself. A browser client (the `web/` app) cannot
  issue them: the preflight never allows the method. The Flutter client is
  unaffected. Separately `Access-Control-Allow-Origin: *` lets any origin's
  script call the API with a bearer token it already holds; `*` prevents cookie
  credentials, and this API is bearer-only, so the practical exposure is bounded
   — but `*` is not a defensible default for a school-data API.
- **Root cause:** `corsHeaders` in `api/app.ts` was written before the `DELETE`
  routes existed and never revisited.
- **Recommended fix:** add `DELETE` to `Access-Control-Allow-Methods`; replace
  `*` with an allowlist of the web app's origins.
- **Dependencies:** none.
- **Risk of fixing:** low; origin allowlisting needs the deployed web origins.
- **Evidence:** live probe P17; `supabase/functions/api/app.ts:30-35`;
  `rbac_route_inventory.ts` (DELETE rules).

### API-110 · **P1** · Approvals / Audit · `POST /approvals/audit` writes the audit trail from a caller-supplied actor

- **Repro steps:** read `handleRecordApprovalAudit`.
- **Expected:** an audit entry's actor is derived from the verified session
  (`auth.claims.sub`).
- **Actual:** `actorId` and `actorName` are read from the **request body**
  (`optionalStr(body, "actor_id", "actorId")`) and inserted verbatim;
  `auth.claims.sub` is available and ignored. A `manageManagement` holder can
  write an approval-audit entry attributing an approval to any named person. The
  `action` field is a bare `as "submitted" | "approved" | "rejected" | "cancelled"`
  cast with no runtime validation, so an out-of-enum value reaches the
  `approval_audit_action_check` constraint and surfaces as a **500** rather than a
  422. The route is also absent from the RBAC inventory (API-100), and no client
  code was found calling it.
- **Root cause:** the endpoint mirrors the repository function's parameter list
  instead of the request's trust boundary.
- **Recommended fix:** derive `actorId` from `claims.sub` and `actorName` from the
  session's display name; validate `action` against the enum and return 422;
  consider deleting the route if nothing calls it.
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** `_shared/approval/approval_handlers.ts:675-720`;
  `supabase/migrations/20260617100000_approval_requests.sql:42-56`.

### API-111 · **P1** · Payments / RBAC · The inventory declares a `viewPayments` gate that is enforced nowhere

- **Repro steps:** `grep -r viewPayments supabase/functions lib`.
- **Expected:** `GET /payments/intents/:id` requires `viewPayments`, as declared.
- **Actual:** the string appears **only** in `rbac_route_inventory.ts` (the rule
  and the slug list). `handleGetPaymentIntent` never calls `requirePermission`;
  its only gate is `claims.scope !== "parent" && claims.scope !== "school"` → 403.
  Any school-scope session — a teacher, a librarian, a transport clerk — can read
  any payment intent in its school by id, exposing `amount`, `gatewayOrderId`,
  `collectionId`, `invoiceId`, `refundId`. School isolation still holds via the
  `payment_intents_school_read` RLS policy, so this is intra-school
  over-exposure, not a tenant leak. Of the 96 permission slugs in the inventory,
  this is the only one enforced nowhere — the other 95 are real.
- **Root cause:** the rule was written to the intended design; the handler was
  written to scope only, and nothing compares the two (API-101).
- **Recommended fix:** add `requirePermission(claims, "viewFinance")` (or mint
  and seed `viewPayments`) to the school-scope branch; keep the parent-ownership
  check.
- **Dependencies:** API-101 would have caught this.
- **Risk of fixing:** low — confirm which roles need the read before choosing the
  slug.
- **Evidence:** `_shared/payment/payment_handlers.ts:140-152`;
  `rbac_route_inventory.ts:140,401`.

### API-112 · **P2** · Approvals · Batch approvals are recorded against the literal name "Approver"

- **Repro steps:** approve two or more items via `POST /approvals/batch-decide`
  and read `approval_audit_entries`.
- **Expected:** the same approver name as a single approve/reject.
- **Actual:** `handleBatchDecideApprovals` sets `const actorName = "Approver";`
  before calling the shared `decideOne`; the single-decision handlers pass the
  real name. The same decision is attributed to a person one at a time and to
  "Approver" from the multi-select, in the table an auditor reads. `actorId` is
  correct in both, so the record is recoverable — but every human-readable
  approval report is wrong for batch decisions.
- **Root cause:** a placeholder left in when the batch path was factored onto the
  shared `decideOne`.
- **Recommended fix:** resolve the display name from the session, as the single
  path does.
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** `_shared/approval/approval_handlers.ts:596-597`.

### API-113 · **P1** · Finance · Money parsing silently converts malformed input into a plausible amount

- **Repro steps:** read `parseAmount` in `finance_collections_handlers.ts` and
  trace `body.amountCollected`.
- **Expected:** a non-numeric or badly-formed amount is a 422.
- **Actual:** `parseFloat(String(raw))` — `"100abc"` becomes `100`, `"1e5"`
  becomes `100000`, `"12.999"` is accepted at sub-paisa precision. There is no
  2-decimal check and no upper bound; only `<= 0` and `> outstanding` are
  rejected. The same idiom recurs across the finance handlers. The invoice lock,
  the over-collection guard and the day-close guard all operate on whatever
  number `parseFloat` produced.
- **Root cause:** `parseFloat`'s prefix-parsing semantics, used as if it were a
  validator.
- **Recommended fix:** one shared money parser — reject anything that is not a
  canonical decimal with ≤2 places, bound it, and use it on every money field.
- **Dependencies:** touches every finance write; do it once, centrally.
- **Risk of fixing:** medium — a stricter parser may reject client payloads that
  currently work; audit the client DTOs first.
- **Evidence:** `_shared/finance/finance_collections_handlers.ts:127-132`;
  `_shared/finance/finance_collections_repository.ts:432-476`.

### API-114 · **P1** · Exams · `maxMarks` accepts values that make an exam permanently unusable

- **Repro steps:** `POST /academics/exams` with `maxMarks: -50`, then attempt any
  mark entry for that exam. Repeat with `maxMarks: 0` and `maxMarks: 1.5`.
- **Expected:** a positive integer, or a 422.
- **Actual:** `maxMarks: Number(body.maxMarks ?? body.max_marks ?? 100) || 100`.
  `0` is falsy and silently becomes `100` (the school's zero-mark exam is stored
  as a 100-mark exam). `-50` is truthy and is stored — the column is
  `INTEGER NOT NULL DEFAULT 100` with **no** positivity CHECK — and because the
  mark constraint is `marks_obtained >= 0 AND marks_obtained <= max_marks`,
  **every** subsequent mark entry for that exam fails at the database. The exam
  is unusable and the teacher sees a 500-class failure, not a validation message.
  `1.5` reaches an `INTEGER` column and errors as a 500.
- **Root cause:** `Number(x) || default` used as a validator; no DB CHECK as
  backstop.
- **Recommended fix:** require a positive integer in the handler (422 otherwise)
  and add `CHECK (max_marks > 0)` to `exam_sessions`.
- **Dependencies:** the CHECK needs a migration and a scan for existing bad rows.
- **Risk of fixing:** low.
- **Evidence:** `_shared/academics/exam_administration/exam_administration_handlers.ts:458`;
  `supabase/migrations/20260618120000_f4_exam_sessions.sql:16`;
  `supabase/migrations/20260814000000_red_team_wave1_transactional_integrity.sql:95-107`.

### API-115 · **P2** · Platform / Validation · No free-text field in the core ERP has a length limit

- **Repro steps:** grep the migrations for `char_length`/`length(` CHECKs and the
  handlers for any maximum-length validation.
- **Expected:** every persisted free-text field is bounded.
- **Actual:** length constraints exist in exactly three places — the ASIP support
  tables (`title` 1–200, `description`/`body` ≤ 8000), `org_assets`, and
  `expense_ledger.category`. Everywhere else — `exam_sessions.title`,
  `approval_requests.title`, `finance_collections.notes` and `reference_number`,
  complaint text, broadcast bodies, student names — the column is bare `TEXT` and
  the handler applies `String(...)` and `.trim()` with no maximum. Nothing in the
  request path caps a string. `MAX_BULK_ITEMS` (500) bounds array length only,
  never element size. A single request can persist a multi-megabyte value that is
  then rendered into a receipt, a report and a PDF.
- **Root cause:** the support module was built with a validation discipline the
  older core modules were not.
- **Recommended fix:** a shared `boundedStr(body, key, max)` helper applied at the
  handler boundary, plus `CHECK (char_length(col) <= n)` on the high-traffic text
  columns.
- **Dependencies:** none; can be done module by module.
- **Risk of fixing:** low-medium — pick limits generous enough not to reject real
  data.
- **Evidence:** `supabase/migrations/20260920000000_support_incident_core.sql:79-80`
  (the good pattern); `20260618120000_f4_exam_sessions.sql:7`;
  `20260617100000_approval_requests.sql:10`.

### API-116 · **P2** · Platform / Tenant isolation · 30 repository reads restate no school predicate and rely on RLS alone

- **Repro steps:** scan `*_repository.ts` for `SELECT`s that bind
  `organization_id` but never `school_id`.
- **Expected:** defence in depth — route guard, repository predicate, RLS.
- **Actual:** 30 such queries, including `audit_events`
  (`audit_repository.ts:107`), `finance_collections`
  (`finance_collections_repository.ts:398`), `payment_intents` and
  `payment_requests` (`payment_repository.ts:78,121`), four communication tables,
  nine director queries over `finance_invoices`/`students`/`admissions_leads`,
  and the AI-wallet and storage-quota tables. The matching RLS policies were read
  and they **do** restate `school_id = app_current_school_id()`, so isolation
  holds today (the live pilot confirms `role: erp_tenant`, `bypassRls: false`).
  The risk is structural: any future path that runs one of these repositories
  under `createServiceClient` — which bypasses RLS — reads across every school in
  the organization with no second barrier. Service-client use is currently
  bounded and appropriate (auth, session validation, identity, the Razorpay
  webhook, the cron broadcast drain, HR offboarding), which is what keeps this
  latent.
- **Root cause:** RLS was introduced as the isolation mechanism and repository
  predicates were not brought up to match.
- **Recommended fix:** add the `school_id` bind to school-scoped reads; add a
  lint/test that a repository query touching a school-scoped table binds both.
- **Dependencies:** none.
- **Risk of fixing:** low, but each query needs checking for a legitimate
  org-scope caller (the director module genuinely needs the org view).
- **Evidence:** `docs/certification/findings/API-certification.md` §5.1 (full table).

### API-117 · **P1** · Platform / Security · Twelve handlers return the raw exception string to the client in a 500

- **Repro steps:** grep for `errorEnvelope(…, String(error), 500)` and
  `errorEnvelope("SERVER_ERROR", error.message, 500)`.
- **Expected:** `ENG-7 (SEC-6)` — the real message is logged server-side and the
  client gets a generic envelope plus a correlation id, as `handleRequest` does.
- **Actual:** twelve call sites catch the exception themselves and put its string
  in the response: `widget_platform_handlers.ts:45,68,105,130,156`,
  `widget_layout_handlers.ts:101`, `setup_wizard_handlers.ts:73,105,163`,
  `platform_providers_handlers.ts:51,58`,
  `control_center_write_handlers.ts:33`, `school_calendar_handlers.ts:45`,
  `copilot_handlers.ts:69`. A `deno-postgres` error stringifies to the driver
  message, carrying the failing SQL fragment plus table, column and constraint
  names. **`auth_handlers.ts:345` is the worst case**: it returns
  `SERVER_ERROR` with the Supabase insert error's `message` verbatim on the
  **pre-authentication OTP request path**, i.e. to an anonymous caller. Two more
  sites return DB-configuration text with a 503 (`tenant_handlers.ts:98`,
  `platform_db.ts:196`). The ~120 other `error.message` uses are on **typed
  domain errors** with author-written messages and are correct.
- **Root cause:** modules added their own catch-all after the central one was
  hardened, reintroducing the pattern locally.
- **Recommended fix:** delete these local catches and let the exception reach the
  central handler, or replace the message with a constant. Add a lint rule
  banning `String(error)` / raw `error.message` inside a 5xx `errorEnvelope`.
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** file/line list above; `supabase/functions/api/app.ts:363-380`
  (the correct pattern).

### API-118 · **P1** · Attendance · Five routes validate before they authorise, so a denial is reported as a 422 and no access-denied audit is written

- **Repro steps:** call `GET /attendance/register/monthly` without `classLabel`
  as a user lacking `viewSis`. Live (unauthenticated), performed:
  `curl https://akshara.veloraunisexsalon.com/attendance/register/monthly`
  → **422 `ATTENDANCE_VALIDATION — classLabel is required`**.
- **Expected:** 403, and an access-denied audit row.
- **Actual:** `handleAttendanceMonthlyRegister`, `handleAttendanceRegister`,
  `handleAttendancePending`, `handleAttendanceConsecutiveAbsence` and
  `handleAttendanceShortAttendance` all parse and reject query parameters
  **before** calling `withAuth`. An unauthorised caller learns the parameter
  contract instead of being refused. Because `api/app.ts` records the
  access-denied audit event by observing `response.status === 403` centrally
  (QA-X-017), no audit row is written for these denials. On the live build, where
  there is no central auth gate (API-105), the same code answers a fully
  anonymous caller.
- **Root cause:** the parse was hoisted above `withAuth` so a bad parameter could
  be rejected before opening a DB connection — a reasonable goal implemented in
  the wrong order.
- **Recommended fix:** authenticate and authorise first, then validate. If the
  early rejection is worth keeping, do it inside `withAuth` after the permission
  check.
- **Dependencies:** these are the same five routes missing from the RBAC
  inventory (API-103).
- **Risk of fixing:** low.
- **Evidence:** `_shared/attendance/attendance_handlers.ts:205-300`;
  `supabase/functions/api/app.ts:341-352`; live probe P12.

### API-119 · **P0** · Finance / Reliability · An in-flight `409 IDEMPOTENCY_CONFLICT` is recorded by the client as a confirmed write — a fee can be shown as collected and never reach the books

- **Repro steps:** two requests carrying the same `Idempotency-Key` for
  `POST /finance/collections`. Request A claims the key and is still running;
  the outbox drains request B, which receives `409 IDEMPOTENCY_CONFLICT`;
  request A then fails (validation, day-lock, DB error) and its claim is
  released.
- **Expected:** nothing was written, so the client must retry or surface a
  failure.
- **Actual:** `send_classification.dart` maps **any** 409 whose code is
  `IDEMPOTENCY_CONFLICT` to `SendClassification.confirmed` ("already applied").
  But the backend returns that exact code for a request **still in flight**
  ("A request with this Idempotency-Key is already being processed"), and the
  same wrapper **releases the claim on a non-2xx** so the failed attempt leaves
  no row. The outbox therefore stores `SyncStatus.confirmed`, which is terminal
  and never retried. For `OperationTypes.collectFee` that is a fee the app
  reports as collected and the books never receive. The same 409 shape is thrown
  by `module_write_handlers.runWithIdempotency`, so the whole generic
  entity-write surface shares it.
- **Root cause:** one status code is used for two different meanings — "already
  applied" (a stored 2xx payload exists) and "maybe applied, still running" — and
  the client was written against the first meaning. The backend comment ("the
  client treats this as 'already applied'") records the agreement; the code does
  not honour it.
- **Recommended fix:** split the wire contract. Return a distinct code (e.g.
  `IDEMPOTENCY_IN_FLIGHT`, 409) when the claim exists with a NULL payload, and
  reserve `IDEMPOTENCY_CONFLICT`/replay for a stored response. Classify the
  in-flight code as `transient` so the outbox retries with the same key. Until
  fixed, the safest client change is to classify 409 as `transient` for
  high-risk operations.
- **Dependencies:** backend + client must ship together; the client change alone
  is safe (extra retries are deduped by the same key).
- **Risk of fixing:** low, and it removes a silent-money-loss path.
- **Evidence:** `lib/core/reliability/sync/send_classification.dart:25-37`;
  `supabase/functions/_shared/idempotency_dispatch.ts` (in-flight 409 branch, and
  the `_safeRelease` on non-2xx);
  `_shared/entity_write/module_write_handlers.ts:84-92`;
  `lib/core/reliability/policy/operation_policy_registry.dart` (`collectFee`).

### API-120 · **P2** · Payments · Confirming an already-captured payment returns 200 or 422 depending on timing

- **Repro steps:** call `POST /payments/intents/confirm` twice for the same
  intent.
- **Expected:** one deterministic outcome for "this payment is already captured".
- **Actual:** `confirmPayment` returns success on its first read
  (`if (intent.status === "captured" || intent.status === "settled") return buildConfirmResult(intent);`)
  but throws `PaymentIntentStateError("Payment already captured …")` → **422**
  after taking the capture lock. Which one a parent gets depends purely on
  whether another request captured the intent between the two reads. Both mean
  "your payment went through"; only one looks like it.
- **Root cause:** the PRA-M-2 capture lock was added below an existing
  early-return without reconciling the two responses.
- **Recommended fix:** return the same idempotent success from the post-lock
  branch.
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** `_shared/payment/payment_service.ts:245-302`.

### API-121 · **P2** · Payments · The confirm path does not forward an `Idempotency-Key`

- **Repro steps:** compare `handleInitiatePayment` and `handleConfirmPayment`.
- **Expected:** symmetry — both money paths pass the header down.
- **Actual:** `handleInitiatePayment` passes `idempotencyKey: idempotencyKey(req)`
  to `initiatePayment`; `handleConfirmPayment` passes no key to `confirmPayment`.
  Confirm is protected only by the universal dispatch wrapper plus the
  `SELECT … FOR UPDATE` capture lock; there is no natural-key backstop tying a
  confirm to its intent, so if the wrapper is bypassed (no header) the lock is
  the only defence.
- **Root cause:** oversight when the key was threaded through initiate.
- **Recommended fix:** forward the key and persist it on the resulting
  collection, as the counter path does.
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** `_shared/payment/payment_handlers.ts:57-95` vs `97-138`.

### API-122 · **P2** · Payments · The Razorpay webhook mints a random dedupe key when the payload has no `id`

- **Repro steps:** read the event-id derivation in `handleRazorpayWebhook`.
- **Expected:** replay protection is a property of this service.
- **Actual:** ``const eventId = String(payload.id ?? `evt_${crypto.randomUUID()}`);``
  A payload without `id` produces a fresh key on every delivery, so
  `recordWebhookEvent` always reports "new" and the event is processed again on
  every redelivery. Razorpay always sends `id`, so this is latent — but it makes
  the guarantee depend on the provider rather than on the code, and it is silent
  when it degrades.
- **Root cause:** a defensive default that defeats the mechanism it defends.
- **Recommended fix:** reject a webhook with no event id (422) rather than
  fabricate one.
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** `_shared/payment/payment_handlers.ts:230`.

### API-123 · **P2** · Finance · `POST /finance/collections` has no natural-key dedup, only key dedup

- **Repro steps:** submit the same collection twice with two different
  `Idempotency-Key`s.
- **Expected:** the second is recognised as the same human intent, or is at least
  flagged.
- **Actual:** both succeed. Idempotency is keyed solely on
  `(organization_id, idempotency_key)`; there is no uniqueness on
  (invoice, amount, date, method). The client mints a fresh key per repository
  call, so a user tapping "Collect" twice, or re-entering the screen after a lost
  response, produces two keys and two collections. `ICA-A2` added exactly this
  kind of natural-key backstop for offline instruments
  (`finance_collections_offline_payment_uq`); the counter path has none.
- **Root cause:** the key-based mechanism was considered sufficient without
  modelling the double-submit case.
- **Recommended fix:** either a short-window duplicate check on
  (invoice, amount, method) returning a 409 the UI can explain, or a client-side
  stable key derived from the collection intent rather than minted per call.
- **Dependencies:** interacts with API-119 — fix that first.
- **Risk of fixing:** medium — a legitimate second identical payment (two
  instalments of the same amount on one day) must remain possible.
- **Evidence:** `_shared/finance/finance_collections_repository.ts:451-469,531-560`;
  `lib/core/reliability/reliable_writer.dart:25-33`.

### API-124 · **P2** · Reliability · Nothing asserts that a route reachable offline has a registered outbox policy

- **Repro steps:** read `OperationPolicyRegistry.withDefaults()`.
- **Expected:** a guard that every write the app can perform while offline is
  registered.
- **Actual:** eleven operations are registered; everything else falls back to
  `OperationPolicy.fallback` (`onlineOnly`). The registry is keyed by an
  operation-type string, not by route, and no test relates the two. A new
  queueable write is opted in by remembering to add an entry. The fallback is
  safe, so the failure mode is "a write that should have been queued isn't" — a
  lost teacher action rather than a corrupted one.
- **Root cause:** the registry is deliberately opt-in (documented), with no
  completeness check.
- **Recommended fix:** enumerate the `OperationTypes` constants used by
  `ReliableWriter` call sites and assert each has an explicit policy.
- **Dependencies:** none.
- **Risk of fixing:** low.
- **Evidence:** `lib/core/reliability/policy/operation_policy_registry.dart:33-80`.

<!-- ═══════════════════════════════════════════════════════════════════════
     OS — Workstream 10, School-OS coherence (2026-07-29)
     Full trace: docs/certification/findings/OS-school-operating-system.md
     WS4's propagation evidence (dead event bus, 9 jobs / 3 crons, 31 manual
     steps) is accepted and NOT re-derived. These entries cover the other
     dimensions: shared state, cross-cutting layers, role/workspace, DAI,
     entity continuity, per-module isolation.
     Backend paths are relative to supabase/functions/_shared/.
     ═══════════════════════════════════════════════════════════════════════ -->

### OS-001 · **P0** · Student app · Canonical attendance null collapsed to 0% at a third mapper (extends XMOD-010)

- **Repro steps:** Open the student app for a student before any attendance has
  been marked, or in a window where every marked day was excused.
- **Expected:** "—" / no data. The canonical helper's contract is explicit —
  `null`, never 0 (`attendance/attendance_percentage.ts:24-26`).
- **Actual:** The student is shown **0%** attendance in their own app.
- **Root cause:** `lib/core/repositories/api/student/mapper/student_mapper.dart:221`
  does `raw['attendancePercent'] as int? ?? 0`. XMOD-010 registers the same
  coercion at `parent_mapper.dart:394` and `phase5_mapper.dart:150` but **not
  this third site**, and its recommended fix is scoped to those two files.
- **Why it is registered separately rather than folded in:** three modules
  independently decided what to do with one canonical value, and two of the three
  decisions were caught. Fixing XMOD-010 as written would leave the student app
  lying.
- **Recommended fix:** Fix all three together — make the model fields nullable
  and render the honest-state placeholder the design system already has.
- **Dependencies:** XMOD-010 — same wave, same change.
- **Risk of fixing:** Low-medium (nullability ripples into consuming widgets).
- **Evidence:** `supabase/functions/_shared/attendance/attendance_percentage.ts:24-26`;
  `lib/core/repositories/api/student/mapper/student_mapper.dart:221`.

### OS-002 · **P0** · SIS, Finance, Analytics, Director, Entitlements · Four definitions of "how many students", and the billing meter uses the loosest

- **Repro steps:** On one school on one day, compare the student count on the
  Director dashboard, the SIS dashboard, the Analytics surface and the Finance
  dashboard. Then check what the entitlement seat check counts.
- **Expected:** One number from one canonical resolver.
- **Actual:** Four structurally different numbers, and **alumni and transferred
  students count against the school's paid licence.**
- **Root cause:** No canonical active-student function exists. Four rival
  predicates:
  (a) `status='active'` — `director/director_repository.ts:118,324,338,734`,
  `sis/sis_dashboard_repository.ts:105`,
  `management/management_aggregate_repository.ts:341`;
  (b) **no status filter at all** — `analytics/analytics_metrics_service.ts:15`,
  `copilot/copilot_context_engine.ts:192`, `sis/sis_dashboard_repository.ts:102`,
  and decisively **`entitlements/entitlement_limits.ts:121`, which enforces the
  paid seat slab**;
  (c) `sis_student_enrollments WHERE is_current = true` —
  `analytics_metrics_service.ts:19`, `copilot_context_engine.ts:197`,
  `sis_dashboard_repository.ts:113`;
  (d) `count(DISTINCT student_id) FROM finance_student_accounts WHERE
  status='open'`, labelled `total_students` —
  `finance/finance_dashboard_repository.ts:62-65`.
  `sis_dashboard_repository.ts` alone uses two of them, at `:102` and `:105`.
  Compounding it, `lib/core/repositories/api/sis/dto/sis_enum_codec.dart:31` maps
  **`SisStudentStatus.prospect => 'active'`**, so unenrolled prospects are
  written to the server as active students and inflate every count above,
  **including the seat count**. Three status vocabularies exist (DB
  `sis/sis_status_codec.ts:5`, API `:2`, Flutter
  `lib/features/sis/sis_models.dart:30`); the backend codec is disciplined, the
  client codec is not.
- **Why P0:** a school is over-billed for students who have left, and a principal
  is shown a different roll number depending on which screen they open.
- **Recommended fix:** One `countActiveStudents(schoolId, asOf)` in `_shared/`,
  defined against `sis_student_enrollments.is_current`; make entitlements call it;
  fix the prospect→active client mapping.
- **Dependencies:** OS-006 (an as-of date needs an academic-year resolver).
- **Risk of fixing:** Medium — changes a billed quantity; needs an owner decision
  on whether the corrected count is applied retroactively.
- **Evidence:** file:line list above.

### OS-003 · **P0** · Exams · A 35% student is F on the server and D on the report card

- **Repro steps:** Enter 35% for a student. Read the grade the server assigns,
  then the grade the client-rendered report card shows.
- **Expected:** One grading scale.
- **Actual:** **F** from the server, **D** on the report card.
- **Root cause:** Two rival "defaults", each documented in its own source as
  *"identical to the legacy fixed grading"*:
  `academics/exam_administration/exam_administration_repository.ts:200-208`
  (`DEFAULT_GRADE_BANDS`, 7 bands ending `>=40 D, >=0 F`) and
  `lib/core/exams/exam_grading.dart:47-55` (`ExamGradingScale.standard`, 6 bands
  ending `>=50 C, >=0 D`). The Flutter side additionally ships three presets —
  `cbseScholastic`, `stateBoardSsc`, `percentageDivision` (`:60-115`) — with **no
  backend counterpart**, so a school on the State Board preset gets client grades
  the server can never reproduce.
- **Why P0:** an examination grade is a claim a school makes about a child that
  the child and parent act on and cannot independently check. Two disagreeing
  sources mean at least one of them is issuing a false one.
- **Recommended fix:** One grading service on the server; the client renders what
  it is given. Move the three presets server-side and key them to school config.
- **Dependencies:** XMOD-030 (State-Board SSC scale unreachable) — this is the
  divergence underneath it.
- **Risk of fixing:** Medium-high — changes issued grades; needs a migration
  decision for results already published.
- **Evidence:** file:line list above.

### OS-004 · **P0** · Exams, Parent app · No exam-percentage helper; 24 inline sites, three rounding rules, and an unguarded division that crashes the parent app

- **Repro steps:** Publish an exam component with `maxScore = 0` (a placeholder
  or mis-configured slot). Open the parent app's exam view.
- **Expected:** A guarded, consistent percentage.
- **Actual:** `0/0` → `NaN.round()` → **`UnsupportedError`** — the parent app
  throws. And across the product, the same percentage is computed with three
  different rounding rules.
- **Root cause:** There is no shared percentage helper anywhere.
  **Crash:** `lib/features/parent/exams/exam_models.dart:57` —
  `int get percent => ((scoreObtained / maxScore) * 100).round();` with no
  `maxScore == 0` guard. **Line 99 of the same file does guard** — two rules, one
  file. **Divergence:** backend
  (`academics/exam_administration/exam_administration_repository.ts`) passes a raw
  double to `gradeForPercent` at `:306,967,1070,1760,2356`, rounds to 2dp via
  `Math.round(p*100)/100` at `:1534,1663`, and via `Math.round(x*10000)/100` at
  `:1602,2378`; Flutter uses integer `.round()` at `exam_report_card.dart:34,103`,
  raw doubles at `:168,226,308`, 2dp at
  `exam_administration_store.dart:1279`, and raw at
  `exam_reports.dart:258,311,360`.
- **Why P0:** it is both a crash on a parent-facing path and a divergence in a
  number that determines a grade.
- **Recommended fix:** One `examPercent(score, maxScore)` returning nullable, in
  a shared module with a paired SQL definition — the pattern
  `attendance_percentage.ts` already proves works. Fix the missing guard first;
  it is a one-line release-blocker.
- **Dependencies:** OS-003 — the same call sites feed grading.
- **Risk of fixing:** Low for the guard; medium for convergence (changes
  displayed percentages).
- **Evidence:** file:line list above.

### OS-005 · **P1** · Finance, Management, Director · Three definitions of "collected", and one file uses two of them 111 lines apart

- **Repro steps:** For one school and one month, compare total collected on the
  Tally export, the Finance dashboard, the Management aggregate and Finance
  Intelligence.
- **Expected:** One figure.
- **Actual:** Three, because refunded money is counted as collected by some
  callers and not others.
- **Root cause:** `collection_status = 'completed'` at
  `director/director_repository.ts:125,298,456`,
  `copilot/copilot_context_engine.ts:143`, `dashboard/dashboard_service.ts:64`,
  `pilot/pilot_snapshot_repository.ts:779`,
  `finance/finance_recovery_repository.ts:382,444`,
  `finance/finance_reports_repository.ts:33`,
  `finance/finance_tally_repository.ts:54`; versus
  `IN ('completed','partially_refunded','refunded')` at
  `finance/finance_dashboard_repository.ts:75,118`,
  `management/management_aggregate_repository.ts:352`,
  `finance/finance_intelligence_service.ts:58`; versus
  `IN ('completed','partially_refunded')` at
  `finance_intelligence_service.ts:169`. **`finance_intelligence_service.ts` uses
  two different definitions 111 lines apart**, so its own collection-rate KPI at
  `:180` is internally inconsistent — and `:180` is itself an inline fork of
  `computeCollectionRate` (`finance_dashboard_repository.ts:39`), which has
  exactly one production caller (`:163`).
- **Recommended fix:** One `collectedAmount(scope, window)` with an explicit,
  documented refund policy; delete the forked rate calculation.
- **Dependencies:** XMOD-014 (five definitions of outstanding dues) — the same
  disease on the other side of the ledger; fix as one wave.
- **Risk of fixing:** Medium — changes reported money figures.
- **Evidence:** file:line list above.

### OS-006 · **P1** · Platform / all modules · There is no academic-year resolver; 66 hard-coded literals in two different dash characters

- **Repro steps:** Try to move the product to FY 2027-28. Then compare the year
  string Finance sends with the one SIS sends.
- **Expected:** One resolver reading `academic_years.is_current`.
- **Actual:** 66 hard-coded literals across `lib/` — **31 with an ASCII hyphen
  (`2026-27`) and 29 with an en-dash (`2026–27`)** — compared by string equality
  (`mock_finance_repository.dart:2726`,
  `mock_academic_operations_repository.dart:370`). **Finance's year and SIS's year
  are different strings for the same year.** Rolling over requires a code change
  in 66 places.
- **Root cause:** `TenantContext` (`lib/core/tenant/tenant_context.dart:7-18`)
  carries only `tenantId`, `schoolId`, `organizationId`, `userId` — no year, no
  term — so every module invents one:
  `finance/fee_structures/finance_fee_structures_provider.dart:14` (`'2026-27'`),
  `sis/academic_assignment/sis_academic_assignment_screen.dart:44` (`'2026–27'`),
  `admissions/admissions_models.dart:609` (`'2026–27'`),
  `finance/finance_workflow_actions.dart:194` (`'2026-27'`),
  `school_completion/substitute_manager_screen.dart:27` and
  `teacher_reassignment_screen.dart:25` (`academicYearId = 'year_1'`). The backend
  **has** the source of truth — `academic/academic_years_repository.ts:118-119`
  (`academic_years.is_current`) — and nothing in `lib/` reads it to seed these
  defaults.
- **Recommended fix:** Add `academicYearId` and `termId` to `TenantContext`,
  seeded from `academic_years.is_current` at session bootstrap; delete the
  literals; normalise the dash at the codec boundary.
- **Dependencies:** OS-017 (this is the missing spine of the workspace context).
  Blocks OS-002.
- **Risk of fixing:** Medium — touches 66 sites, but mechanically.
- **Evidence:** file:line list above.

### OS-007 · **P0** ⭐PRIORITY-REMEDIATION-CANDIDATE · Platform / Audit · Audit is not transactional at any of its 305 call sites

- **Repro steps:** Cancel a fee collection while the audit table is unavailable
  (constraint violation, permission, contention).
- **Expected:** Either both the mutation and its audit row commit, or neither.
- **Actual:** **The mutation has already committed, no audit row exists, and the
  caller receives a 500 telling them it failed.** All three outcomes are wrong at
  once: the money moved, the trail is missing, and the operator believes it did
  not happen — so they will do it again.
- **Root cause:** `runTenant` (`tenant_db.ts`) issues no `BEGIN`/`COMMIT`; only
  15 files in the entire backend touch `savepoint`. `emitMutationAudit`
  (`audit/mutation_audit_catalog.ts:15`) is a separate awaited statement **after**
  the mutation at all 305 sites — e.g.
  `finance/finance_collections_handlers.ts:398-408`, where `cancelCollection`
  commits and then audits.
- **Why P0 and why a priority candidate:** the audit trail is the product's legal
  record and the RC phase explicitly hardened the attendance-correction path to
  audit *"in-transaction with real before→after"*. **That guarantee cannot hold,
  because there are no transactions.** A durability claim that the architecture
  cannot deliver is worse than a known gap, and it is on the money path.
- **Recommended fix:** Wrap mutation + audit in one transaction in `runTenant`,
  or make the audit write a deferred outbox row inside the same statement. The
  catalog and writer are good; only the boundary is wrong.
- **Dependencies:** None. Prerequisite for trusting any audit-based claim.
- **Risk of fixing:** Medium-high — touches the shared DB entry point for every
  handler; needs a full backend regression.
- **Evidence:** `supabase/functions/_shared/tenant_db.ts`;
  `_shared/audit/mutation_audit_catalog.ts:15`;
  `_shared/audit/audit_repository.ts:283,380`;
  `_shared/finance/finance_collections_handlers.ts:398-408`.

### OS-008 · **P1** · Approvals, Vault, Student Health, and 6 more · Three private audit trails invisible to `/audit`, and seven modules that mutate with none

- **Repro steps:** As an auditor, open the audit console and look for approval
  decisions, platform-secret access, or student medical-record access.
- **Expected:** All auditable mutations in one trail.
- **Actual:** None of the three appears. They exist — in three private tables
  nobody queries.
- **Root cause:** Audit is otherwise a genuine platform layer (one writer, one
  catalog, 305 sites, **48 of 62 mutating modules participate**). The exceptions:
  `approval/approval_repository.ts:214` writes its own `approval_audit_entries`;
  `vault/vault_service.ts:107,134` writes `platform_secret_audit_log`;
  `student_health/student_health_repository.ts:71` writes
  `student_health_access_log`. **Reimplementing a platform service privately is
  worse than skipping it** — the trail exists, so the gap is invisible to anyone
  checking whether auditing happens. Six further modules mutate with **zero**
  audit of any kind: `approval/approval_repository.ts:277`,
  `entity_write/entity_write_store.ts:103`,
  `expense_ledger/expense_ledger_repository.ts:109`,
  `parent_experience/parent_experience_service.ts:87`,
  `storage/storage_quota_repository.ts:66`, `vault/vault_service.ts:93`, plus
  `student_health/student_health_repository.ts:235`.
- **Recommended fix:** Route the three private trails through
  `recordServerAuditEvent` with a module-specific event type; add the six unaudited
  write paths to the catalog. Add a test asserting every module directory
  containing an INSERT/UPDATE imports the audit writer.
- **Dependencies:** OS-007.
- **Risk of fixing:** Low-medium.
- **Evidence:** file:line list above; `_shared/audit/audit_repository.ts:283`.

### OS-009 · **P0** ⭐PRIORITY-REMEDIATION-CANDIDATE · Platform / Notifications · The notification rail reaches 15% of modules; 53 modules change state and tell nobody

- **Repro steps:** Mark a child absent. Record a book overdue. Take a payment.
  Then check whether any human was told.
- **Expected:** A notification rail every module inherits.
- **Actual:** **`payment` moves money and notifies nobody. `attendance` marks a
  child absent and notifies nobody. `library` records an overdue book and
  notifies nobody.**
- **Root cause:** `communication/notification_service.ts` (`enqueueFromTemplate`
  `:40`, `processDeliveryQueue` `:83`, `enqueueNotificationRequested` `:218`) is a
  well-built rail with **nine callers outside `communication/` itself**, against
  roughly 62 mutating modules — **≈15% adoption**. The nine: `gate_pass`
  (`gate_pass_repository.ts:479,489`), `support` (`support_handlers.ts:129`),
  `teacher` (`teacher_parent_communication_handlers.ts:134`), `transport`
  (`transport_write_handlers.ts:720`), `promotion`, `school_completion`
  (`communication_bridge_service.ts:151`), `pilot`
  (`pilot_operations_handlers.ts:253,1180`), `student_health`
  (`student_health_operations.ts:174`), `reminders`. `communication/` is a **peer
  module other modules mostly do not know exists**, not a rail they sit on.
- **Why P0 and why a priority candidate:** this is the single strongest
  disproof of "operating system" in the product. A school ERP whose events do not
  reach people is a filing cabinet. It also generalises three already-registered
  defects that are not isolated misses but samples from a 53-module population:
  SIM-003 (complaints notify nobody at any point in a complaint's life),
  XMOD-023 (issued certificates never delivered to the parent), XMOD-019
  (absence alert enqueued but not sent).
- **Recommended fix:** Treat enqueue as a first-class step of the mutation
  catalog — the same place `emitMutationAudit` already sits — so a module that
  declares an auditable mutation also declares its audience. Start with the three
  named above.
- **Dependencies:** XMOD-016 (nine periodic jobs, zero schedulers — the rail
  needs a drain); OS-007 (same transactional boundary).
- **Risk of fixing:** Medium-high — real messages to real parents; needs
  per-event audience resolvers and rate limiting.
- **Evidence:** file:line list above.

### OS-010 · **P1** · Platform / Diagnostics · There is no request-scoped diagnostics layer; the one that exists has a single caller

- **Repro steps:** A principal reports "fees didn't save this morning". Try to
  find that request.
- **Expected:** A request-scoped trail carrying user, session, tenant, school and
  correlation id.
- **Actual:** Nothing to search. `request_context.ts:15` (`setRequestContext`) has
  **exactly one caller** — `auth_handlers.ts:211`.
- **Root cause:** No `_shared/observability`, no request-scoped logger, no error
  reporter, and no correlation propagation beyond an optional
  `x-correlation-id` header read at `audit_repository.ts:396`. The RC phase built
  the request-identity payload (userId/sessionId/tenantId/schoolId/scope from the
  verified JWT, with `student_id` deliberately excluded) and nothing calls it.
  The one genuine cross-cutting piece is the error envelope (`http.ts:33,46`, 200
  files, a single raw `new Response(JSON.stringify(` outlier) — so the error
  *shape* is uniform and observability is absent.
- **Recommended fix:** Call `setRequestContext` in the shared route dispatcher
  rather than in one handler, and emit it on every non-2xx.
- **Dependencies:** None.
- **Risk of fixing:** Low-medium.
- **Evidence:** `_shared/request_context.ts:15`; `_shared/auth_handlers.ts:211`;
  `_shared/http.ts:33,46`; `_shared/audit/audit_repository.ts:396`.

### OS-011 · **P1** · Platform / Reporting · No backend report service; ~55 modules have no reporting surface at all

- **Repro steps:** A board asks the principal for last term's attendance report,
  the complaints log, and the inventory register.
- **Expected:** A shared report service every module inherits.
- **Actual:** None of the three exists. There is **no shared CSV/PDF/report
  service in `_shared/` at all.**
- **Root cause:** Eight hand-rolled report files across only four modules —
  `finance/finance_reports_*`, `finance/finance_tally_export.ts`,
  `hr/hr_reports_*`, `admissions/admissions_reports_*`,
  `education/education_paper_export.ts`. The client does have a genuine shared
  service (`lib/core/reports/akshara_report_export_service.dart`, 20+ callers),
  but 8 modules still ship bespoke `*_report_exporters.dart` on top of it. **About
  55 backend modules have no reporting surface** — including attendance,
  complaints, certificates, inventory, hostel and staff duty, every one of which
  holds data a principal will be asked for by a board, a parent or an inspector.
- **Recommended fix:** One `_shared/reporting/` service (query → typed rows →
  CSV/PDF) that modules register report definitions into.
- **Dependencies:** POLISH-013 (six client Export buttons are stubs precisely
  because there is nothing behind them).
- **Risk of fixing:** Medium — new service, but additive.
- **Evidence:** file:line list above.

### OS-012 · **P1** · Platform / Dashboards · The dashboard widget platform is fully built and has zero consumers; all 23 dashboards are bespoke

- **Repro steps:** Grep `lib/features/**dashboard**` for `dynamic_widget`.
- **Expected:** Dashboards composed from registered widgets.
- **Actual:** **Zero hits.** All 23 dashboards are hand-built.
- **Root cause:** `lib/features/dynamic_widgets/` ships a registry, a layout
  editor and a runtime screen (6 files); the backend ships
  `widget_platform/widget_pack_catalog.ts` with 6 widget ids
  (`homework_summary`, `operations_summary`, `fee_collection`, `school_health`,
  `student_risk`, `attendance_risk`), full CRUD and a router entry. Nothing
  consumes any of it.
- **Why it matters:** an unused platform layer is worse than no platform layer —
  it carries maintenance and migration cost, it appears in inventories as a
  capability, and it disguises the absence of a real dashboard platform. It is
  also why the same insight is hand-duplicated across screens (WIDGET-012) and
  why four dashboard widgets ship with no rendering site (WIDGET-015). Same
  pattern as POLISH-017, at platform scale.
- **Recommended fix:** Either migrate the six catalog widgets onto real
  dashboards, or delete the platform and say so. Do not leave it as an
  inventory entry.
- **Dependencies:** WIDGET-015, WIDGET-012.
- **Risk of fixing:** Low to delete; medium to adopt.
- **Evidence:** `lib/features/dynamic_widgets/` (6 files);
  `_shared/widget_platform/widget_pack_catalog.ts`; 23 dashboard screens under
  `lib/features/*/dashboard/`.

### OS-013 · **P1** · Platform / RBAC · Ten route prefixes are outside the RBAC inventory guard

- **Repro steps:** Compare `_shared/validation/rbac_route_inventory.ts` against
  `_shared/route_registry.ts`.
- **Expected:** Every registered prefix present in the inventory, so the
  invariant test can verify its gating.
- **Actual:** 47 prefixes covered against ~57 registered. **Absent:**
  `attendance`, `attendance-auth`, `copilot`, `analytics`, `homework`, `school`,
  `school-config`, `support`, `plans`, `legal`.
- **Root cause:** The inventory is maintained by hand and has drifted. Those ten
  modules gate in-handler only, unverified by the guard.
- **Why this is worth an entry despite RBAC being the product's best platform
  layer** (`route_registry.ts:119` with a single-ownership guard;
  `permission_middleware` in 146 files): this is **exactly the drift that produced
  the RC phase's five fail-open routes**, where `RouteNames.adminErpRoutes` and
  `kErpRouteViewPermissions` disagreed and both gates keyed off the looser one
  (`docs/roadmap/RC_EXECUTION_LOG.md:48-52`). An invariant test was added on the
  Flutter side; the backend inventory has the same shape of hole and no such
  test. `attendance` being in the gap is the one to look at first.
- **Recommended fix:** Derive the inventory from the registry rather than
  maintaining it, and fail CI when a registered prefix has no inventory entry.
- **Dependencies:** Two attendance routes missing from the inventory are already
  a tracked RC P1 — same fix.
- **Risk of fixing:** Low.
- **Evidence:** `_shared/route_registry.ts:119`;
  `_shared/validation/rbac_route_inventory.ts:12`;
  `docs/roadmap/RC_EXECUTION_LOG.md:48-52`.

### OS-014 · **P1** · Workspaces / RBAC · The workspace model collapses at both ends, and four roles cannot reach the modules their job requires

- **Repro steps:** Sign in as an admissions counsellor and try to enrol the
  applicant you just admitted. Then as a librarian, try to look up the student
  borrowing a book. Then as a hostel manager, try to see a resident's fees.
- **Expected:** A workspace containing the modules that role uses together.
- **Actual:** None of them can. Each workspace contains **one module**.
- **Root cause:** `kRoleWorkspaces` (`lib/core/workspace/workspace.dart:177-193`)
  maps 15 roles (`lib/core/security/erp_role.dart:2-17`) onto 10 workspaces
  (`workspace.dart:15-26`), and the mapping degenerates at both ends:
  **five roles collapse into one workspace** — superAdmin, schoolAdmin,
  principal, vicePrincipal and management all resolve to `schoolAdministration`,
  so the product distinguishes a principal from a VP in its permission model and
  then shows them an identical workspace; and **eight of ten workspaces hold
  exactly one module** (`workspace.dart:110,119,128,137,146,155` — finance,
  inventory, transport, hostel, library each a singleton; frontOffice =
  {admissions, marketing}), while **three hold zero** (teaching, parentSpace,
  studentSpace, `:95-102,157-172`).
  Compounding it, `homeRouteForStaffErp`
  (`lib/features/auth/qa_login_persona.dart:207-216`) has arms for only 5 of 15
  roles; **seven staff roles** (schoolAdmin, management, admissionsCounselor,
  transportManager, hostelManager, librarian, storekeeper) fall to
  `_ => RouteNames.admin` at `:214` and land on the launcher — **even though
  their own workspace declares a `homeRoute`** at `workspace.dart:126,135,144,153`
  that is never consulted. The data to fix that exists and is not read.
- **Why P1:** a "workspace" that is a synonym for a single module is not a
  workspace, and the admissions counsellor case breaks the product's own primary
  workflow: admit, then enrol, spans two workspaces and the role that performs it
  can only see one.
- **Recommended fix:** Populate workspaces around **jobs** rather than modules —
  frontOffice should hold admissions, SIS, certificates, gate pass and complaints;
  finance should include SIS lookup; hostel and library should include SIS. Then
  read `workspace.homeRoute` in `homeRouteForStaffErp` instead of the unfinished
  switch.
- **Dependencies:** JOURNEY-004 (the unfinished landing switch), JOURNEY-008 (the
  five orphaned desks), JOURNEY-013 (no office-staff role to hold them).
- **Risk of fixing:** Low-medium — widening a workspace changes which tiles each
  role sees; permission filtering still applies on top.
- **Evidence:** `lib/core/workspace/workspace.dart:15-26,59-173,177-193`;
  `lib/core/security/erp_role.dart:2-17,46-59`;
  `lib/features/auth/qa_login_persona.dart:207-216`.

### OS-016 · **P1** · Student 360, Finance, SIS, Transport, Library, Teacher · Role opens the door and never furnishes the room — 2 of 8 shared screens adapt to the viewer

- **Repro steps:** Open Student 360 as a teacher, then as a hostel manager, then
  as a finance admin. Compare what each sees.
- **Expected:** A screen scoped to what that role needs and is entitled to see.
- **Actual:** **The identical 1,050-line dossier** — fees, behaviour,
  communication history, documents — to all three. A hostel warden and the
  accountant both read a child's full behavioural and communication record.
- **Root cause:** **17 of 310 `*_screen.dart` files (5.5%)** reference
  `rbacServiceProvider`, `hasPermission` or `ErpRole` at all.
  `lib/features/student_360/student_360_screen.dart` has **zero** occurrences.
  So do `finance/collections/finance_collections_screen.dart`,
  `teacher/attendance/teacher_attendance_screen.dart`,
  `sis/registry/sis_registry_screen.dart`,
  `transport/routes/transport_routes_screen.dart`, and **every screen in
  `lib/features/library/`**. Role is enforced only at the route guard.
  The two that do it properly are worth naming as the target pattern:
  `sis/profile/sis_profile_screen.dart` (per-action gates at
  `:101,115,129,144,473,541` plus `hasPermission(approveClearanceWaiver)` at
  `:158`) and `academics/exam_admin/exam_marks_entry_screen.dart` (six distinct
  gates — `manageExamMarks` `:507`, `manageExams` `:524`, `verifyExamResults`
  `:535`, `submitExamResults` `:546`, `publishExamResults` `:567`,
  `moderateExamMarks` `:1004`).
  The structural tell is the timetable: rather than one role-adaptive screen
  there are **four hard-forked copies** —
  `academics/timetable/timetable_hub_screen.dart`,
  `teacher/timetable/teacher_timetable_screen.dart`,
  `student_app/timetable/student_timetable_screen.dart`,
  `parent/timetable/parent_timetable_screen.dart`. Role is resolved by file path,
  not by the screen. That is the architecture of four apps.
- **Recommended fix:** Section-gate Student 360 by permission (fees behind
  `viewFinance`, behaviour and communication behind their own), using the
  `AksharaManageAction` pattern `sis_profile_screen.dart` already uses.
- **Dependencies:** None for Student 360.
- **Risk of fixing:** Low-medium — some roles will lose sections they can
  currently see, which is the intent.
- **Evidence:** file:line list above.

### OS-017 · **P1** · Platform / Workspace context · Workspace, academic year and class context do not propagate; only tenant does

- **Repro steps:** Pick Class 8A in teacher attendance, then open Fees, Exams or
  SIS. Then switch workspace and observe what changes in any module.
- **Expected:** Context follows the user.
- **Actual:** You re-pick the class in every module, and switching workspace
  changes only which tiles render.
- **Root cause:** `activeWorkspaceProvider` / `activeWorkspaceIdProvider` /
  `userWorkspacesProvider` (`lib/core/workspace/workspace_providers.dart:8-34`)
  are read by **exactly four files outside their own directory** —
  `admin/admin_navigation_provider.dart:328`,
  `admin/screens/admin_hub_screen.dart:32`,
  `shared/navigation/persona_nav.dart:166`,
  `shared/widgets/workspace_switcher.dart:19,22,46,68,71,156`. **Zero feature
  modules read it.** Class context is private to
  `lib/features/teacher/attendance/` and
  `teacher/reports/teacher_report_exporters.dart`. Academic year has no global
  provider at all (see OS-006). The one thing that does propagate is
  `repositoryQueryProvider` (`lib/core/tenant/tenant_provider.dart:41-43`), read
  by **173 files** — genuinely shared, and a data-fetch scope rather than a UI
  context. `currentUserContextProvider` (`:46`) is read by one file.
- **Why P1:** the product's stated north star is USER→ROLE→WORKSPACE→TASK. The
  workspace exists as a data structure with a switcher and a hero graphic, and is
  consumed by four navigation files and no module. It is a nav filter wearing the
  name of a context.
- **Recommended fix:** Extend `TenantContext` into a school context carrying
  workspace, academic year, term and (optionally) a selected class, and make
  `repositoryQueryProvider` — which 173 files already read — the propagation
  vehicle.
- **Dependencies:** OS-006 (year/term), OS-014 (workspaces need real contents
  before propagating them is meaningful).
- **Risk of fixing:** Medium — changes fetch scope broadly; needs care that
  narrowing context does not hide data a role currently sees.
- **Evidence:** file:line list above.

### OS-018 · **P1** · DAI / Global search · 23 of 30 modules cannot be asked about, including every front-office desk

- **Repro steps:** Ask the assistant about a library book, a hostel resident, a
  staff member's leave, a gate pass, a certificate, or an infirmary visit.
- **Expected:** Something, or an honest "I cannot answer that".
- **Actual:** Nothing — those modules have no intent (and per DAI-007 there is no
  cannot-answer state either).
- **Root cause:** `lib/core/dai/dai_resolver.dart:66-78` (`_rules`) defines 11
  intents (`dai_intent.dart:6-42`) reaching **7 modules**: Finance
  (`openReceipt` `:111-125`, `feeDefaulters` `:128-149`), SIS (`lowAttendance`
  `:152-172`, `openClass` `:273-288`), Transport (`:175-191`), Attendance
  (`:194-212`), Homework (`:215-228`), Exams (`:231-244`), and parent/student
  self-service (`:247-270`). `openPerson` (`:295-340`) resolves to a null route.
  Unreachable: admin, admissions, marketing, certificateDesk, gatePass,
  complaints, studentHealth, schoolCompletion, hr, employee, management, hostel,
  library, inventory, alumni, controlCenter, director, organizationBuilder,
  platformOperations, industry, healthcare, salon, restaurant, accommodation,
  whiteLabel, dynamicWidgets.
- **Compound effect worth noting:** the five desks orphaned from every workspace
  (JOURNEY-008) are also absent from DAI — so they are unreachable from the hub,
  from the bottom nav, and from search. There is no path to them at all.
- **Recommended fix:** Add intents for the desks first (certificate, gate pass,
  complaint, infirmary) — they are the surfaces a front office reaches for by
  name, and they currently have no other entry point.
- **Dependencies:** JOURNEY-008; DAI-007 (no cannot-answer state).
- **Risk of fixing:** Low — additive rules in an ordered list.
- **Evidence:** `lib/core/dai/dai_resolver.dart:66-78,111-340`;
  `lib/core/dai/dai_intent.dart:6-42`;
  `lib/features/admin/models/admin_nav_models.dart:6-38`.

### OS-019 · **P1** · DAI / Global search · DAI reads zero state, so no question spanning two modules can ever be answered

- **Repro steps:** Ask "which Class 8 students have both low attendance and fee
  dues" — the canonical question an OS answers and a module collection cannot.
- **Expected:** An answer, or an honest refusal.
- **Actual:** A deep link into **one** module's list screen, with the other half
  of the question discarded and the class filter dropped.
- **Root cause:** `DaiResolver` is declared `abstract final class` and documented
  as **"Pure and synchronous. No I/O, no clock, no randomness"**
  (`dai_resolver.dart:26-27`). It reads no repository, no provider, no `ref`.
  Every intent yields a route string the caller `context.go()`s
  (`lib/features/admin/global_search/global_search_overlay.dart:170`). It carries
  `className`, `section` and `threshold` as fields on the intent and **the
  destination screen never receives or applies them** — `sisStudents` is pushed as
  a bare route (the mechanism behind DAI-004 and DAI-011). And `_feeDefaulters`
  and `_lowAttendance` are **mutually exclusive rules in an ordered first-match
  list** (`:50-53`), so a two-predicate question cannot even be represented. The
  sibling `GlobalSearchRegistry` has 18 static entries — a menu index, not a query
  engine.
- **Why it belongs in this workstream rather than WS5:** DAI-006 registers that
  "Ask anything" over-promises. This entry records the architectural reason: DAI
  is a natural-language shortcut **to the navigation menu**. That is a legitimate
  and useful thing to have built, and it is not integration. Cross-module query is
  not missing — it is excluded by the resolver's stated design contract.
- **Recommended fix:** Decide explicitly. Either keep the pure resolver and
  reframe the product copy as navigation (cheap, honest, closes DAI-006), or add
  a query tier above it that reads shared state and can compose predicates. Do not
  ship the current copy over the current capability.
- **Dependencies:** DAI-004, DAI-006, DAI-011.
- **Risk of fixing:** Low for the copy; high for a query tier.
- **Evidence:** `lib/core/dai/dai_resolver.dart:26-27,50-53,66-78`;
  `lib/features/admin/global_search/global_search_overlay.dart:170`.

### OS-020 · **P1** · Student 360 · The product's one cross-module hub has zero outbound taps, and its model has no field for library, hostel or health

- **Repro steps:** Open Student 360 for any student. Tap the Fees figure. Tap the
  attendance percentage. Tap an exam row. Tap the transport route. Look for the
  student's library loans.
- **Expected:** The screen built as a 360° view lets you follow the student into
  each module.
- **Actual:** **Nothing is tappable.** And the library, hostel and health data are
  not there to link to.
- **Root cause:** `lib/features/student_360/student_360_screen.dart` is 1,050
  lines containing **zero** occurrences of `context.push`, `context.go`,
  `Navigator`, `RouteNames.` or `onTap`. Every section — Academic performance
  `:98`, Attendance `:105`, Fees `:112`, Transport `:118`, Homework `:124`,
  Behaviour `:130`, Communication `:136`, Documents `:142` — is built by `_Section`
  (`:628-666`), which passes `List<(String,String)> entries` into an
  `AksharaKeyValueCard`: plain text pairs. `_ExamList` (`:688`) renders and never
  navigates. The only outbound actions are "call guardian" (which **leaves the
  app**, `:493`) and PDF export (`:905`). And `Student360Profile`
  (`student_360_models.dart:3-45`) has **no `library`, `hostel`, `health`,
  `certificate` or `gatePass` field** — precisely the three or four modules a
  school chases a student across at year end.
  Inbound is healthy by contrast: five modules deep-link in via `openStudent360`
  (`lib/router/student360_navigation.dart:7-10`) — student_success `:309`,
  sis_profile `:342`, sis_registry `:374`, teacher class dashboard `:122`,
  teacher_student_risk `:173`. **Every module can push you in; nothing carries you
  out.**
- **Why P1 and why it is the workstream's clearest single exhibit:** the
  entity-continuity test fails at hop one, on the screen designed to pass it. The
  screen is not missing links so much as missing the idea that its contents are
  entities.
- **Recommended fix:** Make each section header and each row a navigation target
  into the owning module scoped to the student; add the missing model fields
  (library loans, hostel allocation, health visits) — which also closes the
  clearance blind spot XMOD-021 and XMOD-025 describe from the other side.
- **Dependencies:** XMOD-021, XMOD-025 (hostel/library/inventory invisible to
  clearance); OS-021 (Hostel and Library hold no linkable student key).
- **Risk of fixing:** Low-medium for the taps; medium for the model fields, which
  need Hostel and Library to key on the student UUID first.
- **Evidence:** `lib/features/student_360/student_360_screen.dart:98-142,493,628-666,688,905`;
  `lib/features/student_360/student_360_models.dart:3-45`;
  `lib/router/student360_navigation.dart:7-10`.

### OS-021 · **P1** · Hostel, Alumni, Backup, Memories, Parent Meetings, Continuity, Dynamic Widgets · Seven modules are ISOLATED — they work, but nothing outside them learns anything happened

- **Repro steps:** Allocate a hostel room. Graduate a student. Open the backup
  console. Then check whether any other module knows.
- **Expected:** For a School OS, at minimum: the resident is the same person as
  the SIS student; graduating creates an alumnus; the backup status is real.
- **Actual:** None of it. **This list is the answer to the workstream's
  question.**
  1. **Hostel** (LIVE) — touches only `hostel_entities`
     (`hostel/hostel_read_repository.ts:7,56`); imports nothing but audit,
     entitlements and the generic entity store. **It carries its own duplicate
     copy of the student roster** as a `student` entity type inside
     `hostel_entities` (`:224-225`), so a hostel resident and an SIS student are
     two unrelated records. Registered `tracked: false` in the clearance registry
     (`clearance/clearance_contributors.ts:115-125`) and absent from every shared
     dashboard query. **A residential school's second-largest operational surface
     is a private database.**
  2. **Alumni** (HIDDEN, owner CODE-8) — zero SQL, zero cross-module imports
     beyond audit/entitlements; a pure `alumni_entities` JSONB blob.
     **Graduating a student in SIS does not create an alumnus.** The isolation is
     structural, not a consequence of hiding.
  3. **Backup & Restore** (LIVE, orphan route) —
     `lib/features/admin/backup/backup_restore_screen.dart`. No backend
     directory; the status panel is a **hard-coded static card**; and the route
     has zero navigation references (`lib/router/app_router.dart:602` is the only
     mention). A backup console reporting a fabricated status is a claim about
     data safety nobody can act on.
  4. **Memories** (HIDDEN) · 5. **Parent Meetings** (HIDDEN — UI built, **no
     backend write path at all**) · 6. **Continuity** (HIDDEN — no backend
     directory) · 7. **Dynamic Widgets** (HIDDEN — complete backend, zero
     consumers, OS-012).
- **Explicitly excluded rather than counted:** verticals (healthcare, salon,
  restaurant, accommodation), industry, white-label, platform operations,
  multi-school, branch, franchise, workflow automation, resource optimisation and
  education/QIE are MOCK/HIDDEN in the release build per FEATURE_INVENTORY.md
  M25/M26 — flags absent from `config/live_release.json`, repositories resolving
  to `Mock*`, both hide gates active. **Hiding a backend-less surface is the
  honest behaviour the inventory documents, not a defect.**
- **Recommended fix:** Hostel first and alone — key `hostel_entities` on the SIS
  student UUID, delete the duplicate roster, and flip its clearance contributor
  to `tracked: true`. Alumni second — derive from SIS graduation. Backup:
  either connect it or remove the route.
- **Dependencies:** XMOD-021 (clearance covers fees only), XMOD-025 (nothing
  released when a student leaves), OS-020.
- **Risk of fixing:** Medium for Hostel (data migration from the private roster);
  low for the rest.
- **Evidence:** file:line list above; `docs/certification/FEATURE_INVENTORY.md`
  M25/M26 for the MOCK/HIDDEN determinations.

### OS-022 · **P1** · Library, Complaints, HR/Payroll · Three modules that only look connected

- **Repro steps:** Return a book late and ask which parent was told. Raise a
  complaint and ask who was notified. Run payroll and look for the expense in
  Finance.
- **Expected:** The borrower's parent, the assignee, and a posted expense.
- **Actual:** Every parent in the school, nobody, and nothing.
- **Root cause:** Each of these would pass a shallower audit, which is why they
  are recorded rather than left inside OS-021.
  **Library** escapes ISOLATED only via `library/library_write_handlers.ts:1049`
  (`scheduleReminder` → `comm_broadcasts`) — and that call is a **blanket
  broadcast to the entire parent body**, not a message to the borrower's parent.
  The module's own comment at `:30` says so: *"fan out to the whole parent body."*
  Members are keyed **by name, not by student UUID**; it holds a
  `library_entities` JSONB store with no SIS read; clearance registers it
  `tracked: false` (`clearance/clearance_contributors.ts:98-112`).
  **Functionally an isolated ledger with a megaphone** — every parent is told a
  book is overdue and the one who owes it is not told specifically.
  **Complaints** escapes only by reading `inventory_vendors` to fill an assignment
  dropdown (`complaints/complaints_repository.ts:436`). It writes `complaints`
  and `complaint_events` and produces no notification at any point — SIM-003
  confirmed structurally rather than by symptom.
  **HR/Payroll** — `hr/hr_finance_posting_repository.ts:105` writes
  `payroll_finance_postings`, and **no module reads that table** (the only
  mentions are inside `hr/`). The intended consumer,
  `_shared/expense_ledger/`, has **zero `postExpense` callers and is not
  registered in `route_registry.ts`**. The Finance import at `hr/hr_handlers.ts:12`
  is a response mapper only. **The payroll → finance link is fully built and never
  connected** — the same "built, tested, never wired" pattern as POLISH-017 and
  OS-012, here on the money path. Salary is the largest expense a school has and
  it does not reach the books.
- **Recommended fix:** Library — key members on the student UUID and address the
  overdue reminder to that student's guardians. Complaints — enqueue on raise,
  assign and resolve (SIM-003 has the detail). Payroll — register
  `expense_ledger` in the route registry and call `postExpense` from
  `hr_finance_posting_repository.ts`.
- **Dependencies:** OS-009 (the rail), SIM-003, XMOD-021.
- **Risk of fixing:** Medium for Library (re-keying members); low-medium for the
  other two — both are wiring existing, working code.
- **Evidence:** file:line list above.

---

## FIN-AUDIT — money-terminal state transitions (added 2026-07-29)

Targeted audit of every write that moves a record into a money-terminal state,
prompted by the recorded recurring pattern for this codebase: *a terminal
state-write with no status guard double-applies.*

**Overall result: the money-out paths are in good shape.** Refunds
(`finance_refunds_repository.ts:329,489`) use claim-first writes —
`AND refund_status = 'pending' RETURNING *` with throw-on-zero-rows — so
approve and reject cannot both land. Collections serialize on
`FOR UPDATE OF fi` and refuse to over-credit
(`finance_collections_repository.ts:471`). Fee reductions use the same proven
pattern. One outlier was found and fixed; two findings are recorded below.

### FIN-AUDIT-001 — `payment.failed` demoted captured intents — ✅ FIXED
- **Severity:** P1 (would be P0 with payments live)
- **Where:** `payment/payment_service.ts` — `processRazorpayWebhook`
- **What:** the failed branch wrote `SET status='failed' WHERE id = $1` with no
  status guard, while the capture path directly beside it was correctly guarded.
  Razorpay does not guarantee webhook ordering and one order can emit
  `payment.failed` for an attempt and `payment.captured` for the retry, so a
  late failure demoted an intent whose money had been captured.
- **Impact:** parent shown "payment failed" for money the school took;
  reconciliation sees a failed payment that cleared a due. Drives duplicate
  payment by the parent.
- **Status:** fixed — guarded with `AND status NOT IN ('captured','settled')`;
  zero rows treated as processed-and-ignored, not an error, so the gateway does
  not redeliver forever. Two regression tests added (there were none for
  `payment.failed` at all); verified to fail without the guard.

### FIN-AUDIT-002 — payment can be initiated for an already-paid installment
- **Severity:** P1 — NOT release-blocking for V1 (see exposure)
- **Where:** `payment/payment_service.ts` — `initiatePayment`, and
  `resolveInstallmentInvoiceId` at `:75`
- **What:** initiation resolves the installment's invoice but never checks that
  anything is still outstanding. A gateway order is created for an installment
  that is already fully paid.
- **It fails CLOSED, which is why this is P1 and not P0:** the capture path
  refuses to over-credit (`createCollection` throws when
  `amountCollected > outstanding`), so the invoice is never double-credited and
  outstanding cannot go negative. But the refusal happens AFTER the parent has
  paid — money sits with the gateway, no collection is written, and the intent
  never reaches `captured`. Recoverable by refund, but only once someone notices.
- **Recommended fix:** pre-flight the outstanding amount in `initiatePayment`
  and fail before `provider.createOrder`, with the same typed
  `PaymentIntentStateError` used for the missing-invoice case at `:139`. Cheap,
  and it moves the failure to before the money moves.
- **Exposure today:** none. `RAZORPAY_STUB_MODE` defaults true and no payment
  SDK ships in V1, so no real money can move. This must be closed before online
  payments are enabled.

### FIN-AUDIT-003 — `payment_requests.status` can be walked backwards
- **Severity:** P3 — cosmetic/reporting only
- **Where:** `payment/payment_repository.ts:197`
- **What:** `UPDATE payment_requests SET status='initiated' WHERE id = $1`, run
  from `createPaymentIntent`, has no guard. Re-initiating against a request that
  reached `captured` walks it back to `initiated`.
- **Why only P3:** `payment_requests.status` is a coarse tracker; the
  authoritative money record is the intent plus the finance_collections row,
  and neither is affected. Worth a guard for consistency, not urgent.
