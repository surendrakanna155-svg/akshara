import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import {
  type AuditEventFilters,
  type ClientAuditEventInput,
  correlationIdFromRequest,
  ingestClientAuditBatch,
  listAuditEvents,
} from "./audit_repository.ts";

interface BatchUploadBody {
  events?: ClientAuditEventInput[];
}

export async function handleAuditBatchUpload(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  // RT-21 — client audit ingestion is a staff/compliance feature. Restrict it
  // to membership scopes (school / organization); relationship users
  // (parent / student) — the largest and least-trusted population — can no
  // longer inject rows into the forensic trail. Accepted events stay
  // server-pinned to the actor, tenant, and school (defense in depth).
  if (auth.claims.scope !== "school" && auth.claims.scope !== "organization") {
    return errorEnvelope(
      "FORBIDDEN",
      "Audit ingestion requires a staff scope",
      403,
    );
  }

  const body = await readJson<BatchUploadBody>(req);
  if (!body?.events || !Array.isArray(body.events) || body.events.length === 0) {
    return errorEnvelope("VALIDATION_ERROR", "events array is required", 422);
  }

  if (body.events.length > 100) {
    return errorEnvelope("VALIDATION_ERROR", "Maximum 100 events per batch", 422);
  }

  organizationIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) =>
      await ingestClientAuditBatch(db, auth.claims, body.events!, req)
    );

    return jsonResponse(
      envelope({
        acceptedCount: result.acceptedCount,
        rejectedIds: result.rejectedIds,
      }),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("audit batch upload error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to ingest audit batch", 500);
  }
}

// PRA-P1-53 (S2): permission-gated read route for the forensic audit trail.
// Gated on `viewManagement` — an existing school-scoped leadership permission
// (schoolAdmin / principal / vicePrincipal / management / organization*), the
// same population that owns the Management dashboard; it is NOT held by
// teachers, clerks, parents, or students. No new slug is minted and no RBAC seed
// is touched (owned by another worker). The read runs under `withTenantContext`
// so the `audit_events_tenant_read` RLS policy scopes rows to the caller's
// org/school automatically.
const AUDIT_MAX_PAGE_SIZE = 100;

function firstParam(params: URLSearchParams, keys: string[]): string | undefined {
  for (const key of keys) {
    const value = params.get(key);
    if (value !== null && value.trim() !== "") return value.trim();
  }
  return undefined;
}

function parseAuditFilters(params: URLSearchParams): AuditEventFilters {
  return {
    actor: firstParam(params, ["actor", "userId", "user_id"]),
    entityType: firstParam(params, ["entityType", "entity_type"]),
    entityId: firstParam(params, ["entityId", "entity_id"]),
    eventType: firstParam(params, ["eventType", "action", "event_type"]),
    fromDate: firstParam(params, ["fromDate", "from", "from_date"]),
    toDate: firstParam(params, ["toDate", "to", "to_date"]),
  };
}

function parseAuditPagination(params: URLSearchParams): { page: number; pageSize: number } {
  const page = Math.max(1, parseInt(params.get("page") ?? "1", 10) || 1);
  const pageSize = Math.min(
    AUDIT_MAX_PAGE_SIZE,
    Math.max(1, parseInt(params.get("pageSize") ?? "20", 10) || 20),
  );
  return { page, pageSize };
}

export async function handleListAuditEvents(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewManagement");
  if (denied) return denied;

  organizationIdFromClaims(auth.claims);

  const params = new URL(req.url).searchParams;
  const filters = parseAuditFilters(params);
  const pagination = parseAuditPagination(params);

  try {
    const result = await withTenantContext(config, auth.claims, (db) =>
      listAuditEvents(db, auth.claims, filters, pagination));

    return jsonResponse(
      envelope({
        items: result.items,
        pagination: {
          page: result.page,
          pageSize: result.pageSize,
          total: result.total,
          hasMore: result.hasMore,
        },
      }),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("audit events list error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to list audit events", 500);
  }
}

export { correlationIdFromRequest };
