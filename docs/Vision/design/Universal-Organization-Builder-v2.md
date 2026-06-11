# Design — Universal Organization Builder v2

**Status:** Architecture only — not implemented  
**Version:** 2.0 (extends [Universal-Organization-Builder.md](./Universal-Organization-Builder.md))  
**Target industries:** School · Salon · Hospital · Restaurant  
**Depends on:** Auth, tenant model, RBAC registry, v7.15 onboarding, Phase 5 composition patterns

---

## Goals

- Single AI-guided interview flow provisions any supported vertical in minutes
- Declarative org configuration replaces manual SQL provisioning
- Vertical packs share kernel services (auth, payments, communication, analytics, audit)
- Human review gate before irreversible provisioning saga

---

## Vertical Packs

| Pack | Primary entities | Module seeds | Dashboard focus |
|------|-----------------|--------------|-----------------|
| **School** | Students, classes, academic year | SIS, Finance, Education Suite, Phase 5 ops | Attendance, fees, risk, memories |
| **Salon (Velora)** | Clients, stylists, services | Appointments, retail inventory, staff | Chair utilization, revenue, loyalty |
| **Hospital** | Patients, departments, practitioners | Appointments, billing, supply issue | Bed/OPD load, collections, inventory |
| **Restaurant** | Tables, menu, kitchen stations | Orders, inventory, staff shifts | Covers, ticket time, waste |

Each pack is a **template bundle**: enabled modules, default roles, permission matrix, widget layout graph, workflow definitions, and seed data fixtures.

---

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────────┐
│ Interview UI    │────▶│ Interview Service │────▶│ Draft Config Store  │
│ (web wizard)    │     │ (validate steps)  │     │ organization_profiles│
└─────────────────┘     └──────────────────┘     └──────────┬──────────┘
                                                              │
                    ┌─────────────────────────────────────────▼──────────┐
                    │              Config Preview Engine                  │
                    │  modules · roles · widgets · workflows · nav shell  │
                    └─────────────────────────┬────────────────────────────┘
                                              │ human approve
                    ┌─────────────────────────▼────────────────────────────┐
                    │              Provisioning Saga (async)              │
                    │  org → branch → roles → permissions → seeds → go-live │
                    └──────────────────────────────────────────────────────┘
```

| Layer | Responsibility |
|-------|----------------|
| Interview service | Collect answers; validate against pack schema; persist draft |
| Vertical templates | Packaged presets per industry (see table above) |
| Config preview engine | Render diff: modules, RBAC, dashboards before commit |
| Provisioning saga | Async steps with compensating transactions |
| Config store | `organization_profiles.config` JSON (versioned) |

**Reuse from v1.0:** v7.15 CSV import for people after structure exists; Phase 5 probe seeds as template fixtures.

---

## Interview Flow (conceptual)

| Step | School example | Salon example | Hospital example | Restaurant example |
|------|---------------|---------------|------------------|-------------------|
| 1 Identity | School name, board, branches | Salon brand, locations | Hospital name, departments | Restaurant name, outlets |
| 2 Scale | Students, teachers, classes | Stylists, chairs, services/day | Beds, doctors, OPD slots | Tables, kitchen stations, covers/day |
| 3 Modules | Fees, transport, hostel | Retail, loyalty, appointments | Billing, pharmacy, lab | POS, kitchen display, inventory |
| 4 Workflows | Promotion, fee reminders | Appointment confirm, no-show | Discharge, insurance claim | Order → kitchen → serve |
| 5 Channels | WA, SMS, email to parents | Client reminders, promotions | Patient notifications | Table-ready alerts |
| 6 Payments | Fee plans, installments | Service + product checkout | Insurance + cash | Split bill, tips |
| 7 Review | Preview config diff | Preview config diff | Preview config diff | Preview config diff |

Output: `OrganizationConfigV2` document bound to selected pack.

---

## Permissions

| Role | Capability |
|------|------------|
| `platformAdmin` | All templates, cross-tenant preview, impersonation (audited) |
| `organizationAdmin` | Run builder for own org; approve provisioning |
| `branchAdmin` | Post-provision catalog tuning + imports only |

No new runtime permissions until implementation — builder uses existing platform admin scope.

---

## Data Model (conceptual)

| Entity | Purpose |
|--------|---------|
| `organization_profiles` | Vertical type, interview answers, enabled modules, config version |
| `provisioning_jobs` | Saga steps, status, error, rollback pointer |
| `vertical_pack_registry` | Pack definitions (read-only platform catalog) |
| `widget_layouts` | Dashboard graph per role (see Dynamic Widget Platform) |
| `workflow_definitions` | Pack-scoped lifecycle templates (see Universal Workflow Engine) |

No new tables in v10.4 — schema design only.

---

## APIs (conceptual)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/platform/org-builder/packs` | List available vertical packs |
| POST | `/platform/org-builder/interview` | Submit interview step |
| POST | `/platform/org-builder/preview` | Generated config from draft |
| POST | `/platform/org-builder/provision` | Start provisioning saga |
| GET | `/platform/provisioning-jobs/:id` | Saga status + step log |

---

## Phase 5 Foundation Reuse

| Phase 5 module | Builder input |
|----------------|---------------|
| Operations Hub | Default KPI widget set per enabled module |
| Employee Intelligence | Staff workload defaults per vertical |
| Achievement Promotion | Milestone/marketing workflow template |
| Book Distribution | Supply/issue pattern → hospital/restaurant inventory |
| Parent Experience | Portal pattern → patient/client portal pack |

---

## Rollout Plan

1. Document education template from v1.0 manual steps (complete)
2. Extract declarative education pack JSON schema
3. Add Salon pack schema (appointments + services graph)
4. Pilot builder on staging — education only
5. Hospital + Restaurant packs — design validation with domain SMEs
6. Production builder — education GA first; verticals sequential

---

## Risks

| Risk | Mitigation |
|------|------------|
| Over-customization | Template bounds; no arbitrary schema mutation |
| AI hallucination in config | Mandatory human review + preview diff |
| Saga partial failure | Compensating transactions; job retry + alert |
| Vertical scope creep | Pack registry owned by platform team; one pack at a time |
| RBAC explosion | Pack emits bounded permission bundles from registry |

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [Dynamic-Widget-Platform.md](./Dynamic-Widget-Platform.md) | Dashboard output of builder |
| [Universal-Employee-System.md](./Universal-Employee-System.md) | Staff model across verticals |
| [Universal-Workflow-Engine.md](./Universal-Workflow-Engine.md) | Workflow output of builder |
| [FutureTracks-Index.md](./FutureTracks-Index.md) | Design index |
