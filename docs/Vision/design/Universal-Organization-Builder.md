# Design — Universal Organization Builder

**Status:** Future · not implemented  
**Depends on:** Auth, tenant model, onboarding patterns (v1.0)

## Goals

- Single flow to provision any vertical (school, salon, hospital, etc.)
- AI-guided interview → declarative org configuration
- Reduce time-to-first-value from days (manual SQL) to minutes

## Architecture

| Layer | Responsibility |
|-------|----------------|
| Interview service | Collect answers; validate; persist draft config |
| Vertical templates | Packaged module + role + widget presets per industry |
| Provisioning saga | Async: org → school/branch → roles → seed data → go-live |
| Config store | `organization_profiles.config` JSON (versioned) |

Reuse v7.15 onboarding for **people import** after structure exists.

## Permissions

| Role | Capability |
|------|------------|
| `platformAdmin` | All templates, impersonation (audited) |
| `organizationAdmin` | Run builder for own org |
| `schoolAdmin` | Post-provision catalog + imports only |

## Data model (conceptual)

- `organization_profiles` — vertical type, interview answers, enabled modules  
- `provisioning_jobs` — saga steps (exists in SaaS addendum design)  
- `widget_layouts` — dashboard graph per role  
- No new tables in v1.0

## APIs (conceptual)

- `POST /platform/org-builder/interview` — submit step  
- `POST /platform/org-builder/preview` — generated config  
- `POST /platform/org-builder/provision` — start saga  
- `GET /platform/provisioning-jobs/:id` — status  

## Rollout plan

1. Document education template from v1.0 manual steps  
2. Extract declarative education pack  
3. Pilot builder on staging with education only  
4. Second vertical after education GA  

## Risks

| Risk | Mitigation |
|------|------------|
| Over-customization | Template bounds; no arbitrary schema |
| AI hallucination in config | Human review step before provision |
| Saga partial failure | Compensating transactions; PILOT-style tracker |
