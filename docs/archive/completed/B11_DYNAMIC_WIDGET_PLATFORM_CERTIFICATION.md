# B11 — Dynamic Widget Platform — Production Certification

**Status:** ✅ PRODUCTION CERTIFIED (2026-06-25)
**Roadmap:** P3 Platform Expansion, second item — **the final planned roadmap batch** (B1–B11 complete; only P4/B12 Verticals remains, frozen).
**Live cert:** `scripts/qa/live_cert_b11_dynamic_widget_platform.py` — **16/16** against the VPS pilot (real auth, real DB, real RBAC).

## Scope & gap

The Flutter `dynamic_widgets` feature (registry / runtime / layout-editor screens,
models, repos, providers) shipped long ago and is live-wired (`EVOLUTION_API_ENABLED`
is on). It speaks a **rich role/vertical-pack contract**:

- `GET /widgets/data-sources` — the data-source registry
- `GET /widgets/layouts/versions` — per-role layout versions + override flags
- `GET /widgets/layouts/:role` — a `RoleDashboardLayout` (role, vertical pack, version, `DynamicWidgetItem[]`, navigation, `isTenantOverride`)
- `PUT /widgets/layouts/:role` — save a tenant override (version bump)
- `POST /widgets/layouts/:role/reset` — revert to the pack default

The backend only implemented the **older flat per-user dashboard layout**
(`DashboardWidgetPlacement[]`, migration `20260622900000_widget_platform_foundation`).
The rich endpoints were missing or wrong: `/widgets/data-sources` had **no handler
(404)**, `/widgets/layouts/versions` was **mis-routed** (captured as `role="versions"`),
and the role-layout GET/PUT/reset returned the **flat shape**, which the client mapper
read as an empty layout. The hybrid repo masks this by **silently falling back to the
in-app mock** — so the platform looked alive but was never actually server-backed.

B11 closes that gap: the platform now resolves real, server-stored, role-scoped
layouts with durable tenant overrides.

## What was built (backend-only, **no migration**)

Reuses the existing `widget_platform_foundation` tables (`widget_registry`,
`dashboard_layouts`) — both confirmed present + ledgered on the live DB.

- **`_shared/widget_platform/widget_pack_catalog.ts`** — pure reference data mirroring
  the client mock one-to-one: 6 namespaced `WIDGET_DATA_SOURCES`, `packDefaultLayout(role,
  verticalPack)` (school per-role: principal/schoolAdmin/teacher/financeAdmin, plus
  salon/hospital/restaurant packs), `DEFAULT_ROLES`.
- **`_shared/widget_platform/widget_layout_handlers.ts`** — the rich handlers:
  - `GET /widgets/data-sources` → the registry (`viewDynamicWidgets`)
  - `GET /widgets/layouts/versions` → per-role versions + override flags (`viewDynamicWidgets`)
  - `GET /widgets/layouts/:role` → pack default, or the persisted override (`viewDynamicWidgets`)
  - `PUT /widgets/layouts/:role` → upsert a **tenant override**, version+1, audited (`manageDynamicWidgets`)
  - `POST /widgets/layouts/:role/reset` → revert to the pack default (`manageDynamicWidgets`)
- **`widget_platform_router.ts`** — static `data-sources`/`versions` routes matched
  **before** the `:role` param regex; role-layout GET/PUT/reset repointed to the rich
  handlers. Legacy `registry` / `dashboard/layout` / `data` routes untouched. The old
  aliased reset handler in `widget_platform_handlers.ts` (which did a raw DELETE) removed.
- **`rbac_route_inventory.ts`** — added the five new routes.
- **`mutation_audit_catalog.ts`** — `widgetPlatformAudit.roleLayoutSaved` (event_type
  `widget_platform.role_layout.saved`).

### Persistence & the no-DELETE constraint

Tenant overrides persist in `dashboard_layouts` under `dashboard_key = 'role:<role>'`,
`owner_user_id = NULL` (tenant-wide — applies to every user holding that role), with the
full `RoleDashboardLayout` in the `layout` JSONB. The edge connects as the non-bypass
`erp_tenant` role, which has **SELECT/INSERT/UPDATE but not DELETE** on the table. So:

- **Save** is UPDATE-first / INSERT-fallback (a NULL `owner_user_id` never trips the
  UNIQUE constraint, so `ON CONFLICT` can't be used).
- **Reset** rewrites the row to the pack default (`isTenantOverride=false`, version reset)
  rather than deleting it.

### Gating

RBAC only — `viewDynamicWidgets` / `manageDynamicWidgets` at school scope. **No
entitlement gate**: this is a school-level configurability feature, and the shipped UI
gates by permission, not plan. (Adding a gate would have broken the pilot and expanded
scope.)

## Verification

- Backend Deno: `widget_pack_catalog_test.ts` 5/5 + `rbac_route_validation_test.ts` 5/5; `deno check` clean.
- Flutter: analyze clean; dynamic-widget contract + screen tests 8/8.
- Deploy: rsync `_shared/widget_platform/` + `_shared/validation/rbac_route_inventory.ts`
  + `_shared/audit/mutation_audit_catalog.ts` to `/opt/akshara/functions/`; `docker restart
  akshara-edge`; `/health` 200.

### Live cert — 16/16

health · data-sources registry (6 namespaced) · versions pack-default (v1, not overridden)
· role layout pack-default (school_health/fee_collection/student_risk/attendance_risk) ·
override save (version 1→2, `isTenantOverride=true`) · override **persists** durably ·
versions reflect override · audit row written · reset → pack default · GET back to default ·
RBAC: save needs manage (403) · read needs view (403) · school-scope required (org-scope 403)
· unauth 401 · legacy registry intact (200, 8 items) · clean teardown (override rows removed).

Real VPS, real prod DB, edge-minted school-scope JWT, real persistence. Cert rows removed
via `supabase_admin` (which bypasses RLS + the missing DELETE grant).
