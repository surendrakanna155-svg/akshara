# Design — Dynamic Widget Platform

**Status:** Architecture only — not implemented  
**Target industries:** School · Salon · Hospital · Restaurant  
**Depends on:** Universal Organization Builder v2, Operations Hub widget schema (Phase 5), RBAC registry

---

## Goals

- Tenant-scoped, versioned widget definitions — layout changes without code deploy
- Role-bound dashboards generated from Organization Builder interview output
- Widgets bind to repository providers (read-only aggregates + drill-down routes)
- Vertical packs ship default widget graphs; tenants customize within template bounds

---

## Concept

Phase 5 Operations Hub already returns a **schema-driven `widgets` object** (attendance, collections, communications, risk alerts, inventory alerts, fee alerts). The Dynamic Widget Platform generalizes this pattern into a persistent, editable registry.

```
Organization Builder  ──▶  widget_layouts (versioned JSON)
                                    │
                                    ▼
                         Widget Runtime (Flutter + Edge)
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
              Repository      Drill-down       RBAC filter
              provider        route bind       per widget
```

---

## Widget Schema (conceptual)

```json
{
  "layoutId": "principal-dashboard-v1",
  "role": "principal",
  "verticalPack": "school",
  "version": 3,
  "widgets": [
    {
      "id": "attendance-today",
      "type": "kpi",
      "title": "Today's Attendance",
      "dataSource": "operations.attendance.today",
      "permissions": ["viewOperationsHub"],
      "drillDown": "/sis/attendance",
      "size": "half"
    }
  ],
  "navigation": [
    { "label": "Operations", "route": "/operations/hub", "icon": "dashboard" }
  ]
}
```

| Field | Purpose |
|-------|---------|
| `type` | `kpi`, `chart`, `list`, `alert`, `action` |
| `dataSource` | Namespaced provider key (maps to repository method) |
| `permissions` | Widget hidden if user lacks any listed permission |
| `drillDown` | Optional route on tap |
| `size` | Grid placement hint (`full`, `half`, `third`) |

---

## Architecture

| Layer | Responsibility |
|-------|----------------|
| Widget registry | Platform catalog of widget types + data source bindings |
| Layout store | Per-tenant, per-role, versioned JSON in `widget_layouts` |
| Runtime resolver | Merges pack defaults + tenant overrides; filters by RBAC |
| Flutter renderer | Generic widget host — maps `type` → UI component |
| Edge aggregator | Optional server-side batch fetch for dashboard load performance |

---

## Vertical Pack Defaults

| Pack | Primary dashboard roles | Signature widgets |
|------|------------------------|-------------------|
| **School** | Principal, teacher, parent | School health, risk alerts, fee collections, memories |
| **Salon** | Owner, stylist, reception | Chair utilization, appointment pipeline, retail KPIs |
| **Hospital** | Admin, department head | Bed occupancy, OPD queue, billing collections |
| **Restaurant** | Manager, kitchen lead | Active covers, ticket time, waste/inventory alerts |

Pack defaults are emitted by Organization Builder; tenants may reorder, hide, or resize within allowed widget set.

---

## Permissions

| Role | Capability |
|------|------------|
| `platformAdmin` | Define widget types in registry |
| `organizationAdmin` | Edit layouts for all roles in org |
| `schoolAdmin` / branch admin | Edit layouts for branch-scoped roles |
| End user | View widgets permitted by role — no layout edit |

Widget-level permission arrays are AND-checked against user session.

---

## Data Model (conceptual)

| Entity | Purpose |
|--------|---------|
| `widget_type_registry` | Platform-defined widget types + JSON schema |
| `widget_layouts` | Tenant + role + version → widget graph |
| `widget_layout_revisions` | Audit trail of layout changes |
| `widget_data_cache` | Optional TTL cache for expensive aggregates |

---

## APIs (conceptual)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/platform/widgets/types` | Registry of available widget types |
| GET | `/widgets/layouts/:role` | Resolved layout for current user |
| PUT | `/widgets/layouts/:role` | Save tenant override (admin) |
| GET | `/widgets/data/:sourceKey` | Batch data fetch for dashboard |

---

## Flutter Integration (future)

- `DynamicDashboardScreen` — generic host replacing hardcoded module dashboards over time
- Provider: `widgetLayoutProvider(role)` → resolved graph
- Provider: `widgetDataProvider(sourceKey)` → repository dispatch table
- Education pack migrates Operations Hub first; ERP module dashboards follow incrementally

---

## Rollout Plan

1. Extract Operations Hub widget schema as v1 registry entry
2. Persist principal layout JSON for pilot school
3. Generic Flutter widget host — KPI + list types only
4. Organization Builder emits initial layout on provision
5. Salon pack widget set — validate with Velora prototype
6. Chart + alert widget types; layout editor UI (admin)

---

## Risks

| Risk | Mitigation |
|------|------------|
| Unbounded custom widgets | Registry allowlist; no arbitrary code in JSON |
| N+1 repository calls | Batch data endpoint; client-side request coalescing |
| Layout breaking on schema change | Version field + migration transforms |
| RBAC bypass via dataSource | Server validates permission on every data fetch |
| Performance on mobile | Lazy load tabs; cache TTL on aggregates |

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [Universal-Organization-Builder-v2.md](./Universal-Organization-Builder-v2.md) | Layout generation source |
| [Universal-Workflow-Engine.md](./Universal-Workflow-Engine.md) | Action widgets triggering workflows |
| [FutureTracks-Index.md](./FutureTracks-Index.md) | Design index |
