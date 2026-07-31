// Living Dashboard Phase 5 — what Copilot knows about the user's dashboard.
//
// THE REQUIREMENT
// ---------------
// "Copilot must remember every widget. Even after dismissal. User dismisses
// Transport Delay, later asks 'show transport details' — Copilot immediately
// restores the complete transport context. Dashboard dismissal never deletes
// information."
//
// WHY THIS IS NOW POSSIBLE
// ------------------------
// It was not, before Phase 1. `buildFeed` filtered dismissed itemKeys out BEFORE
// scoring, so a put-away item was erased from the response and no other surface
// could learn it existed. Phase 1 inverted that: every item is scored and
// visibility is resolved as an overlay, and `buildFeed({includeHidden: true})`
// returns the put-away ones alongside the visible ones. Rehydration is therefore
// a filter change, not a re-fetch — which is exactly what that inversion was for.
//
// RECOMPUTED, NEVER REPLAYED
// --------------------------
// This deliberately regenerates the feed under the caller's CURRENT permissions
// rather than reading a stored snapshot of what they once saw. Storing titles
// would be cheaper and would also survive the underlying condition clearing —
// but a stored title is a frozen copy of data the user may since have lost the
// right to read, and Copilot is a surface where that leak would be invisible.
// Recomputation cannot leak: an item the caller can no longer generate simply
// does not appear.
//
// The trade-off, stated plainly: if the underlying condition has CLEARED, the
// generator stops emitting the item and Copilot will not rehydrate it. That is
// the honest outcome — there is no live work left to restore, and inventing a
// card for a resolved condition would be fabrication.

import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { buildFeed } from "../intelligence/priority/priority_engine.ts";
import { loadPersonaFeedContext } from "../intelligence/priority/priority_feed_service.ts";
import { isPersona, type Persona } from "../intelligence/priority/priority_types.ts";

/** Loading the feed is not free (analytics bundle + risk + ops worklists), so
 * it is gated on the message plausibly being about the user's dashboard or
 * something they put away. Mirrors the `studentLookup` slot's message-driven
 * pattern — the only existing precedent for a conditional context loader. */
const DASHBOARD_INTENT =
  /\b(dashboard|priorit(y|ies)|dismiss(ed)?|snooz(e|ed)|put away|hidden|hid|earlier|remind(er|ed)?|task|pending|approval|overdue|what did i|show me)\b/i;

export function wantsDashboardContext(userMessage: string): boolean {
  return DASHBOARD_INTENT.test(userMessage);
}

/** Map the caller's assistant/role onto a feed persona. Returns null when no
 * feed applies, so the slot reports `not_applicable` rather than guessing. */
export function personaForCopilot(claims: AccessTokenClaims): Persona | null {
  if (claims.scope === "parent") return "parent";
  if (claims.scope === "student") return "student";
  const role = (claims.primary_role ?? claims.role ?? "").toString();
  if (isPersona(role)) return role;
  if (role === "vicePrincipal") return "principal";
  if (role === "financeAdmin" || role === "accountant") return "finance";
  if (role === "teacher") return "teacher";
  // Any other staff role reads the school feed as an admin would.
  return "admin";
}

export interface DashboardContextItem {
  itemKey: string;
  type: string;
  title: string;
  detail: string;
  score: number;
  reason: string;
  /** Why the dashboard is hiding it — `hidden_snoozed`, `hidden_acknowledged`,
   * `hidden_terminal`. Present only on put-away items. */
  hiddenBecause?: string;
}

export interface DashboardContext extends Record<string, unknown> {
  access: string;
  persona?: string;
  /** What is on the user's dashboard right now. */
  onDashboard?: DashboardContextItem[];
  /** What they put away and can ask to be reminded of. This is the half that
   * did not exist before Phase 1. */
  putAway?: DashboardContextItem[];
}

const MAX_PER_GROUP = 8;

/** Load the caller's dashboard state — visible AND put-away — for the prompt. */
export async function loadDashboardContext(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  userMessage: string,
  nowIso: string,
): Promise<DashboardContext> {
  if (!wantsDashboardContext(userMessage)) return { access: "not_requested" };

  const persona = personaForCopilot(claims);
  if (!persona) return { access: "not_applicable" };

  // RBAC is enforced INSIDE the loader, per source, exactly as it is for the
  // dashboard itself — this path widens nothing.
  const ctx = await loadPersonaFeedContext(db, claims, persona, nowIso);
  const feed = buildFeed(ctx.rawItems, persona, nowIso, {
    weights: ctx.weights,
    lifecycle: ctx.lifecycle,
    nowIso,
    includeHidden: true,
    limit: MAX_PER_GROUP,
  });

  const shape = (it: {
    itemKey: string;
    type: string;
    title: string;
    detail: string;
    score: number;
    reason: string;
    visibilityReason?: string;
  }, hidden: boolean): DashboardContextItem => ({
    itemKey: it.itemKey,
    type: it.type,
    title: it.title,
    detail: it.detail,
    score: it.score,
    reason: it.reason,
    ...(hidden && it.visibilityReason ? { hiddenBecause: it.visibilityReason } : {}),
  });

  return {
    access: "granted",
    persona,
    onDashboard: feed.items.map((it) => shape(it, false)),
    putAway: (feed.hidden ?? []).slice(0, MAX_PER_GROUP).map((it) => shape(it, true)),
  };
}
