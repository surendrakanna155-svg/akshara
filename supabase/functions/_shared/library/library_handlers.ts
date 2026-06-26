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
import { createModuleReadHandlers } from "../entity_read/module_read_handlers.ts";
import { libraryStore } from "./library_read_repository.ts";
import {
  computeDashboard,
  computeFines,
  computeReports,
  listAllEntities,
  membersWithLiveLoans,
} from "./library_aggregations.ts";

const { handleSnapshot, handleList } = createModuleReadHandlers("viewLibrary", libraryStore);

function requireLibraryRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewLibrary") ??
    requireSchoolOperationalScope(claims);
}

function parsePagination(url: URL): { page: number; pageSize: number } {
  const page = Math.max(1, parseInt(url.searchParams.get("page") ?? "1", 10) || 1);
  const pageSize = Math.min(
    100,
    Math.max(1, parseInt(url.searchParams.get("pageSize") ?? "20", 10) || 20),
  );
  return { page, pageSize };
}

/**
 * Run an authenticated, tenant-scoped read that recomputes an aggregate/derived
 * view from the live library entity rows (instead of a static seed snapshot).
 */
async function handleComputed(
  req: Request,
  config: AppConfig,
  errorMessage: string,
  compute: (
    db: Parameters<Parameters<typeof withTenantContext>[2]>[0],
    orgId: string,
    schoolId: string,
  ) => Promise<Record<string, unknown>>,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireLibraryRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) =>
      await compute(db, orgId, schoolId)
    );
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error(`library handleComputed error:`, error);
    return errorEnvelope("INTERNAL_ERROR", errorMessage, 500);
  }
}

export async function handleDashboard(req: Request, config: AppConfig): Promise<Response> {
  return await handleComputed(
    req,
    config,
    "Failed to load library dashboard",
    async (db, orgId, schoolId) => {
      const [books, issues, members] = await Promise.all([
        listAllEntities(db, orgId, schoolId, "catalog"),
        listAllEntities(db, orgId, schoolId, "issue"),
        listAllEntities(db, orgId, schoolId, "member"),
      ]);
      return computeDashboard(books, issues, members);
    },
  );
}

export async function handleCatalog(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "catalog", "Failed to load library catalog");
}

export async function handleIssues(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "issue", "Failed to load library issues");
}

export async function handleReturns(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "return_record", "Failed to load library returns");
}

/**
 * Members list with a live `activeLoans` count overlaid from open loans, so the
 * loan-count reflects reality rather than a never-incremented seed counter.
 */
export async function handleMembers(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireLibraryRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const pagination = parsePagination(url);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const [page, issues] = await Promise.all([
        libraryStore.listEntities(db, orgId, schoolId, "member", pagination),
        listAllEntities(db, orgId, schoolId, "issue"),
      ]);
      return { page, items: membersWithLiveLoans(page.items, issues) };
    });
    return jsonResponse(
      envelope(
        listEnvelope(result.items, {
          page: result.page.page,
          pageSize: result.page.pageSize,
          total: result.page.total,
          hasMore: result.page.hasMore,
        }),
      ),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("library handleMembers error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load library members", 500);
  }
}

export async function handleFines(req: Request, config: AppConfig): Promise<Response> {
  return await handleComputed(
    req,
    config,
    "Failed to load library fines",
    async (db, orgId, schoolId) => {
      const [issues, members, fines] = await Promise.all([
        listAllEntities(db, orgId, schoolId, "issue"),
        listAllEntities(db, orgId, schoolId, "member"),
        listAllEntities(db, orgId, schoolId, "fine"),
      ]);
      return computeFines(issues, members, fines);
    },
  );
}

export async function handleDigitalResources(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_digital_resources", "Failed to load digital resources");
}

export async function handleReports(req: Request, config: AppConfig): Promise<Response> {
  return await handleComputed(
    req,
    config,
    "Failed to load library reports",
    async (db, orgId, schoolId) => {
      const issues = await listAllEntities(db, orgId, schoolId, "issue");
      return computeReports(issues);
    },
  );
}
