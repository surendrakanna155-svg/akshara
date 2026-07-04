# Akshara ERP — Security & RBAC Audit

**Auditor:** Fable (independent, authorized defensive review of the team's own codebase) · **Date:** 2026-07-03 · **HEAD:** `68f15cb`
**Scope:** authentication, authorization/RBAC, secrets, client-side security, tenant-scope trust, audit.
**Confidence:** High.

---

## 1. Executive summary

1. **Authentication is sound.** OTP-only, server-verified: OTP stored SHA-256-hashed, expiry + max-attempts + one-time consume; JWT HS256 via `jose`, minted only after OTP **and** an active membership resolve. **No backend backdoor exists** — the only auth routes are 10 OTP endpoints (`app.ts:278-295`).
2. **The QA/demo persona logins are client-only and correctly gated out of production.** They mint fake non-JWT tokens (`demo_access_*`) that the backend rejects, and `enableQaLogin` can only be true when the resolved env ≠ production — a guard a `--dart-define` cannot override.
3. **No real secrets are committed.** Git-tracked `.env` files are all `.example`; the only real key is the Firebase Android client key (a public identifier by design). `config.ts` is **fail-closed** — it throws if `JWT_SECRET`(<32ch)/`SUPABASE_URL`/`SERVICE_ROLE_KEY` are unset; no default secrets exist.
4. **RBAC is enforced server-side** at a permission-gate the handlers call, plus a **single denied-audit choke point** (`app.ts:303-313`) that records every 403 once centrally. The QW4 audit found and fixed a systemic OR→AND RBAC inversion across 29 sites — a real risk, now closed.
5. **The biggest real security risks are build/release discipline, not runtime backdoors.** A release built without the live-config dart-defines defaults to `development` (demo auth + mock OTP `654321`→superAdmin + cleartext localhost); a missing `key.properties` silently ships a debug-key-signed APK.
6. **PII is written to plaintext SharedPreferences** — parent phone, display name, child name/class, and the claims blob — outside secure storage. (Tokens are *not* in this blob; they live in the keychain.)
7. **RBAC-mapping correctness and session-revocation are NOT proven by the test suite** (see QA-integrity audit): the 503-pattern injects permissions into the test JWT and short-circuits the session-check DB path.

---

## 2. Findings

| ID | Sev | Finding | Evidence | Recommendation |
|---|---|---|---|---|
| SEC-1 | **P1** | Release hardening is opt-in; default env is `development` → a mis-built `--release` enables demo auth + mock OTP `654321`→superAdmin + cleartext localhost | `environment.dart:81` (default `development`), `:114-124`; `mock_auth_repository.dart:11` | Add a compile-time guard: a `kReleaseMode` build must fail-closed unless `APP_ENV==production`. Bake defines into Gradle/xcconfig so they can't be omitted. |
| SEC-2 | **P1** | Debug-signing fallback for `--release`: missing `key.properties` silently ships a debug-key-signed (re-signable) APK | `android/app/build.gradle.kts` (release→debug signing fallback) | Fail the release build when no release keystore is present. |
| SEC-3 | **P1** | PII (parent phone, display name, child name/class, claims) persisted to plaintext `SharedPreferences` | `auth_session_storage.dart:185-213` | Persist the session snapshot through the encrypted `SecureStorageBackend`, or drop phone/child fields from the on-device snapshot. |
| SEC-4 | **P1** | RBAC role→permission mapping correctness + session revocation/logout-takes-effect are unproven (contract tests bypass both) | `session_validation.ts:96-99`; QA-integrity audit §3 | Run the live cert to cover session-revoke + the real role→permission derivation on a live DB. |
| SEC-5 | **P2** | No TLS certificate pinning (tokens + student PII in transit rely on platform TLS only) | no pinning in `lib/`; `dio_client.dart` | Add SPKI pinning via a Dio adapter allowlist (never `=>true`) or Android `network_security_config`. |
| SEC-6 | **P2** | 154 handlers leak raw `error.message` to clients (info disclosure) | `auth_handlers.ts:316,460,614`; +151 | Fixed non-leaking 5xx messages; detail in server logs only. |
| SEC-7 | **P2** | Cross-tenant `SECURITY DEFINER` DB functions trust caller args (see DB audit DB-4) | `subscription_assignment_secdef.sql:18` | Assert actor authority inside the function. |
| SEC-8 | **P2** | No root/jailbreak detection; no biometric app-lock despite sensitive PII | `biometric_authenticator.dart` (attendance only) | Add lightweight root signals + optional biometric app-lock on resume. |
| SEC-9 | **P2** | Mock-auth (`654321`) + QA persona code ships inside the release binary (unreachable when correctly built, but present) | `mock_auth_repository.dart`, `qa_login_screen.dart` | Exclude via conditional imports / build flavor. |
| SEC-10 | **P3** | `ENABLE_DEMO_AUTH=true` dart-define is not production-guarded (client-only fake tokens; no backend data) | `environment.dart:114-116` | Add the `!= production` guard used at line 118. |
| SEC-11 | **P3** | 4 bulk endpoints iterate request arrays uncapped (DoS) — see Engineering ENG-8 | `education_handlers.ts:244` etc. | Cap array length pre-loop. |

---

## 3. Server-side RBAC coverage

- Authorization is enforced in the handler layer (`requirePermission`/`requireAnyPermission`) at **615 `authenticateRequest` sites**; 0 handlers were found doing DB access without a guard. But it is **convention, not structure** — no framework-level forced auth choke point (Engineering ENG-5). A future handler that forgets the gate would not be caught.
- Denied access is audited once at a central choke point — good design.
- **Caveat:** coverage is proven by the 503-contract pattern, which proves *a gate is called* but not that the *role→permission mapping* behind it is correct (permissions are injected into the test JWT). The real mapping is exercised only by the Flutter `RolePermissionMatrix` tests (client-side) and the never-run live cert.

## 4. Tenant-scope trust

Tenant scope (`organization_id`/`school_id`) is derived **server-side from the JWT + `set_request_context`**, not accepted from the request body — the correct posture. Combined with the non-bypass `erp_tenant` RLS role (DB audit), cross-tenant reads/writes are blocked at the database. **The residual risks are (a) the deploy-time invariant that edge fns use `erp_tenant` not `service_role` (DB-2), and (b) the never-executed cross-tenant isolation probes (QA-2).**

## 5. Secrets scan

**Clean.** No committed JWT/Supabase/service-role/Razorpay/Maps keys; all `sk-*`/service-role strings are test fixtures or `Deno.env.get(...)`. `config.ts` is fail-closed. The only key-shaped committed value is the Firebase Android client key (public by design — apply Google Cloud API-key app restrictions as hardening).

## 6. Genuine strengths

- OTP-only, fully server-verified auth with no backdoor; fail-closed config; production-hardened env profile.
- Server-derived tenant scope + non-bypass RLS role — a genuinely strong multi-tenant posture.
- Single denied-audit choke point; the QW4 RBAC-inversion fix shows the review process works.
- Encryption-at-rest done correctly for tokens (keychain) and offline data (SQLCipher, keystore-held key, wiped on logout).

## 7. Unknowns

- Whether the live VPS env is correctly hardened (SEC-1 depends on build discipline off-repo).
- Whether session-revocation actually takes effect live (SEC-4 — never tested end-to-end).
- Live secret hygiene on the VPS (`.env` contents not visible from here).
