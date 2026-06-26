import type { TenantQueryClient } from "../tenant_db.ts";

/**
 * Live aggregation for the Library module's derived/aggregate views.
 *
 * The dashboard KPIs, fines list and reports charts used to be served from
 * static `snapshot_*` seed rows that never reflected real data nor the
 * module's own issue/return writes (LIBRA-6 / MJ-M4). These helpers recompute
 * those views — and the per-member `activeLoans` count — directly from the
 * live entity rows (books / issues / members) inside the tenant RLS context,
 * so a fresh school with no loans honestly shows zeros / empty lists.
 *
 * Field names mirror exactly what the Flutter `LibraryMapper` reads
 * (lib/core/repositories/api/library/mapper/library_mapper.dart); changing
 * them would break the client DTOs.
 */

const LIBRARY_TABLE = "library_entities";

/** Per-day overdue fine, in rupees — mirrors library_write_handlers FINE_PER_DAY. */
export const FINE_PER_DAY = 5;

type Row = Record<string, unknown>;

function asInt(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === "string") {
    const parsed = parseInt(value, 10);
    if (!Number.isNaN(parsed)) return parsed;
  }
  return fallback;
}

function asStr(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value : fallback;
}

function isoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function rupees(amount: number): string {
  return `₹${amount.toLocaleString("en-IN")}`;
}

/**
 * Read every entity row of a given type for the active tenant/school.
 *
 * Aggregations need the full population (counts, "issued today", overdue),
 * which the paginated list store (capped at 100/page) can't supply. RLS on
 * `library_entities` still scopes the result to the caller's school.
 */
export async function listAllEntities(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  entityType: string,
): Promise<Row[]> {
  const rows = await db.queryObject<{ payload: Row }>(
    `SELECT payload
       FROM ${LIBRARY_TABLE}
       WHERE organization_id = $1
         AND school_id = $2
         AND entity_type = $3
       ORDER BY id`,
    [organizationId, schoolId, entityType],
  );
  return rows.map((row) => row.payload);
}

/** Open (un-returned) loans, with computed overdue days against `today`. */
interface OpenLoan {
  issue: Row;
  daysOverdue: number;
}

function openLoans(issues: Row[], today: Date): OpenLoan[] {
  return issues
    .filter((issue) => asStr(issue.status, "active") !== "returned")
    .map((issue) => {
      const dueRaw = asStr(issue.dueDate);
      const due = dueRaw ? new Date(dueRaw) : today;
      const daysOverdue = Math.max(
        0,
        Math.floor((today.getTime() - due.getTime()) / (24 * 60 * 60 * 1000)),
      );
      return { issue, daysOverdue };
    });
}

/** Count of open loans attributed to a member (by member name). */
export function activeLoansFor(memberName: string, issues: Row[]): number {
  let count = 0;
  for (const issue of issues) {
    if (asStr(issue.status, "active") === "returned") continue;
    if (asStr(issue.memberName) === memberName) count += 1;
  }
  return count;
}

/**
 * Overlay a live `activeLoans` count onto each member payload so the Members
 * list / loan-count reflects reality instead of a never-incremented seed.
 */
export function membersWithLiveLoans(members: Row[], issues: Row[]): Row[] {
  return members.map((member) => ({
    ...member,
    activeLoans: activeLoansFor(asStr(member.name), issues),
  }));
}

/** Recompute the dashboard view from live books / issues rows. */
export function computeDashboard(
  books: Row[],
  issues: Row[],
  members: Row[],
  now: Date = new Date(),
): Row {
  const today = isoDate(now);
  const totalBooks = books.reduce((sum, book) => sum + asInt(book.totalCopies, 0), 0);
  const issuedToday = issues.filter((issue) => asStr(issue.issuedDate) === today).length;
  const open = openLoans(issues, now);
  const overdue = open.filter((loan) => loan.daysOverdue > 0);
  const totalFines = overdue.reduce((sum, loan) => sum + loan.daysOverdue * FINE_PER_DAY, 0);

  // Category distribution across the live catalogue.
  const byCategory = new Map<string, number>();
  for (const book of books) {
    const category = asStr(book.category, "General");
    byCategory.set(category, (byCategory.get(category) ?? 0) + asInt(book.totalCopies, 0));
  }
  const categoryDistribution = [...byCategory.entries()].map(([label, value]) => ({
    label,
    value,
    percent: totalBooks > 0 ? Math.round((value / totalBooks) * 1000) / 10 : 0,
  }));

  // Most-issued title across all (open + returned) loans.
  const byTitle = new Map<string, number>();
  for (const issue of issues) {
    const title = asStr(issue.bookTitle);
    if (!title) continue;
    byTitle.set(title, (byTitle.get(title) ?? 0) + 1);
  }
  let popularTitle = "";
  let popularCount = 0;
  for (const [title, count] of byTitle.entries()) {
    if (count > popularCount) {
      popularTitle = title;
      popularCount = count;
    }
  }

  // Most-recent issues (newest issuedDate first), capped to a small list.
  const recentIssues = [...issues]
    .sort((a, b) => asStr(b.issuedDate).localeCompare(asStr(a.issuedDate)))
    .slice(0, 5);

  const overdueTitles = [
    ...new Set(overdue.map((loan) => asStr(loan.issue.bookTitle)).filter((t) => t.length > 0)),
  ];

  const aiInsight = open.length === 0
    ? "No active loans yet. Issue books to start tracking circulation."
    : overdue.length > 0
    ? `${overdue.length} overdue item${overdue.length === 1 ? "" : "s"} need follow-up.`
    : `${open.length} active loan${open.length === 1 ? "" : "s"}, none overdue.`;

  return {
    aiInsight,
    kpis: [
      { id: "books", value: totalBooks.toLocaleString("en-IN"), label: "Total Books", accentName: "primary" },
      { id: "members", value: members.length.toLocaleString("en-IN"), label: "Members", accentName: "info" },
      { id: "issued_today", value: String(issuedToday), label: "Issued Today", accentName: "success" },
      { id: "overdue", value: String(overdue.length), label: "Overdue", accentName: "warning" },
    ],
    recentIssues,
    overdueTitles,
    issueTrend: [],
    categoryDistribution,
    popularTitle,
    overdueSummary: { count: overdue.length, totalFines: rupees(totalFines) },
  };
}

/** Recompute the fines view from live overdue (open) loans. */
export function computeFines(
  issues: Row[],
  members: Row[],
  now: Date = new Date(),
): Row {
  const overdue = openLoans(issues, now).filter((loan) => loan.daysOverdue > 0);

  // Map member name -> sisStudentId for finance linkage on each fine.
  const sisByMember = new Map<string, string | null>();
  for (const member of members) {
    sisByMember.set(asStr(member.name), (member.sisStudentId as string | null) ?? null);
  }

  let totalPending = 0;
  const fines = overdue.map((loan) => {
    const amount = loan.daysOverdue * FINE_PER_DAY;
    totalPending += amount;
    const memberName = asStr(loan.issue.memberName);
    const sisStudentId = sisByMember.get(memberName) ??
      ((loan.issue.sisStudentId as string | null) ?? null);
    return {
      id: asStr(loan.issue.id),
      memberName,
      bookTitle: asStr(loan.issue.bookTitle),
      amount: rupees(amount),
      daysOverdue: loan.daysOverdue,
      status: "pending",
      financeLinked: sisStudentId != null,
      sisStudentId,
    };
  });

  return {
    fines,
    financeIntegrationNote:
      "Library fines sync to Finance FN-02 fee head library_fine. Paid fines post to FN-05 collections.",
    financeRoute: "/finance/fee-structures",
    totalPending: rupees(totalPending),
  };
}

/** Recompute the reports view (charts) from live issues rows. */
export function computeReports(
  issues: Row[],
  now: Date = new Date(),
): Row {
  const overdue = openLoans(issues, now).filter((loan) => loan.daysOverdue > 0);

  // Overdue grouped by the borrower's member type (student / staff / teacher).
  const overdueByType = new Map<string, number>();
  for (const loan of overdue) {
    const type = asStr(loan.issue.memberType, "student");
    overdueByType.set(type, (overdueByType.get(type) ?? 0) + 1);
  }
  const overdueTotal = overdue.length;
  const overdueByClass = [...overdueByType.entries()].map(([label, value]) => ({
    label,
    value,
    percent: overdueTotal > 0 ? Math.round((value / overdueTotal) * 1000) / 10 : 0,
  }));

  // Popular titles by issue count across all loans.
  const byTitle = new Map<string, number>();
  for (const issue of issues) {
    const title = asStr(issue.bookTitle);
    if (!title) continue;
    byTitle.set(title, (byTitle.get(title) ?? 0) + 1);
  }
  const totalIssues = issues.length;
  const popularTitles = [...byTitle.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([label, value]) => ({
      label,
      value,
      percent: totalIssues > 0 ? Math.round((value / totalIssues) * 1000) / 10 : 0,
    }));

  const lastGenerated = isoDate(now);
  return {
    catalog: [
      {
        id: "rpt_circ",
        title: "Circulation Report",
        description: "Monthly issue/return stats",
        lastGenerated,
      },
    ],
    issueTrend: [],
    overdueByClass,
    popularTitles,
  };
}
