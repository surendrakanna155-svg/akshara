// Living Dashboard — persistence for per-user item lifecycle state.
//
// Thin DB layer over `dashboard_item_state` (migration 20260920000400). All
// decision logic lives in the pure resolver `item_lifecycle.ts`; this file only
// reads rows and records the user's action. Every statement runs inside the
// caller's `withTenantContext` transaction, so RLS (per-user, not per-school)
// is what actually enforces isolation — the WHERE clauses here are for index
// selectivity, not security.

import type { TenantQueryClient } from "../../tenant_db.ts";
import {
  isItemLifecycleState,
  type ItemLifecycleRecord,
  type ItemLifecycleState,
} from "./item_lifecycle.ts";
import type { PriorityItemType } from "./priority_types.ts";

export interface ItemLifecycleScope {
  organizationId: string;
  schoolId: string | null;
  userId: string;
}

/** What the user did to one item. `snoozedUntil` is required for a snooze — the
 * table's CHECK rejects a snooze with no end, because that is a permanent bury
 * wearing a temporary label. */
export interface ItemActionInput {
  itemKey: string;
  state: ItemLifecycleState;
  itemType?: PriorityItemType | null;
  snoozedUntil?: string | null;
  /** The item's normalized 0-100 score right now — the severity watermark that
   * makes "bring it back if it gets worse" decidable. Callers should always pass
   * it; omitting it permanently disables escalation for this row. */
  scoreAtAction?: number | null;
  /** `factors.dueInDays` right now — the deadline watermark. */
  dueAtAction?: number | null;
}

interface LifecycleRow {
  item_key: string;
  state: string;
  snoozed_until: string | Date | null;
  score_at_action: number | string | null;
  due_at_action: number | string | null;
  acted_at: string | Date;
}

function toIso(v: string | Date): string {
  return v instanceof Date ? v.toISOString() : new Date(v).toISOString();
}

function toIsoOrNull(v: string | Date | null): string | null {
  return v === null ? null : toIso(v);
}

function toIntOrNull(v: number | string | null): number | null {
  if (v === null) return null;
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? n : null;
}

/** Every lifecycle row this user has. Unrecognized states are dropped rather
 * than coerced: a row we cannot interpret must not silently hide real work, and
 * the resolver treats "no record" as visible. */
export async function loadItemLifecycle(
  db: TenantQueryClient,
  scope: ItemLifecycleScope,
): Promise<ItemLifecycleRecord[]> {
  const rows = await db.queryObject<LifecycleRow>(
    `SELECT item_key, state, snoozed_until, score_at_action, due_at_action, acted_at
       FROM dashboard_item_state
      WHERE organization_id = $1
        AND school_id IS NOT DISTINCT FROM $2
        AND user_id = $3`,
    [scope.organizationId, scope.schoolId, scope.userId],
  );

  const records: ItemLifecycleRecord[] = [];
  for (const row of rows) {
    if (!isItemLifecycleState(row.state)) continue;
    records.push({
      itemKey: row.item_key,
      state: row.state,
      snoozedUntil: toIsoOrNull(row.snoozed_until),
      scoreAtAction: toIntOrNull(row.score_at_action),
      dueAtAction: toIntOrNull(row.due_at_action),
      actedAt: toIso(row.acted_at),
    });
  }
  return records;
}

/** Record one action, upserting the single row for (user, itemKey).
 *
 * `acted_at` is refreshed on every action on purpose: it is what the day-scoped
 * acknowledge rule measures from, so re-acknowledging an item that came back
 * legitimately buys another day rather than reusing the original stale date. */
export async function recordItemAction(
  db: TenantQueryClient,
  scope: ItemLifecycleScope,
  input: ItemActionInput,
): Promise<ItemLifecycleRecord> {
  const snoozedUntil = input.state === "snoozed" ? (input.snoozedUntil ?? null) : null;

  await db.queryObject(
    `INSERT INTO dashboard_item_state (
       organization_id, school_id, user_id, item_key, item_type,
       state, snoozed_until, score_at_action, due_at_action,
       acted_at, actor_id
     ) VALUES ($1,$2,$3,$4,$5,$6,$7::timestamptz,$8,$9, timezone('utc', now()), $3)
     ON CONFLICT (organization_id, school_id, user_id, item_key) DO UPDATE SET
       item_type       = COALESCE(EXCLUDED.item_type, dashboard_item_state.item_type),
       state           = EXCLUDED.state,
       snoozed_until   = EXCLUDED.snoozed_until,
       score_at_action = EXCLUDED.score_at_action,
       due_at_action   = EXCLUDED.due_at_action,
       acted_at        = timezone('utc', now()),
       actor_id        = EXCLUDED.actor_id`,
    [
      scope.organizationId,
      scope.schoolId,
      scope.userId,
      input.itemKey,
      input.itemType ?? null,
      input.state,
      snoozedUntil,
      input.scoreAtAction ?? null,
      input.dueAtAction ?? null,
    ],
  );

  return {
    itemKey: input.itemKey,
    state: input.state,
    snoozedUntil,
    scoreAtAction: input.scoreAtAction ?? null,
    dueAtAction: input.dueAtAction ?? null,
    actedAt: new Date().toISOString(),
  };
}
