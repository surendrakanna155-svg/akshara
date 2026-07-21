// Shared SQL repository for both widget-platform handler surfaces:
//   - widget_layout_handlers.ts   — B11 role/vertical-pack dashboard layouts
//     (dashboard_layouts rows keyed by `role:<role>`, owner_user_id = NULL).
//   - widget_platform_handlers.ts — the older flat per-user dashboard layout
//     (dashboard_layouts rows keyed by an arbitrary dashboardKey, scoped to a
//     specific owner_user_id or the tenant-wide NULL row) + widget_registry.
// Function names are prefixed RoleLayout* vs DashboardLayout*/Widget* to keep
// the two surfaces unambiguous while sharing one file.

import type { TenantQueryClient } from "../tenant_db.ts";

// ─── Role/vertical-pack layouts (widget_layout_handlers.ts) ─────────────────

export interface RoleLayoutOverrideRow {
  id: string;
  layout: unknown;
  updated_at: string | null;
}

/**
 * The stored tenant-wide override row for a role's dashboard layout, if any
 * (`dashboard_key = 'role:<role>'`, `owner_user_id IS NULL`).
 */
export async function getRoleLayoutOverrideRow(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  dashboardKey: string,
): Promise<RoleLayoutOverrideRow | undefined> {
  const rows = await db.queryObject<RoleLayoutOverrideRow>(
    `SELECT id, layout, updated_at FROM dashboard_layouts
     WHERE organization_id = $1 AND school_id = $2
       AND owner_user_id IS NULL AND dashboard_key = $3
     LIMIT 1`,
    [organizationId, schoolId, dashboardKey],
  );
  return rows[0];
}

/**
 * Rewrite an existing tenant-wide role-layout override row's `layout`.
 * Returns the row id when a row was updated, undefined when no override row
 * exists yet for this role (erp_tenant has no DELETE, so callers fall back to
 * `insertRoleLayoutOverride` — see handleSaveRoleLayout).
 */
export async function updateRoleLayoutOverride(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  dashboardKey: string,
  layoutJson: string,
): Promise<string | undefined> {
  const rows = await db.queryObject<{ id: string }>(
    `UPDATE dashboard_layouts
        SET layout = $4::jsonb, updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2
        AND owner_user_id IS NULL AND dashboard_key = $3
      RETURNING id`,
    [organizationId, schoolId, dashboardKey, layoutJson],
  );
  return rows[0]?.id;
}

/**
 * Create the tenant-wide role-layout override row (INSERT fallback used when
 * `updateRoleLayoutOverride` found no existing row).
 */
export async function insertRoleLayoutOverride(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  dashboardKey: string,
  layoutJson: string,
): Promise<string> {
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO dashboard_layouts (organization_id, school_id, owner_user_id, dashboard_key, layout)
     VALUES ($1, $2, NULL, $3, $4::jsonb)
     RETURNING id`,
    [organizationId, schoolId, dashboardKey, layoutJson],
  );
  return rows[0]!.id;
}

// ─── Flat per-user dashboard layout (widget_platform_handlers.ts) ───────────

export interface WidgetRegistryRow {
  id: string;
  title: string;
  category: string;
  required_permission: string;
  description: string | null;
  default_width: number;
  default_height: number;
}

/** All active entries in the widget registry, catalog-ordered. */
export async function listActiveWidgetsFromRegistry(
  db: TenantQueryClient,
): Promise<WidgetRegistryRow[]> {
  return await db.queryObject<WidgetRegistryRow>(
    `SELECT id, title, category, required_permission, description, default_width, default_height
     FROM widget_registry WHERE is_active = true ORDER BY category, title`,
  );
}

export interface DashboardLayoutRow {
  id: string;
  layout: unknown;
}

/**
 * The effective dashboard layout row for a user: their own override when one
 * exists, else the tenant-wide (owner_user_id IS NULL) row for the same key.
 */
export async function getDashboardLayoutRow(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  ownerUserId: string,
  dashboardKey: string,
): Promise<DashboardLayoutRow | undefined> {
  const rows = await db.queryObject<DashboardLayoutRow>(
    `SELECT id, layout FROM dashboard_layouts
     WHERE organization_id = $1 AND school_id = $2
       AND (owner_user_id = $3 OR owner_user_id IS NULL)
       AND dashboard_key = $4
     ORDER BY owner_user_id NULLS LAST
     LIMIT 1`,
    [organizationId, schoolId, ownerUserId, dashboardKey],
  );
  return rows[0];
}

/**
 * Upsert a user's dashboard layout (insert, or overwrite on the
 * organization_id/school_id/owner_user_id/dashboard_key conflict target).
 * Returns the row id.
 */
export async function upsertDashboardLayout(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  ownerUserId: string,
  dashboardKey: string,
  layoutJson: string,
): Promise<string> {
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO dashboard_layouts (organization_id, school_id, owner_user_id, dashboard_key, layout)
     VALUES ($1, $2, $3, $4, $5::jsonb)
     ON CONFLICT (organization_id, school_id, owner_user_id, dashboard_key)
     DO UPDATE SET layout = EXCLUDED.layout, updated_at = timezone('utc', now())
     RETURNING id`,
    [organizationId, schoolId, ownerUserId, dashboardKey, layoutJson],
  );
  return rows[0]!.id;
}
