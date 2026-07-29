# Akshara ERP — Interim Comprehensive Certification Audit

**Date:** 2026-07-20
**Board:** 12 independent parallel expert reviewers + adversarial verification of every Critical/High finding against real code
**Scope audited:** Canonical trunk `integration/w0-canonical` (the project's certified, converged production baseline) — worktree `/Users/surendrakanna/Documents/Akshara_ERP-w0`. 244 migrations, ~979 backend TS files, ~1,825 Dart files, 164 web files.
**Out of scope (as instructed):** intentionally-unfinished roadmap items (W4 GL consolidation, owner-gated live payment gateway, hardware/OMR, statutory payroll, QIE/QPL knowledge-engine R&D lane).

**Method note:** Findings were not accepted on reviewer assertion. Each Critical/High claim was handed to an adversarial verifier instructed to *refute* it against the actual code. 17 verdicts returned: **7 CONFIRMED, 8 PARTIAL (real but re-severitied), 2 REFUTED**. Only verified findings are reported below, at their corrected severity.

---

## 1. Scores

| # | Dimension | Score |
|---|-----------|-------|
| 1 | Architecture | **76 / 100** |
| 2 | Engineering | **76 / 100** |
| 3 | Security | **80 / 100** |
| 4 | Database | **76 / 100** |
| 5 | Finance Integrity | **72 / 100** |
| 6 | Multi-tenant | **86 / 100** |
| 7 | Maintainability | **73 / 100** |
| 8 | Scalability | **62 / 100** |
| 9 | Foundation Readiness | **78 / 100** |

---

## 2. Executive Summary

This is a **genuinely engineering-grade foundation**, materially above typical school-ERP baselines, and the strongest slices (multi-tenant isolation, the core direct-collection money path, auth/session freshness) are the product of real adversarial hardening rather than convention. Two claims that would have been the most damaging — a per-route RBAC coverage gap and a payment-webhook double-apply — were **refuted** on verification: a 47-file per-domain route-contract RBAC suite genuinely exists, and the main capture path is serialized by an atomic `markIntentCaptured` guard that rolls back the losing transaction.

However, the audit **confirmed a cluster of real, in-scope defects in shipped/certified code** — most importantly a **live 100× money-understatement bug** in the finance recovery dashboard, a **same-org PII/access-control leak** exposing a de-authorized guardian's child records, a **concurrent double-credit race** on offline-instrument reconciliation, and a **receipt-number uniqueness collision** that can block a second school's first payment. Separately, the **highest-volume table in the product (`attendance_records`) has no supporting index**, a foundation-level scalability flaw on the roadmap's critical path. None of these are cross-tenant data breaches or systemic auth bypasses, and each is narrowly scoped or gated — but several are *active correctness/integrity errors*, not merely latent, so they must be corrected before more roadmap weight is placed on the finance and parent-facing surfaces.

**Verdict: INTERIM CERTIFIED — Continue After Moderate Corrections.**

**EOS gate: CONDITIONAL PASS — P1 money-integrity + access-control corrections tracked (RECOVERY-100x, GUARDIAN-RLS, RECONCILE-RACE, RECEIPT-UNIQUE, ATTEND-INDEX) before the affected surfaces are extended or re-deployed to the pilot.**

---

## 3. Major Strengths (evidence-backed)

1. **Multi-tenant isolation is engineering-grade and the strongest slice (86).** `tenant_id` is always derived server-side from an HS256-signed JWT, never from client input (`jwt.ts:61-93`, `tenant_db.ts:53-63`). The edge connects as a non-bypass `erp_tenant` role (`NOSUPERUSER NOBYPASSRLS`, migration `20260610100000:25-33`) under `FORCE ROW LEVEL SECURITY`, with a **deploy-time assertion** that fails the health check if the edge ever connects as `service_role` (`tenant_db.ts:183-195`). Request context is transaction-local (`set_config(...,true)` inside `BEGIN/COMMIT`), preventing GUC leakage across pooled connections. An automated grant-vs-RLS cross-check of all **256** tenant-scoped tables found every one has RLS enabled; the 2 exceptions are genuine global reference catalogues.

2. **The core direct-collection money path is correctly concurrency-safe.** `createCollection` takes `SELECT … FOR UPDATE OF fi` on the invoice before the outstanding check (`finance_collections_repository.ts:291-301`), runs the whole collection+receipt+account+allocation inside one transaction, allocates receipt sequence atomically via `INSERT … ON CONFLICT … RETURNING`, and refunds use the correct claim-first `… WHERE refund_status='pending'` + throw-on-0-rows pattern (`finance_refunds_repository.ts:329-341`). Verified live by a real multi-threaded Postgres cert (`live_cert_red_team_wave1.py`).

3. **Auth is fail-closed and fresh on every request.** HS256 is algorithm-pinned (no alg-confusion, `jwt.ts:67`), `JWT_SECRET` requires ≥32 chars with no default (`config.ts:80-82`), and every request re-validates session revocation + `permissions_version` freshness so logout/demotion take effect immediately rather than waiting out the token TTL (`session_validation.ts`, `permission_middleware.ts:40-45`). Refresh tokens are hashed at rest with rotation + reuse-detection family revocation.

4. **Real secret-at-rest encryption and constant-time money signatures.** The vault is AES-256-GCM with a fresh 12-byte IV that throws rather than ever storing plaintext (`vault_crypto.ts:99-113`); webhook/payment signatures use a constant-time comparator (`webhook_hmac.ts:36-43`).

5. **DB-enforced append-only ledgers.** `stock_movements` and `finance_receipts` grant only `SELECT,INSERT` to the non-bypass `erp_tenant` role — immutability is privilege-backed, not comment-backed. Migrations are strictly monotonic (244 files, zero duplicate timestamps).

6. **Clean cross-cutting composition and observability.** Idempotency (`dispatchWithIdempotency`) and entitlements (`withEntitlement`) are non-invasive higher-order wrappers; one structured JSON log line per request with a correlation id and no secrets/bodies; 500s never leak internal detail; every 403 is recorded once as a server-side access-denied audit.

7. **Data-driven RBAC and a clean commercial seam.** Permissions/roles are seed-data with DENY-wins override semantics (`permission_resolver.ts:37-50`), so new modules are seed-only; the entitlement layer is `planAllows ∩ schoolConfigEnabled` with per-deal overrides and a proper 402/403 two-tier gate.

8. **Correct, unified K-12 domain rules.** Attendance % is genuinely canonicalized into one shared SQL+TS module actually consumed across every surface; exam results correctly treat absent/medical/debarred as NULL (excluded from totals/avg/rank) with a publish-time completeness gate; the clearance/no-dues engine correctly distinguishes fail-safe (report) from fail-closed (gate).

---

## 4. Major Weaknesses

1. **Money-unit representation is fragmented three ways and has already produced a live bug** (see Critical Risk #1).
2. **Peripheral money paths lack the discipline of the core path** — offline reconcile and the generic idempotency wrapper (Critical Risks #3, #6).
3. **The highest-volume table has no index** — a scalability foundation flaw (Critical Risk #5). Scalability is the weakest dimension (62): unbounded list endpoints, all-time synchronous dashboard aggregates, N+1 fee assignment, and a per-isolate connection pool with no global ceiling.
4. **The automated merge gate contains zero real-database tests** — RLS/tenant-isolation and money-race guards are verified only by env-gated tests (skipped in CI) or by mocks that re-implement the guard under test. Mitigated by runtime `/health/tenant-access` probes in deploy verification, but not caught at PR time.
5. **Structural consistency debt:** a two-tier persistence model (relational vs opaque JSONB `{module}_entities` with soft, un-FK'd references), god-files (up to 3,313 lines), order-dependent hand-maintained routing, copy-pasted DB idioms, and the `students` identity table written by three modules with no owning service.

---

## 5. Critical Risks (confirmed against real code — ranked)

> These are the items that gate the "moderate corrections" verdict. All are **in-scope** (shipped/certified code, not roadmap stubs) and were **CONFIRMED or PARTIAL-confirmed** by adversarial verification.

### CR-1 — Money-unit `_minor` fragmentation → **LIVE 100× understatement** in the recovery dashboard
- **Category:** Data Model Defect · **Severity:** High (CONFIRMED — verifier found it is *worse* than reported)
- The `_minor` suffix denotes three different encodings inside `_shared/finance/`: BIGINT paise (recovery/concessions, `20260823000000:65,116`; `20260822000000:24`), NUMERIC(12,2) **rupees** (installments/head-allocations, `20260827000000:36,82-83` — the migration's own comment confirms rupee scale), and INTEGER whole rupees (payment engine, `20260614600000:12,40`).
- **The verifier reproduced an active bug:** `finance_recovery_repository.ts:437-440` sums `finance_collections.amount_collected` (NUMERIC **rupees**), labels it `recovered_this_month_minor`, then divides by 100 via `minorToRupees` (`handlers.ts:346,356,578-581`). The recovery dashboard's "recovered this month" and per-collector "amountRecovered" are **understated 100×**, and `attainmentPct` divides a rupee-scale value by a paise-scale target.
- **Fix before extending finance:** standardize one money unit domain-wide (recommend integer paise everywhere), rename the NUMERIC columns that are *not* minor units, and correct the recovery repository/handlers scaling. Add a cross-table test that fails if a `_minor` column is not BIGINT.

### CR-2 — Guardian-unlink RLS remediation is incomplete → de-authorized guardian reads a revoked child's records
- **Category:** Security Defect · **Severity:** High (CONFIRMED)
- PRA-P1-02 added `AND status='active'` to the guardian sub-select only for finance + enrollments (`20260900000012`). **Five other parent-facing read policies still gate on ANY guardian link with no status filter** and are the current definitions: `attendance_records_parent_student_read` (`20260706000000:37-41`), `exam_mark_entries_school` (`20260614830000:11-15`), `exam_remarks_access` (`20260629000000:42-46`), `homework_submissions_parent_read` (`20260836000000:76-80`), `intel_parent_guidance_parent_scope` (`20260802000000:36-40`).
- A guardian with an active link to Child A and an **inactive** (revoked — custody change, estrangement, deletion request) link to Child B in the same school obtains a parent-scope session and can read Child B's attendance, exam marks, teacher remarks, homework, and AI guidance. Same-org (not cross-tenant), but it is broken access control / PII exposure to a person the school explicitly de-authorized.
- **Fix:** re-create the five policies verbatim with `AND status='active'`, and add a permanent guard test scanning every parent-scope guardian sub-select for the active-status predicate (the homework-hardening migration *reintroduced* the bug, so a regression guard is essential).

### CR-3 — Offline-instrument reconcile double-credit race
- **Category:** Implementation Defect (money-integrity) · **Severity:** High (CONFIRMED)
- `reconcileOfflinePayment` (`finance_offline_payments_repository.ts:224-293`) does a **plain unlocked** `getOfflinePayment`, checks `status==='reconciled'`, calls `createCollection`, then a terminal UPDATE guarded only by `AND status <> 'bounced'` — **not** `AND status='pending_reconciliation'`. Two concurrent reconciles both read `pending`, both pass, and against an invoice whose outstanding ≥ 2× the instrument amount, `createCollection`'s invoice `FOR UPDATE` guard (`amountCollected > outstanding`) rejects neither → **two collections booked for one cheque/DD**. No idempotency key is passed, so the collection-level replay index is inert.
- This is precisely the project's own tracked "terminal state-write with no status guard → concurrent double-apply of a delta" pattern. The only test uses a mock that ignores the guard and never counts posted rows.
- **Fix:** `SELECT … FOR UPDATE` the instrument row before the reconciled-check, make the terminal UPDATE the atomic guard (`AND status='pending_reconciliation'` + throw-on-0-rows), add a unique constraint tying an instrument to ≤1 collection, and add a concurrent live cert.

### CR-4 — Receipt-number global UNIQUE collision blocks a second school's collections
- **Category:** Data Model Defect · **Severity:** High (CONFIRMED)
- `finance_receipts.receipt_number` is `TEXT NOT NULL UNIQUE` with **no org/school scope** (`20260612500000:30`). The gapless sequence formats as `${prefix}/${fiscalYear}/${seq}` with prefix defaulting to `"RCP"` and `seq` from a **per-(org,school,fiscal_year)** counter restarting at 1 — the string contains no school/org discriminator (`finance_collections_repository.ts:245-259`). Two schools in the same org (or two orgs) that keep the default `"RCP"` prefix and share a fiscal year both generate `RCP/2026-27/000001`; the second school's first collection INSERT throws a duplicate-key violation and the whole transaction rolls back — **the school cannot record its first payment**, and one tenant's data pattern denies inserts to another (availability-isolation break).
- Gated behind opt-in receipt-sequencing (default off), which keeps it High rather than Critical.
- **Fix:** scope the UNIQUE to `(organization_id, receipt_number)` (or include `school_id`) and/or embed a school code in the number; enforce distinct per-school prefixes.

### CR-5 — `attendance_records` (highest-volume table) has no tenant/student index
- **Category:** Performance Defect · **Severity:** High (verifier corrected from Critical → High: real foundation gap but no correctness/security/money impact, and fixable in one line)
- `attendance_records` (`20260614800000:21-33`) has only `PK(id)` and `UNIQUE(session_id, student_id)`; no index across all 244 migrations serves the hot predicates. The parent-app attendance snapshot filters `student_id` (a session-leading UNIQUE can't serve it), and the student-risk board runs a `LEFT JOIN LATERAL` over the table **once per active student** — genuinely quadratic. The table grows as students × school-days (~100M rows/year at 1,000 schools).
- Invisible at pilot scale; a foundation flaw on the roadmap's critical path.
- **Fix:** `CREATE INDEX ON attendance_records (organization_id, school_id, student_id)` (+ `(organization_id, school_id)`); re-EXPLAIN the three cited queries.

### CR-6 — Universal idempotency wrapper is non-atomic and can permanently poison the key
- **Category:** Engineering Defect · **Severity:** High (CONFIRMED)
- In `idempotency_dispatch.ts` the `claim()` (`:115`), the write (`dispatch()` → handler's own transaction), and `store()` (`:146`) run in **three separate transactions**; `store()` is not wrapped in try/catch. If the isolate dies or `store()` throws after the write commits, the row stays `response_payload IS NULL`; every retry hits `ON CONFLICT DO NOTHING` → permanent **409 IDEMPOTENCY_CONFLICT**, and a `store()` throw returns a **500 for a payment that already committed**. Because the wrapper short-circuits at `claim()` before dispatch, its poisoned 409 also **preempts the stronger inner finance idempotency backstop** — the generic layer defeats the money-safe layer. There is no TTL/reaper (verified: zero cleanup code across all migrations/functions).
- Narrow post-commit crash window; no ledger loss/duplication, which keeps it below Critical.
- **Fix:** claim+write+store in one transaction (the generic entity-write path `module_write_handlers.ts` already does this correctly), or add a bounded in-flight TTL so a stale NULL-payload claim is re-claimable; wrap `store()`; yield to the route's own replay on an in-flight row.

### CR-7 — Unsigned webhook accepts a forged capture in stub mode → fraudulent "paid" receipt
- **Category:** Security Defect · **Severity:** High (CONFIRMED, but gated)
- `verifyRazorpayWebhookSignature` returns `true` when `stubMode && signature===null` (`razorpay_client.ts:87-89`); `RAZORPAY_STUB_MODE` defaults `'true'`. The webhook route is public (`verify_jwt=false`, no `authenticateRequest`). An authenticated parent who calls `initiatePayment` (which returns `razorpayOrderId`) can POST an unsigned `payment.captured` and `processRazorpayWebhook` writes a `finance_collection` + `finance_receipt` and marks the intent captured with **zero real payment** (capped at one per intent by the `status==='captured'` early-return).
- The whole online-payment flow is stub/owner-gated (P0-02), but the endpoint ships in the certified build and the fraudulent *ledger write* occurs regardless of gateway.
- **Fix:** enforce webhook signatures independently of `stubMode` (bypass only under an explicit dev flag), or refuse capture events while stub mode is on. Never treat a null signature as valid.

---

## 6. Recommended Improvements (Medium / Low, by category)

**Security Defects**
- SECURITY DEFINER onboarding functions (`onboarding_ensure_school_membership`, `onboarding_upsert_user_by_phone`) have no in-DB tenant/role guardrails — add in-function `app_current_school_id()`/tenant assertions + role allowlist (currently safe only because one app-layer caller gates them). *Same defense-in-depth pattern applies to `assign_organization_subscription` (Red Team, Low).*
- **OTP returned in the login response for pilot phones in production** (`auth_handlers.ts:102-106`) — the pilot-phone branch isn't environment-gated, so anyone who knows an allowlisted owner/admin number can complete login with no SMS possession. **Must-remove-before-GA;** gate behind `environment!=='production'` and keep the allowlist empty of real privileged phones.
- OTP stored as unsalted SHA-256 of a 6-digit code (reversible on DB compromise within the 5-min window) — HMAC under a server secret (Low).
- Internal health token uses non-constant-time comparison — reuse `timingSafeEqualHex` (Low).
- `audit_events` INSERT policy binds `organization_id` but not `school_id` — a school-scoped caller can mis-tag another school's audit row within its org (Low).
- Support mirror-bridge first-insert trusts an attacker-chosen incident id (unguessable v4 UUID, so minimal) — add an `EXISTS` provenance check (Low).
- `handleRevokeSession` revokes `refresh_tokens` by `session_id` without an owner check — constrain to the caller's own sessions (Low).

**Engineering / Implementation Defects**
- Idempotency replay never verifies the stored method/path fingerprint — reusing one key across endpoints replays the wrong response (Medium).
- Copy-pasted `isUniqueViolation` and SAVEPOINT-recovery idioms across 5-6 repositories — extract into the shared `db`/`tenant_db` kernel (Medium).
- `request_idempotency` has no retention/reaper — completed rows and orphan NULL rows grow unbounded (Low/Medium).

**Data Model Defects**
- Payment tables use INTEGER whole rupees while finance uses NUMERIC(12,2) — paise cannot round-trip the payment path (latent until a fee carries paise) (Medium). *Part of the CR-1 unification.*
- No DB single-current-enrollment guarantee — add a partial `UNIQUE(student_id) WHERE is_current` so concurrent enroll/promote can't leave two current rows (Low).
- Operational tables use soft FKs (attendance/homework/comm) with no referential integrity — document the invariant + orphan-detection, or restore FKs where decoupling isn't required (Low).
- Inconsistent migration idempotency guards (mixed `IF NOT EXISTS`) — complicates incident re-run (Low).

**Performance Defects**
- Director/management dashboards recompute **all-time** aggregates over the two fastest-growing tables synchronously per request with no window/cache — add bounded windows + a materialized/cached snapshot (Medium).
- `listAttendanceSessions` is unbounded (no LIMIT/date filter) with a per-row `count()` join — add pagination + date window (Medium; existing indexes blunt it below the reviewer's original framing).
- `bulkAssignFeeStructure` is an N+1 storm (~9 queries × student in one transaction) — batch reads with `= ANY($ids)` and multi-row inserts (Medium).
- Per-isolate connection pool (`POOL_SIZE=10`) has no global ceiling — front with PgBouncer/Supavisor before multi-school scale-out (Medium Operational Risk).
- Broadcast fan-out silently truncates recipients >5,000 — chunk into queued batches or surface a partial-send error (Medium Operational Risk).
- Generic list store uses OFFSET + uncached `count(*)` per page — prefer keyset pagination for large collections (Low).

**Architecture / Product Design Defects**
- `domain_events` "outbox" worker flips rows to `published` **without dispatching to any subscriber** — either add a subscriber registry or document it as an internal signal log, not an integration bus, before the roadmap assumes delivery semantics (Medium).
- Role/permission catalog is global (PK=slug, no tenant scope) while `is_system` implies custom roles were planned — decide now on per-tenant custom roles (SOP-ID cluster) before the FKs are widely depended on (Low).
- Commercial entitlement enforcement defaults **OFF** (`ENTITLEMENT_ENFORCEMENT` unset) — the plan/suspension gates are inert until flipped; track the flip as a go-live gate with a pre-flip plan-assignment audit and an ON-path smoke test (Low Operational Risk).
- God-files (transport_write 1,953; pilot_operations_repository 3,313; app_router.dart 3,056) — split along finance's per-concern boundary (Medium).
- Order-dependent routing with greedy prefix guards that 404 on unmatched — move to an explicit prefix→router registry (Medium).
- Two-tier persistence (JSONB `{module}_entities` vs relational) with soft cross-module references — document the invariant + reconciliation, or promote high-integrity JSONB modules to relational with FKs (Low — verifier corrected from High; no hard-delete path exists so references can't dangle today).
- `students` identity table has three writers and no owning service — introduce a single SIS-owned `createStudent()` (Medium).

**Domain-correctness (Data Model / Product Design)**
- Term tabulation register drops multiple same-subject exams sharing a term label (last-write-wins by subject string) → wrong report-card totals/rank where FA/SA share a term (Medium).
- TC certificate asserts "All dues have been cleared" while inventory dues are advisory/never queried and the library gate depends on a `sisStudentId` the module reports as un-trackable — either gate those sources or caveat the wording (Medium).
- Management attendance aggregate returns 0% (not null) on zero denominator, and the student-risk engine fabricates optimistic 92%/85% defaults for students with no data — both diverge from the canonical "null = no data" rule and can hide at-risk students (Low).

---

## 7. Items Safe to Leave Unchanged (verified sound / claims refuted)

- **Per-route RBAC coverage — REFUTED as a gap.** A 47-file per-domain `*_route_contract_test.ts` suite signs real JWTs and dispatches through the actual routers, asserting per-route that a token lacking the slug gets 403 and a holder passes — the both-branch, real-dispatch check. RBAC drift *is* caught. No change needed.
- **Main payment-capture double-apply — REFUTED.** `markIntentCaptured` is an atomic `… WHERE status<>'captured'` guard that throws-on-0-rows inside the same transaction as the collection; the losing concurrent capture rolls back entirely. Two collections for one payment cannot both persist on this path. (The *offline-reconcile* path CR-3 and the *unsigned-webhook* path CR-7 are separate and real.)
- **Core direct-collection concurrency, refund claim-first transition, receipt-sequence atomicity, day-close locking, optimistic cancel guards** — verified correct; leave as-is.
- **Tenant isolation mechanics** (server-derived tenant_id, non-bypass role, FORCE RLS, transaction-local GUC, deploy assertion, mirror-bridge org wall) — verified airtight; leave as-is.
- **Auth hardening** (HS256 pin, secret length floor, per-request session/permission freshness, refresh rotation + reuse detection, AES-GCM vault, constant-time money signatures) — leave as-is.
- **Attendance %, exam absent-vs-zero, clearance fail-closed semantics, TC serial atomicity** — verified correct; leave as-is.
- **The env-gating of RLS integration tests itself** is defensible (RLS needs a live Postgres with roles/migrations). The gap is *wiring the probes into an always-on gate*, not the tests — mitigated today by runtime `/health/tenant-access` probes asserted in ~8 deploy/launch verification scripts plus a `MIN_PROBE_COUNT=233` unit tripwire.

---

## 8. Items That Require Refactoring/Correction Before Continuing the Roadmap

**Must fix before extending the *finance* domain (installments, recovery, Tally map, payroll postings are all in flight):**
- **CR-1** money-unit unification + the live 100× recovery-dashboard correction.
- **CR-3** offline-reconcile race guard.
- **CR-4** receipt-number uniqueness scoping.
- **CR-6** idempotency-wrapper atomicity (it can defeat the money-safe backstop).

**Must fix before re-deploying the trunk to the pilot / before GA:**
- **CR-2** guardian-unlink RLS leak (live PII/access-control) + regression guard.
- **CR-7** webhook signature enforcement independent of stub mode.
- OTP-in-login-response for pilot phones (possession-factor bypass on privileged accounts).
- Client mock/real boundary: add `SUPPORT_API_ENABLED` to `config/live_release.json` (or a `/support` surface gate), and apply the auth SEC-9 fail-closed pattern uniformly so a missing flag breaks the build instead of silently serving fabricated data. *(PARTIAL→Medium: bounded to the support module; the trunk has not yet been redeployed to the pilot, so it is latent in the next build.)*

**Must fix before multi-school scale-out (not before the next feature, but before onboarding many schools):**
- **CR-5** `attendance_records` index (one-line migration) + the director/management all-time-aggregate windowing/caching + a transaction-pooler in front of tenant connections.

**Should schedule as a hygiene wave (not roadmap-blocking):**
- Wire the built-but-unwired `expense_ledger` / decide `domain_events` bus semantics; add real-DB tests to the merge gate for money-race + isolation guards; extract the shared DB kernel; split god-files; resolve the global-vs-tenant role-catalog decision before SOP custom roles.

---

## 9. Final Verdict

> ## ✅ INTERIM CERTIFIED — Continue After Moderate Corrections

The foundation is sound, coherent, and safe to build on. Tenant isolation, the core money path, and auth are engineering-grade, and the two most dangerous hypothesized failures were refuted on verification. But the board **confirmed active, in-scope integrity defects** — a live 100× money-understatement, a same-org PII leak, a double-credit reconcile race, and a receipt-collision that can block collections — plus a foundation-level indexing gap. These are correctable without architectural rework, but they are real and several are *live, not latent*. Continue the roadmap **after** the CR-1…CR-7 corrections (and the OTP/support-mock GA items), prioritizing the finance-domain and parent-facing fixes before any further weight is placed on those surfaces or the trunk is re-deployed to the pilot.

*Not certified as GA-ready. This certifies the interim foundation only, per the stated scope.*
