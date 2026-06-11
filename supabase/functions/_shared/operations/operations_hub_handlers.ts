import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { buildOperationsHub } from "./operations_hub_service.ts";

function requireOpsRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewOperationsHub") ??
    requireSchoolOperationalScope(claims);
}

export async function handleOperationsHub(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireOpsRead(auth.claims);
  if (denied) return denied;

  try {
    const hub = await withTenantContext(config, auth.claims, (db) =>
      buildOperationsHub(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
      )
    );
    return jsonResponse(envelope(hub));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const message = error instanceof Error ? error.message : "Operations hub failed";
    return errorEnvelope("OPERATIONS_HUB_ERROR", message, 500);
  }
}

export async function handleOperationsActions(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireOpsRead(auth.claims);
  if (denied) return denied;

  try {
    const items = await withTenantContext(config, auth.claims, async (db) => {
      const hub = await buildOperationsHub(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
      );
      const actions = [
        ...hub.criticalAlerts.map((alert) => ({
          id: alert.id,
          module: alert.module,
          title: alert.title,
          severity: alert.severity,
          actionType: "review",
        })),
        ...hub.pendingActions.map((action) => ({
          id: action.id,
          module: action.module,
          title: action.title,
          severity: "medium",
          actionType: "follow_up",
        })),
      ];
      return actions;
    });
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const message = error instanceof Error ? error.message : "Operations actions failed";
    return errorEnvelope("OPERATIONS_ACTIONS_ERROR", message, 500);
  }
}
