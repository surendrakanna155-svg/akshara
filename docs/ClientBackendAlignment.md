# Akshara ERP — Client/Backend Alignment

**Document ID:** `AKS-ALIGN-v1.0`  
**Status:** Architecture specification (no client changes in v5.6)  
**Parent:** v5.6 Backend Architecture Foundation  
**Last updated:** June 2026

---

## 1. Purpose

Eliminate client/backend inconsistencies identified in the v5.6 gap review. Documents **required future Flutter enum additions** and the **implementation dependency graph** for backend Sprints 2–6 and v7.x phases.

---

## 2. Role Alignment

| Backend role | Client `ErpRole` today | Action required |
|--------------|------------------------|-----------------|
| `superAdmin` | ✅ exists | None |
| `schoolAdmin` | ✅ exists | None |
| `principal` | ✅ exists | None |
| `organizationAdmin` | ❌ missing | **Add in v6.1** (Sprint 3) |
| `schoolGroupDirector` | ❌ missing | **Add in v6.2** (Sprint 4) |
| `platformSupport` | ❌ missing | **Add in v6.4** (internal only) |

**Resolution:** Backend JWT may issue `organizationAdmin` before client enum update; client treats unknown roles as zero permissions until enum synced. Client enum update is **mandatory before org-admin UI ships**.

---

## 3. Permission Alignment

### Current client (22 permissions)

All existing `Permission` enum values map 1:1 to backend `permission_definitions.slug`.

### Required future Flutter additions

| Permission | Scope | Introduced with | Backend sprint |
|------------|-------|-----------------|----------------|
| `viewOrganization` | Organization | Org admin UI | Sprint 3 (v6.1) |
| `manageOrganization` | Organization | Org settings, billing | Sprint 3 |
| `viewSchoolGroups` | Organization | Group dashboards | Sprint 4 (v6.2) |
| `manageSchoolGroups` | Organization | Group CRUD | Sprint 4 |
| `viewCommunications` | School/org | Communication Hub read | Sprint 5 foundation |
| `manageCommunications` | School/org | Thread moderation | v7.1 |
| `sendBroadcast` | School/org | Org/school broadcasts | v7.1 |
| `viewPayments` | School | Payment Engine read | v7.0 |
| `managePayments` | School | Payment requests | v7.0 |
| `approvePayments` | School | Payment approval | v7.0 |

**Client files to update (future — not v5.6):**

- `lib/core/security/permissions.dart`
- `lib/core/security/erp_role.dart`
- `lib/core/security/role_permissions.dart`
- `lib/router/route_guards.dart` (if new route prefixes)

---

## 4. JWT Claim Alignment

| Claim | Client today | Backend v1.1 |
|-------|--------------|--------------|
| `tenant_id` | Via JWT decoder | ✅ Required |
| `school_id` | ✅ | ✅ Nullable for org scope |
| `organization_id` | ✅ | ✅ |
| `scope` | ❌ not parsed | **Add to JwtDecoder in v6.1** |
| `school_group_id` | ❌ not parsed | **Add in v6.2** |
| `permissions_version` | ✅ | ✅ |

### Scope enum (backend → client)

```dart
// Future — lib/core/auth/jwt_scope.dart
enum JwtScope { school, organization, schoolGroup, platform }
```

---

## 5. Audit Event Alignment

| Domain | Client `AuditEventType` today | Backend-only (Sprint 5+) | Future client add |
|--------|------------------------------|----------------------------|-------------------|
| Auth/workflow | 24 types | ✅ aligned | — |
| Communication | — | `messageSent`, `broadcastSent` | v7.1 |
| Payments | — | `paymentRequested`, `paymentCaptured`, `paymentFailed` | v7.0 |
| Inventory-Finance | — | `procurementFinancePosted`, `vendorSynced` | v7.2 |
| Cross-module | — | `domainEventPublished` | v7.2 |

Server accepts client types today; new types added to client enum when corresponding UI ships.

---

## 6. Dependency Graph

```
Sprint 2 (v6.0) ──► org/school/user schema
        │
        ▼
Sprint 3 (v6.1) ──► RBAC + RLS + org admin role + scope claim
        │              └──► Client: ErpRole.organizationAdmin, JwtScope
        ▼
Sprint 4 (v6.2) ──► school groups + schoolGroupDirector
        │              └──► Client: school group enums, school_group_id claim
        ▼
Sprint 5 (v6.3) ──► audit ingestion + domain event bus (outbox)
        │
        ▼
Sprint 6 (v6.4) ──► pilot validation
        │
        ├──► v7.0 Payment Engine ──► Client: payment permissions + audit types
        ├──► v7.1 Communication Hub ──► Client: communication permissions
        └──► v7.2 Inventory-Finance ──► Client: cross-module audit types
```

**Hard dependencies:**

- Organization Admin UI → Sprint 3 RBAC + client enum v6.1
- School group dashboards → Sprint 4 schema + client enum v6.2
- Payment Engine → Sprint 4 Finance API + event bus (Sprint 5)
- Communication Hub → Notification service (Sprint 5) + v7.1 messaging
- Inventory-Finance → Sprint 4 Inventory + Finance APIs + event bus (Sprint 5)

---

## 7. Inconsistencies Resolved (v5.6 gap closure)

| Gap | Resolution |
|-----|------------|
| Org admin marked "future" | Fully specified in RBAC + Tenant + Auth docs |
| `viewManagement` vs `organizationAdmin` | Org admin uses dedicated role + org permissions |
| Dual school group models | Junction table canonical; see `DatabaseArchitecture.md` §3 |
| JWT `scope` missing from Auth doc | Added to `AuthArchitecture.md` §2 |
| Communication Hub one-liner | Full spec in `BackendArchitecture.md` §11 |
| Payment Engine table names only | Full lifecycle in `BackendArchitecture.md` §12 |
| Inventory-Finance one line | Full event model in `BackendArchitecture.md` §13 |
| No event bus architecture | `BackendArchitecture.md` §10 |

---

## 8. Non-Goals

No Flutter code changes in v5.6 gap closure. This document is the checklist for v6.x client sync sprints.
