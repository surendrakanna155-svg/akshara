import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { DailySummaryData } from "./finance_collections_repository.ts";
import {
  computeCollectionRate,
  getDashboard,
} from "./finance_dashboard_repository.ts";
import { dashboardToApi } from "./finance_mapper.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";

type Row = Record<string, unknown>;

class MockDashboardDb {
  studentAccounts = [
    { student_id: "stu-1", status: "open" },
    { student_id: "stu-2", status: "open" },
    { student_id: "stu-3", status: "closed" },
  ];
  assignments = [
    { assignment_status: "active" },
    { assignment_status: "active" },
    { assignment_status: "cancelled" },
  ];
  invoices = [
    { total_amount: "100000", invoice_status: "paid", outstanding_amount: "0" },
    { total_amount: "50000", invoice_status: "issued", outstanding_amount: "30000" },
    { total_amount: "20000", invoice_status: "cancelled", outstanding_amount: "0" },
  ];
  collections = [
    {
      id: "col-1",
      receipt_number: "RCP-001",
      student_id: "stu-1",
      amount_collected: "40000",
      payment_method: "cash",
      collection_date: "2026-06-09",
      collection_status: "completed",
      created_at: "2026-06-09T10:00:00.000Z",
    },
    {
      id: "col-2",
      receipt_number: "RCP-002",
      student_id: "stu-2",
      amount_collected: "20000",
      payment_method: "upi",
      collection_date: "2026-06-08",
      collection_status: "completed",
      created_at: "2026-06-08T10:00:00.000Z",
    },
    {
      id: "col-3",
      receipt_number: "RCP-003",
      student_id: "stu-1",
      amount_collected: "5000",
      payment_method: "cash",
      collection_date: "2026-06-09",
      collection_status: "draft",
      created_at: "2026-06-09T11:00:00.000Z",
    },
  ];
  refunds = [
    {
      id: "ref-1",
      refund_amount: "1000",
      refund_status: "pending",
      created_at: "2026-06-09T09:00:00.000Z",
      collection_id: "col-1",
    },
    {
      id: "ref-2",
      refund_amount: "500",
      refund_status: "processed",
      created_at: "2026-06-08T09:00:00.000Z",
      collection_id: "col-2",
    },
  ];
  dailySummary: DailySummaryData = {
    dateLabel: "2026-06-09",
    todayCollections: 40000,
    todayCollectionCount: 1,
    cashAmount: 40000,
    upiAmount: 0,
    draftCollectionsToday: 1,
    pendingInvoices: 1,
    paidInvoices: 1,
    partiallyPaidInvoices: 0,
    outstandingAmount: 30000,
  };

  async queryObject<T>(sql: string, _args: unknown[] = []): Promise<T[]> {
    if (sql.includes("total_invoiced") && sql.includes("total_collected")) {
      const open = this.studentAccounts.filter((a) => a.status === "open");
      const distinctStudents = new Set(open.map((a) => a.student_id)).size;
      const activeAssignments = this.assignments
        .filter((a) => a.assignment_status === "active").length;
      const totalInvoiced = this.invoices
        .filter((i) => i.invoice_status !== "cancelled")
        .reduce((sum, i) => sum + parseFloat(i.total_amount), 0);
      const totalCollected = this.collections
        .filter((c) => ["completed", "partially_refunded", "refunded"].includes(
          String(c.collection_status),
        ))
        .reduce((sum, c) => sum + parseFloat(String(c.amount_collected)), 0);
      const pendingRefunds = this.refunds.filter((r) => r.refund_status === "pending").length;
      const processedRefunds = this.refunds.filter((r) => r.refund_status === "processed").length;
      return [{
        total_students: String(distinctStudents),
        active_assignments: String(activeAssignments),
        total_invoiced: String(totalInvoiced),
        total_collected: String(totalCollected),
        pending_refunds: String(pendingRefunds),
        processed_refunds: String(processedRefunds),
      }] as T[];
    }
    if (sql.includes("FROM finance_collections fc") && sql.includes("LIMIT 10")) {
      const rows = this.collections
        .filter((c) => ["completed", "partially_refunded", "refunded"].includes(
          String(c.collection_status),
        ))
        .sort((a, b) => String(b.collection_date).localeCompare(String(a.collection_date)))
        .map((c) => ({
          id: c.id,
          receipt_number: c.receipt_number,
          student_name: "Probe Student",
          amount: c.amount_collected,
          payment_method: c.payment_method,
          collection_date: c.collection_date,
        }));
      return rows as T[];
    }
    if (sql.includes("FROM finance_refunds fr") && sql.includes("LIMIT 10")) {
      const rows = [...this.refunds]
        .sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)))
        .map((r) => ({
          id: r.id,
          student_name: "Probe Student",
          amount: r.refund_amount,
          status: r.refund_status,
          requested_at: r.created_at,
        }));
      return rows as T[];
    }
    if (sql.includes("collection_date = CURRENT_DATE")) {
      return [{
        total: String(this.dailySummary.todayCollections),
        count: String(this.dailySummary.todayCollectionCount),
        cash: String(this.dailySummary.cashAmount),
        upi: String(this.dailySummary.upiAmount),
        drafts: String(this.dailySummary.draftCollectionsToday),
      }] as T[];
    }
    if (sql.includes("FROM finance_invoices") && sql.includes("invoice_status NOT IN")) {
      return [{
        pending: String(this.dailySummary.pendingInvoices),
        paid: String(this.dailySummary.paidInvoices),
        partial: String(this.dailySummary.partiallyPaidInvoices),
        outstanding: String(this.dailySummary.outstandingAmount),
      }] as T[];
    }
    return [] as T[];
  }

  async queryCount(): Promise<number> {
    return 0;
  }
}

function schoolClaims(): AccessTokenClaims {
  return {
    sub: "staff",
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL_A,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: ["viewFinance"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "test",
  };
}

function orgClaims(): AccessTokenClaims {
  return {
    ...schoolClaims(),
    school_id: null,
    scope: "organization",
    role: "organizationAdmin",
    role_slugs: ["organizationAdmin"],
    primary_role: "organizationAdmin",
    permissions: ["viewFinance"],
  };
}

Deno.test("computeCollectionRate guards divide by zero", () => {
  assertEquals(computeCollectionRate(50000, 0), 0);
  assertEquals(computeCollectionRate(0, 100000), 0);
});

Deno.test("computeCollectionRate calculates percentage", () => {
  assertEquals(computeCollectionRate(60000, 150000), 40);
});

Deno.test("getDashboard aggregates KPIs", async () => {
  const db = new MockDashboardDb() as unknown as TenantQueryClient;
  const dashboard = await getDashboard(db, ORG, SCHOOL_A);

  assertEquals(dashboard.totalStudents, 2);
  assertEquals(dashboard.activeFeeAssignments, 2);
  assertEquals(dashboard.totalInvoiced, 150000);
  assertEquals(dashboard.totalCollected, 60000);
  assertEquals(dashboard.totalOutstanding, 30000);
  assertEquals(dashboard.collectionRate, 40);
  assertEquals(dashboard.pendingInvoices, 1);
  assertEquals(dashboard.paidInvoices, 1);
  assertEquals(dashboard.todayCollections, 40000);
  assertEquals(dashboard.todayCollectionCount, 1);
  assertEquals(dashboard.pendingRefunds, 1);
  assertEquals(dashboard.processedRefunds, 1);
});

Deno.test("getDashboard returns recent collections and refunds", async () => {
  const db = new MockDashboardDb() as unknown as TenantQueryClient;
  const dashboard = await getDashboard(db, ORG, SCHOOL_A);

  assertEquals(dashboard.recentCollections.length, 2);
  assertEquals(dashboard.recentCollections[0]?.receipt_number, "RCP-001");
  assertEquals(dashboard.recentRefunds.length, 2);
  assertEquals(dashboard.recentRefunds[0]?.status, "pending");
});

Deno.test("dashboardToApi serializes camelCase response", async () => {
  const db = new MockDashboardDb() as unknown as TenantQueryClient;
  const dashboard = await getDashboard(db, ORG, SCHOOL_A);
  const api = dashboardToApi(dashboard);

  assertEquals(api.totalStudents, 2);
  assertEquals(api.collectionRate, 40);
  assertEquals(Array.isArray(api.recentCollections), true);
  const recent = api.recentCollections as Record<string, unknown>[];
  assertEquals(recent[0]?.receiptNumber, "RCP-001");
  assertEquals(recent[0]?.studentName, "Probe Student");
  const refunds = api.recentRefunds as Record<string, unknown>[];
  assertEquals(refunds[0]?.requestedAt, "2026-06-09T09:00:00.000Z");
});

Deno.test("org scope denied for finance dashboard read", () => {
  const denied = requirePermission(orgClaims(), "viewFinance") ??
    requireSchoolOperationalScope(orgClaims());
  assertEquals(denied?.status, 403);
});
