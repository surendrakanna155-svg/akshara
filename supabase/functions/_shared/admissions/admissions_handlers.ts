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
  applicationToApi,
  approvalToApi,
  documentToApi,
  enrollmentToApi,
  leadToApi,
  listEnvelope,
} from "./admissions_mapper.ts";
import {
  createApplication,
  createLead,
  ensureApprovalForApplication,
  getApplicationById,
  getApprovalById,
  getDocumentById,
  getLeadById,
  listApplications,
  listDocuments,
  listLeads,
  reviewDocument,
  setApprovalDecision,
  submitApplication,
  submitEnrollment,
  updateApplication,
  updateLead,
  uploadDocument,
} from "./admissions_repository.ts";

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

function optionalSnakeStr(
  body: Record<string, unknown>,
  key: string,
): string | undefined {
  if (!(key in body) || body[key] === undefined || body[key] === null) {
    return undefined;
  }
  return String(body[key]);
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  try {
    return await withTenantContext(config, claims, operation);
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      throw error;
    }
    throw error;
  }
}

// ─── Leads (Slice 1) ─────────────────────────────────────────────────────────

export async function handleListLeads(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const pagination = parsePagination(url);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      listLeads(db, orgId, schoolId, pagination)
    );
    return jsonResponse(
      envelope(
        listEnvelope(
          result.items.map(leadToApi),
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

export async function handleGetLead(
  req: Request,
  config: AppConfig,
  leadId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const lead = await runTenant(config, auth.claims, (db) =>
      getLeadById(db, orgId, schoolId, leadId)
    );
    if (!lead) {
      return errorEnvelope("NOT_FOUND", `Lead not found: ${leadId}`, 404);
    }
    return jsonResponse(envelope(leadToApi(lead)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

export async function handleCreateLead(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "manageAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const parentName = snakeStr(body, "parent_name");
  const studentName = snakeStr(body, "student_name");
  const classLabel = snakeStr(body, "class_label");
  const phone = snakeStr(body, "phone");

  if (!parentName || !studentName || !classLabel || !phone) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "parent_name, student_name, class_label, and phone are required",
      422,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const lead = await runTenant(config, auth.claims, (db) =>
      createLead(db, orgId, schoolId, {
        parentName,
        studentName,
        classLabel,
        phone,
        source: snakeStr(body, "source") || "website",
        campaign: snakeStr(body, "campaign"),
        counselor: snakeStr(body, "counselor"),
        email: snakeStr(body, "email"),
        address: snakeStr(body, "address"),
        notes: snakeStr(body, "notes"),
      })
    );
    return jsonResponse(envelope(leadToApi(lead)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

export async function handleUpdateLead(
  req: Request,
  config: AppConfig,
  leadId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "manageAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const lead = await runTenant(config, auth.claims, (db) =>
      updateLead(db, orgId, schoolId, leadId, {
        parentName: optionalSnakeStr(body, "parent_name"),
        studentName: optionalSnakeStr(body, "student_name"),
        classLabel: optionalSnakeStr(body, "class_label"),
        phone: optionalSnakeStr(body, "phone"),
        source: optionalSnakeStr(body, "source"),
        campaign: optionalSnakeStr(body, "campaign"),
        email: optionalSnakeStr(body, "email"),
        address: optionalSnakeStr(body, "address"),
        notes: optionalSnakeStr(body, "notes"),
      })
    );
    if (!lead) {
      return errorEnvelope("NOT_FOUND", `Lead not found: ${leadId}`, 404);
    }
    return jsonResponse(envelope(leadToApi(lead)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

// ─── Applications (Slice 2) ──────────────────────────────────────────────────

export async function handleListApplications(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const pagination = parsePagination(url);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      listApplications(db, orgId, schoolId, pagination)
    );
    return jsonResponse(
      envelope(
        listEnvelope(
          result.items.map(applicationToApi),
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

export async function handleGetApplication(
  req: Request,
  config: AppConfig,
  applicationId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const app = await runTenant(config, auth.claims, (db) =>
      getApplicationById(db, orgId, schoolId, applicationId)
    );
    if (!app) {
      return errorEnvelope("NOT_FOUND", `Application not found: ${applicationId}`, 404);
    }
    return jsonResponse(envelope(applicationToApi(app)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

export async function handleCreateApplication(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "manageAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const studentName = snakeStr(body, "student_name");
  const classLabel = snakeStr(body, "class_label");
  const parentName = snakeStr(body, "parent_name");
  if (!studentName || !classLabel || !parentName) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "student_name, class_label, and parent_name are required",
      422,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const leadId = optionalSnakeStr(body, "lead_id") ?? null;

  try {
    const app = await runTenant(config, auth.claims, (db) =>
      createApplication(db, orgId, schoolId, {
        studentName,
        classLabel,
        parentName,
        leadId,
        counselor: snakeStr(body, "counselor"),
      })
    );
    return jsonResponse(envelope(applicationToApi(app)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

export async function handleUpdateApplication(
  req: Request,
  config: AppConfig,
  applicationId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "manageAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const app = await runTenant(config, auth.claims, (db) =>
      updateApplication(db, orgId, schoolId, applicationId, {
        studentName: optionalSnakeStr(body, "student_name"),
        classLabel: optionalSnakeStr(body, "class_label"),
        parentName: optionalSnakeStr(body, "parent_name"),
        counselor: optionalSnakeStr(body, "counselor"),
        status: optionalSnakeStr(body, "status"),
      })
    );
    if (!app) {
      return errorEnvelope("NOT_FOUND", `Application not found: ${applicationId}`, 404);
    }
    return jsonResponse(envelope(applicationToApi(app)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

export async function handleSubmitApplication(
  req: Request,
  config: AppConfig,
  applicationId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "manageAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const app = await runTenant(config, auth.claims, async (db) => {
      const submitted = await submitApplication(
        db,
        orgId,
        schoolId,
        applicationId,
      );
      if (!submitted) return null;
      await ensureApprovalForApplication(db, orgId, schoolId, applicationId);
      return await getApplicationById(db, orgId, schoolId, applicationId);
    });
    if (!app) {
      return errorEnvelope(
        "NOT_FOUND",
        `Application not found or not in draft: ${applicationId}`,
        404,
      );
    }
    return jsonResponse(envelope(applicationToApi(app)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

// ─── Documents (Slice 3) ─────────────────────────────────────────────────────

export async function handleListDocuments(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const pagination = parsePagination(url);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      listDocuments(db, orgId, schoolId, pagination)
    );
    return jsonResponse(
      envelope(
        listEnvelope(
          result.items.map(documentToApi),
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

export async function handleUploadDocument(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "manageAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const leadId = snakeStr(body, "lead_id");
  const documentType = snakeStr(body, "document_type");
  const fileName = snakeStr(body, "file_name");
  if (!leadId || !documentType || !fileName) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "lead_id, document_type, and file_name are required",
      422,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const doc = await runTenant(config, auth.claims, (db) =>
      uploadDocument(db, orgId, schoolId, {
        leadId,
        documentType,
        fileName,
        studentName: snakeStr(body, "student_name"),
        classLabel: snakeStr(body, "class_label"),
      })
    );
    return jsonResponse(envelope(documentToApi(doc)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

export async function handleApproveDocument(
  req: Request,
  config: AppConfig,
  documentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "approveAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req) ?? {};
  const { claims } = auth;
  const orgId = organizationIdFromClaims(claims);
  const schoolId = schoolIdFromClaims(claims);
  const note = snakeStr(body, "note");

  try {
    const doc = await runTenant(config, claims, (db) =>
      reviewDocument(
        db,
        orgId,
        schoolId,
        documentId,
        "verified",
        claims.sub,
        note,
      )
    );
    if (!doc) {
      return errorEnvelope("NOT_FOUND", `Document not found: ${documentId}`, 404);
    }
    return jsonResponse(envelope(documentToApi(doc)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

export async function handleRejectDocument(
  req: Request,
  config: AppConfig,
  documentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "approveAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req) ?? {};
  const { claims } = auth;
  const orgId = organizationIdFromClaims(claims);
  const schoolId = schoolIdFromClaims(claims);
  const note = snakeStr(body, "note");

  try {
    const doc = await runTenant(config, claims, (db) =>
      reviewDocument(
        db,
        orgId,
        schoolId,
        documentId,
        "rejected",
        claims.sub,
        note,
      )
    );
    if (!doc) {
      return errorEnvelope("NOT_FOUND", `Document not found: ${documentId}`, 404);
    }
    return jsonResponse(envelope(documentToApi(doc)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

// ─── Approval + Enrollment (Slice 4) ───────────────────────────────────────

export async function handleApproveAdmission(
  req: Request,
  config: AppConfig,
  approvalId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "approveAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const approval = await runTenant(config, auth.claims, (db) =>
      setApprovalDecision(db, orgId, schoolId, approvalId, "approved")
    );
    if (!approval) {
      return errorEnvelope("NOT_FOUND", `Approval not found: ${approvalId}`, 404);
    }
    return jsonResponse(envelope(approvalToApi(approval)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

export async function handleRejectAdmission(
  req: Request,
  config: AppConfig,
  approvalId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "approveAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const approval = await runTenant(config, auth.claims, (db) =>
      setApprovalDecision(db, orgId, schoolId, approvalId, "rejected")
    );
    if (!approval) {
      return errorEnvelope("NOT_FOUND", `Approval not found: ${approvalId}`, 404);
    }
    return jsonResponse(envelope(approvalToApi(approval)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

export async function handleSubmitEnrollment(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "manageAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const student = (body.student as Record<string, unknown>) ?? {};
  const parent = (body.parent as Record<string, unknown>) ?? {};
  const academic = (body.academic as Record<string, unknown>) ?? {};

  const studentFullName = String(student.full_name ?? "");
  const guardianName = String(parent.guardian_name ?? "");
  const seekingClass = String(academic.seeking_class ?? "");

  if (!studentFullName || !guardianName || !seekingClass) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "student.full_name, parent.guardian_name, and academic.seeking_class are required",
      422,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const enrollment = await runTenant(config, auth.claims, (db) =>
      submitEnrollment(db, orgId, schoolId, {
        applicationId: optionalSnakeStr(body, "application_id") ?? null,
        studentFullName,
        dateOfBirth: String(student.date_of_birth ?? ""),
        gender: String(student.gender ?? ""),
        aadhaar: String(student.aadhaar ?? ""),
        guardianName,
        relationship: String(parent.relationship ?? "guardian"),
        phone: String(parent.phone ?? ""),
        email: String(parent.email ?? ""),
        address: String(parent.address ?? ""),
        seekingClass,
        section: String(academic.section ?? ""),
        academicYear: String(academic.academic_year ?? ""),
        previousSchool: String(academic.previous_school ?? ""),
        needsTransport: Boolean(academic.needs_transport),
        needsHostel: Boolean(academic.needs_hostel),
      })
    );
    return jsonResponse(envelope(enrollmentToApi(enrollment)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}
