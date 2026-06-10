import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { CopilotAssistantType } from "./copilot_types.ts";

export const AI_COPILOT_SESSION_PROBE_SCHOOL_A = "d0400000-0000-4000-8000-000000000001";
export const AI_COPILOT_SESSION_PROBE_SCHOOL_B = "d0400000-0000-4000-8000-000000000002";
export const AI_COPILOT_SESSION_PROBE_SQL = `
  SELECT count(*)::text AS count FROM ai_copilot_sessions WHERE id = $1::uuid
`;

export interface CopilotSessionRow {
  id: string;
  assistant_type: string;
  title: string;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface CopilotMessageRow {
  id: string;
  session_id: string;
  role: string;
  content: string;
  metadata: Record<string, unknown>;
  created_at: string;
}

export class CopilotSessionNotFoundError extends Error {
  constructor(id: string) {
    super(`Copilot session not found: ${id}`);
    this.name = "CopilotSessionNotFoundError";
  }
}

export async function listCopilotSessions(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  userId: string,
): Promise<CopilotSessionRow[]> {
  return await db.queryObject<CopilotSessionRow>(
    `SELECT id, assistant_type, title, status, created_at, updated_at
     FROM ai_copilot_sessions
     WHERE organization_id = $1 AND school_id = $2 AND user_id = $3 AND status = 'active'
     ORDER BY updated_at DESC
     LIMIT 50`,
    [organizationId, schoolId, userId],
  );
}

export async function createCopilotSession(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  userId: string,
  assistantType: CopilotAssistantType,
  title?: string,
): Promise<CopilotSessionRow> {
  const rows = await db.queryObject<CopilotSessionRow>(
    `INSERT INTO ai_copilot_sessions (
       organization_id, school_id, user_id, assistant_type, title
     ) VALUES ($1, $2, $3, $4, $5)
     RETURNING id, assistant_type, title, status, created_at, updated_at`,
    [
      organizationId,
      schoolId,
      userId,
      assistantType,
      title?.trim() || "New conversation",
    ],
  );
  return rows[0]!;
}

export async function getCopilotSession(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  userId: string,
  sessionId: string,
): Promise<CopilotSessionRow | null> {
  const rows = await db.queryObject<CopilotSessionRow>(
    `SELECT id, assistant_type, title, status, created_at, updated_at
     FROM ai_copilot_sessions
     WHERE id = $1 AND organization_id = $2 AND school_id = $3 AND user_id = $4`,
    [sessionId, organizationId, schoolId, userId],
  );
  return rows[0] ?? null;
}

export async function listCopilotMessages(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  sessionId: string,
): Promise<CopilotMessageRow[]> {
  return await db.queryObject<CopilotMessageRow>(
    `SELECT id, session_id, role, content, metadata, created_at
     FROM ai_copilot_messages
     WHERE session_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY created_at ASC`,
    [sessionId, organizationId, schoolId],
  );
}

export async function appendCopilotMessage(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  sessionId: string,
  role: "user" | "assistant" | "system",
  content: string,
  metadata: Record<string, unknown> = {},
): Promise<CopilotMessageRow> {
  const rows = await db.queryObject<CopilotMessageRow>(
    `INSERT INTO ai_copilot_messages (
       session_id, organization_id, school_id, role, content, metadata
     ) VALUES ($1, $2, $3, $4, $5, $6::jsonb)
     RETURNING id, session_id, role, content, metadata, created_at`,
    [sessionId, organizationId, schoolId, role, content, JSON.stringify(metadata)],
  );

  await db.queryObject(
    `UPDATE ai_copilot_sessions
     SET updated_at = timezone('utc', now())
     WHERE id = $1`,
    [sessionId],
  );

  return rows[0]!;
}

export async function updateSessionTitle(
  db: TenantQueryClient,
  sessionId: string,
  title: string,
): Promise<void> {
  await db.queryObject(
    `UPDATE ai_copilot_sessions SET title = $2, updated_at = timezone('utc', now()) WHERE id = $1`,
    [sessionId, title.slice(0, 120)],
  );
}

export function claimsHasPermission(claims: AccessTokenClaims, slug: string): boolean {
  return claims.permissions?.includes(slug) ?? false;
}
