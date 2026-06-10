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
import { listEnvelope } from "../finance/finance_mapper.ts";
import type { EntityReadStore } from "./entity_read_store.ts";

function parsePagination(url: URL): { page: number; pageSize: number } {
  const page = Math.max(1, parseInt(url.searchParams.get("page") ?? "1", 10) || 1);
  const pageSize = Math.min(
    100,
    Math.max(1, parseInt(url.searchParams.get("pageSize") ?? "20", 10) || 20),
  );
  return { page, pageSize };
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

export function createModuleReadHandlers(
  permission: string,
  store: EntityReadStore,
) {
  function requireRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
    return requirePermission(claims, permission) ??
      requireSchoolOperationalScope(claims);
  }

  async function handleSnapshot(
    req: Request,
    config: AppConfig,
    entityType: string,
    notFoundMessage: string,
  ): Promise<Response> {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;

    const denied = requireRead(auth.claims);
    if (denied) return denied;

    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);

    try {
      const snapshot = await runTenant(config, auth.claims, async (db) =>
        await store.getSnapshot(db, orgId, schoolId, entityType)
      );
      return jsonResponse(envelope(snapshot));
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse(error);
      }
      if (error instanceof store.SnapshotNotFoundError) {
        return errorEnvelope("NOT_FOUND", notFoundMessage, 404);
      }
      console.error(`handleSnapshot(${entityType}) error:`, error);
      return errorEnvelope("INTERNAL_ERROR", notFoundMessage, 500);
    }
  }

  async function handleList(
    req: Request,
    config: AppConfig,
    entityType: string,
    errorMessage: string,
  ): Promise<Response> {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;

    const denied = requireRead(auth.claims);
    if (denied) return denied;

    const url = new URL(req.url);
    const pagination = parsePagination(url);
    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);

    try {
      const result = await runTenant(config, auth.claims, async (db) =>
        await store.listEntities(db, orgId, schoolId, entityType, pagination)
      );
      return jsonResponse(
        envelope(
          listEnvelope(result.items, {
            page: result.page,
            pageSize: result.pageSize,
            total: result.total,
            hasMore: result.hasMore,
          }),
        ),
      );
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse(error);
      }
      console.error(`handleList(${entityType}) error:`, error);
      return errorEnvelope("INTERNAL_ERROR", errorMessage, 500);
    }
  }

  async function handleDetail(
    req: Request,
    config: AppConfig,
    entityType: string,
    entityId: string,
    notFoundMessage: string,
    toApi: (payload: Record<string, unknown>) => Record<string, unknown> = (p) => p,
  ): Promise<Response> {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;

    const denied = requireRead(auth.claims);
    if (denied) return denied;

    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);

    try {
      const entity = await runTenant(config, auth.claims, async (db) =>
        await store.getEntity(db, orgId, schoolId, entityType, entityId)
      );
      return jsonResponse(envelope(toApi(entity)));
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse(error);
      }
      if (error instanceof store.EntityNotFoundError) {
        return errorEnvelope("NOT_FOUND", notFoundMessage, 404);
      }
      console.error(`handleDetail(${entityType}, ${entityId}) error:`, error);
      return errorEnvelope("INTERNAL_ERROR", notFoundMessage, 500);
    }
  }

  return { handleSnapshot, handleList, handleDetail, requireRead };
}
