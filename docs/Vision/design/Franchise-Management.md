# Design — Franchise Management

**Status:** Future · organization-level multi-school chains

## Goals

Franchisor oversees many school branches: standards, royalties, aggregate KPIs, template rollout.

## Architecture

| Feature | Description |
|---------|-------------|
| Org hierarchy | `organizations` → many `schools` (exists) |
| Director dashboard | Aggregate KPIs without student PII (Control Center) |
| Template push | Fee structures, comm templates, academic year calendar |
| Royalty / billing | Platform billing per school (SaaS addendum) |

v1.0: `organizationAdmin` + multiple schools via manual provision.

## Permissions

| Role | Scope |
|------|-------|
| `organizationAdmin` | All schools in franchise |
| `director` | Read aggregates, drill to school |
| `schoolAdmin` | Single branch |

## Data model

- `organization_school_links` (implicit via `schools.organization_id`)  
- Future: `franchise_fee_rules`, `template_packs`  

## APIs

- `GET /organization/dashboard` — cross-school aggregates  
- `POST /organization/templates/push` — propagate config  

## Rollout plan

1. v1.0 — 2 schools same org (isolation probes)  
2. Director read-only dashboard  
3. Template push MVP  
4. Royalty billing integration  

## Risks

| Risk | Mitigation |
|------|------------|
| PII in aggregate views | Counts and percentages only |
| Template overwrite | Confirm per school; audit |
