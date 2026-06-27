# AKSHARA — Red Team Certification Audit

**Date:** 2026-06-27
**Branch:** `feature/scope-trim-school-build` (HEAD `4f7f821` — Pilot School Simulation certified)
**Baseline health:** `flutter analyze` → **No issues found** (clean).
**Nature:** This is **not** a feature review or a generic repo audit. It is an adversarial red-team pass that intentionally tries to break the ERP through impatient, malicious, careless, overloaded, and unstable-network behaviour. All prior certifications (B1–B11, Engineering Waves 0–5, Journey Waves 0–5, Onboarding & Dynamic Config, Pilot School Simulation) are treated as source of truth; nothing already certified is re-litigated unless this pass found a concrete defect inside it.

## Method

Five parallel investigation tracks, each grounded in the core write/auth/transaction infrastructure and required to cite `file:line` evidence and label every finding `confirmed-from-code` or `needs-live-verification`:

1. Write-path concurrency & idempotency (duplicates, lost updates, rollback)
2. RBAC, tenant isolation, session/role/token & mid-session changes (incl. a full per-module write-route gating sweep and an RLS `WITH CHECK` sweep)
3. Flutter client resilience (double-tap, refresh/kill during save, network loss, error states)
4. Input limits & empty states (huge text/files, numeric bounds, division-by-zero, zero-data)
5. Backend connection handling under load (overloaded school / production incident)

## Executive summary

**35 findings.** The ERP's foundations are strong — write handlers run in proper single transactions with correct rollback; the per-module RBAC write-gating sweep found the overwhelming majority of routes correctly gated; division-by-zero and empty-state reads are well-guarded; parent **per-child read** scope is re-validated live against the DB. The defects cluster in five areas: **(1)** duplicate / lost-update writes where no DB unique key, row lock, or idempotency key backs an application-level check; **(2)** several parent-scoped RLS policies that pin tenant+school but not the child/parent, leaking PII across families; **(3)** a stale-token window where logout/revoke and role demotion are ineffective for the access-token TTL; **(4)** systemic absence of client-side double-submit guards; **(5)** unbounded inputs/uploads and an unpooled DB connection model.

| Severity | Count | Finding IDs |
|---|---|---|
| Critical | 3 | RT-01, RT-02, RT-09 |
| High | 16 | RT-03, RT-04, RT-06, RT-08, RT-10, RT-11, RT-12, RT-13, RT-16, RT-17, RT-18, RT-20, RT-24, RT-25, RT-26, RT-31, RT-35 |
| Medium | 12 | RT-05, RT-07, RT-14, RT-19, RT-21, RT-27, RT-28, RT-29, RT-30, RT-32, RT-33 |
| Low | 4 | RT-15, RT-22, RT-23, RT-34 |

> Counts: Critical 3, High 17, Medium 11, Low 4 (RT-35 counted High).

**Top risks to fix first:** RT-01 (duplicate / lost fee collection), RT-02 (duplicate student identity), RT-09/10/11/12 (cross-family PII leaks), RT-16/17 (revocation & demotion ineffective), RT-24/25 (client double-submit) — these are the defects that produce real data corruption, privacy breaches, or money errors under the exact behaviours this red team simulates.

---

## Category A — Write-path concurrency, duplicates & lost updates

### RT-01 — Duplicate / lost fee collection (no unique key, no lock, no idempotency)
- **Module:** Finance — Fee Collection / Payment
- **Scenario:** Double-click Save / client retry → duplicate payment; concurrent collection on one invoice → lost update + negative outstanding
- **Steps to reproduce:** `POST /finance/collections` twice for the same `invoiceId` (double-click or slow-network retry). Each call reads invoice `outstanding`, checks `amount > outstanding`, INSERTs a `finance_collections` row with a freshly-generated random `receipt_number`, and decrements `finance_invoices.outstanding_amount` + `finance_student_accounts`.
- **Root cause:** `createCollection` (`supabase/functions/_shared/finance/finance_collections_repository.ts:164-282`) has no idempotency key and no natural unique key; the over-payment guard is a read-then-write (`outstanding` read ~`:181`, INSERT/decrement ~`:194-270`). `finance_collections` has no unique constraint on `invoice_id` (`supabase/migrations/20260612500000_finance_slice4_collections.sql:4-23`). The `UNIQUE` is only on `finance_receipts.receipt_number`, and a *new* random number is generated each attempt (`buildReceiptNumber` ~`:111-115`), so it never blocks a replay. Under READ COMMITTED, two concurrent calls both read the same `outstanding`, both pass the guard, both commit.
- **Severity:** Critical (money: duplicate receipts, double-counted collections, outstanding driven below zero)
- **User impact:** A parent who taps Pay twice (or a cashier who retries) gets two recorded payments; ledger/daily-summary totals overstate cash; reconciliation breaks.
- **Estimated effort:** M
- **Confidence:** confirmed-from-code

### RT-02 — Duplicate student identity on concurrent / double create
- **Module:** SIS — Student Creation / Enrollment
- **Scenario:** Double-submit or concurrent create with the same admission number → two distinct student records (TOCTOU)
- **Steps to reproduce:** `POST /sis/students` twice with the same `admissionNumber`. Each request runs `admissionNumberExists` (SELECT) then INSERTs `students` + `student_profiles`.
- **Root cause:** `createStudent` (`supabase/functions/_shared/sis/sis_students_repository.ts:343-400`) guards uniqueness only at the application level (SELECT `:354`, INSERT `:370-395`); there is no DB unique constraint behind it — `student_profiles` has only a plain index `idx_student_profiles_school_admission` (`supabase/migrations/20260613000000_sis_slice0_foundation.sql:35`) and `UNIQUE (student_id)`. Two requests both see "not exists" and both insert.
- **Severity:** Critical (identity corruption — one child becomes two records; downstream attendance/marks/fees split across the duplicates)
- **User impact:** Duplicate students in the roster; results/fees attach to the wrong copy; very hard to merge afterwards.
- **Estimated effort:** M
- **Confidence:** confirmed-from-code

### RT-03 — Student-code generation races to a PK conflict → opaque 500
- **Module:** SIS — Student Code Generation
- **Scenario:** Two near-simultaneous create-student requests for one school
- **Root cause:** `generateStudentCode` (`supabase/functions/_shared/sis/sis_status_codec.ts:81-101`) reads `MAX(student_code)` and returns `last+1` with no lock; `students` has `UNIQUE (school_id, student_code)` (`supabase/migrations/20260609100000_phase2_rls_scope.sql:17`). Concurrent calls compute the same next code → second INSERT (`sis_students_repository.ts:361-367`) violates the unique constraint and surfaces as a generic `500 INTERNAL_ERROR`.
- **Severity:** High (integrity protected by the constraint, but a legitimate concurrent enrolment fails opaquely)
- **User impact:** During bulk/onboarding enrolment, parallel creates randomly 500; staff retry blindly.
- **Estimated effort:** S–M
- **Confidence:** confirmed-from-code

### RT-04 — Attendance-correction id derived from `count(*)+1` → concurrent PK 500 / duplicates
- **Module:** Attendance — Staff Correction Requests
- **Scenario:** Two teachers (or one double-clicking) `POST /attendance/corrections` simultaneously
- **Root cause:** `createAttendanceCorrection` (`supabase/functions/_shared/attendance/attendance_correction_repository.ts:144-152`) does `SELECT count(*)` → `att_corr_${count+1}` then INSERT; PK is `(organization_id, school_id, id)` (`supabase/migrations/20260618130000_f5_attendance_corrections.sql`). Concurrent calls collide → second INSERT 500s; a serialised double-submit instead creates two identical pending corrections. (The parent path at `attendance_handlers.ts:231` already uses a random id and is safe.)
- **Severity:** High (concurrent 500s + duplicate approval workload; a mis-approval can flip a real attendance mark)
- **User impact:** Correction submissions fail under concurrency; reviewers see duplicates.
- **Estimated effort:** S
- **Confidence:** confirmed-from-code

### RT-05 — Exam-session id derived from `count(*)+1` → concurrent PK 500 / duplicate exam
- **Module:** Academics — Exam Administration
- **Root cause:** `createExamSession` (`supabase/functions/_shared/academics/exam_administration/exam_administration_repository.ts:214-220`) builds id `exam_${count(*)+1}` then INSERTs. Concurrent creates collide → 500; serialised double-submit → two identical exams. (Marks UPDATE `updateExamMark`/`upsertExamRemark` are keyed upserts and safe; `provisionMarkSlots` uses `ON CONFLICT DO NOTHING` and is safe.)
- **Severity:** Medium (pre-result objects; no money/published-marks corruption)
- **User impact:** Duplicate exams in the list, or a 500 under concurrency.
- **Estimated effort:** S
- **Confidence:** confirmed-from-code

### RT-06 — Snapshot lost-update: concurrent writes to one JSON-array row silently drop records
- **Module:** HR (leave ×3), Library, Management (any `mutateSnapshot` list)
- **Scenario:** Two employees submit leave at the same time (or a create races an approve) → the first record is silently lost
- **Steps to reproduce:** Two concurrent `POST /hr/leave` (or a create racing `POST /hr/leave/{id}/approve`). Both call `mutateSnapshot("snapshot_leave", …)`.
- **Root cause:** `mutateSnapshot` (`supabase/functions/_shared/entity_write/entity_write_store.ts:169-204`) is find → mutate → replace with no `FOR UPDATE` / no atomic JSONB upsert. `handleCreateLeaveRequest` (`supabase/functions/_shared/hr/hr_write_handlers.ts:140-155`) and `decideLeaveRequest` (`:184-203`) read `current.requests`, append/modify, and replace the whole array. Under READ COMMITTED both read the same array and the second `replace` overwrites the first. Same pattern at all 5 `mutateSnapshot` call sites (HR ×3, `library_write_handlers.ts:347`, `management_write_handlers.ts:109`).
- **Severity:** High (real records — leave requests, approval decisions — vanish; storing many logical records in one JSON row makes every concurrent write a collision)
- **User impact:** Submitted leave disappears; an approval can be wiped by a simultaneous submission; counts drift.
- **Estimated effort:** M
- **Confidence:** confirmed-from-code (lost-update is a guaranteed consequence of the read-modify-write; exact timing window is needs-live-verification)

### RT-07 — No idempotency on entity-write inserts → double-submit duplicates
- **Module:** Generic entity-write framework + Admissions/CRM (leads, applications), library/hostel/transport/alumni/control-center entities
- **Scenario:** Any "create" POSTed twice (double-click) creates two rows
- **Root cause:** `EntityWriteStore.insert` (`supabase/functions/_shared/entity_write/entity_write_store.ts:75-90`) is a raw `INSERT (id,…) RETURNING` with a per-request id and no business unique key; `runWrite` (`supabase/functions/_shared/entity_write/module_write_handlers.ts:57-90`) accepts **no** idempotency token even though `idempotency-key` is advertised in the CORS allowlist (`supabase/functions/api/index.ts:74`). Handlers that mint `crypto.randomUUID()` per request (e.g. `hr_write_handlers.ts:23`, `alumni_write_handlers.ts:39`, `hostel_write_handlers.ts:59`) and `createLead`/`createApplication` (`supabase/functions/_shared/admissions/admissions_repository.ts:93-126`, `:383-411`, DB-default UUID) each produce a fresh row. `admissions_leads` has no unique key on `(school_id, phone)`.
- **Severity:** Medium (no money/identity corruption, but duplicate leads/entities clutter data and distort CRM funnel metrics + AI next-best-action)
- **User impact:** Double-tapping "Add" creates two of everything; duplicate leads inflate the pipeline.
- **Estimated effort:** M
- **Confidence:** confirmed-from-code

### RT-08 — Exam marks accept negative / above-maximum via direct API
- **Module:** Academics — Exam Administration
- **Scenario:** Backend persists any finite mark, including negatives and values far above `max_marks` (UI guard is bypassable)
- **Steps to reproduce:** `POST /academics/exams/marks/{id}` with `{"marksObtained": 99999}` or `-50`.
- **Root cause:** `exam_administration_handlers.ts:301-304` only checks `Number.isFinite(marksObtained)` — no `0 <= x <= max_marks` bound; `updateExamMark` (`exam_administration_repository.ts:413-439`) writes verbatim; the column has no CHECK (`supabase/migrations/20260614800000_pilot_operations.sql:87`). Client validation (`lib/features/academics/exam_admin/exam_marks_entry_screen.dart:352`) is the only guard.
- **Severity:** High
- **User impact:** Corrupt grades; percentages compute >100% or negative (`exam_administration_repository.ts:527`), skewing rank/pass-rate/parent results; hard to detect post-publish.
- **Estimated effort:** S
- **Confidence:** confirmed-from-code

---

## Category B — Tenant & privacy isolation (RLS)

> Model verified: context set via `app.set_request_context(...)`; role `erp_tenant` is `NOSUPERUSER NOBYPASSRLS` with per-table grants only; sensitive tables `FORCE ROW LEVEL SECURITY`. Postgres semantics applied: on a `FOR ALL` policy an omitted `WITH CHECK` reuses `USING` for writes, so "FOR ALL + tenant+school USING + no WITH CHECK" is **not** a defect — this eliminated ~80 superficially-flagged policies. Defects below are where the `USING` predicate itself is too weak.

### RT-09 — `parent_academic_summaries` leaks every child's academic PII to any parent in the school
- **Module:** Parent scope / Academic summaries
- **Steps to reproduce:** Under `app.set_request_context(org,'parent',parentUser,schoolA,NULL,NULL,parentUser)`, `SELECT * FROM parent_academic_summaries WHERE student_id = <another-child-in-school>` returns the row (expected: 0).
- **Root cause:** Policy `parent_academic_summaries_scope` (`supabase/migrations/20260625000000_phase10_school_final.sql:246-250`) gates only `organization_id = app_current_tenant_id() AND school_id = app_current_school_id()`. The table has per-child `student_id` (`:231`) with attendance/performance/strengths/weaknesses JSON but **no** `student_id IN (SELECT … student_guardians WHERE guardian_user_id = app_current_parent_user_id())` filter and no scope restriction. No `WITH CHECK` → write path equally broad.
- **Severity:** Critical (cross-family PII read **and** write)
- **User impact:** Any parent can read/alter any child's academic summary in their school.
- **Estimated effort:** S (tighten the policy predicate)
- **Confidence:** confirmed-from-code (DB-layer gap unambiguous; live check confirms reachability)

### RT-10 — `parent_engagement_snapshots` leaks across parents
- **Module:** Parent scope / Communication analytics
- **Root cause:** `parent_engagement_scope` (`supabase/migrations/20260626060000_phase15_communication_analytics.sql:85-89`) pins only tenant+school; table is keyed by `parent_user_id` (`:70`) with no `parent_user_id = app_current_parent_user_id()` restriction → any parent reads every other parent's engagement metrics.
- **Severity:** High
- **User impact:** Cross-parent metric leakage.
- **Estimated effort:** S
- **Confidence:** confirmed-from-code

### RT-11 — `parent_meeting_summaries` leaks across children
- **Module:** Parent scope / Teacher effectiveness
- **Root cause:** `parent_meeting_summaries_scope` (`supabase/migrations/20260626070000_phase16_teacher_effectiveness.sql:79-83`) pins only tenant+school; has `student_id` (`:67`) with no guardian/scope pin. Same shape as RT-09.
- **Severity:** High
- **User impact:** Cross-family meeting-summary leak (read+write).
- **Estimated effort:** S
- **Confidence:** confirmed-from-code

### RT-12 — `comm_messages` readable/writable across parents (thread participation not checked)
- **Module:** Communication Hub
- **Root cause:** `comm_messages_thread` (`supabase/migrations/20260614700000_communication_hub.sql:216-224`) gates `tenant + school + scope IN ('parent','school')` but does **not** verify thread participation, unlike the sibling `comm_threads_participant` (`:202-214`) which correctly restricts a parent to threads where `parent_user_id = app_current_user_id()`. A parent can read/write any message in any thread in their school.
- **Severity:** High (private message leak + injection across families)
- **User impact:** Cross-parent message exposure and the ability to post into another family's thread.
- **Estimated effort:** S–M (add an `EXISTS` join to `comm_threads` participation for parent scope)
- **Confidence:** confirmed-from-code

### RT-13 — School-memory tables writable by parent/student scope
- **Module:** School Memories
- **Root cause:** `school_memory_events_school` (+ `_albums`, `_media`) (`supabase/migrations/20260622500000_phase5_foundation.sql:161-180`) use `USING (tenant AND school AND scope IN ('school','parent','student'))` with **no** `WITH CHECK`, so the permissive USING governs writes too → a parent/student can INSERT/UPDATE/DELETE school-wide memory rows. Not cross-tenant, but an unintended write surface.
- **Severity:** High (unauthorised write surface)
- **User impact:** A parent/student could tamper with school-wide memory content.
- **Estimated effort:** S (add a `WITH CHECK` restricting writes to school scope)
- **Confidence:** confirmed-from-code

### RT-14 — Cross-school audit / domain-event injection within an org
- **Module:** Audit / Domain events
- **Root cause:** `audit_events_tenant_insert` and `domain_events_school_insert` (`supabase/migrations/20260614500000_audit_ingestion_domain_events.sql:74-78`, `:92-96`) pin only `organization_id` on INSERT WITH CHECK; both tables have a `school_id` column (`:7`, `:37`). A school-A token can insert rows tagged `school_id = B` in the same org (log integrity). Cross-tenant is still blocked.
- **Severity:** Medium (audit/event-log integrity)
- **User impact:** Within-org cross-school audit/event pollution; weakens forensic trust.
- **Estimated effort:** S
- **Confidence:** confirmed-from-code

### RT-15 — Platform tables (incl. secret vault) have RLS disabled (latent, mitigated)
- **Module:** Platform / Control Center storage
- **Root cause:** `platform_secret_vault`, `platform_secret_audit_log`, `platform_provider_configs`, `platform_usage_events`, `platform_feature_enablements` (`supabase/migrations/20260625000000_phase10_school_final.sql:99-173`) are created with **no** `ENABLE ROW LEVEL SECURITY` and never enabled later. **Mitigated today** because none are GRANTed to `erp_tenant` (access is service_role / SECURITY DEFINER only).
- **Severity:** Low (defense-in-depth; would become Critical if any tenant-role GRANT is ever added)
- **User impact:** None currently; latent cross-org exposure risk for secrets if grants change.
- **Estimated effort:** S (enable RLS + scope policies as belt-and-suspenders)
- **Confidence:** confirmed-from-code

---

## Category C — Session, token & authorization enforcement

### RT-16 — Logout / logout-all / revoke does not stop an in-flight access token
- **Module:** Auth (session lifecycle)
- **Steps to reproduce:** Log in → capture access token → `POST /auth/sessions/logout-all` → reuse the original token on any module route → it still succeeds until the 15-min TTL.
- **Root cause:** `authenticateRequest` (`supabase/functions/_shared/permission_middleware.ts:14-35`) only does a cryptographic `verifyAccessToken` (`jwt.ts:61-93`). No request path consults `sessions.revoked_at` for the token's `session_id`; `revoked_at` is only written (logout/revoke) or read in `handleRefresh` (`auth_handlers.ts:484-494`).
- **Severity:** High
- **User impact:** Device-revoke / logout-all is ineffective for up to `ACCESS_TOKEN_TTL_SECONDS` (default 900, `config.ts:84-86`); a stolen token cannot be force-killed in that window.
- **Estimated effort:** M (per-request session-validity check or short-TTL revocation cache keyed on `session_id`)
- **Confidence:** confirmed-from-code

### RT-17 — Role demotion / deny-override does not invalidate an in-flight token (`permissions_version` is dead)
- **Module:** Auth / RBAC (role lifecycle)
- **Steps to reproduce:** Teacher logs in with `manage*`; admin demotes / adds a deny override; teacher reuses the existing token on the gated write → still passes for up to 15 min.
- **Root cause:** Permissions are resolved only at login/refresh and frozen into the JWT (`auth_handlers.ts:115-137`; resolver `permission_resolver.ts:93-173`); `requirePermission` reads `claims.permissions` (`permission_middleware.ts:38-50`). `permissions_version` exists in claims (`jwt.ts:21`) but is **never compared to the live membership row** on the request path, and no admin handler bumps it on a role change (only a one-time bulk bump in `supabase/migrations/20260627110000_pilot_rbac_permission_recovery.sql:152-153`).
- **Severity:** High
- **User impact:** A demoted user keeps the removed permission for up to 15 min; the schema's `permissions_version` mechanism gates nothing at request time.
- **Estimated effort:** M
- **Confidence:** confirmed-from-code

### RT-18 — Entitlement enforcement is env-flag-gated and OFF by default
- **Module:** Entitlements (`withEntitlement`)
- **Steps to reproduce (flag-off env):** With a valid token, `POST /library/...` (or any wrapped optional module) for a school whose plan excludes it → succeeds (no 402/403).
- **Root cause:** The gate is a no-op unless `ENTITLEMENT_ENFORCEMENT=true` (`supabase/functions/_shared/entitlements/entitlement_enforcement.ts:12-19`); `withEntitlement` skips enforcement when false (`entitlement_middleware.ts:132-135`), defaulting OFF. The gate *itself* is correct when on (runs per request, all methods, reads live subscription — `entitlement_middleware.ts:126-141`, `entitlement_service.ts:55-93`). With the flag off, module gating exists only in client navigation.
- **Severity:** High (Medium where the flag is verified ON, e.g. pilot org)
- **User impact:** Plan/module entitlement unenforced server-side unless the env var is set in every environment.
- **Estimated effort:** S (operational: ensure flag ON everywhere, or default-on)
- **Confidence:** needs-live-verification (per environment)

### RT-20 — `POST /approvals/{id}/cancel` is scope-only — bypasses the per-type approve permission
- **Module:** Approval engine
- **Steps to reproduce:** Any school-scoped user `POST /approvals/{id}/cancel` on a pending approval they don't own (e.g. a pending exam-results or refund approval).
- **Root cause:** `handleDecision` (`supabase/functions/_shared/approval/approval_handlers.ts:276`) wraps the per-type `requirePermission(approvalPermissionForType(type))` block in `if (status !== "cancelled")` (`:293`), so the cancel path runs only the `requireSchoolScope` check (`:285-286`) and skips the `approve*` permission entirely.
- **Severity:** High (a non-approver can cancel any pending approval — DoS on the approval workflow)
- **User impact:** A teacher could cancel a principal's pending approvals.
- **Estimated effort:** S
- **Confidence:** confirmed-from-code

### RT-19 — Payment intents (initiate/confirm) are auth-only (no permission/scope gate)
- **Module:** Payment
- **Root cause:** `handleInitiatePayment` (`supabase/functions/_shared/payment/payment_handlers.ts:37-42`) and `handleConfirmPayment` (`:76-81`) call `authenticateRequest` but no `requirePermission` and no scope check; any authenticated caller can hit them. (RLS still scopes the underlying rows; the Razorpay webhook is correctly HMAC-gated.)
- **Severity:** Medium
- **User impact:** Payment-intent creation/confirmation lacks an authorization gate beyond authentication.
- **Estimated effort:** S
- **Confidence:** confirmed-from-code

### RT-21 — `POST /audit/events/batch` is auth-only → audit-log injection
- **Module:** Audit ingestion
- **Root cause:** `handleAuditBatchUpload` (`supabase/functions/_shared/audit/audit_handlers.ts:19-35`) authenticates but never calls `requirePermission`; any authenticated user can push audit events.
- **Severity:** Medium (forensic-trust / log-pollution)
- **User impact:** A low-privilege user can inject/pollute the audit trail.
- **Estimated effort:** S
- **Confidence:** confirmed-from-code

### RT-22 — Write-performing POSTs gated only by *view* slugs
- **Module:** Director, Promotion, Intelligence (teacher-effectiveness), Approval-audit
- **Root cause:** Several routes perform writes but gate on a read slug: `POST /director/summary` → `viewDirectorPortal` (`director_handlers.ts:139-142`); `POST /promotions/{id}/track` → `viewAchievementPromotion` (`achievement_promotion_handlers.ts:274-282`); `POST /intelligence/teacher-effectiveness/parent-meeting-summary` → `viewTeacherEffectiveness`/`viewLessonAnalytics` (`teacher_effectiveness_handlers.ts:149-156`); `POST /approvals/audit` → `viewManagement` (`approval_handlers.ts:411-420`). All are gated (return on denial) but by view-level rather than manage-level permission.
- **Severity:** Low (these are AI-generation / metric-increment / audit writes, not core mutations)
- **User impact:** A view-only user can trigger generation/metric/audit writes.
- **Estimated effort:** S
- **Confidence:** confirmed-from-code

### RT-23 — Razorpay webhook signature check is bypassed in `stubMode`
- **Module:** Payment webhook
- **Root cause:** `handleRazorpayWebhook` (`supabase/functions/_shared/payment/payment_handlers.ts:160-177`) verifies HMAC but the guard is `if (!valid && !razorpay.stubMode)` — a misconfigured `stubMode` in production would skip verification and accept forged webhooks (with fabricated `manageFinance`/`schoolAdmin` claims).
- **Severity:** Low (depends on a prod misconfiguration)
- **User impact:** Forged payment webhooks if stub mode is ever on in production.
- **Estimated effort:** S (assert stubMode off in prod / fail-closed)
- **Confidence:** confirmed-from-code (exploit is needs-live-verification per env)

> **Verified SAFE in this category:** session-expiry mid-action is graceful — `authenticateRequest` runs before `withTenantContext`, so an expired token yields a clean 401 *before* any DB mutation, inside a single transaction (no partial/duplicate write from expiry). Context-switch (`auth_handlers.ts:559-596`) re-resolves membership and **revokes the prior session** before minting the new token (no privilege escalation). Parent **per-child** scope is re-validated live via a `student_guardians` join in RLS (`parent_entities` policy, `20260614400000_mobile_read_apis.sql:51-63`), so a revoked guardian link is enforced immediately even with a stale JWT. SECURITY DEFINER functions re-derive scope from request-context GUCs (no Critical caller-supplied-id bypass found).

---

## Category D — Client write resilience

> Shared fact: central error handling is solid — `ApiErrorInterceptor` + `ApiFailureMapper` (`lib/core/network/interceptors/api_error_interceptor.dart`, `lib/core/errors/api_failure_mapper.dart`) turn every Dio error into a clean `ApiFailureException` with a friendly message. The findings below are the UI/notifier layer not using that consistently, and the absence of double-submit guards.

### RT-24 — Systemic: no re-entry guard in mutation notifiers
- **Module:** All write notifiers (teacher, finance, admissions, library, transport, HR, SIS, exams…)
- **Root cause:** Every `execute()` does `state = AsyncLoading(); state = await AsyncValue.guard(...)` with **no** `if (state.isLoading) return;` precheck (`lib/features/teacher/teacher_mutations_provider.dart:95-96,126-127,187-188,376-377`; `lib/features/academics/exam_admin/exam_marks_entry_provider.dart:60,88,117,142,183`; analogous `*_mutations_provider.dart` elsewhere). Grep `if (state.isLoading) return` over `lib/` = **0 matches**. Re-entry is gated only by whether the UI disables the button.
- **Severity:** High (removes the last defense for every write below)
- **User impact:** Any unguarded button = potential duplicate write.
- **Estimated effort:** M
- **Confidence:** confirmed-from-code

### RT-25 — Systemic: write buttons not disabled while in flight → double-tap duplicates
- **Module:** Finance, Teacher attendance, Exams admin, SIS, Library, Transport, HR
- **Steps to reproduce (cleanest case):** Teacher attendance → mark all → tap **Submit** twice quickly. `submitAttendance` sets `isSubmitted=true` only *after* the await returns (`lib/features/teacher/attendance/teacher_attendance_provider.dart:177`); the button is `onPressed: canSubmit ? onSubmit : null` with `canSubmit = unmarkedCount==0 && !isSubmitted` (`teacher_attendance_screen.dart:242,349`), so during the in-flight window a second tap fires a second submission.
- **Root cause / representative sites:** Finance `finance_offline_payments_screen.dart`, `finance_collection_detail_screen.dart` (cancel), `finance_invoice_management_section.dart` (issue/cancel), `finance_workflow_actions.dart` (refund approve/reject); Exams `exam_marks_entry_screen.dart:185,195,206,226`; SIS `sis_academic_assignment_screen.dart`, `sis_admissions_conversion_screen.dart`; Admissions `admissions_workflow_actions.dart`; Library `library_management_screen.dart`. Counter-examples that already guard correctly (fix template): `admissions_enrollment_screen.dart:138-159`, `finance_qr_payment_screen.dart:112,169`, `hr_leave_screen.dart:420,425`, `unified_onboarding_flow_screen.dart:64,71,89`.
- **Severity:** High (Critical for money/record writes — combines with RT-01/02/07 backend gaps so duplicates persist)
- **User impact:** Duplicate receipts/collections, double invoices, double refunds, duplicate attendance/marks/results.
- **Estimated effort:** M (broad but mechanical: read mutation `.isLoading` into `onPressed`)
- **Confidence:** confirmed-from-code (button-not-disabled + no re-entry guard); per-endpoint duplication is needs-live-verification

### RT-26 — Silently swallowed write errors (no message on failure)
- **Module:** SIS profile edit, Finance offline payments
- **Root cause:** `sis/profile/sis_profile_edit_sheet.dart` `_save()` (~`:128-147`) `finally`-only resets `_saving` with no `catch` to surface failure; `finance/payments/finance_offline_payments_screen.dart` Reconcile (~`:145-157`) and the record-payment dialog body (~`:329-350`) wrap `execute()` with no try/catch.
- **Severity:** High
- **User impact:** User believes the save worked (or is confused) and re-taps, compounding RT-25.
- **Estimated effort:** S
- **Confidence:** confirmed-from-code

### RT-27 — Raw `'$error'` leaked to users on write failures
- **Module:** Transport, Exams admin, Hostel, SIS, Education, Director
- **Root cause:** ~48 `SnackBar(Text('$error'))` / `Text('$e')` sites show `ApiFailureException.toString()` ("ApiFailureException: <message>") instead of `failure.message` / `AksharaErrorState.fromFailure`. Concentrations: `transport/transport_workflow_actions.dart:52,97,173,278,386,488,534`; `academics/exam_admin/exam_marks_entry_screen.dart:251,266,285,301,370,426`; `hostel/hostel_workflow_actions.dart:115,189,238`; `education/education_screen.dart:213,388,409,423,569`.
- **Severity:** Medium (debug-looking, inconsistent; not a swallow)
- **User impact:** Unprofessional/confusing error text on failed save.
- **Estimated effort:** S (mechanical replace)
- **Confidence:** confirmed-from-code

### RT-28 — Optimistic local-success on toggle-style writes
- **Module:** Transport attendance, HR attendance (check-in/out, boarding/exit toggles)
- **Root cause:** Toggle buttons flip local UI state and fire the write without disabling; on failure the error path only shows raw `'$error'` and the toggle may remain in its success state (`transport/attendance/transport_attendance_screen.dart` + `transport_workflow_actions.dart`; HR equivalents).
- **Severity:** Medium
- **User impact:** Attendance appears marked but isn't persisted; silent UI/server drift.
- **Estimated effort:** M
- **Confidence:** needs-live-verification (confirm state flips before await resolves and isn't reverted on failure)

### RT-29 — Auth interceptor blindly retries the failed request after 401 refresh (incl. POST)
- **Module:** Core network
- **Root cause:** `AuthInterceptor.onError` (`lib/core/network/interceptors/auth_interceptor.dart:71-92,150-160`) refreshes then `_retry`s the original request verbatim for all verbs. If a POST committed server-side but the response 401'd (token expiry across the request/response boundary), the client re-sends the write after refresh → duplicate; no idempotency key on the request.
- **Severity:** Medium (narrow window)
- **User impact:** Rare silent duplicate write across a session-expiry boundary.
- **Estimated effort:** M (restrict auto-retry to idempotent verbs, or send an idempotency key)
- **Confidence:** confirmed-from-code (retry is unconditional); real-world duplication is needs-live-verification

### RT-30 — No browser-refresh/app-kill guard; unsaved-changes guard barely used
- **Module:** All forms (web especially)
- **Root cause:** Grep for `beforeunload` = **0**; `AksharaUnsavedChangesGuard` (`lib/shared/forms/akshara_unsaved_guard.dart`) is referenced in only one screen (`admissions_enrollment_screen.dart`); `PopScope` in only 2 feature files; no local draft persistence for operational forms.
- **Severity:** Medium
- **User impact:** Lost form input on accidental refresh/back with no prompt; uncertainty whether a mid-refresh save committed.
- **Estimated effort:** M
- **Confidence:** confirmed-from-code

---

## Category E — Input hardening, uploads & scale

### RT-31 — No file size cap or MIME/type allowlist on any upload path
- **Module:** School Memories + Admissions documents (Storage)
- **Steps to reproduce:** `POST /admissions/documents/upload/presign` (or memories presign) with `file_name:"x.exe"` → receive a signed PUT URL → PUT arbitrary bytes of any size/type; confirm accepts as long as `storage_path` is tenant-prefixed.
- **Root cause:** `supabase/functions/_shared/storage/storage_service.ts` `createMemoryUploadUrl` / `createAdmissionsDocumentUploadUrl` call `createSignedUploadUrl` with only `{ upsert: false }` — no `contentType`, no size validation; handlers (`school_memories_handlers.ts:219-252`, `admissions_handlers.ts:829-866`) validate only a non-empty filename. No client `file_picker`/`image_picker` guard either.
- **Severity:** High
- **User impact:** Storage/disk-exhaustion abuse; stored-XSS if SVG/HTML is served inline via signed URL; malware distribution; tenant storage bloat.
- **Estimated effort:** M (content-type allowlist + max-bytes at presign and/or Supabase bucket policy)
- **Confidence:** confirmed-from-code (whether the bucket itself enforces limits out-of-band is needs-live-verification)

### RT-32 — Systemic: no max-length on any text input (client or DB)
- **Module:** Cross-cutting (entity-write framework + all forms)
- **Root cause:** Backend `str()`/`requireStr()` (`supabase/functions/_shared/entity_write/module_write_handlers.ts:96-119`) trims but never bounds length; the schema uses **686 unbounded `TEXT` columns and zero `VARCHAR(n)`**; **0 of 63** client files with `TextFormField`/`TextField` set `maxLength`.
- **Severity:** Medium
- **User impact:** DB bloat, UI overflow, oversized payloads, a DoS vector via repeated large writes.
- **Estimated effort:** M (shared bounded-string reader + `maxLength` on key forms)
- **Confidence:** confirmed-from-code

### RT-33 — Unbounded numeric input via `intOr` (negatives / absurd magnitudes)
- **Module:** Cross-cutting entity writes
- **Root cause:** `intOr` (`module_write_handlers.ts:121-133`) returns any finite int — no floor/ceiling. Mitigated only where a DB CHECK exists (finance amounts `>0`, inventory `>=0`, marks templates `>0`); fields without a CHECK persist garbage. RT-08 (marks) is the proven concrete case.
- **Severity:** Medium
- **User impact:** Negative/nonsensical values silently accepted where no DB CHECK backs the field.
- **Estimated effort:** S–M
- **Confidence:** confirmed-from-code (marks proven; other fields needs-live-verification per module)

### RT-34 — Parent children fan-out has no LIMIT
- **Module:** Auth / Parent context (multi-child)
- **Root cause:** On every login and `auth-me`, `resolveParentContext` (`supabase/functions/_shared/auth_context.ts:239-260`) selects all `student_guardians` rows and `loadChildProfiles` (`:200-237`) runs `.in("id", childIds)` with no `.limit()`. Low impact at realistic family sizes; risk is an outlier guardian (mislinked staff-parent, seed/test guardian) inflating the login payload and child-switcher list.
- **Severity:** Low
- **User impact:** Slow login / oversized auth payload and a long un-virtualised switcher for outlier guardians.
- **Estimated effort:** S
- **Confidence:** confirmed-from-code

### RT-35 — No DB connection pooling — a fresh Postgres connection per request (direct 5432)
- **Module:** Backend infrastructure (tenant DB access)
- **Scenario:** Overloaded school / traffic spike → connection exhaustion → cascade of 500s (production incident)
- **Root cause:** `withTenantContext` (`supabase/functions/_shared/tenant_db.ts:88-109`) does `new Client(...)` → `connect()` → run → `end()` per request, and the connection string targets **port 5432 (direct Postgres), not the 6543 pooler** (`deploy/akshara-vps/.env.akshara.example:35`). No PgBouncer/pool layer (grep confirms). Every read/write opens and closes a connection; under concurrent load this churns and can hit `max_connections`.
- **Severity:** High (works at pilot scale; a real scaling cliff under spike/load)
- **User impact:** Under a busy morning (attendance + fees + parents logging in) the API can exhaust DB connections and start failing requests with 500s.
- **Estimated effort:** M (route through the Supabase/PgBouncer pooler on 6543, or add a connection pool)
- **Confidence:** confirmed-from-code (exhaustion threshold is needs-live-verification under load test)

---

## Verified safe (checked this pass — not re-flagged)

- **Transaction rollback** is correct — single `BEGIN`/`COMMIT`/`ROLLBACK` with rollback on any throw (`tenant_db.ts:96-108`).
- **Division-by-zero in computed metrics** (attendance %, pass %, averages, fee %, ROI) is well-guarded across dashboard/analytics/intelligence/director/finance/management/sis/alumni code (e.g. `exam_intelligence_service.ts:152`, `finance_dashboard_repository.ts:44`, `director_repository.ts:595`, `analytics_scoring.ts:53`).
- **Empty-state reads** (zero students, empty academic year) return empty 200s, not NaN/500 (PSIM fix + the division guards above).
- **Required-field handling** is solid (`requireStr` → 422); the gap is bounds/length, not presence.
- **RBAC write-route gating sweep:** the large majority of write routes across ~30 module routers are correctly gated with a `manage*`/`approve*`/`publish*`/`send*` slug that returns on denial (admissions, finance, SIS, academic, timetable, education, library, transport, hostel, HR, alumni, inventory, control-center, organization-builder, onboarding, setup-wizard, widget-platform, growth, entitlements, copilot, intelligence-writes, social, memories, school-calendar, school-config, school-completion). The exceptions are RT-19/20/21/22/23 above; self-service scope-only writes (pilot teacher/parent/student leave & homework submit; inventory-distribution parent ack/replacement) are by-design and not flagged.
- **Determinate-key writes** (`updateExamMark`, `upsertExamRemark`, `provisionMarkSlots ON CONFLICT DO NOTHING`, academic-year & primary-class-teacher partial unique indexes with typed-error mapping) are concurrency-safe.
- **Idempotency where it matters most:** payment intents dedupe on `idempotencyKey` (`payment_service.ts:90-91`).

## Needs live verification (carry into each wave's live VPS step)

- RT-09/10/11/13: confirm parent/student edge handlers actually query those tables under persona context (DB-layer gap is unambiguous regardless).
- RT-18: confirm `ENTITLEMENT_ENFORCEMENT` value per environment.
- RT-25/28/29: confirm real duplicate rows / persisted optimistic state under tap-timing and a 401-after-commit.
- RT-31: confirm whether the Supabase bucket enforces `file_size_limit`/`allowed_mime_types` out-of-band.
- RT-35: load-test the connection-exhaustion threshold.
- Several correct parent policies join `student_guardians` on `guardian_user_id = app_current_user_id()` rather than `app_current_parent_user_id()` — safe only if those GUCs are equal under parent scope; one live check (if they diverge it is an availability bug, not a leak).
