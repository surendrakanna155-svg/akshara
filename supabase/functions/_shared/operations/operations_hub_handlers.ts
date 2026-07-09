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
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import {
  buildOperationsHub,
  completeOperationsAction,
  dismissOperationsAlert,
  isKnownOperationsActionId,
  isKnownOperationsAlertId,
} from "./operations_hub_service.ts";

function requireOpsRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewOperationsHub") ??
    requireSchoolOperationalScope(claims);
}

// #6 — dismiss/complete are MANAGE actions: the client's own
// assertManageOperationsHub gate (operations_hub_mutations_provider.dart)
// requires BOTH manageManagement and viewOperationsHub, so the server mirrors
// that exact AND-gate rather than the read-only requireOpsRead.
function requireOpsManage(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageManagement") ??
    requirePermission(claims, "viewOperationsHub") ??
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

/**
 * #6 — POST /operations/hub/alerts/{alertId}/dismiss. Persists the dismissal
 * (scoped to today) so the next GET /operations/hub genuinely omits it, fixing
 * the client's dismiss button (previously 404, silent no-op forever).
 */
export async function handleDismissOperationsAlert(
  req: Request,
  config: AppConfig,
  alertId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireOpsManage(auth.claims);
  if (denied) return denied;

  if (!isKnownOperationsAlertId(alertId)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `Unknown operations alert id: ${alertId}`,
      422,
    );
  }

  try {
    await withTenantContext(config, auth.claims, async (db) => {
      await dismissOperationsAlert(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
        alertId,
        auth.claims.sub,
      );
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("operations.hub_alert.dismissed", "operations_hub_alert", alertId, {}),
        req,
      );
    });
    return jsonResponse(envelope({ id: alertId, status: "dismissed" }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const message = error instanceof Error ? error.message : "Dismiss alert failed";
    return errorEnvelope("OPERATIONS_DISMISS_ALERT_ERROR", message, 500);
  }
}

/**
 * #6 — POST /operations/hub/actions/{actionId}/complete. Persists the
 * completion (scoped to today) so the next GET /operations/hub genuinely
 * omits it, fixing the client's complete button (previously 404).
 */
export async function handleCompleteOperationsAction(
  req: Request,
  config: AppConfig,
  actionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireOpsManage(auth.claims);
  if (denied) return denied;

  if (!isKnownOperationsActionId(actionId)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `Unknown operations action id: ${actionId}`,
      422,
    );
  }

  try {
    await withTenantContext(config, auth.claims, async (db) => {
      await completeOperationsAction(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
        actionId,
        auth.claims.sub,
      );
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("operations.hub_action.completed", "operations_hub_action", actionId, {}),
        req,
      );
    });
    return jsonResponse(envelope({ id: actionId, status: "completed" }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const message = error instanceof Error ? error.message : "Complete action failed";
    return errorEnvelope("OPERATIONS_COMPLETE_ACTION_ERROR", message, 500);
  }
}
