import type { AppConfig } from "../config.ts";
import { recordServerAuditEvent } from "../audit/audit_repository.ts";
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
import { loadCopilotContext } from "./copilot_context_engine.ts";
import { generateCopilotResponse } from "./copilot_llm_client.ts";
import { classifyDomain, SCHOOL_ASSISTANT_REFUSAL } from "../ai/domain_gate.ts";
import { checkCopilotQuota, copilotQuotaMessage } from "../ai/ai_copilot_quota.ts";
import { resolveAiConfig } from "../ai/ai_settings.ts";
import { getAiEconomics } from "../ai/ai_economics_service.ts";
import { buildSystemPrompt } from "./copilot_prompt_orchestrator.ts";
import {
  appendCopilotMessage,
  claimsHasPermission,
  CopilotSessionNotFoundError,
  createCopilotSession,
  getCopilotSession,
  listCopilotMessages,
  listCopilotSessions,
  updateSessionRollingSummary,
  updateSessionTitle,
} from "./copilot_repository.ts";
import {
  COPILOT_ASSISTANTS,
  COPILOT_ASSISTANT_TYPES,
  COPILOT_SUGGESTED_PROMPTS,
  type CopilotAssistantType,
} from "./copilot_types.ts";

function requireCopilotView(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewAiCopilot") ??
    requireSchoolOperationalScope(claims);
}

function requireCopilotRun(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "runAiCopilot") ??
    requireSchoolOperationalScope(claims);
}

function assistantForType(type: string): (typeof COPILOT_ASSISTANTS)[number] | null {
  return COPILOT_ASSISTANTS.find((a) => a.type === type) ?? null;
}

/** GET /copilot/economics — the N10 AI cost panel: this school's month-to-date
 * spend vs cap, calls by outcome/surface, cache hit ratio and tokens saved. */
export async function handleAiEconomics(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireCopilotView(auth.claims);
  if (denied) return denied;
  try {
    const economics = await withTenantContext(config, auth.claims, (db) =>
      getAiEconomics(db, {
        organizationId: organizationIdFromClaims(auth.claims),
        schoolId: schoolIdFromClaims(auth.claims)!,
      }));
    return jsonResponse(envelope(economics));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", String(error), 500);
  }
}

function sessionToApi(row: Awaited<ReturnType<typeof listCopilotSessions>>[number]) {
  return {
    id: row.id,
    assistantType: row.assistant_type,
    title: row.title,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function messageToApi(row: Awaited<ReturnType<typeof listCopilotMessages>>[number]) {
  return {
    id: row.id,
    sessionId: row.session_id,
    role: row.role,
    content: row.content,
    metadata: row.metadata,
    createdAt: row.created_at,
  };
}

export async function handleListAssistants(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireCopilotView(auth.claims);
  if (denied) return denied;

  const items = COPILOT_ASSISTANTS.filter((assistant) =>
    claimsHasPermission(auth.claims, assistant.requiredViewPermission)
  ).map((assistant) => ({
    type: assistant.type,
    label: assistant.label,
    description: assistant.description,
    skills: assistant.skills,
  }));

  return jsonResponse(envelope({ items }));
}

export async function handleListSuggestions(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireCopilotView(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const assistant = url.searchParams.get("assistant") ?? "";
  if (!COPILOT_ASSISTANT_TYPES.includes(assistant as CopilotAssistantType)) {
    return errorEnvelope("VALIDATION_ERROR", "assistant query param required", 422);
  }

  const definition = assistantForType(assistant);
  if (!definition || !claimsHasPermission(auth.claims, definition.requiredViewPermission)) {
    return errorEnvelope("FORBIDDEN", "Assistant not available for this role", 403);
  }

  return jsonResponse(envelope({
    assistant,
    prompts: COPILOT_SUGGESTED_PROMPTS[assistant as CopilotAssistantType],
  }));
}

export async function handleListSessions(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireCopilotView(auth.claims);
  if (denied) return denied;

  try {
    const sessions = await withTenantContext(config, auth.claims, async (db) =>
      await listCopilotSessions(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
        auth.claims.sub,
      )
    );
    return jsonResponse(envelope({ items: sessions.map(sessionToApi) }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to list copilot sessions", 500);
  }
}

export async function handleCreateSession(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireCopilotRun(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ assistantType?: string; title?: string }>(req);
  const assistantType = body?.assistantType ?? "";
  if (!COPILOT_ASSISTANT_TYPES.includes(assistantType as CopilotAssistantType)) {
    return errorEnvelope("VALIDATION_ERROR", "assistantType required", 422);
  }

  const definition = assistantForType(assistantType);
  if (!definition || !claimsHasPermission(auth.claims, definition.requiredViewPermission)) {
    return errorEnvelope("FORBIDDEN", "Assistant not available for this role", 403);
  }

  try {
    const session = await withTenantContext(config, auth.claims, async (db) => {
      const created = await createCopilotSession(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
        auth.claims.sub,
        assistantType as CopilotAssistantType,
        // ai_copilot_sessions.title is NOT NULL; the client may omit it, so
        // fall back to the assistant's label instead of inserting NULL (500).
        body?.title?.trim() || definition.label,
      );
      await recordServerAuditEvent(db, auth.claims, {
        eventType: "aiCopilotSessionCreated",
        category: "workflow",
        entityType: "ai_copilot_session",
        entityId: created.id,
        metadata: { assistantType },
      }, req);
      return created;
    });
    return jsonResponse(envelope(sessionToApi(session)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to create copilot session", 500);
  }
}

export async function handleGetSession(
  req: Request,
  config: AppConfig,
  sessionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireCopilotView(auth.claims);
  if (denied) return denied;

  try {
    const detail = await withTenantContext(config, auth.claims, async (db) => {
      const orgId = organizationIdFromClaims(auth.claims);
      const schoolId = schoolIdFromClaims(auth.claims)!;
      const session = await getCopilotSession(db, orgId, schoolId, auth.claims.sub, sessionId);
      if (!session) return null;
      const messages = await listCopilotMessages(db, orgId, schoolId, sessionId);
      return { session, messages };
    });
    if (!detail) {
      return errorEnvelope("NOT_FOUND", "Session not found", 404);
    }
    return jsonResponse(envelope({
      session: sessionToApi(detail.session),
      messages: detail.messages.map(messageToApi),
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load copilot session", 500);
  }
}

export async function handleSendMessage(
  req: Request,
  config: AppConfig,
  sessionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireCopilotRun(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ content?: string; screenContext?: Record<string, unknown> }>(req);
  const content = body?.content?.trim() ?? "";
  const screenContext = body?.screenContext;
  if (!content) {
    return errorEnvelope("VALIDATION_ERROR", "content required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims)!;

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const session = await getCopilotSession(db, orgId, schoolId, auth.claims.sub, sessionId);
      if (!session) throw new CopilotSessionNotFoundError(sessionId);

      const definition = assistantForType(session.assistant_type);
      if (!definition || !claimsHasPermission(auth.claims, definition.requiredViewPermission)) {
        throw new Error("ASSISTANT_FORBIDDEN");
      }

      const priorMessages = await listCopilotMessages(db, orgId, schoolId, sessionId);
      const context = await loadCopilotContext(
        db,
        auth.claims,
        orgId,
        schoolId,
        session.assistant_type as CopilotAssistantType,
        content,
      );
      const systemPrompt = buildSystemPrompt(
        session.assistant_type as CopilotAssistantType,
        context,
        screenContext,
      );

      await recordServerAuditEvent(db, auth.claims, {
        eventType: "aiCopilotQuery",
        category: "workflow",
        entityType: "ai_copilot_session",
        entityId: sessionId,
        metadata: {
          assistantType: session.assistant_type,
          promptLength: String(content.length),
          hasScreenContext: String(screenContext != null),
        },
      }, req);

      const userMessage = await appendCopilotMessage(
        db,
        orgId,
        schoolId,
        sessionId,
        "user",
        content,
      );

      // W2-GATE (doc 10 §3, owner-locked rule 6): the school-only Domain Gate —
      // the FIRST AI firewall gate. An off-domain request (politics, movies,
      // sports, code, medical, recipes, travel, general knowledge…) is refused
      // deterministically: 0 tokens, NO context load, NO model call. In-domain
      // and ambiguous requests fall through to the governed path below.
      const domain = classifyDomain(content);
      if (!domain.inDomain) {
        const refusal = await appendCopilotMessage(
          db,
          orgId,
          schoolId,
          sessionId,
          "assistant",
          SCHOOL_ASSISTANT_REFUSAL,
          { domainBlocked: true, model: "none", stub: false },
        );
        await recordServerAuditEvent(db, auth.claims, {
          eventType: "aiCopilotResponse",
          category: "workflow",
          entityType: "ai_copilot_session",
          entityId: sessionId,
          metadata: {
            assistantType: session.assistant_type,
            domainBlocked: "true",
            reason: domain.reason,
          },
        }, req);
        return { userMessage, assistantMessage: refusal, model: "none", stub: false };
      }

      // W2 governance (doc 10 §8, owner-locked rule 9): per-role daily open-chat
      // quota. Model-path turns today vs the role's limit; over → a graceful,
      // deterministic, ZERO-token refusal (checked AFTER the free domain gate so
      // off-domain turns never consume a user's quota).
      const quota = await checkCopilotQuota(
        db,
        { organizationId: orgId, schoolId },
        auth.claims.sub,
        auth.claims.primary_role,
        new Date(),
      );
      if (!quota.allowed) {
        const limited = await appendCopilotMessage(
          db,
          orgId,
          schoolId,
          sessionId,
          "assistant",
          copilotQuotaMessage(quota.limit),
          { quotaExceeded: true, model: "none", stub: false },
        );
        await recordServerAuditEvent(db, auth.claims, {
          eventType: "aiCopilotResponse",
          category: "workflow",
          entityType: "ai_copilot_session",
          entityId: sessionId,
          metadata: {
            assistantType: session.assistant_type,
            quotaExceeded: "true",
            used: String(quota.used),
            limit: String(quota.limit),
          },
        }, req);
        return { userMessage, assistantMessage: limited, model: "none", stub: false };
      }

      const ai = await resolveAiConfig(db, orgId);
      const generation = await generateCopilotResponse({
        systemPrompt,
        history: priorMessages
          .filter((m) => m.role === "user" || m.role === "assistant")
          .map((m) => ({
            role: m.role as "user" | "assistant",
            content: m.content,
          })),
        userMessage: content,
        assistantType: session.assistant_type as CopilotAssistantType,
        context,
        model: ai.model,
        // Route the live call through the governed Model Gateway (W1.1b):
        // timeout + rate-limit + spend-cap + ai_call_log telemetry.
        db,
        gatewayContext: { organizationId: orgId, schoolId, userId: auth.claims.sub },
      });

      const assistantMessage = await appendCopilotMessage(
        db,
        orgId,
        schoolId,
        sessionId,
        "assistant",
        generation.content,
        { model: generation.model, stub: generation.stub },
      );

      // F5: persist the deterministic rolling summary of the turns dropped from
      // the window, so long conversations keep condensed context. Truly
      // best-effort: SAVEPOINT-guarded so a summary-write failure rolls back
      // ONLY the summary and never the already-persisted (and possibly billed)
      // reply/message/telemetry in this same transaction (H1).
      if (generation.summarizedCount && generation.summarizedCount > 0) {
        await db.queryObject("SAVEPOINT copilot_summary");
        try {
          await updateSessionRollingSummary(
            db,
            sessionId,
            generation.rollingSummary ?? "",
            generation.summarizedCount,
          );
          await db.queryObject("RELEASE SAVEPOINT copilot_summary");
        } catch {
          await db.queryObject("ROLLBACK TO SAVEPOINT copilot_summary");
        }
      }

      if (session.title === "New conversation" && content.length <= 120) {
        await updateSessionTitle(db, sessionId, content);
      }

      await recordServerAuditEvent(db, auth.claims, {
        eventType: "aiCopilotResponse",
        category: "workflow",
        entityType: "ai_copilot_session",
        entityId: sessionId,
        metadata: {
          assistantType: session.assistant_type,
          model: generation.model,
          stub: String(generation.stub),
        },
      }, req);

      return { userMessage, assistantMessage, model: generation.model, stub: generation.stub };
    });

    return jsonResponse(envelope({
      userMessage: messageToApi(result.userMessage),
      assistantMessage: messageToApi(result.assistantMessage),
      model: result.model,
      stub: result.stub,
    }));
  } catch (error) {
    if (error instanceof CopilotSessionNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof Error && error.message === "ASSISTANT_FORBIDDEN") {
      return errorEnvelope("FORBIDDEN", "Assistant not available for this role", 403);
    }
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope(
      "INTERNAL_ERROR",
      error instanceof Error ? error.message : "Failed to send copilot message",
      500,
    );
  }
}
