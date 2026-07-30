# SIM — Real School Simulation (Workstream 3A)

**Workstream:** 3A (Real school simulation) · **Date:** 2026-07-29
**Repo:** `/Users/surendrakanna/Documents/Akshara_ERP-release` · **Branch:** `release/v1.0-playstore`
**Method:** static end-to-end trace of nine operational sequences through the
Flutter client, the Deno backend (`supabase/functions/_shared/**`) and the
migrations, read as *what a person has to do*. Read-only; nothing was changed.

**This builds on Workstream 4 and does not re-derive it.**
`docs/certification/findings/XMOD-cross-module-certification.md` already
established, with evidence: the domain-event outbox is structurally dead (368
write sites, 171 event types, an empty subscriber registry and a drain whose
result set is always empty); nine jobs are written as periodic work and exactly
three crons exist on the VPS (scheduled broadcasts, watchdog, nightly backup);
and 31 human steps are required for the product to produce correct outcomes.

Those are the *mechanics*. This workstream asks the human question: **what does
the office actually have to remember, and what breaks first on a busy morning?**

## The school

Sunrise Public School. 620 students, Classes 1–10, two sections each. 34
teachers, one principal, one vice principal, one accounts clerk, one office
clerk who also runs the front desk, a librarian, a transport in-charge with
6 buses, and a part-time nurse. One person — the office clerk — is the entire
back office. Everyone works from a phone; the accounts clerk has a laptop.

---

<!-- Sequences appended below, one at a time. -->
## 0. The one thing the whole day rests on — and nothing watches it

Before any sequence: **everything a parent is ever told depends on one
environment variable being set on one container.**

XMOD counted three installed crons. Two of them (watchdog, nightly backup) are
infrastructure. The third is the scheduled-broadcast sweep, and tracing it
changes the picture in one important way that should be recorded honestly:

`runScheduledBroadcastsForOrg` does not only dispatch due broadcasts. After each
org's dispatch it calls `scheduleNotificationDrain`
(`_shared/communication/communication_handlers.ts:739`) →
`drainNotificationQueue` (`:104-115`) → `processDeliveryQueue(db, orgId)`
(`_shared/communication/notification_service.ts:83`), which claims **every**
pending delivery for that organization — absence alerts, gate-pass OTPs, message
notifications, everything — not just the broadcast's own. It runs for every
active org (`:764-781`), every 5 minutes
(`deploy/akshara-vps/communication-cron/install-communication-cron.sh:36`).

So the queue *is* drained on a schedule — **provided the cron is authenticated.**
And the installer states plainly that it does not do that:

> "this installer wires up the CLIENT side (cron + env file) only. It does NOT
> set `INTERNAL_CRON_TOKEN` on the akshara-edge container … Running this
> installer alone leaves the cron firing 401s (safe — fails closed) until that
> step is done."
> — `install-communication-cron.sh:6-12`

`verifyInternalCronToken` has no "unset = open" mode in any environment
(`_shared/communication/communication_cron_auth.ts:14-33`), which is the correct
security choice. The operational consequence is that a **single unset env var
silently stops every notification in the school**, and:

- the cron logs `FAIL run-scheduled http=401` to
  `/var/log/akshara/communication-cron.log` and nothing else
  (`akshara-broadcast-cron.sh:47-50`);
- the watchdog checks `/health/ready`, `/health/backup`, `/health/storage` and
  container health (`deploy/akshara-vps/monitoring/akshara-watchdog.sh:106-108,140-142`)
  — **not** the cron's exit status, not the delivery-queue depth, not the age of
  the oldest pending delivery;
- nothing in the app tells a school "your parents have not received anything for
  three days." The Delivery Console (`/school/communications/delivery`) shows
  metrics if someone opens it.

The school would learn about it from a parent.

**`SIM-001` (P1)** — no monitoring on the one path that carries every parent
message. *(This also refines, and does not contradict, XMOD's "nothing is
scheduled": the endpoint has no cron of its own, but the broadcast cron drains it
as a side effect. Whether that cron is authenticated on the pilot VPS could not
be verified — SSH is owner-bound.)*

---

## 1. 07:50 — Morning attendance

**What the school does.** 20 class teachers open the app on the bus, in the
corridor, or at the desk, and mark their class before the first bell.

**What the product does well.** This is the best-built flow in the product.
`/teacher/attendance` opens with the class preselected when the teacher taps
today's period on their dashboard (`?class=` preselect,
`lib/router/teacher_navigation.dart:66-72`); the roster is an exception-first
grid; there is a destructive-overwrite confirm with Undo; the in-progress roster
autosaves as a draft; the Submit button names the blocker ("7 unmarked"); an
offline submit is queued and replayed by the sync engine. Six taps for a
40-child class with three absentees. A teacher can genuinely do this in the
corridor.

**What the office has to remember, in order.**

1. **That a teacher has not marked at all.** The pending feed exists —
   `_AttendancePendingWidget` on the principal's dashboard
   (`management_dashboard_screen.dart:389-401`) — but it is a card someone must
   look at. No teacher is reminded, no escalation exists, nothing at 09:30 says
   "Class 6-B is unmarked".
2. **To tell the parent about anything other than a plain absence.** Only
   `mark === 'absent'` enqueues (XMOD chain 1, hop 5a). *Late*, *half-day*,
   *excused*, and every later **attendance-correction approval** notify nobody.
   The busiest real case — a child who arrived at 09:10 — reaches the parent only
   if a human phones.
3. **That the alert the parent gets is unusable.** The body is the hardcoded
   English string `"Student marked absent for class {class_id}"` — no child name,
   no date. A parent with two children in the school cannot tell which one.
   The five-language `attendance_absence` template exists
   (`_shared/communication/parent_comms_localization.ts:69-105`) and has zero
   callers.
4. **That a child on approved leave is still counted absent.** The auto-excuse
   is wired (`pilot/pilot_attendance_repository.ts:223`) but its input requires
   `from_date IS NOT NULL`, and no client ever sends it (XMOD-002). The class
   teacher must remember to raise an attendance correction afterwards — which
   then notifies nobody (see 2).
5. **That two rosters disagree after any student exit.** The display roster
   filters `s.status='active'`; the submit validator filters only
   `e.is_current = true` with no `students` join, and nothing sets `is_current`
   on a status change. Result: `AttendanceRosterMismatchError` and **attendance
   submission for that class is hard-blocked** (XMOD chain 6, hop 7).

**What breaks first on a busy morning.** Item 5. A student was marked
`transferred` yesterday afternoon; this morning that class's teacher cannot
submit at all and gets an error naming a student who is no longer on their
screen. There is no self-service fix — `is_current` has no UI (XMOD boundary).
The class's attendance simply does not exist for that day, which then flows into
the parent app, the office report, the risk score and the principal's dashboard.

**Also unmonitored:** the "3 consecutive absences" and "below 75%" alerts are
pull-only. `GET /attendance/alerts/consecutive-absence` and
`/alerts/short-attendance` are rendered on the office-attendance screen
(`lib/features/management/attendance/office_attendance_screen.dart:33-36`) and
nowhere else — no push, no digest, no cron. A child missing for a week produces
a row on a screen nobody is obliged to open. **`SIM-002` (P1).**

---

## 2. 09:20 — A leave request, end to end

**The teacher's side.** Mrs Rao opens More → Leave, types a reason, and taps
apply. The "From date" field is a **free-text `TextField`**
(`lib/features/teacher/leave/teacher_leave_screen.dart:206-214`), and the DTO
sends `type_label / from_date_label / to_date_label / reason`
(`teacher_write_request_dto.dart:128-133`) — labels, not dates. So the request
lands in `mobile_leave_requests` with `from_date = NULL`.

**The approver's side.** The vice principal approves it. `leave_decision_effect.ts:36-42`
runs `UPDATE mobile_leave_requests SET status, updated_at`. That is the entire
effect.

**What now has to happen by hand, because nothing else does:**

| # | The human step | Why |
|---|---|---|
| 1 | **Notice** that a teacher is away | `listTeachersOnLeave()` requires `from_date IS NOT NULL` (`timetable/substitution_repository.ts:339-344`) → always `[]` → the Daily Substitutions banner is permanently empty |
| 2 | Find someone free, period by period | the substitute wizard's input is the empty list from step 1 |
| 3 | **Tell** the substitute, the class in-charge and the students | `assignSubstitute` returns `notifiedAudience` by echoing the caller's own checkboxes and the literal string *"Substitute assigned and timetable updated."* — there is no notification call in that function (`school_completion/timetable_workforce_service.ts:336-347`) |
| 4 | Mark Mrs Rao's own attendance | approval writes no attendance row; there is **no** HR attendance write endpoint at all, and no `on_leave` status exists |
| 5 | Explain the muster | the muster prints **`A`** for her — "a working day with NO check_in → Absent" (`hr/hr_reports_repository.ts:279-284`); `'L'` in that report means *Late*, not *Leave* |
| 6 | Reconcile the contradiction | the HR dashboard's *"On leave today"* KPI reads `snapshot_leave` and counts her (`hr/hr_read_repository.ts:203-208`) while the muster counts her absent. Both are on screen at the same time |

**And a second, invisible failure.** HR-module staff leave is stored in the JSONB
`snapshot_leave` (`hr/hr_write_handlers.ts:443,462-469`); teacher-app and
parent-app leave is stored in the table `mobile_leave_requests`
(`pilot/pilot_leave_repository.ts:39-59`). Nothing bridges them. So a teacher who
applies through the app appears in **no HR report at all**, and a teacher whose
leave HR entered appears in **no substitution query**. Two leave systems, one
school, and the school cannot tell which one it is looking at.

**Who can even fix the timetable:** `manageAcademicTimetable` is held only by
superAdmin, schoolAdmin, principal and vicePrincipal
(`lib/core/security/role_permissions.dart:76,241,357,465`). At 08:05 the person
who actually reshuffles periods in a real school is a senior teacher or the
academic coordinator — `coordinator` is a server role with no client
representation (JOURNEY-002), and a teacher holds none of these. The vice
principal must do all of it personally, on a phone.

**The parent side is the same shape.** A parent applies for their child's leave;
approval flips a status; the child is still marked absent (§1 item 4); nobody is
notified either way.

---

## 3. 10:00 — Fee collection at the counter

**The clerk's path.** `/finance/dashboard` → sub-nav **More** → **Collections** →
**Record collection** → dialog. Three taps before typing anything, because
Collections is the 5th sub-nav entry and only four fit inline on a phone
(JOURNEY-011). The dashboard itself has no collect action.

**What the product does well — and it is genuinely good.** The write is one
transaction taking the invoice `FOR UPDATE` and writing collection + receipt +
invoice + account + head allocation together, with Idempotency-Key replay
protection (`finance/finance_collections_repository.ts:334-631,454,531`). The
parent's outstanding-dues view recomputes live from the real invoice rows and
overwrites any stale snapshot (`pilot/pilot_snapshot_repository.ts:466-515`). The
dashboard KPI is a live, uncached query. Money integrity inside Finance is
sound.

**What the office has to remember.**

1. **That taking the child's admission does not raise an invoice.** Admission →
   handoff row (automatic) → a human picks a fee structure and "sends to Finance"
   → a human assigns the structure in Finance → *that* raises the account,
   invoice and installments. Two deliberate human steps sit between "the child
   joined" and "the child owes money" (XMOD chain 3, hops 1b/1c).
2. **That allocating a bus seat does not raise a transport fee.** `POST
   /transport/allocations` writes the allocation and returns 201 without calling
   `raiseTransportDemandFor`; the code concedes it at
   `transport/transport_write_handlers.ts:1855-1858`. Someone must open Transport
   Settings and press "Raise demand". **Miss it and the child rides free, with
   zero dues, permanently** — and nothing anywhere flags an allocation with no
   demand.
3. **That receipt numbers are random unless a flag is flipped.**
   `receipts.receipt_sequencing` defaults to `"false"`
   (`finance/finance_settings_repository.ts:49`), so until someone turns it on,
   receipts are `RCPT-{year}-{hex}`. An Indian school's auditor expects a gapless
   book.
4. **That the parent is not told a payment landed.** The post-commit notice is
   SMS-only, errors swallowed, and early-returns unless
   `TRANSACTIONAL_SMS_ENABLED=true`, which **defaults false**
   (`finance/finance_collections_handlers.ts:77-111`, `config.ts:127`). No push,
   no in-app, no email. The receipt exists in the parent app if they go and look.
5. **That the Payment Reminders settings page does nothing.** `reminders.due_reminder_days`,
   `reminders.overdue_reminder` and `receipts.auto_receipt_sms` are rendered as
   editable, described settings with zero consumers anywhere in `supabase/**` or
   `lib/**` (XMOD chain 3). A school will configure a reminder ladder, see it
   saved, and receive nothing. That is worse than the feature being absent.
6. **To run late-fee accrual by hand** (`POST /finance/late-fees/accrue`, no cron)
   — and to remember that it does **not** exclude departed students
   (`finance/finance_late_fee_repository.ts:106-118` has no `students` join), so
   ex-students keep accruing late fees and stay on the dunning list forever.

**What the parent sees meanwhile.** On any failure of the fee or payment call the
parent app does not say "we could not load this" — it renders fabricated money.
`/parent/fees` shows a ₹23,000 annual fee and four fake "Paid" rows (CERT-001);
`/parent/payment` shows another child's name and a ₹4,200 due amount, and would
send that amount to the initiate endpoint (JOURNEY-007). A brand-new school with
no fee structure assigned is exactly the state that triggers both.

**What breaks first.** Item 2, and it breaks quietly. Nobody notices a missing
transport demand in month one; they notice it in month four when the transport
P&L does not reconcile, by which point four months of demand were never raised
for however many students.

---

## 4. The exam cycle, end to end

**Ten steps, seven of them human.**

| Step | Who | Automatic? |
|---|---|---|
| Create exam (draft) | exam admin | manual |
| Schedule → provision mark slots | server, inside the schedule call | automatic — but inserts `marks_obtained = 0`, **not NULL** |
| Enter marks | each subject teacher | manual; computes nothing — no total, grade, rank or percent is written |
| "Process results" | exam admin | manual — it counts un-entered marks and flips a phase |
| Coordinator verify | coordinator | manual |
| Submit for approval | exam admin | manual |
| Principal approves | principal | manual |
| **Publish + bake grades** | server | **automatic** ✅ — inside the approval transaction |
| Report cards | staff pull `GET …/report-cards?term=` per class | manual; nothing is generated or stored at publish |
| Parent sees results | parent app | automatic, and correctly gated on `published = true` |

The publish step is genuinely good engineering: approving the request publishes
the results and writes `effective_marks` + `grade_letter` in the same
transaction. The chain works.

**What the school lives with anyway.**

1. **Report cards are not produced.** Publishing generates nothing. For 620
   students across 20 sections, someone opens the report-cards endpoint **per
   class, per term** and prints. There is no batch, no queue, no "generate all".
2. **Parents are not told.** `…_handlers.ts:918` → SMS only, swallowed, requires
   `transactionalSmsEnabled` + a provider. No push, no in-app. In practice the
   school sends a WhatsApp message manually.
3. **A merely-scheduled exam already reads as 0%.** Because provisioning inserts
   `marks_obtained = 0`, and `GET /parent/experience/hub` reads marks with **no
   `published` filter** (`parent/parent_experience_service.ts:118-131`), a parent
   can see *"Maths Unit Test (38%)"* — or a 0% — for a paper nobody has marked.
   The publish gate holds on the results screen and is bypassed on the hub.
4. **Absent / medical / debarred is honoured in three places and violated in
   five.** Most damagingly, the **parent/student** report card sums all lines with
   no `countsTowardStats` filter (`lib/core/exams/exam_report_card.dart:166-168`),
   so a child who was ill for one paper has that subject counted as 0 out of its
   full marks — their overall percentage and grade are depressed on the copy the
   family reads, while the admin copy computes it correctly.
5. **Grading forks.** The backend has one `gradeForPercent` over
   `exam_grade_scales`; Flutter carries a second implementation, and inside
   Flutter the parent/student card hardcodes `ExamGradingScale.standard`
   (`exam_report_card.dart:179`) while admin paths read the school's configured
   scale. A State-Board school configures its scale, and the parent's copy shows
   a different letter.

**The human consequence:** the report card the office prints and the report card
the parent opens can disagree on both the percentage and the grade, for the same
child, on the same exam. Nobody in the school has a way to notice.

---

## 5. A Transfer Certificate

Mrs Khan's family is moving. She comes to the office on a Tuesday.

**What works, and works well.** The no-dues gate is genuinely fail-closed on the
**write** path — `sis/sis_certificates_repository.ts:541-559` throws before serial
allocation, mapped to `409 DUES_PENDING`. TC serial numbers are gapless and
allocated server-side under a row lock. The bypasses are closed: `issueCertificate`
rejects `transfer`, and raw status writes re-enforce the gate. The certificate
text is careful — it asserts only *"All financial dues have been cleared"*, not
"all dues", so nothing false is printed.

**What "no dues" actually covers.** Fees: yes, blocking. Library: blocking, but
only inside the TC engine and keyed on `payload->>'sisStudentId'` — a free-text
field a librarian types, with no foreign key. Inventory/uniform/textbooks:
advisory only, and not even executed at the gate. Hostel: never queried.
**Transport: no contributor exists at all.**

So the office must chase hostel, transport, uniform and lab dues **by phone**, and
must trust that the librarian typed the student code correctly a year ago, or the
one non-fee block silently does nothing.

**Then the manual tail.** Issuing the TC flips `students.status = 'transferred'`
and writes an issuance row. Nothing else. The office must now, from memory:

delete the transport allocation · **telephone the bus driver and the transport
in-charge** (no code path exists) · edit `sections.strength` by hand · check the
child out of the hostel *and* fix `room.occupiedBeds`, which is incremented on
assign and **never decremented** · close the library membership, for which **no
endpoint exists** · reconcile outstanding uniform/textbook issues · unlink
guardians one at a time, which is impossible for the last one
(`LastGuardianError`) · flip `sis_student_enrollments.is_current = false` or the
class's attendance stays hard-blocked (§1) · cancel the finance assignment and
close the account, or late fees keep accruing and the child stays on the
defaulter list.

**And the parent's access is not revoked.** `auth_context.ts:268-274` selects
`students(id, display_name, status)` and never filters on it, so `childIds`
still includes a transferred child. The *student* loses access; the *parent* does
not.

**Two more things the office will hit.** The certificate-desk path produces
**no PDF at all** — the PDF renders client-side only from the direct SIS path, on
the issuing staff member's device. And issuing a **fee certificate** raises a
Postgres CHECK violation (23514) surfaced as an opaque `INTERNAL_ERROR` 500,
because the request table allows five certificate types and the issues table's
CHECK allows four, with no later `ALTER`.

**Nobody is notified of any of it.** Zero notification calls exist in
`certificate_desk/`, `clearance/` or `sis_certificate_handlers.ts`. The family
learns the TC is ready because they came back to ask.

---

## 6. A complaint

A parent reports at the gate that a bus seat belt is broken. The office clerk
opens Complaints and logs it: category `transport`, severity `high`.

**What works.** The SLA is a real, deterministic policy table — one exported
`SLA_POLICY_HOURS` map keyed on (category, severity), total over the DB's own
CHECK domain, with `sla_due_at` computed at raise time
(`_shared/complaints/complaints_sla.ts:42-51`). `transport/high` = **8 hours**.
`safety/critical` = **1 hour**. Assignment requires `manageComplaints`, not just
`raiseComplaint`. This is the correct shape and the file says so.

**What happens next: nothing.** Grepping `_shared/complaints/` for
`enqueueNotificationRequested`, `processDeliveryQueue`, `scheduleReminder`,
`sendSms` or `notification_service` returns **zero hits** — compare
`gate_pass/gate_pass_repository.ts:21,479-489` and
`student_health/student_health_operations.ts:21,174`, which do notify. So:

- the transport in-charge is not told a complaint was filed against their fleet;
- the assignee is not told they were assigned;
- **the 8-hour SLA cannot breach into anyone's awareness** — on-track/breached is
  derived at *read* time, and there is no sweep, no cron, no digest, no alert;
- the parent who reported it is never told it was resolved.

A one-hour safety SLA that only exists if somebody opens the complaints screen
inside that hour is not an SLA. **`SIM-003` (P1)** — and it is the sharpest
example in the product of the XMOD pattern: correct policy, correct storage,
no delivery.

---

## 7. Parent communication

**The broadcast path is the one genuinely industrialised comms lane.** Audience
segments, templates, a channel policy, scheduling, a delivery console with
metrics, per-broadcast reports, resend, an HMAC-authed delivery-status webhook,
escalation on terminal failure, and a 5-minute cron that dispatches due
broadcasts and drains the org's queue. When it is switched on, it works.

**Everything else that should reach a parent does not go through it.**

| Event | Reaches the parent? |
|---|---|
| Child marked absent | enqueued, English-only, no child name, no date |
| Child marked **late / half-day / excused** | **no** |
| Attendance correction approved | **no** |
| Fee payment received | SMS only, off by default |
| Fee due / overdue reminder | **no** — the settings page has no consumers |
| Exam results published | SMS only, off by default |
| Certificate ready | **no** |
| Complaint resolved | **no** |
| Substitute teacher today | **no** |
| Bus running late | **yes** — a real automatic fan-out to guardians |
| Gate pass approved | **yes** — OTP + QR, enqueued and drained immediately |
| Infirmary incident | **yes** |

Three of eleven. And the three that work are the three that call
`enqueueNotificationRequested` directly on their own write path — which is the
whole architecture in one line: there is no fabric, so a module either remembered
to send, or the parent is not told.

**The five-language promise.** `parent_comms_localization.ts` exists with a
5-language `attendance_absence` template and has **zero callers**; the only route
to it, `enqueueFromTemplate`, is reached solely by the WhatsApp bridge. A school
that turns on a regional language will still send English.

---

## 8. A timetable change

Period 3, Class 8-A: the science teacher has called in sick at 07:40.

1. Nobody in the product knows she is away (§2, item 1).
2. Only the principal, VP or school admin can open the substitute manager
   (`manageAcademicTimetable`). The academic coordinator — the person whose job
   this is — has no client role.
3. The wizard's "teachers on leave" list is structurally empty, so the VP works
   from the staffroom whiteboard and assigns manually, period by period.
4. `assignSubstitute` returns `timetableUpdated: true` as a **literal**, and
   `notifiedAudience` as an echo of the VP's own checkboxes
   (`school_completion/timetable_workforce_service.ts:336-347`). The screen confirms
   *"Substitute assigned and timetable updated."*
5. The substitute is not told. The class is not told. The parents are not told.
   The teacher's own timetable screen is not updated by any notification.
6. The VP walks to the staffroom.

The product's confirmation message is the most misleading string traced in this
workstream, because it is not a bug in a rare path — it is what the screen says
every single time. **`SIM-004` (P1).**

---

## 9. The payroll cycle

**Month end.**

1. **Someone must remember to run it.** `POST /hr/payroll/run/generate` has no
   scheduler. Payroll is a button.
2. **Loss of pay is computed from a store that has no writer.** The absence-based
   LOP term reads `snapshot_attendance` (`hr/hr_write_handlers.ts:1352-1356`), and
   `snapshot_attendance` has **zero writers anywhere in `supabase/functions/**`**.
   That term is permanently zero. Production staff attendance lives in the
   GPS/face ledger `staff_check_ins`, which payroll never reads.
3. **Leave-based LOP works, but only for one of the two leave stores.** The
   deduction (`lopDays × basic / payableDays`, `:1467-1470`) reads only
   `snapshot_leave`, so **leave applied through the teacher app never affects
   pay** — and that is the store every teacher actually uses.
4. **And only for exactly-spelled types.** Only `unpaid`, `lop`, `loss_of_pay`,
   `leave_without_pay`, `lwp` count (`:1309-1315`). An HR clerk who types
   "Unpaid Leave" as a free-text type deducts ₹0, silently.
5. **Leave accrual cannot be run from the app at all.** The engine is built and
   tested server-side (`hr/leave_accrual.ts`, `leave_accrual_handlers.ts`,
   `leave_accrual_test.ts`) and has **zero Dart callers**; `hr_api_paths.dart:38`
   binds only the plain `/hr/leave/balances`. Balances shown to staff are
   therefore never accrued by the engine that was written to accrue them.

**The human consequence.** Payroll runs, produces payslips, and is *arithmetically
correct for the inputs it reads* — while two of its three loss-of-pay inputs are
structurally empty and the third depends on someone typing one of five exact
strings. A school will pay full salary for unpaid leave and never see an error.
Nothing reconciles payroll against the attendance ledger that actually exists.

---

## 10. What breaks first on a busy morning — ranked

1. **A class cannot submit attendance at all**, because a student was transferred
   yesterday and the two rosters disagree (XMOD chain 6, hop 7). No workaround in
   the UI. Highest-impact, silent, and it recurs on every exit.
2. **The notification queue is not draining**, because one env var was never set
   on the edge container, and nothing monitors it (§0). Every parent-facing alert
   in the school stops at once.
3. **Nobody knows a teacher is absent** until a class is unsupervised, because the
   substitution engine's input is a permanently-null column (§2).
4. **The office does not know which classes are unmarked**, because the pending
   feed is a card on a dashboard and no reminder exists (§1).
5. **A parent is shown fabricated money** — the exact day-one state (no fee
   structure assigned) is the state that triggers CERT-001 and JOURNEY-007.
6. **A safety complaint sits past its one-hour SLA** because nothing announces it
   (§6).

Note the shape: items 1, 3 and 4 are not "a feature is missing" — they are
*the school believing an action completed when it did not*. That is the class of
failure a school cannot self-correct, because there is no signal to correct from.

## 11. The office's memory list — 12 things nobody prompts

XMOD catalogued 31 manual steps. These are the ones with **no signal at all** —
nothing in the UI ever indicates the step is outstanding, so they are pure human
memory:

| # | Must remember | Silent failure if forgotten |
|---|---|---|
| 1 | Press "Raise demand" after every bus allocation | student rides free, forever, with zero dues |
| 2 | Assign the fee structure in Finance after every admission | the child owes nothing and appears on no defaulter list |
| 3 | Turn on `receipts.receipt_sequencing` per school | receipts are randomly numbered in the audit book |
| 4 | Set `TRANSACTIONAL_SMS_ENABLED` + a provider | no parent is ever told a payment landed |
| 5 | Set `INTERNAL_CRON_TOKEN` on the edge container | **every** notification stops; nothing alerts |
| 6 | Flip `is_current = false` when a student leaves | that class's attendance is hard-blocked |
| 7 | Fix `room.occupiedBeds` after a hostel checkout | the bed is permanently consumed |
| 8 | Phone the bus driver when a student leaves | the driver waits at the stop |
| 9 | Mark an on-leave employee's attendance | the muster prints `A`; payroll may deduct |
| 10 | Type the leave type as exactly `unpaid`/`lop`/… | LOP silently computes ₹0 |
| 11 | Pull report cards per class after publish | families receive nothing |
| 12 | Ignore the Payment Reminders settings page | it looks configured and does nothing |

Items 3, 4, 5 and 12 are **configuration that presents as done**. That is a
distinct and worse category than a missing feature: the school has been given a
switch, has flipped it, and believes the behaviour exists.

## 12. Verification boundaries

- **Static trace only.** No live tenant, no Postgres lane, no SSH (owner-bound).
  Whether the COM-4 cron is authenticated on the pilot VPS, whether
  `TRANSACTIONAL_SMS_ENABLED` is set, and whether any school has populated
  `library_entities.payload->>'sisStudentId'` correctly are **data/ops questions
  this harness cannot answer**. Every §0 claim rests on the installer script, the
  auth module and the watchdog script as committed.
- **Runtime config is not in the repo.** Defaults were read from
  `_shared/config.ts` and `payment/razorpay_config.ts`.
- **No release binary was run**, so tap counts and screen sequences are derived
  from the widget tree, not measured.
- **Not re-derived here:** the dead event bus, the 9-vs-3 scheduler gap and the
  31-step manual list are XMOD's findings, cited and built on, not re-proved.
- **Deliberately not simulated:** admissions intake, procurement, hostel mess and
  library day-to-day beyond the TC path — out of the nine sequences requested.

## 13. Defects raised by this workstream

`SIM-001` (P1) · `SIM-002` (P1) · `SIM-003` (P1) · `SIM-004` (P1)

Every other failure described above is already registered — by XMOD
(XMOD-001…039), by Workstream 2 (CERT-001…006) or by Workstream 3
(JOURNEY-001…016). This workstream deliberately raised **only** what was not
already recorded; its value is the human account of the rest, not a second copy
of it.
