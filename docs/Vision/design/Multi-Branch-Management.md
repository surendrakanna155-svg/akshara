# Design — Multi-Branch Management

**Status:** Future · single school, multiple physical branches

## Goals

One school entity with branches (e.g. Main Campus, East Wing): branch-scoped students, shared finance options, consolidated reporting.

## Architecture

| Concept | Implementation |
|---------|----------------|
| Branch entity | `school_branches` (SRS Part 11B) |
| Tenant context | `branchId` optional on JWT + repositories |
| Branch switcher | Admin header UI |
| Reports | School-wide vs branch filter |

v1.0: Most tables have `school_id`; `branch_id` partial.

## Permissions

| Role | Branch scope |
|------|--------------|
| `schoolAdmin` | All branches |
| `branchAdmin` | Single branch (future role) |
| `teacher` | Assigned branch/classes |

## Data model

- `school_branches` — name, code, address  
- `students.branch_id` — optional FK  
- RLS: `branch_id` match or school-wide admin bypass  

## APIs

- `GET /school/branches`  
- `POST /school/branches`  
- Filters on SIS/finance: `?branchId=`  

## Rollout plan

1. Schema audit — which tables need `branch_id`  
2. RLS policies per table  
3. Flutter `TenantContext.branchId` wiring  
4. Pilot one school, two branches  

## Risks

| Risk | Mitigation |
|------|------------|
| Incomplete branch RLS | Probe expansion per branch |
| UX complexity | Default single-branch schools unchanged |
