// PRC-A Batch 3 — how many credits an AI call costs (owner decision #3).
//
// "Product usage units, NOT currency semantics." So this file deliberately does
// NOT derive credits from `estimateCostMicros`. Doing so would smuggle currency
// straight back in: the wallet would silently re-price whenever the provider's
// rates or our micro-USD table changed, and a school's "500 credits" would buy a
// different amount of work each month. A credit must mean a fixed amount of
// PRODUCT, decided by us, stable across provider pricing.
//
// Credits are therefore a small integer per call, tiered by model weight. The
// tiering MIRRORS the shape of `priceFor()` in model_gateway.ts (opus > sonnet >
// haiku) so there is one recognisable notion of "heavier model costs more" —
// but the numbers are our own product units, not a currency conversion, and they
// do not move when provider prices do.
//
// Integer throughout, matching the ai_* domain's BIGINT convention. No floats,
// so no rounding drift can accumulate across millions of calls.

/** Any unrecognised model falls to the mid tier — conservative, never free. */
export const DEFAULT_CREDITS_PER_CALL = 3;

/**
 * Credits per model call. Same tier ORDER as the gateway's micro-USD price
 * table, expressed in product units.
 */
export function creditsForCall(model: string): number {
  const m = (model ?? "").toLowerCase();
  if (m.includes("opus")) return 15;
  if (m.includes("haiku")) return 1;
  // sonnet + any unknown model → mid/conservative tier.
  return DEFAULT_CREDITS_PER_CALL;
}

/**
 * What to HOLD at reservation time, before the model has been called and the
 *actual model is known. The gateway reserves against the model it intends to use,
 * so this is the same function — kept as a named seam so the reserve-time and
 * settle-time policies can diverge later without hunting call sites.
 */
export function reservedCreditsFor(model: string): number {
  return creditsForCall(model);
}
