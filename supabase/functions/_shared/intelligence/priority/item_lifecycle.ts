// Living Dashboard — item lifecycle & visibility resolution (design:
// docs/design/living-dashboard/LIVING_DASHBOARD_ARCHITECTURE.md §3.2/§3.3).
//
// WHY THIS EXISTS
// ---------------
// Before this file, a dismissal was destructive: `buildFeed` filtered dismissed
// itemKeys out BEFORE scoring, so the item was erased from the response. A
// principal who dismissed "8 approvals overdue" never saw it again — not at 40
// approvals, not when it went overdue. There was no snooze, no state, and no way
// for any other surface (Copilot) to learn what the user had put away.
//
// The inversion: score EVERY item, then resolve visibility as an overlay. That
// single change makes three things decidable that were not:
//   · "reappears when severity increases"  — compare current score to the score
//     recorded when the user acted (the watermark).
//   · "reappears when the deadline approaches" — compare urgency BANDS, not raw
//     days, so an item resurfaces once per meaningful step, not daily.
//   · "Copilot remembers every widget"     — hidden items are still computed, so
//     rehydration is a filter change, not a re-fetch.
//
// PURITY CONTRACT (load-bearing — mirrored by priority_engine.ts and asserted by
// item_lifecycle_test.ts): no I/O, no Date.now(), no clock. `nowIso` is injected
// by the caller, exactly as the existing generators receive `generatedAt`. This
// is what keeps the feed deterministic and replayable.
//
// NO SCHEDULER REQUIRED: because visibility resolves at read time against the
// injected clock, a snooze expires the moment the user next opens the dashboard.
// Nothing needs to tick. (This deliberately avoids defect XMOD-016 — "nine
// periodic jobs, zero schedulers" — under which a wake-up cron would silently
// never fire.)

import { istDateOf } from "./feed_dates.ts";
import type { ScoredPriorityItem } from "./priority_types.ts";

/** The stored lifecycle of one item for one user.
 *
 * Provenance of each value — worth stating, because not all eight are written
 * the same way:
 *   · user-set   : `acknowledged`, `snoozed`, `completed`, `resolved`
 *   · system-set : `escalated` (resurfaced because it got worse), `expired`
 *                  (a snooze window elapsed)
 *   · derived    : `new` (normally NO row exists at all), `urgent` (score >= 75,
 *                  computed — never trusted from storage)
 * All eight are accepted by the table CHECK so a transition can be recorded
 * without a migration, but the resolver below only ever produces the real ones. */
export type ItemLifecycleState =
  | "new"
  | "urgent"
  | "acknowledged"
  | "snoozed"
  | "completed"
  | "expired"
  | "escalated"
  | "resolved";

export const ITEM_LIFECYCLE_STATES: readonly ItemLifecycleState[] = [
  "new",
  "urgent",
  "acknowledged",
  "snoozed",
  "completed",
  "expired",
  "escalated",
  "resolved",
] as const;

export function isItemLifecycleState(v: string): v is ItemLifecycleState {
  return (ITEM_LIFECYCLE_STATES as readonly string[]).includes(v);
}

/** Terminal states: the user finished the work. These never resurface on their
 * own — the item disappears when its generator stops emitting it, which is the
 * honest signal that the underlying condition actually cleared. */
const TERMINAL_STATES: ReadonlySet<ItemLifecycleState> = new Set([
  "completed",
  "resolved",
]);

/** One stored row, as the engine sees it (repository maps DB → this). */
export interface ItemLifecycleRecord {
  itemKey: string;
  state: ItemLifecycleState;
  /** ISO instant the snooze ends. Only meaningful when state === "snoozed". */
  snoozedUntil?: string | null;
  /** Normalized 0–100 score at the moment the user acted — the severity
   * watermark. NULL means "unknown baseline": we then never resurface on
   * severity, because we cannot honestly claim it got worse. */
  scoreAtAction?: number | null;
  /** `factors.dueInDays` at the moment the user acted — the deadline watermark.
   * NULL/undefined means the item had no clock then. */
  dueAtAction?: number | null;
  /** ISO instant of the user's action (drives the acknowledge day-boundary). */
  actedAt: string;
}

export type VisibilityReason =
  | "visible_new"
  | "visible_snooze_elapsed"
  | "visible_severity_increased"
  | "visible_deadline_advanced"
  | "visible_acknowledge_expired"
  | "hidden_snoozed"
  | "hidden_acknowledged"
  | "hidden_terminal";

export interface VisibilityDecision {
  visible: boolean;
  reason: VisibilityReason;
}

/** How much the 0–100 score must climb past the watermark before a put-away item
 * comes back. Tuned to be a real step, not noise: the score bands are ~11 points
 * apart (urgency tiers 1.0/1.4/1.8/2.4/3.0 over a 1–9 raw range), so 10 means
 * "it moved at least one meaningful tier" without re-nagging on rounding. */
export const ESCALATION_DELTA = 10;

/** Collapse `dueInDays` onto the same tiers `urgencyFactor` scores by, so a
 * deadline resurfaces an item ONCE per meaningful step (14d → 7d → 2d → due)
 * rather than every single day as the number ticks down. Higher = more urgent. */
export function urgencyBand(dueInDays: number | null | undefined): number {
  if (typeof dueInDays !== "number" || !Number.isFinite(dueInDays)) return 0;
  if (dueInDays <= 0) return 4;
  if (dueInDays <= 2) return 3;
  if (dueInDays <= 7) return 2;
  if (dueInDays <= 14) return 1;
  return 0;
}

/** Decide whether a scored item is shown to this user right now.
 *
 * Rule order is deliberate. Escalation is evaluated BEFORE snooze/acknowledge so
 * that a genuine worsening always breaks through something the user put away —
 * that is the whole point of "widgets may return when severity increases". The
 * only thing escalation does NOT override is a terminal state, because there the
 * user has told us the work is done.
 *
 * Pure: `nowIso` is the caller's clock. */
export function resolveVisibility(
  item: ScoredPriorityItem,
  record: ItemLifecycleRecord | null | undefined,
  nowIso: string,
): VisibilityDecision {
  // 1) Never acted on — the common case, and no row exists for it.
  if (!record) return { visible: true, reason: "visible_new" };

  // 2) The user finished it. Nothing resurfaces work that is done; the item
  //    vanishes when its generator stops emitting, which is the honest signal.
  if (TERMINAL_STATES.has(record.state)) {
    return { visible: false, reason: "hidden_terminal" };
  }

  // A record written by a real user action ALWAYS carries a score watermark —
  // every item is scored before it can be acted on. So a missing `scoreAtAction`
  // identifies a LEGACY row (a dismissal migrated out of the old
  // `ai_persona_memory.preferences.dismissedKeys` array, which stored no
  // baseline of any kind). For those we know nothing about the item's state at
  // dismissal time, so neither escalation rule may fire: claiming "it got worse"
  // or "the deadline advanced" against an unknown baseline would be fabricating
  // a comparison. They fall through to the ordinary acknowledge/snooze handling
  // below, which still returns them on the next day boundary.
  const hasBaseline = typeof record.scoreAtAction === "number";

  if (hasBaseline) {
    // 3) It got materially worse than when they put it away.
    if (item.score >= (record.scoreAtAction as number) + ESCALATION_DELTA) {
      return { visible: true, reason: "visible_severity_increased" };
    }

    // 4) The deadline crossed into a more urgent band since they acted. Here a
    //    null `dueAtAction` legitimately means "it had no clock then", so an
    //    item that has since acquired a deadline correctly resurfaces.
    if (urgencyBand(item.factors.dueInDays) > urgencyBand(record.dueAtAction)) {
      return { visible: true, reason: "visible_deadline_advanced" };
    }
  }

  // 5) Snooze: comes back the moment the window closes — resolved at read time,
  //    so no scheduler is involved.
  if (record.state === "snoozed") {
    const until = record.snoozedUntil ? Date.parse(record.snoozedUntil) : NaN;
    const now = Date.parse(nowIso);
    // An unparseable/absent snoozedUntil is treated as already elapsed: failing
    // OPEN here shows a real item, whereas failing closed would silently bury
    // work forever on a bad write.
    if (!Number.isFinite(until) || (Number.isFinite(now) && now >= until)) {
      return { visible: true, reason: "visible_snooze_elapsed" };
    }
    return { visible: false, reason: "hidden_snoozed" };
  }

  // 6) Acknowledge is day-scoped, following the `operations_hub_item_actions`
  //    precedent: "I have seen this today". If the condition is still true
  //    tomorrow, it legitimately deserves the user's attention again.
  if (record.state === "acknowledged" || record.state === "escalated") {
    if (istDateOf(record.actedAt) < istDateOf(nowIso)) {
      return { visible: true, reason: "visible_acknowledge_expired" };
    }
    return { visible: false, reason: "hidden_acknowledged" };
  }

  // 7) `new` / `urgent` / `expired` carry no suppression.
  return { visible: true, reason: "visible_new" };
}

/** Index lifecycle rows by itemKey for the engine's overlay pass. */
export function lifecycleIndex(
  records: readonly ItemLifecycleRecord[],
): Map<string, ItemLifecycleRecord> {
  const byKey = new Map<string, ItemLifecycleRecord>();
  for (const r of records) byKey.set(r.itemKey, r);
  return byKey;
}
