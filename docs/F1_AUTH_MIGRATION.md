# F1 Auth + RBAC — Migration & Rollback

**Phase:** F1 (Production Backend Program)  
**Scope:** Authentication, JWT, tenant claims, RBAC permission sync  
**Stack:** Supabase Auth + Edge Functions + Flutter `ApiAuthRepository`

---

## Cutover checklist

| Step | Action |
|------|--------|
| 1 | Provision school tenant + users on staging Supabase |
| 2 | Deploy Edge `api` function with auth handlers |
| 3 | Build Flutter with `--dart-define=ENABLE_API_MODE=true` |
| 4 | Optional: `--dart-define=DISABLE_DEMO_AUTH=true` for production school flavor |
| 5 | Verify OTP login on staging for staff, parent, teacher personas |
| 6 | Confirm `GET /auth/permissions` returns permission slugs matching `Permission` enum names |
| 7 | Run `flutter test test/integration/auth/f1_auth_rbac_integration_test.dart` against fake Dio (CI) |
| 8 | Run staging integration (`test/integration/auth_staging_integration_test.dart`) when credentials available |

## Feature flags

| Flag | Default (API mode on) | Effect |
|------|----------------------|--------|
| `ENABLE_API_MODE` | `false` in QA builds | Master API switch |
| `AUTH_API_ENABLED` | `true` when API mode on | Selects `ApiAuthRepository` |
| `DISABLE_DEMO_AUTH` | `false` | Blocks mock OTP; requires API auth |

## Client behavior

| Mode | Auth repository | Permissions source |
|------|-----------------|-------------------|
| Demo (`ENABLE_API_MODE=false`) | `MockAuthRepository` | `UserPermissions.forRole()` |
| API (`ENABLE_API_MODE=true`) | `ApiAuthRepository` | Server snapshot via `fetchPermissionPolicy` |
| API + sync failure | `ApiAuthRepository` | **Fail-closed** — empty permission set |

## Rollback

1. Set `ENABLE_API_MODE=false` (or `AUTH_API_ENABLED=false`) in tenant build config  
2. App reverts to `MockAuthRepository` — **UAT/demo only**  
3. Server sessions remain valid; no server data deletion  
4. Re-enable API mode after staging fix without app store release (if flags are build-time, ship hotfix build)

## Data migration

No client auth data migration required. Users re-authenticate via OTP on first API-mode launch.

---

**See also:** `docs/PHASE_F1_FINAL_CERTIFICATION.md`, `docs/PRODUCTION_BACKEND_ROADMAP.md` F1.
