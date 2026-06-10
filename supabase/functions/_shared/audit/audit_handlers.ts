import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import {
  type ClientAuditEventInput,
  correlationIdFromRequest,
  ingestClientAuditBatch,
} from "./audit_repository.ts";

interface BatchUploadBody {
  events?: ClientAuditEventInput[];
}

export async function handleAuditBatchUpload(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const body = await readJson<BatchUploadBody>(req);
  if (!body?.events || !Array.isArray(body.events) || body.events.length === 0) {
    return errorEnvelope("VALIDATION_ERROR", "events array is required", 422);
  }

  if (body.events.length > 100) {
    return errorEnvelope("VALIDATION_ERROR", "Maximum 100 events per batch", 422);
  }

  organizationIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) =>
      await ingestClientAuditBatch(db, auth.claims, body.events!, req)
    );

    return jsonResponse(
      envelope({
        acceptedCount: result.acceptedCount,
        rejectedIds: result.rejectedIds,
      }),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("audit batch upload error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to ingest audit batch", 500);
  }
}

export { correlationIdFromRequest };
