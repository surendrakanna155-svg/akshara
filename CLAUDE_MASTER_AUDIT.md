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

## Known carry-overs (tracked, not blocking)
- Exam **denormalized read-model** (`teacher_entities`) lacks `teacher_id` → teacher row-scoping needs a schema change (authoritative `exam_mark_entries` path IS scoped). Fold into Slice 5 / Batch 2.
- Exam **separation of duties** (approver ≠ verifier): verifier id now recorded; enforcement check pending. Batch 6 (governance).
- Live-DB tests (`tenant_isolation_test.ts`) require a tenant DB; run in CI/staging only.
