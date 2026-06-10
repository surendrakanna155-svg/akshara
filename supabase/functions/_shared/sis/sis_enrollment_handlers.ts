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
  createEnrollment,
  DuplicateEnrollmentError,
  EnrollmentNotFoundError,
  listEnrollments,
  updateEnrollment,
  ValidationError,
  type EnrollmentListFilters,
} from "./sis_enrollments_repository.ts";
import {
  CatalogMismatchError,
  CatalogNotFoundError,
} from "../academic/academic_catalog_resolver.ts";
import { enrollmentListItemToApi, listEnvelope } from "./sis_mapper.ts";
import { StudentNotFoundError } from "./sis_students_repository.ts";

function parsePagination(url: URL): { page: number; pageSize: number } {
  const page = Math.max(1, parseInt(url.searchParams.get("page") ?? "1", 10) || 1);
  const pageSize = Math.min(
    100,
    Math.max(1, parseInt(url.searchParams.get("pageSize") ?? "20", 10) || 20),
  );
  return { page, pageSize };
}

function parseOptionalBool(value: string | null): boolean | undefined {
  if (value == null || value.trim() === "") return undefined;
  const normalized = value.trim().toLowerCase();
  if (normalized === "true" || normalized === "1") return true;
  if (normalized === "false" || normalized === "0") return false;
  return undefined;
}

function parseEnrollmentFilters(url: URL): EnrollmentListFilters {
  const get = (camel: string, snake: string): string | undefined => {
    const value = url.searchParams.get(camel) ?? url.searchParams.get(snake);
    return value?.trim() || undefined;
  };

  return {
    academicYear: get("academicYear", "academic_year"),
    className: get("className", "class_name"),
    sectionName: get("sectionName", "section_name"),
    studentId: get("studentId", "student_id"),
    isCurrent: parseOptionalBool(
      url.searchParams.get("isCurrent") ?? url.searchParams.get("is_current"),
    ),
  };
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

function requireSisRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewSis") ??
    requireSchoolOperationalScope(claims);
}

function requireSisWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageSis") ??
    requireSchoolOperationalScope(claims);
}

function optionalBodyStr(
  body: Record<string, unknown>,
  ...keys: string[]
): string | undefined {
  for (const key of keys) {
    if (key in body && body[key] != null) return String(body[key]);
  }
  return undefined;
}

function optionalNullableStr(
  body: Record<string, unknown>,
  ...keys: string[]
): string | null | undefined {
  for (const key of keys) {
    if (key in body) {
      const value = body[key];
      if (value == null) return null;
      return String(value);
    }
  }
  return undefined;
}

function optionalBodyBool(body: Record<string, unknown>, ...keys: string[]): boolean | undefined {
  for (const key of keys) {
    if (key in body && body[key] != null) {
      const value = body[key];
      if (typeof value === "boolean") return value;
      const parsed = parseOptionalBool(String(value));
      if (parsed !== undefined) return parsed;
    }
  }
  return undefined;
}

function mapEnrollmentError(error: unknown): Response | null {
  if (error instanceof EnrollmentNotFoundError || error instanceof StudentNotFoundError) {
    return errorEnvelope("NOT_FOUND", error.message, 404);
  }
  if (error instanceof DuplicateEnrollmentError) {
    return errorEnvelope("CONFLICT", error.message, 409);
  }
  if (error instanceof CatalogNotFoundError) {
    return errorEnvelope("CATALOG_NOT_FOUND", error.message, 422);
  }
  if (error instanceof CatalogMismatchError) {
    return errorEnvelope("CATALOG_MISMATCH", error.message, 422);
  }
  if (error instanceof ValidationError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  return null;
}

export async function handleListEnrollments(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireSisRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      listEnrollments(
        db,
        orgId,
        schoolId,
        parseEnrollmentFilters(url),
        parsePagination(url),
      )
    );
    return jsonResponse(
      envelope(
        listEnvelope(
          result.items.map(enrollmentListItemToApi),
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
    console.error("handleListEnrollments error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to list enrollments", 500);
  }
}

export async function handleCreateEnrollment(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireSisWrite(auth.claims);
  if (denied) return denied;

  let body: Record<string, unknown> = {};
  try {
    body = (await readJson<Record<string, unknown>>(req)) ?? {};
  } catch {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const studentId = optionalBodyStr(body, "studentId", "student_id");
  const academicYear = optionalBodyStr(body, "academicYear", "academic_year");
  const className = optionalBodyStr(body, "className", "class_name");
  if (!studentId || !academicYear || !className) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "studentId, academicYear, and className are required",
      422,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await runTenant(config, auth.claims, (db) =>
      createEnrollment(db, orgId, schoolId, {
        studentId,
        academicYear,
        academicYearId: optionalNullableStr(body, "academicYearId", "academic_year_id"),
        className,
        classId: optionalNullableStr(body, "classId", "class_id"),
        sectionName: optionalNullableStr(body, "sectionName", "section_name"),
        sectionId: optionalNullableStr(body, "sectionId", "section_id"),
        rollNumber: optionalNullableStr(body, "rollNumber", "roll_number"),
        isCurrent: optionalBodyBool(body, "isCurrent", "is_current"),
        createdBy: auth.claims.sub,
      })
    );
    return jsonResponse(envelope(enrollmentListItemToApi(row)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    const mapped = mapEnrollmentError(error);
    if (mapped) return mapped;
    console.error("handleCreateEnrollment error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to create enrollment", 500);
  }
}

export async function handleUpdateEnrollment(
  req: Request,
  config: AppConfig,
  enrollmentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireSisWrite(auth.claims);
  if (denied) return denied;

  let body: Record<string, unknown> = {};
  try {
    body = (await readJson<Record<string, unknown>>(req)) ?? {};
  } catch {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await runTenant(config, auth.claims, (db) =>
      updateEnrollment(db, orgId, schoolId, enrollmentId, {
        academicYear: optionalBodyStr(body, "academicYear", "academic_year"),
        academicYearId: optionalNullableStr(body, "academicYearId", "academic_year_id"),
        className: optionalBodyStr(body, "className", "class_name"),
        classId: optionalNullableStr(body, "classId", "class_id"),
        sectionName: optionalNullableStr(body, "sectionName", "section_name"),
        sectionId: optionalNullableStr(body, "sectionId", "section_id"),
        rollNumber: optionalNullableStr(body, "rollNumber", "roll_number"),
        isCurrent: optionalBodyBool(body, "isCurrent", "is_current"),
      })
    );
    return jsonResponse(envelope(enrollmentListItemToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    const mapped = mapEnrollmentError(error);
    if (mapped) return mapped;
    console.error("handleUpdateEnrollment error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to update enrollment", 500);
  }
}
