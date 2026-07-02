import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { recordMutationAudit } from "../audit/audit_repository.ts";
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
  commitImportJob,
  createImportPreview,
  createInvite,
  type GeneratePlaceholderInput,
  generatePlaceholderStudents,
  getImportJob,
  listImportJobs,
  listInvites,
  markInviteSent,
  parseCsvText,
  rollbackImportJob,
} from "./onboarding_repository.ts";

function requireOnboardingManage(claims: AccessTokenClaims): Response | null {
  return requirePermission(claims, "manageOnboarding") ??
    requireSchoolOperationalScope(claims);
}

export function requireOnboardingView(claims: AccessTokenClaims): Response | null {
  if (
    claims.permissions.includes("viewOnboarding") ||
    claims.permissions.includes("manageOnboarding")
  ) {
    return requireSchoolOperationalScope(claims);
  }
  return errorEnvelope("FORBIDDEN", "Permission required: viewOnboarding", 403);
}

function jobToApi(job: Awaited<ReturnType<typeof getImportJob>>) {
  if (!job) return null;
  return {
    id: job.id,
    importType: job.import_type,
    status: job.status,
    fileName: job.file_name,
    totalRows: job.total_rows,
    validRows: job.valid_rows,
    invalidRows: job.invalid_rows,
    duplicateRows: job.duplicate_rows,
    committedRows: job.committed_rows,
    report: job.report,
    createdAt: job.created_at,
    updatedAt: job.updated_at,
  };
}

export async function handleListImportJobs(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireOnboardingView(auth.claims);
  if (denied) return denied;

  try {
    const jobs = await withTenantContext(config, auth.claims, async (db) =>
      await listImportJobs(db, organizationIdFromClaims(auth.claims), schoolIdFromClaims(auth.claims)!)
    );
    return jsonResponse(envelope({ items: jobs.map((j) => jobToApi(j)!) }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to list import jobs", 500);
  }
}

export async function handleGetImportJob(
  req: Request,
  config: AppConfig,
  jobId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireOnboardingView(auth.claims);
  if (denied) return denied;

  try {
    const job = await withTenantContext(config, auth.claims, async (db) =>
      await getImportJob(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
        jobId,
      )
    );
    if (!job) return errorEnvelope("NOT_FOUND", "Import job not found", 404);
    return jsonResponse(envelope(jobToApi(job)!));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load import job", 500);
  }
}

async function handleImportPreview(
  req: Request,
  config: AppConfig,
  importType: "student" | "teacher",
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireOnboardingManage(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    fileName?: string;
    csvText?: string;
    rows?: Record<string, unknown>[];
  }>(req);
  const rawRows = body?.rows?.length
    ? body.rows
    : body?.csvText
    ? parseCsvText(body.csvText)
    : [];
  if (!rawRows.length) {
    return errorEnvelope("VALIDATION_ERROR", "rows or csvText is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims)!;

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const preview = await createImportPreview(
        db,
        orgId,
        schoolId,
        auth.claims.sub,
        importType,
        body?.fileName ?? `${importType}_import.csv`,
        rawRows,
      );
      await recordMutationAudit(db, auth.claims, {
        eventType: "onboardingImportPreviewed",
        category: "onboarding",
        entityType: "onboarding_import_job",
        entityId: preview.job.id,
        metadata: { importType, totalRows: rawRows.length },
      }, {
        eventType: "onboarding.import.previewed",
        sourceModule: "onboarding",
        payload: { importType, totalRows: rawRows.length },
        idempotencyKey: `onboarding.import.preview:${preview.job.id}`,
      }, req);
      return preview;
    });
    return jsonResponse(envelope({
      job: jobToApi(result.job),
      preview: result.preview,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Import preview failed", 500);
  }
}

export async function handleStudentImportPreview(req: Request, config: AppConfig): Promise<Response> {
  return await handleImportPreview(req, config, "student");
}

export async function handleTeacherImportPreview(req: Request, config: AppConfig): Promise<Response> {
  return await handleImportPreview(req, config, "teacher");
}

export async function handleGeneratePlaceholderStudents(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireOnboardingManage(auth.claims);
  if (denied) return denied;

  const body = await readJson<GeneratePlaceholderInput>(req);
  if (!body?.academicYear || typeof body.academicYear !== "string") {
    return errorEnvelope("VALIDATION_ERROR", "academicYear is required", 422);
  }
  if (!Array.isArray(body.classes) || body.classes.length === 0) {
    return errorEnvelope("VALIDATION_ERROR", "classes[] is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims)!;

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const generated = await generatePlaceholderStudents(
        db,
        orgId,
        schoolId,
        auth.claims.sub,
        body,
      );
      await recordMutationAudit(db, auth.claims, {
        eventType: "onboardingPlaceholdersGenerated",
        category: "onboarding",
        entityType: "onboarding_import_job",
        entityId: generated.job.id,
        metadata: {
          generatedCount: generated.generatedCount,
          academicYear: body.academicYear,
        },
      }, {
        eventType: "onboarding.placeholders.generated",
        sourceModule: "onboarding",
        payload: { generatedCount: generated.generatedCount },
        idempotencyKey: `onboarding.placeholders:${generated.job.id}`,
      }, req);
      return generated;
    });
    return jsonResponse(envelope({
      job: jobToApi(result.job),
      generatedCount: result.generatedCount,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof Error && error.message.startsWith("PLACEHOLDER_")) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    console.error("handleGeneratePlaceholderStudents error:", error);
    const detail = error instanceof Error ? error.message : "Placeholder generation failed";
    return errorEnvelope("INTERNAL_ERROR", detail, 500);
  }
}

export async function handleCommitImportJob(
  req: Request,
  config: AppConfig,
  jobId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireOnboardingManage(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims)!;

  try {
    const job = await withTenantContext(config, auth.claims, async (db) => {
      const committed = await commitImportJob(db, orgId, schoolId, jobId, auth.claims, req);
      await recordMutationAudit(db, auth.claims, {
        eventType: "onboardingImportCommitted",
        category: "onboarding",
        entityType: "onboarding_import_job",
        entityId: jobId,
        metadata: { committedRows: committed.committed_rows },
      }, {
        eventType: "onboarding.import.committed",
        sourceModule: "onboarding",
        payload: { committedRows: committed.committed_rows },
        idempotencyKey: `onboarding.import.commit:${jobId}`,
      }, req);
      return committed;
    });
    return jsonResponse(envelope(jobToApi(job)!));
  } catch (error) {
    if (error instanceof Error && error.message === "IMPORT_JOB_NOT_FOUND") {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof Error && error.message === "IMPORT_JOB_NOT_PREVIEWED") {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    console.error("handleCommitImportJob error:", error);
    const detail = error instanceof Error ? error.message : "Import commit failed";
    return errorEnvelope("INTERNAL_ERROR", detail, 500);
  }
}

export async function handleRollbackImportJob(
  req: Request,
  config: AppConfig,
  jobId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireOnboardingManage(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims)!;

  try {
    const job = await withTenantContext(config, auth.claims, async (db) => {
      const rolledBack = await rollbackImportJob(db, orgId, schoolId, jobId);
      await recordMutationAudit(db, auth.claims, {
        eventType: "onboardingImportRolledBack",
        category: "onboarding",
        entityType: "onboarding_import_job",
        entityId: jobId,
        metadata: {},
      }, {
        eventType: "onboarding.import.rolled_back",
        sourceModule: "onboarding",
        payload: {},
        idempotencyKey: `onboarding.import.rollback:${jobId}`,
      }, req);
      return rolledBack;
    });
    return jsonResponse(envelope(jobToApi(job)!));
  } catch (error) {
    if (error instanceof Error && error.message === "IMPORT_JOB_NOT_FOUND") {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof Error && error.message === "IMPORT_JOB_NOT_COMMITTED") {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Import rollback failed", 500);
  }
}

export async function handleCreateInvite(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireOnboardingManage(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    inviteType?: string;
    recipientPhone?: string;
    recipientLabel?: string;
    studentId?: string;
    channel?: string;
  }>(req);
  if (!body?.inviteType || !body.recipientPhone || !body.recipientLabel) {
    return errorEnvelope("VALIDATION_ERROR", "inviteType, recipientPhone, recipientLabel required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims)!;

  try {
    const invite = await withTenantContext(config, auth.claims, async (db) => {
      const created = await createInvite(db, orgId, schoolId, auth.claims.sub, {
        inviteType: body.inviteType as "parent" | "teacher" | "student",
        recipientPhone: body.recipientPhone!,
        recipientLabel: body.recipientLabel!,
        studentId: body.studentId ?? null,
        channel: (body.channel as "sms" | "whatsapp") ?? "whatsapp",
      });
      await markInviteSent(db, String(created.id));
      await recordMutationAudit(db, auth.claims, {
        eventType: "onboardingInviteSent",
        category: "onboarding",
        entityType: "onboarding_invite",
        entityId: String(created.id),
        metadata: { channel: body.channel ?? "whatsapp" },
      }, {
        eventType: "onboarding.invite.sent",
        sourceModule: "onboarding",
        payload: { inviteType: body.inviteType },
        idempotencyKey: `onboarding.invite:${created.id}`,
      }, req);
      return created;
    });
    return jsonResponse(envelope(invite));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Invite creation failed", 500);
  }
}

export async function handleListInvites(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireOnboardingView(auth.claims);
  if (denied) return denied;

  try {
    const invites = await withTenantContext(config, auth.claims, async (db) =>
      await listInvites(db, organizationIdFromClaims(auth.claims), schoolIdFromClaims(auth.claims)!)
    );
    return jsonResponse(envelope({ items: invites }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to list invites", 500);
  }
}

export async function handleOnboardingDashboard(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireOnboardingView(auth.claims);
  if (denied) return denied;

  try {
    const data = await withTenantContext(config, auth.claims, async (db) => {
      const orgId = organizationIdFromClaims(auth.claims);
      const schoolId = schoolIdFromClaims(auth.claims)!;
      const jobs = await listImportJobs(db, orgId, schoolId);
      const invites = await listInvites(db, orgId, schoolId);
      return {
        recentJobs: jobs.slice(0, 5).map((j) => jobToApi(j)!),
        pendingInvites: invites.filter((i) => i.status === "pending" || i.status === "sent").length,
        totalInvites: invites.length,
      };
    });
    return jsonResponse(envelope(data));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load onboarding dashboard", 500);
  }
}
