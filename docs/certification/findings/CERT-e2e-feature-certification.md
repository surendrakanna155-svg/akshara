# NIKSHA OS — Workstream 2: End-to-End Feature Certification

**Branch** `release/v1.0-playstore` · **Started** 2026-07-29 · **Read-only pass.**

## What "certified end to end" means here

Per the charter, a feature is certified only when traced **first user action → UI →
validation → API → database → audit → notifications → reports → analytics →
dashboards → related modules → final outcome**. This document records, per module,
**which of those twelve links exist and which are absent** — not whether a test
passes.

Link legend used in every module table:

| Symbol | Meaning |
|---|---|
| ✅ | Link exists and carries the real value end to end |
| ⚠️ | Link exists but is partial, wrong, or unreachable for some personas |
| ❌ | Link is absent — nothing on this path performs that step |
| — | Not applicable to this feature |

## Build-on, not re-derive

This workstream **inherits and does not restate**:

- `findings/XMOD-cross-module-certification.md` — 39 defects; the **dead event bus**
  (XMOD-001) and the **31 manual steps** finding are treated as established facts
  and are cited, not re-proved.
- `findings/JOURNEY-role-journeys.md` — 16 defects; role reachability.
- `findings/SIM-real-school.md` — 4 defects; a full school day.
- `findings/WIDGET-dashboard-certification.md` — 18 defects; every dashboard widget.
- `findings/DAI-certification.md` — 16 defects; global search.

Where a link is broken **for a reason another workstream already documented**, this
document marks the link ⚠️/❌ and cites the existing ID. New defects raised here use
the `E2E-` prefix.

## Order of certification

By what a school touches daily and what hurts most if wrong:
attendance · fees/collections · exams & marks · report cards · certificates ·
admissions · leave · payroll · transport · library · hostel · communication ·
inventory · student & staff records.

## Verification boundary for this workstream

Static + contract tracing only. No Postgres lane, no live VPS, no release binary
(charter). "Writes to table X" is proved by reading the repository/handler SQL and
the migration that defines X, never by observing a row. Where a claim could not be
settled from source, it is stated as a boundary rather than a finding.

---

# 1 — Attendance

Daily, universal, and feeds payroll (staff), the report card (student), risk
analytics and the parent app. Traced: teacher marks a class → correction request
→ approval → the mark actually changing.

## 1.1 Chain: teacher marks a class (`/teacher/attendance` → `POST /teacher/attendance/submit`)

| Link | State | Evidence |
|---|---|---|
| First action | ✅ | `teacher_attendance_screen.dart` roster grid; bulk-mark + "fill remaining present" (`teacher_attendance_provider.dart:139-156`) |
| UI | ✅ | submit disabled until `unmarkedCount == 0` (`teacher_attendance_screen.dart:457`) |
| Validation | ⚠️ | client blocks unmarked; server enforces an **exact roster match** (`pilot_attendance_repository.ts:38-52`, `AttendanceRosterMismatchError`), holiday/year-closure block, and submitted-session immutability. Strong. **But the error copy lies on failure — E2E-001** |
| API | ✅ | `POST /teacher/attendance/submit`, `markAttendance` + `assertTeacherOwnsClass` (`pilot_operations_handlers.ts`) |
| Database | ✅ | `attendance_sessions` (natural key org+school+class+**date**+period) + `attendance_records`; race-safe `ON CONFLICT … WHERE status <> 'submitted'` |
| Audit | ✅ | `auditMobileWrite(…, "attendanceSubmitted", …)` with the mark counts, same transaction |
| Notifications | ⚠️ | guardian absence alert **enqueued** per absent student — but the queue is never drained (**XMOD-019**) and the text is unlocalised/unidentifiable (**XMOD-018**) |
| Reports | ✅ | office register / monthly register / short-attendance reads exist (`attendance_office_repository.ts`) |
| Analytics | ⚠️ | attendance-risk uses a non-canonical formula (**XMOD-020**) |
| Dashboards | ⚠️ | parent + teacher dashboards fabricate attendance (**WIDGET-001**, **WIDGET-002**); "no data" renders as 0% (**XMOD-010**) |
| Related modules | ⚠️ | approved leave auto-excuses on submit (`applyApprovedLeaveExcuse`) ✅; an exited student blocks the whole class submit (**XMOD-007**) |
| Final outcome | ✅ | the session is locked and immutable through this path |

**Certified good, and worth saying so:** this is the most hardened write path
examined in this workstream. One session per class/date/period regardless of who
marks it; a submitted session cannot be silently overwritten; the roster diff
makes a partial submit impossible; the teacher must own the class; approved leave
is auto-excused server-side.

**Structural gap — no attendance can ever be backdated.** `upsertAttendanceSession`
matches and inserts on `session_date = CURRENT_DATE` only
(`pilot_attendance_repository.ts:57-62, 84-95`); the request body carries no date
field (`teacher_attendance_provider.dart:206-229`). A teacher who was absent
yesterday, or a school recovering from an outage, has **no path to enter a past
day's attendance** — and the correction workflow that looks like the answer does
not honour a date either (§1.2). Recorded as **E2E-004**.

## 1.2 Chain: attendance correction (teacher/parent → principal approval → the mark)

| Link | State | Evidence |
|---|---|---|
| First action | ⚠️ | dialog opens **pre-filled with fabricated values** — `'12 Jun 2026'` and *"Biometric sync error — student was present"* — **E2E-002** |
| UI | ⚠️ | attendance date is a **free-text `AksharaFormField`**, not a date picker |
| Validation | ❌ | no date parsing or range check anywhere; `markToDb` silently coerces any unknown mark to `"present"` (`attendance_correction_repository.ts:47-54`); `requesterRole`/`requesterName` are taken from the request body on the staff route — **E2E-003** |
| API | ✅ | `POST /attendance/corrections` (manageSis) · decision gated on `approveAttendanceCorrection`, not plain `manageSis` |
| Database | ⚠️ | row written to `attendance_corrections` — but **`session_date` is never populated** (the INSERT omits the column entirely, `attendance_correction_repository.ts:157-181`) — **E2E-004** |
| Audit | ✅ | `correctionRequested` at submit and `correctionDecided` at decision, both in-transaction with a real before→after and an `updated_at` nonce. Genuinely well done |
| Notifications | ❌ | nothing is sent to the requester when their correction is approved or rejected. No enqueue call in `attendance_handlers.ts` or `approval_type_handlers.ts` for this type |
| Reports | — | |
| Analytics | — | |
| Dashboards | ⚠️ | the admin corrections screen's headline card is driven by a **mock store** — **E2E-005** |
| Related modules | ⚠️ | applied only through the approval engine (`approval_type_handlers.ts:143`); the direct `POST /attendance/corrections/:id/status` route flips the status **without applying it** — **E2E-006** |
| Final outcome | ❌ | **the corrected date is ignored** and a 0-row update is reported as success — **E2E-004**, **E2E-007** |

### The core defect in this chain

`applyAttendanceCorrection` chooses which attendance record to change like this
(`attendance_correction_repository.ts:250-259`): *if the correction carries a
`session_date`, match that session; otherwise take the most recent submitted
session.* `session_date` is **never written** — the create path does not include
the column, and nothing else updates it. So the branch is dead: every approved
correction is applied to the **latest submitted session**, whatever date the
teacher or parent actually asked about. A parent disputing an absence from three
weeks ago gets today's mark changed instead. The `date_label` the teacher typed is
carried into the row, the audit trail and the approver's screen — so the audit
records a date the write never used.

---

# 2 — Fees & collections

The money path. Traced: cashier records a payment at the counter → receipt →
invoice → parent; and the separate cheque/DD/PDC register.

## 2.1 Chain: record a collection (`Record collection` dialog → `POST /finance/collections`)

| Link | State | Evidence |
|---|---|---|
| First action | ✅ | `showRecordCollectionDialog` (`finance_workflow_actions.dart:1270`), reachable from the collections screen and from a student account |
| UI | ✅ | real invoice picker built from loaded invoices, amount pre-filled from that invoice's **actual outstanding** (+ late-fee breakdown line), draft autosave/recovery (REL-3) |
| Validation | ⚠️ | **client-side: none** — the amount field has no `validator`; the server carries all of it (`amount > 0`, `amount <= outstanding`, instrument-method rejection, invoice must exist). Correct, but every mistake costs a round trip |
| API | ✅ | `POST /finance/collections`, `manageFinance` + school scope; `Idempotency-Key` minted for every mutation (`idempotency_key_interceptor.dart`) |
| Database | ✅ | invoice row-locked, replay-on-key, `finance_collections` INSERT + invoice outstanding/status update in one transaction, partial-unique indexes as DB backstops |
| Audit | ✅ | `collectionCreated` mutation audit **and** a `finance.collection.created` domain event with an idempotency key, in-transaction |
| Notifications | ✅ | `notifyParentOfReceipt(...)` is actually called after commit — one of the few flows that closes this link |
| Reports | ⚠️ | daily summary / day-close / Tally export read `finance_collections`; **but see E2E-008 — the day-close lock does not hold** |
| Analytics | ⚠️ | five divergent definitions of "outstanding dues" across the module (**XMOD-014**) |
| Dashboards | ⚠️ | admin landing hero fabricates "₹4.2L Collected today" (**JOURNEY-001**); filter chips do not filter (**WIDGET-008**) |
| Related modules | ⚠️ | ex-students keep accruing (**XMOD-024**); transport raises no demand (**XMOD-004**) |
| Final outcome | ❌ | **the receipt number and the day-close lock are both corrupted by a literal string the client sends as the date — E2E-008** |

**The defect at the end of this chain.** The dialog hard-codes
`collectionDate: 'Today'` (`finance_workflow_actions.dart:1371`); the DTO forwards
the word verbatim; the handler accepts it without validation. Two things then
happen server-side:

1. `isDateLocked` compares **lexically**: `"Today" <= "2026-07-28"` is `false`
   because `'T'` (84) sorts after `'2'` (50). The FIN-D1 closed-day guard therefore
   **never fires for any collection made from the app**.
2. `fiscalYearOf("Today")` does `new Date("TodayT00:00:00Z")` → Invalid Date →
   `NaN` → returns the string **`"NaN-NaN"`**. With receipt sequencing on, every
   receipt is numbered `PREFIX/NaN-NaN/000001` and all years share one sequence.

The INSERT itself survives only because PostgreSQL happens to accept `'today'`
as a special date literal — the write is correct by accident while everything
derived from the same value is wrong. The instrument-reconcile path passes a real
ISO date and is unaffected; this is specific to the counter screen.

## 2.2 Chain: the offline instrument register (`/finance/payments/offline`)

| Link | State | Evidence |
|---|---|---|
| First action | ⚠️ | "Record offline payment" FAB; **Invoice ID pre-filled `'inv_1'`** — **E2E-009** |
| UI | ⚠️ | free-text invoice ID (no picker, unlike §2.1); instrument date + bank shown only for cheque/DD/PDC (correct) |
| Validation | ⚠️ | no client validation at all — no validator, no required fields, no invoice existence check. Server checks amount > 0 and the method enum, **but never that `invoiceId` exists or is non-empty** |
| API | ✅ | `POST /finance/payments/offline`, `manageFinance` |
| Database | ✅ | `finance_offline_payments` at `pending_reconciliation`, **no money posted** — correct for an uncleared instrument |
| Audit | ✅ | `offlinePaymentRecorded` / `Reconciled` / `Bounced`, all in-transaction |
| Notifications | ❌ | nothing to the parent when a cheque clears or bounces |
| Reports | ✅ | pending / reconciled / bounced tabs |
| Analytics | — | |
| Dashboards | ❌ | uncleared instruments appear on no dashboard; a bounced cheque surfaces nowhere outside this screen |
| Related modules | ✅ | reconcile posts a real collection through the standard path with a hard one-collection-per-instrument DB index |
| Final outcome | ❌ | **cash recorded here never becomes money — E2E-010** |

**Certified good, and worth saying so:** the reconcile path is the most carefully
built money code in the repo — `FOR UPDATE` on the instrument before the state
check, a consistent instrument→invoice lock order, an idempotent re-reconcile, a
guarded terminal `AND status = 'pending_reconciliation'` write that fails closed,
and two partial-unique DB indexes as backstops. A cheque cannot be double-credited.

**But the register offers `Cash`.** `createOfflinePayment` writes *every* method —
cash included — as `pending_reconciliation` with no collection. Cash has no
clearance event, so a cashier who records a cash payment here gets *"Offline
payment recorded."*, the student's dues do not move, no receipt exists, the day's
collection total is unchanged, and the parent still sees the full amount
outstanding. It only becomes money if someone later opens the Reconciled tab —
and if the invoice ID was left as the pre-filled `inv_1`, reconciliation throws
`OfflinePaymentNotInvoicedError`/invoice-not-found and the money is stranded
permanently.

---

# 3 — Exams, marks & report cards

Traced: create an exam → open marks entry → a teacher enters marks → publish →
what the parent and the student see, and what the school can export.

## 3.1 Chain: marks entry (`/school/exam-administration/:examId/marks`)

| Link | State | Evidence |
|---|---|---|
| First action | ✅ | per-student cells + bulk paste; AB/ML/DB status selector |
| UI | ✅ | out-of-range cells are counted and named before save ("… out of range 0–80 — not saved") |
| Validation | ✅ | client `0..maxMarks` + `inputFormatters`; server re-validates status enum, requires an integer ≥ 0 for `present`, enforces `<= max_marks` from the **entry's own** row, and a `NOT VALID` DB CHECK backs both |
| API | ✅ | single PATCH and bulk save funnel through one `applyMarkUpdate` so the guards cannot diverge |
| Database | ✅ | `exam_mark_entries` with optimistic concurrency (`expectedVersion`) and a `published = false` fence — a published mark cannot be silently edited |
| Audit | ✅ | per-row before→after audit binding actor → exam → student, including status |
| Notifications | ⚠️ | `POST /academics/exams/marks/remind` exists; nothing schedules it (**XMOD-016**) |
| Reports | ⚠️ | tabulation / merit / distribution exist, but ignore publish state and AB/ML/DB (**XMOD-029**) |
| Analytics | ⚠️ | same |
| Dashboards | ⚠️ | teacher "marks pending" tile is fed by the seeded singleton — **E2E-012** |
| Related modules | ⚠️ | grading forks; State-Board SSC scale unreachable (**XMOD-030**) |
| Final outcome | ✅ | for the mark itself: correct, guarded, audited |

**Certified good, and worth saying so:** alongside attendance submit, marks entry
is the strongest write path in the product. Subject teachers are scoped to exams
they actually teach; a published mark is immutable through this path; concurrency
is handled; every cell change is individually audited with its before value, so
"who changed this mark" is answerable.

## 3.2 Chain: create an exam

| Link | State | Evidence |
|---|---|---|
| First action | ⚠️ | `exam_create_dialog.dart` opens pre-filled with `'Term 2'`, **`'15 Mar 2026'`**, `'9:00 AM - 10:30 AM'`, `'Room 8A'` — **E2E-013** |
| Validation | ⚠️ | client requires `maxMarks > 0`; **server accepts any number** — `Number(body.maxMarks ?? 100) \|\| 100` lets a negative through and silently rewrites `0` to `100`; no DB CHECK on `max_marks` |
| Database | ❌ | `exam_sessions` has **no date column** — only `date_label TEXT` — **E2E-014** |
| Audit | ✅ | exam lifecycle transitions are audited |
| Reports | ⚠️ | a datesheet built from free text cannot be sorted, clash-checked or reminded on |
| Final outcome | ⚠️ | the exam exists and is workable; its date is decorative |

## 3.3 Chain: report card (parent & student)

| Link | State | Evidence |
|---|---|---|
| Source | ✅ | **fixed and verified** — both providers now build from the server-backed published-results feed, not the old in-memory store (`parent/exams/report_card_provider.dart`, `student_app/exams/report_card_provider.dart`) |
| Publish gate | ⚠️ | only published results reach the feed; but unpublished/unentered marks still leak through a different read (**XMOD-005**) and AB/ML/DB are counted as zero (**XMOD-009**) |
| Grading scale | ❌ | the overall grade is **hard-coded to `ExamGradingScale.standard`** (`exam_report_card.dart:178`) regardless of the school's configured scale — **E2E-015** |
| Rank | ⚠️ | always `rankShown: false`, so the school's `showRankToParents` setting has no effect anywhere |
| Remarks | ⚠️ | not carried by the feed — honestly omitted rather than faked (good) |
| Delivery | ❌ | no notification when results are published; the parent must look |
| Final outcome | ⚠️ | a correct list of subject marks under an overall grade computed on a scale the school may not use |

## 3.4 The exam settings sheet is inert

`ExamReportSettingsNotifier` (grading scale · rank visibility · term hints) reads
and writes **only** `ExamAdministrationStore.instance` — an in-memory singleton
with local snapshot persistence. There is **no client caller of
`/academics/exams/grade-scale` anywhere in `lib/`**, although the backend
implements `GET`/`PUT` for it *and audits the change*. So a principal switching
the school to the CBSE or State-Board scale changes a value on their own phone,
which no other device, no server computation and no audit trail ever sees —
**E2E-016**.

The same name is also declared twice: `examReportSettingsProvider` exists as a
`NotifierProvider` in `exam_settings_provider.dart:9` **and** as a dependency-free
`Provider` in `exam_reports_provider.dart:116`. The settings sheet and the create
dialog import the first; the exam **reports** screen imports the second, which
reads the singleton once and — having nothing to watch — caches that value for the
life of the app. Changing the scale therefore does not reach the tabulation and
distribution reports in the same session.

---

# 4 — Documents & records (SIS · Admissions · Homework)

Traced: the school asks for a document → it is uploaded → it is verified → a
decision is taken on it.

| Link | State | Evidence |
|---|---|---|
| First action | ❌ | **there is no file picker in the product** — `file_picker` is not a dependency; `image_picker` is used only by the support screen |
| UI | ❌ | the dialogs collect a *document type* and a *file name* as free text |
| Validation | ❌ | nothing checks a type against a required-documents list, and there is nothing to validate because there is no file |
| API | ✅ | the Storage path itself is real: presign → PUT bytes → confirm |
| Database | ⚠️ | a document row is created and is retrievable — pointing at a blank page |
| Audit | ✅ | verification decisions are audited |
| Notifications | ❌ | none on request, upload or verification |
| Related modules | ❌ | admissions approval, TC/clearance and homework grading all consume these rows as if they were documents |
| Final outcome | ❌ | **the school's record asserts it holds a document it does not hold — E2E-017** |

This is the single widest defect found in this workstream: four upload surfaces
(SIS student documents, admissions documents, student homework submission,
teacher homework attachment) all post the same hard-coded five-line blank PDF.
Each source file documents the substitution as a temporary stand-in for a missing
platform picker; it ships.

---

# 5 — HR & Payroll

| Link | State | Evidence |
|---|---|---|
| First action | ✅ | `showGeneratePayrollRunDialog` — period pre-filled with the current month |
| UI | ⚠️ | period is a free-text field ("Period (e.g. July 2026)") |
| Validation | ❌ | no format validation client- or server-side; `period` is `requireStr` only — **E2E-018** |
| API | ✅ | `POST /hr/payroll/run/generate`, `manageHr`, entitlement-gated |
| Database | ✅ | draft run + entries via a guarded snapshot mutation; a processed run is refused 409 |
| Audit | ✅ | payroll writes are audited |
| Notifications | ❌ | no payslip notification to staff |
| Reports | ✅ | register + payslips |
| Analytics | ⚠️ | LOP term permanently zero (**XMOD-012**); attendance % non-canonical (**XMOD-038**) |
| Related modules | ❌ | teacher-app leave never reaches payroll (**XMOD-011**); approved leave counted as absence (**XMOD-003**) |
| Final outcome | ⚠️ | a run is produced; the statutory month is always `null` — **E2E-018** |

**No HR role exists** to run any of this (**JOURNEY-012**) — payroll is reachable
only by the principal or a school admin.

---

# 6 — Inventory & Procurement

| Link | State | Evidence |
|---|---|---|
| First action | ✅ | Create purchase order; the vendor dropdown is built from the real catalog, with an inline "Add vendor" when it is empty (good) |
| UI | ⚠️ | items and total amount are single free-text fields — there is no line-item editor |
| Validation | ⚠️ | client checks only that a vendor is selected; amount and items may be blank |
| API | ❌ | **the client sends the vendor's display name in the `vendorId` field — E2E-019** |
| Database | ❌ | `purchase_orders.vendor_id` is `UUID NOT NULL REFERENCES inventory_vendors(id)`; a display name cannot cast |
| Audit | ✅ | `purchaseOrderCreated` + `inventory.procurement.created` domain event (server side, correct) |
| Final outcome | ❌ | a purchase order cannot be created from the app |

Secondary, in the same adapter: the free-text PO is translated into **one synthetic
line** (`sku: 'GEN-<PO>'`, `quantity: 1`, `unitCost: <the whole total>`), so
per-item goods receipt against the PO is structurally impossible; and
`purchase_orders.total_amount` is `INTEGER`, so any paise in the typed total are
lost.

**Verified clean:** `withMockWriteFallback` — used by the transport, hostel,
library, inventory, HR, director and predictions hybrid repositories — routes a
write to the in-memory mock when `ApiNotConnectedException` is raised. A
repo-wide grep shows **nothing throws that exception**, so no live write silently
lands in a mock. This was checked because it is exactly the silent-success shape
this workstream is looking for; it is not one.

---

# 7 — Cross-cutting: dates are stored as display labels

Not one defect but a pattern, found independently in five modules:

| Where | Column / field | Consequence |
|---|---|---|
| Attendance corrections | `date_label TEXT` (`session_date DATE` exists, never written) | the correction is applied to the wrong day (**E2E-004**) |
| Exams | `date_label TEXT`, no `exam_date` | no datesheet ordering, no clash detection, no reminder (**E2E-014**) |
| Admissions follow-ups | `scheduledLabel`, default `'Tomorrow 10:00 AM'` | nothing can remind the counsellor |
| Finance collections | client sends the literal `'Today'` | day-close lock bypassed, receipt number reads `NaN` (**E2E-008**) |
| HR payroll | `period` free text ("July 2026") vs a parser expecting `YYYY-MM` | statutory month always `null` (**E2E-018**) |

In every case a real date type exists nearby — `marksEntryDeadline` is a validated
timestamp on the same exam row; `session_date` is a `DATE` column on the same
corrections row; `finance_collections.collection_date` is a `DATE`. The pattern is
not an architectural constraint, it is an unfinished migration from labels to
dates, and it is why four separate features cannot schedule, sort, or validate
anything time-based.

---

# 8 — Modules traced but not defect-bearing here

These were opened and read; nothing new was found beyond what other workstreams
already recorded. Stating what was checked, per the charter's honesty rules.

| Module | What was checked | Verdict |
|---|---|---|
| **Certificates (PRC-A desk)** | `certificate_desk_repository.ts` state machine, the raise dialog, the approval effect | The lifecycle is properly guarded — `pending → approved/rejected → issued/blocked_dues`, each transition a single guarded UPDATE, with a distinct `blocked_dues` terminal state and an `issue_note` recording why. No new defect. The module's real problems are already filed: **XMOD-008** (fee certificate rejected by a DB CHECK), **XMOD-023** (never delivered to the parent), **XMOD-031** (library-blocked TC returns an opaque 500), **XMOD-039** (no parent-facing request surface), **XMOD-021** (no-dues means fees only) |
| **Transport** | `transport_workflow_actions.dart` bulk raise-demand loop | The per-student loop counts `raised / alreadyBilled / failed` and reports all three honestly in the snackbar — a good example of the opposite of E2E-001. Pre-filled `'Akshara Main Gate'` drop point and `'annual'` term are cosmetic. **XMOD-004** (allocation raises no demand) is the module's real defect |
| **Library** | `library_workflow_actions.dart` issue/return/fine/waive dialogs | Fine waiver names the amount and the member in the confirmation; the threshold setting is `int.tryParse`-guarded. No new defect |
| **Hostel** | allocation dialog | Pre-filled block `'A'` / beds `'2'` are plausible defaults, not fabricated records |
| **Communication** | broadcast admin → `notifications_queue` → delivery | Already fully covered by **SIM-001** (nothing monitors the queue), **XMOD-019** (enqueued, never drained), **XMOD-015**, **XMOD-018** |
| **Leave** | teacher/parent submit → approval effect | Already fully covered by **XMOD-002**, **XMOD-003**, **XMOD-011** — the two disjoint leave stores and the missing date window are the module |

# 9 — What this workstream certified as sound

Recording these explicitly, because a register of 120 defects otherwise implies
a product with no working parts, and that is not what the code shows.

1. **Class attendance submit** — one session per class/date/period whoever marks
   it; exact roster reconciliation; submitted sessions immutable; teacher
   ownership enforced; approved leave auto-excused; audited in-transaction.
2. **Exam marks entry** — bounds enforced in three places (client, handler, DB
   CHECK); published marks immutable; optimistic concurrency; subject teachers
   scoped to exams they teach; every cell change individually audited with its
   before value.
3. **The fee collection transaction itself** — invoice row-locked, idempotency
   key replayed, over-collection rejected, receipt number allocated last so a
   rollback never burns one, parent notified after commit. (Its *inputs* are
   defective — E2E-008 — but the transaction is right.)
4. **Offline instrument reconciliation** — `FOR UPDATE` before the state check, a
   single consistent lock order, idempotent re-reconcile, a guarded terminal
   write that fails closed, and two partial-unique DB indexes as backstops. A
   cheque cannot be double-credited.
5. **The certificate-desk state machine** — guarded transitions with a distinct
   blocked terminal state.
6. **`withMockWriteFallback`** — checked specifically for the silent-success
   shape; nothing throws the exception it catches, so no live write lands in a
   mock.

# 10 — Coverage and boundaries

**Traced end to end:** attendance (mark + correct), fees (counter collection +
instrument register), exams (create · marks · publish · report card · settings),
documents/uploads (SIS · admissions · homework), payroll (run generation),
procurement (PO creation).

**Read but not fully traced:** transport, library, hostel, communication, leave,
certificates — each already carries a complete trace from XMOD/SIM/JOURNEY; this
workstream checked them for the four weighted defect classes only and cites those
findings rather than duplicating them.

**Not reached in this pass:** alumni, control centre, director portal, multi-school
and the platform verticals. All are outside the "what a school touches daily"
prioritisation this workstream was given, and none is a money, marks, attendance
or records path.

**Boundaries that could not be crossed** (charter): no Postgres lane, so every
"writes row X" claim here is proved from the handler SQL plus the migration that
defines the column, never from an observed row — this is why E2E-004 and E2E-008
are argued from the *absence of a producer* and from *string-comparison semantics*
rather than from a query result. No live VPS. No release binary. No live payment
gateway, so the Razorpay leg of §2 remains UNKNOWN as the feature inventory
already records.

# Appendix — defects raised by this workstream

| ID | Sev | Module | One line |
|---|---|---|---|
| E2E-001 | P1 | Attendance | A rejected submit is reported as a data-entry mistake |
| E2E-002 | P1 | Attendance | Correction dialog pre-filled with a fabricated date and reason |
| E2E-003 | P1 | Attendance | Staff correction route trusts the body for who is asking |
| E2E-004 | **P0** | Attendance | Approved corrections apply to the wrong day; no day but today can be marked |
| E2E-005 | P1 | Attendance | Corrections admin screen reports submission status from a mock store |
| E2E-006 | P2 | Attendance | A live route approves a correction without applying it |
| E2E-007 | P1 | Attendance | Approving a correction that matches no record reports success |
| E2E-008 | **P0** | Finance | The counter sends `"Today"` — day-close bypassed, receipts read `NaN` |
| E2E-009 | P1 | Finance | Instrument register defaults to a demo invoice ID and validates nothing |
| E2E-010 | P1 | Finance | Cash recorded in the instrument register is never money |
| E2E-011 | **P0** | Teacher / Records | Student risk dossier fabricates attendance, marks, homework and fees |
| E2E-012 | **P0** | Exams | "Export marks summary" exports a seeded demo exam |
| E2E-013 | P2 | Exams | Create-exam dialog pre-fills a date, time, room and term |
| E2E-014 | P1 | Exams | An exam has no machine-readable date |
| E2E-015 | P1 | Report cards | Overall grade ignores the school's grading scale |
| E2E-016 | P1 | Exams | The grading-scale setting never leaves the device |
| E2E-017 | **P0** | SIS · Admissions · Homework | Every upload uploads a synthetic empty PDF |
| E2E-018 | P1 | Payroll | Free-text period → statutory month always null; a month can run twice |
| E2E-019 | **P0** | Procurement | PO create sends the vendor's name where a UUID is required |
| E2E-020 | P2 | Admissions | A follow-up is "scheduled" for a string |
| E2E-021 | P2 | AI content | A failed generation is returned as generated content |
