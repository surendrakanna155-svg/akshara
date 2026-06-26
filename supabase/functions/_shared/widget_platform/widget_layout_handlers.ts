// B11 — Dynamic Widget Platform: role/vertical-pack layout handlers.
//
// Serves the rich, role-bound dashboard contract the Flutter `dynamic_widgets`
// feature consumes (data-source registry, layout versions, per-role layouts with
// tenant overrides). Distinct from the older flat per-user dashboard layout in
// `widget_platform_handlers.ts` (DashboardWidgetPlacement[]), which stays intact.
//
// Tenant overrides persist in the existing `dashboard_layouts` table under
// dashboard_key `role:<role>` with `owner_user_id = NULL` (tenant-wide, applies to
// every user holding that role). The full RoleDashboardLayout is stored in the
// `layout` JSONB. The edge connects as the non-bypass `erp_tenant` role which has
// SELECT/INSERT/UPDATE — but NOT DELETE — so save is UPDATE-first/INSERT-fallback
// and reset rewrites the row to the pack default (no DELETE).

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, widgetPlatformAudit } from "../audit/mutation_audit_catalog.ts";
import {
  DEFAULT_ROLES,
  packDefaultLayout,
  type RoleDashboardLayoutDef,
  WIDGET_DATA_SOURCES,
} from "./widget_pack_catalog.ts";

const DEFAULT_PACK = "school";

function roleKey(role: string): string {
  return `role:${role}`;
}

/** A stored override is a tenant override only if the row's layout says so. */
function isOverride(stored: RoleDashboardLayoutDef | null): boolean {
  return !!stored && stored.isTenantOverride === true;
}

function widgetPlatformError(error: unknown): Response {
  if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
  return errorEnvelope("WIDGET_PLATFORM_ERROR", String(error), 500);
}

interface LayoutRow {
  id: string;
  layout: unknown;
  updated_at: string | null;
}

async function fetchOverrideRow(
  config: AppConfig,
  claims: Parameters<typeof organizationIdFromClaims>[0],
  orgId: string,
  schoolId: string,
  role: string,
): Promise<LayoutRow | undefined> {
  return await withTenantContext(config, claims, async (db) => {
    const rows = await db.queryObject<LayoutRow>(
      `SELECT id, layout, updated_at FROM dashboard_layouts
       WHERE organization_id = $1 AND school_id = $2
         AND owner_user_id IS NULL AND dashboard_key = $3
       LIMIT 1`,
      [orgId, schoolId, roleKey(role)],
    );
    return rows[0];
  });
}

function storedLayout(row: LayoutRow | undefined): RoleDashboardLayoutDef | null {
  if (!row?.layout || typeof row.layout !== "object") return null;
  return row.layout as RoleDashboardLayoutDef;
}

// ─── GET /widgets/data-sources ───────────────────────────────────────────────
export async function handleListDataSources(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewDynamicWidgets") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;
  return jsonResponse(envelope({ items: WIDGET_DATA_SOURCES }));
}

// ─── GET /widgets/layouts/versions ───────────────────────────────────────────
export async function handleListLayoutVersions(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewDynamicWidgets") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const roleParam = url.searchParams.get("role");
  const pack = url.searchParams.get("verticalPack") || DEFAULT_PACK;
  const roles = roleParam ? [roleParam] : DEFAULT_ROLES;
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const items = [] as Array<Record<string, unknown>>;
    for (const role of roles) {
      const row = await fetchOverrideRow(config, auth.claims, orgId, schoolId, role);
      const stored = storedLayout(row);
      const override = isOverride(stored);
      items.push({
        layoutId: `${role}-dashboard-v1`,
        role,
        verticalPack: override ? (stored!.verticalPack ?? pack) : pack,
        version: override ? (stored!.version ?? 1) : 1,
        updatedAt: override ? row?.updated_at ?? null : null,
        isTenantOverride: override,
      });
    }
    return jsonResponse(envelope({ items }));
  } catch (error) {
    return widgetPlatformError(error);
  }
}

// ─── GET /widgets/layouts/:role ──────────────────────────────────────────────
export async function handleGetRoleLayout(
  req: Request,
  config: AppConfig,
  role: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewDynamicWidgets") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await fetchOverrideRow(config, auth.claims, orgId, schoolId, role);
    const stored = storedLayout(row);
    if (isOverride(stored)) {
      return jsonResponse(envelope({ ...stored, role, isTenantOverride: true }));
    }
    return jsonResponse(envelope(packDefaultLayout(role, DEFAULT_PACK)));
  } catch (error) {
    return widgetPlatformError(error);
  }
}

// ─── PUT /widgets/layouts/:role ──────────────────────────────────────────────
export async function handleSaveRoleLayout(
  req: Request,
  config: AppConfig,
  role: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageDynamicWidgets") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ layout?: RoleDashboardLayoutDef; version?: number }>(req);
  const incoming = body?.layout;
  if (!incoming || !Array.isArray(incoming.widgets)) {
    return errorEnvelope("VALIDATION_ERROR", "layout with widgets is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const baseVersion = body?.version ?? incoming.version ?? 1;
  const saved: RoleDashboardLayoutDef = {
    layoutId: incoming.layoutId || `${role}-dashboard-v1`,
    role,
    verticalPack: incoming.verticalPack || DEFAULT_PACK,
    version: baseVersion + 1,
    widgets: incoming.widgets,
    navigation: Array.isArray(incoming.navigation) ? incoming.navigation : [],
    isTenantOverride: true,
  };

  try {
    await withTenantContext(config, auth.claims, async (db) => {
      // erp_tenant has no DELETE on dashboard_layouts, and a NULL owner_user_id
      // never trips the UNIQUE constraint, so upsert by UPDATE-first/INSERT-fallback.
      const updated = await db.queryObject<{ id: string }>(
        `UPDATE dashboard_layouts
            SET layout = $4::jsonb, updated_at = timezone('utc', now())
          WHERE organization_id = $1 AND school_id = $2
            AND owner_user_id IS NULL AND dashboard_key = $3
          RETURNING id`,
        [orgId, schoolId, roleKey(role), JSON.stringify(saved)],
      );
      let id = updated[0]?.id;
      if (!id) {
        const inserted = await db.queryObject<{ id: string }>(
          `INSERT INTO dashboard_layouts (organization_id, school_id, owner_user_id, dashboard_key, layout)
           VALUES ($1, $2, NULL, $3, $4::jsonb)
           RETURNING id`,
          [orgId, schoolId, roleKey(role), JSON.stringify(saved)],
        );
        id = inserted[0]!.id;
      }
      await emitMutationAudit(db, auth.claims, widgetPlatformAudit.roleLayoutSaved(role, id), req);
    });
    return jsonResponse(envelope(saved));
  } catch (error) {
    return widgetPlatformError(error);
  }
}

// ─── POST /widgets/layouts/:role/reset ───────────────────────────────────────
export async function handleResetRoleLayout(
  req: Request,
  config: AppConfig,
  role: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageDynamicWidgets") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ verticalPack?: string }>(req);
  const pack = body?.verticalPack || DEFAULT_PACK;
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const def = packDefaultLayout(role, pack);

  try {
    await withTenantContext(config, auth.claims, async (db) => {
      // No DELETE grant — clear the override by rewriting the row to the pack
      // default (isTenantOverride=false, version reset). No row → nothing to clear.
      const rows = await db.queryObject<{ id: string }>(
        `UPDATE dashboard_layouts
            SET layout = $4::jsonb, updated_at = timezone('utc', now())
          WHERE organization_id = $1 AND school_id = $2
            AND owner_user_id IS NULL AND dashboard_key = $3
          RETURNING id`,
        [orgId, schoolId, roleKey(role), JSON.stringify(def)],
      );
      // SEC-5 — audit the override clear (only when a row was actually rewritten).
      const id = rows[0]?.id;
      if (id) {
        await emitMutationAudit(db, auth.claims, {
          audit: {
            eventType: "widget_platform.role_layout.reset",
            category: "workflow",
            entityType: "dashboard_layout",
            entityId: id,
            metadata: { role, pack },
          },
          domain: {
            eventType: "widget_platform.role_layout.reset",
            payload: { role, pack, layoutRowId: id },
            sourceModule: "widget_platform",
            idempotencyKey: `widget_platform.role_layout.reset:${id}:${pack}`,
          },
        }, req);
      }
    });
    return jsonResponse(envelope(def));
  } catch (error) {
    return widgetPlatformError(error);
  }
}
