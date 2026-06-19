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
import { approvalPermissionForType } from "./approval_permissions.ts";
import {
  approvalAuditToApi,
  approvalRequestToApi,
  listEnvelope,
} from "./approval_mapper.ts";
import {
  ApprovalInvalidStateError,
  ApprovalNotFoundError,
  ApprovalRejectCommentRequiredError,
  ApprovalSelfApproveDeniedError,
  findPendingByEntity,
  getApprovalById,
  insertAuditEntry,
  listApprovals,
  listAuditEntries,
  listPendingApprovals,
  submitApproval,
} from "./approval_repository.ts";
import { orchestrateApprovalDecision } from "./approval_orchestrator.ts";
import { isF2ApprovalType } from "./approval_types.ts";

function optionalStr(
  body: Record<string, unknown>,
  snakeKey: string,
  camelKey: string,
): string | undefined {
  if (snakeKey in body && body[snakeKey] != null) return String(body[snakeKey]);
  if (camelKey in body && body[camelKey] != null) return String(body[camelKey]);
  return undefined;
}

function mapApprovalError(error: unknown): Response | null {
  if (error instanceof ApprovalNotFoundError) {
    return errorEnvelope("NOT_FOUND", error.message, 404);
  }
  if (error instanceof ApprovalInvalidStateError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  if (error instanceof ApprovalRejectCommentRequiredError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  if (error instanceof ApprovalSelfApproveDeniedError) {
    return errorEnvelope("FORBIDDEN", error.message, 403);
  }
  return null;
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

function requireSchoolScope(claims: Parameters<typeof requireSchoolOperationalScope>[0]): Response | null {
  return requireSchoolOperationalScope(claims);
}

export async function handleListApprovals(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewManagement") ??
    requireSchoolScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const rows = await runTenant(config, auth.claims, (db) =>
      listApprovals(db, orgId, schoolId, {
        status: url.searchParams.get("status") ?? undefined,
        type: url.searchParams.get("type") ?? undefined,
        requesterId: url.searchParams.get("requesterId") ??
          url.searchParams.get("requester_id") ?? undefined,
        entityType: url.searchParams.get("entityType") ??
          url.searchParams.get("entity_type") ?? undefined,
        entityId: url.searchParams.get("entityId") ??
          url.searchParams.get("entity_id") ?? undefined,
      })
    );
    return jsonResponse(envelope(listEnvelope(rows.map(approvalRequestToApi))));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleListPendingApprovals(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewManagement") ??
    requireSchoolScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const rows = await runTenant(config, auth.claims, (db) =>
      listPendingApprovals(db, orgId, schoolId)
    );
    return jsonResponse(envelope(listEnvelope(rows.map(approvalRequestToApi))));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleGetApproval(
  req: Request,
  config: AppConfig,
  approvalId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewManagement") ??
    requireSchoolScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await runTenant(config, auth.claims, (db) =>
      getApprovalById(db, orgId, schoolId, approvalId)
    );
    if (!row) {
      return errorEnvelope("NOT_FOUND", `Approval not found: ${approvalId}`, 404);
    }
    return jsonResponse(envelope(approvalRequestToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleFindPendingByEntity(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewManagement") ??
    requireSchoolScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const type = url.searchParams.get("type");
  const entityType = url.searchParams.get("entityType") ??
    url.searchParams.get("entity_type");
  const entityId = url.searchParams.get("entityId") ??
    url.searchParams.get("entity_id");

  if (!type || !entityType || !entityId) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "type, entityType, and entityId query params are required",
      422,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await runTenant(config, auth.claims, (db) =>
      findPendingByEntity(db, orgId, schoolId, type, entityType, entityId)
    );
    return jsonResponse(envelope(row ? approvalRequestToApi(row) : null));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleSubmitApproval(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireSchoolScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const type = optionalStr(body, "type", "type");
  const title = optionalStr(body, "title", "title");
  const summary = optionalStr(body, "summary", "summary");
  const requesterId = optionalStr(body, "requester_id", "requesterId");
  const requesterName = optionalStr(body, "requester_name", "requesterName");
  const entityType = optionalStr(body, "entity_type", "entityType");
  const entityId = optionalStr(body, "entity_id", "entityId");

  if (!type || !title || !summary || !requesterId || !requesterName || !entityType || !entityId) {
    return errorEnvelope("VALIDATION_ERROR", "Missing required approval fields", 422);
  }

  if (!isF2ApprovalType(type)) {
    return errorEnvelope("VALIDATION_ERROR", `Unsupported approval type: ${type}`, 422);
  }

  const payload = (body.payload && typeof body.payload === "object" && !Array.isArray(body.payload))
    ? body.payload as Record<string, unknown>
    : {};

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await runTenant(config, auth.claims, (db) =>
      submitApproval(db, orgId, schoolId, {
        type,
        title,
        summary,
        requesterId,
        requesterName,
        entityType,
        entityId,
        payload,
      })
    );
    return jsonResponse(envelope(approvalRequestToApi(row)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    const mapped = mapApprovalError(error);
    if (mapped) return mapped;
    throw error;
  }
}

async function handleDecision(
  req: Request,
  config: AppConfig,
  approvalId: string,
  status: "approved" | "rejected" | "cancelled",
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireSchoolScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req) ?? {};
  const actorId = optionalStr(body, "actor_id", "actorId") ?? auth.claims.sub;
  const actorName = optionalStr(body, "actor_name", "actorName") ?? "Approver";
  const comment = optionalStr(body, "comment", "comment") ?? null;

  if (status !== "cancelled") {
    const row = await runTenant(config, auth.claims, (db) =>
      getApprovalById(db, organizationIdFromClaims(auth.claims), schoolIdFromClaims(auth.claims), approvalId)
    );
    if (!row) {
      return errorEnvelope("NOT_FOUND", `Approval not found: ${approvalId}`, 404);
    }
    const perm = approvalPermissionForType(row.type);
    if (perm) {
      const permDenied = requirePermission(auth.claims, perm);
      if (permDenied) return permDenied;
    }
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await runTenant(config, auth.claims, (db) =>
      orchestrateApprovalDecision(db, orgId, schoolId, {
        approvalId,
        status,
        actorId,
        actorName,
        comment,
      })
    );
    return jsonResponse(envelope(approvalRequestToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    const mapped = mapApprovalError(error);
    if (mapped) return mapped;
    throw error;
  }
}

export async function handleApproveApproval(
  req: Request,
  config: AppConfig,
  approvalId: string,
): Promise<Response> {
  return await handleDecision(req, config, approvalId, "approved");
}

export async function handleRejectApproval(
  req: Request,
  config: AppConfig,
  approvalId: string,
): Promise<Response> {
  return await handleDecision(req, config, approvalId, "rejected");
}

export async function handleCancelApproval(
  req: Request,
  config: AppConfig,
  approvalId: string,
): Promise<Response> {
  return await handleDecision(req, config, approvalId, "cancelled");
}

export async function handleListApprovalAudit(
  req: Request,
  config: AppConfig,
  approvalId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewManagement") ??
    requireSchoolScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const rows = await runTenant(config, auth.claims, (db) =>
      listAuditEntries(db, orgId, schoolId, approvalId)
    );
    return jsonResponse(envelope(listEnvelope(rows.map(approvalAuditToApi))));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleRecordApprovalAudit(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewManagement") ??
    requireSchoolScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const approvalRequestId = optionalStr(body, "approval_request_id", "approvalRequestId");
  const action = optionalStr(body, "action", "action");
  const actorId = optionalStr(body, "actor_id", "actorId");
  const actorName = optionalStr(body, "actor_name", "actorName");

  if (!approvalRequestId || !action || !actorId || !actorName) {
    return errorEnvelope("VALIDATION_ERROR", "Missing audit entry fields", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await runTenant(config, auth.claims, (db) =>
      insertAuditEntry(
        db,
        orgId,
        schoolId,
        approvalRequestId,
        action as "submitted" | "approved" | "rejected" | "cancelled",
        actorId,
        actorName,
        optionalStr(body, "comment", "comment") ?? null,
      )
    );
    return jsonResponse(envelope(approvalAuditToApi(row)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}
