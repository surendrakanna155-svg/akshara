# Design — Universal Employee System

**Status:** Architecture only — not implemented  
**Target industries:** School · Salon · Hospital · Restaurant  
**Depends on:** v9.6 Employee Platform, v9.9 Employee Intelligence, RBAC registry, Organization Builder v2

---

## Goals

- Single employee model supports multi-role staff across all vertical packs
- Role assignments decouple identity from permission bundles
- Workload and performance signals unified (extends Employee Intelligence)
- Bi-directional sync with legacy membership tables during education migration

---

## Problem Statement

v9.6 introduced `employees` + `employee_role_assignments` projecting from `school_memberships`. v9.9 added intelligence snapshots. Gaps for multi-industry:

- Employee ↔ membership role sync is one-directional (documented v10.4 deferral)
- Role semantics are school-centric (`teacher`, `principal`) — salon/hospital/restaurant need pack-specific roles
- No org-level employee rollup for franchise/multi-branch operators

---

## Universal Employee Model

```
┌──────────────┐     ┌─────────────────────┐     ┌──────────────────┐
│ auth.users   │────▶│ employees           │────▶│ role_assignments │
│ (identity)   │     │ (tenant-scoped HR)  │     │ (pack + branch)  │
└──────────────┘     └─────────────────────┘     └────────┬─────────┘
                                                           │
                              ┌────────────────────────────▼────────────┐
                              │ RBAC permission bundles (per assignment) │
                              └─────────────────────────────────────────┘
```

| Entity | Purpose |
|--------|---------|
| `employees` | Core HR record: name, contact, employment status, branch |
| `employee_role_assignments` | Many-to-many: employee ↔ role ↔ branch ↔ date range |
| `employee_intelligence_snapshots` | Workload, burnout risk, performance signals (v9.9) |
| `membership_projection` | Legacy bridge for education `school_memberships` sync |

---

## Vertical Role Maps

| School | Salon | Hospital | Restaurant |
|--------|-------|----------|------------|
| Teacher | Stylist | Doctor | Server |
| Principal | Salon manager | Department head | Floor manager |
| Admin staff | Receptionist | Nurse | Host |
| Finance clerk | Retail associate | Billing clerk | Cashier |
| Transport staff | — | Lab technician | Kitchen staff |

Each pack defines a **role catalog** mapping to permission bundles in the RBAC registry. Organization Builder selects enabled roles from the catalog.

---

## Multi-Role Support

One employee may hold concurrent assignments:

- School: teacher + transport coordinator
- Salon: stylist + retail associate
- Hospital: doctor + department admin
- Restaurant: server + shift lead

Effective permissions = union of active assignment bundles, scoped to branch. Conflicts resolved by most restrictive write permission.

---

## Architecture

| Layer | Responsibility |
|-------|----------------|
| Employee service | CRUD, assignment lifecycle, branch scope |
| Role sync job | Bi-directional `employees` ↔ `school_membership_roles` (education) |
| Intelligence engine | Snapshot compute on assignment/timetable change |
| Pack role registry | Vertical-specific role definitions + default permissions |
| Org rollup API | Aggregate headcount, workload across branches (franchise track) |

---

## Permissions

| Role | Capability |
|------|------------|
| `viewEmployee` | Read employee list + 360 |
| `manageEmployee` | Create/update employees + assignments |
| `viewEmployeeIntelligence` | Dashboard + snapshots |
| `manageEmployeeIntelligence` | Trigger snapshot recompute |
| `organizationAdmin` | Cross-branch employee view |

Existing Phase 4/5 permission slugs extend — no breaking changes to education deployments.

---

## Data Model Extensions (conceptual)

| Entity | Purpose |
|--------|---------|
| `vertical_role_catalog` | Pack → role slug → permission bundle IDs |
| `employee_sync_jobs` | Background sync queue for membership projection |
| `employee_branch_assignments` | Explicit branch scope when org has multiple locations |

---

## APIs (conceptual)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/employees` | List (branch-filtered) |
| GET | `/employees/:id/360` | Profile + roles + intelligence |
| POST | `/employees/:id/roles` | Assign role |
| DELETE | `/employees/:id/roles/:assignmentId` | End assignment |
| GET | `/employees/intelligence/dashboard` | Principal/manager dashboard |
| POST | `/employees/sync/memberships` | Trigger bi-directional sync (admin) |

---

## Intelligence Signals (extends v9.9)

| Signal | School | Salon | Hospital | Restaurant |
|--------|--------|-------|----------|------------|
| Workload | Classes/week | Appointments/day | Patients/day | Covers/shift |
| Burnout risk | Timetable overload | Back-to-back bookings | On-call hours | Double shifts |
| Performance | Student outcomes | Client retention | Patient feedback | Ticket time |

Snapshots computed on schedule + on assignment change event.

---

## Rollout Plan

1. Complete bi-directional membership sync (education pilot)
2. Extract `vertical_role_catalog` schema
3. Salon role pack — stylist, manager, reception
4. Organization Builder emits role assignments on provision
5. Hospital + Restaurant catalogs
6. Org-level rollup for franchise track

---

## Risks

| Risk | Mitigation |
|------|------------|
| Permission union conflicts | Explicit conflict matrix; audit on elevation |
| Sync drift between employees and memberships | Reconciliation job + alert |
| Role catalog sprawl | Pack-owned catalogs; platform approval for new roles |
| Intelligence false positives | Human override flag; principal/manager review queue |
| Cross-branch data leakage | Branch scope on every query; RLS enforced |

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [Universal-Organization-Builder-v2.md](./Universal-Organization-Builder-v2.md) | Role selection at provision time |
| [Dynamic-Widget-Platform.md](./Dynamic-Widget-Platform.md) | Employee intel widgets |
| [Universal-Workflow-Engine.md](./Universal-Workflow-Engine.md) | Leave/approval workflows |
| [FutureTracks-Index.md](./FutureTracks-Index.md) | Design index |
