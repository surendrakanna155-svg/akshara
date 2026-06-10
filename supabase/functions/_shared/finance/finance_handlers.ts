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
import {
  CatalogMismatchError,
  CatalogNotFoundError,
} from "../academic/academic_catalog_resolver.ts";
import {
  feeStructureToApi,
  listEnvelope,
  parseItemInputsFromBody,
} from "./finance_mapper.ts";
import {
  archiveFeeStructure,
  createFeeStructure,
  getFeeStructure,
  listFeeStructures,
  updateFeeStructure,
} from "./finance_structures_repository.ts";

function parsePagination(url: URL): { page: number; pageSize: number } {
  const page = Math.max(1, parseInt(url.searchParams.get("page") ?? "1", 10) || 1);
  const pageSize = Math.min(
    100,
    Math.max(1, parseInt(url.searchParams.get("pageSize") ?? "20", 10) || 20),
  );
  return { page, pageSize };
}

function snakeStr(body: Record<string, unknown>, key: string): string {
  return String(body[key] ?? "");
}

function optionalStr(
  body: Record<string, unknown>,
  snakeKey: string,
  camelKey: string,
): string | undefined {
  if (snakeKey in body && body[snakeKey] != null) {
    return String(body[snakeKey]);
  }
  if (camelKey in body && body[camelKey] != null) {
    return String(body[camelKey]);
  }
  return undefined;
}

function normalizeStatus(raw: string | undefined): string {
  const value = (raw ?? "active").trim();
  return value === "inactive" ? "inactive" : "active";
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

export async function handleListFeeStructures(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewFinance") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const pagination = parsePagination(url);
  const academicYear = url.searchParams.get("academicYear") ??
    url.searchParams.get("academic_year") ?? undefined;
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      listFeeStructures(db, orgId, schoolId, pagination, academicYear || undefined)
    );
    return jsonResponse(
      envelope(
        listEnvelope(
          result.items.map(({ structure, items }) =>
            feeStructureToApi(structure, items)
          ),
          {
            page: result.page,
            pageSize: result.pageSize,
            total: result.total,
            hasMore: result.hasMore,
          },
        ),
      ),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

export async function handleGetFeeStructure(
  req: Request,
  config: AppConfig,
  structureId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewFinance") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      getFeeStructure(db, orgId, schoolId, structureId)
    );
    if (!result) {
      return errorEnvelope("NOT_FOUND", `Fee structure not found: ${structureId}`, 404);
    }
    return jsonResponse(envelope(feeStructureToApi(result.structure, result.items)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

export async function handleCreateFeeStructure(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "manageFinance") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const name = snakeStr(body, "name").trim() ||
    String(body.name ?? "").trim();
  const academicYear = optionalStr(body, "academic_year", "academicYear")?.trim() ?? "";
  if (!name || !academicYear) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "name and academic_year are required",
      422,
    );
  }

  const description = optionalStr(body, "description", "description") ??
    optionalStr(body, "class_range", "classRange") ??
    null;
  const status = normalizeStatus(optionalStr(body, "status", "status"));
  const items = parseItemInputsFromBody(body);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      createFeeStructure(db, orgId, schoolId, {
        name,
        academicYear,
        academicYearId: optionalStr(body, "academic_year_id", "academicYearId") ?? null,
        description,
        status,
        createdBy: auth.claims.sub,
        items,
      })
    );
    return jsonResponse(
      envelope(feeStructureToApi(result.structure, result.items)),
      { status: 201 },
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof CatalogNotFoundError) {
      return errorEnvelope("CATALOG_NOT_FOUND", error.message, 422);
    }
    if (error instanceof CatalogMismatchError) {
      return errorEnvelope("CATALOG_MISMATCH", error.message, 422);
    }
    throw error;
  }
}

export async function handleUpdateFeeStructure(
  req: Request,
  config: AppConfig,
  structureId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "manageFinance") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  const updateInput: Parameters<typeof updateFeeStructure>[3] = {};
  const name = optionalStr(body, "name", "name");
  if (name !== undefined) updateInput.name = name.trim();
  const academicYear = optionalStr(body, "academic_year", "academicYear");
  if (academicYear !== undefined) updateInput.academicYear = academicYear.trim();
  const academicYearId = optionalStr(body, "academic_year_id", "academicYearId");
  if (academicYearId !== undefined) {
    updateInput.academicYearId = academicYearId.trim() || null;
  }
  if ("description" in body || "class_range" in body || "classRange" in body) {
    updateInput.description = optionalStr(body, "description", "description") ??
      optionalStr(body, "class_range", "classRange") ??
      null;
  }
  const status = optionalStr(body, "status", "status");
  if (status !== undefined) updateInput.status = normalizeStatus(status);
  if ("items" in body || "categories" in body) {
    updateInput.items = parseItemInputsFromBody(body);
  }

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      updateFeeStructure(db, orgId, schoolId, structureId, updateInput)
    );
    if (!result) {
      return errorEnvelope("NOT_FOUND", `Fee structure not found: ${structureId}`, 404);
    }
    return jsonResponse(envelope(feeStructureToApi(result.structure, result.items)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof CatalogNotFoundError) {
      return errorEnvelope("CATALOG_NOT_FOUND", error.message, 422);
    }
    if (error instanceof CatalogMismatchError) {
      return errorEnvelope("CATALOG_MISMATCH", error.message, 422);
    }
    throw error;
  }
}

export async function handleArchiveFeeStructure(
  req: Request,
  config: AppConfig,
  structureId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "manageFinance") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      archiveFeeStructure(db, orgId, schoolId, structureId)
    );
    if (!result) {
      return errorEnvelope("NOT_FOUND", `Fee structure not found: ${structureId}`, 404);
    }
    return jsonResponse(envelope(feeStructureToApi(result.structure, result.items)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}
