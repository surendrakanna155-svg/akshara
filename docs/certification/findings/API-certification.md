# Workstream 7 — API Certification

**Scope:** every production API surface of the NIKSHA OS Deno edge function
(`supabase/functions/api`), enumerated from the declarative route registry
(`_shared/route_registry.ts`) and the 66 module routers under `_shared/**`.

**Date:** 2026-07-29 · **Branch:** `release/v1.0-playstore` @ `87300c44`
**Mode:** READ-ONLY certification. No fixes, no commits. Defects → `DEFECT_REGISTER.md` (`API-` prefix).

## Method

1. **Enumeration** — mechanical extraction of `(method, path)` pairs from every
   non-test `*.ts` under `_shared/` matching the three routing idioms in use
   (`path === "…" && method === "…"`, the reverse order, and
   `path.match(/^\/…$/)` + a method guard in the same block), then cross-read of
   the registry and of each high-risk router by hand.
2. **RBAC completeness sweep** — diff of the extracted route set against
   `_shared/validation/rbac_route_inventory.ts` (315 declared rules).
3. **Hand certification** of the high-risk surfaces: money (finance, payment),
   marks (exam administration), attendance, SIS/identity, approvals, audit,
   support, and the reliability outbox contract on the client side.
4. **Live read-only probing** of `https://akshara.veloraunisexsalon.com` —
   unauthenticated `GET`/`OPTIONS` only. Every probe and its verbatim response is
   recorded in §2. No mutations, no authentication attempts, no real data.

## Verification boundaries (inherited + newly discovered)

- **No Postgres lane.** RLS policies are read as DDL; they were not executed.
  Every "tenant isolation" statement below is a *code+DDL* reading, not a live
  cross-tenant test. The one live signal available is `GET /health/tenant-access`
  (§2), which the pilot currently reports as **degraded**.
- **SSH owner-bound** — no container introspection, so "what is deployed" could
  only be inferred from black-box probes.
- **Unauthenticated probing only** — no route's authorised response shape,
  pagination, or tenant behaviour could be exercised live.
- **NEW:** the live pilot's `GET /health` reports `version: "unknown"`,
  `builtAt: null`, so the deployed commit **cannot be identified**. Everything
  certified below is certified against the *repository*; §2 shows the live
  deployment demonstrably differs from it.

---

## 1. Enumeration and registry integrity

### 1.1 What the surface actually is

| Measure | Count |
|---|---|
| Module routers registered in `MODULE_ROUTES` | 66 |
| `*_router.ts` files (non-test) under `_shared/` | 66 |
| Distinct `(method, literal path)` pairs extracted | 384 |
| Distinct `(method, parameterised path)` pairs extracted | 428 |
| Non-module routes matched directly in `api/app.ts` | 20 (7 health, 10 auth, +3) |
| Rules in `RBAC_ROUTE_INVENTORY` | 315 |

The extraction is a static approximation (a handler reached only through a
`switch` on a path segment — the support and complaints routers do this — is
counted once per literal case, and a regex route's method is inferred from the
enclosing block). It is accurate enough to bound the problem: **the real route
surface is roughly 700–800 `(method, path)` pairs and the RBAC inventory
describes 315 of them.**

### 1.2 The RBAC inventory is not a completeness gate — API-100 … API-103

The RC phase found two attendance routes missing from
`rbac_route_inventory.ts` and a `GET /audit/retention` not registered. Those are
not outliers; they are two samples from a systematically incomplete file. The
sweep found:

- **232 literal routes absent** from the inventory, **97 of them mutating**
  (`POST`/`PUT`/`PATCH`/`DELETE`).
- **~250 parameterised mutating routes absent** (e.g. every
  `/academics/exams/*` mark-write route, every `/approvals/:id/{approve,reject,cancel}`,
  every `/admissions/leads/:id/*` transition).
- **91 inventory entries with no matching route in the code** — stale rules that
  the "RBAC matrix" test still exercises and passes.

The attendance module is the clearest illustration. `attendance_router.ts`
exposes **11 routes**; the inventory contains **one** attendance rule
(`POST /parent/attendance/corrections`). Missing entirely:
`GET /attendance/sessions`, `GET /attendance/sessions/:id`,
`GET /attendance/register`, `GET /attendance/register/monthly`,
`GET /attendance/pending`, `GET /attendance/alerts/consecutive-absence`,
`GET /attendance/alerts/short-attendance`, `GET /attendance/corrections`,
`GET /attendance/corrections/:id`, **`POST /attendance/corrections`** and
**`PATCH /attendance/corrections/:id/status`** — the last of which is the
approval action that flips a child's attendance record.

Money is no better. Absent from the inventory: `POST /finance/collections`
(taking a fee payment), `POST /finance/refunds` (raising a refund),
`POST /finance/day-close`, `POST /finance/discounts`,
`POST /finance/fee-assignments` + `/bulk`, `POST /finance/late-fees/accrue`,
`POST /finance/fee-reductions/discount-applications`,
`POST /finance/fee-reductions/scholarship-awards`,
`POST /finance/recovery/{contacts,promises,targets}`. The inventory's only
finance write rules are `POST /finance/fee-structures` and
`POST /finance/refunds/:id/approve`.

**Why it stays broken:** nothing compares the inventory to the code.
`rbac_route_validation_test.ts` and `rbac_full_matrix_test.ts` both iterate
`RBAC_ROUTE_INVENTORY` and call the *pure function* `requirePermission(claims, rule.permission)`.
They never construct a `Request`, never call `matchModuleRoute`, and never touch
a handler. The suite therefore proves that `requirePermission` denies a
non-holder — a property of a 20-line function — and proves **nothing** about any
route. A route added with no gate at all, or with the wrong gate, passes the
whole RBAC suite by simply not being listed. That is precisely the mechanism
that let the two attendance routes ship unaudited, and it is still open.

The stale half is equally load-bearing: the inventory still declares
`PUT /teacher/exams/marks/:id` (`manageExamMarks`), a route **deleted by
PRA-P0-12**, while the governed replacement `PUT /academics/exams/marks/:id` is
absent. Anyone reading the inventory to answer "what gates a mark change?" is
reading a rule for a route that no longer exists.

### 1.3 Registry prefix declaration is incomplete — API-104

`MODULE_ROUTES` declares `{ name: "audit", prefixes: ["/audit"] }`, but
`routeAudit` also owns `POST /domain-events/process-pending`:

```ts
if (!path.startsWith("/audit") && path !== "/domain-events/process-pending") return null;
```

The prefix table is the input to the single-ownership guard
(`route_registry_test.ts`). A path the table does not know about cannot be
checked for double-ownership, so the guarantee the registry exists to provide
("no `(method, path)` is claimed by two entries") does not cover this route. It
is also a mutating, unauthenticated-by-inventory route that processes the domain
event queue.

### 1.4 Routes that exist but no persona can be shown to reach

`POST /approvals/audit` (`handleRecordApprovalAudit`) inserts a row directly into
`approval_audit_entries` from a **client-supplied `actor_id` and `actor_name`**
— see API-110. No client code was found calling it. A write endpoint into the
audit trail with no caller is pure attack surface.

---

## 2. Live probe log — `https://akshara.veloraunisexsalon.com`

Unauthenticated `GET`/`OPTIONS` only. No mutations, no credentials, no real
identifiers. Every response below is verbatim.

| # | Probe | Status | Body / note |
|---|---|---|---|
| P1 | `GET /health` | 200 | `{"status":"ok","service":"akshara-api","version":"unknown","builtAt":null}` |
| P2 | `GET /health/ready` | 200 | `{"status":"ready","database":true}` |
| P3 | `GET /health/tenant-access` | **503** | `status:"degraded"` + full RLS isolation matrix (see §2.3) |
| P4 | `GET /health/operations` | 200 | `pendingEvents:0, pendingDeliveries:23, openApCommitments:2, previewedImportJobs:2` |
| P5 | `GET /health/storage` | 200 | `bucket:"school-memories", reachable:true` |
| P6 | `GET /health/providers` | 200 | `vault:{configured:false}, delivery:{pendingQueue:-1}` |
| P7 | `GET /health/backup` | 200 | nightly backup sha256, bytes, `offsite:false`, `finishedAt` |
| P8 | `GET /zzz/nope` | **404** | `NOT_FOUND — Route not found: GET /zzz/nope` |
| P9 | `GET /support/incidents/not-a-uuid` | **422** | `VALIDATION — invalid incident id` |
| P10 | `GET /support/platform/incidents/not-a-uuid` | **422** | `VALIDATION — invalid incident id` |
| P11 | `GET /support/incidents` | 401 | `UNAUTHORIZED — Missing bearer token` |
| P12 | `GET /attendance/register/monthly` | **422** | `ATTENDANCE_VALIDATION — classLabel is required` |
| P13 | `GET /audit/events` | **404** | route exists in repo |
| P14 | `GET /audit/retention` | **404** | route exists in repo |
| P15 | `GET /identity/roles` | **404** | route exists in repo |
| P16 | `GET /finance/dashboard`, `/finance/collections`, `/payments/intents/xyz`, `/plans`, `/subscription`, `/search`, `/copilot/sessions`, `/school-config`, `/education/question-bank`, `/academics/exams`, `/transport/routes`, `/hr/staff-duties/substitutions`, `/inventory/stock/approvals`, `/widgets/registry`, `/widgets/data-sources`, `/analytics/dashboard`, `/dashboard/overview`, `/intelligence/priorities`, `/legal/status`, `/certificate-requests`, `/gate-passes`, `/complaints`, `/sis/clearance/waivers`, `/staff-attendance/geofence`, `/attendance/corrections`, `/attendance/alerts/short-attendance` | 401 | `UNAUTHORIZED — Missing bearer token` (26 paths) |
| P17 | `OPTIONS /finance/collections` (Origin: `https://evil.example`) | 200 | `Access-Control-Allow-Origin: *`, `Allow-Methods: GET, POST, PUT, PATCH, OPTIONS` |

Security headers are present on every response
(`nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`,
`CSP: default-src 'none'; frame-ancestors 'none'`), and every response —
including the 404s and 422s — carries an `x-correlation-id`, confirming these
responses are produced by the application, not by nginx.

### 2.1 The deployed build is not this branch — API-105 (P0)

P8/P9/P10/P12 are decisive. `api/app.ts` on this branch authenticates **before**
dispatch:

```ts
if (!isPublicModuleRoute(method, path)) {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;      // ← 401 for EVERY module path
}
return dispatchWithIdempotency(req, config, async () => { … 404 … });
```

and `api/eng4_5_forced_auth_test.ts` asserts exactly this:

> `ICA-F1: an unauthenticated request to ANY module path is 401 at the central
> gate` … "so even an unknown route returns 401 (not 404) — unauthenticated
> callers cannot enumerate which routes exist."

**In production that is false.** An anonymous caller gets 404 for an unknown
path, 422 for a malformed support incident id, and 422 with the parameter
contract (`classLabel is required`) for the attendance monthly register. The
only build that behaves this way is one where routing and per-route validation
run *before* authentication — i.e. one that predates ICA-F1
(`e0e98375`, 2026-07-21). P13/P14/P15 corroborate: three routes that exist on
this branch return 404 live.

Consequences that matter for release:

1. **The ICA-F1 guarantee is a repository property, not a production one.** In
   the live build every route is authenticated only because its own handler
   remembers to call `authenticateRequest`. There is no backstop. Any handler
   that forgets is anonymous — and the RBAC inventory (§1.2) cannot detect that,
   because it never dispatches a request either.
2. **Route enumeration is open.** An anonymous scanner can map the entire API by
   404-vs-401, which is the reconnaissance step ICA-F1 was built to close.
3. **Nothing certified against this branch can be asserted about production**
   until a deploy + re-probe. This is the single largest boundary in this
   workstream.
4. `GET /health` cannot resolve the delta because it reports
   `version: "unknown", builtAt: null` — the deploy step never wrote
   `build_info.json` or set `AKSHARA_BUILD_SHA`, so the mechanism built to answer
   "which commit is live" (`_shared/build_info.ts`) returns nothing (**API-106**).

### 2.2 Sensitive health endpoints are open to the internet — API-107 (P0)

P3–P7 return 200/503 with full payloads and **no `x-internal-health-token`**.
`_shared/internal_health_auth.ts` is supposed to prevent this:

```ts
const configured = config.internalHealthToken;
if (!configured) {
  if (config.environment === "production") return errorEnvelope("FORBIDDEN", …, 403);
  return null;                                   // ← pass-through
}
```

The guard has existed since the pilot build (`9057bfb8`, 2026-06-10), so it is
almost certainly present in the deployed code. Its passing through therefore
implies **`INTERNAL_HEALTH_TOKEN` is unset *and* `APP_ENV` is not `production`**
on the live container.

What this leaks today, anonymously: the tenant's school count
(`visible_schools=7`), the internal DB role name (`erp_tenant`), the complete
RLS isolation test matrix including which tests fail, operational queue depths,
the storage bucket name, that the vault is not configured, and the nightly
backup's SHA-256, byte size, offsite status and completion time.

**The second-order risk is worse than the leak.** `APP_ENV != "production"` is
the same flag that gates OTP delivery:

```ts
export function canReturnOtpInResponse(config: AppConfig, phone: string): boolean {
  if (config.environment === "production") return false;
  if (config.otpPilotPhones.includes(phone)) return true;
  if (config.otpDevMode && config.environment !== "production") return true;
  return false;
}
```

If `APP_ENV` is genuinely not `production` on the pilot, then `POST /auth/login`
returns the OTP **in the response body** for any allowlisted pilot phone, and for
*every* phone if `OTP_DEV_MODE` is on — account takeover with no SMS. This was
**not tested** (it is a mutation and an authentication attempt; both are out of
scope for this pass). It requires owner verification of the container's `APP_ENV`
and `OTP_DEV_MODE` before release. The repo test
`ICA-B2: canReturnOtpInResponse is false in production` passes — and, exactly as
in §2.1, asserts a premise the live environment may not satisfy.

### 2.3 Live RLS isolation is failing — API-108 (P0)

`GET /health/tenant-access` returns `status: "degraded"`, `isolation.pass: false`
with `enforced: true`, role `erp_tenant`, `bypassRls: false`. Of the isolation
probes in `_shared/tenant_isolation_probes.ts`, **four fail on the live pilot
right now**:

| Probe | Live detail | Expected |
|---|---|---|
| `student_denied_student_profiles` | `visible_profiles=1` | 0 |
| `student_denied_sis_students_api` | `visible_directory_rows=1` | 0 |
| `student_denied_sis_student_create` | `visible_profiles_for_create=1` | 0 |
| `student_denied_sis_dashboard` | `visible_directory_rows=1` | 0 |

Every school↔school and parent↔child probe passes
(`school_a_cannot_see_school_b`, `school_a_cannot_see_school_b_students`,
`parent_cannot_see_unlinked_student`, `org_scope_denied_raw_students`, …), so
this is **not** cross-tenant leakage between schools. It is a **persona**
isolation failure: a `student`-scope database session can see rows through
`student_profiles` and the SIS directory/create/dashboard query shapes that the
probe asserts it must not.

This is the only live database-isolation evidence available in this harness (no
Postgres lane, no SSH), and it is currently red. Whether the visible row is the
student's own record — in which case the probe's premise is wrong and the
**probe** is the defect — or another student's, cannot be determined without DB
access. Either way the pilot's own isolation self-test reports FAIL and a
release cannot be certified over a red isolation matrix. **Owner action
required.**

### 2.4 CORS omits `DELETE` while the API exposes `DELETE` routes — API-109 (P2)

`Access-Control-Allow-Methods: GET, POST, PUT, PATCH, OPTIONS` (verified live,
P17) — but the API has `DELETE` routes, several of them in the RBAC inventory
itself (`DELETE /academic/timetables/substitutions/:id`,
`DELETE /sis/students/:id/guardians/:guardianUserId`,
`DELETE /identity/permission-overrides`-family). A browser client (the `web/`
app) cannot issue them: the preflight response does not list `DELETE`, so the
request never leaves the browser. The Flutter client is unaffected (no
preflight). Separately, `Access-Control-Allow-Origin: *` lets any origin script
call the API with a bearer token it already holds; with `*` the browser refuses
to send cookies, and this API is bearer-only, so the practical risk is bounded —
but `*` on a school-data API is not a defensible default.

---

## 3. Permissions — is every mutating route gated?

### 3.1 The result: in the repository, yes

A route→handler map was built from all 66 routers, then every handler reached by
a `POST`/`PUT`/`PATCH`/`DELETE` was resolved (through one or two levels of local
helper — `guard()`, `withAuth()`, `runWrite()`, the `createModule*Handlers` and
`create*ScopedReadHandlers` factories) and checked for a permission or scope
gate. **No ungated mutating route was found.** The two legitimate exceptions are
signature-authenticated by design and were confirmed fail-closed:

- `POST /webhooks/razorpay` — HMAC-verified. `RT-23` decoupled signature
  enforcement from `stubMode`, and `ICA-A5` additionally refuses to post to the
  books while the gateway is stubbed. Both were read and hold.
- `POST /communications/delivery/webhook` — `verifyCommunicationWebhookSignature`.
- `POST /communications/broadcasts/run-scheduled` also accepts an
  `x-internal-cron-token`; `verifyInternalCronToken` returns `false` when the
  token is unset (fail-closed), verified in `communication_cron_auth.ts:72`.

This is a real and non-obvious strength, and it should be recorded as such: the
gate coverage is good. What is broken is the *machinery that is supposed to
prove* it (§1.2) — and that machinery failing is what will let the next
ungated route through.

The 96 permission slugs in the inventory were also checked against handler code:
**95 are genuinely enforced somewhere.** Exactly one is fiction — see §3.2.

### 3.2 `viewPayments` is enforced nowhere — API-111

The inventory declares:

```ts
{ method: "GET", path: "/payments/intents/:id", permission: "viewPayments", scope: "school", module: "payment" },
```

`handleGetPaymentIntent` never calls `requirePermission`. Its only gate is:

```ts
if (auth.claims.scope !== "parent" && auth.claims.scope !== "school") { …403… }
```

The string `"viewPayments"` appears in the entire backend **only** inside
`rbac_route_inventory.ts` — it is enforced by no handler and granted by no role
seed. So *any* school-scope session (a teacher, a librarian, a transport clerk)
can read any payment intent in its school by id, including `amount`,
`gatewayOrderId`, `collectionId`, `invoiceId` and `refundId`. School isolation
holds (the `payment_intents_school_read` RLS policy pins `school_id`), so this is
an intra-school over-exposure, not a tenant leak. The defect worth weighting is
that **the inventory documents a control that does not exist**, and the RBAC
suite happily green-lights it because it only ever tests the inventory against
itself.

### 3.3 `POST /approvals/audit` accepts a caller-supplied actor — API-110

`handleRecordApprovalAudit` correctly requires `manageManagement` (RT-22 fixed an
earlier `viewManagement` gate), but then writes the audit row from the **request
body**:

```ts
const actorId   = optionalStr(body, "actor_id",   "actorId");
const actorName = optionalStr(body, "actor_name", "actorName");
…
insertAuditEntry(db, orgId, schoolId, approvalRequestId,
  action as "submitted" | "approved" | "rejected" | "cancelled",
  actorId, actorName, …);
```

`auth.claims.sub` is available and ignored. A `manageManagement` holder can
therefore write an approval-audit entry attributing an approval to *any* named
person. An audit trail whose actor is client-supplied is not an audit trail. The
`action` is also a bare `as` cast with no runtime validation — the value reaches
the `approval_audit_action_check` constraint, so a bad value becomes a **500**
rather than a 422.

### 3.4 Batch approvals record a placeholder approver — API-112

`handleBatchDecideApprovals` sets `const actorName = "Approver";` before calling
the shared `decideOne`. The single-decision endpoints pass the real name. So the
same approval decision is attributed to a named person when taken one at a time
and to the literal string "Approver" when taken from the multi-select — in the
same `approval_audit_entries` table an auditor reads. `actorId` is correct in
both, so the record is recoverable, but any human-readable approval report is
wrong for every batch decision.

### 3.5 Separation of duties is coarse in HR/inventory/transport/library

`createModuleWriteHandlers` takes exactly **one** `manage*` permission for a
whole module: `manageHr` covers creating an employee, approving leave, running
payroll and posting statutory liabilities to Finance; `manageInventory` covers
both stock issue and stock adjustment; `manageTransport` covers routes, vehicles
and the transport fee demand. Where the product has an explicit maker–checker
decision (fee concession FIN-D4, clearance waivers SCE-1, refunds, purchase
orders) the split is properly implemented with a distinct `approve*` slug. Where
it does not, a single slug is the whole authority. This is a design observation,
not a code defect — recorded so it is a deliberate choice rather than an
accident.

---

## 4. Validation

### 4.1 Money

`POST /finance/collections` is the best-validated write in the system and it
holds up:

- amount must be finite and `> 0` (handler **and** repository);
- the invoice row is locked, and `amountCollected > outstanding` is rejected;
- the collection date is refused if the day is closed (`FIN-D1`);
- cheque/DD/PDC cannot be entered directly — they must come through the offline
  instrument register (`PRA-P1-09`);
- the receipt number is allocated last, inside the transaction, so a rollback
  never burns a number (`PRA-P1-08`).

Two gaps remain:

**API-113 — money parsing silently truncates garbage.** `parseAmount` is
`parseFloat(String(raw))`. `parseFloat("100abc")` is `100`, `parseFloat("1e5")`
is `100000`, and `"12.999"` is accepted at sub-paisa precision with no 2-decimal
check and no upper bound. A malformed client field becomes a *plausible* amount
rather than a 422. The same `parseFloat`-and-hope idiom appears across the
finance handlers.

**API-114 — `maxMarks` accepts values that brick an exam.**
`handleCreateExam` computes `maxMarks: Number(body.maxMarks ?? body.max_marks ?? 100) || 100`.
Consequences: `maxMarks: 0` silently becomes `100`; `maxMarks: -50` is stored
(the column is `INTEGER NOT NULL DEFAULT 100` with **no** positivity CHECK), and
because the mark CHECK is `marks_obtained >= 0 AND marks_obtained <= max_marks`,
**every** subsequent mark entry for that exam fails at the database — the exam is
unusable and the teacher sees a 500-class error, not a validation message. A
fractional `maxMarks: 1.5` reaches an `INTEGER` column and errors as a 500.

### 4.2 Marks

`parseMarkPayload` + `applyMarkUpdate` are correct: `marksObtained` must be a
finite **non-negative integer** (RT-08), must be `<= max_marks`, status is a
closed enum, and `20260814000000_red_team_wave1_transactional_integrity.sql`
adds the DB CHECK as the backstop. Absent/medical/debarred correctly store NULL
marks with a status rather than a 0. No defect found.

### 4.3 Dates

Dates are validated per-handler against explicit regexes (`DATE_RE` = `YYYY-MM-DD`,
`MONTH_RE` = `YYYY-MM`) and `parseDeadline` rejects an unparseable timestamp with
a 422 *before* opening the tenant context (EXM-6) — a good pattern. There is,
however, no shared date validator: each module re-declares its own, so the
rejection message and the accepted format vary by module. Not a defect on its
own; it is why a date bug in one module will not be caught by another's tests.

### 4.4 Free text — API-115

Length constraints exist in exactly three places: the ASIP support tables
(`title` 1–200, `description`/`body` ≤ 8000), `org_assets`, and
`expense_ledger.category`. Everywhere else in the core ERP — `exam_sessions.title`,
`approval_requests.title`, `finance_collections.notes`,
`finance_collections.reference_number`, complaint text, broadcast bodies,
student names — the column is bare `TEXT` and the handler applies `String(...)`
and `.trim()` with **no maximum length**. Nothing in the request path caps a
string field. A single request can persist a multi-megabyte "notes" value that
then has to be rendered into a receipt, a report and a PDF. The `MAX_BULK_ITEMS`
cap (500) bounds array *length* only, never element size.

### 4.5 SQL injection — none found

Every user-controlled value reaches the database as a `$n` bind parameter. 153
template-literal interpolations into SQL-looking strings were reviewed; all are
either server-owned constants, table names fixed at module construction
(`createEntityWriteStore("hr_entities", …)`), numerically clamped (`LIMIT
${Math.min(1000, …)}`), or `$n` placeholder indices built from a server-side
`conditions[]` array. The one genuine string interpolation —
`trackPromotionMetric`'s `'{${metric}}'` jsonb path — is preceded by an explicit
`["views","shares","downloads"].includes(metric)` allowlist in the handler. This
surface is clean.

---

## 5. Tenant isolation

### 5.1 Three layers, and one of them is frequently absent

The intended model is route guard → repository predicate → RLS. Layer 3 is
comprehensive: every school table carries `ENABLE`/`FORCE ROW LEVEL SECURITY`
with `app_current_tenant_id()` / `app_current_school_id()` / scope-aware
policies, and the live pilot confirms the app connects as `erp_tenant` with
`bypassRls: false`.

Layer 2 is not. **30 repository `SELECT`s filter on `organization_id` with no
`school_id` predicate**, including:

| Repository | Table |
|---|---|
| `audit/audit_repository.ts:107` | `audit_events` |
| `finance/finance_collections_repository.ts:398` | `finance_collections` |
| `payment/payment_repository.ts:78,121` | `payment_intents`, `payment_requests` |
| `communication/communication_repository.ts` | `notification_deliveries`, `comm_threads`, `comm_broadcasts`, `comm_device_tokens` |
| `director/director_repository.ts` (9 queries) | `finance_invoices`, `finance_collections`, `students`, `sis_student_enrollments`, `admissions_leads`, … |
| `ai/ai_wallet_repository.ts`, `storage/storage_quota_repository.ts` | wallet + quota tables |

For each of these, school isolation rests **entirely on RLS**. The matching
policies were read and they do restate `school_id = app_current_school_id()`
(e.g. `audit_events_tenant_read`, `payment_intents_school_read`), so today the
isolation holds — but with no defence in depth. Any future path that runs one of
these repositories under `createServiceClient` (which bypasses RLS) reads across
every school in the organization with no second barrier. Service-client use is
currently bounded and appropriate (auth, session validation, identity/custom
roles, the Razorpay webhook, the cron broadcast drain, HR offboarding
revocation) — that is what keeps this a latent risk rather than a live one.
**API-116.**

### 5.2 Cross-school reads in a multi-school tenant

`MULTI-SCHOOL` is a supported product configuration, so "same organization,
different school" is a real boundary and not a theoretical one. The director
module deliberately crosses it (that is its purpose) and is gated by
`module.multi_branch` entitlement plus organization scope; the
`org_scope_*` isolation probes covering it pass live. No cross-school defect was
found in code review.

### 5.3 The live isolation matrix is red

See §2.3. Four `student`-scope probes fail on the pilot right now. This is the
only executed isolation evidence available, and it is the one that matters most
— **API-108**.

---

## 6. Failure behaviour — what the client sees

### 6.1 The envelope is consistent

Every response is `{ data, error: { code, message } }`, produced by the single
`errorEnvelope` helper, with security headers and a correlation id attached
centrally. `handleRequest`'s outer catch is correct and deliberate: it logs
`error.message` server-side and returns
`SERVER_ERROR — "An unexpected error occurred."` with the correlation id. The
`CONFIG_ERROR` path does the same. That is the right shape and it was verified
live (§2).

### 6.2 Twelve handlers bypass that discipline and return the raw exception — API-117

The central catch only fires for exceptions that *escape* a handler. Twelve call
sites catch the exception themselves and put its string into the client
envelope with a 500:

| File | Sites |
|---|---|
| `widget_platform/widget_platform_handlers.ts` | 45, 68, 105, 130, 156 |
| `widget_platform/widget_layout_handlers.ts` | 101 |
| `setup_wizard/setup_wizard_handlers.ts` | 73, 105, 163 |
| `control_center/platform_providers_handlers.ts` | 51, 58 |
| `control_center/control_center_write_handlers.ts` | 33 |
| `school_calendar/school_calendar_handlers.ts` | 45 |
| `copilot/copilot_handlers.ts` | 69 |

all of the form `errorEnvelope("…", String(error), 500)`. A `deno-postgres`
error stringifies to the driver's message — which carries the failing SQL
fragment, the table and column names, and the constraint name. `ENG-7 (SEC-6)`
closed exactly this hole in `app.ts`; these handlers re-open it one module at a
time. `_shared/auth_handlers.ts:345` is the worst instance because it is on the
**pre-authentication OTP request path**: a Supabase insert failure returns
`SERVER_ERROR` with `error.message` verbatim to an anonymous caller.

Two more sites return the DB configuration error text with a 503
(`tenant_handlers.ts:98`, `platform_db.ts:196`).

Everything else is fine: the ~120 other `error.message` uses are on **typed
domain errors** (`ExamValidationError`, `CollectionAmountError`,
`ApprovalNotFoundError`, …) whose messages are author-written and safe to show.
That distinction is the point — the defect is not "message contains a message",
it is "message contains an exception the author never saw".

### 6.3 403 precedence and the access-denied audit — API-118

`api/app.ts` records an access-denied audit event by observing
`response.status === 403` centrally (QA-X-017). Five attendance handlers return
**422 before any authorisation runs**:

```ts
export async function handleAttendanceMonthlyRegister(req, config) {
  const url = new URL(req.url);
  const classLabel = (url.searchParams.get("classLabel") ?? "").trim();
  if (!classLabel) return errorEnvelope("ATTENDANCE_VALIDATION", "classLabel is required", 422);
  …
  return await withAuth(req, config, true, async (claims) => { … });   // ← auth is HERE
}
```

(also `handleAttendanceRegister`, `handleAttendancePending`,
`handleAttendanceConsecutiveAbsence`, `handleAttendanceShortAttendance`). A user
without `viewSis` who sends a malformed request gets a 422 describing the
parameter contract instead of a 403 — and because no 403 is produced, **no
access-denied audit row is written**. On the live build, where there is no
central auth gate (§2.1), the same code answers an entirely anonymous caller —
verified as probe P12. These are the same five routes that are missing from the
RBAC inventory.

---

## 7. Retries and idempotency

### 7.1 The design is sound

Two independent layers:

1. **Universal store-and-replay** — `dispatchWithIdempotency` wraps the whole
   module dispatch. With an `Idempotency-Key` on a mutating request it claims
   `(organization_id, idempotency_key)`, runs the write once, replays the stored
   2xx envelope on retry, releases the claim on a non-2xx so a transient failure
   stays retryable, rejects key reuse across a different `(method, path)` with
   `422 IDEMPOTENCY_KEY_REUSED` (ICA-D1), and re-claims a slot abandoned by a
   crash after `IN_FLIGHT_CLAIM_TTL_MS` (ICA-A4). It never turns a committed
   write into a 500 when the replay payload fails to persist.
2. **Per-route natural-key backstops** — `finance_collections` has a partial
   unique index on `(organization_id, idempotency_key)` and another on
   `offline_payment_id` (ICA-A2); `payment_webhook_events` dedupes by gateway
   event id; `confirmPayment` takes `SELECT … FOR UPDATE` on the intent and
   re-reads status before creating a collection (PRA-M-2); approval decisions
   use a guarded `UPDATE … AND status = 'pending'`.

The client cooperates: `IdempotencyKeyInterceptor` mints a key for **every**
mutating Dio request, and `DioMutationExecutor` sends the outbox envelope's
stored key so an outbox retry reuses it.

### 7.2 An in-flight 409 is reported to the user as success — API-119 (P0 for money)

This is the defect that matters. `send_classification.dart`:

```dart
if (resp.statusCode == 409) {
  if (resp.errorCode == kIdempotencyConflictCode) {
    return SendClassification.confirmed;      // "already applied"
  }
  …
}
```

But the backend returns `409 IDEMPOTENCY_CONFLICT` for a request that is **still
in flight**, not one that has succeeded:

```ts
// Genuinely in-flight (NULL payload, not stale) → transient conflict.
return { claimed: false, priorStatus: null, priorPayload: null };
…
return errorEnvelope("IDEMPOTENCY_CONFLICT",
  "A request with this Idempotency-Key is already being processed", 409);
```

and the very same wrapper **releases the claim if that in-flight request then
fails**:

```ts
// Non-2xx → release the claim so the client can safely retry later.
await _safeRelease(store);
```

So the sequence — attempt A claims and is still running; the outbox drains
attempt B with the same key and gets 409; A then fails validation or errors, and
its claim is released — leaves **nothing written to the database and a
`SyncStatus.confirmed` in the client's outbox**. A `confirmed` envelope is
terminal: it is never retried. For `OperationTypes.collectFee` that is a fee
recorded as collected in the app and absent from the books. The same 409 shape
is thrown by `module_write_handlers.runWithIdempotency`, so the entire generic
entity-write surface shares it.

The backend comment (`idempotency_dispatch.ts`, "the client treats this as
'already applied'") shows the two sides agreed on a contract the backend does not
honour: a 409 in-flight is a *maybe*, and only a stored 2xx payload is an
"already applied". Nothing distinguishes them on the wire today.

### 7.3 Same state, two different statuses on the payment confirm path — API-120

`confirmPayment` returns success for an already-captured intent on its first
read:

```ts
if (intent.status === "captured" || intent.status === "settled") return buildConfirmResult(intent);
```

but throws after taking the capture lock:

```ts
if (captureLock[0]?.status === "captured")
  throw new PaymentIntentStateError(`Payment already captured for intent ${intent.id}`);   // → 422
```

A parent retrying a confirm therefore gets `200` or `422 VALIDATION_ERROR`
depending purely on whether another request captured it between the two reads.
Both are "your payment went through"; only one looks like it.

### 7.4 Smaller idempotency gaps

- **API-121** — `handleConfirmPayment` does not forward an `Idempotency-Key` to
  `confirmPayment`, although `handleInitiatePayment` does. Confirm is protected
  only by the universal wrapper plus the row lock; there is no natural-key
  backstop tying a confirm to its intent.
- **API-122** — the Razorpay webhook derives its dedupe key as
  `String(payload.id ?? \`evt_${crypto.randomUUID()}\`)`. A provider payload
  without `id` mints a fresh key on every delivery, so `recordWebhookEvent`
  always reports "new" and the event is processed on every redelivery. Razorpay
  always sends `id`; the fallback silently makes replay protection a property of
  the provider rather than of this service.
- **API-123** — `POST /finance/collections` has no *natural*-key dedup (invoice +
  amount + date + method). Two genuinely different `Idempotency-Key`s for the
  same human intent — a user tapping "Collect" twice, or a screen re-entered
  after a lost response — both succeed. `ICA-A2` added exactly this kind of
  backstop for offline instruments; the counter path has none.

---

## 8. Offline and recovery — what the outbox does with each route

`OperationPolicyRegistry.withDefaults()` is the whole policy surface. Eleven
operations are registered; **everything else falls back to `onlineOnly`**, which
is the safe default and is correctly documented as such.

| Operation | Policy | API route | Assessment |
|---|---|---|---|
| `attendance.mark` / `attendance.submit` | queueable, low-risk LWW | `POST /teacher/attendance/{draft,submit}` | Correct. Single-owner data; last write wins is the documented decision. |
| `exam.marks.saveDraft` | queueable, low-risk | draft save | Correct. |
| `exam.marks.submit` | queueable, **high-risk** | `PUT /academics/exams/marks/:id` | Correct — requires explicit conflict resolution. |
| `leave.apply` | queueable, low-risk | `POST /parent/leave`, `POST /teacher/leave` | Correct. |
| `finance.collectFee` | queueable, **high-risk** | `POST /finance/collections` | Correct in shape — and the optimistic projection deliberately mints **no** receipt number, showing "Pending Sync" until the server confirms. Undermined by API-119. |
| `staffAttendance.check` | onlineOnly | `POST /staff-attendance/check` | Correct, and well reasoned: a queued GPS+face check-in would be guaranteed stale, so the only offline path is the audited manual request. |
| `login`, `gatewayPayment`, `aiGenerate` | onlineOnly | — | Correct. |

Failure classification is otherwise sound: 5xx and 429 are `transient` and
retried with backoff; 4xx other than 409 is `failed` and not retried; a real 409
becomes `conflict` and, for a high-risk operation, is surfaced for explicit
resolution rather than silently re-applied. `NetworkUnavailableException` covers
connect/send/receive timeouts, so a lost response on a slow link is queued and
retried **with the same key** — which is the case idempotency was built for and
it works.

**API-124 (P2)** — the registry is keyed by an operation *type* string, not by
route. There is no test asserting that every route the app can call while
offline has a registered policy, so a new queueable write is opted in by
remembering to add a registry entry. The fallback is safe (`onlineOnly`), so the
failure mode is "a write that should have been queued isn't" — a lost teacher
action rather than a corrupted one. Worth a guard, not a blocker.
