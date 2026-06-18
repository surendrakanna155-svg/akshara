# Phase F1 — Auth + RBAC Final Certification

**Date:** 2026-06-18  
**Phase:** Production Backend Program **F1**  
**Class A items:** A1 Authentication & tenant session · A10 RBAC & permission sync  
**Verdict:** **PASS** (client F1 scope)  
**Authority:** `docs/ORCHESTRATOR_AGENT.md`, `docs/PRODUCTION_BACKEND_ROADMAP.md`

---

## Executive summary

| Gate | Result |
|------|--------|
| `flutter analyze` (F1 paths) | **0 errors** |
| `flutter test` (full suite) | **1956 passed**, 1 skipped |
| F1 contract tests | **PASS** (auth DTO/mapper/remote) |
| F1 integration tests | **PASS** (fake Dio login → verify → sync → refresh) |
| F1 security tests | **PASS** (API mode fail-closed RBAC) |
| Mock fallback | **PASS** (`ENABLE_API_MODE=false` → `MockAuthRepository`) |
| F2 scope | **Not started** |

**Production API readiness:** **~45% → ~53%** (F1 client + contract layer complete; staging deploy verification pending ops)

---

## Deliverables

### Flutter client (Agent A + D)

| Area | Change |
|------|--------|
| `AuthRepository` | Added `revokeSession`, `logoutAllSessions`, `fetchPermissionPolicy` |
| `ApiAuthRepository` | Session revoke + policy fetch; permission version from server |
| `AuthPermissionsDto` | `permissionsVersion`, `etag`, `syncedAt` |
| `AuthMapper` | Policy from DTO/verification; version-aware sync |
| `auth_repository_providers` | Unified `syncAuthPermissions` → `permission_sync_service`; `applyVerificationPermissions` |
| `rbac_service` | **Fail-closed** in API mode when no server snapshot |
| `auth_provider` | Bootstrap permissions on verify/login before network re-sync |
| `repository_config` | F1 flag documentation |

### Supabase backend (pre-existing — verified in repo)

| Endpoint | Handler |
|----------|---------|
| `POST /auth/login` | `handleLogin` |
| `POST /auth/verify-otp` | `handleVerifyOtp` |
| `POST /auth/refresh` | `handleRefresh` |
| `POST /auth/logout` | `handleLogout` |
| `POST /auth/sessions/logout-all` | `handleLogoutAll` |
| `POST /auth/sessions/revoke` | `handleRevokeSession` |
| `GET /auth/me` | `handleMe` |
| `GET /auth/permissions` | `handlePermissions` |

### Documentation

| Doc | Path |
|-----|------|
| Migration & rollback | `docs/F1_AUTH_MIGRATION.md` |
| Certification | `docs/PHASE_F1_FINAL_CERTIFICATION.md` |

### Tests added

| File | Coverage |
|------|----------|
| `test/contracts/auth/auth_repository_contract_test.dart` | Permission version DTO mapping |
| `test/contracts/auth/auth_remote_datasource_test.dart` | Revoke + logout-all |
| `test/integration/auth/f1_auth_rbac_integration_test.dart` | Full F1 flow |
| `test/security/rbac/f1_api_mode_fail_closed_test.dart` | API/mock repo selection + fail-closed |

---

## Certification checklist

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Supabase Auth integration (client Dio + paths) | ✅ |
| 2 | JWT handling (interceptor + refresh callback) | ✅ |
| 3 | School/tenant claims in `AuthUser` + `AuthClaims` | ✅ |
| 4 | RBAC sync API (`fetchPermissionPolicy`) | ✅ |
| 5 | Flutter repository integration | ✅ |
| 6 | Mock fallback when API mode off | ✅ |
| 7 | Contract tests | ✅ |
| 8 | Migration path documented | ✅ |
| 9 | F2 not started | ✅ |
| 10 | Staging E2E with live Supabase | ⏸ Ops gate (not blocking client F1 cert) |

---

## Known limitations (F1)

| Item | Owner | Phase |
|------|-------|-------|
| Staging deploy + live OTP SMS | DevOps | Pre real-school |
| `permission_sync_openapi_integration_test` | Skipped without `STAGING_CONTRACT_TESTS=true` | Ops |
| NestJS extraction | Deferred | Post-scale |

---

## Next authorized step

**F2 — Approval API** (do not start without orchestrator authorization).

---

## Test evidence

```
flutter test test/contracts/auth/
flutter test test/integration/auth/f1_auth_rbac_integration_test.dart
flutter test test/security/rbac/f1_api_mode_fail_closed_test.dart
flutter test  → 1956 passed, 1 skipped
```

---

**Certified by:** Agent E + G gate  
**Status:** F1 client certification **PASS** · STOP per orchestrator
