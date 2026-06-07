# Akshara ERP — Master Roadmap

**Version:** 1.0  
**Last updated:** June 2026  
**Current release:** v2.7 (Security Hardening)  
**Production readiness:** 97 / 100  
**Quality gates:** `flutter analyze` 0 issues · `flutter test` 693 passing · 117 test files

---

## Current State

### Architecture Summary

Akshara ERP is a **Flutter monorepo** with:

- **Web ERP admin shell** — 11 business modules + Control Center
- **Mobile apps** — Parent, Teacher, Student (inline mocks)
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
| 5 | management | ERP | 8 | 8 methods | Mock / stub API |
| 6 | transport | ERP | 10 | 10 methods | Mock / stub API |
| 7 | hr | ERP | 9 | 9 methods | Mock / stub API |
| 8 | hostel | ERP | 9 | 9 methods | Mock / stub API |
| 9 | library | ERP | 8 | 8 methods | Mock / stub API |
| 10 | inventory | ERP | 8 | 8 methods | Mock / stub API |
| 11 | alumni | ERP | 9 | 9 methods | Mock / stub API |
| 12 | control_center | ERP | 12 | 12 methods | Mock / stub API |
| 13 | auth | All | 6 | 6 methods (Auth) | ✅ Live |
| 14 | parent | Mobile | 13 | Inline mocks | ❌ No repository |
| 15 | teacher | Mobile | 8 | Inline mocks | ❌ No repository |
| 16 | student | Mobile | 7 | Inline mocks | ❌ No repository |
| 17 | notifications | Cross-cutting | 0 | — | — |

### API Inventory

| Module | Read | Write | Live total | Mock | API repo |
|--------|-----:|------:|-----------:|-----:|:--------:|
| Admissions | 11 | 19 | 30/30 | ✅ | ✅ |
| Finance | 13 | 10 | 23/23 | ✅ | ✅ |
| SIS | 5 | 5 | 10/10 | ✅ | ✅ |
| Auth | 6 | — | 6/6 | ✅ | ✅ |
| Transport | 10 | 0 | 0/10 | ✅ | ❌ stub |
| HR | 9 | 0 | 0/9 | ✅ | ❌ stub |
| Hostel | 9 | 0 | 0/9 | ✅ | ❌ stub |
| Library | 8 | 0 | 0/8 | ✅ | ❌ stub |
| Inventory | 8 | 0 | 0/8 | ✅ | ❌ stub |
| Alumni | 9 | 0 | 0/9 | ✅ | ❌ stub |
| Management | 8 | 0 | 0/8 | ✅ | ❌ stub |
| Control Center | 12 | 0 | 0/12 | ✅ | ❌ stub |
| **ERP Total** | **110** | **34** | **63/144** | **144/144** | **46%** |

**DTO files:** 68 · **Contract test files:** 18 · **Integration test dirs:** 5 (auth, admissions, finance, sis, audit)

### Test Inventory

| Category | Files | Tests (approx) |
|----------|------:|---------------:|
| Feature provider/screen | 62 | ~380 |
| Contract | 18 | ~120 |
| Integration | 5 | ~30 |
| Security | 6 | ~20 |
| Router | 2 | ~10 |
| Core (network, RBAC, tenant) | 12 | ~50 |
| Golden | 3 | 3 |
| Auth / startup / widget | 9 | ~80 |
| **Total** | **117** | **693** |

### Production Readiness Score

**97 / 100** — see `docs/ArchitectureReview/v2.7-Security-Review.md`

| Category | Score |
|----------|------:|
| Auth security | 9.0 |
| RBAC | 8.5 |
| Audit/compliance | 8.0 |
| Token lifecycle | 9.0 |
| Build/test health | 10.0 |
| API coverage | 5.5 |
| Server security | 4.5 |
| Mobile/mock gaps | 5.0 |

### Technical Debt Summary

| Priority | Open items |
|----------|----------|
| P0 | 3 (server RBAC, audit ingestion, 8 stub modules) |
| P1 | 8 (mobile repos, pagination, OpenAPI, etc.) |
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

---

## Future Releases

### v2.8 — API Contract Validation & Audit Backend

| Field | Detail |
|-------|--------|
| **Goals** | OpenAPI staging validation; wire audit upload uploader; permission sync backend validation |
| **Dependencies** | v2.7 security foundation; staging backend deployed |
| **Acceptance criteria** | OpenAPI contract tests pass against staging; audit events drain from upload queue; analyze 0; tests pass |
| **Estimated effort** | 2–3 weeks |
| **Risks** | Backend audit endpoint not ready |
| **Blockers** | TD-P0-02, TD-P1-03, TD-P1-05 |
| **Owner** | Agent A + Agent D |
| **Status** | 🔲 Not started |

### v2.9 — HR + Transport Live Read APIs

| Field | Detail |
|-------|--------|
| **Goals** | Live read APIs for HR (9 methods) and Transport (10 methods) |
| **Dependencies** | v2.8 contract validation pattern; backend HR/Transport endpoints |
| **Acceptance criteria** | 19 live read methods; contract + integration tests; dashboard screens wired |
| **Estimated effort** | 3–4 weeks |
| **Risks** | Backend schema mismatch |
| **Blockers** | TD-P0-03 (partial) |
| **Owner** | Agent A + Agent B |
| **Status** | 🔲 Not started |

### v3.0 — Mobile Repository Layer

| Field | Detail |
|-------|--------|
| **Goals** | Migrate parent/teacher/student from inline mocks to repository pattern |
| **Dependencies** | Auth API stable; mobile backend endpoints defined |
| **Acceptance criteria** | 3 mobile modules use repositories; provider tests updated; no inline mock data |
| **Estimated effort** | 6–8 weeks |
| **Risks** | Mobile API surface undefined; breaking UX changes |
| **Blockers** | TD-P1-01 |
| **Owner** | Agent C + Agent A |
| **Status** | 🔲 Not started |

### v3.1 — Pagination & Performance

| Field | Detail |
|-------|--------|
| **Goals** | Server pagination in repository interfaces; virtualized DataTables |
| **Dependencies** | v2.9+ modules on live API; backend pagination support |
| **Acceptance criteria** | Paginated fetch for Admissions, Finance, SIS lists; no full-list fetch; p95 < 2s |
| **Estimated effort** | 4–5 weeks |
| **Risks** | Breaking repository interface changes |
| **Blockers** | TD-P1-02, TD-P1-13 |
| **Owner** | Agent A + Agent B |
| **Status** | 🔲 Not started |

### v3.2 — Remaining ERP Live Read APIs

| Field | Detail |
|-------|--------|
| **Goals** | Live read for Hostel, Library, Inventory, Alumni, Management, Control Center (55 methods) |
| **Dependencies** | v2.9 pattern established; backend modules deployed |
| **Acceptance criteria** | 55 additional live read methods; all ERP modules off stub API |
| **Estimated effort** | 8–10 weeks |
| **Risks** | Control Center complexity; multi-tenant scoping |
| **Blockers** | TD-P0-03 |
| **Owner** | Agent A + Agent B |
| **Status** | 🔲 Not started |

### v4.0 — Multi-Tenant Production SaaS

| Field | Detail |
|-------|--------|
| **Goals** | Production deployment with server RBAC/RLS, monitoring, DR, full API coverage |
| **Dependencies** | v3.0–v3.2 complete; all P0 debt resolved |
| **Acceptance criteria** | Production checklist 98%+; security score 95+; E2E tests; pilot validated |
| **Estimated effort** | 12–16 weeks |
| **Risks** | Server-side security gaps; performance at scale |
| **Blockers** | TD-P0-01, TD-P0-02, TD-P0-03 |
| **Owner** | Agent G + all agents |
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

Phase 4: Pilot                          🔲 NEXT (v2.8–v2.9)
  Staging backend + contract validation + HR/Transport APIs
  Target readiness: 93+

Phase 5: Staging                        🔲 (v3.0–v3.2)
  Mobile repos + pagination + remaining ERP APIs
  Target readiness: 96+

Phase 6: Production                       🔲 (v4.0)
  Server RBAC/RLS + monitoring + DR
  Target readiness: 98+

Phase 7: Multi-Tenant SaaS              🔲 (v4.0+)
  Gradual tenant rollout + Control Center live
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
3. Read docs/CURSOR_WORKFLOW.md → follow startup procedure
4. Pick next 🔲 milestone
5. Execute → validate → document → report
```

**Next milestone:** v2.8 — API Contract Validation & Audit Backend
