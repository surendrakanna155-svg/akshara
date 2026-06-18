# Phase F2 — Approval API Final Certification

**Date:** 2026-06-17  
**Phase:** Production Backend Program **F2**  
**Class A item:** A2 Unified Approval API  
**Verdict:** **PASS** (F2 scope)  
**Authority:** `docs/ORCHESTRATOR_AGENT.md`, `docs/F2_APPROVAL_API_EXECUTION_PLAN.md`

---

## Executive summary

| Gate | Result |
|------|--------|
| `flutter analyze` | **0 errors** |
| `flutter test` (full suite) | **1958 passed**, 1 skipped |
| F2 contract tests | **PASS** (`approval_repository_contract_test.dart` + fake Dio API parity) |
| F2 integration tests | **PASS** (`f2_approval_api_integration_test.dart`) |
| Existing approval suite | **PASS** (M-D2–M-D7 integration + provider + widget) |
| Mock fallback | **PASS** (`APPROVAL_API_ENABLED=false` → `MockApprovalRepository`) |
| PO self-approve denial | **PASS** (server `403` + client mapping) |
| F3 scope | **Not started** |

**Production API readiness:** **~53% → ~65%** (F2 schema + Edge + Flutter API repo complete; staging deploy verification pending ops)

---

## Deliverables

### F2.0 — Schema + CRUD (Supabase)

| Artifact | Path |
|----------|------|
| Migration | `supabase/migrations/20260617100000_approval_requests.sql` |
| Tables | `approval_requests`, `approval_audit_entries`, `approval_domain_effects` |
| RLS | School-scope FORCE RLS + `erp_tenant` grants |
| Partial unique index | One pending row per `(school, type, entity_type, entity_id)` |

### F2.1 — Flutter API repository

| Artifact | Path |
|----------|------|
| Paths | `lib/core/repositories/api/approval/remote/approval_api_paths.dart` |
| DTOs | `lib/core/repositories/api/approval/dto/` |
| Mapper | `lib/core/repositories/api/approval/mapper/approval_mapper.dart` |
| Remote | `lib/core/repositories/api/approval/remote/approval_remote_datasource.dart` |
| Repository | `lib/core/repositories/api/approval/api_approval_repository.dart` |
| Providers | `api_repository_providers.dart`, `repository_providers.dart` |

### F2.2 — Approval orchestrator (Edge)

| Artifact | Path |
|----------|------|
| Repository | `supabase/functions/_shared/approval/approval_repository.ts` |
| Orchestrator | `supabase/functions/_shared/approval/approval_orchestrator.ts` |
| Handlers | `supabase/functions/_shared/approval/approval_handlers.ts` |
| Router | `supabase/functions/_shared/approval/approval_router.ts` |
| API wiring | `supabase/functions/api/index.ts` |

### F2.3 — Type handlers (7 types)

| Type | Handler |
|------|---------|
| `examResults` | `approval_type_handlers.ts` → domain effect |
| `studentLeave` | leave status effect |
| `staffLeave` | leave status effect |
| `attendanceCorrection` | correction applied/denied |
| `feeConcession` | concession active/rejected |
| `refund` | `approveRefund` integration + fallback effect |
| `inventoryPo` | PO status + self-approve denial in `decideApproval` |

### Client hardening (API mode = server source of truth)

| Change | Path |
|--------|------|
| Skip duplicate audit writes | `approval_center_service.dart` |
| Skip governance store dispatch | `approval_adapter_registry.dart`, `approval_center_provider.dart` |

### Documentation

| Doc | Path |
|-----|------|
| Analysis | `docs/F2_APPROVAL_API_ANALYSIS.md` |
| Execution plan | `docs/F2_APPROVAL_API_EXECUTION_PLAN.md` |
| Migration & rollback | `docs/F2_APPROVAL_MIGRATION.md` |
| Certification | `docs/PHASE_F2_FINAL_CERTIFICATION.md` |

### Tests added / updated

| File | Coverage |
|------|----------|
| `test/contracts/approval/approval_repository_contract_test.dart` | API fake-Dio parity |
| `test/integration/approval/f2_approval_api_integration_test.dart` | Server audit + PO forbidden |
| `supabase/functions/_shared/approval/approval_router_test.ts` | Route matching |
| `supabase/functions/_shared/approval/approval_permissions_test.ts` | Permission map |

---

## Certification checklist

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Unified `approval_requests` schema with RLS | ✅ |
| 2 | `/approvals/*` Edge routes (list, submit, approve, reject, cancel, audit) | ✅ |
| 3 | Flutter `ApiApprovalRepository` wired via `APPROVAL_API_ENABLED` | ✅ |
| 4 | Mock fallback unchanged (`MockApprovalRepository`) | ✅ |
| 5 | M-D2 Approval Center UI unchanged | ✅ |
| 6 | Server orchestrates audit + domain effects in API mode | ✅ |
| 7 | PO self-approve denied server-side | ✅ |
| 8 | Seven F2 type handlers registered | ✅ |
| 9 | Rollback via `APPROVAL_API_ENABLED=false` | ✅ |
| 10 | `flutter analyze` 0 errors | ✅ |
| 11 | Full test suite green | ✅ |

---

## Rollback verification

| Scenario | Expected | Verified |
|----------|----------|----------|
| `APPROVAL_API_ENABLED=false` | Mock repo + client audit + adapters | ✅ (provider wiring) |
| API mode approve | No governance store write | ✅ (`skipDomainEffects`) |
| API mode audit | Server-only trail | ✅ (`_serverManagesAudit`) |

---

## Known limitations (deferred to F3–F7)

- Domain handlers write `approval_domain_effects`; full domain API orchestration (F4 exam publish, F5 attendance, F7 finance) replaces inline effects later.  
- Staging E2E against live Supabase tenant pending ops credentials.  
- `recordAuditEntry` client mirror is no-op in API mode (by design).

---

**Certified by:** Cursor Agent (F2 implementation session)  
**Next phase:** F3 locked until Program Director authorization
