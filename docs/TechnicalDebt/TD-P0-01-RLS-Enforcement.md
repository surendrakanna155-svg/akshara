# TD-P0-01 — RLS Enforcement

**ID:** `TD-P0-01`
**Priority:** P0 (blocking for tenant-data API exposure)
**Status:** ✅ **Substantially CLOSED (verified live 2026-07-03).** Tenant-data API paths run on the non-bypass `erp_tenant` role (`rolbypassrls=f`) with `FORCE ROW LEVEL SECURITY` and cross-tenant isolation **live-verified** (7/7 read + 2/2 write PASS, audit report 11 §3b). Residual is **regression-hardening only**, re-scoped to `P0-TEST-2` (isolation suite into CI) + `P0-INFRA-6` (deploy-time `erp_tenant` assert) — **not** an open RLS gap.
**Opened:** June 2026 (Sprint 3 Phase 2 closure)
**Closed (enforcement):** Phase 3A `erp_tenant` rollout; live-verified 2026-07-03 (Fable audit)
**Baseline:** `v6.1-phase1-rbac-foundation` → Phase 2 auth scope expansion

> **Correction (DOC-9 / DB-9, 2026-07-04).** An earlier revision of this doc said Finance/SIS RLS was
> *"not started (gated)"*. That was **stale**: RLS is enforced across the tenant-data path (the edge
> connects as `erp_tenant`, a `NOBYPASSRLS` role, and FORCE RLS is on core tables), and live
> cross-tenant probes pass. Module handlers query through the tenant context helper. This doc is kept
> as the debt's closure record; the only forward work is keeping enforcement regression-guarded
> (the two P0 tasks above).

---

## Summary

**Original debt (June 2026):** Edge Functions used **Supabase `service_role`**, which **bypasses
PostgreSQL RLS**. Sprint 3 Phase 2 delivered RLS policies, `set_request_context`, aggregate views, and
tenant isolation self-tests as **infrastructure** only — not authoritative until tenant-data queries
moved to a **non-bypass connection**.

**Resolution (Phase 3A → live 2026-07-03):** tenant-data queries now run on the dedicated
**`erp_tenant`** role (no `BYPASSRLS`) via the `withTenantContext` helper, with `FORCE ROW LEVEL
SECURITY` on core tables so policies apply even to privileged roles. Cross-tenant isolation is
**live-verified** on the VPS (read + write, cross-tenant / cross-school / parent scopes). `service_role`
is reserved for auth plumbing, provisioning, and cron. The debt's original gate — "don't expose
tenant-data APIs on `service_role`" — is satisfied.

---

## Current state

| Component | Status |
|-----------|--------|
| `app.set_request_context` RPC (public wrapper: `set_request_context`) | ✅ Deployed |
| RLS policies on core tables | ✅ Defined |
| `org_school_summary` aggregate view | ✅ Defined |
| `tenant_isolation.run_self_test()` | ✅ Defined |
| Edge Function calls `set_request_context` | ✅ On token issue / `/auth/me` |
| Edge Function auth client | ✅ `service_role` (auth only — by design) |
| `erp_tenant` + `withTenantContext` helper | ✅ Phase 3A |
| `ERP_TENANT_DATABASE_URL` secret | ✅ Required on staging |
| `FORCE ROW LEVEL SECURITY` on core tables | ✅ Phase 3A |
| `run_tenant_isolation_enforced_test()` | ✅ Passes under `erp_tenant` |
| Module API handlers use tenant helper | ✅ Across the tenant-data path (`withTenantContext`); no longer Admissions-only |
| Admissions APIs | ✅ Live — smoke + handoff E2E pass |
| `admissions_fee_handoffs` RLS | ✅ FORCE RLS, school scope only — Phase 4B0 |
| Module APIs (Finance, SIS, HR, Transport, …) | ✅ On `erp_tenant` (non-bypass) with RLS enforced |
| Cross-tenant isolation (live VPS) | ✅ **Live-verified 2026-07-03** — 7/7 read + 2/2 write PASS (report 11 §3b) |
| Regression into CI · deploy-time role assert | 🔜 `P0-TEST-2` · `P0-INFRA-6` (keep enforcement guarded) |

---

## Risk

Any tenant-data API backed by `service_role` without an application-layer tenant guard can read or mutate rows across schools or organizations. JWT scope and membership validation at auth issue time are necessary but **insufficient** once module endpoints query operational tables.

---

## Gate — must close before exposing

Do **not** expose live endpoints that return or mutate tenant operational data until TD-P0-01 is closed:

- Admissions APIs  
- Finance APIs  
- SIS APIs  
- HR APIs  
- Transport APIs  
- Inventory APIs  
- Any student-data read/write APIs  

Auth-only endpoints (OTP, token issue, refresh, context switch, `/auth/me`, `/auth/permissions`) may ship under accepted debt.

---

## Required actions to close

1. **Introduce non-bypass DB access** — `db_user` (or equivalent) connection pool that does not have `BYPASSRLS`; reserve `service_role` for provisioning, cron, and auth plumbing only.
2. **Mandatory `set_request_context`** — call before every tenant-data query on the non-bypass connection; reject requests where JWT claims cannot be applied.
3. **`FORCE ROW LEVEL SECURITY`** — on all tenant operational tables so policies apply even to privileged roles used in tests.
4. **Integration test suite** — extend `run_tenant_isolation_self_test` to run under the enforced role on staging CI; add negative tests per scope (school, organization, parent, student).
5. **Middleware contract** — document and enforce: permission check (application) + RLS (database) for every module handler.

---

## Acceptance criteria

| # | Criterion |
|---|-----------|
| AC-1 | Module API handlers use non-bypass connection for tenant data reads/writes |
| AC-2 | Staging isolation suite passes under enforced role (not superuser bypass) |
| AC-3 | Org scope cannot `SELECT` raw `school_memberships` or student PII tables |
| AC-4 | School A JWT cannot read School B rows in integration tests |
| AC-5 | Parent JWT cannot read unlinked students |
| AC-6 | Service role usage audited and limited to allowlisted operations |

---

## Related documents

- `../archive/completed/releases/v6.1-Sprint3-RBAC-Tenant-Architecture.md` §6.5, §19 Phase 2–3  
- `docs/TenantArchitecture.md` §4  
- `../archive/roadmap/BackendRoadmap.md` §4 (Sprint 3 gate)  
- `docs/AuthArchitecture.md` §2 (scope + session vars)

---

## History

| Date | Event |
|------|-------|
| 2026-06 | Opened at Phase 2 approval; accepted technical debt for auth scope expansion deploy |
| 2026-06 | Phase 3A: `erp_tenant` role, `withTenantContext`, FORCE RLS, enforced isolation tests |
| 2026-06-12 | Phase 4B0: `admissions_fee_handoffs` — school-only RLS, 5 new isolation probes, handoff APIs |
| 2026-07-03 | **Enforcement live-verified** (Fable audit report 11): edge = `erp_tenant` (`NOBYPASSRLS`), FORCE RLS on, cross-tenant isolation 7/7 read + 2/2 write PASS. Debt substantially closed; residual = regression-into-CI (`P0-TEST-2`) + deploy-assert (`P0-INFRA-6`). |
| 2026-07-04 | Doc corrected to reality (DOC-9/DB-9); removed stale "Finance/SIS not started" framing. |
