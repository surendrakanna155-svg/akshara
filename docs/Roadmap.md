# Akshara ERP — Master Roadmap

**Version:** 1.4  
**Last updated:** June 2026  
**Current release:** v4.2 (Mobile Live Read APIs)  
**Production readiness:** 99 / 100  
**Quality gates:** `flutter analyze` 0 issues · `flutter test` 871 passing · 150 test files  
**Autonomous execution depth:** 3 milestones per session (see `docs/CURSOR_WORKFLOW.md` §11)

---

## Current State

### Architecture Summary

Akshara ERP is a **Flutter monorepo** with:

- **Web ERP admin shell** — 11 business modules + Control Center
- **Mobile apps** — Parent, Teacher, Student (repository pattern; mock default)
- **Repository pattern** — Interface → Mock | API, gated by per-module feature flags
- **Riverpod** — ~1,600 provider declarations
- **GoRouter** — ~100 routes across 4 shell surfaces
- **Dio** — Shared client with CorrelationId → Tenant → Auth → ApiError interceptors

```
Screen → Provider → Repository Interface → ApiRepository → RemoteDataSource → Dio
                                              ↓ (flag off)
                                         MockRepository
```

### Module Inventory (17 feature modules)

| # | Module | Surface | Screens | Repository | API status |
|---|--------|---------|--------:|------------|------------|
| 1 | admin | ERP shell | 2 | — | — |
| 2 | admissions | ERP | 10 | 30 methods | ✅ Live read + write |
| 3 | finance | ERP | 11 | 23 methods | ✅ Live read + write |
| 4 | sis | ERP | 5 | 10 methods | ✅ Live read + write |
| 5 | management | ERP | 8 | 8 methods | ✅ Live read |
| 6 | transport | ERP | 10 | 10 methods | ✅ Live read |
| 7 | hr | ERP | 9 | 9 methods | ✅ Live read |
| 8 | hostel | ERP | 9 | 9 methods | ✅ Live read |
| 9 | library | ERP | 8 | 8 methods | ✅ Live read |
| 10 | inventory | ERP | 8 | 8 methods | ✅ Live read |
| 11 | alumni | ERP | 9 | 9 methods | ✅ Live read |
| 12 | control_center | ERP | 12 | 12 methods | ✅ Live read |
| 13 | auth | All | 6 | 6 methods (Auth) | ✅ Live |
| 14 | parent | Mobile | 13 | 12 methods | ✅ Live read |
| 15 | teacher | Mobile | 8 | 10 methods | ✅ Live read |
| 16 | student | Mobile | 7 | 7 methods | ✅ Live read |
| 17 | notifications | Cross-cutting | 0 | — | — |

### API Inventory

| Module | Read | Write | Live total | Mock | API repo |
|--------|-----:|------:|-----------:|-----:|:--------:|
| Admissions | 11 | 19 | 30/30 | ✅ | ✅ |
| Finance | 13 | 10 | 23/23 | ✅ | ✅ |
| SIS | 5 | 5 | 10/10 | ✅ | ✅ |
| Auth | 6 | — | 6/6 | ✅ | ✅ |
| Transport | 10 | 0 | 10/10 | ✅ | ✅ |
| HR | 9 | 0 | 9/9 | ✅ | ✅ |
| Hostel | 9 | 0 | 9/9 | ✅ | ✅ |
| Library | 8 | 0 | 8/8 | ✅ | ✅ |
| Inventory | 8 | 0 | 8/8 | ✅ | ✅ |
| Alumni | 9 | 0 | 9/9 | ✅ | ✅ |
| Management | 8 | 0 | 8/8 | ✅ | ✅ |
| Control Center | 12 | 0 | 12/12 | ✅ | ✅ |
| **ERP Total** | **129** | **34** | **136/144** | **144/144** | **94%** |

**DTO files:** 92 · **Contract test files:** 37 · **Integration test dirs:** 14 · **Mobile repos:** 3

### Test Inventory

| Category | Files | Tests (approx) |
|----------|------:|---------------:|
| Feature provider/screen | 62 | ~380 |
| Contract | 37 | ~220 |
| Integration | 14 | ~60 |
| Mobile contract | 3 | 22 |
| Security | 6 | ~20 |
| Router | 2 | ~10 |
| Core (network, RBAC, tenant, pagination) | 14 | ~55 |
| Golden | 3 | 3 |
| Auth / startup / widget | 9 | ~80 |
| **Total** | **145** | **848** |

### Production Readiness Score

**99 / 100** — see `docs/ArchitectureReview/v3.2-ERP-Read-API-Audit.md`

| Category | Score |
|----------|------:|
| Auth security | 9.0 |
| RBAC | 8.5 |
| Audit/compliance | 8.5 |
| Token lifecycle | 9.0 |
| Build/test health | 10.0 |
| API coverage | 9.4 |
| Contract validation | 8.8 |
| Mobile architecture | 8.8 |
| Pagination | 7.5 |
| Server security | 4.5 |

### Technical Debt Summary

| Priority | Open items |
|----------|----------|
| P0 | 2 (server RBAC, audit server ingestion) |
| P1 | 4 (pagination partial, manage guards, etc.) |
| P2 | 12 |
| P3 | 6 |

Full register: `docs/TechnicalDebtRegister.md`

---

## Completed Releases

### v0.1 — Project Bootstrap

| Field | Detail |
|-------|--------|
| **Objective** | Flutter project scaffold, theme, navigation skeleton |
| **Modules** | Core app shell |
| **Architecture** | MaterialApp + basic routing |
| **Release doc** | (pre-doc era — captured in v0.2 release notes) |
| **Status** | ✅ Complete |

### v0.2 — Academic MVP

| Field | Detail |
|-------|--------|
| **Objective** | Parent/teacher/student mobile MVPs with mock data |
| **Modules** | Parent, Teacher, Student |
| **Architecture** | Inline mock providers, GoRouter shells |
| **Release doc** | `docs/Releases/v0.2-Academic-MVP.md` |
| **Status** | ✅ Complete |

### v0.3 — Admissions MVP

| Field | Detail |
|-------|--------|
| **Objective** | Admissions ERP module UI with mock data |
| **Modules** | Admissions (10 screens) |
| **Architecture** | Feature providers + mock seed data |
| **Release doc** | `docs/Releases/v0.3-Admissions-MVP.md` |
| **Status** | ✅ Complete |

### v0.4 — Finance MVP Phase 1

| Field | Detail |
|-------|--------|
| **Objective** | Finance dashboard, collections, fee structures (read-only UI) |
| **Modules** | Finance |
| **Release doc** | `docs/Releases/v0.4-Finance-MVP-Phase1.md` |
| **Status** | ✅ Complete |

### v0.5 — Student SIS

| Field | Detail |
|-------|--------|
| **Objective** | SIS module UI — registry, profile, academic assignment |
| **Modules** | SIS |
| **Release doc** | `docs/Releases/v0.5-Student-SIS.md` |
| **Status** | ✅ Complete |

### v0.6 — Finance Phase 2

| Field | Detail |
|-------|--------|
| **Objective** | Finance extended screens — defaulters, refunds, reports, settings |
| **Modules** | Finance |
| **Architecture** | Repository interfaces introduced |
| **Release doc** | `docs/Releases/v0.6-Finance-Phase2.md` |
| **Status** | ✅ Complete |

### v0.7 — (Internal — Admin shell)

| Field | Detail |
|-------|--------|
| **Objective** | Admin ERP navigation shell, module scaffolds |
| **Status** | ✅ Complete (documented in v0.8+ audits) |

### v0.8 — Transport MVP

| Field | Detail |
|-------|--------|
| **Objective** | Transport module — routes, vehicles, drivers, tracking |
| **Modules** | Transport |
| **Release doc** | `docs/Releases/v0.8-Transport-MVP.md` |
| **Audit** | `docs/ArchitectureReview/v0.8-Audit.md` |
| **Status** | ✅ Complete (mock only) |

### v0.9 — HR MVP

| Field | Detail |
|-------|--------|
| **Objective** | HR module — employees, attendance, payroll, leave |
| **Modules** | HR |
| **Release doc** | `docs/Releases/v0.9-HR-MVP.md` |
| **Audit** | `docs/ArchitectureReview/v0.9-Audit.md` |
| **Status** | ✅ Complete (mock only) |

### v1.0 — Hostel MVP

| Field | Detail |
|-------|--------|
| **Objective** | Hostel module — rooms, allocation, mess, leave |
| **Modules** | Hostel |
| **Release doc** | `docs/Releases/v1.0-Hostel-MVP.md` |
| **Audit** | `docs/ArchitectureReview/v1.0-Audit.md` |
| **Status** | ✅ Complete (mock only) |

### v1.1 — Library MVP

| Field | Detail |
|-------|--------|
| **Objective** | Library module — catalog, issues, returns, fines |
| **Modules** | Library |
| **Release doc** | `docs/Releases/v1.1-Library-MVP.md` |
| **Audit** | `docs/ArchitectureReview/v1.1-Audit.md` |
| **Status** | ✅ Complete (mock only) |

### v1.2 — Inventory MVP

| Field | Detail |
|-------|--------|
| **Objective** | Inventory module — stock, procurement, allocation |
| **Modules** | Inventory |
| **Release doc** | `docs/Releases/v1.2-Inventory-MVP.md` |
| **Audit** | `docs/ArchitectureReview/v1.2-Audit.md` |
| **Status** | ✅ Complete (mock only) |

### v1.3 — Alumni MVP

| Field | Detail |
|-------|--------|
| **Objective** | Alumni module — directory, events, donations, jobs |
| **Modules** | Alumni |
| **Release doc** | `docs/Releases/v1.3-Alumni-MVP.md` |
| **Audit** | `docs/ArchitectureReview/v1.3-Audit.md` |
| **Status** | ✅ Complete (mock only) |

### v1.4 — Control Center MVP

| Field | Detail |
|-------|--------|
| **Objective** | Super-admin multi-school management |
| **Modules** | Control Center |
| **Release doc** | `docs/Releases/v1.4-ControlCenter-MVP.md` |
| **Audit** | `docs/ArchitectureReview/v1.4-Audit.md` |
| **Status** | ✅ Complete (mock only) |

### v1.5 — API Repository Scaffolding

| Field | Detail |
|-------|--------|
| **Objective** | Repository interfaces + API scaffolding for all 11 ERP modules |
| **Architecture** | Interface → Mock → ApiRepository stub pattern; feature flags |
| **Release doc** | `docs/Releases/v1.5-API-Repository-Scaffolding.md` |
| **Audits** | `docs/ArchitectureReview/v1.5-*` (10 audit docs) |
| **Status** | ✅ Complete |

### v1.6 — Security RBAC

| Field | Detail |
|-------|--------|
| **Objective** | RBAC service, permissions, route guards, tenant architecture |
| **Architecture** | 22 permissions, ErpRouteGuard, tenant interceptors |
| **Release doc** | `docs/Releases/v1.6-Security-RBAC.md` |
| **Audits** | `docs/ArchitectureReview/v1.6-*` (4 audit docs) |
| **Status** | ✅ Complete |

### v1.7 — (Internal — Production readiness baseline)

| Field | Detail |
|-------|--------|
| **Objective** | First production readiness review (58/100 baseline) |
| **Audit** | `docs/ArchitectureReview/v1.7-Production-Readiness-Review.md` |
| **Status** | ✅ Complete |

### v1.8 — API Foundation

| Field | Detail |
|-------|--------|
| **Objective** | Dio client, interceptors, ApiFailure, DTO envelope pattern |
| **Architecture** | Shared network layer, error mapping |
| **Release doc** | `docs/Releases/v1.8-API-Foundation.md` |
| **Audits** | `docs/ArchitectureReview/v1.8-*` (3 audit docs) |
| **Status** | ✅ Complete |

### v1.9 — Admissions Read API

| Field | Detail |
|-------|--------|
| **Objective** | 11 live read endpoints for Admissions |
| **Modules** | Admissions |
| **Release doc** | `docs/Releases/v1.9-Admissions-API.md` |
| **Audit** | `docs/ArchitectureReview/v1.9-Admissions-API-Audit.md` |
| **Status** | ✅ Complete |

### v2.0 — Auth Foundation

| Field | Detail |
|-------|--------|
| **Objective** | JWT auth, session manager, token refresh, audit logging |
| **Architecture** | AuthRepository, AuthSessionManager, AuditLogger |
| **Release doc** | `docs/Releases/v2.0-Auth-Foundation.md` |
| **Audits** | `docs/ArchitectureReview/v2.0-*` (3 audit docs) |
| **Status** | ✅ Complete |

### v2.1 — Finance Read API

| Field | Detail |
|-------|--------|
| **Objective** | 13 live read endpoints for Finance |
| **Modules** | Finance |
| **Release doc** | `docs/Releases/v2.1-Finance-API.md` |
| **Audits** | `docs/ArchitectureReview/v2.1-*` (8 audit docs) |
| **Status** | ✅ Complete |

### v2.2 — Auth Server Integration

| Field | Detail |
|-------|--------|
| **Objective** | Live auth API — login, OTP, refresh, permissions |
| **Architecture** | AuthRemoteDataSource, server permission sync |
| **Release doc** | `docs/Releases/v2.2-Auth-Server-Integration.md` |
| **Audits** | `docs/ArchitectureReview/v2.2-*` (2 audit docs) |
| **Status** | ✅ Complete |

### v2.3 — SIS Read API

| Field | Detail |
|-------|--------|
| **Objective** | 5 live read endpoints for SIS |
| **Modules** | SIS |
| **Release doc** | `docs/Releases/v2.3-SIS-API.md` |
| **Audit** | `docs/ArchitectureReview/v2.3-SIS-API-Audit.md` |
| **Status** | ✅ Complete |

### v2.4 — Finance API Completion

| Field | Detail |
|-------|--------|
| **Objective** | Extended Finance read coverage to 13 endpoints |
| **Modules** | Finance |
| **Release doc** | `docs/Releases/v2.4-Finance-API.md` |
| **Audit** | `docs/ArchitectureReview/v2.4-Finance-API-Audit.md` |
| **Status** | ✅ Complete |

### v2.5 — Admissions Write APIs

| Field | Detail |
|-------|--------|
| **Objective** | 19 write endpoints — leads, applications, documents, enrollment, approval |
| **Modules** | Admissions |
| **Architecture** | Mutation provider pattern established |
| **Release doc** | `docs/Releases/v2.5-Admissions-Write-APIs.md` |
| **Audits** | `docs/ArchitectureReview/v2.5-*` (2 audit docs) |
| **Status** | ✅ Complete |

### v2.6 — SIS + Finance Write APIs

| Field | Detail |
|-------|--------|
| **Objective** | SIS 5 write + Finance 10 write endpoints |
| **Modules** | SIS, Finance |
| **Tag** | `v2.6-api-completion` |
| **Release docs** | `docs/Releases/v2.6-SIS-Write-APIs.md`, `docs/Releases/v2.6-Finance-Write-APIs.md` |
| **Audits** | `docs/ArchitectureReview/v2.6-*` (3 audit docs) |
| **Status** | ✅ Complete |

### v2.7 — Security Hardening

| Field | Detail |
|-------|--------|
| **Objective** | Auth security, RBAC sync, audit upload queue — no business features |
| **Architecture** | Secure storage, JWT validator, rotation tracker, permission sync service, audit queue |
| **Release doc** | `docs/Releases/v2.7-Security-Hardening.md` |
| **Audits** | `docs/ArchitectureReview/v2.7-*` (4 audit docs) |
| **Status** | ✅ Complete |

### v2.8 — API Contract Validation & Audit Backend

| Field | Detail |
|-------|--------|
| **Objective** | OpenAPI contract validation; wire audit batch upload; permission sync schema validation |
| **Architecture** | OpenAPI spec + client validator + audit remote datasource + `auditApiEnabledProvider` |
| **Release doc** | `docs/Releases/v2.8-Contract-Validation-Audit-Backend.md` |
| **Audits** | `docs/ArchitectureReview/v2.8-*` (2 audit docs) |
| **Status** | ✅ Complete |

### v2.9 — HR + Transport Live Read APIs

| Field | Detail |
|-------|--------|
| **Objective** | Live read APIs for HR (9 methods) and Transport (10 methods) |
| **Modules** | HR, Transport |
| **Architecture** | Full DTO/mapper/remote stack; contract + integration tests; OpenAPI dashboard schemas |
| **Release doc** | `docs/Releases/v2.9-HR-Transport-Read-APIs.md` |
| **Audits** | `docs/ArchitectureReview/v2.9-*` (2 audit docs) |
| **Status** | ✅ Complete |

### v3.0 — Mobile Repository Layer

| Field | Detail |
|-------|--------|
| **Objective** | Parent/Teacher/Student repository pattern; remove inline mock providers |
| **Architecture** | 3 interfaces + mock repos + API stubs + feature flags |
| **Release doc** | `docs/Releases/v3.0-Mobile-Repository-Layer.md` |
| **Audit** | `docs/ArchitectureReview/v3.0-Mobile-Repository-Audit.md` |
| **Status** | ✅ Complete |

### v3.1 — Pagination & Performance

| Field | Detail |
|-------|--------|
| **Objective** | PaginatedResult for Admissions/Finance/SIS lists; virtualized DataTables |
| **Architecture** | RepositoryQuery.page/pageSize; AksharaVirtualizedDataTable |
| **Release doc** | `docs/Releases/v3.1-Pagination-Performance.md` |
| **Audit** | `docs/ArchitectureReview/v3.1-Pagination-Audit.md` |
| **Status** | ✅ Complete |

### v3.2 — Remaining ERP Live Read APIs

| Field | Detail |
|-------|--------|
| **Objective** | Live read for Hostel, Library, Inventory, Alumni, Management, Control Center (54 methods) |
| **Release doc** | `docs/Releases/v3.2-Remaining-ERP-Read-APIs.md` |
| **Audit** | `docs/ArchitectureReview/v3.2-ERP-Read-API-Audit.md` |
| **Status** | ✅ Complete |

### v4.0 — Multi-Tenant Production SaaS (Client Foundation)

| Field | Detail |
|-------|--------|
| **Objective** | Tenant mock scoping, 401 logout, production env flags, monitoring scaffold |
| **Release doc** | `docs/Releases/v4.0-Multi-Tenant-Production-SaaS.md` |
| **Audit** | `docs/ArchitectureReview/v4.0-Tenant-Production-Audit.md` |
| **Status** | ✅ Complete (client); server RBAC/audit partial |

### v4.1 — Pagination Rollout

| Field | Detail |
|-------|--------|
| **Objective** | PaginatedResult on 6 additional list endpoints |
| **Release doc** | `docs/Releases/v4.1-Pagination-Rollout.md` |
| **Audit** | `docs/ArchitectureReview/v4.1-Pagination-Audit.md` |
| **Status** | ✅ Complete (9/40 list endpoints) |

### v4.2 — Mobile Live Read APIs

| Field | Detail |
|-------|--------|
| **Objective** | Parent/Teacher/Student full API read stacks (29 methods) |
| **Release doc** | `docs/Releases/v4.2-Mobile-Live-Read-APIs.md` |
| **Audit** | `docs/ArchitectureReview/v4.2-Mobile-API-Audit.md` |
| **Status** | ✅ Complete |

---

## Future Releases

### v4.3 — Server RBAC/RLS Validation

| Field | Detail |
|-------|--------|
| **Goals** | Prove server-side authorization; complete manage* mutation guards; extend tenant scoping |
| **Dependencies** | Backend RBAC/RLS deployment |
| **Blockers** | TD-P0-01, TD-P0-02 |
| **Status** | 🔲 Not started |

---

## Production Path

```
Phase 1: Mock MVP (v0.1–v1.4)           ✅ COMPLETE
  All 11 ERP modules + 3 mobile apps with mock data

Phase 2: API MVP (v1.5–v2.6)            ✅ COMPLETE
  Repository scaffolding + live API for Admissions, Finance, SIS, Auth

Phase 3: Security Foundation (v2.7)     ✅ COMPLETE
  Secure storage, JWT validation, RBAC sync, audit queue

Phase 4: Pilot                          ✅ COMPLETE (v2.8–v2.9)
  Staging backend + contract validation + HR/Transport APIs
  Target readiness: 93+ → **98.5 achieved**

Phase 5: Staging                        ✅ COMPLETE (v3.0–v3.2)
  Mobile repos + pagination + remaining ERP APIs
  Target readiness: 96+ → **99 achieved**

Phase 6: Production                       ✅ COMPLETE (v4.0 client foundation)
  Tenant scoping + 401 logout + production env
  Target readiness: 98+ → **99 achieved**

Phase 7: Multi-Tenant SaaS              ✅ PARTIAL (v4.0–v4.2)
  Pagination rollout + mobile live APIs
  Target readiness: 99+ → **99 achieved**

Phase 8: Server Security                🔲 NEXT (v4.3)
  Server RBAC/RLS + audit ingestion + mutation guards
  Target readiness: 99+
```

---

## Definition of Done

Every release milestone is **DONE** when all items are checked:

| # | Criterion | Owner |
|---|-----------|-------|
| 1 | `flutter analyze` = 0 issues | Agent G |
| 2 | `flutter test` = all passing | Agent G |
| 3 | Release doc created in `docs/Releases/` | Agent F |
| 4 | Audit doc created in `docs/ArchitectureReview/` | Agent F |
| 5 | Route inventory updated (if routes changed) | Agent E |
| 6 | Architecture inventory updated (if modules changed) | Agent F |
| 7 | `docs/Roadmap.md` milestone marked complete | Agent F |
| 8 | `docs/TechnicalDebtRegister.md` updated (if debt changed) | Agent F |
| 9 | Completion report delivered | Agent G |
| 10 | No files modified outside agent ownership (unless orchestrator fix) | Agent G |

---

## Agent Quick Start

```
1. Read this document (Roadmap.md)
2. Read AGENTS.md → identify your agent role
3. Read docs/CURSOR_WORKFLOW.md → follow startup procedure (§1) and multi-milestone rules (§11)
4. Pick next 🔲 milestone — autonomous sessions target 3 consecutive milestones
5. Execute → validate → document → continue (do not stop after one milestone)
```

**Next milestone:** v4.3 — Server RBAC/RLS Validation  
**Autonomous execution depth:** 3 milestones per session
