// W4 — Transport assignment history read endpoints (Owner decision #5).
// Reconstruct a student's transport allocation as-of any past date, and list the
// full effective-dated timeline — for an allocation or for a student. Read-only;
// gated by the SAME viewTransport + school-scope check as every other transport
// read (transport_handlers.ts).

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import {
  TenantDbNotConfiguredError,
  type TenantQueryClient,
  withTenantContext,
} from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import {
  type AllocationHistoryRecord,
  getAllocationAsOf,
  getStudentAllocationAsOf,
  listAllocationTimeline,
  listStudentAllocationTimeline,
} from "./transport_allocation_history_repository.ts";

function requireTransportRead(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "viewTransport") ??
    requireSchoolOperationalScope(claims);
}

/** Extracts the `{id}` path segment at `index` (0-based over non-empty segments). */
function pathSegment(url: URL, index: number): string | undefined {
  const seg = url.pathname.split("/").filter((s) => s.length > 0)[index];
  return seg ? decodeURIComponent(seg) : undefined;
}

/** Shared read plumbing: auth + RBAC + tenant tx, then run `read`. */
async function runHistoryRead(
  req: Request,
  config: AppConfig,
  read: (
    db: TenantQueryClient,
    orgId: string,
    schoolId: string,
    url: URL,
  ) => Promise<unknown>,
  errorMessage: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireTransportRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const url = new URL(req.url);

  try {
    const payload = await withTenantContext(
      config,
      auth.claims,
      async (db) => await read(db, orgId, schoolId, url),
    );
    return jsonResponse(envelope(payload));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error(`${errorMessage}:`, error);
    return errorEnvelope("INTERNAL_ERROR", errorMessage, 500);
  }
}

/** Shape one history record for the API. */
function toWire(r: AllocationHistoryRecord): Record<string, unknown> {
  return {
    id: r.id,
    allocationId: r.allocationId,
    sisStudentId: r.sisStudentId,
    routeId: r.routeId,
    pickupStop: r.pickupStop,
    dropStop: r.dropStop,
    shift: r.shift,
    validFrom: r.validFrom,
    validTo: r.validTo,
    open: r.validTo === null,
    payload: r.payload,
  };
}

/**
 * GET /transport/allocations/{id}/history
 *   → full effective-dated timeline for the allocation (oldest period first).
 *   With ?asOf=<ISO date> → { asOf, allocation } = the period open on that date
 *   (null when the allocation had no active period then).
 */
export async function handleAllocationHistory(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runHistoryRead(
    req,
    config,
    async (db, orgId, schoolId, url) => {
      const allocationId = pathSegment(url, 2);
      if (!allocationId) {
        return { timeline: [] as unknown[] };
      }
      const asOf = url.searchParams.get("asOf") ?? url.searchParams.get("as_of");
      if (asOf) {
        const record = await getAllocationAsOf(db, orgId, schoolId, allocationId, asOf);
        return { asOf, allocation: record ? toWire(record) : null };
      }
      const timeline = await listAllocationTimeline(db, orgId, schoolId, allocationId);
      return { allocationId, timeline: timeline.map(toWire) };
    },
    "Failed to read allocation history",
  );
}

/**
 * GET /transport/students/{sisStudentId}/allocation-history
 *   → full transport-assignment timeline for the student (oldest first).
 *   With ?asOf=<ISO date> → { asOf, allocation } = which route/stop the student
 *   rode on that date (null when they rode nothing then).
 */
export async function handleStudentAllocationHistory(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runHistoryRead(
    req,
    config,
    async (db, orgId, schoolId, url) => {
      const sisStudentId = pathSegment(url, 2);
      if (!sisStudentId) {
        return { timeline: [] as unknown[] };
      }
      const asOf = url.searchParams.get("asOf") ?? url.searchParams.get("as_of");
      if (asOf) {
        const record = await getStudentAllocationAsOf(db, orgId, schoolId, sisStudentId, asOf);
        return { asOf, allocation: record ? toWire(record) : null };
      }
      const timeline = await listStudentAllocationTimeline(db, orgId, schoolId, sisStudentId);
      return { sisStudentId, timeline: timeline.map(toWire) };
    },
    "Failed to read student allocation history",
  );
}
