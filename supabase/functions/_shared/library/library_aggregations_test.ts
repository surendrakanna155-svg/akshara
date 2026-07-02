import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  activeLoansFor,
  computeDashboard,
  computeFines,
  computeReports,
  FINE_PER_DAY,
  listAllEntities,
  membersWithLiveLoans,
  outstandingFineForMember,
  overdueList,
  overdueOpenLoans,
} from "./library_aggregations.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";

/** Fixed "now" so "issued today" / "overdue" are deterministic. */
const NOW = new Date("2026-06-26T10:00:00.000Z");
const TODAY = "2026-06-26";

function isoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function daysFromNow(days: number): string {
  return isoDate(new Date(NOW.getTime() + days * 24 * 60 * 60 * 1000));
}

function book(over: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: crypto.randomUUID(),
    isbn: "111",
    title: "Book",
    author: "Author",
    category: "Fiction",
    totalCopies: 3,
    availableCopies: 3,
    shelf: "A-1",
    status: "available",
    ...over,
  };
}

function issue(over: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: crypto.randomUUID(),
    memberName: "Arjun",
    memberType: "student",
    bookTitle: "Book",
    isbn: "111",
    issuedDate: TODAY,
    dueDate: daysFromNow(14),
    status: "active",
    sisStudentId: null,
    ...over,
  };
}

function member(over: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: crypto.randomUUID(),
    name: "Arjun",
    memberType: "student",
    identifier: "ADM-1",
    classOrDepartment: "10-A",
    activeLoans: 99, // intentionally stale seed value
    status: "active",
    sisStudentId: "SIS-1",
    ...over,
  };
}

// --- Empty / fresh-school honesty -------------------------------------------

Deno.test("dashboard: fresh school => zeros and empty lists", () => {
  const result = computeDashboard([], [], [], NOW);
  const kpis = result.kpis as Array<Record<string, unknown>>;
  const byId = Object.fromEntries(kpis.map((k) => [k.id, k.value]));
  assertEquals(byId.books, "0");
  assertEquals(byId.members, "0");
  assertEquals(byId.issued_today, "0");
  assertEquals(byId.overdue, "0");
  assertEquals(result.recentIssues, []);
  assertEquals(result.overdueTitles, []);
  assertEquals(result.categoryDistribution, []);
  assertEquals(result.popularTitle, "");
  assertEquals(result.overdueSummary, { count: 0, totalFines: "₹0" });
});

Deno.test("fines: fresh school => empty list, zero pending", () => {
  const result = computeFines([], [], [], NOW);
  assertEquals(result.fines, []);
  assertEquals(result.totalPending, "₹0");
});

Deno.test("reports: fresh school => empty charts", () => {
  const result = computeReports([], NOW);
  assertEquals(result.overdueByClass, []);
  assertEquals(result.popularTitles, []);
  assertEquals(result.issueTrend, []);
  const catalog = result.catalog as Array<Record<string, unknown>>;
  assertEquals(catalog.length, 1);
});

// --- Real aggregates from live rows -----------------------------------------

Deno.test("dashboard: counts books, issued-today and overdue from live rows", () => {
  const books = [book({ totalCopies: 5, category: "Fiction" }), book({ totalCopies: 2, category: "Science" })];
  const issues = [
    issue({ issuedDate: TODAY, dueDate: daysFromNow(14), bookTitle: "Alpha" }), // active, today, not overdue
    issue({ issuedDate: daysFromNow(-20), dueDate: daysFromNow(-3), bookTitle: "Beta" }), // overdue 3d
    issue({ issuedDate: daysFromNow(-5), dueDate: daysFromNow(-1), bookTitle: "Beta", status: "returned" }), // returned -> not open
  ];
  const members = [member(), member({ name: "Priya" })];

  const result = computeDashboard(books, issues, members, NOW);
  const byId = Object.fromEntries(
    (result.kpis as Array<Record<string, unknown>>).map((k) => [k.id, k.value]),
  );
  assertEquals(byId.books, "7"); // 5 + 2
  assertEquals(byId.members, "2");
  assertEquals(byId.issued_today, "1"); // only the one issued today
  assertEquals(byId.overdue, "1"); // only Beta active+overdue

  const summary = result.overdueSummary as Record<string, unknown>;
  assertEquals(summary.count, 1);
  assertEquals(summary.totalFines, `₹${3 * FINE_PER_DAY}`);
  assertEquals(result.overdueTitles, ["Beta"]);
  assertEquals(result.popularTitle, "Beta"); // issued twice
});

Deno.test("fines: lists overdue open loans with computed amount and finance link", () => {
  const issues = [
    issue({ memberName: "Arjun", bookTitle: "Beta", dueDate: daysFromNow(-2) }), // 2d overdue
    issue({ memberName: "Priya", bookTitle: "Gamma", dueDate: daysFromNow(5) }), // not overdue
    issue({ memberName: "Arjun", bookTitle: "Old", dueDate: daysFromNow(-10), status: "returned" }), // returned
  ];
  const members = [member({ name: "Arjun", sisStudentId: "SIS-1" })];

  const result = computeFines(issues, members, [], NOW);
  const fines = result.fines as Array<Record<string, unknown>>;
  assertEquals(fines.length, 1);
  assertEquals(fines[0].memberName, "Arjun");
  assertEquals(fines[0].bookTitle, "Beta");
  assertEquals(fines[0].amount, `₹${2 * FINE_PER_DAY}`);
  assertEquals(fines[0].daysOverdue, 2);
  assertEquals(fines[0].status, "pending");
  assertEquals(fines[0].financeLinked, true);
  assertEquals(fines[0].sisStudentId, "SIS-1");
  assertEquals(result.totalPending, `₹${2 * FINE_PER_DAY}`);
});

Deno.test("reports: overdueByClass and popularTitles from live rows", () => {
  const issues = [
    issue({ memberType: "student", bookTitle: "Beta", dueDate: daysFromNow(-1) }), // overdue
    issue({ memberType: "teacher", bookTitle: "Beta", dueDate: daysFromNow(-1) }), // overdue
    issue({ memberType: "student", bookTitle: "Gamma", dueDate: daysFromNow(5) }), // not overdue
  ];
  const result = computeReports(issues, NOW);
  const overdueByClass = result.overdueByClass as Array<Record<string, unknown>>;
  // 2 overdue: 1 student, 1 teacher
  const byLabel = Object.fromEntries(overdueByClass.map((s) => [s.label, s.value]));
  assertEquals(byLabel.student, 1);
  assertEquals(byLabel.teacher, 1);

  const popular = result.popularTitles as Array<Record<string, unknown>>;
  assertEquals(popular[0].label, "Beta"); // issued twice
  assertEquals(popular[0].value, 2);
});

// --- activeLoans derivation -------------------------------------------------

Deno.test("activeLoans: reflects open loans, ignores returned, per member", () => {
  const issues = [
    issue({ memberName: "Arjun", status: "active" }),
    issue({ memberName: "Arjun", status: "active" }),
    issue({ memberName: "Arjun", status: "returned" }),
    issue({ memberName: "Priya", status: "active" }),
  ];
  assertEquals(activeLoansFor("Arjun", issues), 2);
  assertEquals(activeLoansFor("Priya", issues), 1);
  assertEquals(activeLoansFor("Nobody", issues), 0);
});

Deno.test("membersWithLiveLoans: overlays real count, drops after a return", () => {
  const arjun = member({ name: "Arjun", activeLoans: 99 });
  const members = [arjun];

  // No loans yet => 0 (seed counter ignored)
  assertEquals(
    (membersWithLiveLoans(members, []) as Array<Record<string, unknown>>)[0].activeLoans,
    0,
  );

  // After issuing 1 book => 1
  const afterIssue = [issue({ memberName: "Arjun", status: "active" })];
  assertEquals(
    (membersWithLiveLoans(members, afterIssue) as Array<Record<string, unknown>>)[0].activeLoans,
    1,
  );

  // After return => back to 0
  const afterReturn = [issue({ memberName: "Arjun", status: "returned" })];
  assertEquals(
    (membersWithLiveLoans(members, afterReturn) as Array<Record<string, unknown>>)[0].activeLoans,
    0,
  );
});

// --- listAllEntities (tenant-scoped, un-paginated) --------------------------

class MockDb {
  rows: Array<{ entity_type: string; payload: Record<string, unknown> }> = [
    { entity_type: "issue", payload: { id: "i1", memberName: "Arjun" } },
    { entity_type: "issue", payload: { id: "i2", memberName: "Priya" } },
    { entity_type: "catalog", payload: { id: "b1", title: "Book" } },
  ];

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    const entityType = args[2] as string;
    if (sql.includes("ORDER BY id")) {
      return this.rows
        .filter((r) => r.entity_type === entityType)
        .map((r) => ({ payload: r.payload })) as T[];
    }
    return [] as T[];
  }
}

Deno.test("listAllEntities: returns every payload of a type (no pagination cap)", async () => {
  const db = new MockDb() as unknown as TenantQueryClient;
  const issues = await listAllEntities(db, ORG, SCHOOL, "issue");
  assertEquals(issues.length, 2);
  assertEquals(issues.map((i) => i.id).sort(), ["i1", "i2"]);

  const catalog = await listAllEntities(db, ORG, SCHOOL, "catalog");
  assertEquals(catalog.length, 1);
});

// --- LIB-1 overdue list + LIB-D1 outstanding-fine helper ---------------------

Deno.test("overdueList: only open overdue loans, each with accrued fine", () => {
  const issues = [
    issue({ memberName: "Arjun", bookTitle: "Beta", isbn: "111", dueDate: daysFromNow(-3) }), // overdue 3d
    issue({ memberName: "Priya", bookTitle: "Gamma", dueDate: daysFromNow(5) }), // not overdue
    issue({ memberName: "Arjun", bookTitle: "Old", dueDate: daysFromNow(-10), status: "returned" }), // returned
  ];
  const list = overdueList(issues, NOW);
  assertEquals(list.length, 1);
  assertEquals(list[0].memberName, "Arjun");
  assertEquals(list[0].bookTitle, "Beta");
  assertEquals(list[0].isbn, "111");
  assertEquals(list[0].daysOverdue, 3);
  assertEquals(list[0].fineAmount, `₹${3 * FINE_PER_DAY}`);
});

Deno.test("overdueList / overdueOpenLoans: fresh school => empty", () => {
  assertEquals(overdueList([], NOW), []);
  assertEquals(overdueOpenLoans([], NOW).length, 0);
});

Deno.test("overdueOpenLoans: returns issue + daysOverdue for open overdue loans only", () => {
  const issues = [
    issue({ dueDate: daysFromNow(-2) }), // overdue
    issue({ dueDate: daysFromNow(-2), status: "returned" }), // returned -> excluded
    issue({ dueDate: daysFromNow(1) }), // not overdue
  ];
  const open = overdueOpenLoans(issues, NOW);
  assertEquals(open.length, 1);
  assertEquals(open[0].daysOverdue, 2);
});

Deno.test("outstandingFineForMember: sums persisted outstanding + live overdue, excludes waived", () => {
  const issues = [
    issue({ memberName: "Arjun", dueDate: daysFromNow(-4) }), // live overdue 4d = ₹20
    issue({ memberName: "Arjun", dueDate: daysFromNow(-1), status: "returned" }), // returned -> no live fine
    issue({ memberName: "Priya", dueDate: daysFromNow(-10) }), // other member
  ];
  const fines = [
    { memberName: "Arjun", amount: 30, status: "outstanding" },
    { memberName: "Arjun", amount: 100, status: "waived" }, // excluded
    { memberName: "Priya", amount: 50, status: "outstanding" }, // other member
  ];
  // Arjun: 30 (persisted outstanding) + 4*FINE_PER_DAY (live) = 30 + 20 = 50.
  assertEquals(outstandingFineForMember("Arjun", issues, fines, NOW), 30 + 4 * FINE_PER_DAY);
  // A member with no fines => 0.
  assertEquals(outstandingFineForMember("Nobody", issues, fines, NOW), 0);
});
