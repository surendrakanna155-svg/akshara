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
import { emitMutationAudit, inventoryDistributionAudit } from "../audit/mutation_audit_catalog.ts";
import {
  buildDistributionDashboard,
  createDistribution,
  listCatalogItems,
  listStudentDistributions,
  requestReplacement,
  transitionDistributionStatus,
  buildDistributionReports,
} from "./inventory_distribution_repository.ts";

function requireDistRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewInventoryDistribution") ??
    requirePermission(claims, "viewInventory") ??
    requireSchoolOperationalScope(claims);
}

function requireDistWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageInventoryDistribution") ??
    requirePermission(claims, "manageInventory") ??
    requireSchoolOperationalScope(claims);
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

function mapDistribution(row: {
  id: string;
  student_id: string;
  catalog_item_id: string;
  quantity: number;
  status: string;
  distributed_at: string | null;
  acknowledged_at: string | null;
  payment_request_id: string | null;
  itemName?: string;
  category?: string;
}) {
  return {
    id: row.id,
    studentId: row.student_id,
    catalogItemId: row.catalog_item_id,
    itemName: row.itemName,
    category: row.category,
    quantity: row.quantity,
    status: row.status,
    distributedAt: row.distributed_at,
    acknowledgedAt: row.acknowledged_at,
    paymentRequestId: row.payment_request_id,
  };
}

export async function handleDistributionDashboard(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireDistRead(auth.claims);
  if (denied) return denied;

  try {
    const dashboard = await runTenant(config, auth.claims, (db) => buildDistributionDashboard(db));
    return jsonResponse(envelope(dashboard));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INVENTORY_DISTRIBUTION_ERROR", "Dashboard failed", 500);
  }
}

export async function handleDistributionReports(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireDistRead(auth.claims);
  if (denied) return denied;

  try {
    const reports = await runTenant(config, auth.claims, (db) => buildDistributionReports(db));
    return jsonResponse(envelope(reports));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INVENTORY_DISTRIBUTION_ERROR", "Reports failed", 500);
  }
}

export async function handleListCatalogItems(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireDistRead(auth.claims);
  if (denied) return denied;

  const category = new URL(req.url).searchParams.get("category") ?? undefined;
  try {
    const items = await runTenant(config, auth.claims, (db) => listCatalogItems(db, category));
    return jsonResponse(envelope({
      items: items.map((i) => ({
        id: i.id,
        category: i.category,
        name: i.name,
        skuCode: i.sku_code,
        unitPrice: i.unit_price,
        stockOnHand: i.stock_on_hand,
      })),
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INVENTORY_DISTRIBUTION_ERROR", "List catalog failed", 500);
  }
}

export async function handleListDistributions(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireDistRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  try {
    const items = await runTenant(config, auth.claims, (db) =>
      listStudentDistributions(db, {
        studentId: url.searchParams.get("studentId") ?? undefined,
        status: url.searchParams.get("status") ?? undefined,
      })
    );
    return jsonResponse(envelope({ items: items.map(mapDistribution) }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INVENTORY_DISTRIBUTION_ERROR", "List distributions failed", 500);
  }
}

export async function handleCreateDistribution(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireDistWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    studentId: string;
    catalogItemId: string;
    quantity?: number;
  }>(req);
  if (!body?.studentId || !body.catalogItemId) {
    return errorEnvelope("VALIDATION_ERROR", "studentId and catalogItemId are required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const created = await runTenant(config, auth.claims, async (db) => {
      const row = await createDistribution(db, orgId, schoolId, {
        studentId: body.studentId,
        catalogItemId: body.catalogItemId,
        quantity: body.quantity ?? 1,
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        inventoryDistributionAudit.created(row.id, body.studentId),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(mapDistribution(created)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const message = error instanceof Error ? error.message : "Create distribution failed";
    return errorEnvelope("INVENTORY_DISTRIBUTION_ERROR", message, 500);
  }
}

export async function handleTransitionDistribution(
  req: Request,
  config: AppConfig,
  distributionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const body = await readJson<{ status: string; notes?: string }>(req);
  if (!body?.status) {
    return errorEnvelope("VALIDATION_ERROR", "status is required", 422);
  }

  const parentAck = body.status === "parent_acknowledged";
  const denied = parentAck
    ? null
    : requireDistWrite(auth.claims);
  if (denied) return denied;
  if (parentAck && auth.claims.scope !== "parent" && requireDistWrite(auth.claims)) {
    return requireDistWrite(auth.claims)!;
  }

  try {
    const updated = await runTenant(config, auth.claims, async (db) => {
      const row = await transitionDistributionStatus(db, distributionId, body.status, body.notes);
      await emitMutationAudit(
        db,
        auth.claims,
        inventoryDistributionAudit.statusChanged(distributionId, body.status),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(mapDistribution(updated)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const message = error instanceof Error ? error.message : "Transition failed";
    return errorEnvelope("INVENTORY_DISTRIBUTION_ERROR", message, 500);
  }
}

export async function handleRequestReplacement(
  req: Request,
  config: AppConfig,
  distributionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "parent") {
    const denied = requireDistWrite(auth.claims);
    if (denied) return denied;
  }

  const body = await readJson<{ notes?: string }>(req);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const payerUserId = auth.claims.sub;

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      const row = await requestReplacement(
        db,
        orgId,
        schoolId,
        distributionId,
        payerUserId,
        body?.notes,
      );
      await emitMutationAudit(
        db,
        auth.claims,
        inventoryDistributionAudit.replacementRequested(distributionId),
        req,
      );
      return row;
    });
    return jsonResponse(envelope({
      distribution: mapDistribution(result.distribution),
      paymentRequestId: result.paymentRequestId,
    }), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const message = error instanceof Error ? error.message : "Replacement request failed";
    return errorEnvelope("INVENTORY_DISTRIBUTION_ERROR", message, 500);
  }
}
