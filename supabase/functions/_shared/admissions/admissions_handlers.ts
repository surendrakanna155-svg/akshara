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
  admissionsAudit,
  emitMutationAudit,
} from "../audit/mutation_audit_catalog.ts";
import {
  applicationToApi,
  approvalToApi,
  documentToApi,
  enrollmentToApi,
  followUpToApi,
  handoffToApi,
  leadActivityToApi,
  leadToApi,
  listEnvelope,
} from "./admissions_mapper.ts";
import {
  listFeeHandoffs,
  sendHandoffToFinance,
  updateHandoffStatus,
} from "./admissions_handoffs_repository.ts";
import {
  ADMISSIONS_UPLOAD_CONSTRAINTS,
  buildAdmissionsDocumentStoragePath,
  createAdmissionsDocumentDownloadUrl,
  createAdmissionsDocumentUploadUrl,
  validateUpload,
} from "../storage/storage_service.ts";
import {
  addLeadActivity,
  addLeadFollowUp,
  assignLeadCounselor,
  changeLeadStage,
  createApplication,
  createLead,
  ensureApprovalForApplication,
  getApplicationById,
  getApprovalById,
  getDocumentById,
  getDocumentStoragePath,
  getLeadById,
  listApplications,
  listDocuments,
  listLeadActivities,
  listLeadFollowUps,
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
    const detail = await runTenant(config, auth.claims, async (db) => {
      const lead = await getLeadById(db, orgId, schoolId, leadId);
      if (!lead) return null;
      const activities = await listLeadActivities(db, orgId, schoolId, leadId);
      const followUps = await listLeadFollowUps(db, orgId, schoolId, leadId);
      return { lead, activities, followUps };
    });
    if (!detail) {
      return errorEnvelope("NOT_FOUND", `Lead not found: ${leadId}`, 404);
    }
    return jsonResponse(
      envelope({
        ...leadToApi(detail.lead),
        activities: detail.activities.map(leadActivityToApi),
        followUps: detail.followUps.map(followUpToApi),
      }),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

function humanizeStage(stage: string): string {
  return stage
    .split(/[_\s]+/)
    .filter((part) => part.length > 0)
    .map((part) => part[0].toUpperCase() + part.slice(1))
    .join(" ");
}

export async function handleAssignLeadCounselor(
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
  const counselor = snakeStr(body, "counselor");
  if (!counselor) {
    return errorEnvelope("VALIDATION_ERROR", "counselor is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const lead = await runTenant(config, auth.claims, async (db) => {
      const updated = await assignLeadCounselor(db, orgId, schoolId, leadId, counselor);
      if (!updated) return null;
      const activity = await addLeadActivity(db, orgId, schoolId, leadId, {
        activityType: "assignment",
        title: `Assigned to ${counselor}`,
        description: `Lead assigned to counselor ${counselor}.`,
        actor: counselor,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        admissionsAudit.leadAssigned(leadId, counselor, activity.id),
        req,
      );
      return updated;
    });
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

export async function handleChangeLeadStage(
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
  const stage = snakeStr(body, "stage");
  if (!stage) {
    return errorEnvelope("VALIDATION_ERROR", "stage is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const lead = await runTenant(config, auth.claims, async (db) => {
      const updated = await changeLeadStage(db, orgId, schoolId, leadId, stage);
      if (!updated) return null;
      const activity = await addLeadActivity(db, orgId, schoolId, leadId, {
        activityType: "stageChange",
        title: `Stage moved to ${humanizeStage(stage)}`,
        description: `Pipeline stage updated to ${humanizeStage(stage)}.`,
        actor: updated.counselor || auth.claims.primary_role,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        admissionsAudit.leadStageChanged(leadId, stage, activity.id),
        req,
      );
      return updated;
    });
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

export async function handleAddLeadFollowUp(
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
  const task = snakeStr(body, "task");
  if (!task) {
    return errorEnvelope("VALIDATION_ERROR", "task is required", 422);
  }
  const scheduledLabel = snakeStr(body, "scheduled_label");
  const outcome = snakeStr(body, "outcome");
  const counselor = snakeStr(body, "counselor");

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      const lead = await getLeadById(db, orgId, schoolId, leadId);
      if (!lead) return null;
      const followUp = await addLeadFollowUp(db, orgId, schoolId, leadId, {
        task,
        scheduledLabel,
        outcome,
        counselor: counselor || lead.counselor,
      });
      await addLeadActivity(db, orgId, schoolId, leadId, {
        activityType: "followUp",
        title: scheduledLabel
          ? `Follow-up scheduled · ${scheduledLabel}`
          : "Follow-up logged",
        description: task,
        actor: counselor || lead.counselor || auth.claims.primary_role,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        admissionsAudit.leadFollowUpAdded(leadId, followUp.id),
        req,
      );
      return followUp;
    });
    if (!result) {
      return errorEnvelope("NOT_FOUND", `Lead not found: ${leadId}`, 404);
    }
    return jsonResponse(envelope(followUpToApi(result)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

export async function handleAddLeadNote(
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
  const content = snakeStr(body, "content");
  if (!content) {
    return errorEnvelope("VALIDATION_ERROR", "content is required", 422);
  }
  // Optional activity_type lets the same endpoint log notes, WhatsApp sends and
  // call records onto the unified timeline (wa.me deep-link only, no Meta API).
  const activityTypeRaw = snakeStr(body, "activity_type") || "note";
  const allowedTypes = ["note", "whatsapp", "call"];
  const activityType = allowedTypes.includes(activityTypeRaw)
    ? activityTypeRaw
    : "note";
  const defaultTitle = activityType === "whatsapp"
    ? "WhatsApp message logged"
    : activityType === "call"
    ? "Call logged"
    : "Note added";
  const title = snakeStr(body, "title") || defaultTitle;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      const lead = await getLeadById(db, orgId, schoolId, leadId);
      if (!lead) return null;
      const activity = await addLeadActivity(db, orgId, schoolId, leadId, {
        activityType,
        title,
        description: content,
        actor: lead.counselor || auth.claims.primary_role,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        admissionsAudit.leadNoteAdded(leadId, activity.id, activityType),
        req,
      );
      return activity;
    });
    if (!result) {
      return errorEnvelope("NOT_FOUND", `Lead not found: ${leadId}`, 404);
    }
    return jsonResponse(envelope(leadActivityToApi(result)), { status: 201 });
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
    const lead = await runTenant(config, auth.claims, async (db) => {
      const created = await createLead(db, orgId, schoolId, {
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
      });
      await emitMutationAudit(
        db,
        auth.claims,
        admissionsAudit.leadCreated(created.id, created.source),
        req,
      );
      return created;
    });
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
    const lead = await runTenant(config, auth.claims, async (db) => {
      const updated = await updateLead(db, orgId, schoolId, leadId, {
        parentName: optionalSnakeStr(body, "parent_name"),
        studentName: optionalSnakeStr(body, "student_name"),
        classLabel: optionalSnakeStr(body, "class_label"),
        phone: optionalSnakeStr(body, "phone"),
        source: optionalSnakeStr(body, "source"),
        campaign: optionalSnakeStr(body, "campaign"),
        email: optionalSnakeStr(body, "email"),
        address: optionalSnakeStr(body, "address"),
        notes: optionalSnakeStr(body, "notes"),
      });
      if (!updated) return null;
      await emitMutationAudit(db, auth.claims, admissionsAudit.leadUpdated(leadId), req);
      return updated;
    });
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
    const app = await runTenant(config, auth.claims, async (db) => {
      const created = await createApplication(db, orgId, schoolId, {
        studentName,
        classLabel,
        parentName,
        leadId,
        counselor: snakeStr(body, "counselor"),
      });
      await emitMutationAudit(db, auth.claims, admissionsAudit.applicationCreated(created.id), req);
      return created;
    });
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
    const app = await runTenant(config, auth.claims, async (db) => {
      const updated = await updateApplication(db, orgId, schoolId, applicationId, {
        studentName: optionalSnakeStr(body, "student_name"),
        classLabel: optionalSnakeStr(body, "class_label"),
        parentName: optionalSnakeStr(body, "parent_name"),
        counselor: optionalSnakeStr(body, "counselor"),
        status: optionalSnakeStr(body, "status"),
      });
      if (!updated) return null;
      await emitMutationAudit(db, auth.claims, admissionsAudit.applicationUpdated(applicationId), req);
      return updated;
    });
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
      const app = await getApplicationById(db, orgId, schoolId, applicationId);
      if (app) {
        await emitMutationAudit(db, auth.claims, admissionsAudit.applicationSubmitted(applicationId), req);
      }
      return app;
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
  const storagePath = snakeStr(body, "storage_path");
  if (!leadId || !documentType || !fileName) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "lead_id, document_type, and file_name are required",
      422,
    );
  }
  // ADMIS-5: a document is only "uploaded" once a real file is stored. The
  // client first presigns + PUTs the bytes, then confirms here with the
  // resulting storage_path. No metadata-only fallback.
  if (!storagePath) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "storage_path is required — upload the file via /admissions/documents/upload/presign first",
      422,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  // Guard: the stored object must live under this tenant's prefix.
  if (!storagePath.startsWith(`${orgId}/${schoolId}/`)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "storage_path is not scoped to this tenant",
      422,
    );
  }

  try {
    const doc = await runTenant(config, auth.claims, async (db) => {
      const created = await uploadDocument(db, orgId, schoolId, {
        leadId,
        documentType,
        fileName,
        storagePath,
        studentName: snakeStr(body, "student_name"),
        classLabel: snakeStr(body, "class_label"),
      });
      await emitMutationAudit(db, auth.claims, admissionsAudit.documentUploaded(created.id, leadId), req);
      return created;
    });
    return jsonResponse(envelope(documentToApi(doc)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

/// ADMIS-5: presign a direct-to-Storage upload for an admissions document.
/// Mirrors the device-memories presign flow: the client PUTs the file bytes to
/// the returned signed URL, then confirms via POST /admissions/documents/upload.
export async function handlePresignDocumentUpload(
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
  const fileName = snakeStr(body, "file_name");
  if (!leadId || !fileName) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "lead_id and file_name are required",
      422,
    );
  }
  // RT-31: reject wrong-type / oversized uploads at presign (bucket enforces too).
  const uploadError = validateUpload(
    fileName,
    {
      contentType: optionalSnakeStr(body, "content_type"),
      sizeBytes: body.size_bytes == null ? null : Number(body.size_bytes),
    },
    ADMISSIONS_UPLOAD_CONSTRAINTS,
  );
  if (uploadError) {
    return errorEnvelope("VALIDATION_ERROR", uploadError, 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const storagePath = buildAdmissionsDocumentStoragePath(
    orgId,
    schoolId,
    leadId,
    fileName,
  );

  try {
    const upload = await createAdmissionsDocumentUploadUrl(config, storagePath);
    return jsonResponse(envelope({
      signedUrl: upload.signedUrl,
      token: upload.token,
      storagePath: upload.path,
    }));
  } catch (error) {
    const message = error instanceof Error ? error.message : "Presign failed";
    return errorEnvelope("ADMISSIONS_UPLOAD_ERROR", message, 500);
  }
}

/// ADMIS-5: return a short-lived signed URL so a verifier/principal can open or
/// download a stored admissions document. Tenant-scoped via the document row.
export async function handleDownloadDocument(
  req: Request,
  config: AppConfig,
  documentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const path = await runTenant(config, auth.claims, (db) =>
      getDocumentStoragePath(db, orgId, schoolId, documentId)
    );
    if (!path) {
      return errorEnvelope(
        "NOT_FOUND",
        `No stored file for document: ${documentId}`,
        404,
      );
    }
    const downloadUrl = await createAdmissionsDocumentDownloadUrl(config, path);
    return jsonResponse(envelope({ downloadUrl }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    const message = error instanceof Error ? error.message : "Download URL failed";
    return errorEnvelope("ADMISSIONS_ERROR", message, 500);
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
    const doc = await runTenant(config, claims, async (db) => {
      const reviewed = await reviewDocument(
        db,
        orgId,
        schoolId,
        documentId,
        "verified",
        claims.sub,
        note,
      );
      if (!reviewed) return null;
      await emitMutationAudit(db, claims, admissionsAudit.documentApproved(documentId), req);
      return reviewed;
    });
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
    const doc = await runTenant(config, claims, async (db) => {
      const reviewed = await reviewDocument(
        db,
        orgId,
        schoolId,
        documentId,
        "rejected",
        claims.sub,
        note,
      );
      if (!reviewed) return null;
      await emitMutationAudit(db, claims, admissionsAudit.documentRejected(documentId), req);
      return reviewed;
    });
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
    const approval = await runTenant(config, auth.claims, async (db) => {
      const updated = await setApprovalDecision(db, orgId, schoolId, approvalId, "approved");
      if (!updated) return null;
      await emitMutationAudit(db, auth.claims, admissionsAudit.admissionApproved(approvalId), req);
      return updated;
    });
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
    const approval = await runTenant(config, auth.claims, async (db) => {
      const updated = await setApprovalDecision(db, orgId, schoolId, approvalId, "rejected");
      if (!updated) return null;
      await emitMutationAudit(db, auth.claims, admissionsAudit.admissionRejected(approvalId), req);
      return updated;
    });
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
    const enrollment = await runTenant(config, auth.claims, async (db) => {
      const created = await submitEnrollment(db, orgId, schoolId, {
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
        academicYearId: optionalSnakeStr(academic, "academic_year_id") ??
          optionalSnakeStr(academic, "academicYearId") ?? null,
        classId: optionalSnakeStr(academic, "class_id") ??
          optionalSnakeStr(academic, "classId") ?? null,
        sectionId: optionalSnakeStr(academic, "section_id") ??
          optionalSnakeStr(academic, "sectionId") ?? null,
        previousSchool: String(academic.previous_school ?? ""),
        needsTransport: Boolean(academic.needs_transport),
        needsHostel: Boolean(academic.needs_hostel),
      });
      await emitMutationAudit(db, auth.claims, admissionsAudit.enrollmentSubmitted(created.id), req);
      return created;
    });
    return jsonResponse(envelope(enrollmentToApi(enrollment)), { status: 201 });
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

// ─── Fee handoffs (Phase 4B0) ────────────────────────────────────────────────

export async function handleListApprovedHandoffs(
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
      listFeeHandoffs(db, orgId, schoolId, pagination)
    );
    return jsonResponse(
      envelope(
        listEnvelope(
          result.items.map(handoffToApi),
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

export async function handleSendToFinance(
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

  const handoffId = snakeStr(body, "handoff_id");
  const feeStructureId = snakeStr(body, "fee_structure_id");
  if (!handoffId || !feeStructureId) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "handoff_id and fee_structure_id are required",
      422,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const handoff = await runTenant(config, auth.claims, async (db) => {
      const sent = await sendHandoffToFinance(db, orgId, schoolId, handoffId, feeStructureId);
      if (!sent) return null;
      await emitMutationAudit(db, auth.claims, admissionsAudit.financeHandoffSent(handoffId), req);
      return sent;
    });
    if (!handoff) {
      return errorEnvelope("NOT_FOUND", `Handoff not found: ${handoffId}`, 404);
    }
    return jsonResponse(envelope(handoffToApi(handoff)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

function normalizeHandoffStatus(raw: string): string {
  const key = raw.trim();
  if (key === "sentToFinance" || key === "sent_to_finance") return "sent_to_finance";
  if (key === "pending" || key === "completed" || key === "failed") return key;
  return key.replace(/([A-Z])/g, "_$1").toLowerCase().replace(/^_/, "");
}

export async function handleUpdateHandoffStatus(
  req: Request,
  config: AppConfig,
  handoffId: string,
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

  const statusRaw = snakeStr(body, "status");
  if (!statusRaw) {
    return errorEnvelope("VALIDATION_ERROR", "status is required", 422);
  }

  const status = normalizeHandoffStatus(statusRaw);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const handoff = await runTenant(config, auth.claims, async (db) => {
      const updated = await updateHandoffStatus(db, orgId, schoolId, handoffId, status);
      if (!updated) return null;
      await emitMutationAudit(db, auth.claims, admissionsAudit.handoffStatusUpdated(handoffId, status), req);
      return updated;
    });
    if (!handoff) {
      return errorEnvelope("NOT_FOUND", `Handoff not found: ${handoffId}`, 404);
    }
    return jsonResponse(envelope(handoffToApi(handoff)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof Error && error.message.startsWith("Invalid handoff")) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    throw error;
  }
}
