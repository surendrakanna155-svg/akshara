import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requireAnyPermission,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, schoolCompletionAudit } from "../audit/mutation_audit_catalog.ts";
import {
  createSubject,
  listSubjects,
  subjectToApi,
  updateSubject,
} from "./subjects_repository.ts";
import {
  createLessonLog,
  lessonLogToApi,
  listLessonLogs,
} from "./lesson_logs_repository.ts";
import {
  brandingToApi,
  getSchoolBranding,
  upsertSchoolBranding,
} from "./branding_repository.ts";
import {
  getWhatsAppProviderConfig,
  upsertWhatsAppProviderConfig,
  whatsAppConfigToApi,
  whatsAppConfigToRuntime,
} from "./whatsapp_repository.ts";
import { sendWhatsAppMessage } from "./whatsapp_providers.ts";
import { runTimetableAutomation } from "./timetable_automation_service.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function handleListSubjects(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewSubjects") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const items = await withTenantContext(config, auth.claims, (db) =>
      listSubjects(db, organizationIdFromClaims(auth.claims), schoolIdFromClaims(auth.claims))
    );
    return jsonResponse(envelope({ items: items.map(subjectToApi) }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("SUBJECTS_ERROR", String(error), 500);
  }
}

export async function handleCreateSubject(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageSubjects") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    subjectCode: string;
    subjectName: string;
    category?: string;
    gradeLabels?: string[];
  }>(req);
  if (!body?.subjectCode || !body.subjectName) {
    return errorEnvelope("VALIDATION_ERROR", "subjectCode and subjectName required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const created = await createSubject(db, orgId, schoolId, {
        subjectCode: body.subjectCode,
        subjectName: body.subjectName,
        category: body.category,
        gradeLabels: body.gradeLabels,
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(db, auth.claims, schoolCompletionAudit.subjectCreated(created.id), req);
      return created;
    });
    return jsonResponse(envelope(subjectToApi(row)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("SUBJECTS_ERROR", String(error), 500);
  }
}

export async function handleUpdateSubject(
  req: Request,
  config: AppConfig,
  subjectId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageSubjects") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    subjectName?: string;
    category?: string;
    gradeLabels?: string[];
    status?: string;
  }>(req);

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const updated = await updateSubject(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        subjectId,
        body ?? {},
      );
      if (!updated) throw new Error("Subject not found");
      await emitMutationAudit(db, auth.claims, schoolCompletionAudit.subjectUpdated(subjectId), req);
      return updated;
    });
    return jsonResponse(envelope(subjectToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("SUBJECTS_ERROR", String(error), 500);
  }
}

export async function handleListLessonLogs(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewLessonLogs") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const className = url.searchParams.get("className") ?? undefined;

  try {
    const items = await withTenantContext(config, auth.claims, (db) =>
      listLessonLogs(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        { className, teacherUserId: url.searchParams.get("teacherUserId") ?? undefined },
      )
    );
    return jsonResponse(envelope({ items: items.map(lessonLogToApi) }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("LESSON_LOGS_ERROR", String(error), 500);
  }
}

export async function handleCreateLessonLog(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageLessonLogs") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    className: string;
    sectionName?: string;
    subjectId?: string;
    topic: string;
    outcome?: string;
    notes?: string;
    recordedOn?: string;
  }>(req);
  if (!body?.className || !body.topic) {
    return errorEnvelope("VALIDATION_ERROR", "className and topic required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const created = await createLessonLog(db, orgId, schoolId, {
        className: body.className,
        sectionName: body.sectionName,
        subjectId: body.subjectId,
        topic: body.topic,
        outcome: body.outcome,
        notes: body.notes,
        recordedOn: body.recordedOn,
        teacherUserId: auth.claims.sub,
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(db, auth.claims, schoolCompletionAudit.lessonLogCreated(created.id), req);
      return created;
    });
    return jsonResponse(envelope(lessonLogToApi(row)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("LESSON_LOGS_ERROR", String(error), 500);
  }
}

export async function handleAutomateTimetables(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnyPermission(auth.claims, ["manageTimetableAutomation", "manageAcademicTimetable"]) ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    academicYearId: string;
    periodsPerDay?: number;
    daysPerWeek?: number;
    sectionId?: string;
  }>(req);
  if (!body?.academicYearId) {
    return errorEnvelope("VALIDATION_ERROR", "academicYearId required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const automation = await runTimetableAutomation(
        db,
        orgId,
        schoolId,
        body.academicYearId,
        auth.claims.sub,
        {
          periodsPerDay: body.periodsPerDay,
          daysPerWeek: body.daysPerWeek,
          sectionId: body.sectionId,
        },
      );
      await emitMutationAudit(
        db,
        auth.claims,
        schoolCompletionAudit.timetableAutomated(body.academicYearId, automation.timetablesCreated),
        req,
      );
      return automation;
    });
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("TIMETABLE_AUTOMATION_ERROR", String(error), 500);
  }
}

export async function handleGetSchoolBranding(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewSchoolBranding") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const row = await withTenantContext(config, auth.claims, (db) =>
      getSchoolBranding(db, organizationIdFromClaims(auth.claims), schoolIdFromClaims(auth.claims))
    );
    return jsonResponse(envelope(brandingToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("BRANDING_ERROR", String(error), 500);
  }
}

export async function handleSaveSchoolBranding(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageSchoolBranding") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    displayName?: string;
    tagline?: string;
    primaryColor?: string;
    secondaryColor?: string;
    logoUrl?: string;
    faviconUrl?: string;
    loginBackgroundUrl?: string;
  }>(req);

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const saved = await upsertSchoolBranding(db, orgId, schoolId, body ?? {});
      await emitMutationAudit(db, auth.claims, schoolCompletionAudit.brandingUpdated(saved.id), req);
      return saved;
    });
    return jsonResponse(envelope(brandingToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("BRANDING_ERROR", String(error), 500);
  }
}

export async function handleGetWhatsAppProvider(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewWhatsAppProvider") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const row = await withTenantContext(config, auth.claims, (db) =>
      getWhatsAppProviderConfig(db, organizationIdFromClaims(auth.claims), schoolIdFromClaims(auth.claims))
    );
    return jsonResponse(envelope(whatsAppConfigToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("WHATSAPP_PROVIDER_ERROR", String(error), 500);
  }
}

export async function handleSaveWhatsAppProvider(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "managePlatformWhatsApp");
  if (denied) return denied;

  const body = await readJson<{
    provider: "stub" | "msg91" | "gupshup";
    senderId?: string;
    apiKeyRef?: string;
    templateNamespace?: string;
    isActive?: boolean;
  }>(req);
  if (!body?.provider) {
    return errorEnvelope("VALIDATION_ERROR", "provider required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const saved = await upsertWhatsAppProviderConfig(db, orgId, schoolId, {
        provider: body.provider,
        senderId: body.senderId,
        apiKeyRef: body.apiKeyRef,
        templateNamespace: body.templateNamespace,
        isActive: body.isActive,
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(db, auth.claims, schoolCompletionAudit.whatsAppProviderUpdated(saved.id), req);
      return saved;
    });
    return jsonResponse(envelope(whatsAppConfigToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("WHATSAPP_PROVIDER_ERROR", String(error), 500);
  }
}

export async function handleTestWhatsAppProvider(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "managePlatformWhatsApp");
  if (denied) return denied;

  const body = await readJson<{ toPhone: string; templateId?: string }>(req);
  if (!body?.toPhone) {
    return errorEnvelope("VALIDATION_ERROR", "toPhone required", 422);
  }

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const row = await getWhatsAppProviderConfig(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
      );
      const config = whatsAppConfigToRuntime(row);
      const delivery = await sendWhatsAppMessage(config, {
        toPhone: body.toPhone,
        templateId: body.templateId ?? "akshara_test",
        body: "Akshara ERP WhatsApp provider test",
      });
      await emitMutationAudit(db, auth.claims, schoolCompletionAudit.whatsAppTestSent(body.toPhone), req);
      return delivery;
    });
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("WHATSAPP_PROVIDER_ERROR", String(error), 500);
  }
}

export { UUID as schoolCompletionUuidPattern };
