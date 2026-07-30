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

/**
 * The OPEN (un-returned) issue rows only, filtered in SQL and bounded — for
 * hot-path callers (the priority feed) that must not scan a school's entire
 * cumulative loan history the way `listAllEntities` does. Open loans at one
 * school are bounded by the physical book count; 2000 is far past any pilot
 * school. RLS still scopes to the caller's school.
 */
export async function listOpenIssueEntities(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<Row[]> {
  const rows = await db.queryObject<{ payload: Row }>(
    `SELECT payload
       FROM ${LIBRARY_TABLE}
       WHERE organization_id = $1
         AND school_id = $2
         AND entity_type = 'issue'
         AND COALESCE(payload->>'status', 'active') <> 'returned'
       ORDER BY id
       LIMIT 2000`,
    [organizationId, schoolId],
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
 * LIB-D1 — a member's total OUTSTANDING (un-waived) fine, in rupees. Sums both
 * halves of the fines view for that member: (a) persisted `fine` entities that
 * are still `outstanding` (raised on an overdue return, not yet waived), and
 * (b) the live accruing fine on still-open overdue loans. Mirrors the disjoint
 * split in {@link computeFines} so a fine is never double-counted. Used to
 * enforce the issue-block-on-fine-threshold guardrail.
 */
export function outstandingFineForMember(
  memberName: string,
  issues: Row[],
  fineEntities: Row[] = [],
  now: Date = new Date(),
): number {
  let total = 0;
  for (const fine of fineEntities) {
    if (asStr(fine.memberName) !== memberName) continue;
    if (asStr(fine.status, "outstanding") === "waived") continue;
    total += asInt(fine.amount, 0);
  }
  for (const loan of openLoans(issues, now)) {
    if (loan.daysOverdue <= 0) continue;
    if (asStr(loan.issue.memberName) !== memberName) continue;
    total += loan.daysOverdue * FINE_PER_DAY;
  }
  return total;
}

/**
 * LIB-1 — the open (un-returned) overdue loans as flat rows for the client
 * overdue list / export, each carrying the accrued fine so far. Only genuinely
 * overdue (daysOverdue > 0) loans are included.
 */
export function overdueList(issues: Row[], now: Date = new Date()): Row[] {
  return openLoans(issues, now)
    .filter((loan) => loan.daysOverdue > 0)
    .map((loan) => ({
      issueId: asStr(loan.issue.id),
      memberName: asStr(loan.issue.memberName),
      memberType: asStr(loan.issue.memberType, "student"),
      bookTitle: asStr(loan.issue.bookTitle),
      isbn: asStr(loan.issue.isbn),
      dueDate: asStr(loan.issue.dueDate),
      daysOverdue: loan.daysOverdue,
      fineAmount: rupees(loan.daysOverdue * FINE_PER_DAY),
      sisStudentId: (loan.issue.sisStudentId as string | null) ?? null,
    }));
}

/** LIB-5 — the open overdue loans as {@link OpenLoan} (issue + daysOverdue). */
export function overdueOpenLoans(issues: Row[], now: Date = new Date()): OpenLoan[] {
  return openLoans(issues, now).filter((loan) => loan.daysOverdue > 0);
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

/**
 * Map a persisted `fine` entity (written by handleReturnBook on an overdue
 * return) into the fines-view DTO the Flutter `LibraryMapper` reads. The
 * persisted status (`outstanding` / `waived`) maps to the client enum
 * (`pending` / `waived`); only `outstanding` fines count toward `totalPending`.
 */
function mapPersistedFine(fine: Row): Row {
  const status = asStr(fine.status, "outstanding");
  const sisStudentId = (fine.sisStudentId as string | null) ?? null;
  return {
    id: asStr(fine.id),
    memberName: asStr(fine.memberName),
    bookTitle: asStr(fine.bookTitle),
    amount: rupees(asInt(fine.amount, 0)),
    daysOverdue: asInt(fine.daysOverdue, 0),
    status: status === "waived" ? "waived" : "pending",
    financeLinked: sisStudentId != null,
    sisStudentId,
  };
}

/**
 * Recompute the fines view from BOTH the persisted `fine` entities (raised on
 * overdue returns, mutated by waive) AND the live overdue (open, un-returned)
 * loans. The two sets are disjoint — an open loan has no return-time fine row
 * yet — so a fine appears exactly once. Only `outstanding` (pending) amounts
 * count toward `totalPending`; waived fines are listed but excluded.
 */
export function computeFines(
  issues: Row[],
  members: Row[],
  fineEntities: Row[] = [],
  now: Date = new Date(),
): Row {
  const overdue = openLoans(issues, now).filter((loan) => loan.daysOverdue > 0);

  // Map member name -> sisStudentId for finance linkage on each fine.
  const sisByMember = new Map<string, string | null>();
  for (const member of members) {
    sisByMember.set(asStr(member.name), (member.sisStudentId as string | null) ?? null);
  }

  let totalPending = 0;

  // Persisted return-time fines (outstanding + waived).
  const persisted = fineEntities.map((fine) => {
    const mapped = mapPersistedFine(fine);
    if (mapped.status === "pending") {
      totalPending += asInt(fine.amount, 0);
    }
    return mapped;
  });

  // Live fines on still-open overdue loans (not yet returned).
  const live = overdue.map((loan) => {
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
    fines: [...persisted, ...live],
    // PRA-P1-40 (S0/T7): honest note — library fines do NOT sync to Finance.
    // There is no `library_fine` fee head or collection posting; a fine can only
    // be waived or left outstanding today. The previous copy told the librarian a
    // Finance sync existed. A real cash-collection/posting path is future work.
    financeIntegrationNote:
      "Library fines are tracked in the Library module and are NOT posted to the Finance ledger. " +
      "Where a fine is matched to a registered student, collect it manually via the FN-02 library_fine fee head.",
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
