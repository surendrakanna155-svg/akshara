# TD-P0-01 — RLS Enforcement

**ID:** `TD-P0-01`  
**Priority:** P0 (blocking for tenant-data API exposure)  
**Status:** Open — infrastructure ready, not authoritative  
**Opened:** June 2026 (Sprint 3 Phase 2 closure)  
**Baseline:** `v6.1-phase1-rbac-foundation` → Phase 2 auth scope expansion

---

## Summary

Edge Functions currently use **Supabase `service_role`**, which **bypasses PostgreSQL RLS**. Sprint 3 Phase 2 delivered RLS policies, `auth.set_request_context`, aggregate views, and tenant isolation self-tests as **infrastructure**. These are **not authoritative** for the live API path until tenant data queries move to **non-bypass connections**.

**Approved framing (Phase 2):** Auth Scope Expansion Foundation — not complete RLS enforcement.

---

## Current state

| Component | Status |
|-----------|--------|
| `auth.set_request_context` RPC | ✅ Deployed |
| RLS policies on core tables | ✅ Defined |
| `org_school_summary` aggregate view | ✅ Defined |
| `tenant_isolation.run_self_test()` | ✅ Defined |
| Edge Function calls `set_request_context` | ✅ On token issue / `/auth/me` |
| Edge Function DB client | ❌ `service_role` (bypasses RLS) |
| User-scoped / non-bypass DB role | ❌ Not implemented |
| `FORCE ROW LEVEL SECURITY` on tenant tables | ❌ Not applied |
| Module APIs (Admissions, Finance, SIS, …) | ❌ Not exposed (Phase 3+) |

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

- `docs/Releases/v6.1-Sprint3-RBAC-Tenant-Architecture.md` §6.5, §19 Phase 2–3  
- `docs/TenantArchitecture.md` §4  
- `docs/BackendRoadmap.md` §4 (Sprint 3 gate)  
- `docs/AuthArchitecture.md` §2 (scope + session vars)

---

## History

| Date | Event |
|------|-------|
| 2026-06 | Opened at Phase 2 approval; accepted technical debt for auth scope expansion deploy |
