// PRC-A Batch 4 — Storage quota HTTP handler.
//
//   GET /storage/quota   the org's storage usage, plan limit, health (viewStorageQuota)
//
// There is deliberately NO mutation endpoint: usage is written internally by the
// upload/delete paths (recordStorageUsage) and the limit is set by the PLAN, not
// granted ad hoc — so this module adds no audited mutating route (nothing for
// QA-R-008 to classify).

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import { authenticateRequest, requirePermission } from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { resolveSubscription } from "../entitlements/entitlement_service.ts";
import { readStorageUsage, storageQuotaHealth } from "./storage_quota_repository.ts";
import { storageQuotaEnforcementEnabled } from "./storage_quota_enforcement.ts";

export async function handleGetStorageQuota(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewStorageQuota");
  if (denied) return denied;

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const sub = await resolveSubscription(
        db,
        auth.claims.tenant_id,
        auth.claims.school_id ?? null,
      );
      const { usedBytes } = await readStorageUsage(db, {
        organizationId: auth.claims.tenant_id,
        schoolId: auth.claims.school_id ?? null,
      });
      return { limitBytes: sub.limits.storageBytes, usedBytes, planName: sub.plan.name };
    });
    const { limitBytes, usedBytes, planName } = result;
    return jsonResponse(envelope({
      planName,
      usedBytes,
      limitBytes, // null = unlimited
      availableBytes: limitBytes == null ? null : Math.max(0, limitBytes - usedBytes),
      health: storageQuotaHealth(usedBytes, limitBytes),
      // Whether the cap is actually being enforced right now (the dark switch).
      // An admin must not read "0 of 5 GiB" as "you are protected" when the gate
      // is off — expose the truth.
      enforced: storageQuotaEnforcementEnabled(),
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", String(error), 500);
  }
}
