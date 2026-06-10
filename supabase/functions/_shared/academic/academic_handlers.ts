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
  academicYearToApi,
  classToApi,
  listEnvelope,
  sectionToApi,
  teacherAssignmentToApi,
} from "./academic_mapper.ts";
import {
  AcademicYearNotFoundError,
  ConcurrentCurrentYearError,
  createAcademicYear,
  DuplicateAcademicYearLabelError,
  listAcademicYearsPage,
  updateAcademicYear,
  ValidationError as AcademicYearValidationError,
  type AcademicYearListFilters,
} from "./academic_years_repository.ts";
import {
  ClassNotFoundError,
  createClass,
  DuplicateClassError,
  listClassesPage,
  updateClass,
  ValidationError as ClassValidationError,
  type ClassListFilters,
} from "./classes_repository.ts";
import {
  createSection,
  DuplicateSectionError,
  getSectionWithClass,
  listSectionsPage,
  SectionNotFoundError,
  updateSection,
  ValidationError as SectionValidationError,
  type SectionListFilters,
} from "./sections_repository.ts";
import {
  createTeacherAssignment,
  DuplicatePrimaryClassTeacherError,
  getTeacherAssignmentWithDetails,
  listTeacherAssignmentsPage,
  TeacherAssignmentNotFoundError,
  updateTeacherAssignment,
  ValidationError as TeacherAssignmentValidationError,
  type TeacherAssignmentListFilters,
  type TeacherAssignmentRole,
} from "./teacher_assignments_repository.ts";

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

function queryParam(url: URL, camel: string, snake: string): string | undefined {
  const value = url.searchParams.get(camel) ?? url.searchParams.get(snake);
  return value?.trim() || undefined;
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

function requireAcademicRead(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "viewSis") ??
    requireSchoolOperationalScope(claims);
}

function requireAcademicWrite(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
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

function optionalBodyBool(
  body: Record<string, unknown>,
  ...keys: string[]
): boolean | undefined {
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

function optionalBodyInt(
  body: Record<string, unknown>,
  ...keys: string[]
): number | undefined {
  for (const key of keys) {
    if (key in body && body[key] != null) {
      const parsed = parseInt(String(body[key]), 10);
      if (!Number.isNaN(parsed)) return parsed;
    }
  }
  return undefined;
}

function optionalNullableInt(
  body: Record<string, unknown>,
  ...keys: string[]
): number | null | undefined {
  for (const key of keys) {
    if (key in body) {
      const value = body[key];
      if (value == null) return null;
      const parsed = parseInt(String(value), 10);
      if (!Number.isNaN(parsed)) return parsed;
    }
  }
  return undefined;
}

function handleTenantError(error: unknown, fallbackMessage: string): Response {
  if (error instanceof TenantDbNotConfiguredError) {
    return tenantDbNotConfiguredResponse(error);
  }
  console.error(fallbackMessage, error);
  return errorEnvelope("INTERNAL_ERROR", fallbackMessage, 500);
}

function mapAcademicYearWriteError(error: unknown): Response | null {
  if (error instanceof AcademicYearNotFoundError) {
    return errorEnvelope("NOT_FOUND", error.message, 404);
  }
  if (error instanceof DuplicateAcademicYearLabelError ||
    error instanceof ConcurrentCurrentYearError) {
    return errorEnvelope("CONFLICT", error.message, 409);
  }
  if (error instanceof AcademicYearValidationError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  return null;
}

function mapClassWriteError(error: unknown): Response | null {
  if (error instanceof ClassNotFoundError) {
    return errorEnvelope("NOT_FOUND", error.message, 404);
  }
  if (error instanceof DuplicateClassError) {
    return errorEnvelope("CONFLICT", error.message, 409);
  }
  if (error instanceof ClassValidationError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  return null;
}

function mapSectionWriteError(error: unknown): Response | null {
  if (error instanceof SectionNotFoundError) {
    return errorEnvelope("NOT_FOUND", error.message, 404);
  }
  if (error instanceof DuplicateSectionError) {
    return errorEnvelope("CONFLICT", error.message, 409);
  }
  if (error instanceof SectionValidationError) {
    if (error.message.includes("Class not found")) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  return null;
}

function mapTeacherAssignmentWriteError(error: unknown): Response | null {
  if (error instanceof TeacherAssignmentNotFoundError) {
    return errorEnvelope("NOT_FOUND", error.message, 404);
  }
  if (error instanceof DuplicatePrimaryClassTeacherError) {
    return errorEnvelope("CONFLICT", error.message, 409);
  }
  if (error instanceof TeacherAssignmentValidationError) {
    if (error.message.includes("Section not found")) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error.message.includes("Teacher is not an active member")) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  return null;
}

function parseTeacherRole(value: string | undefined): TeacherAssignmentRole | null {
  if (!value) return null;
  if (value === "class_teacher" || value === "subject_teacher" || value === "coordinator") {
    return value;
  }
  return null;
}

export async function handleListAcademicYears(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAcademicRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const filters: AcademicYearListFilters = {
    status: queryParam(url, "status", "status"),
    isCurrent: parseOptionalBool(
      url.searchParams.get("isCurrent") ?? url.searchParams.get("is_current"),
    ),
  };
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      listAcademicYearsPage(db, orgId, schoolId, filters, parsePagination(url))
    );
    return jsonResponse(
      envelope(
        listEnvelope(
          result.items.map(academicYearToApi),
          result,
        ),
      ),
    );
  } catch (error) {
    return handleTenantError(error, "Failed to list academic years");
  }
}

export async function handleCreateAcademicYear(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAcademicWrite(auth.claims);
  if (denied) return denied;

  let body: Record<string, unknown> = {};
  try {
    body = (await readJson<Record<string, unknown>>(req)) ?? {};
  } catch {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const yearLabel = optionalBodyStr(body, "yearLabel", "year_label");
  const startDate = optionalBodyStr(body, "startDate", "start_date");
  const endDate = optionalBodyStr(body, "endDate", "end_date");
  if (!yearLabel || !startDate || !endDate) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "yearLabel, startDate, and endDate are required",
      422,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const created = await runTenant(config, auth.claims, (db) =>
      createAcademicYear(db, orgId, schoolId, {
        yearLabel,
        startDate,
        endDate,
        isCurrent: optionalBodyBool(body, "isCurrent", "is_current"),
        status: optionalBodyStr(body, "status"),
        createdBy: auth.claims.sub,
      })
    );
    return jsonResponse(envelope(academicYearToApi(created)), { status: 201 });
  } catch (error) {
    const mapped = mapAcademicYearWriteError(error);
    if (mapped) return mapped;
    return handleTenantError(error, "Failed to create academic year");
  }
}

export async function handleUpdateAcademicYear(
  req: Request,
  config: AppConfig,
  yearId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAcademicWrite(auth.claims);
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
    const updated = await runTenant(config, auth.claims, (db) =>
      updateAcademicYear(db, orgId, schoolId, yearId, {
        yearLabel: optionalBodyStr(body, "yearLabel", "year_label"),
        startDate: optionalBodyStr(body, "startDate", "start_date"),
        endDate: optionalBodyStr(body, "endDate", "end_date"),
        isCurrent: optionalBodyBool(body, "isCurrent", "is_current"),
        status: optionalBodyStr(body, "status"),
      })
    );
    return jsonResponse(envelope(academicYearToApi(updated)));
  } catch (error) {
    const mapped = mapAcademicYearWriteError(error);
    if (mapped) return mapped;
    return handleTenantError(error, "Failed to update academic year");
  }
}

export async function handleListClasses(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAcademicRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const filters: ClassListFilters = {
    academicYearId: queryParam(url, "academicYearId", "academic_year_id"),
    status: queryParam(url, "status", "status"),
  };
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      listClassesPage(db, orgId, schoolId, filters, parsePagination(url))
    );
    return jsonResponse(
      envelope(listEnvelope(result.items.map(classToApi), result)),
    );
  } catch (error) {
    return handleTenantError(error, "Failed to list classes");
  }
}

export async function handleCreateClass(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAcademicWrite(auth.claims);
  if (denied) return denied;

  let body: Record<string, unknown> = {};
  try {
    body = (await readJson<Record<string, unknown>>(req)) ?? {};
  } catch {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const academicYearId = optionalBodyStr(body, "academicYearId", "academic_year_id");
  const className = optionalBodyStr(body, "className", "class_name");
  if (!academicYearId || !className) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "academicYearId and className are required",
      422,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const created = await runTenant(config, auth.claims, (db) =>
      createClass(db, orgId, schoolId, {
        academicYearId,
        className,
        displayOrder: optionalBodyInt(body, "displayOrder", "display_order"),
        status: optionalBodyStr(body, "status"),
        createdBy: auth.claims.sub,
      })
    );
    return jsonResponse(envelope(classToApi(created)), { status: 201 });
  } catch (error) {
    const mapped = mapClassWriteError(error);
    if (mapped) return mapped;
    return handleTenantError(error, "Failed to create class");
  }
}

export async function handleUpdateClass(
  req: Request,
  config: AppConfig,
  classId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAcademicWrite(auth.claims);
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
    const updated = await runTenant(config, auth.claims, (db) =>
      updateClass(db, orgId, schoolId, classId, {
        className: optionalBodyStr(body, "className", "class_name"),
        displayOrder: optionalBodyInt(body, "displayOrder", "display_order"),
        status: optionalBodyStr(body, "status"),
      })
    );
    return jsonResponse(envelope(classToApi(updated)));
  } catch (error) {
    const mapped = mapClassWriteError(error);
    if (mapped) return mapped;
    return handleTenantError(error, "Failed to update class");
  }
}

export async function handleListSections(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAcademicRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const filters: SectionListFilters = {
    classId: queryParam(url, "classId", "class_id"),
    academicYearId: queryParam(url, "academicYearId", "academic_year_id"),
    status: queryParam(url, "status", "status"),
  };
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      listSectionsPage(db, orgId, schoolId, filters, parsePagination(url))
    );
    return jsonResponse(
      envelope(listEnvelope(result.items.map(sectionToApi), result)),
    );
  } catch (error) {
    return handleTenantError(error, "Failed to list sections");
  }
}

export async function handleCreateSection(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAcademicWrite(auth.claims);
  if (denied) return denied;

  let body: Record<string, unknown> = {};
  try {
    body = (await readJson<Record<string, unknown>>(req)) ?? {};
  } catch {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const classId = optionalBodyStr(body, "classId", "class_id");
  const sectionName = optionalBodyStr(body, "sectionName", "section_name");
  if (!classId || !sectionName) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "classId and sectionName are required",
      422,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const created = await runTenant(config, auth.claims, async (db) => {
      const row = await createSection(db, orgId, schoolId, {
        classId,
        sectionName,
        capacity: optionalNullableInt(body, "capacity"),
        strength: optionalBodyInt(body, "strength"),
        status: optionalBodyStr(body, "status"),
        createdBy: auth.claims.sub,
      });
      return await getSectionWithClass(db, orgId, schoolId, row.id) ?? row;
    });
    return jsonResponse(envelope(sectionToApi(created)), { status: 201 });
  } catch (error) {
    const mapped = mapSectionWriteError(error);
    if (mapped) return mapped;
    return handleTenantError(error, "Failed to create section");
  }
}

export async function handleUpdateSection(
  req: Request,
  config: AppConfig,
  sectionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAcademicWrite(auth.claims);
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
    const updated = await runTenant(config, auth.claims, async (db) => {
      await updateSection(db, orgId, schoolId, sectionId, {
        capacity: optionalNullableInt(body, "capacity"),
        strength: optionalBodyInt(body, "strength"),
        status: optionalBodyStr(body, "status"),
      });
      const row = await getSectionWithClass(db, orgId, schoolId, sectionId);
      if (!row) throw new SectionNotFoundError(sectionId);
      return row;
    });
    return jsonResponse(envelope(sectionToApi(updated)));
  } catch (error) {
    const mapped = mapSectionWriteError(error);
    if (mapped) return mapped;
    return handleTenantError(error, "Failed to update section");
  }
}

export async function handleListTeacherAssignments(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAcademicRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const role = parseTeacherRole(queryParam(url, "role", "role"));
  const filters: TeacherAssignmentListFilters = {
    teacherId: queryParam(url, "teacherId", "teacher_id"),
    classId: queryParam(url, "classId", "class_id"),
    sectionId: queryParam(url, "sectionId", "section_id"),
    ...(role ? { role } : {}),
  };
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      listTeacherAssignmentsPage(db, orgId, schoolId, filters, parsePagination(url))
    );
    return jsonResponse(
      envelope(
        listEnvelope(result.items.map(teacherAssignmentToApi), result),
      ),
    );
  } catch (error) {
    return handleTenantError(error, "Failed to list teacher assignments");
  }
}

export async function handleCreateTeacherAssignment(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAcademicWrite(auth.claims);
  if (denied) return denied;

  let body: Record<string, unknown> = {};
  try {
    body = (await readJson<Record<string, unknown>>(req)) ?? {};
  } catch {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const teacherId = optionalBodyStr(body, "teacherId", "teacher_id");
  const sectionId = optionalBodyStr(body, "sectionId", "section_id");
  const role = parseTeacherRole(optionalBodyStr(body, "role"));
  if (!teacherId || !sectionId || !role) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "teacherId, sectionId, and role are required",
      422,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const created = await runTenant(config, auth.claims, async (db) => {
      const row = await createTeacherAssignment(db, orgId, schoolId, {
        teacherId,
        sectionId,
        role,
        isPrimary: optionalBodyBool(body, "isPrimary", "is_primary"),
        createdBy: auth.claims.sub,
      });
      const detail = await getTeacherAssignmentWithDetails(db, orgId, schoolId, row.id);
      if (!detail) throw new TeacherAssignmentNotFoundError(row.id);
      return detail;
    });
    return jsonResponse(envelope(teacherAssignmentToApi(created)), { status: 201 });
  } catch (error) {
    const mapped = mapTeacherAssignmentWriteError(error);
    if (mapped) return mapped;
    return handleTenantError(error, "Failed to create teacher assignment");
  }
}

export async function handleUpdateTeacherAssignment(
  req: Request,
  config: AppConfig,
  assignmentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAcademicWrite(auth.claims);
  if (denied) return denied;

  let body: Record<string, unknown> = {};
  try {
    body = (await readJson<Record<string, unknown>>(req)) ?? {};
  } catch {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const roleValue = optionalBodyStr(body, "role");
  let role: TeacherAssignmentRole | undefined;
  if (roleValue) {
    const parsed = parseTeacherRole(roleValue);
    if (!parsed) {
      return errorEnvelope("VALIDATION_ERROR", "Invalid role value", 422);
    }
    role = parsed;
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const updated = await runTenant(config, auth.claims, async (db) => {
      await updateTeacherAssignment(db, orgId, schoolId, assignmentId, {
        teacherId: optionalBodyStr(body, "teacherId", "teacher_id"),
        sectionId: optionalBodyStr(body, "sectionId", "section_id"),
        role,
        isPrimary: optionalBodyBool(body, "isPrimary", "is_primary"),
      });
      const row = await getTeacherAssignmentWithDetails(db, orgId, schoolId, assignmentId);
      if (!row) throw new TeacherAssignmentNotFoundError(assignmentId);
      return row;
    });
    return jsonResponse(envelope(teacherAssignmentToApi(updated)));
  } catch (error) {
    const mapped = mapTeacherAssignmentWriteError(error);
    if (mapped) return mapped;
    return handleTenantError(error, "Failed to update teacher assignment");
  }
}
