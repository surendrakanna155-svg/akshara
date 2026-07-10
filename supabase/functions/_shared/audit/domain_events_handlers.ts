import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { publishPendingDomainEvents } from "./domain_events_worker.ts";
import { runSignalRefinery } from "../ai/signal_refinery.ts";

export async function handleProcessDomainEvents(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageCommunications");
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  try {
    const result = await withTenantContext(config, auth.claims, async (db) =>
      await publishPendingDomainEvents(db, orgId)
    );

    // Signal Refinery (W1.4): after the publish transaction commits, refine
    // each affected school in its OWN school-scoped transaction — the cache/
    // signal RLS requires school scope (the drain is org-scoped), and isolation
    // means one school's refinery error never fails the drain or another
    // school. Best-effort accelerator; the outbox publish is unaffected.
    for (const schoolId of result.schoolIds) {
      try {
        await withTenantContext(
          config,
          { ...auth.claims, scope: "school", school_id: schoolId },
          (db) => runSignalRefinery(db, { organizationId: orgId, schoolId }),
        );
      } catch {
        // swallow — cache freshness is best-effort; never fail the drain
      }
    }

    return jsonResponse(envelope({
      processed: result.processed,
      published: result.published,
      failed: result.failed,
      retried: result.retried,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to process domain events", 500);
  }
}
