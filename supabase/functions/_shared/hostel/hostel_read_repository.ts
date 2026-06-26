import { createEntityReadStore } from "../entity_read/entity_read_store.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

export const HOSTEL_STUDENT_SCHOOL_A = "bf000000-0000-4000-8000-000000000001";
export const HOSTEL_STUDENT_SCHOOL_B = "bf000000-0000-4000-8000-000000000002";

export const hostelStore = createEntityReadStore("hostel_entities", "Hostel");

/** Static fields shown on the Visitors screen when no seed snapshot is present. */
const DEFAULT_QR_PLACEHOLDER_LABEL = "QR visitor pass preview (120×120)";
const DEFAULT_PARENT_APP_ROUTE = "/parent/dashboard";

/** Visitor payloads in the active state are not yet checked out. */
function isActiveVisitor(payload: Record<string, unknown>): boolean {
  const status = (payload.status as string | undefined) ?? "";
  const checkOut = payload.checkOut;
  return status === "active" || checkOut === null || checkOut === undefined;
}

/** Newest-first ordering by ISO `checkIn` timestamp (string compare is safe for ISO). */
function byCheckInDesc(
  a: Record<string, unknown>,
  b: Record<string, unknown>,
): number {
  const ai = (a.checkIn as string | undefined) ?? "";
  const bi = (b.checkIn as string | undefined) ?? "";
  if (ai === bi) return 0;
  return ai < bi ? 1 : -1;
}

/**
 * Recomputes the Visitors screen payload from the live `visitor` list entities
 * instead of a frozen seeded snapshot (MJ-M1). A just-logged visitor (a
 * `visitor` entity inserted by `handleLogVisitor`) therefore appears on the
 * Visitors screen immediately.
 *
 * Returns the exact JSON shape the Flutter `HostelVisitorsData` mapper expects:
 * `{ activeVisitors, visitorLog, qrPlaceholderLabel, parentAppRoute }`.
 * - `activeVisitors`: visitors still checked in (status `active` / no checkOut),
 *   newest first.
 * - `visitorLog`: completed/past visits (checked-out or expired), newest first —
 *   mirroring the canonical mock semantics where active visitors are not also
 *   listed in the log.
 *
 * Static fields (`qrPlaceholderLabel`, `parentAppRoute`) are read from the seed
 * `snapshot_visitors` payload when present, falling back to sensible defaults so
 * a missing seed snapshot does not 500.
 */
export async function recomputeVisitors(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<Record<string, unknown>> {
  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `SELECT payload
       FROM hostel_entities
       WHERE organization_id = $1
         AND school_id = $2
         AND entity_type = $3
       ORDER BY id`,
    [organizationId, schoolId, "visitor"],
  );
  const visitors = rows
    .map((row) => row.payload)
    .sort(byCheckInDesc);

  const activeVisitors = visitors.filter(isActiveVisitor);
  const visitorLog = visitors.filter((payload) => !isActiveVisitor(payload));

  let qrPlaceholderLabel = DEFAULT_QR_PLACEHOLDER_LABEL;
  let parentAppRoute = DEFAULT_PARENT_APP_ROUTE;
  try {
    const snapshot = await hostelStore.getSnapshot(
      db,
      organizationId,
      schoolId,
      "snapshot_visitors",
    );
    if (typeof snapshot.qrPlaceholderLabel === "string") {
      qrPlaceholderLabel = snapshot.qrPlaceholderLabel;
    }
    if (typeof snapshot.parentAppRoute === "string") {
      parentAppRoute = snapshot.parentAppRoute;
    }
  } catch (_error) {
    // No seed snapshot for this tenant — defaults above are correct, do not 500.
  }

  return { activeVisitors, visitorLog, qrPlaceholderLabel, parentAppRoute };
}

export const getSnapshot = hostelStore.getSnapshot;
export const listEntities = hostelStore.listEntities;
export const getEntity = hostelStore.getEntity;
export const HostelSnapshotNotFoundError = hostelStore.SnapshotNotFoundError;
export const HostelEntityNotFoundError = hostelStore.EntityNotFoundError;

export const HOSTEL_ENTITIES_PROBE_SQL = hostelStore.entitiesProbeSql;
export const HOSTEL_STUDENTS_API_PROBE_SQL = hostelStore.listApiProbeSql("student");
export const HOSTEL_STUDENT_DETAIL_PROBE_SQL = hostelStore.detailProbeSql("student");
