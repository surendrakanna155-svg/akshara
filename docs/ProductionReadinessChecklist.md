# Akshara ERP — Production Readiness Checklist

**Version:** 2.0  
**Last updated:** June 2026 (v7.7 governance sync)  
**Current score:** 94 / 100 (production-weighted; external integrations env-dependent)  
**Operations runbooks:** `docs/Operations/` (v7.7)

Use this checklist before pilot, staging, and production deployments. Mark `[x]` when verified.

---

## Auth

| # | Item | Demo | Pilot | Staging | Production |
|---|------|:----:|:-----:|:-------:|:----------:|
| A1 | OTP login flow works (mock + API) | [x] | [ ] | [ ] | [ ] |
| A2 | JWT access + refresh token lifecycle | [x] | [ ] | [ ] | [ ] |
| A3 | Secure token storage (native encrypted) | [x] | [x] | [x] | [ ] |
| A4 | Token refresh rotation + reuse detection | [x] | [x] | [ ] | [ ] |
| A5 | Session revocation + logout-all | [x] | [ ] | [ ] | [ ] |
| A6 | JWT claim validation (client) | [x] | [x] | [x] | [ ] |
| A7 | Auth API deployed and contract-tested | [x] | [ ] | [ ] | [ ] |
| A8 | Failed 401 forces logout on all paths | [x] | [ ] | [ ] | [ ] |
| A9 | Demo/mock auth disabled in production | [x] | [ ] | [ ] | [ ] |

---

## RBAC

| # | Item | Demo | Pilot | Staging | Production |
|---|------|:----:|:-----:|:-------:|:----------:|
| R1 | 33 permissions defined (view/manage/approve + copilot/timetable/analytics) | [x] | [x] | [x] | [ ] |
| R2 | ErpRouteGuard on all 12 ERP prefixes | [x] | [x] | [x] | [ ] |
| R3 | ManagePermissionGuard available | [x] | [x] | [x] | [ ] |
| R4 | ApprovePermissionGuard available | [x] | [x] | [x] | [ ] |
| R5 | Server permission sync on login/refresh | [x] | [ ] | [ ] | [ ] |
| R6 | Permission cache version tracking | [x] | [x] | [ ] | [ ] |
| R7 | Denied-access audit events | [x] | [x] | [ ] | [ ] |
| R8 | **Server-side RBAC / RLS enforced** | [x] | [x] | [x] | [ ] |
| R9 | manage* wired on all mutation routes | [x] | [x] | [ ] | [ ] |
| R9a | RBAC validation suite passing | [x] | [x] | [ ] | [ ] |
| R9b | Tenant isolation validation suite (**213 probes**) | [x] | [x] | [x] | [ ] |

---

## API

| # | Item | Demo | Pilot | Staging | Production |
|---|------|:----:|:-----:|:-------:|:----------:|
| P1 | Repository interfaces for all 11 ERP modules | [x] | [x] | [x] | [ ] |
| P2 | Mock repositories — full parity | [x] | [x] | [x] | [ ] |
| P3 | Admissions API — read + write (30 methods) | [x] | [ ] | [ ] | [ ] |
| P4 | Finance API — read + write (23 methods) | [x] | [ ] | [ ] | [ ] |
| P5 | SIS API — read + write (10 methods) | [x] | [ ] | [ ] | [ ] |
| P6 | Auth API (6 methods) | [x] | [ ] | [ ] | [ ] |
| P7 | Remaining 6 modules — live API | [x] | [x] | [ ] | [ ] |
| P7a | HR API — read (9 methods) | [x] | [x] | [ ] | [ ] |
| P7b | Transport API — read (10 methods) | [x] | [x] | [ ] | [ ] |
| P7c | All 11 ERP modules — read APIs | [x] | [x] | [ ] | [ ] |
| P7d | Mobile repository layer (3 apps) | [x] | [x] | [ ] | [ ] |
| P7e | Paginated list fetch (9 endpoints) | [x] | [x] | [ ] | [ ] |
| P7f | Mobile live read APIs (29 methods) | [x] | [x] | [ ] | [ ] |
| P8 | OpenAPI contract validation against staging | [x] | [ ] | [ ] | [ ] |
| P9 | Per-module feature flags tested | [x] | [ ] | [ ] | [ ] |
| P10 | ApiFailure mapping — no raw Dio in UI | [x] | [x] | [x] | [ ] |

---

## Monitoring

| # | Item | Demo | Pilot | Staging | Production |
|---|------|:----:|:-----:|:-------:|:----------:|
| M1 | Correlation ID on all API requests | [x] | [ ] | [ ] | [ ] |
| M2 | Client error reporting (crash analytics) | [x] | [x] | [x] | [ ] |
| M2a | Sentry/Datadog vendor adapters selectable by environment | [x] | [x] | [x] | [ ] |
| M3 | API latency dashboards | [ ] | [ ] | [ ] | [ ] |
| M4 | Auth failure rate alerting | [ ] | [ ] | [ ] | [ ] |
| M5 | Permission sync failure alerting | [ ] | [ ] | [ ] | [ ] |

---

## Audit

| # | Item | Demo | Pilot | Staging | Production |
|---|------|:----:|:-----:|:-------:|:----------:|
| U1 | Local audit logging (200-entry retention) | [x] | [x] | [x] | [ ] |
| U2 | Audit event categorization (security/auth/workflow) | [x] | [x] | [ ] | [ ] |
| U3 | Correlation ID on audit events | [x] | [x] | [ ] | [ ] |
| U4 | Upload queue with batching + retry | [x] | [x] | [ ] | [ ] |
| U4a | Audit health monitor | [x] | [x] | [ ] | [ ] |
| U4b | Audit readiness verifier | [x] | [x] | [ ] | [ ] |
| U5 | **Audit ingestion endpoint live** | [x] | [x] | [x] | [ ] |
| U5a | Client audit batch upload wired (`auditApiEnabledProvider`) | [x] | [x] | [ ] | [ ] |
| U6 | Tamper-evident / signed audit trail | [ ] | [ ] | [ ] | [ ] |
| U7 | Admissions workflow events (12 types) | [x] | [x] | [ ] | [ ] |
| U8 | Finance mutation audit metadata | [x] | [x] | [ ] | [ ] |

---

## Security

| # | Item | Demo | Pilot | Staging | Production |
|---|------|:----:|:-----:|:-------:|:----------:|
| S1 | flutter analyze = 0 issues | [x] | [x] | [x] | [ ] |
| S2 | Security test suite passing | [x] | [x] | [ ] | [ ] |
| S3 | Tenant headers on authenticated requests | [x] | [x] | [ ] | [ ] |
| S4 | No secrets in repository | [x] | [x] | [x] | [ ] |
| S5 | TLS enforced for all API calls | [ ] | [ ] | [ ] | [ ] |
| S6 | Penetration test completed | [ ] | [ ] | [ ] | [ ] |
| S7 | Security score ≥ 88/100 | [x] | [x] | [ ] | [ ] |

---

## Performance

| # | Item | Demo | Pilot | Staging | Production |
|---|------|:----:|:-----:|:-------:|:----------:|
| F1 | Cold start < 3s (splash → dashboard) | [ ] | [ ] | [ ] | [ ] |
| F2 | API list fetch < 2s (p95) | [ ] | [ ] | [ ] | [ ] |
| F3 | Pagination implemented for large lists | [x] | [ ] | [ ] | [ ] |
| F4 | Virtualized lists for DataTables | [x] | [ ] | [ ] | [ ] |
| F5 | Provider rebuild profiling done | [ ] | [ ] | [ ] | [ ] |

---

## Testing

| # | Item | Demo | Pilot | Staging | Production |
|---|------|:----:|:-----:|:-------:|:----------:|
| T1 | flutter test — all passing (1087+) | [x] | [x] | [x] | [ ] |
| T2j | Pilot workflow certification tests | [x] | [x] | [ ] | [ ] |
| T2k | Observability abstraction tests | [x] | [x] | [ ] | [ ] |
| T2l | Vendor monitoring adapter tests | [x] | [x] | [x] | [ ] |
| M4 | MonitoringService abstraction | [x] | [x] | [ ] | [ ] |
| M5 | AnalyticsService abstraction | [x] | [x] | [ ] | [ ] |
| M6 | Observability health snapshot | [x] | [x] | [ ] | [ ] |
| PI1 | Pilot school checklist | [x] | [ ] | [ ] | [ ] |
| UI1 | ERP dashboards on ViewState (11/11) | [x] | [x] | [ ] | [ ] |
| UI2 | Mobile write UI fully wired | [x] | [x] | [ ] | [ ] |
| T2 | Contract tests for live API modules | [x] | [x] | [x] | [ ] |
| T2a | OpenAPI schema validation tests | [x] | [x] | [ ] | [ ] |
| T2b | Mobile repository contract tests | [x] | [x] | [ ] | [ ] |
| T2c | Pagination unit tests | [x] | [x] | [ ] | [ ] |
| T2d | Mobile API integration tests | [x] | [x] | [ ] | [ ] |
| T2e | RBAC + tenant validation suites | [x] | [x] | [ ] | [ ] |
| T2g | Pagination endpoint registry test | [x] | [x] | [ ] | [ ] |
| T2h | Mobile write contract tests | [x] | [x] | [ ] | [ ] |
| T2i | Performance registry tests | [x] | [x] | [ ] | [ ] |
| P1 | PaginatedResult on all ERP list endpoints | [x] | [x] | [ ] | [ ] |
| P2 | Pagination endpoint registry | [x] | [x] | [ ] | [ ] |
| F6 | Provider rebuild registry | [x] | [x] | [ ] | [ ] |
| F7 | Fee handoff override decouple | [x] | [x] | [ ] | [ ] |
| M1 | Parent write APIs (3 methods) | [x] | [x] | [ ] | [ ] |
| M2 | Teacher write APIs (6 methods) | [x] | [x] | [ ] | [ ] |
| M3 | Student write APIs (1 method) | [x] | [x] | [ ] | [ ] |
| T3 | Integration tests with fake Dio | [x] | [x] | [ ] | [ ] |
| T4 | Security tests (RBAC, token, session) | [x] | [x] | [ ] | [ ] |
| T5 | Route protection inventory test | [x] | [x] | [ ] | [ ] |
| T6 | Golden tests (3 dashboards) | [x] | [ ] | [ ] | [ ] |
| T7 | E2E / Patrol tests | [ ] | [ ] | [ ] | [ ] |
| T8 | Load test (100 concurrent users) | [ ] | [ ] | [ ] | [ ] |

---

## Deployment

| # | Item | Demo | Pilot | Staging | Production |
|---|------|:----:|:-----:|:-------:|:----------:|
| D1 | Environment config (dev/staging/prod) | [x] | [x] | [ ] | [ ] |
| D2 | CI pipeline runs analyze + test | [x] | [x] | [x] | [ ] |
| D3 | Web build deployable | [ ] | [ ] | [ ] | [ ] |
| D4 | Android/iOS build pipeline | [ ] | [ ] | [ ] | [ ] |
| D5 | Feature flag rollout per tenant | [ ] | [ ] | [ ] | [ ] |
| D6 | Rollback procedure documented | [x] | [x] | [ ] | [ ] |

---

## Backup & Disaster Recovery

| # | Item | Demo | Pilot | Staging | Production |
|---|------|:----:|:-----:|:-------:|:----------:|
| B1 | Database backup schedule | [ ] | [x] | [x] | [ ] |
| B2 | Backup restore tested | [ ] | [ ] | [ ] | [ ] |
| B3 | RPO / RTO defined | [x] | [x] | [x] | [ ] |
| B4 | Multi-region failover plan | [ ] | [ ] | [ ] | [ ] |
| B5 | Client offline mode documented | [x] | [x] | [ ] | [ ] |

---

## Scoring Guide

| Environment | Minimum checks | Readiness target |
|-------------|---------------:|-----------------:|
| Demo / mock | Auth R1–R4, P1–P2, T1, S1 | 90+ |
| Pilot | + P3–P6, A7, R5, U4 | 93+ |
| Staging | + P8, U5, R8, F3 | 96+ |
| Production SaaS | All items checked | 98+ |
