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
  createStudentDocument,
  documentToApi,
  listStudentDocuments,
} from "./sis_documents_repository.ts";
import { resolveStudentId } from "./sis_student_resolver.ts";
import { StudentNotFoundError } from "./sis_students_repository.ts";

function requireSisRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewSis") ??
    requireSchoolOperationalScope(claims);
}

function requireSisWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageSis") ??
    requireSchoolOperationalScope(claims);
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

function optionalStr(body: Record<string, unknown>, ...keys: string[]): string | undefined {
  for (const key of keys) {
    const value = body[key];
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return undefined;
}

export async function handleListStudentDocuments(
  req: Request,
  config: AppConfig,
  studentIdOrCode: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireSisRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const items = await runTenant(config, auth.claims, async (db) => {
      const resolved = await resolveStudentId(db, orgId, schoolId, studentIdOrCode);
      if (!resolved) throw new StudentNotFoundError(studentIdOrCode);
      const rows = await listStudentDocuments(db, orgId, schoolId, resolved);
      return rows.map(documentToApi);
    });
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof StudentNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    console.error("handleListStudentDocuments error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to list student documents", 500);
  }
}

export async function handleUploadStudentDocument(
  req: Request,
  config: AppConfig,
  studentIdOrCode: string,
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

  const documentType = optionalStr(body, "type", "documentType", "document_type");
  if (!documentType) {
    return errorEnvelope("VALIDATION_ERROR", "type is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const fileUri = optionalStr(body, "fileUri", "file_uri", "fileName", "file_name");

  try {
    const created = await runTenant(config, auth.claims, async (db) => {
      const resolved = await resolveStudentId(db, orgId, schoolId, studentIdOrCode);
      if (!resolved) throw new StudentNotFoundError(studentIdOrCode);
      const row = await createStudentDocument(db, orgId, schoolId, resolved, {
        documentType,
        status: optionalStr(body, "status") ?? "pending",
        fileUri: fileUri ? `storage://documents/${fileUri}` : null,
        uploadedBy: auth.claims.sub,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        sisAudit.studentUpdated(resolved),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(documentToApi(created)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof StudentNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    console.error("handleUploadStudentDocument error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to upload student document", 500);
  }
}
