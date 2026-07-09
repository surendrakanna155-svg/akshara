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
import { emitMutationAudit, inventoryDistributionAudit } from "../audit/mutation_audit_catalog.ts";
import {
  approveReplacementRequest,
  buildDistributionDashboard,
  createDistribution,
  DistributionUpdateBlockedError,
  fulfillReplacementRequest,
  listCatalogItems,
  listReplacementRequests,
  listStudentDistributions,
  rejectReplacementRequest,
  ReplacementRequestInvalidStateError,
  ReplacementRequestNotFoundError,
  requestReplacement,
  transitionDistributionStatus,
  buildDistributionReports,
} from "./inventory_distribution_repository.ts";

function requireDistRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requireAnyPermission(claims, ["viewInventoryDistribution", "viewInventory"]) ??
    requireSchoolOperationalScope(claims);
}

function requireDistWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requireAnyPermission(claims, ["manageInventoryDistribution", "manageInventory"]) ??
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

/// FV-12 — maps a distribution row carrying a replacement sub-state to the
/// shape the client's `InvReplacementRequest` model expects. `id` and
/// `distributionId` are intentionally the same value: the distribution row
/// itself IS the replacement request (see inventory_distribution_repository.ts).
function mapReplacementRequest(row: {
  id: string;
  student_id: string;
  quantity: number;
  notes: string | null;
  replacement_status?: string | null;
  replacement_requested_at?: string | null;
  replacement_resolved_at?: string | null;
  replacement_rejection_reason?: string | null;
  itemName?: string;
  category?: string;
}) {
  return {
    id: row.id,
    distributionId: row.id,
    studentId: row.student_id,
    itemName: row.itemName,
    category: row.category,
    quantity: row.quantity,
    status: row.replacement_status,
    notes: row.notes,
    requestedAt: row.replacement_requested_at,
    resolvedAt: row.replacement_resolved_at,
    rejectionReason: row.replacement_rejection_reason,
  };
}

/** Maps replacement-workflow repository errors to their HTTP envelope. */
function mapReplacementRepositoryError(error: unknown): Response | null {
  if (error instanceof ReplacementRequestNotFoundError) {
    return errorEnvelope("NOT_FOUND", error.message, 404);
  }
  if (error instanceof ReplacementRequestInvalidStateError) {
    return errorEnvelope("INVALID_STATE", error.message, 409);
  }
  // Gap-remediation P0-3: the status UPDATE affected 0 rows (RLS blocked it —
  // wrong scope/ownership — or a concurrent change). The repository already
  // rolled the whole DB transaction back (see tenant_db.ts withTenantContext),
  // so nothing partially committed; surface it as a conflict rather than a
  // fabricated 2xx built from an undefined row.
  if (error instanceof DistributionUpdateBlockedError) {
    return errorEnvelope("REPLACEMENT_UPDATE_BLOCKED", error.message, 409);
  }
  return null;
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
    const mapped = mapReplacementRepositoryError(error);
    if (mapped) return mapped;
    const message = error instanceof Error ? error.message : "Replacement request failed";
    return errorEnvelope("INVENTORY_DISTRIBUTION_ERROR", message, 500);
  }
}

/// FV-12 replacement workflow — GET /inventory/distribution/replacements.
/// Staff-only list of distributions currently carrying (or having carried) a
/// replacement sub-state, optionally filtered by ?status=pending|approved|
/// fulfilled|rejected. Same read gate as every other distribution list route.
export async function handleListReplacementRequests(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireDistRead(auth.claims);
  if (denied) return denied;

  const status = new URL(req.url).searchParams.get("status") ?? undefined;
  try {
    const items = await runTenant(config, auth.claims, (db) => listReplacementRequests(db, status));
    return jsonResponse(envelope({ items: items.map(mapReplacementRequest) }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INVENTORY_DISTRIBUTION_ERROR", "List replacement requests failed", 500);
  }
}

/// POST /inventory/distribution/replacements/:id/approve — staff decision
/// moving a `pending` request to `approved`. Write-gated like every other
/// distribution mutation (no parent bypass — approval is staff-only).
export async function handleApproveReplacementRequest(
  req: Request,
  config: AppConfig,
  requestId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireDistWrite(auth.claims);
  if (denied) return denied;

  try {
    const updated = await runTenant(config, auth.claims, async (db) => {
      const row = await approveReplacementRequest(db, requestId);
      await emitMutationAudit(
        db,
        auth.claims,
        inventoryDistributionAudit.replacementApproved(requestId),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(mapReplacementRequest(updated)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const mapped = mapReplacementRepositoryError(error);
    if (mapped) return mapped;
    const message = error instanceof Error ? error.message : "Approve replacement failed";
    return errorEnvelope("INVENTORY_DISTRIBUTION_ERROR", message, 500);
  }
}

/// POST /inventory/distribution/replacements/:id/fulfill — issues the actual
/// replacement item (reuses createDistribution's stock-decrement path) and
/// marks the request `fulfilled`. Only valid from `approved`.
export async function handleFulfillReplacementRequest(
  req: Request,
  config: AppConfig,
  requestId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireDistWrite(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const updated = await runTenant(config, auth.claims, async (db) => {
      const row = await fulfillReplacementRequest(db, orgId, schoolId, requestId, auth.claims.sub);
      await emitMutationAudit(
        db,
        auth.claims,
        inventoryDistributionAudit.replacementFulfilled(requestId),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(mapReplacementRequest(updated)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const mapped = mapReplacementRepositoryError(error);
    if (mapped) return mapped;
    const message = error instanceof Error ? error.message : "Fulfill replacement failed";
    return errorEnvelope("INVENTORY_DISTRIBUTION_ERROR", message, 500);
  }
}

/// POST /inventory/distribution/replacements/:id/reject — staff decision
/// moving a `pending` or `approved` request to `rejected`, with an optional
/// reason surfaced back to the requester.
export async function handleRejectReplacementRequest(
  req: Request,
  config: AppConfig,
  requestId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireDistWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ reason?: string }>(req);

  try {
    const updated = await runTenant(config, auth.claims, async (db) => {
      const row = await rejectReplacementRequest(db, requestId, body?.reason);
      await emitMutationAudit(
        db,
        auth.claims,
        inventoryDistributionAudit.replacementRejected(requestId, body?.reason),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(mapReplacementRequest(updated)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const mapped = mapReplacementRepositoryError(error);
    if (mapped) return mapped;
    const message = error instanceof Error ? error.message : "Reject replacement failed";
    return errorEnvelope("INVENTORY_DISTRIBUTION_ERROR", message, 500);
  }
}
