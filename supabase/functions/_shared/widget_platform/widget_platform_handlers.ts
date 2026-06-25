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
import { DEFAULT_WIDGET_LAYOUT, type DashboardWidgetPlacement } from "./widget_platform_service.ts";
import { buildWidgetData, invalidateWidgetCache } from "./widget_data_service.ts";

export async function handleListWidgets(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewDynamicWidgets") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const items = await withTenantContext(config, auth.claims, async (db) => {
      return await db.queryObject<{
        id: string;
        title: string;
        category: string;
        required_permission: string;
        description: string | null;
        default_width: number;
        default_height: number;
      }>(`SELECT id, title, category, required_permission, description, default_width, default_height
          FROM widget_registry WHERE is_active = true ORDER BY category, title`);
    });
    return jsonResponse(envelope({
      items: items.map((w) => ({
        id: w.id,
        title: w.title,
        category: w.category,
        requiredPermission: w.required_permission,
        description: w.description,
        defaultWidth: w.default_width,
        defaultHeight: w.default_height,
      })),
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("WIDGET_PLATFORM_ERROR", String(error), 500);
  }
}

export async function handleGetDashboardLayout(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewDynamicWidgets") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const dashboardKey = url.searchParams.get("dashboardKey") ?? "default";
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await db.queryObject<{ id: string; layout: unknown }>(
        `SELECT id, layout FROM dashboard_layouts
         WHERE organization_id = $1 AND school_id = $2
           AND (owner_user_id = $3 OR owner_user_id IS NULL)
           AND dashboard_key = $4
         ORDER BY owner_user_id NULLS LAST
         LIMIT 1`,
        [orgId, schoolId, auth.claims.sub, dashboardKey],
      );
      return rows[0];
    });
    const layout = (row?.layout as DashboardWidgetPlacement[] | undefined) ?? DEFAULT_WIDGET_LAYOUT;
    return jsonResponse(envelope({ id: row?.id ?? null, dashboardKey, layout }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("WIDGET_PLATFORM_ERROR", String(error), 500);
  }
}

export async function handleSaveDashboardLayout(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageDynamicWidgets") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ dashboardKey?: string; layout: DashboardWidgetPlacement[] }>(req);
  if (!body?.layout) return errorEnvelope("VALIDATION_ERROR", "layout is required", 422);

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  // dashboardKey can come from the body or, for role-scoped paths
  // (/widgets/layouts/:role), the query param injected by the router.
  const dashboardKey = body.dashboardKey ??
    new URL(req.url).searchParams.get("dashboardKey") ?? "default";

  try {
    const id = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await db.queryObject<{ id: string }>(
        `INSERT INTO dashboard_layouts (organization_id, school_id, owner_user_id, dashboard_key, layout)
         VALUES ($1, $2, $3, $4, $5::jsonb)
         ON CONFLICT (organization_id, school_id, owner_user_id, dashboard_key)
         DO UPDATE SET layout = EXCLUDED.layout, updated_at = timezone('utc', now())
         RETURNING id`,
        [orgId, schoolId, auth.claims.sub, dashboardKey, JSON.stringify(body.layout)],
      );
      await emitMutationAudit(db, auth.claims, widgetPlatformAudit.layoutSaved(rows[0]!.id), req);
      return rows[0]!.id;
    });
    return jsonResponse(envelope({ id, dashboardKey, layout: body.layout }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("WIDGET_PLATFORM_ERROR", String(error), 500);
  }
}

export async function handleGetWidgetData(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewDynamicWidgets") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const widgetIdsParam = url.searchParams.get("widgetIds");
  const widgetIds = widgetIdsParam?.split(",").map((s) => s.trim()).filter(Boolean);
  const forceRefresh = url.searchParams.get("refresh") === "true";
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, (db) =>
      buildWidgetData(db, orgId, schoolId, auth.claims, { widgetIds, forceRefresh })
    );
    return jsonResponse(envelope({ widgets: result.widgets, cached: result.cached }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("WIDGET_PLATFORM_ERROR", String(error), 500);
  }
}

export async function handleRefreshWidgetData(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageDynamicWidgets") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  invalidateWidgetCache(orgId, schoolId, auth.claims.sub);

  const url = new URL(req.url);
  const widgetIdsParam = url.searchParams.get("widgetIds");
  const widgetIds = widgetIdsParam?.split(",").map((s) => s.trim()).filter(Boolean);

  try {
    const result = await withTenantContext(config, auth.claims, (db) =>
      buildWidgetData(db, orgId, schoolId, auth.claims, { widgetIds, forceRefresh: true })
    );
    return jsonResponse(envelope({ widgets: result.widgets, cached: false }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("WIDGET_PLATFORM_ERROR", String(error), 500);
  }
}
