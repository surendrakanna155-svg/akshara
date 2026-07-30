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

/** Default finance-integration note shown on the Mess screen when no seed snapshot is present. */
const DEFAULT_MESS_FINANCE_NOTE =
  "Mess expenses are tracked in the Hostel module and are NOT posted to the Finance ledger; " +
  "record them against the FN-05 expense head manually if needed";

/** Newest-first ordering by ISO `recordedAt` timestamp (string compare is safe for ISO). */
function byRecordedAtDesc(
  a: Record<string, unknown>,
  b: Record<string, unknown>,
): number {
  const ar = (a.recordedAt as string | undefined) ?? "";
  const br = (b.recordedAt as string | undefined) ?? "";
  if (ar === br) return 0;
  return ar < br ? 1 : -1;
}

/** Formats a rupee amount as the `₹N.NL` (lakhs) label the Mess screen expects. */
function rupeesToLakhLabel(rupees: number): string {
  const lakhs = rupees / 100000;
  return `₹${lakhs.toFixed(1)}L`;
}

/**
 * Recomputes the Mess screen payload from the live `mess_record` entities
 * (HOSTE-3) instead of only a frozen seeded snapshot. A just-recorded menu (a
 * `mess_record` entity inserted by `handleRecordMess`) therefore appears on the
 * Mess screen immediately, and the MTD cost reflects the recorded spend.
 *
 * Returns the exact JSON shape the Flutter `HostelMessData` mapper expects:
 * `{ weeklyMenus, consumptionTrend, costMtd, financeIntegrationNote }`.
 * - `weeklyMenus`: the recorded menus newest-first (mapped to {day, mealType,
 *   items, dietaryTags}).
 * - `consumptionTrend`: per-day total cost (lakhs) so the trend chart reflects
 *   real spend.
 * - `costMtd`: the summed cost of recorded meals, as a `₹N.NL` label.
 *
 * When no `mess_record` entities exist yet, falls back to the seed
 * `snapshot_mess` payload (preserving the previous behaviour) so the screen is
 * never empty for a freshly-seeded tenant, and a missing seed does not 500.
 */
export async function recomputeMess(
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
    [organizationId, schoolId, "mess_record"],
  );
  const records = rows.map((row) => row.payload);

  let seededFinanceNote = DEFAULT_MESS_FINANCE_NOTE;
  let seedSnapshot: Record<string, unknown> | null = null;
  try {
    seedSnapshot = await hostelStore.getSnapshot(
      db,
      organizationId,
      schoolId,
      "snapshot_mess",
    );
    if (typeof seedSnapshot.financeIntegrationNote === "string") {
      seededFinanceNote = seedSnapshot.financeIntegrationNote;
    }
  } catch (_error) {
    // No seed snapshot for this tenant — defaults below are correct, do not 500.
  }

  // No live records yet: return the seed snapshot verbatim when present so the
  // screen keeps its richer demo content; otherwise an honest empty payload.
  if (records.length === 0) {
    if (seedSnapshot) return seedSnapshot;
    return {
      weeklyMenus: [],
      consumptionTrend: [],
      costMtd: rupeesToLakhLabel(0),
      financeIntegrationNote: seededFinanceNote,
    };
  }

  const sorted = [...records].sort(byRecordedAtDesc);

  const weeklyMenus = sorted.map((record) => ({
    day: (record.day as string | undefined) ?? "",
    mealType: (record.mealType as string | undefined) ?? "breakfast",
    items: (record.items as string | undefined) ?? "",
    dietaryTags: Array.isArray(record.dietaryTags)
      ? (record.dietaryTags as unknown[]).map((tag) => String(tag))
      : [],
  }));

  // Per-day total cost (in lakhs), in the order days first appear (newest-first).
  const costByDay = new Map<string, number>();
  for (const record of sorted) {
    const day = (record.day as string | undefined) ?? "";
    const cost = typeof record.costRupees === "number"
      ? record.costRupees
      : parseInt(String(record.costRupees ?? 0), 10) || 0;
    costByDay.set(day, (costByDay.get(day) ?? 0) + cost);
  }
  const consumptionTrend = [...costByDay.entries()].map(([label, rupees]) => ({
    label,
    amountLakhs: Number((rupees / 100000).toFixed(2)),
    targetLakhs: Number((rupees / 100000).toFixed(2)),
  }));

  const totalRupees = sorted.reduce((sum, record) => {
    const cost = typeof record.costRupees === "number"
      ? record.costRupees
      : parseInt(String(record.costRupees ?? 0), 10) || 0;
    return sum + cost;
  }, 0);

  return {
    weeklyMenus,
    consumptionTrend,
    costMtd: rupeesToLakhLabel(totalRupees),
    financeIntegrationNote: seededFinanceNote,
  };
}

export const getSnapshot = hostelStore.getSnapshot;
export const listEntities = hostelStore.listEntities;
export const getEntity = hostelStore.getEntity;
export const HostelSnapshotNotFoundError = hostelStore.SnapshotNotFoundError;
export const HostelEntityNotFoundError = hostelStore.EntityNotFoundError;

export const HOSTEL_ENTITIES_PROBE_SQL = hostelStore.entitiesProbeSql;
export const HOSTEL_STUDENTS_API_PROBE_SQL = hostelStore.listApiProbeSql("student");
export const HOSTEL_STUDENT_DETAIL_PROBE_SQL = hostelStore.detailProbeSql("student");
