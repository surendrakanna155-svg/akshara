# Akshara ERP — Tenant Architecture

**Document ID:** `AKS-TENANT-ARCH-v1.1`  
**Status:** Architecture specification (no implementation)  
**Aligned with:** Client `TenantContext` · `TenantInterceptor` · `RepositoryQuery`  
**Last updated:** June 2026 (v5.6 gap closure)

---

## 1. Overview

Akshara ERP is a **multi-tenant SaaS** where the **organization** is the tenant boundary. Schools operate within organizations. All data access is scoped by tenant context injected server-side.

```
Platform
└── Organization (tenant_id)
    ├── Users (memberships)
    ├── Schools
    │   └── Operational data (admissions, finance, SIS, …)
    └── Organization-level data (CRM, billing, branding)
```

---

## 2. Entity Model

### Organization

| Field | Description |
|-------|-------------|
| `id` | UUID — maps to `TenantContext.tenantId` |
| `name` | Display name |
| `slug` | URL-safe identifier for login/branding |
| `plan` | Subscription tier |
| `status` | active · suspended · trial |
| `settings` | JSONB — feature flags, limits |

### School

| Field | Description |
|-------|-------------|
| `id` | UUID — maps to `TenantContext.schoolId` |
| `organization_id` | FK → organizations |
| `name`, `code` | Identity |
| `settings` | JSONB — academic calendar, modules enabled |

**Note:** Schools do **not** carry `school_group_id`. Group membership is via junction table (§6).

### Branch (optional — Sprint 4+)

| Field | Description |
|-------|-------------|
| `id` | UUID |
| `school_id` | FK → schools |
| `name` | Campus name |

Operational data may include optional `branch_id` where campus-level scoping is required (hostel, transport). Default: school-level only.

### User

| Field | Description |
|-------|-------------|
| `id` | UUID — maps to `TenantContext.userId` |
| `phone` | Primary identifier (E.164) |
| `email` | Optional |
| `profile` | JSONB — name, avatar |

---

## 3. Membership Model

```
users
  ├── organization_memberships (user_id, organization_id, role, status)
  │     └── membership_permissions (overrides)
  ├── school_memberships (user_id, school_id, role, status)
  │     └── membership_permissions (overrides)
  └── school_group_memberships (user_id, school_group_id, role, status)
```

| Membership table | Scope | Roles | Use case |
|------------------|-------|-------|----------|
| `organization_memberships` | Organization | `organizationAdmin`, billing contact | Org settings, CRM, provisioning |
| `school_memberships` | School | `schoolAdmin`, `principal`, `teacher`, … | Day-to-day ERP |
| `school_group_memberships` | School group | `schoolGroupDirector` | Regional/chain dashboards |

A user may hold **multiple membership types simultaneously**. Active JWT scope selects which membership applies.

### Organization Admin membership

| Rule | Detail |
|------|--------|
| Table | `organization_memberships` |
| Role | `organizationAdmin` |
| JWT scope | `organization` |
| `school_id` in JWT | Always `null` |
| School mutations | Requires context switch to school + valid `school_membership` |
| Org ownership | `organizations`, `organization_settings`, `school_groups`, org CRM, billing, white-label |
| Not owned | School operational tables (leads, fees, students) except aggregated read |

### Organization-level ownership boundaries

| Owned by org admin (write) | Owned by school roles (write) | Shared (org read, school write) |
|----------------------------|--------------------------------|----------------------------------|
| Org profile, plan, seats | Admissions, finance, SIS ops | School list, group config |
| School provisioning (create school) | Module operations | Cross-school KPIs |
| CRM, white-label, billing | Inventory, transport, HR | Audit export (org scope) |
| School group CRUD | Fee collection, refunds | Feature flags per school |

**Active context:** JWT carries `scope` + optional `school_id` / `school_group_id`. Switch via `POST /v1/auth/context/switch`.

---

## 4. Tenant Isolation Strategy

### Layer 1: Application middleware

Every request must resolve:

```typescript
// Conceptual — not implemented
interface RequestContext {
  tenantId: string;      // from JWT — never from body
  scope: 'school' | 'organization' | 'school_group' | 'platform';
  schoolId?: string;     // from JWT when scope=school
  schoolGroupId?: string; // from JWT when scope=school_group
  organizationId: string; // same as tenantId
  userId: string;
}
```

Reject requests where body/query tenant ≠ JWT tenant.

### Layer 2: PostgreSQL RLS (Sprint 3)

```sql
-- Session variables set by middleware before query:
SET app.tenant_id = '<uuid>';
SET app.scope = 'school|organization|school_group|platform';
SET app.school_id = '<uuid>';          -- nullable
SET app.school_group_id = '<uuid>';    -- nullable
SET app.user_id = '<uuid>';

-- Policy on every business table:
CREATE POLICY tenant_isolation ON admissions_leads
  USING (tenant_id = current_setting('app.tenant_id')::uuid
         AND (school_id = current_setting('app.school_id')::uuid
              OR current_setting('app.school_id')::uuid IS NULL));
```

### Layer 3: Client headers (defense-in-depth)

Flutter `TenantInterceptor` sends headers matching JWT claims. Server validates headers match JWT; ignores mismatched headers.

---

## 5. Client Alignment

| Client artifact | Server equivalent |
|-----------------|-------------------|
| `TenantContext.tenantId` | `organizations.id` |
| `TenantContext.schoolId` | `schools.id` |
| `TenantContext.organizationId` | `organizations.id` |
| `TenantContext.userId` | `users.id` |
| `X-Tenant-Id` header | JWT `tenant_id` claim |
| `X-School-Id` header | JWT `school_id` claim |
| `RepositoryQuery` | Server query scope |

Demo tenant: `tenant_demo_001` / `school_akshara_001` (mock only; not in production DB).

---

## 6. Multi-School Groups

### Canonical data model

**Decision:** Junction table is canonical. A school may belong to **multiple groups**.

```
organizations
  └── school_groups (id, organization_id, name, description)
        └── school_group_memberships (school_group_id, school_id)  ← canonical
              └── schools
```

| Table | Purpose |
|-------|---------|
| `school_groups` | Group entity under organization |
| `school_group_memberships` | Many-to-many: schools ↔ groups |
| `school_group_memberships (user)` | `school_group_memberships` for users → see §3 |

**Deprecated pattern (do not use):** `schools.school_group_id` FK — removed to avoid single-group limitation.

### Group administration model

| Actor | Can create group | Can assign schools | Can view aggregate KPIs |
|-------|:----------------:|:------------------:|:-----------------------:|
| `organizationAdmin` | ✅ | ✅ | ✅ (all groups) |
| `schoolGroupDirector` | ❌ | ❌ | ✅ (assigned groups only) |
| `schoolAdmin` | ❌ | ❌ | ❌ (school scope only) |

Group directors are assigned via `school_group_memberships (user_id, school_group_id, role=schoolGroupDirector)`.

### RLS approach for school groups

Session variables (set from JWT):

```sql
SET app.tenant_id = '<org_uuid>';
SET app.scope = 'school_group';
SET app.school_group_id = '<group_uuid>';
```

**Policy pattern for aggregate reads:**

```sql
-- Materialized view or subquery: schools in active group
CREATE POLICY group_school_access ON management_kpis
  USING (
    tenant_id = current_setting('app.tenant_id')::uuid
    AND (
      current_setting('app.scope') = 'organization'
      OR (
        current_setting('app.scope') = 'school_group'
        AND school_id IN (
          SELECT school_id FROM school_group_memberships
          WHERE school_group_id = current_setting('app.school_group_id')::uuid
        )
      )
      OR school_id = NULLIF(current_setting('app.school_id', true), '')::uuid
    )
  );
```

Operational tables (leads, fees) remain **school-scoped** even for org admin reads — org admin sees aggregated views, not raw PII, unless explicitly granted.

| Feature | Tenant scope |
|---------|--------------|
| Org dashboard | All schools in org |
| School group dashboard | Schools in group via junction |
| School ERP | Single school |
| Cross-school student transfer | Event between schools in same org |

---

## 6a. Organization Admin (specified)

See §3 for membership and ownership boundaries. Role is **Sprint 3** deliverable, not deferred.

- Role: `organizationAdmin`
- JWT: `scope=organization`, `school_id=null`
- Permissions: see `RBACArchitecture.md` §2a

---

## 7. Future PostgreSQL RLS Support

| Phase | RLS coverage |
|-------|--------------|
| Sprint 3 | Core tables: users, admissions, finance, SIS |
| Sprint 4 | All ERP module tables |
| Sprint 5 | Audit, platform, cross-module |
| Sprint 6 | AI/copilot read-only views with service role |

**Service role bypass:** Platform admin operations use separate service account; never exposed to tenant JWT.

**Testing:** Tenant isolation validation suite (client v4.3) extended with server integration tests in v5.6.

---

## 8. Tenant Lifecycle

| State | Behavior |
|-------|----------|
| Trial | Full features; data retained 30 days post-expiry |
| Active | Normal operation |
| Suspended | Read-only; no mutations |
| Deleted | Soft delete org; 90-day retention then purge |

---

## 9. Future Compatibility

| Product | Tenant implication |
|---------|-------------------|
| School Branding | `organization_settings.branding` |
| White-label | Org slug → custom domain mapping |
| Akshara Business Suite | Org-level CRM; separate schema namespace |
| Renewal Management | Org subscription + school seat counts |
| Communication Hub | Threads scoped to school + org broadcasts |

---

## 10. Implementation Phases

| Sprint | Deliverable |
|--------|-------------|
| Sprint 2 | Organization + school + membership schema |
| Sprint 3 | RLS policies on core modules |
| Sprint 4 | School groups, context switch API |
| Sprint 5 | Tenant lifecycle, suspension |
| Sprint 6 | v5.6 tenant isolation validation |

No tenant code created in Sprint 1.
