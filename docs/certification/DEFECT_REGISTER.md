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
| 79 | 16 | 42 | 18 | 3 |

By workstream: **CERT** 6 (1 P0 · 5 P1) · **XMOD** 39 (10 P0 · 22 P1 · 7 P2) ·
**DAI** 16 (2 P0 · 7 P1 · 5 P2 · 2 P3) · **WIDGET** 18 (3 P0 · 8 P1 · 6 P2 · 1 P3).

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
