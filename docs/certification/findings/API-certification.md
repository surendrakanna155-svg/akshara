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
