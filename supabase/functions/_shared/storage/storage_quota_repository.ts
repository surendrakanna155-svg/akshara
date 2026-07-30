// PRC-A Batch 4 — Storage quota: usage projection + append recorder + health.
//
// Mirrors the live-certified AI-credit-wallet (ai_wallet_repository.ts): usage is
// a PROJECTION over an append-only signed ledger (storage_usage_entries), never a
// mutable counter. An upload appends +bytes; a delete appends -bytes; usage is
// their sum. BIGINT integers throughout — no float drift over millions of files.
//
// Unlike the wallet, enforcement is SOFT (check-then-act, see
// storage_quota_enforcement.ts) rather than an atomic admit: bytes are a soft
// resource where a small transient over-quota is acceptable, exactly as the
// existing student/school slab limits (entitlement_limits.ts) already accept.

import type { TenantQueryClient } from "../tenant_db.ts";

export interface StorageQuotaScope {
  organizationId: string;
  /** Retained on each row for a future per-school breakdown; the quota sums org-wide. */
  schoolId: string | null;
}

/**
 * Org storage usage in bytes = SUM(storage_usage_entries.delta_bytes).
 *
 * MAY be reported as any non-negative value; in practice it never goes negative
 * because a delete only ever frees bytes that an upload previously recorded. It
 * is returned honestly (not clamped) so a reconciliation bug would be visible
 * rather than silently hidden.
 */
export async function readStorageUsage(
  db: TenantQueryClient,
  scope: StorageQuotaScope,
): Promise<{ usedBytes: number }> {
  const rows = await db.queryObject<{ used: string | number }>(
    `SELECT coalesce(sum(delta_bytes), 0) AS used
       FROM storage_usage_entries
      WHERE organization_id = $1`,
    [scope.organizationId],
  );
  return { usedBytes: toBytes(rows[0]?.used) };
}

export interface RecordStorageInput {
  /** Positive when bytes are stored, negative when freed. Never zero. */
  deltaBytes: number;
  category: string;
  objectKey: string;
  actorId: string | null;
}

/**
 * Appends one signed usage row. No UPDATE path by design (the table grants
 * erp_tenant SELECT+INSERT only) — a correction is a compensating row.
 *
 * A zero delta is dropped (nothing stored/freed → nothing to record); the DB
 * CHECK `storage_usage_entries_delta_nonzero` is the hard guarantee behind this.
 * Returns null for a no-op so callers can treat it as "nothing to do".
 */
export async function recordStorageUsage(
  db: TenantQueryClient,
  scope: StorageQuotaScope,
  input: RecordStorageInput,
): Promise<{ id: string } | null> {
  const delta = Math.trunc(input.deltaBytes);
  if (!Number.isFinite(delta) || delta === 0) return null;
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO storage_usage_entries
       (organization_id, school_id, delta_bytes, category, object_key, actor_id)
     VALUES ($1, $2::uuid, $3::bigint, $4, $5, $6::uuid)
     RETURNING id`,
    [
      scope.organizationId,
      scope.schoolId,
      delta,
      input.category ?? "",
      input.objectKey ?? "",
      input.actorId,
    ],
  );
  return rows[0] ? { id: rows[0].id } : null;
}

/**
 * Pure: would storing `addBytes` more keep the org within `limitBytes` plus the
 * grace buffer? `limitBytes == null` means unlimited. Mirrors
 * entitlement_limits.withinSlab, generalised from +1 to +addBytes.
 */
export function withinStorageQuota(
  usedBytes: number,
  addBytes: number,
  limitBytes: number | null,
  graceBufferPercent: number,
): boolean {
  if (limitBytes == null) return true;
  const ceiling = Math.floor(limitBytes * (1 + (graceBufferPercent || 0) / 100));
  return usedBytes + Math.max(0, Math.trunc(addBytes)) <= ceiling;
}

export type StorageQuotaHealth = "unlimited" | "healthy" | "low" | "full";

/**
 * Health verdict for the panel + any future alert. A RATIO of the plan limit —
 * "you have used 92% of your plan's storage" is the statement an admin can act
 * on. Unlimited plans are always "unlimited" (never "low"), so an org on an
 * uncapped plan is never nagged.
 */
export const STORAGE_LOW_REMAINING_RATIO = 0.1;

export function storageQuotaHealth(
  usedBytes: number,
  limitBytes: number | null,
): StorageQuotaHealth {
  if (limitBytes == null) return "unlimited";
  if (limitBytes <= 0) return "full";
  if (usedBytes >= limitBytes) return "full";
  const remaining = limitBytes - usedBytes;
  return remaining <= Math.ceil(limitBytes * STORAGE_LOW_REMAINING_RATIO)
    ? "low"
    : "healthy";
}

function toBytes(v: string | number | undefined): number {
  if (v == null) return 0;
  const n = typeof v === "number" ? v : Number.parseInt(String(v), 10);
  return Number.isFinite(n) ? Math.trunc(n) : 0;
}
