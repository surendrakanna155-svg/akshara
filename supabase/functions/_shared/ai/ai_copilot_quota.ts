// Adaptive AI — P3-AI-2 / W2 governance: per-role daily copilot (open-chat) quota
// (design doc 10 §8, owner-locked rule 9 — token usage must stay predictable).
//
// Open chat is the expensive tail, so it is metered PER ROLE PER DAY on top of
// the W1 per-user/hour + per-school/day rate limits + monthly spend cap. Enforced
// at the copilot handler (reuse-first — no change to the W1 gateway signature):
// a user's copilot ai_call_log rows today (model-path turns; domain-refused free
// turns never reach the gateway, so they don't count) are compared to their
// role's limit. Over quota → a graceful, deterministic refusal at ZERO tokens.

import type { TenantQueryClient } from "../tenant_db.ts";
import { type AiTenantScope, countUserSurfaceCallsSince } from "./ai_call_log_repository.ts";

export const COPILOT_SURFACE = "copilot";

/** Starting per-role daily limits (doc 10 §8 — tune at pilot from ai_call_log).
 * A single env override `AI_COPILOT_DAILY_LIMIT` caps ALL roles when set. */
const ROLE_DAILY_LIMITS: Record<string, number> = {
  student: 10,
  parent: 10,
  teacher: 20,
  principal: 30,
  vicePrincipal: 30,
  management: 20,
  director: 20,
  correspondent: 20,
};

const DEFAULT_ROLE_LIMIT = 30;

function envOverride(): number | null {
  const raw = Deno.env.get("AI_COPILOT_DAILY_LIMIT");
  if (!raw) return null;
  const n = Number.parseInt(raw, 10);
  return Number.isFinite(n) && n > 0 ? n : null;
}

/** The daily copilot-message limit for a role slug (env override wins). */
export function roleDailyCopilotLimit(roleSlug: string): number {
  const override = envOverride();
  if (override !== null) return override;
  return ROLE_DAILY_LIMITS[roleSlug] ?? DEFAULT_ROLE_LIMIT;
}

/** Pure decision: has the user hit their daily limit? */
export function copilotQuotaExceeded(used: number, limit: number): boolean {
  return used >= limit;
}

/** Start-of-day (UTC) ISO for the day containing `now` — the quota window. */
export function startOfUtcDayIso(now: Date): string {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())).toISOString();
}

/** The graceful, zero-token message served when the daily quota is spent. */
export function copilotQuotaMessage(limit: number): string {
  return `You've reached today's AI assistant limit (${limit} messages). ` +
    `Your dashboards, search, and reports still work as usual — please try the ` +
    `AI assistant again tomorrow.`;
}

export interface CopilotQuotaVerdict {
  allowed: boolean;
  used: number;
  limit: number;
}

/** Check the caller's daily copilot quota (model-path turns today vs role limit).
 * Deterministic, read-only, zero tokens. */
export async function checkCopilotQuota(
  db: TenantQueryClient,
  scope: AiTenantScope,
  userId: string,
  roleSlug: string,
  now: Date,
): Promise<CopilotQuotaVerdict> {
  const limit = roleDailyCopilotLimit(roleSlug);
  const used = await countUserSurfaceCallsSince(
    db,
    scope,
    userId,
    COPILOT_SURFACE,
    startOfUtcDayIso(now),
  );
  return { allowed: !copilotQuotaExceeded(used, limit), used, limit };
}
