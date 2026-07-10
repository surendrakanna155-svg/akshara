// Adaptive AI — P3-AI-1 / W1-completion F3: output-side response guard.
//
// The design's second injection wall (doc 02 §5.3): the input side fences
// untrusted data as DATA-not-instructions; this side validates the model's
// REPLY before it is ever served or cached. A violation is discarded — the
// caller's deterministic fallback is served instead and the gateway logs a
// `fallback_guard` outcome. Pure + deterministic so every branch is unit-tested
// without a model or DB. Opt-in per surface (narrative surfaces like copilot);
// structured-JSON callers keep their own field re-validation.
//
// Checks (all conservative, to avoid discarding correct answers):
//   • length  — reply longer than the surface bound (runaway / prompt echo)
//   • url     — a link whose host was not in the provided context (exfil/inject)
//   • inject  — the reply echoes an injection directive or our fence sentinel
//   • number  — a ₹ amount or percentage not present in the injected facts
//               (the rail: the model NEVER computes numbers — they are injected;
//                a currency/percentage the context never mentioned is fabricated)

export type GuardReason = "length" | "url" | "injection" | "number";

export interface GuardResult {
  ok: boolean;
  reason?: GuardReason;
}

export interface GuardOptions {
  /** Hard character cap on the reply (default 8000 ≈ well past any bounded T3). */
  maxChars?: number;
  /** Narrative surfaces legitimately DERIVE percentages from injected counts
   * ("2 of 5 schools (40%)"); enforcing PERCENT_RE there discards correct
   * replies constantly (audit P2-2). When set, only currency amounts must
   * appear verbatim in the context; percentages are exempt. */
  allowDerivedPercents?: boolean;
}

const DEFAULT_MAX_CHARS = 8000;

// Conservative injection-echo markers. A legitimate school-data answer never
// contains these; a steered reply that reproduces attacker instructions does.
const INJECTION_MARKERS = [
  "ignore previous instruction",
  "ignore all previous",
  "ignore the above",
  "disregard previous",
  "disregard the above",
  "disregard all prior",
  "you are now",
  "new instructions:",
  "system prompt",
  // Our own fence sentinels must never appear in output. The real sentinels
  // are ⟦UNTRUSTED_DATA⟧ / ⟦/UNTRUSTED_DATA⟧ (prompt_safety.ts) — the
  // underscore form below matches both, lowercased (audit P3-1: the earlier
  // "<<untrusted"/"untrusted-data" guesses matched neither and were dead).
  "untrusted_data",
  "<<untrusted",
  "untrusted-data",
];

const URL_RE = /\bhttps?:\/\/([^\s/"'<>)\]}?#]+)/gi;
// A number: digit-groups with an OPTIONAL decimal part only when digits follow
// (so a trailing sentence period is never captured — "8,500." → "8,500").
const NUMBER_RE = /\d[\d,]*(?:\.\d+)?/g;
// A ₹/Rs/INR currency amount, or a percentage — the two number classes that are
// facts (never legitimately model-computed) per the rails.
const CURRENCY_RE = /(?:₹|\brs\.?|\binr)\s*(\d[\d,]*(?:\.\d+)?)/gi;
const PERCENT_RE = /(\d[\d,]*(?:\.\d+)?)\s*(?:%|percent\b)/gi;

function normalizeNumber(raw: string): string {
  const cleaned = raw
    .replace(/,/g, "")
    .replace(/(\.\d*?)0+$/, "$1") // strip trailing fractional zeros: 8500.50 → 8500.5 (H4)
    .replace(/\.$/, ""); // 8500. → 8500
  return cleaned.replace(/^0+(?=\d)/, ""); // drop leading zeros but keep "0"
}

/** All digit-groups present in the provided context, normalized for matching. */
function contextNumbers(context: string): Set<string> {
  const set = new Set<string>();
  for (const m of context.matchAll(NUMBER_RE)) {
    set.add(normalizeNumber(m[0]));
  }
  return set;
}

function contextHosts(context: string): Set<string> {
  const set = new Set<string>();
  const lower = context.toLowerCase();
  for (const m of lower.matchAll(URL_RE)) {
    set.add(m[1]!.split("/")[0]!);
  }
  return set;
}

/**
 * Validate a model reply against the provided context (system prompt + user
 * turn — the only material the model was given). Returns `{ok:true}` when the
 * reply is safe to serve, else `{ok:false, reason}`.
 */
export function guardModelReply(
  reply: string,
  context: string,
  opts?: GuardOptions,
): GuardResult {
  const maxChars = opts?.maxChars ?? DEFAULT_MAX_CHARS;
  if (reply.length > maxChars) return { ok: false, reason: "length" };

  const lower = reply.toLowerCase();
  for (const marker of INJECTION_MARKERS) {
    if (lower.includes(marker)) return { ok: false, reason: "injection" };
  }

  const allowedHosts = contextHosts(context);
  for (const m of lower.matchAll(URL_RE)) {
    const host = m[1]!.split("/")[0]!;
    if (!allowedHosts.has(host)) return { ok: false, reason: "url" };
  }

  const ctxNums = contextNumbers(context);
  const numberChecks = opts?.allowDerivedPercents ? [CURRENCY_RE] : [CURRENCY_RE, PERCENT_RE];
  for (const re of numberChecks) {
    for (const m of reply.matchAll(re)) {
      if (!ctxNums.has(normalizeNumber(m[1]!))) return { ok: false, reason: "number" };
    }
  }

  return { ok: true };
}
