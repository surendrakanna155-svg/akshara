import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requireAnyPermission,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, inventoryIntelligenceAudit } from "../audit/mutation_audit_catalog.ts";
import {
  computeAssetLifecycle,
  computeInventoryCopilot,
  computeProcurementWorkflow,
  recordAssetLifecycleEvent,
  type AssetLifecycleEventType,
  type RecordLifecycleEventInput,
} from "./inventory_intelligence_service.ts";

function requireInventoryIntelligence(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requireAnyPermission(claims, ["viewInventoryIntelligence", "viewInventory"]) ??
    requireSchoolOperationalScope(claims);
}

function requireAssetLifecycleManage(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requireAnyPermission(claims, ["manageAssetLifecycle", "manageInventory"]) ??
    requireSchoolOperationalScope(claims);
}

function requireProcurementWorkflowManage(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requireAnyPermission(claims, ["manageProcurementWorkflow", "manageInventory"]) ??
    requireSchoolOperationalScope(claims);
}

export async function handleInventoryCopilot(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireInventoryIntelligence(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const snapshot = await withTenantContext(config, auth.claims, (db) =>
      computeInventoryCopilot(db, orgId, schoolId));
    return jsonResponse(envelope(snapshot));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    console.error("handleInventoryCopilot error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to compute inventory copilot", 500);
  }
}

export async function handleAssetLifecycle(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireInventoryIntelligence(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const snapshot = await withTenantContext(config, auth.claims, (db) =>
      computeAssetLifecycle(db, orgId, schoolId));
    return jsonResponse(envelope(snapshot));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    console.error("handleAssetLifecycle error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load asset lifecycle", 500);
  }
}

export async function handleRecordAssetLifecycleEvent(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAssetLifecycleManage(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  let body: Record<string, unknown>;
  try {
    body = await readJson(req) ?? {};
  } catch {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const assetId = typeof body.assetId === "string" ? body.assetId : "";
  const eventType = typeof body.eventType === "string" ? body.eventType : "";
  const validTypes: AssetLifecycleEventType[] = [
    "purchase",
    "distribution",
    "replacement",
    "damage",
    "retirement",
  ];
  if (!assetId || !validTypes.includes(eventType as AssetLifecycleEventType)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "assetId and valid eventType are required",
      422,
    );
  }

  const input: RecordLifecycleEventInput = {
    assetId,
    assetTag: typeof body.assetTag === "string" ? body.assetTag : undefined,
    eventType: eventType as AssetLifecycleEventType,
    notes: typeof body.notes === "string" ? body.notes : undefined,
    metadata: typeof body.metadata === "object" && body.metadata !== null
      ? body.metadata as Record<string, unknown>
      : undefined,
  };

  try {
    const event = await withTenantContext(config, auth.claims, async (db) => {
      const created = await recordAssetLifecycleEvent(
        db,
        orgId,
        schoolId,
        auth.claims.sub ?? null,
        input,
      );
      await emitMutationAudit(
        db,
        auth.claims,
        inventoryIntelligenceAudit.lifecycleEventRecorded(created.id, created.eventType),
        req,
      );
      return created;
    });
    return jsonResponse(envelope(event), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    console.error("handleRecordAssetLifecycleEvent error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to record lifecycle event", 500);
  }
}

export async function handleProcurementWorkflow(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireInventoryIntelligence(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const snapshot = await withTenantContext(config, auth.claims, (db) =>
      computeProcurementWorkflow(db, orgId, schoolId));
    return jsonResponse(envelope(snapshot));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    console.error("handleProcurementWorkflow error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load procurement workflow", 500);
  }
}

export async function handleAdvanceProcurementWorkflow(
  req: Request,
  config: AppConfig,
  purchaseOrderId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireProcurementWorkflowManage(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await db.queryObject<{ id: string; status: string; po_number: string }>(
        `UPDATE purchase_orders
         SET status = CASE
           WHEN status = 'draft' THEN 'approved'
           WHEN status = 'approved' THEN 'partially_received'
           ELSE status
         END,
         approved_by = CASE WHEN status = 'draft' THEN $4::uuid ELSE approved_by END,
         approved_at = CASE WHEN status = 'draft' THEN timezone('utc', now()) ELSE approved_at END,
         updated_at = timezone('utc', now())
         WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3
         RETURNING id, status, po_number`,
        [purchaseOrderId, orgId, schoolId, auth.claims.sub ?? null],
      );
      if (rows.length === 0) {
        return null;
      }
      const row = rows[0]!;
      await emitMutationAudit(
        db,
        auth.claims,
        inventoryIntelligenceAudit.procurementWorkflowAdvanced(row.id, row.status),
        req,
      );
      return { purchaseOrderId: row.id, poNumber: row.po_number, status: row.status };
    });

    if (!result) {
      return errorEnvelope("NOT_FOUND", "Purchase order not found", 404);
    }
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    console.error("handleAdvanceProcurementWorkflow error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to advance procurement workflow", 500);
  }
}
