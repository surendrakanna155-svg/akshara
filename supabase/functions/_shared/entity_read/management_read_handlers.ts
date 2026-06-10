import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
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

function requireSchoolScope(claims: Parameters<typeof requirePermission>[0]): Response | null {
  if (claims.scope !== "school" || !claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Management data requires school scope", 403);
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

export function createManagementReadHandlers(
  permission: string,
  store: EntityReadStore,
) {
  function requireRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
    return requirePermission(claims, permission) ?? requireSchoolScope(claims);
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
      console.error(`management snapshot(${entityType}) error:`, error);
      return errorEnvelope("INTERNAL_ERROR", notFoundMessage, 500);
    }
  }

  return { handleSnapshot };
}
