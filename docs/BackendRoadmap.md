# Akshara ERP — Backend Roadmap

**Document ID:** `AKS-BE-ROADMAP-v1.2`  
**Status:** Sprints 1–6 complete · v7.7 hardened · v1.0-rc1 validated  
**Prerequisite:** v5.6 Backend Architecture Foundation  
**Last updated:** June 2026 (v1.0 Release Candidate)

---

## 1. Overview

Backend implementation proceeds in **6 sprints** after architecture foundation. Each sprint delivers deployable increments validated against existing Flutter contract tests.

```
Sprint 1 (v5.6)  Architecture docs + gap closure  ← COMPLETE
Sprint 2 (v6.0)  Core platform + auth
Sprint 3 (v6.1)  RBAC + RLS + core modules  ← COMPLETE
Sprint 4 (v6.2)  Full ERP API surface
Sprint 5 (v6.3)  Audit ingestion + hardening
Sprint 6 (v6.4)  Validation + pilot backend
```

---

## 2. Sprint 1 — Backend Foundation (v5.6) ✅

**Scope:** Architecture and planning only.

| Deliverable | Status |
|-------------|--------|
| `docs/BackendArchitecture.md` | ✅ |
| `docs/DatabaseArchitecture.md` | ✅ |
| `docs/AuthArchitecture.md` | ✅ |
| `docs/RBACArchitecture.md` | ✅ |
| `docs/TenantArchitecture.md` | ✅ |
| `docs/AuditArchitecture.md` | ✅ |
| `docs/DeploymentArchitecture.md` | ✅ |
| `docs/BackendRoadmap.md` | ✅ |
| `docs/ClientBackendAlignment.md` | ✅ |

**Effort:** 1 week (documentation) + gap closure pass  
**Risk:** Low — no code dependencies

---

## 2a. Sprint 1 Gap Closure (v5.6.1) ✅

| Gap area | Document updated |
|----------|------------------|
| Organization Admin | RBAC §2a, Tenant §3/§6a, Auth scope |
| Multi-school groups | Database §3, Tenant §6, RBAC §2b |
| Communication Hub | Backend §11, Database §8a, Audit §5 |
| Universal Payment Engine | Backend §12, Database §8b, Audit §5 |
| Inventory-Finance | Backend §13, Database §8c, Audit §5 |
| Event bus | Backend §10 |
| Client alignment | `ClientBackendAlignment.md` |

---

## 3. Sprint 2 — Core Platform (v6.0)

**Goal:** Runnable staging backend with auth.

| Work item | Effort | Owner |
|-----------|--------|-------|
| Supabase project (staging) | 2 d | Backend |
| Core schema: org, school, user, membership | 3 d | Backend |
| OTP send/verify endpoints | 3 d | Backend |
| JWT issue + refresh rotation | 3 d | Backend |
| OpenAPI spec v1 (auth + health) | 2 d | Agent A |
| CI staging deploy pipeline | 2 d | DevOps |
| Flutter auth integration test vs staging | 2 d | Agent E |

**Total:** ~3 weeks  
**Gate:** OTP login works end-to-end on staging  
**Risk:** SMS provider provisioning delay

---

## 4. Sprint 3 — RBAC + RLS + Core Modules (v6.1)

**Goal:** Server-side authorization; Admissions + Finance + SIS live.

| Work item | Effort | Owner |
|-----------|--------|-------|
| Permission tables + role seed | 2 d | Backend |
| RBAC middleware on Edge Functions | 3 d | Backend |
| PostgreSQL RLS policies (core modules) | 5 d | Backend |
| Admissions API (30 methods) | 8 d | Agent A |
| Finance API (23 methods) | 6 d | Agent A |
| SIS API (10 methods) | 4 d | Agent A |
| Contract test validation | 3 d | Agent E |

**Total:** ~5 weeks  
**Gate:** All 63 core module contract tests pass against staging  
**Risk:** RLS complexity; cross-module handoff edge cases  
**Resolves:** TD-P0-01 (partial — core modules)

**Sprint 3 progress (June 2026):**

| Phase | Status |
|-------|--------|
| 5A SIS foundation | ✅ |
| 5C Academic catalog + soft FK | ✅ (5C.0–5C.3) |
| 5B SIS dashboard aggregates | ✅ |
| Finance invoices (Phase 4B3) | ✅ |
| Finance collections (Phase 4B4) | ✅ |
| Finance refunds (Phase 4B5) | ✅ |
| Sprint 3 gate | ✅ Complete |
| Transport + HR read APIs (Sprint 4 Phase 1) | ✅ |
| Hostel + Library + Inventory + Alumni (Sprint 4 Phase 2) | ✅ |
| Management + Control Center (Sprint 4 Phase 3) | ✅ |
| Mobile read APIs (Sprint 4 Phase 4) | ✅ |
| Audit ingestion + domain_events outbox (Sprint 5) | ✅ |
| Validation + pilot backend (Sprint 6) | ✅ |

---

## 5. Sprint 4 — Full ERP API Surface (v6.2)

**Goal:** All 144 repository methods have live backend.

| Work item | Effort | Owner |
|-----------|--------|-------|
| Transport, HR, Hostel APIs (28 methods) | 8 d | Agent A |
| Library, Inventory, Alumni APIs (25 methods) | 8 d | Agent A |
| Management, Control Center APIs (20 methods) | 6 d | Agent A |
| Mobile read APIs (29 methods) | 6 d | Agent C |
| School groups schema + org admin RBAC | 3 d | Backend |
| Context switch API | 2 d | Backend |
| Pagination on all list endpoints | 4 d | Agent A |
| RLS on remaining modules | 4 d | Backend |

**Total:** ~6 weeks  
**Gate:** 144/144 contract parity  
**Risk:** Control Center platform scope creep

---

## 6. Sprint 5 — Audit + Hardening (v6.3)

**Goal:** Compliance-ready audit pipeline.

| Work item | Effort | Owner |
|-----------|--------|-------|
| Audit ingestion endpoint | 3 d | Backend |
| Client queue drain integration | 2 d | Agent D |
| Server mutation audit middleware | 4 d | Backend |
| **`domain_events` outbox + router** | 3 d | Backend |
| Audit partitioning + archive | 3 d | Backend |
| Production environment setup | 3 d | DevOps |
| Security review + pen test | 5 d | External |

**Total:** ~4 weeks  
**Gate:** Audit events ingested and queryable; v5.7 validation  
**Resolves:** TD-P0-02

---

## 7. Sprint 6 — Validation + Pilot Backend (v6.4)

**Goal:** Production-ready backend for pilot school.

| Work item | Effort | Owner |
|-----------|--------|-------|
| v5.6 RBAC validation suite (server) | 3 d | Agent E |
| v5.7 audit ingestion validation | 2 d | Agent E |
| Cross-module handoff integration tests | 3 d | Agent E |
| Pilot school onboarding | 3 d | Ops |
| Production deploy + monitoring | 3 d | DevOps |
| Runbook + incident response docs | 2 d | Agent F |

**Total:** ~3 weeks  
**Gate:** Pilot school live on production backend  
**Readiness target:** 98/100

---

## 8. Future Backend Phases (post v6.4)

| Phase | Focus | Dependencies |
|-------|-------|--------------|
| v7.0 | Universal Payment Engine (Razorpay) | ✅ Complete (stub mode) |
| v7.1 | Communication Hub | ✅ Complete (stub providers) |
| v7.1-Pilot | Pilot Operations Sprint | ✅ Complete |
| v7.1-Pilot-Closure | Timetable integration + seed fix | ✅ Complete |
| v7.15 | School onboarding & data migration (Phase A) | ✅ Complete |
| v7.2 | Inventory-Finance integration | ✅ Complete |
| v7.3 | Production hardening | ✅ Complete |
| v7.3.1 | Audit remediation (RBAC/RLS/hybrid routing) | ✅ Complete |
| v7.3.2 | Mutation audit completion (A10–A14) | ✅ Complete |
| v7.2a | Shared vendor master + sync | ✅ (v7.2) |
| v7.2b | Procurement → AP posting | ✅ (v7.2) |
| v7.2c | Finance reconciliation UI | ✅ Complete |
| v7.4 | AI Copilot services | ✅ Complete |
| v7.5 | Smart Timetable + Workload Engine | ✅ Complete |
| v7.6 | Analytics & Intelligence (risk + school health) | ✅ Complete |
| v7.7 | Production SaaS Launch Hardening | ✅ Complete |
| **v1.0-rc1** | Release Candidate (pilot validation + ops docs) | ✅ Validated on staging |
| v7.8 | Live integrations sign-off + pen test | Pilot cutover |
| v7.8 | Document & Report Engine | R2 + PDF service |
| v7.9 | School Memories + Akshara Growth | Media service |

### v7.2 Inventory-Finance roadmap detail

| Step | Deliverable | Gate |
|------|-------------|------|
| 1 | Shared `vendors` table; `vendor.created/updated` events | Contract tests |
| 2 | `procurement.approved` consumer → AP commitment | Integration test |
| 3 | Ledger posting + `inventory_finance_postings` link | ✅ Finance reconciliation (v7.2c) |
| 4 | Client audit enum sync | Flutter tests |

---

## 9. Effort Summary

| Sprint | Duration | Cumulative |
|--------|----------|------------|
| Sprint 1 (v5.6) | 1 wk | 1 wk |
| Sprint 2 (v6.0) | 3 wks | 4 wks |
| Sprint 3 (v6.1) | 5 wks | 9 wks |
| Sprint 4 (v6.2) | 6 wks | 15 wks |
| Sprint 5 (v6.3) | 4 wks | 19 wks |
| Sprint 6 (v6.4) | 3 wks | 22 wks |

**Total to pilot-ready backend:** ~22 weeks (5.5 months) with 2 backend engineers + existing Flutter agents.

---

## 10. Critical Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Supabase limits at scale | Performance ceiling | NestJS extraction plan documented |
| RLS policy bugs | Data leakage | Tenant isolation test suite (v5.6) |
| OpenAPI drift | Client breakage | Contract tests as deploy gate |
| SMS/OTP provider outage | Auth blocked | Fallback provider; email OTP |
| Audit volume | DB growth | Partitioning from Sprint 5 |
| Scope creep (AI, payments) | Delay core ERP | Strict sprint boundaries |

---

## 11. Dependencies on Client

| Client artifact | Backend dependency |
|---------------|-------------------|
| 37 contract test files | API parity gate |
| `ApiConfig` headers | Middleware must honor |
| `Permission` enum (22 today; 32 planned) | RBAC seed data |
| `AuditEventType` (24 today; 40+ planned) | Audit schema |
| `TenantContext` | Tenant model |
| `ClientBackendAlignment.md` | Enum sync checklist |
| Feature flags (`repository_config`) | Per-module rollout |

Client requires **no changes** for Sprint 1. Sprint 3+ requires enum additions per `ClientBackendAlignment.md`.
