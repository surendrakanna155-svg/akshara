# QW4 — Backend API/RBAC/RLS/Error-path · COMPLETION CERTIFICATION

**Date:** 2026-06-30 · **Branch:** `feature/data-reliability-platform`
**Gate:** Engineering Operating System (`/eos`) per [`engineering/ENGINEERING_GATE_POLICY.md`](engineering/ENGINEERING_GATE_POLICY.md).
**Companion:** [`FINAL_QA_MASTER_TRACKER.md`](FINAL_QA_MASTER_TRACKER.md) · [`FINAL_QA_ROADMAP.md`](FINAL_QA_ROADMAP.md) · [`engineering/eos/EOS_RUN_LEDGER.md`](engineering/eos/EOS_RUN_LEDGER.md).

---

## Verdict

> **EOS gate: PASS** for all locally-verifiable QW4 work. The wave is **CONDITIONAL at the program
> level** pending **6 genuinely live-Postgres/RLS-blocked rows** + the infra remainder of **8 Partial
> rows**. **No locally-fixable P0/P1 remains** — the 1 P1 RBAC defect (QW4-INV-OR) and the 1 P1 audit
> gap (exam-publish unaudited) the contract suites surfaced were **fixed in-flight**.

**QW4 row status (73-row wave): 59 Verified · 8 Partial · 6 Blocked (live-DB).**

Authoritative sweep on local hardware:
- **Backend** `deno test --allow-env --allow-read supabase/functions/` → **1344 passed / 0 failed** (2 ignored).
- **Flutter** `flutter test` → **+2874 passed / 0 failed** (the new read-path `RetryInterceptor` wired
  into the live HTTP stack caused no regression).
- `flutter analyze` → 0 issues · `deno check` clean on every touched file.
- **44 new test files + 3 extended** (40 backend Deno route-contract/error/audit suites, 4 Flutter
  resilience suites).

---

## Approach

QW4 turns the backend from "37% RBAC-documented, few routers tested" into a contract-asserted surface
using the **DB-free route-contract pattern** (finding **F5/F9**). Why it works without a database:
`assertSessionValid` short-circuits when `supabaseUrl`/`serviceRoleKey` are absent
(`session_validation.ts:96`), so a forged JWT (`signAccessToken`) flows straight to `requirePermission`.
Status legend: **401** (no/invalid token) · **403** (authenticated, lacks permission) · **402**
(entitlement gate) · **422/400** (gate passed, body invalid, before DB) · **503
TENANT_DB_NOT_CONFIGURED** (gate + validation passed, reached the unconfigured DB — the DB-free
"authorized" proxy) · **404** (unregistered path/method).

Executed as **3 batches of parallel module-cluster agents**, each self-verifying with `deno test` /
`flutter test`, then reconciled through full-tree sweeps with an EOS gate per batch:

| Batch | Scope | Rows | Result |
|---|---|---:|---|
| 1 | Router-contract + RBAC (finance, comm, control-center, the entitlement-gated modules, director/analytics/copilot/timetable/onboarding/org-builder/widget, student/operations/exam/legal/approvals/pilot) | 35 | 29 V · 6 Partial |
| 2 | Untested modules (employee, parent-experience, principal-command, school-calendar, memories, setup-wizard, inventory-distribution, school-config, teacher-assistant, growth, school-completion, teacher-overlay) + error-paths + coverage | 24 | 23 V · 1 Partial |
| 3 | Client resilience (auth refresh-replay, retry/backoff, push handlers, offline cached session, notifications) + audit-trail emission (fee/exam/approval) | 8 | 7 V · 1 Partial |

A reusable **testable-seam refactor** (`supabase/functions/api/app.ts`) extracted the `Deno.serve`
callback into an importable `handleRequest(req, configLoader)` so the index-level error/CORS/
correlation-id rows are testable without `--allow-net` (CI runs `deno test` with no net permission).

### Notable proofs
- **Verb anti-escalation** — refund approve/reject require `approveRefunds`, not `manageFinance`
  (`QA-B-015`); storekeeper/counselor verb gates (carried from QW2).
- **Entitlement 402 matrix** — `requireEntitlement` returns 402 for every `withEntitlement`-wrapped
  prefix when the plan slug is absent (`QA-B-065`).
- **superAdmin compositional gate** — control-center requires `viewControlCenter` **+ org scope**; a
  school-scope principal holding the perm is denied (`QA-B-050/058`).
- **Index-level envelope** — global 404, 500 SERVER_ERROR (via an uncaught idempotency-dispatch
  throw), CONFIG_ERROR (throwing loader), CORS preflight + headers on errors, correlation-id
  propagation, webhook HMAC accept/reject (`QA-B-062..070`).

---

## The contract suites earned their keep — bugs found and fixed

| Sev | Fix | Evidence |
|---|---|---|
| **P1** | **QW4-INV-OR — systemic RBAC inversion.** The idiom `requirePermission(A) ?? requirePermission(B) ?? requireScope()` collapsed an intended **OR-fallback into an AND** (`requirePermission` returns a truthy 403 on denial, so `??` short-circuits on the first miss). It fails closed (no leak) but wrongly 403s legitimate broader-role users (e.g. a `viewSis` holder denied Student-360). **Fixed at all 29 sites across 15 handler files** via a new `requireAnyPermission(claims, slugs)` helper; OR-semantics pinned by unit + route-contract tests. | `permission_middleware.ts` (+helper, +4 unit tests); 15 handlers; `analytics_handlers.ts` |
| **P1** | **Exam-results publish was completely unaudited.** A non-reversible mutation that publishes results to students/parents + sends SMS emitted **no** `audit_events`/`domain_events` row. Added `examAudit.resultsPublished` to the catalog + `emitMutationAudit` on the publish success path. | `exam_administration_handlers.ts`, `mutation_audit_catalog.ts` (`QA-X-015`) |
| **P2** | **Error responses lacked CORS + correlation-id.** The outer SERVER_ERROR/CONFIG_ERROR catches returned the envelope without the header merge, so a browser would see an opaque CORS error instead of the 500. `app.ts` now `withCors`-decorates **every** response. | `app.ts` (`QA-B-068`) |

**New builds (locally verified):**
- `app.ts` — testable request-handler seam (index.ts is now a thin `Deno.serve(handleRequest)` shell).
- `lib/core/network/interceptors/retry_interceptor.dart` — bounded, idempotent-only (GET/HEAD)
  retry/backoff for transient 5xx/429, wired in `dio_client.dart` between Auth and ApiError
  interceptors. Closes a genuine read-path gap (Phase 0 covered only the write/sync path). (`QA-X-008`)
- `scripts/backend_coverage_gate.sh` + a CI step — backend line-coverage floor **40%** (measured
  **41.4%**, 23978/57957 lines), fails the build on regression. (`QA-B-074/075`)

---

## Findings tracked (real, deferred to the right wave/owner)

- **P2 · Approval audit identity is body-overridable** (`approval_handlers.ts:289`) — `actor_id` on the
  recorded decision can be set from the request body, so the audit approver is spoofable (RBAC still
  gates *who may decide*). May be an intentional "decided on behalf of" affordance → **owner judgment**;
  fix = record both the authenticated user and any claimed actor. (`QA-X-016`)
- **P2 · Platform-provider routes skip `requireOrgScope`** (`platform_providers_handlers.ts:35+`) — they
  gate on a platform permission only, unlike sibling control-center surfaces. Not exploitable today
  (those perms are superAdmin-org-scope only). (`QA-B-058`)
- **P2 · Growth list-reads gate on a single slug** while dashboard/funnel are OR — an admissions-only
  user sees growth aggregates but 403s on campaign/inquiry lists (`growth_handlers.ts:189/324/503`).
  Product/RBAC decision. (`QA-B-010`)
- **P2 · Notifications row has no deep-link nav** (`notifications_screen.dart:113`) — same gap QW3
  found; mark-read works. (`QA-X-013`)
- **P3 · Status-code inconsistencies** — school-config/ memories use 400 INVALID_BODY where 422 is the
  convention; two school_completion reads gate on a manage slug. Asserted as-is, not normalized.
- **P3 · fee-collect audit is hand-inlined** rather than via a catalog builder (consistency only).

---

## Remaining QW4 rows — genuinely blocked / partial (need live `ERP_TENANT_DATABASE_URL` + RLS)

The DB-free pattern proves **authorization** (the gate lets the right caller through); it cannot prove
**row-level cross-tenant isolation** — that is enforced in Postgres RLS inside `withTenantContext`.

**6 Blocked (pure RLS rolled-back-txn cross-tenant probes):**

| Row | Probe |
|---|---|
| `QA-B-053` | library catalog/issues/members cross-tenant |
| `QA-B-054` | alumni registry/donations cross-tenant |
| `QA-B-055` | inventory assets/allocations/lifecycle cross-tenant |
| `QA-B-056` | transport routes/vehicles/drivers cross-tenant |
| `QA-B-060` | academic lesson-logs/subjects/syllabus/rooms cross-tenant |
| `QA-B-061` | parent per-child RLS (parent A ↛ parent B's child) |

**8 Partial (local RBAC/contract leg Verified; infra remainder):** `QA-B-032` (student row-isolation),
`QA-B-040` (per-row approve/reject 403 runs after the row loads in-tx), `QA-B-041` (AI persona-bounding),
`QA-B-044` (parent per-child DATA), `QA-B-058`/`QA-B-059` (cross-org control-center/director DATA),
`QA-B-065` (live per-org plan→402), `QA-X-011` (on-device FCM delivery → device/FCM lane with
QA-X-010/012).

These join QW1's live-Postgres RLS leftovers (`QA-B-051/052/057`) on the **live-regression DB cron**
lane. No locally-verifiable P0/P1 remains.

---

## Bottom line

Every QW4 backend route that can be contract-asserted on local hardware now is — **59/73 Verified**,
with 8 Partial (local leg green, data/RLS leg infra) and 6 Blocked on a live tenant DB. The wave did
more than add coverage: it **fixed a systemic RBAC inversion (29 sites), closed an unaudited
compliance-critical mutation, hardened CORS on error paths, built a read-path retry interceptor, and
stood up a backend coverage floor in CI.** **QW4's locally-verifiable scope is COMPLETE.**
