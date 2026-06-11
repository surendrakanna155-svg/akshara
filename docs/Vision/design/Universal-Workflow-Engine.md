# Design — Universal Workflow Engine

**Status:** Architecture only — not implemented  
**Target industries:** School · Salon · Hospital · Restaurant  
**Depends on:** Audit pipeline, RBAC registry, Organization Builder v2, domain events outbox

---

## Goals

- Declarative workflow definitions reusable across vertical packs
- Standard lifecycle patterns: draft → review → approve → publish → archive
- Workflow steps bind to permissions, audit events, and optional domain event emission
- Organization Builder emits pack-specific workflow templates at provision time

---

## Problem Statement

Akshara already implements ad-hoc workflows per module:

| Module | Workflow | Status |
|--------|----------|--------|
| Admissions | Application → review → enroll | ✅ Production |
| Achievement Promotion | draft → generate → pending approval → published | ✅ v10.3 |
| School Memories | draft → published → archived | ✅ v10.2 |
| Inventory Distribution | distributed → ack → replacement | ✅ v9.7 |
| Fee invoices | draft → issued → paid | ✅ Finance |

The Universal Workflow Engine extracts the **common pattern** so new vertical packs (Salon appointments, Hospital discharge, Restaurant order fulfillment) ship workflows without bespoke handler code per module.

---

## Workflow Definition Schema (conceptual)

```json
{
  "workflowId": "achievement-promotion",
  "verticalPack": "school",
  "entityType": "achievement_promotion",
  "initialStatus": "draft",
  "states": [
    { "id": "draft", "label": "Draft" },
    { "id": "pending_approval", "label": "Pending Approval" },
    { "id": "published", "label": "Published", "terminal": true }
  ],
  "transitions": [
    {
      "from": "draft",
      "to": "pending_approval",
      "action": "generate",
      "permission": "manageAchievementPromotion",
      "auditEvent": "promotion.assets.generated"
    },
    {
      "from": "pending_approval",
      "to": "published",
      "action": "publish",
      "permission": "approveAchievementPromotion",
      "auditEvent": "promotion.published"
    }
  ]
}
```

---

## Architecture

```
┌──────────────────┐     ┌─────────────────────┐     ┌─────────────────┐
│ Workflow Registry│────▶│ Workflow Runtime    │────▶│ Entity Table    │
│ (pack templates) │     │ (validate transition)│     │ status column   │
└──────────────────┘     └──────────┬──────────┘     └─────────────────┘
                                    │
                         ┌──────────▼──────────┐
                         │ Audit + Domain Event │
                         └─────────────────────┘
```

| Layer | Responsibility |
|-------|----------------|
| Workflow registry | Platform + pack-scoped definition catalog |
| Runtime engine | Validates transition, permission, guards; updates status |
| Action hooks | Optional side effects (generate assets, send notification) |
| Audit middleware | Emits catalogued events per transition |
| UI generator | Flutter action buttons from available transitions for user role |

---

## Vertical Workflow Templates

| Pack | Workflow | States (summary) |
|------|----------|------------------|
| **School** | Achievement promotion | draft → pending → published |
| **School** | Memory event | draft → published → archived |
| **School** | Inventory replacement | ack → replacement_requested → fulfilled |
| **Salon** | Appointment | booked → confirmed → completed → no-show |
| **Salon** | Loyalty reward | earned → pending → redeemed |
| **Hospital** | Patient discharge | admitted → discharge_pending → discharged |
| **Hospital** | Supply requisition | requested → approved → issued |
| **Restaurant** | Order | placed → kitchen → ready → served → closed |
| **Restaurant** | Waste report | logged → reviewed → adjusted |

Organization Builder enables subset of templates based on interview answers.

---

## Permissions Model

Each transition declares a required permission slug. Runtime checks:

1. User has permission in current branch scope
2. Entity is in valid `from` state
3. Optional guard predicate (e.g., assets generated before publish)

Separate **view** vs **manage** vs **approve** transitions — mirrors Achievement Promotion pattern.

---

## Data Model (conceptual)

| Entity | Purpose |
|--------|---------|
| `workflow_definitions` | Registry: pack, entity type, states, transitions |
| `workflow_instances` | Optional: long-running saga tracking (multi-step) |
| `workflow_transition_log` | Immutable audit of state changes |
| Entity tables | Existing `status` columns — no parallel state store required |

Prefer **entity-native status** + registry metadata over separate state machine tables for simple workflows.

---

## APIs (conceptual)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/workflows/definitions/:entityType` | Definition for entity (admin) |
| GET | `/workflows/:entityType/:id/transitions` | Available actions for current user |
| POST | `/workflows/:entityType/:id/:action` | Execute transition |
| GET | `/workflows/:entityType/:id/history` | Transition log |

Existing module routes (e.g., `POST /promotions/:id/publish`) become thin wrappers over workflow runtime — backward compatible.

---

## Integration Points

| System | Integration |
|--------|-------------|
| Audit catalog | Each transition maps to `MutationAuditSpec` |
| Domain events | Transitions emit to `domain_events` outbox |
| RBAC | Permission slugs on transitions |
| Dynamic Widget Platform | Action widgets invoke available transitions |
| Organization Builder | Emits enabled workflow definitions at provision |

---

## Rollout Plan

1. Extract Achievement Promotion + Memories workflows into registry JSON
2. Workflow runtime library in Edge `_shared/workflows/`
3. Refactor promotion handlers to use runtime (no API break)
4. Salon appointment workflow — first non-education template
5. Flutter generic action bar from `/transitions` endpoint
6. Hospital + Restaurant templates; builder integration

---

## Risks

| Risk | Mitigation |
|------|------------|
| Over-abstraction | Start with status-column workflows; sagas only when needed |
| Breaking existing APIs | Thin wrapper preserves current routes |
| Guard logic complexity | Guards as named functions in registry; unit tested |
| Concurrent transitions | Optimistic locking on entity `updated_at` |
| Pack workflow conflicts | Unique `workflowId` per pack + entity type |

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [Universal-Organization-Builder-v2.md](./Universal-Organization-Builder-v2.md) | Workflow template selection |
| [Dynamic-Widget-Platform.md](./Dynamic-Widget-Platform.md) | Action widgets |
| [Universal-Employee-System.md](./Universal-Employee-System.md) | Approval actor roles |
| [FutureTracks-Index.md](./FutureTracks-Index.md) | Design index |
