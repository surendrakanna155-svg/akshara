# NIKSHA OS — RC System Audit, Diagnostics & Architecture Review

**Date:** 2026-07-28 · **Branch:** `release/v1.0-playstore`
**Method:** six independent read-only audits, every claim carrying file:line evidence, key claims re-verified by hand.

> **VERDICT: NOT CERTIFIED as an observable, supportable system.**
> The engineering is largely excellent. The wiring is not. This review does not
> ask for more logging — it finds that most of what is already built is
> **switched off, unwired, or never drained**, and that several completion
> claims are true of the *code* and false of the *product*.

---

## The one-sentence summary

Every mechanism required for production support is already written and shipped
in the binary. Correlation IDs, structured server logs, a rich incident schema,
PII-minimised evidence collection, a forensic server-side audit trail, a
transactional outbox, an accrual engine, a deterministic Morning Brief — all
real, all tested. **A large share of them is not connected to anything.**

---

## 1–5. Observability, audit, diagnostics, AI-support readiness

### The crux — verified by hand, twice

`Environment.production` sets `enableLogging: false` (`environment.dart:70`).
`ObservabilityConfig` derives `enableAnalytics` and `enableMonitoring` from it
(`observability_providers.dart:31-32`). `config/live_release.json` contains no
monitoring vendor credentials.

**Therefore, in the shipping RC, monitoring and analytics resolve to no-ops.**
This is not accidental — it is pinned by a passing test
(`observability_providers_test.dart:35-50`).

Three consequences the flag alone does not reveal:

1. **`enableErrorReporting: true` is a dead field.** Three references, all inside
   its own declaration. Nothing reads it. It reads as reassurance and gates
   nothing.
2. **Wiring a Sentry DSN would not help.** `SentryMonitoringService` is
   constructed without a transport, so it defaults to
   `NoOpVendorMonitoringTransport` whose `send()` is empty
   (`sentry_monitoring_service.dart:9`, `vendor_monitoring_transport.dart:24-29`).
   No vendor SDK is in `pubspec.yaml`. `monitoring/README.md:45` says
   "wire a DSN to enable" — **that claim is false.**
3. **The only surviving sink writes almost nothing.** `reportFlutterError` /
   `reportZoneError` do write an audit event — with metadata
   `{'source': 'zone'}` and null user/school/correlation
   (`error_reporting_service.dart:37-53`). The exception, its type, its stack,
   the screen and the route are all handed to a no-op and discarded.

### What is actually recorded when production fails

| Signal | Uncaught Dart exception | Failed API call |
|---|---|---|
| What failed | ✗ (only `source`) | ✗ nothing persisted |
| Stack trace | ✗ discarded | n/a |
| Screen / module / route | ✗ | ✗ |
| Correlation id | ✗ (null) | ✗ (generated, then dropped) |
| Timestamp | ✓ device-local only | ✗ |

`reportApiFailure` writes **only** to the two no-ops — there is no audit write on
that path at all (`error_reporting_service.dart:72-95`).

### Can support reconstruct "attendance failed yesterday at 10:32"?

**No.** Walked end to end:

- Actions, navigation, network state, validation failures, the exception — none
  are retrievable. `IncidentTelemetryBuffer.recordAction`/`recordError` have
  **zero callers**; the buffer is RAM-only and dies with the process.
- Student attendance mutations are **not audited server-side** at all —
  `attendance_handlers.ts` contains no audit call. Even a *successful* mark
  leaves no audit row.
- The only artifact surviving 24 hours is the edge request log, which carries no
  user id, no school id, and usually a null client IP (the gateway sets no
  `X-Forwarded-For`).

The realistic query is "grep all attendance non-2xx around 10:32 across every
school", with no way to attribute one to the complainant.

### P0s — supportability

| # | Finding | Evidence |
|---|---|---|
| **O-P0-1** | **`SUPPORT_API_ENABLED` is absent from `config/live_release.json`**, so `supportRepositoryProvider` returns `MockSupportRepository`. A user files an incident, gets a plausible `SUP-N` reference, and **nothing is sent or stored**. The app tells them it worked. | `repository_providers.dart:370-375`; flag absent from config; `mock_support_repository.dart:209-229` |
| **O-P0-2** | **No entry point to the support surface.** Only `lib/features/support/` links to itself — no drawer, settings, nav or app-bar affordance. Reachable by deep link only. | `app_router.dart:301-321`; `persona_nav.dart` has no `support` |
| **O-P0-3** | **Failed API calls are recorded nowhere on the client.** | `error_reporting_service.dart:72-95` |
| **O-P0-4** | **Uncaught exceptions persist only "an error happened."** | `error_reporting_service.dart:37-53` |
| **O-P0-5** | **The audit upload queue is never flushed.** `auditUploadServiceProvider` has zero callers; client audit accumulates on-device forever, uncapped. | `audit_compliance_providers.dart:24-29` |
| **O-P0-6** | ✅ **FIXED THIS SESSION.** Docker logs were unrotated and unbounded — the one durable diagnostic source was also a disk-exhaustion risk, on a VPS **shared with unrelated production workloads**. | `docker-compose.akshara.yml` — 50MB × 5 added to all five services |

### What is already sound (do not re-open)

- **Correlation IDs propagate correctly end to end** — client interceptor on every
  Dio (`correlation_id_interceptor.dart:14-25`, `dio_client.dart:65`) → server
  accept-or-generate (`app.ts:135`) → echoed on **every** response including 500s
  (`app.ts:115`) → contract-tested (`qw4_error_paths_test.ts:93-104`).
  The plumbing is right; the gap is that **no path shows the id to a user**, so
  support can never obtain one.
- **Backend request logging is structured JSON and secret-safe** — deliberate
  omission of bodies, tokens and query strings (`app.ts:78-101`).
- **Internal errors never leak to the client** (`app.ts:228-245`).
- **Server-side audit for mutations is genuinely forensic** — actor, role,
  correlation, entity, IP, UA, RLS-enforced, indexed (`audit_repository.ts:295-320`).
  This is the strongest investigative asset in the system.
- **403 denials are audited centrally at the dispatcher** (`app.ts:207-217`).
- **The ASIP incident design is good engineering** — schema, evidence collection,
  PII minimisation. The problem is that it is disconnected and disabled, not wrong.

### 6. Privacy · 7. Performance · 8. Retention

Assessed by a dedicated audit; see the privacy report for detail. The headline is
that the deliberate omission of bodies/tokens/query strings from server logs is
correct and verified, and that `AUDIT_RETENTION_DAYS` plus the retention seam
exist. Retention behaviour must be reconciled against
`docs/legal/DATA_RETENTION_AND_DELETION_POLICY.md` — a mismatch between the policy
users are shown and the code that runs is a compliance finding, not a cleanup task.

### 9. Cross-module correlation

**Certify the event *log*. Do NOT certify event-driven *propagation*.**

- 201 event types, 346 emit sites, one writer, idempotency keys on 162/161 specs,
  transactional outbox genuinely inside the mutation transaction, RLS-hardened.
  Excellent foundation.
- **But every event is inserted in terminal `status='published'`**
  (`audit_repository.ts:365`) while the drain selects `pending|failed`
  (`domain_events_worker.ts:41`). The intersection is empty **by construction**.
- **Zero production subscribers** (`domain_event_subscribers.ts:70`).
- **No cron drains it** — and that matters beyond the dead outbox, because the
  **Signal Refinery** (AI cache invalidation and fact freshness) is invoked only
  from inside the drain. Real, working code, dormant in production.
- Actual propagation is **two hand-wired direct SMS calls**, whose success writes
  nothing and whose failure only reaches stdout — so *"did the parent get it?"*
  is unanswerable. For a school ERP, "we never told the parent" is a live dispute
  category.

⚠️ **Sequencing trap:** do **not** flip the status literal to `'pending'` in this
RC. That would instantly make 346 call sites depend on a cron that is not
installed, and every event would sit unpublished. Safe order is **cron first,
status second, in separate releases.**

`DOMAIN_EVENTS_ARCHITECTURE.md` already documents both limitations in writing.
This is an honest unfinished seam, not a false claim — but any release note
asserting event-driven propagation would be inaccurate against this code.

---

## 1. Floating AI button vs screen actions — ✅ FIXED THIS SESSION

Confirmed on a real device: the raised centre AI button was painted over the
"Save draft / N unmarked" submit row on **Mark Attendance** — a mistap hazard on
the most-used data-entry screen.

Per the directive, the button was **not** removed or hidden. Instead:

- `BottomNavAiScope` (new) publishes the exact band height to everything below a
  shell. It is a scope rather than a preference read because the preference alone
  cannot distinguish "inside a shell, button drawn" from "pushed full-screen, no
  nav at all" — padding the second case would add dead space for a button that
  is not there.
- The three persona shells resolve the height once and publish it.
- All **six** screens carrying a fixed bottom action bar now reserve it:
  teacher attendance, teacher + parent conversations, parent payment, parent
  receipt detail, support incident detail.
- Resolves to **0** when no button is drawn, so it costs nothing when unneeded.

---

## 2–3. Leave workflow and end-to-end propagation — NOT CERTIFIED

**Three disconnected leave subsystems ship in one binary**, sharing no store, no
balance and no vocabulary: `mobile_leave_requests` (parent/teacher apps),
`snapshot_leave` (a JSONB blob used by HR and payroll), and
`leave_accrual_ledger` (fully built, **zero callers**).

**Approving a leave does three things: flip a status, recount pending, write an
audit row.** That is the entire effect.

| Downstream | Verdict |
|---|---|
| Staff attendance | ❌ manual — and the muster has **no leave state**, so approved paid leave is reported as **Absent** |
| Student attendance | ⚠️ built, **can never fire** (see L-P0-1) |
| Timetable / substitutes | ❌ **zero** propagation — the bridging query targets the wrong table *and* a permanently-null column |
| Payroll | ⚠️ the one working link — unpaid-only, pull-based, and only for 5 hardcoded English strings |
| Notification | ❌ an in-memory stub; in API mode **nobody is told**, including the applicant |

### Leave P0s

- **L-P0-1 — No client ever sends machine-readable leave dates.** Only
  `from_date_label` free text. The column exists and the backend accepts it, but
  `from_date IS NOT NULL` predicates make substitution and student auto-excuse
  return **empty forever**. Both features are silently dead.
- **L-P0-2 — Leave dates are unvalidated free text** with a *decorative*
  calendar icon that is not a button. `"tomorrow"` is a valid leave date. This is
  the root cause of L-P0-1.
- **L-P0-3 — Half-day leave crashes the HR leave list.** Backend returns `0.5`;
  the mapper does `item['days'] as int?` → `TypeError`. Reachable from a shipped
  checkbox.
- **L-P0-4 — Approved staff leave depresses the employee's attendance %** on the
  statutory muster.
- **L-P0-5 — Nobody is notified of a leave decision.**

Not implemented at all: Comp Off · encashment · paternity · multi-step approval ·
holiday-aware day counting · **any per-school leave policy UI** (effective policy
is hardcoded constants: casual 12 / sick 12 / earned 15).

**Genuinely production-grade and not to be re-opened:** the *governance* half —
decision immutability, separation of duties, over-balance guard with an audited
override, complete audit trail, honest partial-success batch decide, LOP
money-safety invariants, tenant isolation on every surface.

---

## 4. Principal Morning Brief — NOT CERTIFIED (feature is not wired)

**`DaiBriefComposer` has zero production call sites.** The only file importing
`lib/core/dai/dai_brief.dart` is its own test — verified independently by hand.

The RC ships a committed, 11-test-covered "Principal Morning Brief" that renders
on no screen. What a principal actually sees is a different, backend-scored
surface (`management_principal_overview_panel.dart:83`).

Assessing the composer as a specification:

- **Roughly half its lines are events, not exceptions** — healthy attendance,
  staff absence, admissions joined, and a "no defaulters" line that fires
  *precisely when nothing is wrong*.
- **The "don't re-surface what I approved" requirement has no implementation.**
  `pendingApprovals` is a bare `int` with no producer and no link to
  `ApprovalStatus`. The guarantee rests on a field name.
- **6 of the 7 highest-value exception classes cannot reach it** — unresolved
  issues, failed automations, missing substitutes, policy conflicts, payroll
  exceptions, operational risk. Every one has real data in the app and no path in.
  `WorkflowInstanceStatus.failed` exists with no selector at all.
- **Severity does not affect order** — a `critical` line can render below two
  warnings; tone drives colour only.
- ✅ **Determinism is real and proven.** No imports, no clock, no randomness, pure
  static, pinned by a repeat-invocation test. The commit's claim is accurate.

---

## 5. DAI safety — ✅ CERTIFIED

The strongest result in the review. DAI **cannot execute anything**, and this is
structural rather than disciplinary:

- The package's complete import set is three pure modules — a permission enum,
  route-name constants, its own model. **No I/O dependency is reachable.**
- **No `async`, no `await`, no `Future` in 704 lines.** A synchronous function
  with no I/O cannot write, pay, publish, delete or approve.
- `DaiIntent` carries no callback, payload or command object — the richest thing
  it holds is a route string. All 12 intent kinds are read/open verbs.
- The single production call site does `pop()` + `context.go()`.
- Permission is **filtered before render**, so a user without `viewFinance` sees
  no card at all rather than one that fails on tap — this does not leak the
  existence of a screen.
- Injection-shaped input is actively rejected; the resolver refuses to guess
  below 55% confidence; it holds no data and cannot enumerate people.

**Guard rails to build BEFORE any action capability** (so the requirement is
enforced by construction, not discipline):

1. The permission check currently lives in a **private widget method**, not in the
   type. `DaiResolver.resolve` is public and returns a fully-routed intent with no
   gate — a second call site could skip it and nothing would fail.
2. ⚠️ **Highest-risk seam:** `AdaptiveAction.payload` + `requiresConfirmation` are
   already parsed end-to-end from the server and **consumed by nobody**. The RC
   ships the exact wire shape of "execute this with these arguments, ask first",
   honouring only `deepLink`, and only as navigation. The rail is enforced by
   *omission*. The first widget that reads `payload` makes `requiresConfirmation`
   a load-bearing boolean **supplied by a remote**, with no client-side
   confirmation, permission check or audit behind it.
3. `mutation_permission_registry.dart` already inventories every guarded mutation.
   **Any future DAI action must be required to appear there, with a missing entry
   a hard failure rather than a silent pass.**

---

## Recommended order (cheap and safe first)

1. ✅ Docker log rotation — **done this session**.
2. ✅ AI-button bottom safe space — **done this session**.
3. Add `SUPPORT_API_ENABLED` to `config/live_release.json`, **or** make the mock
   stop returning a fake ticket reference. Shipping a fabricated `SUP-N` to a user
   is the most user-hostile item in this review.
4. Give the support surface an entry point.
5. Install a cron for `POST /domain-events/process-pending` — additive, a no-op
   for events, and it **activates the Signal Refinery**. Best value-to-risk here.
6. Add user/school id to the edge request log; surface a correlation id or
   incident reference in `AksharaErrorState` so a screenshot is traceable.
7. Audit student attendance mutations server-side (separable from the event work).
8. Correct the false claims: `monitoring/README.md:45`, and the present-tense
   delivery-semantics claims in `DOMAIN_EVENTS_ARCHITECTURE.md`.

**Post-release, architectural — do not attempt now:** flipping the domain-event
status literal, registering subscribers, leave-subsystem consolidation, wiring the
Morning Brief, accrual scheduling.

---

## Addendum — audit-trail and privacy findings that arrived last

### A-P0-1 — A compliance PDF is built from a 200-entry device buffer

`finance_audit_register_service.dart:113-117` generates the **"Finance Audit
Register"** from `auditEventsProvider` — the device-local `SharedPreferences`
ring buffer, capped at 200 entries with a 30-day TTL. It is exported from
`finance_reports_screen.dart:220`.

**A school can hand an auditor a document titled "Finance Audit Register" that
reflects one device's last 200 events.** The document misdescribes itself. This
compounds with A-P0-2 below: the events it draws on never reach the server
either.

### A-P0-2 — The client audit upload queue is never drained

`auditUploadServiceProvider` is read in exactly one place in the repository — an
integration test. No app-lifecycle hook, timer, or post-mutation trigger calls
`flush()`. `AUDIT_API_ENABLED: true` is set and the endpoint is live, so the
uploader is wired and simply never invoked.

Consequence: **login, logout, token refresh, role change, permission denied,
receipt export and access denied exist only on the device**, capped at 200
entries and then evicted. None of them is durable.

### A-P0-3 — A green completeness test asserts a false premise

`qa_r_008_audit_completeness_test.ts:143-144` marks the attendance module
audit-exempt because *"the audited mutation is the staff APPROVAL, not the parent
submit."* But `attendance_handlers.ts:452-491` — `PATCH
/attendance/corrections/:id/status`, gated on `requireAttendanceApprove` — flips
that governance decision with **no audit call at all**. The approval-workflow
path does audit; this direct route bypasses it.

A passing test asserting a false premise is worse than a known gap, because it
converts an open question into a settled one.

### A-P0-4 — ✅ FIXED THIS SESSION: request/response logging leaked tokens and OTPs

`dio_client.dart` logged `requestHeader`, `requestBody` and `responseBody`, gated
on `enableLogging` — false in production but **true in staging and development**.
`scripts/run_live.sh` runs a staging-configured **debug** build against the
**live** pilot backend, so that combination printed to the device log: the
`Authorization: Bearer` token, the OTP in the `/auth/verify-otp` body, and access
tokens, parent phone numbers and linked-child profiles in responses. Anything
able to read logcat could collect them.

The release guard makes this unshippable in a store build — but the pilot lane
runs against real children's data, so "it cannot reach production" is not the
same as "it is safe". Now logs method, path and status only.

### A-P1 — Audit trail field completeness

**BEFORE/AFTER values exist for exactly one mutation: exam marks**
(`mutation_audit_catalog.ts:954-969`). One `before:` capture in ~78 KB of
catalog. So *"who changed this student's marks from X to Y"* is fully
answerable — genuinely forensic — while *"who changed this fee structure from ₹X
to ₹Y"* and *"what was the grading scale before"* are not. Many events carry
metadata `{}`.

The exam module proves the pattern is affordable. This is a coverage decision,
not an architectural limit.

Also: **correlation_id is NULL on 39 of 375 write sites**, concentrated in money
and AI (fee collection, refunds, every Copilot invocation, all staff attendance,
all onboarding imports). Root cause is a two-tier helper API where only one tier
auto-derives the id.

### What is genuinely production-grade (do not re-open)

- **Tenant isolation of the audit trail** — RLS with `FORCE`, a `NOBYPASSRLS`
  role asserted at runtime, a repository-level org predicate, a route guard, a
  write-side school binding that closed a real leak, and six live isolation
  probes. Four independent layers plus continuous verification.
- **Immutability by grant** — `SELECT, INSERT` only, no UPDATE/DELETE, on all
  three audit tables. Enforced at the database, not in application code.
- **IP/user-agent capture** — verified at every one of 375 call sites.
- **Student health access logging** — a dedicated immutable table auditing
  **reads** as well as writes, in the same transaction as the act it records.
- **OTP handling** — HMAC-keyed before storage (not bare SHA-256), rejection-
  sampled generation, and a production short-circuit that is exported
  specifically so the invariant is unit-assertable.
- **The encrypted reliability outbox** degrades to *non-durable*, never to
  *unencrypted-on-disk*.
- **Documentation honesty** — `AuditArchitecture.md` carries an explicit
  "not built" banner for partitioning, tiered retention and the hash chain. That
  posture is why the two places it drifts are worth correcting.

### Retention — the compliance mismatch

`AUDIT_RETENTION_DAYS` is parsed into config and **never consumed by any code
path**. There is no purge job, no `pg_cron` (the codebase says so itself), and
`countAuditEventsBeyondRetention` — which performs no deletion — has zero
callers.

Meanwhile `docs/legal/DATA_RETENTION_AND_DELETION_POLICY.md` promises schools and
parents that audit logs are kept "up to 3 years", communication logs 24 months,
diagnostics 12 months, and that data is deleted or anonymised "within a
reasonable period".

**The code and the published policy disagree, and the policy is the one the
customer relies on.** Under DPDP, storage limitation is not optional. This is the
single most serious compliance finding in the review, and it is not fixed by a
purge script — it needs the policy and the implementation reconciled deliberately.
