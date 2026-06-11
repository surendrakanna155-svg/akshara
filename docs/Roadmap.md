# Akshara ERP — Master Roadmap

**Version:** 2.0  
**Last updated:** June 2026  
**Current release:** v15.6 Production Validation (`v15.6-production-validation`)  
**Previous release:** v15.0 Real School Simulation  
**Readiness tags:** `v1.0-ops-ready` · `v1.0-customer-ready`  
**Feature freeze:** active — no new milestones  
**Production validation:** PASS — see `docs/Operations/Production-Validation-Report.md`  
**Production readiness:** 94 / 100 (launch-weighted; live integrations env-dependent)  
**Quality gates:** `flutter analyze` 0 issues · `flutter test` all passing  
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
| **Total** | **145+** | **1087+** |

### Production Readiness Score

**97 / 100** — see `docs/ArchitectureReview/v5.5-Monitoring-Adapters-Audit.md`

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
| Monitoring/observability | 9.1 |
| Server security | 4.5 |

### Technical Debt Summary

| Priority | Open items |
|----------|----------|
| P0 | 2 (server RBAC, audit server ingestion) |
| P1 | 0 |
| P2 | 10 |
| P3 | 5 |

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

### v4.3 — Server RBAC & Tenant Isolation Validation

| Field | Detail |
|-------|--------|
| **Objective** | Tenant/RBAC validation suites; staging checklist; Control Center isolation |
| **Release doc** | `docs/Releases/v4.3-Server-RBAC-Validation.md` |
| **Audits** | `docs/ArchitectureReview/v4.3-*` (2 audit docs) |
| **Status** | ✅ Complete (client); server RLS pending |

### v4.4 — Audit Backend Completion

| Field | Detail |
|-------|--------|
| **Objective** | Audit health monitor, readiness verifier, lifecycle validation |
| **Release doc** | `docs/Releases/v4.4-Audit-Backend-Completion.md` |
| **Audits** | `docs/ArchitectureReview/v4.4-*` (2 audit docs) |
| **Status** | ✅ Complete (client); server ingestion pending |

### v4.5 — Manage Permission Enforcement

| Field | Detail |
|-------|--------|
| **Objective** | UI + provider manage/approve enforcement; permission coverage inventory |
| **Release doc** | `docs/Releases/v4.5-Manage-Permission-Enforcement.md` |
| **Audits** | `docs/ArchitectureReview/v4.5-*` (2 audit docs) |
| **Status** | ✅ Complete (partial UI coverage) |

### v4.6 — Complete Pagination Rollout

| Field | Detail |
|-------|--------|
| **Objective** | PaginatedResult on all 42 ERP list endpoints |
| **Release doc** | `docs/Releases/v4.6-Pagination-Rollout.md` |
| **Audit** | `docs/ArchitectureReview/v4.6-Pagination-Audit.md` |
| **Status** | ✅ Complete |

### v4.7 — Performance Optimization

| Field | Detail |
|-------|--------|
| **Objective** | Provider rebuild reduction; handoff decouple; performance registry |
| **Release doc** | `docs/Releases/v4.7-Performance-Optimization.md` |
| **Audit** | `docs/ArchitectureReview/v4.7-Performance-Audit.md` |
| **Status** | ✅ Complete (partial — 7/10 clusters) |

### v4.8 — Mobile Write APIs

| Field | Detail |
|-------|--------|
| **Objective** | Parent/Teacher/Student write APIs (10 methods) |
| **Release doc** | `docs/Releases/v4.8-Mobile-Write-APIs.md` |
| **Audit** | `docs/ArchitectureReview/v4.8-Mobile-Write-API-Audit.md` |
| **Status** | ✅ Complete |

### v4.9 — UI Completion & Legacy Dashboard Migration

| Field | Detail |
|-------|--------|
| **Objective** | ViewState migration (8 dashboards); mobile write UI; pagination UX |
| **Release doc** | `docs/Releases/v4.9-UI-Completion.md` |
| **Audit** | `docs/ArchitectureReview/v4.9-UI-Audit.md` |
| **Status** | ✅ Complete (partial pagination/virtualization) |

### v5.0 — Pilot School Readiness

| Field | Detail |
|-------|--------|
| **Objective** | Cross-module workflow certification; pilot checklists |
| **Release doc** | `docs/Releases/v5.0-Pilot-Readiness.md` |
| **Audit** | `docs/ArchitectureReview/v5.0-Pilot-Audit.md` |
| **Status** | ✅ Complete (mock pilot); live pilot blocked by P0 |

### v5.1 — Monitoring & Observability Foundation

| Field | Detail |
|-------|--------|
| **Objective** | Monitoring/analytics abstractions; operational metrics; health integration |
| **Release doc** | `docs/Releases/v5.1-Monitoring-Observability.md` |
| **Audit** | `docs/ArchitectureReview/v5.1-Observability-Audit.md` |
| **Status** | ✅ Complete (architecture only) |

---

## Future Releases

### v5.2 — Pagination UX & Virtualization Completion

| Field | Detail |
|-------|--------|
| **Goals** | Pagination bars on remaining list screens; virtualize transport/alumni tables |
| **Release doc** | `docs/Releases/v5.2-Pagination-UX-Completion.md` |
| **Audit** | `docs/ArchitectureReview/v5.2-Pagination-UX-Audit.md` |
| **Status** | ✅ Complete |

### v5.3 — Manage Permission Completion

| Field | Detail |
|-------|--------|
| **Goals** | Wire manage/approve guards on all mutation UI buttons |
| **Release doc** | `docs/Releases/v5.3-Manage-Permission-Completion.md` |
| **Audit** | `docs/ArchitectureReview/v5.3-Authorization-Audit.md` |
| **Status** | ✅ Complete |

### v5.4 — Global Error Handling & Resilience

| Field | Detail |
|-------|--------|
| **Goals** | Global error handler, Riverpod observer, API/repository failure reporting |
| **Release doc** | `docs/Releases/v5.4-Global-Error-Handling.md` |
| **Audit** | `docs/ArchitectureReview/v5.4-Resilience-Audit.md` |
| **Status** | ✅ Complete |

### v5.5 — Vendor Monitoring Adapters

| Field | Detail |
|-------|--------|
| **Goals** | Sentry/Datadog adapter implementations; production crash reporting |
| **Dependencies** | v5.4 complete |
| **Release doc** | `docs/Releases/v5.5-Vendor-Monitoring-Adapters.md` |
| **Audit** | `docs/ArchitectureReview/v5.5-Monitoring-Adapters-Audit.md` |
| **Blockers** | Vendor account provisioning for SDK-backed transports |
| **Status** | ✅ Complete |

### v5.6 — Backend Architecture Foundation

| Field | Detail |
|-------|--------|
| **Goals** | Backend platform architecture docs; database, auth, RBAC, tenant, audit, deployment |
| **Release doc** | `docs/Releases/v5.6-Backend-Architecture.md` |
| **Audit** | `docs/ArchitectureReview/v5.6-Backend-Architecture-Audit.md` |
| **Scope** | Architecture and planning only — no backend code |
| **Status** | ✅ Complete |

### v6.0 — Backend Core Platform (Sprint 2)

| Field | Detail |
|-------|--------|
| **Goals** | Supabase staging, core schema, OTP auth, JWT refresh |
| **Release doc** | `docs/Releases/v6.0-Core-Platform-Foundation.md` |
| **Status** | ✅ Complete |

### v6.1 Phase 5C — Academic Catalog + Soft FK

| Phase | Goal | Status |
|-------|------|--------|
| 5C.0 | Academic schema + GET APIs | ✅ Complete |
| 5C.1 | Flutter catalog read layer | ✅ Complete |
| 5C.2 | Backend soft FK + resolver | ✅ Complete |
| 5C.3 | Client soft FK dual-write | ✅ Complete |

**Release docs:** `docs/Releases/v6.1-Phase5C3-Client-Soft-FK.md`

### v6.1 Phase 5B — SIS Dashboard Aggregates

| Field | Detail |
|-------|--------|
| **Goals** | Live SIS dashboard KPIs, class/gender distribution, recent enrollments |
| **Dependencies** | Phase 5A SIS foundation, Phase 5C academic catalog |
| **Release doc** | `docs/Releases/v6.1-Phase5B-SIS-Dashboard-Aggregates.md` |
| **Status** | ✅ Complete |

**Next:** Sprint 3 completion gate — Finance slice (4B3–4B5) complete

### v6.1 Phase 4B5 — Finance Refunds

| Field | Detail |
|-------|--------|
| **Goals** | Refund workflow API parity, collection reversal sync, client detail read |
| **Release doc** | `docs/Releases/v6.1-Phase4B5-Finance-Refunds.md` |
| **Status** | ✅ Complete |

---

## Upcoming Backend Work

### v6.2 Sprint 4 Phase 1 — Transport + HR Read APIs

| Field | Detail |
|-------|--------|
| **Goals** | Live backend for Transport (10) + HR (9) read methods |
| **Release doc** | `docs/Releases/v6.2-Sprint4-Transport-HR-Read-APIs.md` |
| **Status** | ✅ Complete |

---

## Upcoming Backend Work

### v6.2 Sprint 4 Phase 2 — Operational Modules Read APIs

| Field | Detail |
|-------|--------|
| **Goals** | Hostel + Library + Inventory + Alumni live read APIs (34 methods) |
| **Release doc** | `docs/Releases/v6.2-Sprint4-Operational-Modules-Read-APIs.md` |
| **Status** | ✅ Complete |

---

## Upcoming Backend Work

### v6.2 Sprint 4 Phase 3 — Management + Control Center Read APIs

| Field | Detail |
|-------|--------|
| **Goals** | Management (8) + Control Center (12) live read APIs |
| **Release doc** | `docs/Releases/v6.2-Sprint4-Management-ControlCenter-Read-APIs.md` |
| **Status** | ✅ Complete |

---

## Upcoming Backend Work

### v6.3 Sprint 5 — Audit Ingestion + Hardening

| Field | Detail |
|-------|--------|
| **Goals** | Audit ingestion, domain_events outbox, mutation middleware |
| **Release doc** | `docs/Releases/v6.3-Sprint5-Audit-Ingestion.md` |
| **Status** | ✅ Complete (core pipeline) |

### v6.4 Sprint 6 — Validation + Pilot Backend

| Field | Detail |
|-------|--------|
| **Goals** | Server RBAC validation, audit E2E, cross-module tests, pilot verify scripts |
| **Release doc** | `docs/Releases/v6.4-Sprint6-Validation-Pilot-Backend.md` |
| **Status** | ✅ Complete |

### v7.0 — Universal Payment Engine

| Field | Detail |
|-------|--------|
| **Goals** | Razorpay integration, payment intent lifecycle, invoice/collection linkage |
| **Release doc** | `docs/Releases/v7.0-Universal-Payment-Engine.md` |
| **Status** | ✅ Complete (stub mode) |

### v7.1 — Communication Hub

| Field | Detail |
|-------|--------|
| **Goals** | Notifications, templates, messaging, broadcasts, stub SMS/Email/Push |
| **Release doc** | `docs/Releases/v7.1-Communication-Hub.md` |
| **Status** | ✅ Complete (stub providers) |

### v7.1-Pilot — Pilot Operations Sprint

| Field | Detail |
|-------|--------|
| **Goals** | Attendance/timetable ops, mobile write parity, comms inbox, device tokens, audit hardening |
| **Release doc** | `docs/Releases/v7.1-Pilot-Operations-Sprint.md` |
| **Audit doc** | `docs/ArchitectureReview/v7.1-Pilot-Operations-Audit.md` |
| **Status** | ✅ Complete |

### v7.1-Pilot-Closure — Pilot Closure Sprint

| Field | Detail |
|-------|--------|
| **Goals** | Timetable read integration, seed data fix, probe validation |
| **Release doc** | `docs/Releases/v7.1-Pilot-Closure-Sprint.md` |
| **Status** | ✅ Complete — pilot blockers closed |

### v7.15 — School Data Migration & Onboarding (Phase A)

| Field | Detail |
|-------|--------|
| **Goals** | Student/teacher import, parent provisioning, OTP student-ID login, invites, audit, probes |
| **Release doc** | `docs/Releases/v7.15-School-Onboarding-PhaseA.md` |
| **Audit doc** | `docs/ArchitectureReview/v7.15-School-Onboarding-PhaseA.md` |
| **Status** | ✅ Complete |

### v7.2 — Inventory-Finance Integration

| Field | Detail |
|-------|--------|
| **Goals** | Shared vendor master, procurement → AP posting |
| **Release doc** | `docs/Releases/v7.2-Inventory-Finance-Integration.md` |
| **Status** | ✅ Complete |

### v7.3 — Production Hardening

| Field | Detail |
|-------|--------|
| **Goals** | Webhook tenant resolution, event retries, ops monitoring, runbook |
| **Release doc** | `docs/Releases/v7.3-Production-Hardening.md` |
| **Status** | ✅ Complete |

### v7.3.1 — Audit Remediation

| Field | Detail |
|-------|--------|
| **Goals** | Close Priority A findings from comprehensive audit (RBAC, RLS, hybrid routing, probes) |
| **Release doc** | `docs/Releases/v7.3.1-Audit-Remediation.md` |
| **Audit doc** | `docs/ArchitectureReview/v7.3-Comprehensive-Audit-5C2-v7.3.md` |
| **Status** | ✅ Complete |

### v7.3.2 — Mutation Audit Completion

| Field | Detail |
|-------|--------|
| **Goals** | Close A10–A14: audit + domain events on all core ERP writes; webhook collection |
| **Release doc** | `docs/Releases/v7.3.2-Mutation-Audit-Completion.md` |
| **Audit doc** | `docs/ArchitectureReview/v7.3.2-Mutation-Audit-Completion.md` |
| **Status** | ✅ Complete |

### v7.2c — Finance Reconciliation UI

| Field | Detail |
|-------|--------|
| **Goals** | Reconciliation dashboard, timeline, GRN/posting review, vendor history, write repos |
| **Release doc** | `docs/Releases/v7.2c-Finance-Reconciliation-UI.md` |
| **Audit doc** | `docs/ArchitectureReview/v7.2c-Finance-Reconciliation-UI.md` |
| **Status** | ✅ Complete |

**Next milestone:** v7.5 Smart Timetable + Workload Engine

---

### v7.4 — AI Copilot

| Field | Detail |
|-------|--------|
| **Goals** | Read-only copilot foundation, five ERP assistants, context engine, chat UI |
| **Release doc** | `docs/Releases/v7.4-AI-Copilot.md` |
| **Audit doc** | `docs/ArchitectureReview/v7.4-AI-Copilot.md` |
| **Status** | ✅ Complete |

**Next milestone:** v7.8 Live Integrations Sign-off

---

### v7.5 — Smart Timetable + Workload Engine

| Field | Detail |
|-------|--------|
| **Goals** | Timetable engine, workload, clash detection, publish workflow, Copilot scheduling assistance |
| **Release doc** | `docs/Releases/v7.5-Smart-Timetable-Workload-Engine.md` |
| **Audit doc** | `docs/ArchitectureReview/v7.5-Smart-Timetable-Workload-Engine.md` |
| **Status** | ✅ Complete |

### v1.0-rc1 — Release Candidate (pilot validation)

| Field | Detail |
|-------|--------|
| **Goals** | Package v7.7 baseline for limited production pilot; full Demo School validation; ops docs |
| **Release doc** | `docs/Releases/v1.0-Release-Candidate.md` |
| **Validation** | `docs/Operations/Production-Validation-Report.md` |
| **Go-live** | `docs/Operations/Go-Live-Checklist.md` |
| **Tags** | `v1.0-rc1` · `v1.0-ops-ready` · `v1.0-customer-ready` |
| **Ops** | `docs/Operations/Customer-Readiness-Report.md` |
| **Status** | ✅ Validated on staging (feature freeze — no v7.8+ implementation in RC) |

**Execution focus:** Akshara Evolution Program v8.x wave.

**Vision & order:** `docs/Vision/FutureVision.md` · `docs/Vision/ImplementationRoadmap.md`

### v8.0–v8.4 — Evolution wave (complete)

| Tag | Capability |
|-----|------------|
| `v8.0-academic-year-transition` | Year rollover preview/execute |
| `v8.1-ai-communication-assistant` | Communication Copilot expansion |
| `v8.2-parent-guidance-assistant` | Parent guidance persona |
| `v8.3-teacher-copilot` | Teacher persona + attendance context |
| `v8.4-principal-copilot` | Principal analytics persona |

### v8.5–v8.8 — Education Suite (complete)

| Tag | Capability |
|-----|------------|
| `v8.5-ai-question-paper-generator` | AI question papers — bank-first, PDF/print |
| `v8.6-question-bank` | Reusable question repository |
| `v8.7-homework-worksheet-generator` | Homework + worksheet generation |
| `v8.8-report-card-remarks-generator` | Multilingual report remarks |

**Docs:** `docs/Releases/v8.5-*` … `v8.8-*` · `docs/ArchitectureReview/v8.5-v8.8-Education-Suite.md`

### v8.9–v9.3 — Akshara Intelligence Layer (complete)

| Tag | Capability |
|-----|------------|
| `v8.9-student-risk-prediction` | Risk scoring from attendance, marks, homework, comm, behavior, timetable |
| `v9.0-ai-communication-assistant-full` | 8 scenarios × 8 languages · WhatsApp/SMS/email drafts |
| `v9.1-parent-guidance-assistant-full` | Weekly/monthly/exam review · multilingual printable reports |
| `v9.2-teacher-success-center` | At-risk students, gaps, insights, suggested actions |
| `v9.3-principal-intelligence-center` | Executive dashboard, health insights, export summaries |

**Docs:** `docs/Releases/v8.9-*` … `v9.3-*` · `docs/ArchitectureReview/v8.9-v9.3-Intelligence-Layer.md`

**Flag:** `--dart-define=INTELLIGENCE_API_ENABLED=true` (with `ENABLE_API_MODE=true`)

### v9.4–v9.7 — Phase 4 Evolution (complete)

| Tag | Capability |
|-----|------------|
| `v9.4-homework-intelligence-bridge` | Education + intelligence homework orchestration |
| `v9.5-student-360-profile` | Unified student profile + timeline |
| `v9.6-employee-platform` | Multi-role employee + role assignments |
| `v9.7-inventory-distribution-engine` | Student inventory lifecycle + finance bridge |

**Docs:** `docs/Releases/v9.4-*` … `v9.7-*` · `docs/ArchitectureReview/v9.4-v9.7-Phase4-Consolidated-Review.md`

**Flags:** `INTELLIGENCE_API_ENABLED`, `SIS_API_ENABLED`, `EMPLOYEE_API_ENABLED`, `INVENTORY_DISTRIBUTION_API_ENABLED`

### v9.8–v10.3 — Phase 5 Evolution (complete)

| Tag | Capability |
|-----|------------|
| `v9.8-parent-experience-bridge` | Parent hub — Student 360 + inventory ack + guidance |
| `v9.9-employee-intelligence-platform` | Employee 360 + workload/burnout intelligence dashboard |
| `v10.0-school-operations-hub` | Principal daily command center — school health score |
| `v10.1-book-distribution-platform` | Textbook reports + lost/damaged/missing lifecycle |
| `v10.2-school-memories-platform` | Event timeline, albums, media |
| `v10.3-achievement-promotion-engine` | Achievement workflow — generate, approve, publish, track |

**Docs:** `docs/Releases/v9.8-*` … `v10.3-*` · `docs/ArchitectureReview/v9.8-v10.3-Phase5-Consolidated-Review.md`

**Flag:** `--dart-define=PHASE5_API_ENABLED=true` (with `ENABLE_API_MODE=true` and Phase 4 dependency flags)

### v10.4 — Production Hardening (complete)

| Tag | Capability |
|-----|------------|
| `v10.4-production-hardening` | Phase A–F: parent polish, storage, promotion assets, contract tests, staging script, vision design |

| Phase | Deliverable |
|-------|-------------|
| A | Parent hub — guidance excerpts, homework intelligence, 6-tab polish |
| B | School Memories object storage — presign/confirm/download pipeline |
| C | Promotion asset metadata — six-channel structured bundle |
| D | `phase5_repository_contract_test.dart` |
| E | `scripts/phase5_staging_verify.sh` + validation doc |
| F | Vision design docs — Organization Builder v2, Widget Platform, Employee System, Workflow Engine |

**Docs:** `docs/Releases/v10.4-Production-Hardening.md` · `docs/ArchitectureReview/v10.4-Architecture-Review.md` · `docs/Releases/Phase5-Staging-Validation.md`

**Migration:** `20260622700000_v104_storage_foundation.sql`

### v10.4.1 — Polish & Real-World Readiness (complete)

| Deliverable | Detail |
|-------------|--------|
| Memories Flutter | Upload/download/share UI + repository pipeline |
| Parent polish | Child-aware dashboard, provider invalidation, empty/error states |
| Promotion | Metadata export, metric tracking, approval UX |
| Audit | Download/share/track domain events |
| Tests | +7 (integration + polish) |

**Docs:** `docs/Releases/v10.4.1-Polish-Readiness.md`

### v10.4.2 — Real School Readiness (complete)

| Deliverable | Detail |
|-------------|--------|
| Deploy tooling | `scripts/deploy_staging.sh` |
| Staging probes | Route 404 detection in `phase5_staging_verify.sh` (exit 2) |
| RBAC inventory | Onboarding + distribution + memories/analytics routes |
| Performance | Operations Hub parallel SQL |
| Real school doc | `docs/Releases/RealSchoolValidation.md` |

**Quality gates:** `flutter analyze` 0 · `flutter test` 1126+ passing  
**Staging status:** Deploy blocked — run `./scripts/deploy_staging.sh`  
**Docs:** `docs/Releases/v10.4.2-Real-School-Readiness.md` · `docs/ArchitectureReview/v10.4.2-Production-Readiness.md`

### v1.0 RC Finalization (complete)

| Deliverable | Detail |
|-------------|--------|
| Deployment guide | `docs/Operations/Deployment-Guide.md` |
| RC readiness | `docs/ArchitectureReview/RC-Readiness-Review.md` — **93% overall** |
| Performance | Student 360 parallel SQL; Employee dashboard N+1 eliminated |
| RBAC | 78 routes; onboarding job GET; feature flag aggregator fixed |
| Launch verify | Phase 5 route probes in `production_launch_verify.sh` |

**Docs:** `docs/Releases/v1.0-RC-Finalization.md`

### v10.5–v11.0 — Akshara Evolution Program (complete)

Foundation screens, backend routes, and mock repositories for setup wizard, widget platform, teacher assistant, parent insights, principal command, and growth platform.

**Docs:** `docs/Releases/v10.5-v11.0-Evolution-Program.md`

### v11.1–v11.5 — Evolution Foundation Hardening (complete)

| Milestone | Capability | Status |
|-----------|------------|--------|
| v11.1 | `ApiEvolutionRepository`, remote/DTOs/mappers, contract + integration tests, `EVOLUTION_API_ENABLED` | ✅ |
| v11.2 | Live widget data (`GET /widgets/data`), refresh/cache, permission filtering, dashboard binding | ✅ |
| v11.3 | Setup wizard auto-provision (academic year, classes, sections, fee structures, warnings) | ✅ |
| v11.4 | Growth ↔ Admissions (`lead_id` FK, convert inquiry, funnel dashboard) | ✅ |
| v11.5 | Class-scoped teacher insights, parent language persistence, priority engine, ops action center | ✅ |

**Quality gates:** `flutter analyze` 0 · `flutter test` 1143 passing  
**Flag:** `--dart-define=EVOLUTION_API_ENABLED=true` (with `ENABLE_API_MODE=true`)  
**Docs:** `docs/Releases/v11.1-v11.5-Evolution-Hardening.md` · `docs/ArchitectureReview/v11.1-v11.5-Evolution-Hardening.md`

### v12.0 — Phase 8 School Completion (complete)

| Milestone | Capability | Status |
|-----------|------------|--------|
| 1 | Subject Management System | ✅ |
| 2 | Lesson Log System | ✅ |
| 3 | Timetable Automation Engine | ✅ |
| 4 | Parent Insight Language Auto Flow | ✅ |
| 5 | School Branding Foundation | ✅ |
| 6 | WhatsApp Provider Abstraction (MSG91/Gupshup) | ✅ |

**Flag:** `--dart-define=SCHOOL_COMPLETION_API_ENABLED=true`  
**Docs:** `docs/Releases/v12.0-Phase8-School-Completion.md` · `docs/ArchitectureReview/v12.0-Phase8-School-Completion.md`

### v12.1–v12.6 — Phase 9 School Platform Completion (complete)

| Milestone | Capability | Status |
|-----------|------------|--------|
| v12.1 | Class ↔ Subject matrix, teacher allocation, workload | ✅ |
| v12.2 | Lesson analytics engine (teacher + principal) | ✅ |
| v12.3 | Timetable optimization engine | ✅ |
| v12.4 | School branding → ThemeData (login, splash, parent) | ✅ |
| v12.5 | Communication delivery bridge; super-admin provider only | ✅ |
| v12.6 | Real school pilot toolkit | ✅ |

**Flag:** `--dart-define=SCHOOL_COMPLETION_API_ENABLED=true`  
**Docs:** `docs/Releases/v12.1-v12.6-Phase9-School-Platform.md` · `docs/ArchitectureReview/v12.1-v12.6-Phase9-School-Platform.md`

### v12.7–v13.2 — Phase 10 Final School Platform (complete)

| Milestone | Capability | Status |
|-----------|------------|--------|
| v12.7 | Syllabus automation (templates, generate, clone) | ✅ |
| v12.8 | Lesson ↔ topic tracking, teacher/principal dashboards | ✅ |
| v12.9 | Super Admin Control Center (providers, usage, features) | ✅ |
| v13.0 | Vault & secret management (encrypt, rotate, health) | ✅ |
| v13.1 | Timetable intelligence (rooms, labs, exam timetable) | ✅ |
| v13.2 | Parent experience (structured summary, no AI chat) | ✅ |

**Flags:** `SCHOOL_COMPLETION_API_ENABLED=true` · `PARENT_API_ENABLED=true`  
**Docs:** `docs/Releases/v12.7-v13.2-Phase10-School-Final.md` · `docs/ArchitectureReview/v12.7-v13.2-Phase10-School-Final.md`

### v13.3–v14.0 — School Intelligence Program (complete)

| Milestone | Capability | Status |
|-----------|------------|--------|
| v13.3 | Finance Copilot + Executive Dashboard | ✅ |
| v13.4 | Inventory Copilot + Asset Lifecycle | ✅ |
| v13.5 | Student Success Intelligence | ✅ |
| v13.6 | Exam & Academic Intelligence | ✅ |
| v13.7 | Communication Analytics | ✅ |
| v13.8 | Teacher Effectiveness | ✅ |
| v14.0 | Final audit + production readiness | ✅ |

**Docs:** `docs/Releases/v14.0-Final-School-Intelligence-Program.md` · `docs/ArchitectureReview/v14.0-Final-School-Intelligence-Audit.md`

---

### v7.7 — Production SaaS Launch Hardening

| Field | Detail |
|-------|--------|
| **Goals** | Close Final Production Readiness Audit Priority A — deploy verify, integrations docs, DR runbooks, health auth, governance sync |
| **Release doc** | `docs/Releases/v7.7-Production-SaaS-Launch-Hardening.md` |
| **Audit doc** | `docs/ArchitectureReview/v7.7-Production-SaaS-Launch-Hardening.md` |
| **Status** | ✅ Complete |

**Next milestone:** v7.8 — Live Integrations Sign-off

---

## Production Path (updated)

Phase 11: Production Backend              ✅ COMPLETE (v7.2–v7.3 deployed to staging)

**Next milestone:** v7.8 — Live Integrations Sign-off (pilot production cutover)

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

Phase 8: Server Security                ✅ PARTIAL (v4.3–v4.5 client validation)
  RBAC/tenant validation + audit health + manage guards
  Target readiness: 78+ → **80 achieved**

Phase 9: Scale & Completion              ✅ PARTIAL (v4.6–v4.8)
  Pagination rollout + performance + mobile writes
  Target readiness: 85+ → **87 achieved**

Phase 10: Pilot Readiness                 ✅ PARTIAL (v4.9–v5.1)
  UI completion + pilot certification + observability foundation
  Target readiness: 90+ → **93 achieved**

Phase 11: Production Backend              ✅ COMPLETE (v7.2–v7.3 + audit remediation)
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

**Next milestone:** v7.8 — Live Integrations Sign-off  
**Recommended tag:** `v7.7-production-launch-hardening`  
**Autonomous execution depth:** 3 milestones per session
