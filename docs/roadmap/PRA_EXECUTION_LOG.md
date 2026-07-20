# PRA Remediation — Cumulative Execution Log (Durable Checkpoint)

> **RESUME PROTOCOL.** When the owner says **"continue roadmap"**, a new session must:
> 1. Recall Memory (`pra-remediation-execution-state`) → it points here.
> 2. **Work in the worktree** `/Users/surendrakanna/Documents/Akshara_ERP-pra` (branch `feature/erp-pra-remediation`) — **NOT** the main worktree (which holds the disjoint QP/curriculum lane on `feature/qp-content-readiness`).
> 3. Read this log top-to-bottom, then continue from the **CHECKPOINT** section at the bottom. Never repeat committed work.

- **Branch:** `feature/erp-pra-remediation` — worktree `/Users/surendrakanna/Documents/Akshara_ERP-pra`. **NOT pushed** (owner instruction — do not push any branch).
- **Authority / full plan:** `PRA_FIX_STRATEGY.md` §12.1 stage map (S0–S7). That file is on the **main** worktree at `docs/roadmap/PRA_FIX_STRATEGY.md` (it is not committed on this branch). The frozen 117-item register is `FINAL_EXECUTION_MASTER_ROADMAP.md` §PROGRAM PRA — **FROZEN, never rewrite**.
- **Test invocation:** backend `deno test --allow-all --no-check <path>`; Flutter `flutter test <path>` + `dart analyze <files>`. No root task runner.
- **Migration band:** PRA uses `20260900000000`–`20260900000014` so far. **Next free = `20260900000015`.** (DRP/PRC band `20260877–890` is a different lane — do not reuse.)
- **Per-stage rule (owner):** full affected-area regression green + EOS gate (PASS / CONDITIONAL PASS) before the next stage; commit every completed stage; isolated commits.

---

## Stage status

| Stage | Scope | Status | Commit |
|---|---|---|---|
| **S0** | Honesty / delete-the-lie / gate | ✅ committed | `1b893f6d` |
| **S1** | Money & stock integrity | ✅ committed | `e4807308` |
| **S2** | Identity Lifecycle & Revocation (ILR · C1) | ✅ committed | `8e75616b` |
| **S3** | Pilot-lane governance / canonical teacher↔class | ✅ committed | `972836b7` |
| **S4** | Reporting & metric integrity | ✅ **COMPLETE** | `005695d5` (metric core) + `64e086da` (report card / export / queues) |
| **S5** | Communication & delivery | ✅ **COMPLETE** | `fbbb7634` |
| **S6** | Academic-operations blockers | ✅ **COMPLETE** (all 11 items; P1-17 landed with S7) | `355637e0` + `f5bc4558` (+ P1-17 in `808504d1`) |
| **S7** | Operational-module blockers | ✅ **COMPLETE** (CONDITIONAL PASS; large/owner P1s tracked) | `808504d1` |

---

## S0 — Honesty / delete-the-lie / gate  ✅ `1b893f6d`
27 files. Removed pilot route shadow (P0-12), dispatch-uniqueness test (N-14), exam
approval real repo (P0-05/N-9), surface-gate branch/franchise/resource-opt (N-7/8),
parent repo fail-closed (P0-17 + **N-10/N-11 parent-ack fail-closed**), teacher→parent
timeline live, delete-the-lie (P0-24 B5-C claim/dead-link / P1-40 / P1-50), mock-import
ratchet guard (T2-H). Regression green.

## S1 — Money & stock integrity  ✅ `e4807308`
25 files, +2209/−89. Money-race guards (P0-03 refund, P0-04 collection-cancel, M-2
capture, P2-10 GRN, M-1 replacement) via claim-first / FOR UPDATE + guarded terminal
write. Payment wiring **P0-02 backend fail-closed** (client SDK still pending → S7).
Stock P1-37/38. Finance P1-11/P1-10. Owner-approved P1-09 (cheque register sole path) +
P1-08 (gapless FY receipt series). Migration `20260900000000`. Regression green.

## S2 — Identity Lifecycle & Revocation (ILR · C1)  ✅ `8e75616b`
23 files, +2194/−8. EOS: CONDITIONAL PASS. Regression 335/0 + api graph clean.
P0-01 revocation primitive + HR-offboarding wiring; P1-01 2nd-guardian link/unlink;
P1-02 RLS active-link + unlink writer; P1-03 refresh children; P1-04 safety-core
deterministic resolution; P1-05 officeStaff grants + override write; P1-06 OTP crypto
RNG; P1-07 context-switch through assertSessionValid (C2 backstop); P1-53 audit read
route; P2-34 permissions_version trigger. Migrations `…010`, `…011`, `…012`.
**Live-lane follow-up:** one-time blast-radius audit for legacy non-'active' membership
rows before the live cut-over (needs VPS DB).

## S3 — Pilot-lane governance / canonical teacher↔class  ✅ `972836b7`
11 files, +~900. EOS: CONDITIONAL PASS. Regression 810/0 + api graph clean.
P0-08 canonical helpers (teacher_subject_assignments); P0-07 repointed teacher class/
attendance readers off the unwritten timetable_slots; P0-11 ownership guards (attendance
draft/submit + homework); P0-10 exam-remark author server-resolved + backfill mig `…014`;
P0-09 FK academic_timetable_periods.teacher_id→users(id) mig `…013`; P1-16 subject
authority canonical; P1-31 per-period DISTINCT.
**Deployment GATE (live lane):** fail-closed guards require the tenant's
`teacher_subject_assignments` populated (school-completion wizard) before enabling, or
plain teachers 403. Migs `…013`/`…014` apply on VPS.

## S4 — Reporting & metric integrity  ✅ `005695d5` + `64e086da`
**Correction to the prior checkpoint:** S4 is **fully complete**. The prior log recorded
it as PARTIAL because the session hit an API limit mid-stage; the tail was finished and
committed in `64e086da` *after* that log was written.

- `005695d5` (metric core, 3 files): P0-22 management attendance % → canonical
  `attendedDaysSql`/`attendanceDenominatorSql`; P2-22 per-class grouping; P0-23 Revenue
  MTD → month-to-date; P1-47 defaulters → Finance `overdueDaysSql>0`. Census confirmed
  management was the sole inline attendance divergence. Regression 429/0 + api graph clean.
- `64e086da` (tail, 8 files): **P0-06** student report card → server-backed published
  results (`studentExamsProvider` → GET /student/exams) — was a never-hydrated local seed
  store bound to a mock student id; **P1-32** parent report card same fix (scope already
  correct); **P1-49** finance report export → real data rows via XCT-1 grid (was a 3-row
  metadata stub with a fake success snackbar); **P1-48** management dashboard approval
  queue + recent-conversions populated from real sources (revenueTrend/expenseBreakdown/
  enrollmentTrend left HONESTLY empty — no data source exists, not faked). Regression
  management 15/0 + api graph clean; Flutter report-card 100+/0, finance-reports 58/0;
  `dart analyze` clean; no goldens changed.
- **Tracked P1 follow-ups:** report-card rank/remarks/grading-scale/attendance% need a
  backend exams enrichment endpoint (omitted, never faked); dashboard trend series await
  their data sources (monthly collections, expense ledger, enrollment snapshots).

---

## S5 — Communication & delivery  ✅ COMPLETE  `fbbb7634`

**Scope (PRA_FIX_STRATEGY §12.1):** P0-16, P0-18, P1-45; + N-11; P1-44 (route-scoped
delay broadcast). **EOS gate: PASS.** Regression: **578 affected-area backend tests green**
(32 sms/guardian/channels + 204 communication/teacher/transport + 342 finance/academics),
api-graph `deno check` clean, `deno lint` clean. No migration needed (reuses
`notification_deliveries` / `students` / `student_guardians`); next free migration still
`20260900000015`. *(DLT template registration = ops sub-task PRA-P2-20 — out of code scope,
honestly excluded.)*

### What shipped
- **Shared linchpin** `communication/guardian_recipients.ts` →
  `guardianUserIdsForStudents(db, org, school, sisStudentIds[])`: resolves SIS
  `student_code`s to DISTINCT **active** guardian user ids, scoped org+school (matches the
  active-link RLS 20260900000012). Built once, used by BOTH P0-16 and P1-44.
- **P0-16** (`teacher/teacher_parent_communication_handlers.ts`): "Send to parent" no longer
  stamps a hardcoded `status:"sent"` with zero delivery. It resolves the student's active
  guardians, enqueues a REAL delivery per requested channel (`deliveryChannels()` maps the
  teacher UI labels → push/sms/email; empty ⇒ push), drains the queue, and returns an HONEST
  `status` (`"queued"` vs `"no_recipients"`) + `recipientCount`.
- **P0-18** (`sms_provider.ts`): `buildTransactionalRequest` now honours the DLT route
  (route=dlt + sender_id + template message id + `variables_values`) instead of hard-coding
  Quick; `sendTransactionalSms` gained an optional 4th `templateId` (defaults to
  `config.fast2smsMessageId`) threaded to the builder. Both real callers
  (exam-result + fee-receipt SMS) build a full DLT-capable `smsConfig`, so both now honour
  DLT when configured. Quick route unchanged (pilot default).
- **P1-45** (`communication/communication_service.ts` + `communication_handlers.ts`):
  `sendBroadcastMessage` accepts an optional `channels?: string[]`. `normalizeBroadcastChannels`
  is **additive** — `push` is always present (free in-app baseline + sole ack channel) and
  `sms`/`email` are opt-in extras; omitted/empty ⇒ `["push"]` (byte-for-byte the old
  behaviour, no automatic cost). Fan-out loops the channels, attaching `requiresAck` to the
  push batch ONLY (no ack double-count). Handler reads `channels` from the request body.
- **P1-44** (`transport/transport_write_handlers.ts`): `handleNotifyRouteDelay` no longer
  `sendBroadcastMessage(audience:"parents")` (which spammed EVERY parent while lying about
  the count). It extracts the on-route allocations' `sisStudentId`s, resolves their active
  guardians via the shared helper, enqueues push to exactly them, and reports a truthful
  `recipientCount` (+ `affectedStudents`).
- **N-11**: verified — `api_parent_repository.dart` `acknowledgeCommunication` calls
  `_remote.acknowledgeCommunication` (fail-closed, PRA-N-10 S0), server endpoint
  `communication_service.ts acknowledgeNotification` exists. No change needed.

### New tests (4 files)
`communication/guardian_recipients_test.ts` (scope/active-only/dedup/empty),
`sms_provider_dlt_p0_18_test.ts` (Quick unchanged, DLT branch, templateId override, wire
threading via fetch stub), `communication/communication_channels_p1_45_test.ts` (additive
default push, opt-in sms/email, dedup, unknown dropped), `teacher/teacher_parent_communication_p0_16_test.ts`
(channel mapping); + P1-44 route-scope extraction test added to `transport_write_handlers_test.ts`.

### Tracked follow-ups (non-blocking)
- **PRA-P2-20 (ops):** register the per-message-type DLT templates (fee receipt vs result)
  with the provider; code already accepts a distinct `templateId` the day config carries them.
- **Live lane (INFRA-BLOCKED here):** the Fast2SMS DLT network leg + real guardian push
  delivery are certified on the VPS live lane (same boundary as QA-C-011).

### Recon findings (historical — implemented above)

**P0-16 — teacher "Send to parent" delivers nothing.**
`supabase/functions/_shared/teacher/teacher_parent_communication_handlers.ts` →
`handleSendParentCommunication` (lines 148–223). It INSERTs a `parent_communication_log`
row into `teacher_entities` with a **hardcoded `status:"sent"`** (line 172) and returns
`{id,status:"sent"}` (line 221), but **never enqueues any delivery** — the captured
`channels` array (line 159) is ignored. **Fix:** resolve the student's active guardian
user id(s) and enqueue a real delivery, then set status honestly.
- Substrate: `notification_service.ts` → `enqueueNotificationRequested(db, orgId, schoolId,
  recipientUserId, title, body, category)` (push) and `enqueueFromTemplate(...)`;
  `enqueueDelivery(db, {…, channel})` for a specific channel; `processDeliveryQueue(db,
  orgId)` drains via provider. `communication_service.ts` `sendDirectMessage` shows the
  reuse pattern (enqueue + processDeliveryQueue).
- Student→parent resolution: `student_guardians` where `status='active'` →
  `guardian_user_id`. Note `sisStudentId` here is the SIS id; confirm the join key to
  `student_guardians.student_id` (see `exam_administration_handlers.ts:272-273` which joins
  `student_guardians sg ON sg.student_id = s.id JOIN users u ON u.id = sg.guardian_user_id`
  — reuse that resolution shape from the sisStudentId).
- Set the log `status` to reflect real enqueue (e.g. "queued"/"sent"/"failed"), not a
  constant. Keep the concern-resolution + audit logic intact.

**P0-18 — transactional SMS ignores DLT (TRAI).** Builder fix is the uncommitted WIP
above. The 2 real callers of `sendTransactionalSms`:
- `academics/exam_administration/exam_administration_handlers.ts:281` (exam-result SMS)
- `finance/finance_collections_handlers.ts:105` (fee-collection/receipt SMS)
Both call `sendTransactionalSms(smsConfig, phone, msg)`. **Fix:** add optional 4th arg
`templateId?` to `sendTransactionalSms`, pass through to `buildTransactionalRequest`;
default to `config.fast2smsMessageId`. Per-message-type template *registration* is ops
(PRA-P2-20) — code just needs to honor the DLT config + allow a distinct templateId.

**P1-45 — broadcasts are push-only, no SMS/email fallback.**
`communication_service.ts` `sendBroadcastMessage` (279–387) enqueues **`channel:"push"`
only** (line 339 `enqueueDeliveriesBatch({… channel:"push" …})`). **Fix (bounded, opt-in):**
accept an optional `channels?: string[]` (subset of push/sms/email; **default `["push"]`
→ zero behavior change**); enqueue one `enqueueDeliveriesBatch` per selected channel.
Attach `requiresAck` only to the primary (push) batch to avoid ack double-counting. Wire
the handler (`communication_handlers.ts` handleCreateBroadcast) to read `channels` from the
request. This closes "no fallback" without automatic cost blow-up (admin opt-in).

**P1-44 — transport delay broadcast is NOT route-scoped (real defect).**
`transport/transport_write_handlers.ts` `handleNotifyRouteDelay` (389–430): computes
`affected` = allocations on the route (line 406), returns `recipientCount: affected.length`
— but calls `sendBroadcastMessage(..., {audience:"parents", ...})` (line 409) which fans
out to **EVERY parent in the school**. The count is a lie and it over-broadcasts
(spam/privacy). **Fix:** resolve the affected allocations' `sisStudentId` → active
`guardian_user_id`s and notify exactly those users (reuse `enqueueDeliveriesBatch` to the
resolved recipient list; do NOT add a new `comm_broadcasts.audience` token — that CHECK
constraint would need a migration). `recipientCount` then equals the real guardians
notified. (Depends on the same student→guardian resolution as P0-16 — build it once, e.g.
a small shared helper `guardianUserIdsForStudents(db, org, school, sisStudentIds[])`.)

**N-11 — parent notice "acknowledge" faked locally.** ✅ **Already fixed in S0.**
`lib/core/repositories/api/parent/api_parent_repository.dart:310-317` now calls
`_remote.acknowledgeCommunication` (comment "PRA-N-10 (S0/T2-E): fail closed"). Server
endpoint exists (`communication_service.ts:937 acknowledgeNotification`). **Verify only.**

### S5 test suites to run before commit
`supabase/functions/_shared/communication/*_test.ts` (broadcast_batch, broadcast_report,
communication_audience_ack, communication_unit, qa_c_010/012/014/016, scheduled_broadcasts,
route_parity), `sms_provider_test.ts`, `sms_provider_transactional_qa_c_011_test.ts`,
`teacher/*_test.ts`, `transport/transport_write_handlers_test.ts`, + full api graph
`deno check`. Add: a DLT-branch SMS test; a P0-16 enqueue test; a P1-44 route-scope test;
a P1-45 multi-channel test.

---

## S6 — Academic-operations blockers  ✅ COMPLETE  `355637e0` + `f5bc4558`

**EOS: CONDITIONAL PASS.** All 3 P0s + 7 of 8 P1s implemented, tested, committed.
Migrations `20260900000015` (parent-insights parent-scope RLS), `…016`/`…017` (SIS-doc +
homework buckets), `…018` (exam grade scales). **Next free = `20260900000019`.**
Integrated verification: **699 backend tests green** + api-graph `deno check` clean +
`deno lint` clean; full `dart analyze lib/` clean; Flutter suites green (exam-admin 46,
promotion 14, grading 101, storage 151).

**`355637e0` (part 1 — backend):**
- **P0-21** parent-insights AI no longer fabricates a child's metrics (parent-scope RLS on
  `intel_student_risk_snapshots` + handler `child_ids` gate + service raises no-data 404
  instead of defaulting 85/80/70).
- **P0-13** admissions approval gate — `submitEnrollment` refuses a non-'approved'
  application; walk-in path requires `approveAdmissions`.
- **P1-18** syllabus refuses to fabricate a stub for unseeded grade/board (422).
- **P1-20** TC no-dues now includes library dues (fines + unreturned books).
- **P1-12** exam tabulation/report-card dedupe per subject (no supplementary double-count) +
  senior-gated `/unpublish` reopen for correction.

**`f5bc4558` (part 2 — Flutter/storage):**
- **P0-14** annual promotion usable — 4 client↔backend contract bugs fixed + real
  academic-year UUIDs + surface-gate split (zero-backend reshuffle/section-balance deferred).
- **P1-13** grading scale persists + authoritative at publish/report (`exam_grade_scales`
  table + parameterized `gradeForPercent`; legacy default when no row).
- **P1-14** save-all counts out-of-range marks as failures + preserves the recovery draft.
- **P1-19** SIS document upload stores real bytes (`student-documents` bucket, presign→PUT→
  confirm; fabricated `storage://` string gone).
- **P1-30** homework attachments store real bytes (`homework-attachments` bucket).

**P1-17** school-calendar UI — ✅ **DONE** (landed in the S7 commit `808504d1`): full client
slice (screen/repo/datasource/mock/providers) wired to the complete-but-UI-less backend +
gated Management nav entry. S6 is now 11/11 items.

**Tracked S6 residuals (CONDITIONAL — P1/UX follow-ups, non-blocking):**
- Grade-scale client provider not yet synced to the new GET/PUT endpoint (backend is
  authoritative; local scale survives restart via attachPersistence).
- Native OS file picker + document/homework "download/open" buttons (real-storage vertical
  done via synthetic payload, mirroring admissions — no native dep added).
- Migrations `…015`–`…018` apply on deploy (no DB in this lane).
- P0-14 deploy note: both `ACADEMIC_API_ENABLED` + `ACADEMIC_OPERATIONS_API_ENABLED` must be
  enabled together for real year UUIDs to reach the promotion backend.

## S7 — Operational-module blockers  ✅ COMPLETE  `808504d1`

**EOS: CONDITIONAL PASS.** All in-scope P0 blockers closed + the mechanical P1 tail; larger
statutory/owner-data-model P1s tracked. Migration `20260900000019` (payroll_finance_postings).
**Next free = `20260900000020`.** Integrated verification (all 6 workstreams together):
api-graph `deno check` clean; `deno lint` clean; **399 backend tests** (transport/hr/
inventory/library/ai) + full `dart analyze lib/` clean + **209 Flutter tests** (transport/hr/
staff/library/payment/calendar/contracts).

**Delivered:**
- **P0-15** staff attendance recordable via the audited MANUAL-REQUEST fallback (client
  screen + approver queue on the built-and-tested `/staff-attendance/manual-request` +
  `/decide`; the check-in card's device path throws today). No hardware deps.
- **P0-19** vehicle→route assignment (`PUT /transport/routes/{id}/vehicle`) — the dormant
  seat-capacity guard now fires (over-fill / too-small-bus → 409).
- **P0-20** allocation raises the fee demand — `POST /transport/demands/bulk` (idempotent,
  demand-only) + derived per-allocation `demandRaised` + client bulk action.
- **P0-24** real payroll→Finance posting (`payroll_finance_postings`, idempotent, atomic in
  `handleProcessPayrollRun`) — B5 Option C closed (expense-record; Finance has no GL yet).
- **P0-02** CLIENT fail-closed (dropped fabricated `txn_`/`APS-` receipt; new
  `pendingGatewayVerification` phase; contract-ready gateway-proof fields). Backend was
  already fail-closed since S1. **Real gateway SDK = OWNER decision — PAUSED (stop-cond #7).**
- P1-33 HR settings writable · P1-36 LOP automation · P1-39 inventory writes · P2-12 per-type
  borrow caps · P1-42 lost-book workflow · P1-43 live transport roster · **P1-46** embeddings
  routed through the governed gateway path (security; dormant-safe).

### Tracked (NOT done — deliberately deferred, with rationale)
- **P1-34** leave accrual / carry-forward — medium build; the HR settings are now writable so
  a `paid:false` leave-type model can drive it (owner nuance on leave-type vocabulary).
- **P1-35** payroll statutory PF/ESI/PT/TDS — **LARGE compliance build** (per-state PT slabs,
  PF/ESI ceilings, TDS slabs, employer/employee splits); needs a statutory-config source.
- **P1-41** library accession / per-copy identity — **owner data-model decision** (numbering
  scheme + back-fill of existing pooled titles). `LibraryBookStatus.lost` enum is in place.
- **P0-02 real gateway SDK** (Razorpay/…) + credentials — stop-condition #7.
- **P0-15 real GPS+face device adapters** — geolocator/camera/ML deps + iOS/Android platform
  config (a hardware-dependent build; the audited fallback is the sanctioned interim closure).
- Client-wiring residuals: typed-repository callers for the new transport assign-vehicle +
  roster endpoints; a `GET /staff-attendance/manual-request` list route + the exact
  `approveStaffAttendance` client Permission-enum slug for a live approver queue.
- All PRA migrations `…015`–`…019` apply on deploy (no DB in this lane).

---

## CHECKPOINT — 2026-07-20 (S0–S7 COMPLETE — Tier-1 remediation done)

**Committed & verified (branch `feature/erp-pra-remediation`, NOT pushed):**
S0 `1b893f6d` · S1 `e4807308` · S2 `8e75616b` · S3 `972836b7` · S4 `005695d5`+`64e086da` ·
S5 `fbbb7634` · **S6 `355637e0`+`f5bc4558`** · **S7 `808504d1`**.

**Status:** all **24 P0s** across S0–S7 are addressed; the P1 tail is done except the
large-build / owner-data-model / hardware / gateway-SDK items listed above (each tracked with
rationale). Working tree clean at `808504d1`. Migrations `…015`–`…019` unapplied (deploy step).

**Resume / next actions (for a future session or the owner):**
1. **Owner decisions** to unblock the remaining P0/P1 tail: payment gateway choice + creds
   (P0-02 SDK); library accession numbering scheme (P1-41); staff real-device build scope
   (P0-15). 2. **Large builds** when scheduled: P1-35 statutory payroll, P1-34 leave accrual.
3. **Deploy:** apply migrations `…015`–`…019`; enable `ACADEMIC_API_ENABLED` +
   `ACADEMIC_OPERATIONS_API_ENABLED` together for promotion; register DLT SMS templates (S5).
4. **Small follow-ups:** grade-scale client↔endpoint sync; native file picker + download
   buttons; transport client wiring; staff approver-queue GET route + Permission slug.

**Per-stage rule (held throughout):** full affected-area regression green + EOS gate before
each commit; isolated commits; **not pushed**.

**Clean resume boundaries:** every committed stage. The student→guardian resolution helper
now exists (`communication/guardian_recipients.ts`) — reuse it anywhere else a
student-cohort→parent notification is needed.
