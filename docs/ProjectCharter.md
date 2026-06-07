# Akshara ERP — Project Charter

**Version:** 1.0  
**Last updated:** June 2026  
**Status:** Active

---

## Vision

Akshara ERP is a **multi-tenant school SaaS platform** that unifies admissions, finance, student information, and campus operations into a single Flutter client — accessible to staff via web ERP and to parents, teachers, and students via mobile apps.

---

## Mission

Deliver a **production-grade, repository-driven ERP client** that:

1. Works offline-first with mock data for demos and development
2. Switches to live APIs per module via feature flags
3. Enforces security (auth, RBAC, tenant, audit) at every layer
4. Maintains full test and documentation coverage for every release

---

## Target Users

| Persona | Surface | Primary modules |
|---------|---------|-----------------|
| School admin / staff | Web ERP admin shell | All 11 ERP modules + Control Center |
| Admissions counselor | Web ERP | Admissions |
| Finance officer | Web ERP | Finance |
| Registrar | Web ERP | SIS |
| Parent | Mobile app | Fees, attendance, homework, notices |
| Teacher | Mobile app | Attendance, homework, exams, messages |
| Student | Mobile app | Timetable, homework, attendance, profile |
| Super admin | Control Center | Multi-school tenant management |

---

## Modules

### ERP Business Modules (11)

Admissions · Finance · SIS · Management · Transport · HR · Hostel · Library · Inventory · Alumni · Control Center

### Platform Modules

Auth · Admin shell · Notifications · Shared widgets · Router · Core infrastructure

### Mobile Modules (3)

Parent · Teacher · Student

---

## Architecture Principles

1. **Repository pattern** — Screen → Provider → Repository interface → Mock | API
2. **Feature flags** — Per-module `*ApiEnabledProvider` in `repository_config.dart`
3. **Single Dio client** — Interceptors: CorrelationId → Tenant → Auth → ApiError
4. **Riverpod state** — Providers for all async data; no direct repository calls from widgets
5. **DTO isolation** — API payloads never leak past mapper layer
6. **Incremental API rollout** — Mock remains default; API enabled per environment + module flag
7. **No duplicate abstractions** — Extend existing services; do not create parallel implementations
8. **Scoped agent ownership** — Each agent owns defined directories only

---

## Security Principles

1. **Defense in depth** — Client RBAC + server enforcement (server is authoritative)
2. **Least privilege** — view* and manage* permissions per module; approve* for workflows
3. **Secure token storage** — `flutter_secure_storage` on native; prefs fallback on web/tests
4. **JWT claim validation** — Client validates structure/claims; signature verified server-side
5. **Tenant isolation** — Tenant headers on every authenticated request; no cross-tenant data
6. **Audit everything security-relevant** — Login, logout, access denied, mutations, permission sync
7. **No secrets in repo** — Environment config via `environment.dart`; never commit credentials

---

## Coding Standards

- **Dart 3.5+** / **Flutter 3.35+**
- Follow `flutter_lints` — `flutter analyze` must be 0 issues before merge
- Match surrounding code style in each file
- Minimize diff scope — focused changes only
- No comments unless non-obvious business logic
- Use existing naming: `*Provider`, `*Screen`, `*Repository`, `*Dto`, `*Mapper`

---

## Repository Standards

Every ERP module must implement:

```
lib/core/repositories/interfaces/{module}_repository.dart
lib/core/repositories/mock/mock_{module}_repository.dart
lib/core/repositories/api/{module}/api_{module}_repository.dart
lib/core/repositories/api/{module}/remote/{module}_remote_datasource.dart
lib/core/repositories/api/{module}/mapper/{module}_mapper.dart
lib/core/repositories/api/{module}/dto/
```

Contract tests: `test/contracts/{module}/`

---

## Testing Standards

| Layer | Location | Minimum |
|-------|----------|---------|
| Unit / provider | `test/features/` | Provider load + error states |
| Contract | `test/contracts/` | Mock ↔ API signature parity |
| Integration | `test/integration/` | Fake Dio round-trips |
| Security | `test/security/` | RBAC deny, token expiry, revoked session |
| Router | `test/router/` | Route guard inventory |
| Golden | `test/golden/` | Dashboard smoke renders |

**Gate:** `flutter test` — all passing, never merge with failures.

---

## Release Standards

Every release requires:

1. `docs/Releases/v{X.Y}-{Name}.md`
2. `docs/ArchitectureReview/v{X.Y}-*-Audit.md` (≥1 audit doc)
3. Updated `docs/Roadmap.md` milestone status
4. Completion report with analyze + test results
5. Git tag `v{X.Y}-{slug}` on `main`

---

## Production Standards

| Environment | Requirements |
|-------------|--------------|
| Demo / mock | Default — no backend required |
| Pilot | Auth + Admissions + Finance + SIS APIs deployed |
| Staging | All live modules + audit ingestion + permission sync validated |
| Production SaaS | Server RBAC/RLS, secure storage audit, monitoring, DR plan |

Current production readiness: **97 / 100** (see `docs/ArchitectureReview/v2.7-Security-Review.md`).
