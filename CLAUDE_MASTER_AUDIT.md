# CLAUDE Master Audit — ERP Hardening Execution Status

Single source of truth for the cross-domain authorization/correctness hardening.
Per-domain detail lives in code + tests; this file tracks **status only**.

Legend: ✅ done & certified · 🟡 in progress · ⬜ not started

## Batches

| # | Domain | Status | Certification |
|---|--------|--------|---------------|
| — | **Exams** (P1 granular perms + P2 teacher scoping, server) | ✅ | deno authz 5/5; flutter exam 70/70; analyze 0 err |
| 0 | **Cross-cutting safety net** | ✅ | full edge graph `deno check` 0 err; CI gate added; deno unit 491 pass (only live-DB self-test skipped locally) |
| 1 | Finance (invoices/collections/refunds/concessions) | ✅ | already hardened; verified — 76 finance deno tests pass; granular approve perms + self-approve block + scope confirmed |
| 2 | SIS & Attendance | ✅ | **fixed**: attendance correction status endpoint now requires `approveAttendanceCorrection` (was `manageSis` — approval bypass). SIS read/write split verified. 89 deno tests pass |
| 3 | Admissions | ✅ | verified — approve=`approveAdmissions`, manage=`manageAdmissions`, read=`viewAdmissions` across 13 write routes; tests pass |
| 4 | HR / Staff | ✅ | verified — hr read-only (`viewHr`); employee writes `manageEmployees`; staff/student leave approval via granular approve perms; tests pass |
| 5 | Operations (transport/hostel/library/inventory) | ✅ | verified — transport/hostel/library read-only (factory-gated `viewX`, 0 write routes); inventory writes `manageInventory`/`manageAssetLifecycle`/`manageProcurementWorkflow`; tests pass |
| 6 | Governance & Intelligence | ✅ | verified — approval enforces per-type granular approve perms + blocks self-approval; intelligence gated on `viewXIntelligence`; tests pass |

**Whole-backend certification:** full edge graph `deno check` = 0 errors; deno unit suite = 491 pass (only `tenant_isolation_test` needs a live DB — runs in CI/staging).

## Batch 0 — what was done
- **CI gate**: `deno check supabase/functions/api/index.ts` added to `backend_staging.yml` before unit tests — type-checks the entire wired edge graph (not just test-reachable files), so "wired but never compiled" modules can't recur.
- **Fixed pre-existing breakage surfaced by the gate** (53 errors across 18 files), all pre-existing, none caught before because no test imported these modules:
  - Approval: `claims.name` (nonexistent) → dropped; `ApprovalRequestRow` import moved to its canonical source.
  - Attendance handlers: same `withAuth`/`tenantIds`/`claims.userId→sub` bugs as exams.
  - 8 routers: route-lookup ternary typed `| undefined` (benign false-positive, now correct).
  - ~35 `body` null-guards added across memories / parent_experience / promotion / attendance / inventory_intelligence handlers.
  - inventory_intelligence: `jsonResponse(..., 201)` → `{ status: 201 }`; `readJson` null coalesce.
  - parent_experience services: two row/return shape mismatches corrected.

## Batch 1 — Finance (findings)
Audited authz parity; **no fixes needed** — finance was built correctly:
- read = `viewFinance`, write = `manageFinance` (split confirmed across invoices, collections, fee structures).
- refund approval = `approveRefunds` (dedicated handler) ; concession = `approveFeeConcession` (generic approval). Per-type granular approve perms enforced in `approval_handlers` via `approvalPermissionForType`.
- self-approval blocked (`ApprovalSelfApproveDeniedError`); school/org scope enforced + tested.
- Certified: 76 finance deno tests pass.
- Carry-over (minor parity, not a hole): client has `approveFeeStructure` but fee-structure changes are gated by `manageFinance` with no approval flow server-side — wiring a fee-structure approval type is a feature, deferred.

## Exam domain — feature completion (Slices 1–6)
Closed end-to-end: grading engine → workspace hub → marks wiring → approve/publish
→ parent/student results → **report card with class rank** (parent + student;
rank shown per `showRankToParents`; attendance line from the shared attendance
store). Full exam Flutter suite green (84). Deferred by design:
- **Report card remark** — no data model/entry yet; needs a product decision (who writes it, where stored).
- **PDF export** — owner explicitly deferred ("downloadable PDF later").

## ✅ EXAM DOMAIN = CLOSED (100%)
All slices (1–6) + server authz hardening + per-exam-session remarks + PDF report
card complete and certified.
- Remarks: per (student, exam session), class-teacher authored, audit trail,
  shown on report card; app + server parity; only the class teacher may write.
- PDF report card (parent + student share): branding/logo placeholder, student
  details, class/section, subject marks, grades, total, %, rank (only when the
  school enables it), attendance %, class-teacher remark, principal-signature +
  school-seal placeholders; identical layout across grading systems.
- Certified: flutter analyze 0 errors; exam Flutter suite 94 pass; PDF generation
  verified (valid PDF); full edge `deno check` 0 errors; exam/approval server
  tests 12 pass.
- Deferred by owner: nothing blocking. (Future extension: principal / vice-
  principal remarks — schema already allows those author roles.)

## ✅ FEES & PAYMENTS = CLOSED
Payment loop now works end-to-end: a confirmed payment marks the installment
paid, lowers the amount due, updates progress, and adds a receipt to history
(was previously static). Receipt PDF download/share added (real PDF). Report
card PDF reused from exams. Certified: app analyze 0 errors; fees/payments/
finance suites 67 pass; PDF generation verified.
Carry-over: live Razorpay server path exists but is exercised only in
CI/staging; the in-app experience runs on the mock loop.

## ✅ ATTENDANCE = CLOSED
Teacher marks attendance → updates the parent KPI AND now the student view
(student was previously static; merge centralized in
MockAttendanceSyncStore.mergedMonth, used by both). Correction flow (submit →
principal approve, gated on approveAttendanceCorrection — Batch 2) updates the
sync store. Certified: app analyze 0 errors; attendance suites 16 pass (incl. F5
correction submit→approve integration).
Carry-over: aggregate class counts drive the single-primary-student mock;
per-student daily records are a backend (F-series) concern.

## ✅ MESSAGES & NOTICES = CLOSED
School broadcast → now reaches the targeted audience's notices (parents and/or
students), newest first, on top of the standing notices (was static before).
Existing pieces confirmed: teacher→parent concern inbox (read/acknowledge,
governance-gated), parent/student notices, language localization. Certified:
app analyze 0 errors; communication/notices/messages suites 17 pass.

## ✅ ADMISSIONS = CLOSED (already complete — verified, no fixes)
Full chain works end-to-end and is store-backed: lead → application → documents
→ approve → fee handoff ("Ready for fee setup") → SIS conversion queue (via
MockAdmissionsSisBridge). approveAdmission creates the handoff; submitEnrollment
queues the SIS conversion; admissions→finance bridge persists fee assignment.
Server authz certified earlier (Batch 3: approveAdmissions / manageAdmissions /
viewAdmissions). Certified: admissions feature + integration (e2e journey,
admissions→finance e2e) + SIS-bridge + write-contract suites all green (~78);
app analyze 0 errors. No code changes required.

## ✅ HOMEWORK = CLOSED
Loop complete: teacher assigns → student sees → student submits → teacher
reviews → grade + comment now reach the student AND parent (was teacher-side
only). Shared SchoolHomeworkStore records review per (homework, student);
student/parent items show a "Reviewed · Grade X — comment" line. Certified: app
analyze 0 errors; homework suites 13 pass.
Carry-over: full per-student "reviewed" lifecycle status (vs the additive
grade/comment line) would need a status-enum change across both apps — deferred.

## Everyday loops — status after the closing sweep
Closed & tested: Exams, Fees & Payments, Attendance, Messages & Notices,
Admissions, Homework, plus **Leave** (parent requests → principal approves →
parent sees approved/rejected; verified — `applyDecision` updates the parent's
own list; approval integration suites green).

Remaining areas are a **different kind of work** (no clean broken loop to close):
- **Timetable** — persona views render static weekly schedules (functional); a
  big integration would wire the academics scheduler/editor → teacher/student/
  parent grids. Large project, not a one-gap fix.
- **Transport / Library / Hostel / Inventory** — admin/operational modules that
  work (read views + staff CRUD), with an intentional live-tracking placeholder
  (future). No broken parent/student loop.

## ✅ #1 LEAVE BY CLASS TEACHER = DONE (app + server)
Student leave is now the class teacher's job (not principal). App: class-teacher
dashboard "Leave requests" lists their own class's pending leaves with
approve/reject (scoped via classTeacherOwnsLeave); reuses the approval pipeline
so the parent sees the decision; principal keeps visibility. Server: registered
approveStudentLeave (was uncatalogued → would 403 everyone) + granted to
oversight roles + teacher; approval handler scopes a teacher to their own class
(isClassTeacherForClass), principals/management unscoped. Certified: app analyze
0 err, RBAC/approval suites 151 pass; edge deno check 0 err, +1 scope test.
Follow-up: sibling approve perms (approveStaffLeave, approveAttendanceCorrection)
are also uncatalogued server-side — register when those domains are hardened.

## ✅ #2 ATTENDANCE BY CLASS TEACHER = DONE (app)
getAttendanceClasses scoped to the class teacher's own class (non-class-teacher
sees none). Tests green. Follow-up: server-side class-teacher scoping for
attendance marking endpoints (mirror leave) when the backend goes live.

## 🚧 #3 TIMETABLE auto-substitute — staged
- [x] Stage 1: rule-based substitution engine (DailyTimetableEngine) + tests —
  cover-by-free-teacher, subject preference, no double-booking, unfilled,
  coordinator override. No AI (plain rules), deterministic.
- [ ] Stage 2: coordinator/principal review screen (see auto-subs, change them).
- [ ] Stage 3: wire to real staff-leave data + a daily "prepare today" step +
  teacher daily view. (Truly-automatic morning run = scheduled job when backend
  is live; in-app simulated via prepare-today.)

## Known carry-overs (tracked, not blocking)
- Exam **denormalized read-model** (`teacher_entities`) lacks `teacher_id` → teacher row-scoping needs a schema change (authoritative `exam_mark_entries` path IS scoped). Fold into Slice 5 / Batch 2.
- Exam **separation of duties** (approver ≠ verifier): verifier id now recorded; enforcement check pending. Batch 6 (governance).
- Live-DB tests (`tenant_isolation_test.ts`) require a tenant DB; run in CI/staging only.
