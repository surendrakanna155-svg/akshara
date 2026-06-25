// Publisher — AI caption enhancement (reuses the shared Claude client).
//
// Takes the deterministic, subject-aware asset bundle and asks Claude for sharper
// per-channel captions. Safe-by-default: no API key / refusal / bad JSON / any
// error → the deterministic captions are kept unchanged (never blocks publish,
// never fabricates beyond the given title/description).

import { aiApiKey, callClaude, claudeModel } from "../ai/anthropic_client.ts";

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
 */
export async function enhanceCaptionsWithAi(
  assets: Record<string, unknown>,
  ctx: CaptionContext,
): Promise<Record<string, unknown>> {
  const key = aiApiKey();
  if (!key) return assets;

  const system =
    "You write short, warm captions for an Indian school's social posts. " +
    "Use only the facts given. No new claims, no emojis spam, max ~200 characters each. " +
    "Reply ONLY with compact JSON: {\"poster\":\"\",\"whatsapp\":\"\",\"instagram\":\"\",\"facebook\":\"\"}.";
  const user = `Type: ${ctx.subjectType}\nTitle: ${ctx.title}\n` +
    (ctx.description ? `Details: ${ctx.description}\n` : "") +
    "Write one caption per channel.";

  let parsed: Record<string, unknown> | null = null;
  try {
    const result = await callClaude({
      system,
      messages: [{ role: "user", content: user }],
      maxTokens: 400,
      model: claudeModel(),
      apiKey: key,
    });
    if (result.refused || !result.text) return assets;
    const match = result.text.match(/\{[\s\S]*\}/);
    if (!match) return assets;
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
