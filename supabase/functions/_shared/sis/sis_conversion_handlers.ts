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
import { emitMutationAudit, sisAudit } from "../audit/mutation_audit_catalog.ts";
import {
  AdmissionsEnrollmentNotFoundError,
  convertAdmissionsEnrollment,
  ValidationError,
} from "./sis_conversion_repository.ts";
import {
  CatalogMismatchError,
  CatalogNotFoundError,
} from "../academic/academic_catalog_resolver.ts";
import { admissionsConversionToApi } from "./sis_mapper.ts";
import { StudentNotFoundError } from "./sis_students_repository.ts";

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
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

function mapConversionError(error: unknown): Response | null {
  if (
    error instanceof AdmissionsEnrollmentNotFoundError ||
    error instanceof StudentNotFoundError
  ) {
    return errorEnvelope("NOT_FOUND", error.message, 404);
  }
  if (error instanceof ValidationError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  if (error instanceof CatalogNotFoundError) {
    return errorEnvelope("CATALOG_NOT_FOUND", error.message, 422);
  }
  if (error instanceof CatalogMismatchError) {
    return errorEnvelope("CATALOG_MISMATCH", error.message, 422);
  }
  return null;
}

export async function handleAdmissionsConversion(
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

  const enrollmentId = optionalBodyStr(body, "enrollmentId", "enrollment_id");
  const academicYear = optionalBodyStr(body, "academicYear", "academic_year");
  const className = optionalBodyStr(body, "className", "class_name") ??
    optionalBodyStr(body, "classLabel", "class_label");
  const sectionName = optionalNullableStr(body, "sectionName", "section_name") ??
    optionalNullableStr(body, "section", "section");
  const rollNumber = optionalNullableStr(body, "rollNumber", "roll_number");

  if (!enrollmentId || !academicYear || !className) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "enrollmentId, academicYear, and className are required",
      422,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      const converted = await convertAdmissionsEnrollment(db, orgId, schoolId, {
        enrollmentId,
        academicYear,
        academicYearId: optionalNullableStr(body, "academicYearId", "academic_year_id"),
        className,
        classId: optionalNullableStr(body, "classId", "class_id"),
        sectionName,
        sectionId: optionalNullableStr(body, "sectionId", "section_id"),
        rollNumber,
        convertedBy: auth.claims.sub,
      });
      if (!converted.idempotent) {
        await emitMutationAudit(
          db,
          auth.claims,
          sisAudit.admissionsConverted(converted.studentId, enrollmentId),
          req,
        );
      }
      return converted;
    });
    const status = result.idempotent ? 200 : 201;
    return jsonResponse(envelope(admissionsConversionToApi(result)), { status });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    const mapped = mapConversionError(error);
    if (mapped) return mapped;
    console.error("handleAdmissionsConversion error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to convert admissions enrollment", 500);
  }
}
