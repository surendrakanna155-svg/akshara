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
  InvalidStudentStatusError,
  InvalidStudentStatusTransitionError,
} from "./sis_status_codec.ts";
import { StudentNotFoundError } from "./sis_students_repository.ts";
import { resolveStudentId } from "./sis_student_resolver.ts";
import {
  certificateDataToApi,
  certificateIssueToApi,
  InvalidCertificateTypeError,
  issueCertificate,
  issueTransferCertificate,
  listCertificateIssues,
  NoDuesPendingError,
} from "./sis_certificates_repository.ts";

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

/**
 * SIS-1 — GET /sis/students/{id}/certificates. The issuance register for a
 * student (viewSis + school scope). Newest first. 404 when the student is not in
 * the caller's school scope.
 */
export async function handleListCertificates(
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
      const rows = await listCertificateIssues(db, orgId, schoolId, resolved);
      return rows.map(certificateIssueToApi);
    });
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof StudentNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    console.error("handleListCertificates error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to list certificates", 500);
  }
}

/**
 * SIS-1 — POST /sis/students/{id}/certificates. Records a bonafide/study/conduct
 * certificate issuance and returns the certificate data for the client PDF
 * (manageSis + school scope). Body: { type, reason? }. `transfer` is rejected
 * here (422) — it MUST go through the transfer-certificate engine so the no-dues
 * gate can never be bypassed.
 */
export async function handleIssueCertificate(
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

  const type = optionalStr(body, "type", "certificateType", "certificate_type");
  if (!type) {
    return errorEnvelope("VALIDATION_ERROR", "type is required", 422);
  }
  const reason = optionalStr(body, "reason", "note");

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const data = await runTenant(config, auth.claims, async (db) => {
      const resolved = await resolveStudentId(db, orgId, schoolId, studentIdOrCode);
      if (!resolved) throw new StudentNotFoundError(studentIdOrCode);
      const cert = await issueCertificate(db, orgId, schoolId, {
        studentId: resolved,
        type,
        reason: reason ?? null,
        issuedBy: auth.claims.sub,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        sisAudit.certificateIssued(cert.issueId, resolved, cert.certificateType),
        req,
      );
      return cert;
    });
    return jsonResponse(envelope(certificateDataToApi(data)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof StudentNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof InvalidCertificateTypeError) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    console.error("handleIssueCertificate error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to issue certificate", 500);
  }
}

/**
 * SIS-D1 — POST /sis/students/{id}/transfer-certificate. The TC engine, one
 * transaction (manageSis + school scope). Body: { reason }. Enforces the Finance
 * no-dues gate (409 DUES_PENDING with the outstanding amount when the student
 * still owes fees — nothing is written), allocates a per-school sequential TC
 * serial, records the transfer issuance, and auto-sets the student's status to
 * transferred. An already-terminal student (transferred/graduated) is a 422.
 */
export async function handleIssueTransferCertificate(
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

  const reason = optionalStr(body, "reason", "note");

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      const resolved = await resolveStudentId(db, orgId, schoolId, studentIdOrCode);
      if (!resolved) throw new StudentNotFoundError(studentIdOrCode);
      const tc = await issueTransferCertificate(db, orgId, schoolId, {
        studentId: resolved,
        reason: reason ?? null,
        issuedBy: auth.claims.sub,
      });
      // Audit INSIDE the same transaction: a rollback (e.g. a late failure)
      // discards the audit too, so the trail only ever reflects committed TCs.
      await emitMutationAudit(
        db,
        auth.claims,
        sisAudit.transferCertificateIssued(
          tc.certificate.issueId,
          resolved,
          tc.serialNo,
          reason ?? null,
        ),
        req,
      );
      return tc;
    });
    return jsonResponse(
      envelope(certificateDataToApi(result.certificate)),
      { status: 201 },
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof StudentNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof NoDuesPendingError) {
      // 409 DUES_PENDING — the message carries the outstanding amount. Nothing
      // was written: the gate throws before any serial/row/status change.
      return errorEnvelope("DUES_PENDING", error.message, 409);
    }
    if (
      error instanceof InvalidStudentStatusTransitionError ||
      error instanceof InvalidStudentStatusError
    ) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    console.error("handleIssueTransferCertificate error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to issue transfer certificate", 500);
  }
}
