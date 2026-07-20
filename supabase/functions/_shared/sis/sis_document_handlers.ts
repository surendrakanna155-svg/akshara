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
  buildStudentDocumentStoragePath,
  createStudentDocumentDownloadUrl,
  createStudentDocumentUploadUrl,
  STUDENT_DOCUMENT_UPLOAD_CONSTRAINTS,
  validateUpload,
} from "../storage/storage_service.ts";
import {
  createStudentDocument,
  documentToApi,
  getStudentDocumentStoragePath,
  listStudentDocuments,
  StudentDocumentNotFoundError,
  verifyStudentDocument,
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

/**
 * PRA-P1-19 — presign a direct-to-Storage upload for a student document. Mirrors
 * the admissions presign flow: the client PUTs the file bytes to the returned
 * signed URL, then confirms via POST /sis/students/{id}/documents with the
 * resulting storage_path. Type + size are enforced here BEFORE a URL is minted.
 */
export async function handlePresignStudentDocumentUpload(
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

  const fileName = optionalStr(body, "fileName", "file_name");
  if (!fileName) {
    return errorEnvelope("VALIDATION_ERROR", "file_name is required", 422);
  }
  // Reject wrong-type / oversized uploads at presign (the bucket enforces too).
  const uploadError = validateUpload(
    fileName,
    {
      contentType: optionalStr(body, "contentType", "content_type") ?? null,
      sizeBytes: body.size_bytes == null && body.sizeBytes == null
        ? null
        : Number(body.size_bytes ?? body.sizeBytes),
    },
    STUDENT_DOCUMENT_UPLOAD_CONSTRAINTS,
  );
  if (uploadError) {
    return errorEnvelope("VALIDATION_ERROR", uploadError, 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const resolved = await runTenant(config, auth.claims, (db) =>
      resolveStudentId(db, orgId, schoolId, studentIdOrCode));
    if (!resolved) throw new StudentNotFoundError(studentIdOrCode);
    const storagePath = buildStudentDocumentStoragePath(
      orgId,
      schoolId,
      resolved,
      fileName,
    );
    const upload = await createStudentDocumentUploadUrl(config, storagePath);
    return jsonResponse(envelope({
      signedUrl: upload.signedUrl,
      token: upload.token,
      storagePath: upload.path,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof StudentNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    const message = error instanceof Error ? error.message : "Presign failed";
    return errorEnvelope("SIS_UPLOAD_ERROR", message, 500);
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
  // The human file name is kept as a display label; the REAL retrievable object
  // is `storage_path`.
  const fileName = optionalStr(body, "fileName", "file_name", "fileUri", "file_uri");
  const storagePath = optionalStr(body, "storagePath", "storage_path");

  // PRA-P1-19: a document is only "uploaded" once a real file is stored. The
  // client first presigns + PUTs the bytes, then confirms here with the
  // resulting storage_path. No fabricated metadata-only fallback.
  if (!storagePath) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "storage_path is required — upload the file via /sis/students/{id}/documents/presign first",
      422,
    );
  }
  // Guard: the stored object must live under this tenant's prefix.
  if (!storagePath.startsWith(`${orgId}/${schoolId}/`)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "storage_path is not scoped to this tenant",
      422,
    );
  }

  try {
    const created = await runTenant(config, auth.claims, async (db) => {
      const resolved = await resolveStudentId(db, orgId, schoolId, studentIdOrCode);
      if (!resolved) throw new StudentNotFoundError(studentIdOrCode);
      const row = await createStudentDocument(db, orgId, schoolId, resolved, {
        documentType,
        status: optionalStr(body, "status") ?? "pending",
        fileUri: fileName ?? null,
        storagePath,
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

/**
 * PRA-P1-19 — GET /sis/students/{id}/documents/{docId}/download. Returns a
 * short-lived signed URL so a verifier can open the stored document. 404 when
 * the row has no stored object (legacy metadata-only) or is out of scope.
 */
export async function handleDownloadStudentDocument(
  req: Request,
  config: AppConfig,
  _studentIdOrCode: string,
  docId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireSisRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const path = await runTenant(config, auth.claims, (db) =>
      getStudentDocumentStoragePath(db, orgId, schoolId, docId));
    if (!path) {
      return errorEnvelope("NOT_FOUND", `No stored file for document: ${docId}`, 404);
    }
    const downloadUrl = await createStudentDocumentDownloadUrl(config, path);
    return jsonResponse(envelope({ downloadUrl }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    const message = error instanceof Error ? error.message : "Download URL failed";
    return errorEnvelope("SIS_ERROR", message, 500);
  }
}

/**
 * SIS-3 — PATCH /sis/students/{id}/documents/{docId}/verify. Marks a document
 * verified or rejected (manageSis + school scope). Body: { status:
 * 'verified'|'rejected', note? }. 404 when the student or document is not in the
 * caller's school scope.
 */
export async function handleVerifyStudentDocument(
  req: Request,
  config: AppConfig,
  studentIdOrCode: string,
  docId: string,
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

  const rawStatus = optionalStr(body, "status");
  if (rawStatus !== "verified" && rawStatus !== "rejected") {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "status must be 'verified' or 'rejected'",
      422,
    );
  }
  const note = optionalStr(body, "note", "reason");

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const verified = await runTenant(config, auth.claims, async (db) => {
      const resolved = await resolveStudentId(db, orgId, schoolId, studentIdOrCode);
      if (!resolved) throw new StudentNotFoundError(studentIdOrCode);
      const row = await verifyStudentDocument(db, orgId, schoolId, docId, {
        status: rawStatus,
        verifierId: auth.claims.sub,
        note: note ?? null,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        sisAudit.documentVerified(row.id, resolved, rawStatus, note),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(documentToApi(verified)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof StudentNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof StudentDocumentNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    console.error("handleVerifyStudentDocument error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to verify student document", 500);
  }
}
