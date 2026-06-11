# Design — Multi-School SaaS Operations

**Status:** Future · v1.0 = limited pilot (1+ schools, manual provision)

## Goals

- Operate 10–1000 schools on shared infrastructure  
- Self-service school add (replace SQL provisioning)  
- Per-school billing, health score, support isolation  

## Architecture

| Component | Description |
|-----------|-------------|
| Control Center | ACC screens (schools registry, onboarding wizard) |
| Provisioning saga | `create_school` job type |
| Per-school config | Feature flags, plan tier, integrations |
| Ops runbooks | Per-school PILOT tracker, validation scripts |

v1.0: [`Real-School-Onboarding-Guide.md`](../../Operations/guides/Real-School-Onboarding-Guide.md) Phase 1 manual.

## Permissions

| Role | Scope |
|------|-------|
| `organizationAdmin` | All schools in org |
| `platformAdmin` | Cross-org (Control Center) |
| `schoolAdmin` | Single school |

## Data model

Existing: `organizations`, `schools`, `school_memberships`. Future: `school_subscriptions`, `school_health_scores`.

## APIs

- `POST /platform/schools` — provision (future)  
- `GET /platform/schools` — registry  
- `GET /health/tenant-access` — per-school probe expansion  

## Rollout plan

1. v1.0 — manual SQL provision + documented UUID handoff  
2. v1.1 — scripted provision CLI  
3. v2.0 — Control Center wizard + saga  

## Risks

| Risk | Mitigation |
|------|------------|
| Noisy neighbor | Rate limits per school; connection pooling |
| Cross-school leak | 213+ probes in CI |
