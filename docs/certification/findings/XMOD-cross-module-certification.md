# XMOD — Cross-Module Synchronisation Certification

**Workstream:** 4 (Cross-module synchronisation) · **Date:** 2026-07-29
**Repo:** `/Users/surendrakanna/Documents/Akshara_ERP-release` · **Branch:** `release/v1.0-playstore`
**Method:** static end-to-end code trace of 6 chains, backend (`supabase/functions/_shared/**`),
migrations (`supabase/migrations/**`), Flutter client (`lib/**`) and ops (`deploy/**`).
Read-only. No code changed.

---

## VERDICT — **NOT CERTIFIED**

NIKSHA OS is, today, **a very well-built bag of independent ERP modules**, not a School
Operating System.

The individual modules are strong: money writes are transactional and idempotent, the
no-dues gate is genuinely fail-closed on the write path, the attendance-percentage formula
is genuinely canonical and shared by eleven surfaces, the exam publish gate is genuinely
enforced on the parent read path. Engineering quality inside a module is high.

What is missing is the **connective tissue**. There is no event fabric, no orchestration
layer, and no scheduler. A module changes its own tables and stops. Every other module
finds out either (a) because it happens to query the same table at read time — which works
by luck of shared schema, not by design — or (b) because **a human remembers to go and do
the other thing**.

Counted below: **31 human steps** that a school must remember, unprompted, or the product
silently produces a wrong outcome. Most of them are invisible — nothing in the UI says
"you still owe the system this action."

The two structural root causes:

1. **The event fabric is dead on arrival.** 368 write sites emit domain events across 171
   event types into a table nothing ever reads (§1).
2. **Nothing is scheduled.** Eight jobs are written as "run this periodically" and exactly
   **zero** are installed as crons (§2). Every one of them is a button a human must press.

---

## 1. The spine: the domain-event outbox is a dead log

| Fact | Evidence |
|---|---|
| Every domain event is inserted **already terminal** | `supabase/functions/_shared/audit/audit_repository.ts:365` — `VALUES (…, 'published', timezone('utc', now()))` |
| The drain only ever selects non-terminal rows | `supabase/functions/_shared/audit/domain_events_worker.ts:41` — `AND status IN ('pending', 'failed')` |
| Therefore the drain's result set is **structurally always empty** | ↑ the two lines above are mutually exclusive |
| The subscriber registry has **zero** production registrations | `registerDomainEventSubscriber` (`audit/domain_event_subscribers.ts:85`) is called only from `audit/domain_events_worker_test.ts:135,166,204,212` |
| The dispatch loop therefore never runs for a real event | `domain_events_worker.ts:73` `await dispatchDomainEvent(...)` is inside the loop over the empty set |
| Nothing schedules the drain anyway | only route is `POST /domain-events/process-pending` (`audit/audit_router.ts:27`), permission-gated `manageCommunications` (`audit/domain_events_handlers.ts:19`). No cron exists — see §2 |
| Scale of the dead write | **368** `emitMutationAudit`/`recordMutationAudit` call sites across the backend; **171** declared event types in `audit/mutation_audit_catalog.ts` |

**Collateral damage — the one real consumer is starved.** `runSignalRefinery`
(`ai/signal_refinery.ts:184-202`) is the AI cache/fact-signal invalidator, and it is
written *correctly*: its own query ignores `status` entirely and walks a per-school
watermark, so it **would** work against the log as written. But its only invocation is
`audit/domain_events_handlers.ts:33` — `for (const schoolId of result.schoolIds)` — and
`schoolIds` is populated only inside the drain's published branch
(`domain_events_worker.ts:86`). Empty drain → empty school list → the refinery never runs.
A correct consumer, wired behind a structurally-empty trigger.

**CONFIRMED — the inherited claim is still true after the RC phase.**

---

## 2. Nothing is scheduled

Installed crons on the VPS — the complete list:

| Cron | File |
|---|---|
| scheduled-broadcast sweep (`/communications/broadcasts/run-scheduled`) | `deploy/akshara-vps/communication-cron/install-communication-cron.sh:36` |
| watchdog | `deploy/akshara-vps/monitoring/install-monitoring.sh:24` |
| nightly backup | `deploy/akshara-vps/backup/install-ops-cron.sh:66` |

Jobs written as periodic work with **no scheduler**:

| Job | Route / entry point |
|---|---|
| Domain-event drain + AI cache invalidation | `POST /domain-events/process-pending` — `audit/audit_router.ts:27` |
| Late-fee accrual | `POST /finance/late-fees/accrue` — `finance/finance_late_fee_handlers.ts:30` |
| Payroll run generation | `POST /hr/payroll/run/generate` — `hr/hr_write_handlers.ts:1568` |
| Leave accrual | `POST /hr/leave/accrual/run` — `hr/hr_router.ts:134` |
| Student-risk recompute | `POST /intelligence/risk/students/compute` — `intelligence/intelligence_handlers.ts:139` |
| Daily-brief pre-warm | `POST /intelligence/briefs/prewarm` — `intelligence/briefs/brief_handlers.ts:95` |
| Notification delivery drain | `POST /communications/notifications/process-queue` — `communication/communication_router.ts:130` |
| Parent academic-summary refresh | `POST /parent/experience/summary/refresh` — `parent_experience/parent_experience_router.ts:48` |
| Transport document-expiry scan | `runDocumentExpiryReminder` — `transport/transport_write_handlers.ts:1566` |

---

## 3. What IS genuinely synchronised (say the good part honestly)

These were traced and found correct — they are the proof that the architecture *can* work:

- **One canonical attendance-%** — `attendance/attendance_percentage.ts:63-107`
  (attended = present + late + 0.5·half_day; denominator = marked − excused; **null**, never
  0, on empty denominator). Imported by 11 production surfaces: office reports, Student 360,
  ops hub, director, management aggregate, dashboard, pilot, both parent services,
  intelligence risk.
- **Money collection is atomic and idempotent** — one transaction taking invoice
  `FOR UPDATE`, writing collection + receipt + invoice + account + head allocation:
  `finance/finance_collections_repository.ts:334-631`; Idempotency-Key replay at `:454,531`.
- **Exam publish gate holds on the parent read path** —
  `academics/exam_administration/exam_administration_repository.ts:1038` (`AND m.published = true`).
- **Exam publish is genuinely automatic on principal approval** — `POST /approvals/{id}/approve`
  → `approval/approval_handlers.ts:158` → `approval/approval_orchestrator.ts:37` →
  `approval/approval_type_handlers.ts:66-79` → `publishExamResults`, in one transaction
  (`tenant_db.ts:123-131`).
- **TC no-dues gate is fail-closed on the write path**, not a report —
  `sis/sis_certificates_repository.ts:553-559` throws before serial allocation;
  `clearance/clearance_engine.ts:173-177` fails closed on an unreadable source.
- **TC serial numbers are gapless and server-side** — `sis/sis_certificates_repository.ts:341-363`.
- **Headcount / enrolment KPIs are live counts**, not stale counters —
  `sis/sis_dashboard_repository.ts:101`, `dashboard/dashboard_service.ts:91`.
- **Transport delay → guardians** is a real automatic fan-out —
  `transport/transport_write_handlers.ts:700-720`.
- **Parent fee + attendance + results reads recompute live** from the real tables, overlaying
  any stale seed snapshot — `entity_read/mobile_read_handlers.ts:104-217`,
  `pilot/pilot_snapshot_repository.ts:466-515`.

The pattern: **within-module and read-time coupling is good; write-time cross-module
propagation is absent.**

---

## CHAIN 1 — Attendance → Parent → Reports → Dashboard → Notifications → Brief → Analytics

The real write path is **not** `attendance/attendance_handlers.ts` (that module owns only
session/register reads and the corrections workflow). It is the teacher/pilot lane.

| # | Hop | Verdict | Evidence |
|---|---|---|---|
| 1 | Teacher marks → DB | **AUTOMATIC** (server) | `pilot/pilot_operations_handlers.ts:202` → `pilot/pilot_attendance_repository.ts:197,282,303` — sessions + records in one tx |
| 1b | Client submit while offline | **PARTIAL** | `lib/core/reliability/policy/operation_policy_registry.dart:41` (queueable); drains on app start/resume/online — `lib/core/reliability/sync/sync_engine.dart:50,66,81` |
| 1c | Approved student leave auto-excuses the mark | **DEAD** | wired at `pilot/pilot_attendance_repository.ts:223`, but its input `approvedLeaveStudentIdsForToday` (`:67-82`) requires `from_date IS NOT NULL` — see XMOD-002 |
| 2 | Parent visibility | **AUTOMATIC** | `entity_read/mobile_read_handlers.ts:217` → `pilot/pilot_attendance_repository.ts:330-339` (live join, `status='submitted'`) |
| 3a | Office reports / Student 360 / ops hub / director | **AUTOMATIC** | all inline `attendancePercentSql()` — `attendance/attendance_office_repository.ts:442`, `sis/student_360_service.ts:108`, `operations/operations_hub_service.ts:142`, `director/director_repository.ts:153` |
| 3b | Parent academic summary + printable report | **MANUAL** | `parent_experience/parent_experience_router.ts:80-90` — `if (existing) return existing`; the GET never recomputes. Refresh at `:48` has **zero** non-test callers |
| 4 | Admin dashboard attendance KPI | **AUTOMATIC** | `dashboard/dashboard_service.ts:71-86` — live, uncached |
| 5a | Parent absence notification — enqueue | **AUTOMATIC** | `pilot/pilot_operations_handlers.ts:245-263` → `communication/notification_service.ts:218` (**refutes the inherited "no caller" claim**) |
| 5b | …in-app inbox visibility | **AUTOMATIC** | inbox selects `status IN ('sent','pending')` — `communication/communication_repository.ts:327-331` |
| 5c | …actual push send | **PARTIAL / MANUAL** | attendance never drains the queue; the pending row ships only when unrelated traffic drains that org (`transport/transport_write_handlers.ts:720`, `gate_pass/gate_pass_repository.ts:489`, `teacher/teacher_parent_communication_handlers.ts:134`) or an admin calls `/communications/notifications/process-queue` |
| 5d | 5-language absence template | **DEAD — no caller (CONFIRMED)** | template `communication/parent_comms_localization.ts:69-105`; the attendance path hardcodes English at `pilot/pilot_operations_handlers.ts:258-260` and passes no `templateCode`; localization is reachable only via `enqueueFromTemplate` (`notification_service.ts:57-68`), whose only caller is the WhatsApp bridge |
| 6 | Morning / Daily Brief | **PARTIAL server, DEAD end-to-end** | T1 sections computed live per request (`intelligence/briefs/brief_service.ts:176`); attendance included for teachers (`intelligence/priority/teacher_sources.ts:74-90`). **No client calls `/intelligence/briefs/*`**; Flutter's own composer `lib/core/dai/dai_brief.dart:22-30` has zero callers; no pre-warm cron |
| 7 | Analytics | **AUTOMATIC on read** | `analytics/analytics_metrics_service.ts:24-31` — live per request |
| 8 | Student-risk list feeding dashboards/briefs | **MANUAL** | read `intelligence/intelligence_handlers.ts:92`; compute only via `POST …/compute` at `:139` |
| 9 | AI narrative cache freshness | **NEVER** | §1 |

**Divergences found:** `analytics/analytics_metrics_service.ts:26-31` computes
`absentRate = absent/total` — excused and half-day sit in the denominator, late counts as
neither — and this feeds `attendanceRiskScore` → intelligence hub → principal brief.
`parent_experience/parent_experience_service.ts:53` uses `canonicalPct ?? 100`, optimistically
treating "no data" as perfect attendance.

**Honest-state break:** the canonical formula returns **null** for "no data"
(`attendance_percentage.ts:24-26`: "Callers display this as —/no data, not as 0%"). Two
client mappers convert it to **0%**: `lib/core/repositories/api/parent/mapper/parent_mapper.dart:394`
and `lib/core/repositories/api/phase5/phase5_mapper.dart:150`.

**Notification coverage:** only `mark === 'absent'` notifies
(`pilot/pilot_operations_handlers.ts:245`). Late, half-day, auto-excused, and every later
**attendance correction approval** notify nobody. And the body a parent receives is
`"Student marked absent for class {class_id}"` — no child name, no date.

---

## CHAIN 2 — Leave → Attendance → Payroll → Timetable → Substitute → Reports

**This is the worst chain in the product.**

| # | Hop | Verdict | Evidence |
|---|---|---|---|
| 1 | Leave filed | **PARTIAL — two disjoint stores** | HR staff leave → JSONB `snapshot_leave.requests[]` (`hr/hr_write_handlers.ts:443,462-469`); teacher/parent app leave → table `mobile_leave_requests` (`pilot/pilot_leave_repository.ts:39-59`). Nothing bridges them |
| 2 | Approval | **AUTOMATIC but status-only** | HR: one snapshot mutate flipping `status`/`decisionComment`/`pendingCount` + one audit row, then return — `hr/hr_write_handlers.ts:738-783`. Approval Center: `UPDATE mobile_leave_requests SET status, updated_at` — `approval/leave_decision_effect.ts:36-42`, else snapshot flip `:47-64`. **The inherited claim is CONFIRMED: status flip + audit, zero downstream writes** |
| 3 | Approved leave → staff attendance record | **MANUAL / non-existent** | No POST `/hr/attendance` route exists; `snapshot_attendance` has **zero writers** anywhere in `supabase/functions/**`. Production staff attendance is the GPS/face ledger `staff_check_ins`, and no `on_leave` status exists |
| 3b | …so how does an on-leave teacher appear? | **AS ABSENT** | `hr/hr_reports_repository.ts:279-284` — "a working day with NO check_in → Absent ('A')". `'L'` in that report means **Late** (`:281,351`), not Leave. The muster handler never loads `snapshot_leave` (`hr/hr_reports_handlers.ts:134-139`) |
| 4 | Payroll LOP | **PARTIAL** | Automatic for unpaid types — `hr/hr_write_handlers.ts:1467-1470` deducts `lopDays × basic/payableDays`, nobody types it. But: only `unpaid/lop/loss_of_pay/leave_without_pay/lwp` count (`:1309-1315`); the absence-based term reads `snapshot_attendance` (`:1352-1356`) which has no writer → permanently 0; and it reads only `snapshot_leave`, so **teacher-app leave never affects pay** |
| 5 | Timetable "teacher unavailable" | **PARTIAL** | No flag is ever persisted on periods. Derived at read time by `listTeachersOnLeave()` — `timetable/substitution_repository.ts:322-353` |
| 6 | Substitute allocation | **MANUAL, and its input is structurally empty** | see below |
| 7 | Reports | **PARTIAL and self-contradictory** | `onLeaveToday` KPI is automatic from `snapshot_leave` (`hr/hr_read_repository.ts:203-208`); the muster shows the same person as Absent (hop 3b). Nothing reconciles them; `mobile_leave_requests` leave appears in **no** HR report |

### The permanently-NULL column — CONFIRMED and worse than reported

`listTeachersOnLeave` queries `mobile_leave_requests` with
`AND from_date IS NOT NULL AND to_date IS NOT NULL AND from_date <= $3 AND to_date >= $3`
(`timetable/substitution_repository.ts:339-344`).

- Column added **nullable, no default, no backfill** —
  `supabase/migrations/20260830000000_attendance_half_day_and_leave_dates.sql:21-26`.
- Only writer: `pilot/pilot_leave_repository.ts:57-58` (`input.fromDate ?? null`).
- Its two callers pass `optionalIsoDate(body,"from_date")` —
  `pilot/pilot_operations_handlers.ts:307-308` (teacher), `:349-350` (parent).
- **No client ever sends `from_date`.** Teacher DTO sends `type_label / from_date_label /
  to_date_label / reason` only (`lib/core/repositories/api/teacher/dto/teacher_write_request_dto.dart:128-133`);
  parent DTO the same plus `child_id / type / has_attachment`
  (`lib/core/repositories/api/parent/dto/parent_leave_submit_request_dto.dart:9-17`). The
  teacher form's "From date" is a free-text `TextField`, not a date picker
  (`lib/features/teacher/leave/teacher_leave_screen.dart:206-214`).
- The approval path does not backfill it either (`approval/leave_decision_effect.ts:37-42`).
- The only places the column is ever given a value are unit-test fixtures
  (`timetable/substitution_repository_test.ts:455,466,477,488`).

**One nullable column silently disables two separate product features:**

1. `listTeachersOnLeave()` always returns `[]` → `getSubstituteCoverage` short-circuits
   (`timetable/timetable_workforce_service.ts:232`) → `GET /timetable/substitutions?date=`
   returns an empty `onLeave` → the substitution banner
   (`lib/features/academics/timetable/substitutions/daily_substitutions_screen.dart:127-142`)
   never lists anyone.
2. `approvedLeaveStudentIdsForToday()` always returns an empty set → the ATT-D3 auto-excuse
   at `pilot/pilot_attendance_repository.ts:223` never fires → **an approved student leave
   still counts against the child's attendance percentage.**

And even if the column were populated, HR-module staff leave would remain invisible, because
the substitution engine queries `mobile_leave_requests` while HR writes `snapshot_leave`.

**Also:** `assignSubstitute` returns `notifiedAudience` by echoing the caller's own three
booleans and the literal string `"Substitute assigned and timetable updated."`
(`timetable/timetable_workforce_service.ts:336-347`). No notification call exists in that
function. `timetableUpdated: true` is a literal.

---

## CHAIN 3 — Fees → Ledger → Parent view → Receipts → Dashboard

| # | Hop | Verdict | Evidence |
|---|---|---|---|
| 1a | Enrolment → finance handoff row | **AUTOMATIC** | `admissions/admissions_repository.ts:1420` → `admissions_handoffs_repository.ts:94-102` — a worklist row, no money |
| 1b | Handoff → "sent to finance" with a plan | **MANUAL** | `admissions/admissions_handlers.ts:1736` — a human supplies `feeStructureId` |
| 1c | Assign structure → assignment + account + invoice + installments | **MANUAL trigger, automatic downstream** | `finance/finance_assignments_repository.ts:242,334,375,391` → `finance_invoices_repository.ts:116,136`. **Nothing fires on admission or class assignment** |
| 2 | Transport allocation → transport fee demand | **MANUAL — the broken hop** | `POST /transport/allocations` (`transport/transport_write_handlers.ts:321-433`) writes allocation + history + audit and returns 201; it **never** calls `raiseTransportDemandFor`. The code concedes it at `:1855-1858`. A human must open Transport Settings and press "Raise demand" (`lib/features/transport/transport_workflow_actions.dart:647,834`) |
| 2b | Once raised → invoice | **AUTOMATIC** | `transport/transport_write_handlers.ts:1796` → `assignFeeStructure`; idempotent per `(student,route,year,term)` at `:1780-1786` |
| 3 | Counter collection → invoice + account + heads + receipt | **AUTOMATIC, atomic** | `finance/finance_collections_repository.ts:334-631` |
| 3b | "Finance ledger" | **Does not exist** | `finance/finance_ledger_repository.ts:8-10` — "Read-only aggregation over existing tables… Nothing here writes." No double-entry table; money state is the denormalized `finance_student_accounts` + invoices + collections |
| 4 | Parent outstanding-dues view | **AUTOMATIC (live)** | `pilot/pilot_snapshot_repository.ts:466-515` — overwrites any stale snapshot with live invoice rows |
| 5 | Receipt row + number | **AUTOMATIC**; gapless only behind a flag | `finance/finance_collections_repository.ts:575`, `:273-302`. `receipts.receipt_sequencing` **defaults `"false"`** (`finance/finance_settings_repository.ts:49`) → legacy random `RCPT-{year}-{hex}` |
| 5b | Parent receives the receipt | **AUTOMATIC** | `pilot/pilot_snapshot_repository.ts:541` reads real `finance_receipts` |
| 5c | Parent is *told* a payment landed | **OFF by default** | `finance/finance_collections_handlers.ts:77-111` — SMS only, post-commit, errors swallowed; early-returns unless `TRANSACTIONAL_SMS_ENABLED=true` (**defaults false**, `config.ts:127`). No push, no in-app, no email |
| 6 | Dashboard collection KPI | **AUTOMATIC (live, uncached)** | `finance/finance_dashboard_repository.ts:47,52`; `finance/finance_collections_repository.ts:1016-1041` |
| 7 | Late-fee accrual | **MANUAL** | `POST /finance/late-fees/accrue` — `finance/finance_late_fee_handlers.ts:30`; no scheduler |
| 8 | Razorpay online payment | **STUBBED** | `payment/razorpay_config.ts:15-16` (`RAZORPAY_STUB_MODE` defaults `"true"`), webhook refuses to post in stub mode (`payment/payment_handlers.ts:222-228`). No gateway SDK in `pubspec.yaml`; the parent screen says so honestly (`lib/features/parent/payment/parent_payment_screen.dart:113-122`) |
| 8b | Webhook → books, if creds existed | **AUTOMATIC** | `payment/payment_service.ts:381,416-438` reuses `createCollection`; capture race guarded `FOR UPDATE` at `:292-302` |

### "Outstanding dues" is not one number — five divergent bases

1. Stored column `finance_student_accounts.outstanding_amount`, `status='open'` —
   **the no-dues/TC gate** (`clearance/clearance_contributors.ts:31`), recovery/dunning
   (`finance/finance_recovery_repository.ts:183,494`), risk (`intelligence/student_risk_repository.ts:143`).
2. `SUM(finance_invoices.outstanding_amount)` WHERE status `IN ('issued','partially_paid')` —
   dashboard total outstanding (`finance/finance_collections_repository.ts:1054`).
3. …WHERE status `NOT IN ('cancelled','draft')`, **`LIMIT 12`, no academic-year filter** —
   **the parent app** (`pilot/pilot_snapshot_repository.ts:472-477`).
4. …WHERE status `NOT IN ('paid','cancelled')`, cast `::int` — Student 360
   (`sis/student_360_service.ts:159-166`) — truncates paise on a `NUMERIC(12,2)` column
   (`supabase/migrations/20260612400000_finance_slice3_invoices.sql:17`).
5. …WHERE status `<> 'cancelled'` (monthly) — `finance/finance_reports_repository.ts:38`,
   `director/director_repository.ts:288`.

The stored column is kept aligned only by hand-written compensation at each write site —
`finance/finance_invoices_repository.ts:286-311` says it outright: "STORED aggregates …
nothing re-derives them". There is no reconciliation job and no canonical function, so the
number the parent sees and the number the TC gate enforces can legitimately disagree.

### Finance settings that no code honours

`FINANCE_SETTINGS_TEMPLATE` (`finance/finance_settings_repository.ts:33`) is rendered as an
editable, described settings screen (`lib/features/finance/settings/finance_settings_screen.dart:115-137`,
routed at `lib/router/finance_navigation.dart:135`). Five entries have **zero consumers**
anywhere in `supabase/**` or `lib/**`:

| Setting | Promise made to the school |
|---|---|
| `reminders.due_reminder_days` (`:75`) | "Days before the due date to send a payment reminder." |
| `reminders.overdue_reminder` (`:82`) | "Automatically remind guardians of overdue fees." |
| `receipts.auto_receipt_sms` (`:62`) | "Notify guardians by SMS when a payment is received." |
| `payments.allow_partial` (`:95`) | "Permit collecting less than the full outstanding amount." |
| `receipts.invoice_prefix` (`:55`) | "Prefix used on generated invoices." |

(Consumed correctly: `payments.due_days`, `installment_terms`, `head_allocation_priority`,
`midyear_admission_proration_policy`, `late_fee_percent/flat/cap`, `grace_days`,
`receipts.receipt_prefix/receipt_sequencing`.)

Related: the shared XCT-2 reminder rail documents eight module consumers including "the
Finance fee-reminder ladder (T-3 / T0 / T+7)" (`reminders/reminders_service.ts:10-20`).
Actual callers of `scheduleReminder`: **four** — exam administration, transport, library,
inventory-finance. Finance is not among them.

---

## CHAIN 4 — Exams → Marks → Report cards → Analytics → Parent

| # | Hop | Verdict | Evidence |
|---|---|---|---|
| 1 | Exam created | **MANUAL** | `academics/exam_administration/exam_administration_repository.ts:384` — inserts `'draft'` |
| 2 | Scheduled → mark slots provisioned | **AUTOMATIC** (inside the manual schedule call) | `…_repository.ts:501` → `provisionMarkSlots:408-459`. ⚠ inserts `marks_obtained = 0` (`:434`), **not NULL** |
| 3 | Marks entered | **MANUAL; computes nothing** | `…_repository.ts:637-646` writes only `marks_obtained, marks_entered, status`. No total, grade, rank or percent. The only trigger on the table is `row_version` (`supabase/migrations/20260817000000_reliability_row_version_conflict.sql:27`) |
| 4 | "Process results" | **MANUAL — a gate, not a computation** | `…_repository.ts:832-862` counts un-entered marks then flips phase |
| 5 | Coordinator verify → submit → principal approve | **MANUAL** (3 human steps) | `…_repository.ts:864-889`; SoD enforced at `approval/approval_repository.ts:375-385` |
| 6 | Approval → **publish** | **AUTOMATIC** ✅ | `POST /approvals/{id}/approve` → `approval/approval_handlers.ts:158` → `approval/approval_orchestrator.ts:37` → `approval/approval_type_handlers.ts:66-79` → `publishExamResults`. Same transaction (`tenant_db.ts:123-131`) |
| 6b | Publish bakes effective marks + grades | **AUTOMATIC** | `…_repository.ts:939-978` resolves the school grade scale once and writes `effective_marks` + `grade_letter` |
| 7 | Report card (staff) | **MANUAL pull, live compute** | `GET /academics/exams/class/{class}/report-cards?term=` — `…_repository.ts:2256-2396`; nothing is generated or stored at publish |
| 8 | Report card (parent/student) | **AUTOMATIC on read** | `lib/features/parent/exams/report_card_provider.dart:16-37` → `lib/core/exams/exam_report_card.dart:144-186` |
| 9 | Analytics | **AUTOMATIC but a separate live query** | `intelligence/exam_intelligence_service.ts:98,123,144`; `analytics/analytics_metrics_service.ts:36`; `management/management_aggregate_repository.ts:188`; `director/director_repository.ts:166`. Publishing does not feed them; they re-read `exam_mark_entries` |
| 10 | Parent visibility of results | **AUTOMATIC, correctly gated** | `…_repository.ts:1038` — `AND m.published = true` |
| 11 | Parent notified results are out | **AUTOMATIC but usually a no-op** | `…_handlers.ts:918` → `:261-290` — SMS only, swallowed, requires `transactionalSmsEnabled` + provider. No push, no in-app |

> **Correction to an earlier draft finding:** it was reported that no client path reaches
> `publish` on the default build (`EXAM_APPROVAL_REQUIRED=true` hides the direct-publish
> button at `lib/features/academics/exam_admin/exam_marks_entry_screen.dart:563`, and
> `ApprovalAdapterRegistry.dispatchApproved` early-returns on `skipDomainEffects`
> at `lib/core/approvals/adapters/approval_adapter_registry.dart:35`). That is all true, and
> it is **correct by design** — the client does not need to publish, because the server
> publishes inside the approval decision. **The chain works. Not a defect.**

### Parent leak of unpublished marks — the publish gate is bypassed elsewhere

`GET /parent/experience/hub` (parent-scoped, `validation/rbac_route_inventory.ts:248`) reads
raw marks with **no `published` filter and no status filter**, in two places:

- `parent/parent_experience_service.ts:118-131` → `weakMarks` → surfaced as
  `homeworkIntelligence.weakTopics` (`:209`), e.g. `"Maths Unit Test (38%)"`.
- `sis/student_360_service.ts:117-125` → per-exam `avg_pct` → surfaced to the parent as
  `academics.recentExams` (`parent_experience_service.ts:176-179`); `viewMode:"parent"` does
  not redact it.

Compounded by hop 2: a merely *scheduled* exam has `marks_obtained = 0`, so it reads as
**0%** and lands in the parent's "weak topics" before anyone has marked a paper.

### Absent / medical / debarred — correct in 3 places, violated in 5

Correct (present-only totals, non-present never shifts a rank): tabulation
`…_repository.ts:1436-1505`; backend report card `…_repository.ts:2340-2394`; Flutter *admin*
report card `lib/core/exams/exam_report_card.dart:222-227` (`countsTowardStats`).

Violated:
1. **`lib/core/exams/exam_report_card.dart:166-168`** — the **parent/student** report card sums
   all lines with no `countsTowardStats` filter; an absent subject arrives as
   `scoreObtained: 0` (`pilot/pilot_snapshot_repository.ts:860` drops the status code) and
   still contributes its `maxScore`, depressing the child's overall percent and grade.
2. `management/management_aggregate_repository.ts:182,191,213,222` — `COUNT(*)` denominator
   includes AB/ML/DB → pass rate under-reported.
3. `director/director_repository.ts:164-166`, `:760-765` — no `published`, no status filter.
4. `intelligence/exam_intelligence_service.ts:96-101` — `total_marks = count(*)`.
5. `analytics/analytics_metrics_service.ts:33-38` — counts unentered zeros as failures.

### Grading is not one function

Backend `gradeForPercent` (`…_repository.ts:216-224`) over `exam_grade_scales` is shared
correctly by publish, backend report card and the published-results read. Flutter carries a
**second** implementation (`lib/core/exams/exam_grading.dart:37-42`), and inside Flutter the
scale lookup forks: admin paths use `store.reportSettings.gradingScale`
(`exam_report_card.dart:227`), while the **parent/student** card hardcodes
`ExamGradingScale.standard` (`exam_report_card.dart:179`). The `stateBoardSsc` preset
(`exam_grading.dart:95-107`) is referenced only by its own declaration and the presets list —
no screen selects it, and nothing PUTs `/academics/exams/grade-scale`.

---

## CHAIN 5 — Certificate issuance → clearance gate → student record

| # | Hop | Verdict | Evidence |
|---|---|---|---|
| 1 | Request raised | **AUTOMATIC** backend / **staff-only** client | `certificate_desk/certificate_desk_handlers.ts:130-241` inserts the request (`:207`), auto-submits an F2 approval (`:216`), links it (`:227`). Parent scope is allowed server-side (`:167-182`) but **no parent/student screen exists** — the only surface is inside the admin shell (`lib/router/app_router.dart:1560`) |
| 2 | Approval decision | **MANUAL** | `approval/approval_permissions.ts:12`; nothing auto-approves |
| 3 | No-dues gate | **AUTOMATIC, fail-closed, on the write path** | `sis/sis_certificates_repository.ts:541-559` throws `NoDuesPendingError` **before** serial allocation (`:583`); mapped to `409 DUES_PENDING` at `sis/sis_certificate_handlers.ts:225-229`. Bypass closed: `issueCertificate` rejects `transfer` (`:454-458`); raw status writes re-enforce (`sis/sis_students_repository.ts:743-755`) |
| 4 | Serial + issuance ledger row | **AUTOMATIC** | `sis/sis_certificates_repository.ts:341-363` (gapless, row-locked) then `insertIssue:408-427` |
| 5 | Student record → `transferred` | **AUTOMATIC (status only)** | `sis/sis_certificates_repository.ts:647-661`, guarded `AND status=$5`, 0 rows → rollback. **No exit-date column exists** anywhere in `supabase/migrations/` |
| 6 | Enrolment closed / roster / transport / hostel | **MANUAL** | The TC engine never touches `sis_student_enrollments.is_current` (whole fn `:520-682`) |
| 7 | Parent/student receives the certificate | **MANUAL (physical hand-over)** | Zero notification calls in `certificate_desk/`, `clearance/`, `sis/sis_certificate_handlers.ts`. PDF renders client-side on the issuing staff device (`lib/features/sis/certificates/sis_certificate_pdf_service.dart:15-47`) and **only** from the direct SIS path — the certificate-desk path returns `issueId`/`serialNo` with no PDF surface at all |

### What "no dues" actually means

| Source of dues | In the TC gate? |
|---|---|
| **Fees** | ✅ queried, **blocking** — `clearance/clearance_contributors.ts:26-49` |
| **Library** | ⚠ blocking, but **only inside the TC engine** (`sis/sis_certificates_repository.ts:299-331`, called at `:547`) — and keyed on `payload->>'sisStudentId'`, a free-text field a librarian types with no FK (`library/library_write_handlers.ts:207`). In the clearance registry it is `tracked:false` (`clearance/clearance_contributors.ts:108-114`) |
| **Inventory / uniform / textbooks** | ❌ advisory only for a TC (`clearance/clearance_engine.ts:99`) and **not even executed** at the gate (`clearance/clearance_gate.ts:39`) |
| **Hostel** | ❌ never queried, `tracked:false` (`clearance/clearance_contributors.ts:119-125`) |
| **Transport** | ❌ **no contributor exists** — absent from `DEFAULT_CLEARANCE_REGISTRY` (`:129-134`) |
| **Lab / other** | ❌ none |

**The certificate text itself is honest** — `TC_FINANCE_CLEARANCE_STATEMENT`
(`sis/sis_certificates_repository.ts:56-57`) asserts only *"All financial dues have been
cleared"*, not "all dues". That narrowly avoids a printed false claim. The *product* claim
("no-dues gate") is still much broader than the implementation.

Three further inconsistencies:
- The read-only clearance **report** (`clearance/clearance_handlers.ts:60-72`) never calls
  `libraryDuesForStudent`, so it can show a student as cleared while the TC gate blocks on an
  unreturned book.
- A library-blocked TC decided through the certificate desk returns an opaque **500**, not
  `blocked_dues` — the pre-flight checks finance only
  (`certificate_desk/certificate_desk_approval_effect.ts:117-123`) and `mapApprovalError`
  has no branch for the library throw (`approval/approval_handlers.ts:48-64`).
- `enforceTransferClearance` (`sis/sis_students_repository.ts:838-861`) checks **finance
  only**, so a `PATCH`/`PUT` to `status='transferred'` bypasses the library gate the TC path
  enforces.

**Additional functional break:** `certificate_type` is `'bonafide' | 'study' | 'conduct' |
'transfer' | 'fee'` in code (`sis/sis_certificates_repository.ts:34`, request CHECK
`supabase/migrations/20260884000000_certificate_requests.sql:35`), but the issues table's CHECK
allows only four — `supabase/migrations/20260849000000_sis_certificates.sql:33-34` — with no
later `ALTER`. Issuing a **fee certificate** raises 23514 → opaque `INTERNAL_ERROR` 500
(`sis/sis_certificate_handlers.ts:155-156`).

---

## CHAIN 6 — Student transfer → fees stop → transport unassign → roster update

**There is no exit orchestration at all.** Flipping `students.status` writes one row and one
audit row — `sis/sis_handlers.ts:486-492` is: resolve id → `updateStudentStatus` →
`emitMutationAudit`. Nothing else. Grep for any notification/enqueue across
`sis_handlers.ts`, `sis_students_repository.ts`, `sis_certificates_repository.ts`: **zero hits**.

Four independent status writers, no canonical one:

| Writer | Location | Dues gate |
|---|---|---|
| `PATCH /sis/students/:id/status` | `sis/sis_students_repository.ts:885-891` | `enforceTransferClearance` (`:883`) |
| `PUT /sis/students/:id` | `sis/sis_students_repository.ts:762-769` | same gate re-applied (`:748`) |
| TC issuance | `sis/sis_certificates_repository.ts:647-655` | full no-dues + waiver |
| Year rollover → `alumni` | `academic/academic_transition_repository.ts:381` | **none** |

And the gate is transfer-only: `if (targetStatus !== "transferred") return;`
(`sis/sis_students_repository.ts:843`) — `inactive` and `graduated` clear no dues at all.

| # | Hop | Verdict | Evidence |
|---|---|---|---|
| 1 | Fee demands stop | **PARTIAL** | Auto-resolve path filters `AND s.status='active'` (`finance/finance_assignments_repository.ts:236`), but the explicit `student_ids[]` path — the normal UI flow — skips it (`finance/finance_assignments_handlers.ts:375`) and `bulkAssignFeeStructureSetBased` inserts straight from `unnest($3::uuid[])` (`:731-733`) with no re-check |
| 1b | Late-fee accrual stops | **NO** | `finance/finance_late_fee_repository.ts:106-118` — no `students` join, no status predicate. Ex-student invoices keep accruing |
| 1c | Drops off the defaulter/dunning list | **NO** | `finance/finance_recovery_repository.ts:183-187`, `:494-498` — `LEFT JOIN students` present but the WHERE is only `fsa.status='open' AND outstanding_amount>0`. A waiver-cleared transfer keeps `outstanding_amount > 0` (`clearance/clearance_contributors.ts:31` only *sums*, never zeroes) → a permanent defaulter ghost |
| 2 | Transport seat unassigned | **MANUAL** | `stopStudentTransport` (`transport/transport_write_handlers.ts:553`) is complete and correct — soft-stop, cancels the invoice, releases the dedupe key — but its **only** caller is `DELETE /transport/allocations/{id}` (`:626-639`). Zero callers from any SIS path |
| 2b | **Driver / transport manager informed** | **NOTHING EXISTS** | The only transport notification in the codebase is `POST /transport/notify-delay` (`:666`). No enqueue in the stop path, none in the SIS exit path |
| 2c | Ex-student can still be bus-allocated | **defect** | Bulk-allocation roster joins `students` with no `s.status` predicate — `transport/transport_read_repository.ts:227-235` |
| 3 | Class roster / section strength | **MANUAL** | `sections.strength` is a stored integer written only from the section create/update body (`academic/academic_handlers.ts:552,592`); repo-wide grep finds **zero** increment/decrement writers |
| 4 | Hostel bed released | **MANUAL + defect** | `handleCheckoutStudent` (`hostel/hostel_write_handlers.ts:156-194`) only flips the payload to `checkedOut`; `room.occupiedBeds` is incremented on assign (`:131,136`) and **never decremented** — the bed is permanently consumed |
| 5 | Library membership closed | **MANUAL — no endpoint** | `library/library_router.ts:54,102` — only `GET`/`POST /library/members`. No close/deactivate route; `status:"active"` is written at enrol and never changed |
| 5b | Inventory issue reconciled | **MANUAL** | `inventory_distribution/inventory_distribution_repository.ts:123-135` — no exit hook |
| 6 | Parent portal access revoked | **NOT REVOKED** | `auth_context.ts:268-274` selects `students(id,display_name,status)` and **never filters on it**; `childIds` at `:300` therefore includes transferred/inactive children. Contrast `resolveStudentContext:335-339`, which *does* `.eq("status","active")` — **the student loses access, the parent does not** |
| 6b | Guardian link deactivation | **MANUAL, and blocked** | Soft unlink sets `status='inactive'` (`sis/sis_guardians_repository.ts:168`) and RLS gates on it — but `LastGuardianError` (`:164`) refuses to deactivate the sole remaining active link, so a departed student's only parent can never be de-authorized through the API |
| 7 | Attendance register stops listing | **BROKEN — two rosters disagree** | Display roster filters `AND s.status = 'active'` (`pilot/pilot_attendance_repository.ts:556`) so the student vanishes from the teacher's list; the submit validator `activeRosterStudentIds` (`:167-178`) filters **only** `e.is_current = true` with no `students` join, so it still expects the mark → `AttendanceRosterMismatchError` at `:240-247`. **Nothing sets `is_current=false` on a status change** — attendance submission for that class is hard-blocked |
| 8 | Dashboard headcount | **AUTOMATIC** ✅ | `sis/sis_dashboard_repository.ts:101-108`, `dashboard/dashboard_service.ts:91`, `director/director_repository.ts:118-120` — live counts with correct status predicates. The only fully-correct hop in the chain |

---

## THE MANUAL LIST — every human step someone must remember

*This is the most valuable output of this workstream. A school does not experience "the
modules are decoupled"; it experiences "nobody told the bus driver".*

### Attendance
1. **Be online, or reopen the app** — an offline teacher submit sits in the local queue until
   the sync engine drains (`lib/core/reliability/sync/sync_engine.dart:50,66,81`).
2. **Trigger the notification drain** so absence alerts actually *send*:
   `POST /communications/notifications/process-queue`. No cron does this.
3. **Refresh the parent academic summary** (`POST /parent/experience/summary/refresh`) or the
   parent reads a frozen attendance rate forever.
4. **Recompute student risk** (`POST /intelligence/risk/students/compute`) — this feeds
   principal dashboards and the principal brief.
5. **Run the domain-events drain** (`POST /domain-events/process-pending`) if AI-narrative
   caches are ever to reflect anything that happened.
6. **Pre-warm the daily brief** (`POST /intelligence/briefs/prewarm`).
7. **Tell the parent yourself** when a child is *late*, *half-day*, *excused*, or when an
   attendance correction is approved — none of these notify anyone.

### Leave & substitution
8. **Mark the on-leave employee's attendance yourself** — nothing writes a row on approval and
   the muster will otherwise print `A`. There is no HR attendance write endpoint at all, so
   this cannot even be corrected through the API.
9. **Choose an unpaid leave type** exactly (`unpaid`/`lop`/`loss_of_pay`/`leave_without_pay`/
   `lwp`) or payroll silently deducts ₹0.
10. **Trigger the payroll run** (`POST /hr/payroll/run/generate`).
11. **Trigger leave accrual** (`POST /hr/leave/accrual/run`).
12. **Notice that a teacher is away** — no period is flagged and the "teachers on leave" list
    is structurally always empty.
13. **Open the substitute wizard and assign manually**, period by period.
14. **Tell the substitute, the class in-charge and the students personally** —
    `notifiedAudience` is a cosmetic echo of your own checkboxes.
15. **Reconcile HR "on leave today" against the muster by hand** — they read different stores
    and will disagree.
16. **Correct the student's attendance percentage by hand** after an approved leave — the
    auto-excuse never fires.

### Fees
17. **Pick a fee structure and "send to Finance"** on every admission handoff.
18. **Assign the structure in Finance** — *this*, not admission, is what raises the invoice.
19. **After allocating a student to a bus route, separately open Transport Settings and press
    "Raise demand"** — otherwise the student rides free with zero dues.
20. **Reconcile cheque/DD/PDC** through the Offline Instrument Register before it posts.
21. **Run late-fee accrual** (`POST /finance/late-fees/accrue`).
22. **Turn on `receipts.receipt_sequencing`** per school or receipts stay randomly numbered.
23. **Set `TRANSACTIONAL_SMS_ENABLED` + a provider**, or no parent is ever told a payment landed.
24. **Ignore the Payment Reminders settings page entirely** — nothing reads it.

### Exams
25. **Pull `GET …/report-cards?term=` per class** — nothing is generated at publish.
26. **Tell parents results are out** unless SMS is configured; there is no push or in-app alert.

### Certificates
27. **Raise the certificate request on the parent's behalf** — there is no parent-facing screen.
28. **Chase hostel, transport, inventory and lab dues by hand** — none of them block a TC.
29. **Ensure the librarian typed the student code correctly into the library member record**,
    or the only non-fee block silently does nothing.
30. **Print and physically hand over the certificate** from the issuing staff device — and note
    the certificate-desk path produces no PDF at all.

### Student exit
31. **After a student leaves, do all of this manually:** delete the transport allocation ·
    **phone the bus driver and transport manager** (no code path exists) · edit
    `sections.strength` · check the student out of the hostel *and* fix `room.occupiedBeds`
    by hand (no API decrements it) · close library membership (no endpoint exists) ·
    reconcile outstanding inventory distributions · unlink guardians one by one (impossible
    for the last one) · flip `sis_student_enrollments.is_current = false` or class attendance
    submission stays hard-blocked · cancel the finance assignment and close the account or
    late fees keep accruing and the ex-student stays on the dunning list.

---

## Re-verification of the inherited architecture review

| Inherited claim | Status now |
|---|---|
| Outbox is a durable log, not a bus; inserted `'published'`, drain selects `pending\|failed`; empty subscriber registry | **CONFIRMED, unchanged** — `audit_repository.ts:365` vs `domain_events_worker.ts:41`; registry empty |
| Leave approval = status flip + audit row | **CONFIRMED** — `hr/hr_write_handlers.ts:738-783`; `approval/leave_decision_effect.ts:36-64` |
| Substitution fed by a query against the wrong table **and** a permanently-null column | **CONFIRMED, and worse** — wrong store (`mobile_leave_requests` vs `snapshot_leave`) *and* `from_date` never populated by any client; the same NULL also kills student-leave auto-excuse |
| Attendance→parent notification is a 5-language template with no caller | **PARTIALLY REFUTED** — a notification *is* enqueued on the write path (`pilot/pilot_operations_handlers.ts:245-263`), but with a **hardcoded English string**; the 5-language `attendance_absence` template (`communication/parent_comms_localization.ts:69`) still has **zero callers** and the alert names no child and no date |

**Correction made during this workstream:** an intermediate finding claimed exam results can
never be published on the default build. That is **wrong** — the server publishes inside the
approval decision (`approval/approval_type_handlers.ts:66-79`, reached from
`approval/approval_handlers.ts:158` via `approval/approval_orchestrator.ts:37`). Recorded here
so it is not carried forward.

---

## Verification boundaries

- **Static trace only.** No Postgres lane, no live pilot DB (SSH is owner-bound), so
  "structurally always empty" claims rest on code + migrations, not on a `SELECT`.
- Whether a *deployed* crontab or pg_cron job exists outside `deploy/**` could not be
  inspected. `supabase/migrations/20260920000130` states there is no pg_cron.
- Whether any production tenant populates `library_entities.payload->>'sisStudentId'`
  correctly is a data question, not a code question.
- Runtime config (`TRANSACTIONAL_SMS_ENABLED`, `RAZORPAY_*`, `INTERNAL_CRON_TOKEN`) is not in
  the repo; defaults were read from `config.ts` and `payment/razorpay_config.ts`.
- The web app (`web/`) was not traced; findings above are backend + Flutter.
- Whether a UI exists to set `sis_student_enrollments.is_current = false` directly could not
  be confirmed.

---

## Defects raised

39 entries appended to `docs/certification/DEFECT_REGISTER.md` as **XMOD-001 … XMOD-039**
(10 × P0, 22 × P1, 7 × P2).
