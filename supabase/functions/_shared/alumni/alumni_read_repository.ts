import { createEntityReadStore } from "../entity_read/entity_read_store.ts";

export const ALUMNI_RECORD_SCHOOL_A = "bf300000-0000-4000-8000-000000000001";
export const ALUMNI_RECORD_SCHOOL_B = "bf300000-0000-4000-8000-000000000002";

export const alumniStore = createEntityReadStore("alumni_entities", "Alumni");

export const getSnapshot = alumniStore.getSnapshot;
export const listEntities = alumniStore.listEntities;
export const getEntity = alumniStore.getEntity;
export const AlumniSnapshotNotFoundError = alumniStore.SnapshotNotFoundError;
export const AlumniEntityNotFoundError = alumniStore.EntityNotFoundError;

export const ALUMNI_ENTITIES_PROBE_SQL = alumniStore.entitiesProbeSql;
export const ALUMNI_REGISTRY_API_PROBE_SQL = alumniStore.listApiProbeSql("alumni");
export const ALUMNI_REGISTRY_DETAIL_PROBE_SQL = alumniStore.detailProbeSql("alumni");

const LAKH = 100_000; // 1 L = 1e5

/** Parse a stored rupee string like "₹12.4L", "₹25,000", "₹2.1L" or "1500" to a number of rupees. */
export function parseRupees(raw: unknown): number {
  if (typeof raw === "number") return Number.isFinite(raw) ? raw : 0;
  if (typeof raw !== "string") return 0;
  const text = raw.trim();
  if (text === "" || text === "—") return 0;
  // Lakh-suffixed shorthand (e.g. "₹12.4L").
  const lakhMatch = text.match(/^₹?\s*([\d.,]+)\s*L$/i);
  if (lakhMatch) {
    const value = Number(lakhMatch[1]!.replace(/,/g, ""));
    return Number.isFinite(value) ? value * LAKH : 0;
  }
  const cleaned = text.replace(/[₹,\s]/g, "");
  const value = Number(cleaned);
  return Number.isFinite(value) ? value : 0;
}

/** Format a number of rupees back to the display convention used by the UI. */
export function formatRupees(amount: number): string {
  if (amount >= LAKH) {
    const lakhs = Math.round((amount / LAKH) * 10) / 10;
    return `₹${lakhs}L`;
  }
  return `₹${Math.round(amount).toLocaleString("en-IN")}`;
}

function str(value: unknown): string {
  return typeof value === "string" ? value : value == null ? "" : String(value);
}

/**
 * Honest profile detail. The alumnus entity stores only flat fields
 * (no employment/event sub-records are persisted), so employment history and
 * events attended are surfaced from real fields when present, otherwise empty.
 * Donation history is computed from real 'donation' entity rows for this alumnus.
 */
export function alumniDetailToApi(
  alumni: Record<string, unknown>,
  donations: Array<Record<string, unknown>> = [],
): Record<string, unknown> {
  const alumniId = str(alumni.id);

  const employmentHistory = Array.isArray(alumni.employmentHistory)
    ? (alumni.employmentHistory as Array<Record<string, unknown>>).map((entry) => ({
      organization: str(entry.organization),
      role: str(entry.role),
      period: str(entry.period),
    }))
    : [];

  const eventsAttended = Array.isArray(alumni.eventsAttended)
    ? (alumni.eventsAttended as unknown[]).map((e) => str(e)).filter((e) => e !== "")
    : [];

  const donationHistory = donations
    .filter((d) => str(d.alumniId) === alumniId)
    .map((d) => ({
      id: str(d.id),
      date: str(d.date),
      amount: str(d.amount),
      campaign: str(d.campaign),
      status: str(d.status) || "received",
      financeReceiptId: str(d.financeReceiptId),
    }));

  return {
    alumni,
    employmentHistory,
    donationHistory,
    mentorshipRole: alumni.engagementStatus === "active" ? "Mentor available" : "Not enrolled",
    eventsAttended,
  };
}

export interface AlumniLiveRows {
  alumni: Array<Record<string, unknown>>;
  events: Array<Record<string, unknown>>;
  campaigns: Array<Record<string, unknown>>;
  donations: Array<Record<string, unknown>>;
  mentorship: Array<Record<string, unknown>>;
}

const RECENT_GRADUATE_LIMIT = 5;
const UPCOMING_EVENT_LIMIT = 5;

function batchYearNum(row: Record<string, unknown>): number {
  const n = parseInt(str(row.batchYear), 10);
  return Number.isFinite(n) ? n : 0;
}

/**
 * Compute the alumni dashboard snapshot from live entity rows instead of a
 * pre-seeded snapshot. A fresh school with no alumni sees 0 registered and ₹0.
 * Field names match the seeded snapshot contract consumed by the Flutter mapper.
 */
export function computeAlumniDashboard(rows: AlumniLiveRows): Record<string, unknown> {
  const { alumni, events, campaigns, donations, mentorship } = rows;

  const registered = alumni.length;
  const activeAlumni = alumni.filter((a) => str(a.engagementStatus) === "active").length;

  let received = 0;
  let pledged = 0;
  let pending = 0;
  for (const d of donations) {
    const amount = parseRupees(d.amount);
    switch (str(d.status)) {
      case "pledged":
        pledged += amount;
        break;
      case "pending":
        pending += amount;
        break;
      case "refunded":
        break;
      default: // "received" and any unknown settled state
        received += amount;
        break;
    }
  }

  const recentGraduates = [...alumni]
    .sort((a, b) => batchYearNum(b) - batchYearNum(a))
    .slice(0, RECENT_GRADUATE_LIMIT);

  const upcomingEvents = events
    .filter((e) => {
      const status = str(e.status);
      return status === "upcoming" || status === "ongoing";
    })
    .sort((a, b) => str(a.date).localeCompare(str(b.date)))
    .slice(0, UPCOMING_EVENT_LIMIT);

  const totalRegistrations = events.reduce(
    (sum, e) => sum + (typeof e.registrations === "number" ? e.registrations : 0),
    0,
  );
  const totalCapacity = events.reduce(
    (sum, e) => sum + (typeof e.capacity === "number" ? e.capacity : 0),
    0,
  );
  // P2 (gap-remediation): `registrations` has no write path yet (events are
  // created with registrations:0 and nothing increments it — no RSVP/check-in
  // flow exists). So whenever real events exist, totalRegistrations is always
  // 0 and this would silently read "0%" — indistinguishable from a genuine
  // zero-turnout event. Say so honestly instead of fabricating a rate.
  const eventAttendanceRate = totalCapacity === 0
    ? "0%"
    : totalRegistrations === 0
    ? "Not yet tracked"
    : `${Math.round((totalRegistrations / totalCapacity) * 100)}%`;

  const totalDonors = campaigns.reduce(
    (sum, c) => sum + (typeof c.donorCount === "number" ? c.donorCount : 0),
    0,
  );
  const campaignParticipation = registered > 0
    ? `${Math.round((totalDonors / registered) * 100)}%`
    : "0%";

  const aiInsight = registered === 0
    ? "No alumni registered yet. Add graduates to begin tracking engagement."
    : `${registered} alumni registered. ${upcomingEvents.length} upcoming event${
      upcomingEvents.length === 1 ? "" : "s"
    }.`;

  return {
    aiInsight,
    kpis: [
      {
        id: "registered",
        value: registered.toLocaleString("en-IN"),
        label: "Registered Alumni",
        accentName: "primary",
      },
    ],
    recentGraduates,
    upcomingEvents,
    donationSummary: {
      totalReceived: formatRupees(received),
      pledgedAmount: formatRupees(pledged),
      pendingAmount: formatRupees(pending),
    },
    engagement: {
      activeAlumni,
      eventAttendanceRate,
      mentorshipPairs: mentorship.length,
      campaignParticipation,
    },
  };
}

/** Group a month label "YYYY-MM" -> short label like "Jun 2026" from an ISO-ish date string. */
const MONTHS = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec",
];

function monthKey(dateStr: string): string | null {
  const match = dateStr.match(/^(\d{4})-(\d{2})/);
  if (!match) return null;
  return `${match[1]}-${match[2]}`;
}

function monthLabel(key: string): string {
  const [year, month] = key.split("-");
  const idx = parseInt(month!, 10) - 1;
  return `${MONTHS[idx] ?? month} ${year}`;
}

/**
 * Compute the alumni reports snapshot (donationTrend / engagementByBatch /
 * eventAttendanceTrend) from live rows. The static report catalog
 * (definitions of available exports) is preserved as-is since it describes
 * report templates, not seeded data.
 *
 * #5 (gap-remediation): the client mapper (`toReports` in alumni_mapper.dart)
 * reads `eventAttendanceTrend` (shape {label, amountLakhs, targetLakhs} — the
 * same generic AlumniTrendPoint contract donationTrend uses) and
 * `engagementByBatch` (shape {label, value, percent} — AlumniSegment). This
 * emits both real keys instead of the old `eventAttendance` key with a
 * {label, registrations, capacity} shape the client never read.
 */
export function computeAlumniReports(
  rows: Pick<AlumniLiveRows, "alumni" | "donations" | "events">,
  catalog: unknown[],
): Record<string, unknown> {
  const { alumni, donations, events } = rows;

  // Donation trend: total received rupees per month (in lakhs).
  const donationByMonth = new Map<string, number>();
  for (const d of donations) {
    if (str(d.status) === "refunded") continue;
    const key = monthKey(str(d.date));
    if (!key) continue;
    donationByMonth.set(key, (donationByMonth.get(key) ?? 0) + parseRupees(d.amount));
  }
  const donationTrend = [...donationByMonth.entries()]
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([key, amount]) => ({
      label: monthLabel(key),
      amountLakhs: Math.round((amount / LAKH) * 10) / 10,
    }));

  // Engagement by batch: distribution of currently-active (engaged) alumni
  // across graduation years — the only per-batch breakdown real fields
  // support (batchYear + engagementStatus), mirroring the count+share-of-total
  // shape used elsewhere (e.g. library's overdueByClass).
  const activeByBatch = new Map<string, number>();
  for (const a of alumni) {
    if (str(a.engagementStatus) !== "active") continue;
    const year = str(a.batchYear) || "Unknown";
    activeByBatch.set(year, (activeByBatch.get(year) ?? 0) + 1);
  }
  const totalActive = [...activeByBatch.values()].reduce((sum, n) => sum + n, 0);
  const engagementByBatch = [...activeByBatch.entries()]
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([label, value]) => ({
      label,
      value,
      percent: totalActive > 0 ? Math.round((value / totalActive) * 1000) / 10 : 0,
    }));

  // Event attendance rate trend: registrations/capacity as a percent per
  // event (most recent first), reshaped to the generic trend-point contract
  // (amountLakhs carries the percent value here, same as the mock fixture).
  const eventAttendanceTrend = [...events]
    .sort((a, b) => str(b.date).localeCompare(str(a.date)))
    .map((e) => {
      const registrations = typeof e.registrations === "number" ? e.registrations : 0;
      const capacity = typeof e.capacity === "number" ? e.capacity : 0;
      const rate = capacity > 0 ? Math.round((registrations / capacity) * 1000) / 10 : 0;
      return {
        label: str(e.title),
        amountLakhs: rate,
      };
    });

  return {
    catalog,
    donationTrend,
    engagementByBatch,
    eventAttendanceTrend,
  };
}
