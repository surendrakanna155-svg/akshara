# Akshara ERP — Authentication Architecture

**Document ID:** `AKS-AUTH-ARCH-v1.1`  
**Status:** Architecture specification (no implementation)  
**Aligned with:** Client `AuthSessionManager`, JWT decoder, token refresh service  
**Last updated:** June 2026 (v5.6 gap closure)

---

## 1. Overview

Akshara ERP uses **phone-first OTP authentication** with **JWT access tokens** and **rotating refresh tokens**. Architecture supports web ERP, mobile apps, and future SSO — mobile-first by design.

```
┌──────────┐    OTP     ┌─────────────┐   JWT    ┌─────────────┐
│  Client  │ ─────────► │  Identity   │ ───────► │  API Layer  │
│ Flutter  │ ◄───────── │  Service    │ ◄─────── │ PostgREST/  │
└──────────┘  tokens     └─────────────┘          │  Functions  │
                                                   └─────────────┘
```

---

## 2. JWT Access Token Strategy

### Token format

- Algorithm: **RS256** (asymmetric; public key distributed to API layer)
- Lifetime: **15 minutes**
- Storage (client): secure storage (native encrypted — resolved v2.7)

### Required claims

| Claim | Type | Description |
|-------|------|-------------|
| `sub` | UUID | User ID |
| `tenant_id` | UUID | Organization ID |
| `school_id` | UUID? | Active school (null for org-only users) |
| `organization_id` | UUID | Same as tenant_id (explicit for client parity) |
| `role` | string | Maps to client `ErpRole.name` |
| `permissions` | string[] | Resolved permission slugs |
| `permissions_version` | integer | Bumped on role/permission change |
| `scope` | string | **`school` \| `organization` \| `school_group` \| `platform`** |
| `school_group_id` | UUID? | Set when `scope=school_group`; else null |
| `session_id` | UUID | Active session reference |
| `iat`, `exp` | timestamp | Standard JWT |

### Scope model

| Scope | When issued | `school_id` | `school_group_id` | Typical role |
|-------|-------------|-------------|-------------------|--------------|
| `school` | Default for staff/mobile | Required | null | `schoolAdmin`, `teacher`, … |
| `organization` | Org admin login | null | null | `organizationAdmin` |
| `school_group` | Group director login | null | Required | `schoolGroupDirector` |
| `platform` | Akshara internal | null | null | `superAdmin` |

Middleware sets PostgreSQL session vars from scope:

```
app.tenant_id      ← tenant_id
app.school_id      ← school_id (nullable)
app.school_group_id ← school_group_id (nullable)
app.scope          ← scope
```

### Context switch

| Endpoint | Action |
|----------|--------|
| `POST /v1/auth/context/switch` | Body: `{ "scope", "schoolId"?, "schoolGroupId"? }` → new JWT |

Validates user holds membership for target scope before reissue. Audit: `tenantChange`.

### Client validation (existing)

Flutter `JwtDecoder` validates: signature (when key available), expiry, required claims. Server is authoritative; client validation is defense-in-depth.

---

## 3. Refresh Token Rotation

### Flow

1. Client sends refresh token to `POST /v1/auth/refresh`.
2. Server validates refresh token; checks not revoked, not reused.
3. Server issues **new access token + new refresh token**.
4. Old refresh token marked **used** (single-use rotation).
5. If reused refresh token detected → **revoke all sessions** for user (theft detection — client v2.7).

### Refresh token properties

| Property | Value |
|----------|-------|
| Format | Opaque UUID (stored hashed in DB) |
| Lifetime | 30 days (sliding on use) |
| Storage | `refresh_tokens` table: `token_hash`, `user_id`, `session_id`, `used_at`, `revoked_at` |
| Device binding | Optional `device_id` claim |

---

## 4. Session Management

### Session model

```
sessions (
  id UUID PK,
  user_id UUID,
  tenant_id UUID,
  device_type TEXT,       -- web | ios | android
  device_name TEXT,
  ip_address INET,
  user_agent TEXT,
  last_active_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ
)
```

### Operations

| Endpoint | Action | Audit event |
|----------|--------|-------------|
| `POST /v1/auth/otp/send` | Send OTP | — |
| `POST /v1/auth/otp/verify` | Verify OTP; create session | `login` |
| `POST /v1/auth/refresh` | Rotate tokens | `tokenRefresh` |
| `POST /v1/auth/logout` | Revoke current session | `logout` |
| `POST /v1/auth/logout-all` | Revoke all user sessions | `logoutAllSessions` |
| `GET /v1/auth/sessions` | List active sessions | — |
| `DELETE /v1/auth/sessions/:id` | Revoke specific session | `sessionRevoked` |
| `POST /v1/auth/context/switch` | Switch school/org/group scope | `tenantChange` |

---

## 5. Logout-All Support

1. Client calls `POST /v1/auth/logout-all` with valid access token.
2. Server sets `revoked_at` on all active sessions for user.
3. Server invalidates all refresh tokens for user.
4. Server bumps `permissions_version` if role change triggered logout-all.
5. All clients receive 401 on next request; Flutter `onSessionExpired` fires (v4.0).

---

## 6. OTP-Ready Architecture

### OTP flow

```
1. POST /v1/auth/otp/send   { phone, tenant_slug? }
   → Rate limit: 3/min per phone, 10/hr per IP
   → Store hashed OTP in otp_requests (TTL 5 min)
   → Send via SMS provider (MSG91 / Twilio)

2. POST /v1/auth/otp/verify { phone, otp, device_info }
   → Validate OTP (max 3 attempts)
   → Upsert user record
   → Resolve membership (tenant + school + role)
   → Issue access + refresh tokens
   → Emit audit: login
```

### Demo mode (existing client)

Client supports mock OTP for development. Production disables demo auth (`ProductionReadinessChecklist` A9).

### Future SSO

Architecture reserves `auth_providers` table for OAuth2/OIDC (Google Workspace for schools) without changing JWT claim structure.

---

## 7. Mobile-First Authentication

| Concern | Design |
|---------|--------|
| Parent multi-child | JWT includes `child_ids[]`; school context per active child |
| Teacher | Single school; role `teacher`; limited module permissions |
| Student | Single school; role `student`; read-only APIs |
| Token refresh background | Mobile refresh service (client v2.7) mirrors server rotation |
| Biometric unlock | Client-only; reuses stored refresh token |
| Offline | Read cache valid; writes require fresh token |

### Header contract (matches client `ApiConfig`)

```
Authorization: Bearer <access_token>
X-Tenant-Id: <tenant_id>
X-School-Id: <school_id>
X-Organization-Id: <organization_id>
X-Correlation-Id: <uuid>
X-Api-Version: 1
```

---

## 8. Permission Sync on Login/Refresh

On every token issue/refresh:

1. Resolve effective permissions from role + membership overrides.
2. Embed in JWT `permissions` claim.
3. Return `permissions_version` for client cache invalidation.
4. Client `PermissionSyncService` compares version; refetches if stale (v2.7).

---

## 9. Security Controls

| Control | Implementation |
|---------|----------------|
| Rate limiting | Gateway + Redis counters |
| Brute force | OTP lockout after 5 failures / 15 min |
| Token binding | Optional device fingerprint |
| CSRF | Not applicable (Bearer token API) |
| CORS | Strict origin allowlist for web |
| Audit | All auth events to audit pipeline |

---

## 10. Implementation Phases

| Sprint | Deliverable |
|--------|-------------|
| Sprint 2 | OTP send/verify, JWT issue, refresh rotation |
| Sprint 3 | Logout-all, session list, permission sync endpoint |
| Sprint 4 | SSO provider stub, device management |
| Sprint 5 | Production hardening, penetration test |

No auth code created in Sprint 1.
