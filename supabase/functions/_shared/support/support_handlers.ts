// ASIP — HTTP handlers for the `/support` module. Every handler funnels through
// authenticateRequest, requires school scope, and runs its DB work under
// withTenantContext (RLS-enforced erp_tenant). Mutations are audited. Finer
// authz (reporter-owns vs support view/manage) is enforced here, on top of the
// school-scope RLS (the platform norm).

import type { AppConfig } from "../config.ts";
import {
  authenticateRequest,
  requireAnyPermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { withTenantContext } from "../tenant_db.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  correlationIdFromRequest,
  recordServerAuditEvent,
} from "../audit/audit_repository.ts";
import { enqueueNotificationRequested } from "../communication/notification_service.ts";
import {
  buildSupportAttachmentStoragePath,
  createSupportAttachmentDownloadUrl,
  createSupportAttachmentUploadUrl,
  SUPPORT_ATTACHMENT_UPLOAD_CONSTRAINTS,
  validateUpload,
} from "../storage/storage_service.ts";
import {
  approveAnalysis,
  getIncident,
  getLatestAnalysis,
  insertAttachment,
  insertEvent,
  insertIncident,
  insertMessage,
  listAttachments,
  listEvents,
  listIncidents,
  listLatestEvidence,
  listMessages,
  updateIncidentStatus,
} from "./support_repository.ts";
import {
  buildEvidenceParts,
  persistEvidence,
  runAnalysis,
} from "./support_service.ts";
import { categorize } from "./incident_package.ts";
import {
  ATTACHMENT_KINDS,
  type ClientContext,
  type ConfirmAttachmentRequest,
  type CreateIncidentRequest,
  type EvidenceRow,
  type IncidentRow,
  type PostMessageRequest,
  type PresignAttachmentRequest,
  type StatusTransitionRequest,
  SUPPORT_STATUSES,
} from "./support_types.ts";

// ── authz helpers (finer-than-RLS, handler-layer) ────────────────────────────

function hasSupportView(claims: AccessTokenClaims): boolean {
  return claims.permissions.includes("viewSupport") ||
    claims.permissions.includes("manageSupport");
}
function hasSupportManage(claims: AccessTokenClaims): boolean {
  return claims.permissions.includes("manageSupport");
}
function isReporter(claims: AccessTokenClaims, incident: IncidentRow): boolean {
  return incident.reporter_user_id === claims.sub;
}

// Valid status transitions. new/awaiting → in_progress etc.; resolved/closed can
// reopen to in_progress. Anything else is rejected (422).
const ALLOWED_TRANSITIONS: Record<string, string[]> = {
  new: ["triaging", "in_progress", "closed"],
  triaging: ["in_progress", "awaiting_customer", "resolved", "closed"],
  in_progress: ["awaiting_customer", "resolved", "closed"],
  awaiting_customer: ["in_progress", "resolved", "closed"],
  resolved: ["closed", "in_progress"],
  closed: ["in_progress"],
};

/** Best-effort reporter notification — never fails the core mutation. */
async function notifyReporter(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incident: IncidentRow,
  title: string,
  body: string,
): Promise<void> {
  try {
    await enqueueNotificationRequested(
      db,
      claims.tenant_id,
      incident.school_id,
      incident.reporter_user_id,
      title,
      body,
      "support",
    );
  } catch (_err) {
    // Notification delivery is best-effort; the mutation already succeeded.
  }
}

// ── handlers ─────────────────────────────────────────────────────────────────

export async function handleCreateIncident(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const scopeDenied = requireSchoolOperationalScope(auth.claims);
  if (scopeDenied) return scopeDenied;

  const body = await readJson<CreateIncidentRequest>(req);
  if (!body || typeof body.title !== "string" || body.title.trim().length === 0) {
    return errorEnvelope("VALIDATION", "title is required", 422);
  }
  const title = body.title.trim().slice(0, 200);
  const description = typeof body.description === "string" ? body.description.slice(0, 8000) : "";
  const context: ClientContext | undefined = body.context ?? undefined;
  const claims = auth.claims;

  const incident = await withTenantContext(config, claims, async (db) => {
    const parts = await buildEvidenceParts(db, claims, context, claims.sub);
    const { category } = categorize(
      {
        title,
        description,
        reporterRole: claims.primary_role ?? claims.role ?? "",
        moduleKey: parts.derived.moduleKey,
        screenRoute: parts.derived.screenRoute,
        platform: parts.derived.platform,
        appVersion: parts.derived.appVersion,
      },
      parts.diagnostics,
    );

    const row = await insertIncident(db, claims, {
      title,
      description,
      category,
      severity: "sev3",
      moduleKey: parts.derived.moduleKey,
      screenRoute: parts.derived.screenRoute,
      appVersion: parts.derived.appVersion,
      platform: parts.derived.platform,
      deviceModel: parts.derived.deviceModel,
      osVersion: parts.derived.osVersion,
      sessionId: parts.derived.sessionId,
      correlationId: parts.derived.correlationId,
    });

    await persistEvidence(db, claims, row.id, parts);
    await insertEvent(db, claims, row.id, {
      eventType: "created",
      actorUserId: claims.sub,
      toValue: row.status,
      metadata: { public_ref: row.public_ref, category },
    });
    await insertEvent(db, claims, row.id, {
      eventType: "evidence_collected",
      actorUserId: null,
      metadata: { signals: parts.diagnostics.signals },
    });
    await recordServerAuditEvent(db, claims, {
      eventType: "supportIncidentCreated",
      category: "support",
      entityType: "support_incident",
      entityId: row.id,
      metadata: { public_ref: row.public_ref, category, module: row.module_key },
      correlationId: correlationIdFromRequest(req),
    }, req);
    return row;
  });

  return jsonResponse(envelope(incident), { status: 201 });
}

export async function handleListIncidents(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const scopeDenied = requireSchoolOperationalScope(auth.claims);
  if (scopeDenied) return scopeDenied;

  const url = new URL(req.url);
  const page = Number(url.searchParams.get("page") ?? "1") || 1;
  const pageSize = Number(url.searchParams.get("pageSize") ?? "20") || 20;
  const status = url.searchParams.get("status") ?? undefined;
  const claims = auth.claims;
  const reporterOnly = !hasSupportView(claims);

  const result = await withTenantContext(config, claims, (db) =>
    listIncidents(db, claims, {
      reporterOnly,
      reporterUserId: claims.sub,
      status: status && SUPPORT_STATUSES.includes(status as never) ? status : undefined,
      page,
      pageSize,
    }));

  return jsonResponse(envelope(result));
}

export async function handleGetIncident(
  req: Request,
  config: AppConfig,
  incidentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const scopeDenied = requireSchoolOperationalScope(auth.claims);
  if (scopeDenied) return scopeDenied;
  const claims = auth.claims;

  const loaded = await withTenantContext(config, claims, async (db) => {
    const incident = await getIncident(db, claims, incidentId);
    if (!incident) return { notFound: true as const };
    const support = hasSupportView(claims);
    if (!support && !isReporter(claims, incident)) return { forbidden: true as const };

    const events = await listEvents(db, claims, incidentId);
    const messages = await listMessages(db, claims, incidentId, support);
    const attachments = await listAttachments(db, claims, incidentId);
    const evidence = support ? await listLatestEvidence(db, claims, incidentId) : [];
    const analysis = support ? await getLatestAnalysis(db, claims, incidentId) : null;
    return { incident, events, messages, attachments, evidence, analysis };
  });

  if ("notFound" in loaded) return errorEnvelope("NOT_FOUND", "Incident not found", 404);
  if ("forbidden" in loaded) return errorEnvelope("FORBIDDEN", "Not your incident", 403);

  // Signed download URLs for the attachments (service-role storage; best-effort
  // per attachment so one bad object never fails the whole detail read).
  const attachmentsWithUrls = await Promise.all(
    loaded.attachments.map(async (a) => {
      let downloadUrl: string | null = null;
      try {
        downloadUrl = await createSupportAttachmentDownloadUrl(config, a.storage_path);
      } catch (_e) {
        downloadUrl = null;
      }
      return { ...a, download_url: downloadUrl };
    }),
  );

  return jsonResponse(envelope({
    incident: loaded.incident,
    events: loaded.events,
    messages: loaded.messages,
    attachments: attachmentsWithUrls,
    evidence: loaded.evidence,
    analysis: loaded.analysis,
  }));
}

export async function handlePostMessage(
  req: Request,
  config: AppConfig,
  incidentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const scopeDenied = requireSchoolOperationalScope(auth.claims);
  if (scopeDenied) return scopeDenied;
  const claims = auth.claims;

  const body = await readJson<PostMessageRequest>(req);
  if (!body || typeof body.body !== "string" || body.body.trim().length === 0) {
    return errorEnvelope("VALIDATION", "body is required", 422);
  }
  const text = body.body.trim().slice(0, 8000);

  const result = await withTenantContext(config, claims, async (db) => {
    const incident = await getIncident(db, claims, incidentId);
    if (!incident) return { notFound: true as const };

    let senderKind: string;
    let visibility: string;
    if (isReporter(claims, incident)) {
      senderKind = "reporter";
      visibility = "school_visible";
    } else if (hasSupportManage(claims)) {
      senderKind = "support";
      visibility = body.internalNote === true ? "internal_note" : "school_visible";
    } else {
      return { forbidden: true as const };
    }

    const message = await insertMessage(db, claims, incidentId, {
      senderUserId: claims.sub,
      senderKind,
      visibility,
      body: text,
    });
    await insertEvent(db, claims, incidentId, {
      eventType: "message_posted",
      actorUserId: claims.sub,
      metadata: { visibility, senderKind },
    });
    await recordServerAuditEvent(db, claims, {
      eventType: "supportIncidentMessagePosted",
      category: "support",
      entityType: "support_incident",
      entityId: incidentId,
      metadata: { visibility, senderKind },
      correlationId: correlationIdFromRequest(req),
    }, req);

    // Notify the reporter when SUPPORT posts a school-visible reply.
    if (senderKind === "support" && visibility === "school_visible") {
      await notifyReporter(
        db,
        claims,
        incident,
        `Update on ${incident.public_ref}`,
        "The support team replied to your reported issue.",
      );
    }
    return { message };
  });

  if ("notFound" in result) return errorEnvelope("NOT_FOUND", "Incident not found", 404);
  if ("forbidden" in result) return errorEnvelope("FORBIDDEN", "Cannot post to this incident", 403);
  return jsonResponse(envelope(result.message), { status: 201 });
}

export async function handlePresignAttachment(
  req: Request,
  config: AppConfig,
  incidentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const scopeDenied = requireSchoolOperationalScope(auth.claims);
  if (scopeDenied) return scopeDenied;
  const claims = auth.claims;

  const body = await readJson<PresignAttachmentRequest>(req);
  if (!body || typeof body.fileName !== "string" || !ATTACHMENT_KINDS.includes(body.kind as never)) {
    return errorEnvelope("VALIDATION", "kind and fileName are required", 422);
  }
  const uploadError = validateUpload(
    body.fileName,
    { contentType: body.contentType ?? null, sizeBytes: body.sizeBytes ?? null },
    SUPPORT_ATTACHMENT_UPLOAD_CONSTRAINTS,
  );
  if (uploadError) return errorEnvelope("VALIDATION", uploadError, 422);

  const access = await withTenantContext(config, claims, async (db) => {
    const incident = await getIncident(db, claims, incidentId);
    if (!incident) return { notFound: true as const };
    if (!isReporter(claims, incident) && !hasSupportManage(claims)) {
      return { forbidden: true as const };
    }
    return { ok: true as const };
  });
  if ("notFound" in access) return errorEnvelope("NOT_FOUND", "Incident not found", 404);
  if ("forbidden" in access) return errorEnvelope("FORBIDDEN", "Cannot attach to this incident", 403);

  const storagePath = buildSupportAttachmentStoragePath(
    claims.tenant_id,
    claims.school_id!,
    incidentId,
    body.fileName,
  );
  const presign = await createSupportAttachmentUploadUrl(config, storagePath);
  return jsonResponse(envelope({
    signed_url: presign.signedUrl,
    token: presign.token,
    storage_path: presign.path,
  }));
}

export async function handleConfirmAttachment(
  req: Request,
  config: AppConfig,
  incidentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const scopeDenied = requireSchoolOperationalScope(auth.claims);
  if (scopeDenied) return scopeDenied;
  const claims = auth.claims;

  const body = await readJson<ConfirmAttachmentRequest>(req);
  if (
    !body || typeof body.storagePath !== "string" || typeof body.fileName !== "string" ||
    !ATTACHMENT_KINDS.includes(body.kind as never)
  ) {
    return errorEnvelope("VALIDATION", "kind, storagePath and fileName are required", 422);
  }
  // The confirmed path MUST belong to this tenant+school+incident (a client can
  // never register an object under another tenant's or incident's prefix).
  const expectedPrefix = `${claims.tenant_id}/${claims.school_id}/${incidentId}/`;
  if (!body.storagePath.startsWith(expectedPrefix)) {
    return errorEnvelope("VALIDATION", "storagePath does not belong to this incident", 422);
  }

  const result = await withTenantContext(config, claims, async (db) => {
    const incident = await getIncident(db, claims, incidentId);
    if (!incident) return { notFound: true as const };
    if (!isReporter(claims, incident) && !hasSupportManage(claims)) {
      return { forbidden: true as const };
    }
    const attachment = await insertAttachment(db, claims, incidentId, {
      kind: body.kind,
      storagePath: body.storagePath,
      fileName: body.fileName.slice(0, 200),
      contentType: (body.contentType ?? "").slice(0, 120),
      sizeBytes: typeof body.sizeBytes === "number" && body.sizeBytes >= 0 ? body.sizeBytes : 0,
      uploadedBy: claims.sub,
    });
    await insertEvent(db, claims, incidentId, {
      eventType: "attachment_added",
      actorUserId: claims.sub,
      metadata: { kind: body.kind },
    });
    await recordServerAuditEvent(db, claims, {
      eventType: "supportIncidentAttachmentAdded",
      category: "support",
      entityType: "support_incident",
      entityId: incidentId,
      metadata: { kind: body.kind },
      correlationId: correlationIdFromRequest(req),
    }, req);
    return { attachment };
  });

  if ("notFound" in result) return errorEnvelope("NOT_FOUND", "Incident not found", 404);
  if ("forbidden" in result) return errorEnvelope("FORBIDDEN", "Cannot attach to this incident", 403);
  return jsonResponse(envelope(result.attachment), { status: 201 });
}

export async function handleCollectEvidence(
  req: Request,
  config: AppConfig,
  incidentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnyPermission(auth.claims, ["manageSupport"]) ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;
  const claims = auth.claims;

  const result = await withTenantContext(config, claims, async (db) => {
    const incident = await getIncident(db, claims, incidentId);
    if (!incident) return { notFound: true as const };

    const existing = await listLatestEvidence(db, claims, incidentId);
    const context = reconstructContextFromEvidence(existing, incident);
    const parts = await buildEvidenceParts(db, claims, context, incident.reporter_user_id);
    await persistEvidence(db, claims, incidentId, parts);
    await insertEvent(db, claims, incidentId, {
      eventType: "evidence_collected",
      actorUserId: claims.sub,
      metadata: { signals: parts.diagnostics.signals, recollected: true },
    });
    await recordServerAuditEvent(db, claims, {
      eventType: "supportIncidentEvidenceCollected",
      category: "support",
      entityType: "support_incident",
      entityId: incidentId,
      metadata: { signals: parts.diagnostics.signals },
      correlationId: correlationIdFromRequest(req),
    }, req);
    return { diagnostics: parts.diagnostics };
  });

  if ("notFound" in result) return errorEnvelope("NOT_FOUND", "Incident not found", 404);
  return jsonResponse(envelope({ diagnostics: result.diagnostics }));
}

export async function handleAnalyzeIncident(
  req: Request,
  config: AppConfig,
  incidentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnyPermission(auth.claims, ["manageSupport"]) ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;
  const claims = auth.claims;

  const result = await withTenantContext(config, claims, async (db) => {
    const incident = await getIncident(db, claims, incidentId);
    if (!incident) return { notFound: true as const };
    const evidence = await listLatestEvidence(db, claims, incidentId);
    const analysis = await runAnalysis(config, db, claims, incident, evidence);
    await insertEvent(db, claims, incidentId, {
      eventType: "ai_analyzed",
      actorUserId: claims.sub,
      metadata: { version: analysis.version, method: analysis.method, confidence: analysis.confidence },
    });
    await recordServerAuditEvent(db, claims, {
      eventType: "supportIncidentAnalyzed",
      category: "support",
      entityType: "support_incident",
      entityId: incidentId,
      metadata: { version: analysis.version, method: analysis.method },
      correlationId: correlationIdFromRequest(req),
    }, req);
    return { analysis };
  });

  if ("notFound" in result) return errorEnvelope("NOT_FOUND", "Incident not found", 404);
  return jsonResponse(envelope(result.analysis), { status: 201 });
}

export async function handleApproveAnalysis(
  req: Request,
  config: AppConfig,
  incidentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnyPermission(auth.claims, ["manageSupport"]) ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;
  const claims = auth.claims;

  const body = await readJson<{ version?: number }>(req);
  const version = typeof body?.version === "number" ? body.version : NaN;
  if (!Number.isInteger(version) || version < 1) {
    return errorEnvelope("VALIDATION", "version (>=1) is required", 422);
  }

  const result = await withTenantContext(config, claims, async (db) => {
    const incident = await getIncident(db, claims, incidentId);
    if (!incident) return { notFound: true as const };
    const updated = await approveAnalysis(db, claims, incidentId, version, claims.sub);
    if (updated === 0) return { conflict: true as const };
    await insertEvent(db, claims, incidentId, {
      eventType: "ai_analysis_approved",
      actorUserId: claims.sub,
      metadata: { version },
    });
    await recordServerAuditEvent(db, claims, {
      eventType: "supportIncidentAnalysisApproved",
      category: "support",
      entityType: "support_incident",
      entityId: incidentId,
      metadata: { version },
      correlationId: correlationIdFromRequest(req),
    }, req);
    return { ok: true as const };
  });

  if ("notFound" in result) return errorEnvelope("NOT_FOUND", "Incident not found", 404);
  if ("conflict" in result) {
    return errorEnvelope("CONFLICT", "Analysis version already approved or not found", 409);
  }
  return jsonResponse(envelope({ approved: true, version }));
}

export async function handleTransitionStatus(
  req: Request,
  config: AppConfig,
  incidentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnyPermission(auth.claims, ["manageSupport"]) ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;
  const claims = auth.claims;

  const body = await readJson<StatusTransitionRequest>(req);
  if (!body || !SUPPORT_STATUSES.includes(body.status as never)) {
    return errorEnvelope("VALIDATION", "a valid status is required", 422);
  }
  const resolutionSummary = typeof body.resolutionSummary === "string"
    ? body.resolutionSummary.slice(0, 2000)
    : null;

  const result = await withTenantContext(config, claims, async (db) => {
    const incident = await getIncident(db, claims, incidentId);
    if (!incident) return { notFound: true as const };
    if (incident.status === body.status) {
      return { updated: incident }; // idempotent no-op
    }
    const allowed = ALLOWED_TRANSITIONS[incident.status] ?? [];
    if (!allowed.includes(body.status)) {
      return { invalid: true as const, from: incident.status };
    }
    const updated = await updateIncidentStatus(db, claims, incidentId, incident.status, {
      status: body.status,
      resolvedBy: body.status === "resolved" ? claims.sub : null,
      resolutionSummary,
    });
    if (!updated) return { conflict: true as const };

    await insertEvent(db, claims, incidentId, {
      eventType: body.status === "resolved" ? "resolved" : "status_changed",
      actorUserId: claims.sub,
      fromValue: incident.status,
      toValue: body.status,
    });
    await recordServerAuditEvent(db, claims, {
      eventType: "supportIncidentStatusChanged",
      category: "support",
      entityType: "support_incident",
      entityId: incidentId,
      metadata: { from: incident.status, to: body.status },
      correlationId: correlationIdFromRequest(req),
    }, req);

    await notifyReporter(
      db,
      claims,
      incident,
      `${incident.public_ref} is now ${body.status.replace(/_/g, " ")}`,
      body.status === "resolved"
        ? "Your reported issue has been resolved."
        : "The status of your reported issue changed.",
    );
    return { updated };
  });

  if ("notFound" in result) return errorEnvelope("NOT_FOUND", "Incident not found", 404);
  if ("invalid" in result) {
    return errorEnvelope("VALIDATION", `Cannot move from ${result.from} to ${body.status}`, 422);
  }
  if ("conflict" in result) {
    return errorEnvelope("CONFLICT", "Status changed concurrently; retry", 409);
  }
  return jsonResponse(envelope(result.updated));
}

// Rebuild a minimal ClientContext from the stored evidence so a support-side
// re-collection re-runs the audit + diagnostics without the original request.
function reconstructContextFromEvidence(
  rows: EvidenceRow[],
  incident: IncidentRow,
): ClientContext {
  const clientCtx = rows.find((r) => r.kind === "client_context")?.payload as
    | Record<string, unknown>
    | undefined;
  const apiCalls = rows.find((r) => r.kind === "api_calls")?.payload as
    | Record<string, unknown>
    | undefined;
  const breadcrumbs = rows.find((r) => r.kind === "breadcrumbs")?.payload as
    | Record<string, unknown>
    | undefined;
  return {
    appVersion: (clientCtx?.appVersion as string) ?? incident.app_version ?? undefined,
    platform: (clientCtx?.platform as string) ?? incident.platform ?? undefined,
    deviceModel: (clientCtx?.deviceModel as string) ?? incident.device_model ?? undefined,
    osVersion: (clientCtx?.osVersion as string) ?? incident.os_version ?? undefined,
    sessionId: (clientCtx?.sessionId as string) ?? incident.session_id ?? undefined,
    screenRoute: (clientCtx?.screenRoute as string) ?? incident.screen_route ?? undefined,
    moduleKey: (clientCtx?.moduleKey as string) ?? incident.module_key ?? undefined,
    correlationIds: Array.isArray(clientCtx?.correlationIds)
      ? (clientCtx!.correlationIds as string[])
      : (incident.correlation_id ? [incident.correlation_id] : []),
    breadcrumbs: Array.isArray(breadcrumbs?.items) ? (breadcrumbs!.items as never[]) : [],
    recentApiCalls: Array.isArray(apiCalls?.items) ? (apiCalls!.items as never[]) : [],
  };
}
