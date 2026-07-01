# Akshara ERP — Product Enhancement Backlog

**Revision:** 4 (FROZEN) · **Date:** 2026-06-30 · **Owner:** surendrakanna155@gmail.com
**Status:** 🔒 **PRODUCT ARCHITECTURE FROZEN** (2026-06-30) — the single source of truth for all product enhancements.
**Scope:** product enhancements, workflow improvements, productivity features, operational improvements **only**.

> Distinct from [`PRODUCT_COMMERCIAL_BACKLOG.md`](PRODUCT_COMMERCIAL_BACKLOG.md) (scope/commercial),
> [`FINAL_QA_ROADMAP.md`](FINAL_QA_ROADMAP.md) (quality — **frozen**), [`Vision/FutureVision.md`](Vision/FutureVision.md)
> (future vision), [`../IDEAS_BACKLOG.md`](../IDEAS_BACKLOG.md). Every item is verified against all four and against
> the live code. **No code/roadmap/QA changes are made by this document** — it is a planning artifact.

---

> ## 🔒 PRODUCT ARCHITECTURE FROZEN
>
> Frozen as of **2026-06-30**. **No further feature brainstorming. No speculative additions.**
> Future additions may come **only** from — and must be added as dated, sourced entries:
> - **Real pilot-school feedback**
> - **Production usage**
> - **Customer requests**
> - **Regulatory changes**
>
> Implementation, roadmap updates, and commits happen **only after** the owner promotes approved items out of
> this backlog. The QA program (FINAL_QA_*, QW1–QW8, EOS ledger) stays frozen and is untouched by this doc.

---

## Locked product decisions (apply to every item)

1. **English-first.** No app localization, no UI translation, no PDF/receipt/report-card translation. **Only
   parent-communication templates may be multilingual.**
2. **Students NEVER use Face ID, QR, RFID, or geo attendance.** Student attendance stays teacher-entered.
3. **Staff Face ID attendance is Must-Before-GA** (see the GA section). Flow (⚠ **CORRECTED 2026-07-01,
   FINAL** — see [`ATTENDANCE_AUTH_DESIGN_DECISION.md`](ATTENDANCE_AUTH_DESIGN_DECISION.md)): **GPS geofence
   (configurable radius) → anti-mock location validation → live camera face verification → Check-In → work
   day → live camera face verification → Check-Out.** Attendance auth **MUST NEVER** use fingerprint /
   Touch ID / PIN / password / device-biometric fallback (device OS biometric = **app-login only**); it is
   **completely separate from login/logout** — login must never affect attendance.
4. **Parent communication localization is deterministic.** No LLM / OpenAI / runtime translation — a
   predefined multilingual template catalog only.

Also honoured (PRODUCT_COMMERCIAL_BACKLOG O1–O10): payments engines + monetization = Phase 2; live GPS bus
tracking = Phase 2; white-label/custom-domain = Phase 2; reception/gate-pass/visitor module = Future Vision.

---

## Priority legend

The macro phase stays (**Must-Before-GA → Phase 1 → Phase 2 → Future**). Within **Phase 1**, every item is
banded so implementation can be sequenced:

| Tag | Meaning |
|---|---|
| **GA** | Must-Before-GA (the single hard blocker = staff Face ID attendance; the build is tracked in PRODUCT_COMMERCIAL_BACKLOG O5 — this doc adds the product design + dashboard) |
| **P1** | Phase 1 · **Critical Operational** — a real school cannot run the daily workflow without it |
| **P2** | Phase 1 · **Productivity** — speeds up / de-duplicates an existing flow |
| **P3** | Phase 1 · **Nice Improvement** — polish / convenience |
| **Ph2** | Phase 2 — later; lower priority or pairs with already-Phase-2 capability (`Ph2`, *not* `P2`) |
| **Fut** | Future — marginal / low-demand for the target schools |

**Complexity:** S ≤ ~2 days · M ~1 week · L > 1 week.
**Behaviour/policy items** are *not* in the main tables — they live in **Appendix A — Needs Owner Decision**.

---

## Final-freeze defaults (Rev 4 — staff-attendance config decided)

- **GA-D1 Late cutoff:** School Start Time **+ configurable grace** (e.g. 09:00 + 10 min → 09:00–09:10 On Time, after 09:10 Late). Per-school configurable.
- **GA-D2 Geofence radius:** default **100 m**; school-configurable to 50 / 100 / 150 / 200 / 300 m.
- **GA-D3 Check-Out: NOT mandatory.** Open days surface as "No Check-Out"; **Principal/HR Manual-Close** with mandatory reason + audit (built into GA-2). Board shows Working Now · No Check-Out · Manual Closed.
- **GA-D4 Mid-day exit:** supported — Check-In → Official Duty / Field Visit / Meeting → Return → Check-Out, fully audited (an official-duty exit is **not** a check-out).
- These four were the last open decisions; **Appendix A now has no open staff-attendance items**.

## Revision-3 changes (final owner decisions — this freeze)

1. **Staff Face ID fallback decided** → new **GA-2 Manual Attendance Request + approval** (geofence/biometric
   fail → retry → manual request with mandatory reason → Principal/HR approve/reject → fully audited; never
   automatic, no silent bypass). Resolves the old open question (Appendix GA-D5, removed).
2. **Transport fee architecture decided** → new **TRN-9 Transport fee structure + due schedule** (Transport
   *defines* structure + raises fee **demand**; **Finance remains the only payment engine** — no duplicate
   payment logic). Resolves the old open question (Appendix TRN-D1, removed).
3. **Recovery CRM re-banded** → **Collector Performance (FIN-R5) moved P2 → P1**; P1 recovery core =
   R1 dashboard · R2 call queue · R3 promise-to-pay · R4 contact history · R5 collector performance.
   P2 = R6 targets · R7 cheque/DD/PDC/bounce.
4. **New TCH-9 "My Attendance" (read-only)** staff self-service history (today/yesterday/month, in/out times,
   working hours, late days, manual overrides).
5. **GA-3 principal staff-attendance summary** locked to the operational metric set (Total · Checked In ·
   Checked Out · Working Now · Late · Absent); trends are Future.

## Revision-2 change log (summary; full lists at the end)

- **Staff Face ID attendance promoted to a Must-Before-GA design section** with the geofence→face→check-in/out
  architecture + the principal real-time attendance board.
- **Finance deep-dived into a Fee Recovery / Collections CRM** sub-area (call queue, promise-to-pay, contact
  history, recovery dashboard, collector performance, outstanding analytics, targets) — built by **expanding
  the existing defaulter list (old FIN-3)**, not duplicating it. Added installment due-schedule, late-fee
  accrual, cheque/PDC handling.
- **Phase 1 split into P1/P2/P3 bands** across all modules.
- **Appendix A refined:** merged/removed weak items, added Finance + staff-attendance decisions, defaults recommended.
- A few items merged/removed (see end).

---

## Counts (rev 2)

| Band | Items |
|---|---|
| GA (staff attendance: check-in/out · manual fallback · principal summary) | 3 |
| Cross-cutting foundations (P1) | 3 |
| P1 — Critical Operational | ~36 |
| P2 — Productivity | ~29 |
| P3 — Nice Improvement | ~8 |
| Ph2 | ~12 |
| Fut | 1 |
| Appendix A — Needs Owner Decision | ~26 |

---

# Must-Before-GA — Staff Attendance (Face ID)

> The **build** is already tracked as a GA blocker (PRODUCT_COMMERCIAL_BACKLOG O5 / Queue 2). This section is
> **not a duplicate** — it records the owner-approved **product design** and the **principal dashboard**
> enhancement that rides on it. It **improves** the existing read-only HR-04 staff-attendance screen
> (`hr_attendance_screen.dart`, which already shows Check-in/Check-out/Status/Geo/Face columns against
> seed/mock data) by wiring the real flow. **All staff-attendance config defaults are now decided and frozen
> (see the "Frozen config defaults" table below) — no open decisions remain in Appendix A for this track.**

| ID | Title | Design constraints | Cx | Tag |
|----|-------|--------------------|----|-----|
| **GA-1** | **Staff attendance check-in / check-out** (⚠ **CORRECTED 2026-07-01, FINAL** — [`ATTENDANCE_AUTH_DESIGN_DECISION.md`](ATTENDANCE_AUTH_DESIGN_DECISION.md)) | Flow: open Check-In → **geofence validation (configurable radius)** → **anti-mock location validation (reject mock/spoofed/low-accuracy/stale GPS)** → **live camera face verification** → on success **Check-In**; same flow for **Check-Out**. **MUST NEVER** use OS Face ID / fingerprint / Touch ID / PIN / password / device-biometric fallback (device OS biometric = app-login only). Retry a few times on failure. **Check-Out is NOT mandatory** (GA-D3). **Mid-day official movements** (Official Duty / Field Visit / Meeting → Return → Check-Out) are supported and **fully audited** — an official-duty exit is **not** a check-out (GA-D4). Completely **separate from login/logout** (login never affects attendance). Captures timestamp, geo (accuracy + anti-mock result), camera-face-verification result, on-time/late derivation, all movements, per staff per day. Wires the existing read-only HR-04 columns to real data. | L | GA |
| **GA-2** | **Exception workflows — Manual Attendance Request & Manual Close** | **(a) Manual Attendance Request** — the **only** path when geofence/biometric fail after retries (camera failure, GPS issue, official outdoor duty, device problem): staff submit with a **mandatory reason**; **Principal/HR approve or reject**. **(b) Manual Close** — when a staff member forgot to check out, **Principal/HR manually close** the open attendance with a **mandatory reason**. Both are **never automatic, no silent bypass**, and **fully audit-logged** (actor, decision, reason). | M | GA |
| **GA-3** | **Principal real-time staff-attendance summary** | Summary counts: **Total Staff · Checked In · Checked Out · Working Now · Late · Absent**. The live roster also carries each member's check-out status — **Working Now · No Check-Out · Manual Closed** — with the GA-2(b) Manual-Close action inline. Day/department filters; rolls up from GA-1 + GA-2. Feeds the monthly muster (HR-6) & payroll. Improves Operations Hub / HR-04 — do not create a separate dashboard. *Trends are a Future enhancement; GA = operational visibility only.* | M | GA |

**Frozen config defaults (staff attendance):**

| Setting | Frozen default | School-configurable? |
|---|---|---|
| **Late cutoff (GA-D1)** | **School Start Time + grace period** (e.g. 09:00 + 10 min → 09:00–09:10 On Time; after 09:10 Late) | Yes — start time + grace minutes per school |
| **Geofence radius (GA-D2)** | **100 m** | Yes — 50 / 100 / 150 / 200 / 300 m |
| **Check-Out (GA-D3)** | **Not mandatory** — open days show "No Check-Out"; Principal/HR Manual-Close (reason + audit, via GA-2b) | Behaviour fixed; closing is a Principal/HR action |
| **Mid-day exit (GA-D4)** | **Supported & audited** — Check-In → Official Duty / Field Visit / Meeting → Return → Check-Out | Behaviour fixed |

---

# Cross-cutting foundations (P1 — build first)

These unlock most reports and all reminders below. **No module may invent its own export or reminder system.**

| ID | Title | Why | Evidence / where checked | Cx | Tag |
|----|-------|-----|--------------------------|----|-----|
| **XCT-1** | **Shared Export / file-generation pipeline** (PDF + CSV/Excel) | Unblocks ~20 module reports; replaces a platform-wide dead stub | Every "Export/Download" button calls `showAksharaExportQueuedSnackBar` (`lib/shared/widgets/akshara_analytics_panel.dart`) — *"file generation pipeline is not connected yet."* Generalise the real per-row path in `lib/core/reports/akshara_report_export_service.dart` | L | P1 |
| **XCT-2** | **Shared Reminder & scheduling foundation** (scheduled-job runner + in-app reminder/notification centre) | "Foundation first" — every module reminder rides this | No cron/scheduled-job dir under `supabase/functions/`; rails reusable (`transport_write_handlers.ts` → `sendBroadcastMessage`). External push/SMS/WhatsApp delivery **stays owner-gated**; in-app surfacing ships now | L | P1 |
| **XCT-3** | **Date pickers for all free-text date fields** | Removes data errors across leave/correction/exam-create | Free-text date `TextField`s in `teacher_leave_screen.dart`, `leave_apply_form.dart`, `teacher_attendance_workflow.dart`, `exam_create_dialog.dart` | S | P2 |

---

# Admissions / Front-office

**Today:** lead/enquiry CRM (create/list/filter, stage stepper, lead score), follow-ups, call/note/WhatsApp
logging, applications, real document upload + approve/reject, principal approval queue, enrollment wizard
(auto admission number), fee handoff to Finance, dashboard + reports, settings.

| ID | Title | Pri | Cx | Lenses | Evidence (does NOT exist) |
|----|-------|-----|----|--------|---------------------------|
| **ADM-1** | Real admissions reports export (funnel/sources/counselors) — rides XCT-1 | P2 | M | 4 | Reports "Export" is the shared stub (`admissions_reports_screen.dart`) |
| **ADM-2** | Auto-log WhatsApp/call to lead timeline on send | P2 | S | 2,3 | `WhatsAppContactButton` only opens wa.me; clerk re-types via separate "Log WhatsApp" |
| **ADM-3** | Bulk lead actions (assign/stage on selection) | P2 | M | 2,3 | No select-all/checkbox in `lib/features/admissions/` |
| **ADM-4** | Inline actions on "Follow-ups due today" (complete/reschedule/call) | P2 | M | 1,3,5 | Dashboard row action just navigates to the Leads list |
| **ADM-5** | "New Application" from a real lead picker (remove placeholder default) | P2 | S | 1,3 | Falls back to "New Student / New Parent / class 5" when no cached lead |

---

# Student Information (SIS)

**Today:** student CRUD + status lifecycle, registry search/filter/CSV, per-student documents, Student 360
dossier (9 tabs + PDF), academic assignment (single + bulk), guardian linking, dashboard.

| ID | Title | Pri | Cx | Lenses | Evidence (does NOT exist) |
|----|-------|-----|----|--------|---------------------------|
| **SIS-1** | Bonafide / Study / Conduct certificate generation (print-ready PDF, English) | P1 | M | 1,3,6 | No certificate generator (`grep bonafide/conduct/study` = 0); only upload exists |
| **SIS-2** | Richer registry export + class-list / contact-sheet reports (parent name + phone) — rides XCT-1 | P2 | S–M | 4 | Registry CSV = 4 fields; directory API returns no phone |
| **SIS-3** | Document "Verify" action + status (write the unused `verified_by`/`verified_at`) | P3 | S | 1,3 | Columns exist but never written; no verify route |
| **SIS-4** | Family / sibling view for the clerk | P3 | M | 1,3,6 | Siblings grouped only for the parent app; SIS profile shows only this student's guardians |
| **SIS-5** | Transfer / exit log report (date-ranged, exportable) — rides XCT-1 | P2 | S–M | 4,6 | Only a `transferredStudents` count; no exportable list |
| **SIS-6** | Bulk document upload / per-class document drive | Ph2 | M | 2,3 | `handleUploadStudentDocument` is single-student only |

---

# Attendance (student)

**Today:** teacher period-wise marking (draft autosave + crash-resume, submit gate, all-present/absent),
**absentee→parent alert on submit (gated)**, correction workflow, parent/student monthly calendar.
*(Staff attendance → the GA section above.)*

| ID | Title | Pri | Cx | Lenses | Evidence (does NOT exist) |
|----|-------|-----|----|--------|---------------------------|
| **ATT-1** | **Office attendance register (AC-06)** — filter by class/date, named present/absent/late lists, read + export | P1 | L | 1,4 | A **specced P0** (`docs/Academic.md`, "read+export, no override") with **no screen**; office sees only an aggregate % KPI |
| **ATT-2** | Monthly class attendance register export (students × days grid, %) — rides XCT-1 | P1 | M | 4,6 | No register builder (`grep attendance.register` = 0); the canonical monthly artifact |
| **ATT-3** | Absentees-only fast-mark / "fill remaining present & submit" | P2 | S | 2,3 | Submit needs a fully-marked roster each period; only manual all-present/absent exist |
| **ATT-4** | Office "not-yet-marked" compliance monitor (by cutoff time) | P2 | M | 1,5 | `isPending` computed per teacher, never surfaced school-wide |

---

# Finance — Fees, Collections & Recovery

**Today:** fee structures + heads, assignment from admissions handoff, annual invoice (due hardcoded +30d),
collection counter (idempotent + row-locked) + auto receipt + receipt SMS (gated), receipt PDF, **defaulters
with aging buckets + WhatsApp**, discounts/scholarships, **refunds with maker-checker audit (done)**, daily
summary KPIs, settings (several inert: prefixes, late-fee %, due/overdue reminder days).

> Fenced off from tracked Phase-2 engines (Unified Payment Request, QR pay, offline reconciliation, full
> GL/accounting, dedicated expense module, in-product billing). Everything here is the **fee office's daily
> counter + recovery workflow**.

### 1 · Counter & receipting

| ID | Title | Pri | Cx | Lenses | Evidence (does NOT exist) |
|----|-------|-----|----|--------|---------------------------|
| **FIN-1** | Daily collection summary export (mode-wise totals; lock → FIN-D1) — rides XCT-1 | P1 | S | 4 | `getDailySummary` shown only as 4 KPI cards; no export |
| **FIN-2** | Printable student fee statement / ledger (all invoices + receipts + running balance) | P1 | M | 4,6 | Student-accounts panel shows summary only; data exists (`listAllCollectionsForAccount`) |
| **FIN-3** | Indian-format receipt polish (logo/letterhead, amount-in-words, signatory, ORIGINAL/COPY) | P2 | S–M | 6 | Receipt PDF has school **name text only** (`finance_receipt_pdf_service.dart`); English preserved |
| **FIN-4** | Admin duplicate-receipt reprint (surface existing provider + "DUPLICATE" stamp + audit) | P2 | S | 3,6 | `exportReceiptPdfProvider` exists but isn't wired into any finance screen |
| **FIN-5** | Batch receipt printing ("print today's receipts") | P2 | M | 2 | Counter records + prints exactly one receipt at a time |
| **FIN-6** | Installment / term-wise fee due schedule (replace hardcoded +30d; per-installment due dates) | P1 | M | 1,6 | Installment plans stubbed (`installmentOptions:[]`); due date hardcoded +30d. *Schedule definition is config; distinct from the tracked payment **rail**.* |

### 2 · Reporting & analytics

| ID | Title | Pri | Cx | Lenses | Evidence (does NOT exist) |
|----|-------|-----|----|--------|---------------------------|
| **FIN-7** | Day collection report (transaction-level: student/class/mode/ref/collected-by) + export | P1 | S | 4 | Reports export only emit catalog metadata, not transactions |
| **FIN-8** | Class-wise dues / collection report (export) | P1 | S–M | 4 | No class-grouped report; defaulters list is a flat top-200 by amount |
| **FIN-9** | Outstanding analytics (aging movement, recovery-rate trend, top defaulters, head-wise dues) | P2 | M | 4 | No outstanding-trend/recovery analytics; aging is a point-in-time bucket only |

### 3 · Fee Recovery / Collections CRM *(expands the old defaulter list — does NOT duplicate it)*

> The current defaulters screen lists who owes what (aging + WhatsApp) but its "Last contact" column is
> hardcoded empty (`finance_defaulters_handlers.ts` `lastContact:""`, `contactHistory:[]`). That stub is the
> seed for a real recovery CRM. Reminders ride **XCT-2**; exports ride **XCT-1**.
> **P1 recovery core = R1–R5 (dashboard · call queue · promise-to-pay · contact history · collector performance);
> P2 = R6 targets · R7 cheque/DD/PDC/bounce.**

| ID | Title | Pri | Cx | Lenses | Evidence (does NOT exist) |
|----|-------|-----|----|--------|---------------------------|
| **FIN-R1** | **Recovery dashboard** — outstanding by aging/class/route, target-vs-collected, recovered-this-period, top defaulters | P1 | M | 1,4 | No recovery/collections dashboard; defaulters screen is a flat list |
| **FIN-R2** | **Telecaller call queue** — prioritised "who to call today" worklist (by amount/aging/promise-date), one-click call/WhatsApp, log outcome — *folds the old due/overdue reminder worklist* | P1 | M | 1,2,3,5 | No call queue/worklist; reminders settings inert; no human follow-up surface |
| **FIN-R3** | **Promise-to-pay (PTP)** — capture promised amount + date; PTP-due worklist; kept/broken status | P1 | M | 1,5 | No PTP concept anywhere (`grep promise` = 0) |
| **FIN-R4** | **Contact / reminder history** per student — immutable log of every call/WhatsApp/SMS/visit + outcome | P1 | M | 1,5 | "Last contact"/contact history hardcoded empty; nothing persisted |
| **FIN-R5** | **Collector / telecaller performance** — calls made, PTPs obtained, ₹ recovered, conversion | P1 | M | 1,4 | No collector attribution or performance view |
| **FIN-R6** | **Collection targets** — set monthly target per collector/class; track attainment (target → Appendix FIN-D6) | P2 | M | 1,4 | No target concept; nothing to measure recovery against |
| **FIN-R7** | Cheque / DD handling — PDC register + bounce/return tracking + re-deposit | P2 | M | 1,6 | Collection modes are Cash/UPI/Card; no cheque lifecycle/PDC register |

*(Day-close lock, fee-head allocation rule, cancelled-receipt reason, concession approval formalization,
late-fee accrual policy, collection-target ownership → Appendix A.)*

---

# HR / Staff

**Today:** staff CRUD + status, documents (read-only), leave (per-row approve/reject + Approval Center), payroll
(process run; PDF export stubbed), staff attendance table (display), recruitment/performance, Employee
Intelligence (workload/burnout — shipped). *(HR Excel bulk import is tracked — excluded.)*

| ID | Title | Pri | Cx | Lenses | Evidence (does NOT exist) |
|----|-------|-----|----|--------|---------------------------|
| **HR-1** | Salary register export (per-employee Basic/Allowances/Deductions/Net + totals) — rides XCT-1 | P1 | M | 4,6 | Payroll export is a stub snackbar; reports emit 4 metadata rows |
| **HR-2** | One-click payslip run (per-employee PDF + "all for this run") | P1 | M | 2,3,6 | No `payslip` token anywhere; payroll only marks a run "processed" |
| **HR-3** | Batch leave approve/reject (multi-select / approve-all-pending) | P2 | S–M | 2,3 | Leave UI is strictly per-row; backend already loops |
| **HR-4** | Leave-balance report/export (employee × type) — rides XCT-1 | P2 | M | 4,6 | Balances computed per-employee only on profile; no school-wide report |
| **HR-5** | Headcount-by-department report/export — rides XCT-1 | P3 | S–M | 4,6 | Tile exports metadata only; `topDepartment` computed but not a report |
| **HR-6** | Monthly staff attendance **muster** export (employee × day grid) — rides XCT-1, **feeds from GA-1** | P1 | M | 4,6 | No muster/register export; the canonical monthly HR/payroll attestation |
| **HR-7** | Employee directory export (code/name/dept/designation/phone/join/status) — rides XCT-1 | P2 | S | 4,6 | No export on the employees screen |

*(Staff document-expiry tracking, probation-end follow-up, leave-on-behalf balance rule → Appendix A.
Birthday/anniversary greeting **removed** as weak — see change log.)*

---

# Exams *(top-priority module — O2)*

**Today:** exam lifecycle with coordinator-verify + principal-approve gate, per-student marks + remarks,
board-aware grading scales + rank toggle, **consolidated per-student term report card + single-student PDF**,
Exam Intelligence analytics (on-screen only). *(AI generators + secure CBT tracked — excluded.)*

| ID | Title | Pri | Cx | Lenses | Evidence (does NOT exist) |
|----|-------|-----|----|--------|---------------------------|
| **EXM-1** | **Fast bulk marks entry** (grid, Enter-to-next, **Save-all**) — *folds teacher save-all* | P1 | M | 2,3 | Per-row save only; backend has only single-mark PATCH. ~60 taps for a class of 30 |
| **EXM-2** | Marks-entry progress board across teachers/classes (who still owes marks before processing) | P1 | M | 1 | Only a per-exam "X/Y entered" counter; no school-wide completion view |
| **EXM-3** | Consolidated class mark sheet / tabulation register (students × subjects, totals/%/rank) export — rides XCT-1 | P1 | M | 4 | Marks CSV is single-exam/single-subject; no grid builder |
| **EXM-4** | Subject-topper + class merit / rank-order list export — rides XCT-1 | P2 | S–M | 4 | Rank computed but never produced as a printable merit list |
| **EXM-5** | Pass/fail & grade-distribution report export — rides XCT-1 | P2 | S | 4 | Exam Intelligence has no export/share/print |
| **EXM-6** | Marks-entry deadline + teacher reminder (in-app; external gated) — rides XCT-2 | P2 | M | 5 | No deadline field; no laggard-teacher nudge |
| **EXM-7** | Exam datesheet / timetable PDF for students & parents — rides XCT-1 | P2 | M | 4 | No datesheet concept; exams are independent rows |
| **EXM-8** | Comparative term analysis (Term 1 vs Term 2 per student/subject) | Ph2 | M | 4 | Report cards & analytics per-term only |

*(Hall tickets, seating plans, grace marks/moderation, supplementary/re-test, batch report-card print,
absent/"AB" status → Appendix A.)*

---

# Homework

**Today:** teacher create (free-text "due label") + per-submission review, student view/submit, parent view,
`homework.assigned` notification. *(AI homework/worksheet generators + Intelligence Bridge shipped.)*

| ID | Title | Pri | Cx | Lenses | Evidence (does NOT exist) |
|----|-------|-----|----|--------|---------------------------|
| **HWK-1** | **Real due-date picker** (replace free-text "due label") — keystone for reminders/overdue/sorting | P1 | S–M | 1,6 | Stores `due_label` free text; real `due_date DATE` exists only on the education-suite table. *Contract change.* |
| **HWK-2** | "Not submitted" list per assignment (names of non-submitters) | P1 | M | 1,4 | Only submission rows exist; no roster-diff |
| **HWK-3** | Same homework → multiple sections in one tap | P2 | M | 2,3,6 | Single `class_label` field; a teacher of 8-A/B/C re-types 3× |
| **HWK-4** | Teacher attachment on create (worksheet/photo) | P2 | M | 1,6 | Student row renders an attachment + column exists, but the create form has none (half-wired) |
| **HWK-5** | Homework history / export per class — rides XCT-1 | P2 | M | 4 | Export exists only for the AI-education path |
| **HWK-6** | Bulk "mark submitted" / "mark all reviewed" (paper homework) | P2 | M | 2,3 | Review is per-row bottom sheet only |
| **HWK-7** | Student submit with note/photo (wire existing `attachment_label`/`notes`) | P2 | S–M | 3,6 | DTO + column support it; the student UI submits bare (half-wired) |
| **HWK-8** | Homework "due tomorrow" reminder (in-app; external gated) — rides XCT-2 + HWK-1 | P2 | M | 5,6 | Only `homework.assigned` fires |
| **HWK-9** | Templates / "repeat last" (recurring reading log, weekly spellings) | Ph2 | M | 2,3 | No template/recurring concept |
| **HWK-10** | Class homework-load / clash view + principal oversight | Ph2 | L | 1,4 | No consolidated per-class/day view; AC-01 admin oversight specced, unbuilt |

---

# Communication / Notices

**Today:** broadcast composer + queue-drained delivery, multi-channel scaffolding (go-live gated), templates
CRUD, broadcast history, parent↔teacher threads, per-recipient read/mark-read, org-level delivery metrics.
*(AI assistant, Hub Expansion/WA Business/delivery analytics, posters, holiday-calendar authoring, push/SMS
go-live, parent-comms localization — tracked, excluded.)*

| ID | Title | Pri | Cx | Lenses | Evidence (does NOT exist) + distinctness |
|----|-------|-----|----|--------|------------------------------------------|
| **COM-1** | Per-broadcast delivery & read report + CSV export (sent/delivered/read/unread + unread names) — rides XCT-1 | P1 | M | 4 | `delivery_status` inserted 'pending', never updated; only org-wide metrics. The thin **per-notice** report, not the Phase-2 analytics platform |
| **COM-2** | Audience picker (class/section) + saved segments | P1 | M | 2,3 | Audience is a free-text box limited to 5 fixed presets; resolver has no class/section path |
| **COM-3** | Resend-to-unread (one tap) | P2 | S | 2,5 | Only "new broadcast" exists; `grep resend` = 0 |
| **COM-4** | Schedule-send (activate the dead `scheduled_at` column) — rides XCT-2 | P2 | M | 3 | `scheduled_at` exists but never written/read; no cron |
| **COM-5** | Save-broadcast-as-template / send-template-as-broadcast | P2 | S | 2 | Composer ignores the template store (free-text only) |
| **COM-6** | Message-history / thread export for a parent — rides XCT-1 | Ph2 | S–M | 4 | Threads readable in-app, no export |

*(Acknowledgement-required notices with signed-receipt log → Appendix A.)*

---

# Library

**Today:** add book, issue (14-day auto due), return + auto fine, fines + waive (audited), members + live loan
overlay, dashboard reports, digital resources. *(Textbook Book Distribution is a separate shipped module.)*

| ID | Title | Pri | Cx | Lenses | Evidence (does NOT exist) |
|----|-------|-----|----|--------|---------------------------|
| **LIB-1** | One-click overdue list screen + export — rides XCT-1 | P1 | S | 1,4 | Overdue exists only as a KPI count; no actionable list/export |
| **LIB-2** | Catalog edit/delete + CSV bulk import | P1 | M | 1,2 | Only `handleAddBook`; can't fix a typo or load a real catalog |
| **LIB-3** | Barcode quick issue/return (plain book barcode/ISBN scan) | P2 | M | 2,3,6 | Buttons say "Scan…" but open dropdowns; no scanner. (Plain book barcode — not student biometric) |
| **LIB-4** | Loan renewal / re-issue (capped) | P2 | S | 1,6 | No renew handler; a book can only close on return |
| **LIB-5** | Overdue-book reminder (in-app; external gated) — rides XCT-2 | P2 | M | 5,6 | UI says *"Overdue reminders … placeholder"*; no handler |
| **LIB-6** | Member library card / borrowing-history export — rides XCT-1 | Ph2 | S | 4,6 | No per-member history endpoint |
| **LIB-7** | Book reservation / hold queue | Fut | M | 1 | `reserved` enum exists, no workflow; low demand for target schools |

*(Issue guardrails — max books / block-on-fine → Appendix A.)*

---

# Transport (admin)

**Today:** route create/activate, vehicle list (insurance/fitness/GPS fields), driver list (license/rating),
student→route allocation + occupancy, transport attendance, **delay broadcast to parents (built)**.
*(Live GPS/parent map/driver app = Phase 2 — excluded.)*

| ID | Title | Pri | Cx | Lenses | Evidence (does NOT exist) |
|----|-------|-----|----|--------|---------------------------|
| **TRN-1** | Vehicle & driver registration (CRUD) | P1 | M | 1,6 | Both **seed-only** — no create handler; a school can't onboard its fleet |
| **TRN-2** | Vehicle-document expiry tracker (insurance/fitness/PUC/permit/road-tax, real dates) | P1 | M | 1,6 | Expiry fields are free-text strings; PUC/permit/road-tax not modelled |
| **TRN-3** | Stop-wise student roster + route roster print/export — rides XCT-1 | P1 | M | 1,3,4,6 | `pickupStop` is a string; no aggregation-by-stop or printable roster |
| **TRN-4** | Stop editor / ordered stop management on a route | P1 | M | 1,3 | `handleCreateRoute` writes `stops:[]`; no add/reorder UI |
| **TRN-5** | Bulk student → route allocation (by class/section) | P2 | M | 2,3 | Per-student dialog only |
| **TRN-6** | Student transport list + vehicle list exports — rides XCT-1 | P2 | S | 4,6 | Export is a stub |
| **TRN-7** | Route capacity / over-allocation warning at assign time | P2 | S | 1,6 | Occupancy exists at dashboard level; assign flow doesn't warn |
| **TRN-8** | Vehicle/driver document-expiry reminders (in-app; external gated) — rides XCT-2 + TRN-2 | P2 | M | 5,6 | No alert logic on expiry fields |
| **TRN-9** | **Transport fee structure + due schedule** (per route / stop / slab) → **creates fee demand** | P1 | M–L | 1,6 | No transport fee model today. **Architecture (owner-decided):** Transport defines routes/stops/vehicles/drivers/student-mapping/**fee structure + due schedule** and **raises the demand**; **Finance remains the only payment engine and collects** — no duplicate payment logic. Due schedule reuses the FIN-6 pattern |

---

# Inventory / Store

**Today:** asset registry (read-only), **procurement loop** (PO → approve → GRN/receive) + vendor create +
stock valuation + approval handoff (built), low-stock prediction + reorder recommendations (display only).
*(Asset lifecycle/depreciation/RMA = Future — excluded.)*

| ID | Title | Pri | Cx | Lenses | Evidence (does NOT exist) |
|----|-------|-----|----|--------|---------------------------|
| **INV-1** | Stock issue / consumption (stock-out) with issue slip | P1 | M | 1,6 | Stock only ever goes **up** via GRN; no issue/stock-out handler |
| **INV-2** | Consumable item registry + reorder-level CRUD | P1 | M | 1,6 | Store serves `asset` type only; no way to define a consumable/threshold |
| **INV-3** | Manual stock-adjust (non-PO stock-in, damage/wastage, opening balance) | P2 | S | 1,2 | Only GRN raises stock; no adjust handler |
| **INV-4** | Low-stock / reorder report + one-click "raise PO from recommendation" — rides XCT-1 | P2 | M | 3,4,6 | Copilot computes recommendations but there's no export and no link to `createPurchaseOrder` |
| **INV-5** | Stock register / consumption / GRN exports — rides XCT-1 | P2 | S | 4,6 | Reports export is a stub |
| **INV-6** | Physical stock-take / count session (counted qty → variance) | P2 | M | 1,6 | No count/stock-take handler; term-end verification is universal |
| **INV-7** | Low-stock alert/reminder to storekeeper (in-app; external gated) — rides XCT-2 | P2 | M | 5,2 | Risk alerts computed for display only; no dispatch |
| **INV-8** | Vendor performance / rating + on-time-delivery on the vendor record | Ph2 | M | 1,6 | Vendor has spend/active-orders but no rating |

---

# Teacher (persona / daily flow)

**Today:** home dashboard (schedule, pending tasks, 5 quick actions), attendance, exams, homework, today/timetable
with substitution chip, leave, class-teacher dashboard, deterministic parent-communication. All 18 teacher
endpoints route cleanly. *(Teacher Copilot + AI generators shipped.)*

| ID | Title | Pri | Cx | Lenses | Evidence (does NOT exist) |
|----|-------|-----|----|--------|---------------------------|
| **TCH-1** | "Mark attendance" directly from a today-schedule period row (deep link) | P2 | S | 3,6 | Today rows have no `onTap`; class taps fall through to the generic timetable |
| **TCH-2** | "Marks pending / deadline" surface on the teacher home — ties XCT-2 | P2 | M | 5,1 | Home pending-tasks list HW/messages/leave only; no marks |
| **TCH-3** | My-class summary export (attendance register / marks sheet) — rides XCT-1 | P2 | M | 4 | Zero export/CSV/PDF in `lib/features/teacher/` |
| **TCH-4** | Cover/substitution alert on home + cover visibility in the **weekly** timetable (in-app; push gated) | P2 | S–M | 5,6 | Cover shows only as a Today-screen chip; weekly model has no substitute fields |
| **TCH-5** | "Create homework" quick action on home (route exists, unused) | P3 | S | 3,6 | Home quick actions only offer "Homework" (= review) |
| **TCH-6** | Pending-task counts deep-link to a **filtered** view | P3 | S | 3 | `hw_review` opens the list unfiltered |
| **TCH-7** | Teacher timetable export/share — rides XCT-1 | P3 | S | 4,6 | Timetable screen is view-only |
| **TCH-9** | **"My Attendance" (read-only) for all staff** — Today · Yesterday · This Month · Check-In time · Check-Out time · Working Hours · Late Days · Manual Overrides | P1 | M | 1,6 | No self-service staff attendance history screen; data comes from GA-1/GA-2. Read-only |
| **TCH-8** | Global section/class quick-switcher (carry active section across surfaces) | Ph2 | M | 3 | Each screen re-selects class independently |

---

# Principal (single-school command)

**Today:** **Unified Approval Center** (single-select approve/reject + audit), Operations Hub (health/alerts —
shipped), Principal Command/Intelligence Center (shipped), management dashboard with **KPI drill-down (built)**
+ dashboard PDF export, stale-pending count (computed, inert).

| ID | Title | Pri | Cx | Lenses | Evidence (does NOT exist) |
|----|-------|-----|----|--------|---------------------------|
| **PRI-1** | Batch approve/reject in the Approval Center (multi-select) | P1 | M | 2,3 | Queue is strictly single-select; principal clears 5–15/day one by one |
| **PRI-2** | Unsubmitted / pending exam-marks exception list (shares EXM-2 data) | P2 | M | 1 | Pending-marks exists only teacher-side; nothing in principal_command |
| **PRI-3** | Daily school report (compose Operations Hub snapshot → PDF/share) — rides XCT-1 | P2 | M | 3,4 | Operations Hub has the data but no export/digest |
| **PRI-4** | Weekly principal digest (in-app summary card) — ties XCT-2 | P3 | M | 5 | No weekly digest; only an on-page monthly summary |
| **PRI-5** | Pending-approval reminder / escalation (surface the inert stale-count) — ties XCT-2 | P3 | S | 5 | Stale (>48h) count computed but inert |

---

# Director (multi-school / chain)

**Today:** executive dashboard, schools, portfolio, revenue, growth, marketing, admissions, compliance,
reports — live org aggregates; **board-pack PDF export (built)**; AI executive summary; per-school health.

| ID | Title | Pri | Cx | Lenses | Evidence (does NOT exist) |
|----|-------|-----|----|--------|---------------------------|
| **DIR-1** | Cross-school league table (sortable / ranked by any metric) | P2 | S | 1,3 | Schools render unranked (ORDER BY name); "Compare Schools" is a dead filter label |
| **DIR-2** | Consolidated collection report (per-school fee % + outstanding, exportable) — rides XCT-1 | P2 | M | 4 | Only the all-in-one board pack exists |
| **DIR-3** | CSV/Excel export of the school-comparison table — rides XCT-1 | P3 | S | 4 | Export = PDF board pack only |

*(Per-school drill-down "Open Management Portal" — cross-persona scoping — → Appendix A.)*

---

# Parent (persona / self-service)

**Today:** bottom-nav shell + child-switcher (one active child), dashboard, attendance calendar + correction
dispute, homework view, exams + **report-card PDF (built)**, fees + Pay-Now + **per-receipt PDF (built)**, leave
(apply + history), PTM (read-only), transport, notices, events, messages, notifications inbox.

| ID | Title | Pri | Cx | Lenses | Evidence (does NOT exist) |
|----|-------|-----|----|--------|---------------------------|
| **PAR-1** | Surface PTM Accept/Decline (RSVP) — backend `POST /parent/meetings/:id/rsvp` already exists | P2 | S | 1,6 | Endpoint exists but no UI/mutation (half-wired) |
| **PAR-2** | "Apply Leave" as a dashboard quick action | P2 | S | 1,3 | Buried under Profile → Leave (3+ taps) |
| **PAR-3** | Medical-certificate upload on leave (real file picker → storage) | P2 | M | 1,6 | Attach is a stub (`attachmentName` hardcoded); no picker |
| **PAR-4** | Payment-history export (year statement PDF/CSV) — rides XCT-1 | P2 | M | 4 | History is a view-only sheet; no export |
| **PAR-5** | In-app proactive reminder banners (fee due / exam / PTM / form) — ties XCT-2 | P2 | M | 5,6 | Only a lone mock AI fee tip |
| **PAR-6** | Surface PTM action-items / follow-ups + a real "next PTM" hero | P3 | S–M | 1,6 | Model has `actionItems`/`followUps`; parent screen renders neither |
| **PAR-7** | Event RSVP actionable | Ph2 | S–M | 1,6 | `isRsvpOpen` shown as a count only; needs new endpoint |
| **PAR-8** | Add-to-calendar (.ics) for PTM / events / approved leave | Ph2 | M | 1,6 | No `.ics`; events lack machine-readable start/end DateTime |

*(All-children family view, annual fee/80C certificate, consolidated "action inbox", parent event/holiday
calendar view, cancel-leave, consent/permission slips → Appendix A.)*

---

# Reject / Merge (with reasons)

| Item | Disposition | Reason |
|------|-------------|--------|
| Manual "message parents of today's absentees" (teacher) | **Reject** | Already built — absentee→parent alert auto-fans-out on attendance submit (gated); ad-hoc re-send covered by **COM-3**. |
| "Save all marks" teacher action | **Merge → EXM-1** | Same capability as fast bulk marks entry. |
| Homework load view + principal homework oversight | **Merge → HWK-10** | Two framings of one consolidated per-class homework view. |
| Per-screen date pickers (teacher/parent leave, correction, exam-create) | **Merge → XCT-3** | One cross-cutting UX fix. |
| Finance due/overdue reminder worklist (old FIN-9) | **Merge → FIN-R2** | The telecaller call queue *is* the recovery worklist; reminders ride XCT-2. |
| Old defaulter "call-list with last-contacted" (old FIN-3) | **Split → FIN-R1…R4** | Expanded into the recovery CRM (dashboard, queue, PTP, history). |
| HR birthday / work-anniversary greeting | **Remove** | Weak / nice-to-have, not a daily-operations need; can return as a Future idea if requested. |

---

# Appendix A — Needs Owner Decision

Kept **out of the main backlog** until you decide. Each is a real, evidenced candidate; only a
behaviour/policy/format/semantics choice is missing. After you decide, it moves into the band shown.

### Staff Attendance (GA)
*All staff-attendance config defaults and the failure/missed-check-out fallbacks are **decided and frozen** —
see the GA section's "Frozen config defaults" table and GA-2. **No open decisions remain** for this track.*

### Finance
| ID | Decision needed | Recommended default | → Band |
|----|-----------------|---------------------|--------|
| **FIN-D1** | Day-close lock — block back-dated entries; who reopens? | Lock with supervisor reopen + audit | P1 |
| **FIN-D2** | Fee-head allocation rule when a part-payment is made (enables head-wise dues) | Priority order (tuition first), configurable | P1 |
| **FIN-D3** | Require a reason on receipt cancellation (+ cancelled register) | Yes — require reason | P1 |
| **FIN-D4** | Concession approval — formalize maker-checker (who approves; capture approver/time/reason). ⚠ prereq: per-student concession persistence is in-memory (a **defect** → QA) | Maker-checker like refunds | P1 |
| **FIN-D5** | Late-fee accrual — grace days, %, cap, per-head or flat, manual-waive path (wires the inert `late_fee_percent`) | Flat % after N grace days, with waive + audit | P2 |
| **FIN-D6** | Collection-target ownership — who sets targets (per collector/class/month) and visibility | Principal sets; collectors see own | P2 |

### Admissions
| ID | Decision needed | Recommended default | → Band |
|----|-----------------|---------------------|--------|
| **ADM-D1** | "Mark Lost" reason taxonomy + lost-reasons report | Small fixed picklist (fees-high/competitor/distance/other) | P2 |
| **ADM-D2** | Duplicate-lead by phone — warn vs hard-block | Warn-only with "open existing" | P2 |
| **ADM-D3** | Admission-number scheme — human sequential (PREFIX/YEAR/serial) + reset-per-year? ⚠ back-compat with existing `ADM-…` | Configurable prefix + per-year serial; keep old numbers valid | P1 |
| **ADM-D4** | Offer/admission-confirmation letter — template/branding/fields | Standard template + branding (admission no/class/fee/reporting date) | P2 |

### Student Information
| ID | Decision needed | Recommended default | → Band |
|----|-----------------|---------------------|--------|
| **SIS-D1** | TC engine — Finance no-dues gate? auto status→transferred? TC numbering/register? | Yes to all (no-dues gate, auto-status, sequential register) | P1 |
| **SIS-D2** | ID-card batch — layout/fields; depends on student-photo capture | Standard template; first confirm photo storage exists | P2 |
| **SIS-D3** | Mandatory-document set for the compliance report | Configurable required-doc list per school/board | P2 |

### HR
| ID | Decision needed | Recommended default | → Band |
|----|-----------------|---------------------|--------|
| **HR-D1** | Staff document-expiry — which doc types + reminder lead time (adds expiry field) | Police-verification/medical/contract/licence; 30-day lead | P2 |
| **HR-D2** | Probation-end follow-up — add probation-end date + lead time + confirm/extend | Yes; 15-day lead | P2 |
| **HR-D3** | Leave-on-behalf — block vs warn on insufficient balance; half-day support | Warn + override with audit; support half-day | P2 |

### Attendance
| ID | Decision needed | Recommended default | → Band |
|----|-----------------|---------------------|--------|
| **ATT-D1** | Consecutive-absence escalation threshold + policy | 3 consecutive days → office list + (gated) alert | P1 |
| **ATT-D2** | Short-attendance list threshold (boards differ) — configurable? | Default 75%, configurable | P2 |
| **ATT-D3** | Half-day mark + auto-mark approved leave as "excused" on the roster | Add half-day; auto-mark approved leave | P1 |

### Exams
| ID | Decision needed | Recommended default | → Band |
|----|-----------------|---------------------|--------|
| **EXM-D1** | Batch report-card print — who/where triggers; pre/post publish | Coordinator-triggered, post-publish | P1 |
| **EXM-D2** | Grace marks / moderation — who, when, audit, parent visibility | Coordinator at verify; full audit; not shown to parents | P1/P2 |
| **EXM-D3** | Supplementary / re-test result rule — replace vs best-of vs separate line | Separate line, configurable | Ph2 |
| **EXM-D4** | Hall-ticket / admit-card content — fields, photo, seat, instructions | Standard board-style template | P1 |
| **EXM-D5** | Seating-arrangement strategy — roll-order vs mixed-class | Mixed-class default, configurable | P1 |
| **EXM-D6** | Absent / "AB" status — render on card; counts toward rank/average? | Show AB; exclude from average; not ranked | P1 |

### Communication
| ID | Decision needed | Recommended default | → Band |
|----|-----------------|---------------------|--------|
| **COM-D1** | Acknowledgement-required notices with signed-receipt log — acknowledge-vs-read workflow | Explicit "Acknowledge" action + receipt log | P1/P2 |

### Library
| ID | Decision needed | Recommended default | → Band |
|----|-----------------|---------------------|--------|
| **LIB-D1** | Issue guardrails — max books per member + block-on-outstanding-fine thresholds | Configurable (e.g. max 2; block above ₹ threshold) | P2 |

### Homework
| ID | Decision needed | Recommended default | → Band |
|----|-----------------|---------------------|--------|
| **HWK-D1** | "Not submitted" nudge to parent after due date (auto-chasing is a behaviour change) | Opt-in, teacher-triggered (not automatic) | P2 |

### Director
| ID | Decision needed | Recommended default | → Band |
|----|-----------------|---------------------|--------|
| **DIR-D1** | Per-school drill-down ("Open Management Portal") — cross-persona scoping/RBAC traversal | Scoped read-through with audit | P2 |

### Parent
| ID | Decision needed | Recommended default | → Band |
|----|-----------------|---------------------|--------|
| **PAR-D1** | May parents cancel/withdraw a pending leave request? | Yes, before approval | P2 |
| **PAR-D2** | Consolidated "all my children" family view (totals + per-child snapshot) | Yes — a combined home for multi-child parents | P2 |
| **PAR-D3** | Annual fee / 80C-style fee-payment certificate — format/branding/signatory | Yearly paid-fees certificate with branding | P1 |
| **PAR-D4** | Consolidated "what needs my action" inbox (fees + homework + PTM + forms) + prioritization | Yes — single action inbox; fees/PTM first | P2 |
| **PAR-D5** | Parent month-calendar of events & holidays — scope split vs the tracked holiday-calendar *authoring* item | Build the parent **read/view** side; authoring stays the tracked item | Ph2 |
| **PAR-D6** | Parent-facing consent / permission-slip approval (trip/photo/activity) | Defer | Ph2 |

---

# Out of scope — defects observed (route to the QA program, NOT this backlog)

Honesty/quality issues found while reviewing — they belong in the QA tracker:

- **Platform-wide:** every "Export/Download" button is a dead stub (`showAksharaExportQueuedSnackBar`) — real fix is **XCT-1**.
- **HR:** leave-create dialog hardcodes `employeeId: 'HR-EMP-102'` (no picker).
- **Finance:** per-student concession assignments are in-memory only (not persisted) — prerequisite for **FIN-D4**.
- **Admissions:** "New Application" creates placeholder junk rows when no lead is cached (fixed by **ADM-5**).
- **Teacher:** one parent-communication provider path reads a mock canonical student registry — verify live wiring.

---

# Relationship to existing backlogs (no duplication)

- **PRODUCT_COMMERCIAL_BACKLOG.md** — scope/commercial/owner decisions; honoured (O1–O10). Staff Face ID **build** remains its item (O5); this doc adds only the **design** (check-in/out flow + GA-2 manual-request fallback), the **principal summary** (GA-3), and staff self-service **"My Attendance"** (TCH-9) — not a competing build item.
- **Transport fee (TRN-9)** does **not** conflict with the tracked Phase-2 payment engine or SaaS monetization (O6): Transport only **defines** fee structure + due schedule and **raises demand**; **Finance** stays the sole payment/collection engine. Live GPS tracking remains Phase-2 (O8) and is untouched.
- **FutureVision.md / ImplementationRoadmap.md** — future capabilities (many shipped ✅). Excluded.
- **IDEAS_BACKLOG.md** — TTS, AI School Builder, posters/holiday-calendar **authoring**, deployment model, backup follow-ups. Excluded (PAR-D5 adds only the parent **read** side).
- **FINAL_QA_ROADMAP.md / FINAL_QA_MASTER_TRACKER.md / QW1–QW8 / EOS ledger** — **frozen**; defects above route there, not here.

**Next step:** owner reviews this → resolves Appendix A → approves → *then* the roadmap is updated and
implementation begins. Nothing is started, committed, or roadmapped by this document.
