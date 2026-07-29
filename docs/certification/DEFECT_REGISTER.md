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
| 45 | 11 | 27 | 7 | 0 |

By workstream: **CERT** 6 (1 P0 · 5 P1) · **XMOD** 39 (10 P0 · 22 P1 · 7 P2).

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
