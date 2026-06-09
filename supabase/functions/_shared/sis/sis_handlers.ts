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
  InvalidStudentStatusError,
  InvalidStudentStatusTransitionError,
} from "./sis_status_codec.ts";
import {
  listEnvelope,
  studentDetailToApi,
  studentDirectoryItemToApi,
} from "./sis_mapper.ts";
import type {
  CreateStudentInput,
  StudentListFilters,
  UpdateStudentInput,
} from "./sis_students_repository.ts";
import {
  createStudent,
  DuplicateAdmissionNumberError,
  getStudent,
  listStudents,
  StudentNotFoundError,
  updateStudent,
  updateStudentStatus,
  ValidationError,
} from "./sis_students_repository.ts";

function parsePagination(url: URL): { page: number; pageSize: number } {
  const page = Math.max(1, parseInt(url.searchParams.get("page") ?? "1", 10) || 1);
  const pageSize = Math.min(
    100,
    Math.max(1, parseInt(url.searchParams.get("pageSize") ?? "20", 10) || 20),
  );
  return { page, pageSize };
}

function parseListFilters(url: URL): StudentListFilters {
  const get = (camel: string, snake: string): string | undefined => {
    const value = url.searchParams.get(camel) ?? url.searchParams.get(snake);
    return value?.trim() || undefined;
  };

  return {
    search: get("search", "search") ?? get("q", "q"),
    academicYear: get("academicYear", "academic_year"),
    className: get("className", "class_name"),
    sectionName: get("sectionName", "section_name"),
    status: get("status", "status"),
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

function parseCreateStudentInput(
  body: Record<string, unknown>,
  createdBy: string,
): CreateStudentInput | null {
  const displayName = optionalBodyStr(body, "displayName", "display_name", "studentName", "student_name");
  const admissionNumber = optionalBodyStr(body, "admissionNumber", "admission_number");
  if (!displayName || !admissionNumber) return null;

  return {
    displayName,
    admissionNumber,
    dateOfBirth: optionalNullableStr(body, "dateOfBirth", "date_of_birth"),
    gender: optionalNullableStr(body, "gender"),
    bloodGroup: optionalNullableStr(body, "bloodGroup", "blood_group"),
    address: optionalNullableStr(body, "address"),
    city: optionalNullableStr(body, "city"),
    state: optionalNullableStr(body, "state"),
    postalCode: optionalNullableStr(body, "postalCode", "postal_code"),
    country: optionalNullableStr(body, "country"),
    status: optionalBodyStr(body, "status"),
    createdBy,
  };
}

function parseUpdateStudentInput(body: Record<string, unknown>): UpdateStudentInput {
  return {
    displayName: optionalBodyStr(body, "displayName", "display_name", "studentName", "student_name"),
    status: optionalBodyStr(body, "status"),
    admissionNumber: optionalBodyStr(body, "admissionNumber", "admission_number"),
    dateOfBirth: optionalNullableStr(body, "dateOfBirth", "date_of_birth"),
    gender: optionalNullableStr(body, "gender"),
    bloodGroup: optionalNullableStr(body, "bloodGroup", "blood_group"),
    address: optionalNullableStr(body, "address"),
    city: optionalNullableStr(body, "city"),
    state: optionalNullableStr(body, "state"),
    postalCode: optionalNullableStr(body, "postalCode", "postal_code"),
    country: optionalNullableStr(body, "country"),
  };
}

function mapWriteError(error: unknown): Response | null {
  if (error instanceof StudentNotFoundError) {
    return errorEnvelope("NOT_FOUND", error.message, 404);
  }
  if (error instanceof DuplicateAdmissionNumberError) {
    return errorEnvelope("CONFLICT", error.message, 409);
  }
  if (error instanceof ValidationError || error instanceof InvalidStudentStatusError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  if (error instanceof InvalidStudentStatusTransitionError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  return null;
}

export async function handleListStudents(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireSisRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const pagination = parsePagination(url);
  const filters = parseListFilters(url);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      listStudents(db, orgId, schoolId, filters, pagination)
    );
    return jsonResponse(
      envelope(
        listEnvelope(
          result.items.map(studentDirectoryItemToApi),
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
    console.error("handleListStudents error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to list students", 500);
  }
}

export async function handleGetStudent(
  req: Request,
  config: AppConfig,
  studentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireSisRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const detail = await runTenant(config, auth.claims, (db) =>
      getStudent(db, orgId, schoolId, studentId)
    );
    if (!detail) {
      return errorEnvelope("NOT_FOUND", `Student not found: ${studentId}`, 404);
    }
    return jsonResponse(envelope(studentDetailToApi(detail)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof StudentNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    console.error("handleGetStudent error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load student", 500);
  }
}

export async function handleCreateStudent(
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

  const input = parseCreateStudentInput(body, auth.claims.sub);
  if (!input) {
    return errorEnvelope("VALIDATION_ERROR", "displayName and admissionNumber are required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const detail = await runTenant(config, auth.claims, (db) =>
      createStudent(db, orgId, schoolId, input)
    );
    return jsonResponse(envelope(studentDetailToApi(detail)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    const mapped = mapWriteError(error);
    if (mapped) return mapped;
    console.error("handleCreateStudent error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to create student", 500);
  }
}

export async function handleUpdateStudent(
  req: Request,
  config: AppConfig,
  studentId: string,
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
    const detail = await runTenant(config, auth.claims, (db) =>
      updateStudent(db, orgId, schoolId, studentId, parseUpdateStudentInput(body))
    );
    return jsonResponse(envelope(studentDetailToApi(detail)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    const mapped = mapWriteError(error);
    if (mapped) return mapped;
    console.error("handleUpdateStudent error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to update student", 500);
  }
}

export async function handleUpdateStudentStatus(
  req: Request,
  config: AppConfig,
  studentId: string,
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

  const status = optionalBodyStr(body, "status");
  if (!status) {
    return errorEnvelope("VALIDATION_ERROR", "status is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const detail = await runTenant(config, auth.claims, (db) =>
      updateStudentStatus(db, orgId, schoolId, studentId, { status })
    );
    return jsonResponse(envelope(studentDetailToApi(detail)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    const mapped = mapWriteError(error);
    if (mapped) return mapped;
    console.error("handleUpdateStudentStatus error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to update student status", 500);
  }
}
