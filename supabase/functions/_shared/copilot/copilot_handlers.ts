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
import { resolveAiConfig } from "../ai/ai_settings.ts";
import { buildSystemPrompt } from "./copilot_prompt_orchestrator.ts";
import {
  appendCopilotMessage,
  claimsHasPermission,
  CopilotSessionNotFoundError,
  createCopilotSession,
  getCopilotSession,
  listCopilotMessages,
  listCopilotSessions,
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
        apiKey: ai.apiKey,
        provider: ai.provider,
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
