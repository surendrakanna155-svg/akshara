# Akshara ERP — RBAC Architecture

**Document ID:** `AKS-RBAC-ARCH-v1.1`  
**Status:** Architecture specification (no implementation)  
**Aligned with:** Client `Permission` enum (22 values today; 32 planned) · `ErpRole` · `RolePermissionMatrix`  
**Last updated:** June 2026 (v5.6 gap closure)

---

## 1. Overview

RBAC enforces **least privilege** at three layers:

1. **Server middleware** — authoritative; every API request checked
2. **PostgreSQL RLS** — row-level tenant/school isolation
3. **Client guards** — UX-only; hides unauthorized actions (v5.3 complete)

Server enforcement resolves **TD-P0-01**.

---

## 2. Roles

Maps 1:1 to client `ErpRole`:

| Role | Scope | Primary surface |
|------|-------|-----------------|
| `superAdmin` | Platform | Control Center |
| `schoolAdmin` | School | Full ERP |
| `principal` | School | Management, admissions approval |
| `management` | School | Management module |
| `financeAdmin` | School | Finance |
| `admissionsCounselor` | School | Admissions |
| `teacher` | School | Teacher mobile |
| `parent` | School | Parent mobile |
| `student` | School | Student mobile |
| `transportManager` | School | Transport |
| `hostelManager` | School | Hostel |
| `librarian` | School | Library |
| `inventoryManager` | School | Inventory |

### Extended roles (Sprint 3–4)

| Role | Scope | Primary surface | Client enum |
|------|-------|-----------------|-------------|
| `organizationAdmin` | Organization | Org dashboard, CRM, billing, school provisioning | **Add v6.1** |
| `schoolGroupDirector` | School group | Group KPI dashboard, cross-school reports | **Add v6.2** |
| `platformSupport` | Platform | Internal Akshara support (read-only) | **Add v6.4** |

`superAdmin` remains platform-scoped via Control Center; distinct from `organizationAdmin` (tenant-scoped).

---

## 2a. Organization Admin — Permission Matrix

**Role:** `organizationAdmin`  
**JWT scope:** `organization` (see `AuthArchitecture.md`)  
**Membership:** `organization_memberships` only (no active `school_id`)

| Permission | Granted | Ownership boundary |
|------------|:-------:|-------------------|
| `viewOrganization` | ✅ | Org profile, plan, seat usage |
| `manageOrganization` | ✅ | Org settings, branding, feature flags |
| `viewSchoolGroups` | ✅ | List groups and member schools |
| `manageSchoolGroups` | ✅ | Create/edit groups; assign schools |
| `viewControlCenter` | ✅ | Org-scoped control center (not platform) |
| `manageControlCenter` | ✅ | CRM, white-label, org billing |
| `viewManagement` | ✅ | Cross-school aggregated KPIs (read) |
| `viewAdminHub` | ✅ | Org-level admin navigation |
| `viewAdmissions` … `viewAlumni` | ✅ (view only) | Cross-school read via org RLS |
| All `manage*` / `approve*` | ❌ | School operations require school context switch |

**Write boundaries:** Org admin may **not** mutate school operational data (leads, fees, enrollments) without switching to a school context and holding a school role with `manage*`.

**vs `superAdmin`:** `superAdmin` has all permissions at platform scope; `organizationAdmin` is tenant-scoped with no school mutations by default.

---

## 2b. School Group Director — Permission Matrix

**Role:** `schoolGroupDirector`  
**JWT scope:** `school_group`  
**Membership:** `school_group_memberships` (user ↔ group)

| Permission | Granted |
|------------|:-------:|
| `viewSchoolGroups` | ✅ |
| `viewManagement` | ✅ |
| All module `view*` for schools in group | ✅ |
| All `manage*` / `approve*` | ❌ (read-only aggregate role) |

Group director may drill into a member school only if they also hold a `school_membership` for that school.

---

## 3. Permissions

### Current client permissions (22)


| Module | View | Manage | Approve |
|--------|------|--------|---------|
| Admissions | `viewAdmissions` | `manageAdmissions` | `approveAdmissions` |
| Finance | `viewFinance` | `manageFinance` | `approveRefunds` |
| SIS | `viewSis` | `manageSis` | — |
| Management | `viewManagement` | `manageManagement` | — |
| Transport | `viewTransport` | `manageTransport` | — |
| HR | `viewHr` | `manageHr` | — |
| Hostel | `viewHostel` | `manageHostel` | — |
| Library | `viewLibrary` | `manageLibrary` | — |
| Inventory | `viewInventory` | `manageInventory` | — |
| Alumni | `viewAlumni` | `manageAlumni` | — |
| Control Center | `viewControlCenter` | `manageControlCenter` | — |
| Admin Hub | `viewAdminHub` | — | — |

### Planned permissions (10 — add with backend sprints)

| Module / domain | View | Manage | Approve | Client sprint |
|-----------------|------|--------|---------|---------------|
| Organization | `viewOrganization` | `manageOrganization` | — | v6.1 |
| School groups | `viewSchoolGroups` | `manageSchoolGroups` | — | v6.2 |
| Communications | `viewCommunications` | `manageCommunications` | — | v7.1 |
| Broadcasts | — | `sendBroadcast` | — | v7.1 |
| Payments | `viewPayments` | `managePayments` | `approvePayments` | v7.0 |

**Total planned:** 32 permissions. See `docs/ClientBackendAlignment.md`.

---

## 4. Permission Groups

Logical groupings for role assignment UI:

| Group | Permissions |
|-------|-------------|
| `admissions_full` | view + manage + approve admissions |
| `finance_operations` | view + manage finance |
| `finance_approvals` | approveRefunds |
| `sis_operations` | view + manage SIS |
| `operations_modules` | view + manage for transport/hr/hostel/library/inventory |
| `platform_admin` | view + manage control center |
| `org_admin` | viewOrganization + manageOrganization + viewSchoolGroups + manageSchoolGroups + viewControlCenter + manageControlCenter + all view* |
| `group_director` | viewSchoolGroups + viewManagement + view* (schools in group) |

Groups stored in `permission_groups` + `permission_group_items` for admin UI; resolved to flat permission set at token issue.

---

## 5. Role Versioning

```
role_definitions (id, name, version, is_system)
role_permissions (role_id, permission_slug, version)
membership_permissions (membership_id, permission_slug, granted, version)
```

| Mechanism | Behavior |
|-----------|----------|
| `permissions_version` in JWT | Integer; incremented on any role/permission change |
| Client cache | Invalidates when JWT version ≠ cached version |
| Server check | Middleware validates permission against current DB state (not JWT alone for mutations) |
| Audit | `roleChange`, `permissionSync`, `permissionDenied` events |

---

## 6. Server-Side Enforcement

### Middleware stack

```
Request → JWT verify → Extract tenant context → Permission check → RLS context set → Handler
```

### Permission check rules

| Operation type | Required permission | Example |
|----------------|---------------------|---------|
| GET list/detail | `view{Module}` | `viewAdmissions` |
| POST/PUT/PATCH create/update | `manage{Module}` | `manageFinance` |
| Approve/reject workflow | `approve{Module}` | `approveAdmissions` |

### Denied access

- HTTP **403 Forbidden**
- Body: `{ "error": { "code": "PERMISSION_DENIED", "permission": "manageFinance" } }`
- Audit event: `permissionDenied` with correlation ID
- Client: `ManagePermissionGuard` already hides button; server is authoritative

### Mutation registry alignment

Client `MutationPermissionRegistry` (9 entries) defines provider-level mutations. Server enforces matching permissions on corresponding endpoints.

---

## 7. Approval Workflow Architecture

```
┌─────────────┐     submit      ┌─────────────┐
│  Operator   │ ──────────────► │   Pending   │
│ (manage*)   │                 │   Queue     │
└─────────────┘                 └──────┬──────┘
                                       │ approve/reject
                                       ▼
                                ┌─────────────┐
                                │  Approver   │
                                │ (approve*)  │
                                └─────────────┘
```

| Workflow | Manage permission | Approve permission |
|----------|-------------------|---------------------|
| Admission approval | `manageAdmissions` | `approveAdmissions` |
| Document verification | `manageAdmissions` | `approveAdmissions` |
| Refund approval | `manageFinance` | `approveRefunds` |
| Fee handoff | `manageAdmissions` | — (auto on submit) |

**State machine:** Stored in entity `status` column; transitions validated server-side; audit on each transition.

---

## 8. Multi-School RBAC

| Scenario | JWT scope | `school_id` | Permission source |
|----------|-----------|-------------|-------------------|
| Single-school staff | `school` | Set | `school_memberships` role |
| Multi-school staff | `school` | Active school (switched) | `school_memberships` for active school |
| Organization admin | `organization` | `null` | `organization_memberships` → org permission matrix (§2a) |
| School group director | `school_group` | `null` | `school_group_memberships` → group matrix (§2b) |
| Platform super admin | `platform` | `null` | All permissions |

**Context switch:** `POST /v1/auth/context/switch` reissues JWT with new `scope`, `school_id`, or `school_group_id`. Emits audit `tenantChange`.

**Cross-school reports:** Org scope + `viewManagement`; group scope + `viewManagement` filtered to group schools via RLS.

---

## 9. Future Product RBAC Extensions

| Future product | RBAC extension | Sprint |
|----------------|----------------|--------|
| Communication Hub | `viewCommunications`, `manageCommunications`, `sendBroadcast` | v7.1 |
| Universal Payment Engine | `viewPayments`, `managePayments`, `approvePayments` | v7.0 |
| Copilot services | Service account role; read-scoped permissions | v7.2 |
| CRM / Business Suite | Subset of `manageControlCenter` | v7.5 |

Permission enum extensible via DB `permission_definitions`; client enum synced per `ClientBackendAlignment.md`.

---

## 10. Implementation Phases

| Sprint | Deliverable |
|--------|-------------|
| Sprint 2 | Permission tables, role seed (22 client permissions) |
| Sprint 3 | Middleware enforcement; `organizationAdmin` role + org permissions |
| Sprint 4 | School group roles; `schoolGroupDirector`; context switch |
| Sprint 5 | Approval workflows; permission sync endpoint |
| Sprint 6 | RBAC validation suite vs Flutter tests |

No RBAC code created in Sprint 1.
