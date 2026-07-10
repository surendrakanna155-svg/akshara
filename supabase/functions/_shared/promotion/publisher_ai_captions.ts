// Publisher — AI caption enhancement (reuses the shared Claude client).
//
// Takes the deterministic, subject-aware asset bundle and asks Claude for sharper
// per-channel captions. Safe-by-default: no API key / refusal / bad JSON / any
// error → the deterministic captions are kept unchanged (never blocks publish,
// never fabricates beyond the given title/description).

import { governedModelText } from "../ai/model_gateway.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

const CHANNELS = ["poster", "whatsapp", "instagram", "facebook"] as const;
type Channel = typeof CHANNELS[number];

export interface CaptionContext {
  subjectType: string;
  title: string;
  description?: string | null;
}

function asObject(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" ? value as Record<string, unknown> : null;
}

/**
 * Returns a copy of the asset record with AI-refined captions where available.
 * Pure overlay — only the `caption` string of known channels can change.
 *
 * AI-3: resolves the effective AI config from the admin Control Center panel
 * (falling back to env), so an org that configured AI only via the panel still
 * gets AI captions instead of silently dropping to deterministic ones.
 */
export async function enhanceCaptionsWithAi(
  db: TenantQueryClient,
  orgId: string | null,
  assets: Record<string, unknown>,
  ctx: CaptionContext,
  schoolId: string | null = null,
  userId: string | null = null,
): Promise<Record<string, unknown>> {
  if (!orgId) return assets;

  const system =
    "You write short, warm captions for an Indian school's social posts. " +
    "Use only the facts given. No new claims, no emojis spam, max ~200 characters each. " +
    "Reply ONLY with compact JSON: {\"poster\":\"\",\"whatsapp\":\"\",\"instagram\":\"\",\"facebook\":\"\"}.";
  const user = `Type: ${ctx.subjectType}\nTitle: ${ctx.title}\n` +
    (ctx.description ? `Details: ${ctx.description}\n` : "") +
    "Write one caption per channel.";

  // Governed (timeout + rate-limit + spend-cap + ai_call_log); null text →
  // no live answer → keep deterministic captions.
  const text = await governedModelText(db, {
    organizationId: orgId,
    schoolId,
    userId,
    surface: "promotion_captions",
  }, { system, messages: [{ role: "user", content: user }], maxTokens: 400 });
  if (!text) return assets;

  const match = text.match(/\{[\s\S]*\}/);
  if (!match) return assets;
  let parsed: Record<string, unknown> | null = null;
  try {
    parsed = asObject(JSON.parse(match[0]));
  } catch {
    return assets; // safe fallback
  }
  if (!parsed) return assets;

  const next: Record<string, unknown> = { ...assets };
  for (const channel of CHANNELS) {
    const caption = parsed[channel];
    const asset = asObject(next[channel as Channel]);
    if (typeof caption === "string" && caption.trim().length > 0 && asset) {
      next[channel] = { ...asset, caption: caption.trim() };
    }
  }
  return next;
}
