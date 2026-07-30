// PRC-A Batch 4 — Storage quota enforcement (caps 31–36).
//
// Ships DARK: only ACTS when STORAGE_QUOTA_ENFORCEMENT=true. Without this, the
// deploy that ships storage limits would start rejecting uploads for any plan
// that has a max_storage_bytes set the instant the edge restarts — before anyone
// intends it. Mirrors entitlement_enforcement.ts / ai_wallet_enforcement.ts (same
// hazard, same shape), so there is one recognisable "shipped but not yet acting"
// pattern. Read from the env each call so flipping it needs only an edge restart.
//
// Enforcement is SOFT check-then-act, identical in shape to
// entitlement_limits.enforceStudentLimit: read current usage, allow if usage +
// this file stays within limit + grace, else 402. Storage is a soft resource —
// a small transient over-quota under concurrency is acceptable (the next upload
// is blocked); it does NOT need the wallet's atomic admit. A limit-check FAILURE
// fails OPEN (never breaks an upload), again matching the slab limits.

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { resolveSubscription } from "../entitlements/entitlement_service.ts";
import { readStorageUsage, withinStorageQuota } from "./storage_quota_repository.ts";

export function storageQuotaEnforcementEnabled(): boolean {
  try {
    return (Deno.env.get("STORAGE_QUOTA_ENFORCEMENT") ?? "").toLowerCase() === "true";
  } catch {
    // Env unreadable → OFF. Like the wallet's flag, an unreadable master switch
    // must not take every tenant's uploads offline; only a resolvable OVER-quota
    // blocks, and that path fails open too.
    return false;
  }
}

/**
 * 402 PLAN_LIMIT_EXCEEDED when storing `addBytes` more would push the org past
 * its plan storage cap (+ grace). Null when: enforcement off · plan unlimited ·
 * within quota · or any error (fail-open). Never throws.
 *
 * `addBytes` is the client-declared size at presign time — the same value
 * validateUpload already trusts for the per-file cap.
 */
export async function enforceStorageQuota(
  config: AppConfig,
  claims: AccessTokenClaims,
  addBytes: number,
): Promise<Response | null> {
  if (!storageQuotaEnforcementEnabled()) return null;
  try {
    return await withTenantContext(config, claims, async (db) => {
      const sub = await resolveSubscription(db, claims.tenant_id, claims.school_id ?? null);
      const limit = sub.limits.storageBytes;
      if (limit == null) return null; // unlimited plan
      const { usedBytes } = await readStorageUsage(db, {
        organizationId: claims.tenant_id,
        schoolId: claims.school_id ?? null,
      });
      if (withinStorageQuota(usedBytes, addBytes, limit, sub.limits.graceBufferPercent)) {
        return null;
      }
      return errorEnvelope(
        "PLAN_LIMIT_EXCEEDED",
        `Your ${sub.plan.name} plan storage limit of ${
          Math.floor(limit / 1048576)
        } MiB is reached. Delete files or upgrade to add more.`,
        402,
      );
    });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return null;
    // Fail-open: a quota-check failure must never break an upload (matches the
    // student/school slab limits). Logged so an operator can see it.
    console.error("Storage quota check failed:", error);
    return null;
  }
}
