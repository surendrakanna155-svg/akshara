import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  overlayFeesSnapshotFromFinance,
  overlayReceiptsFromFinance,
} from "./pilot_operations_repository.ts";

// SQL-aware mock: the finance overlays issue several distinct queries (count,
// student/enrollment context, school name, data rows). Route each by a marker
// in the SQL so the test exercises the real mapping/shaping logic.
function mockDb(routes: Array<{ match: string; rows: unknown[] }>): TenantQueryClient {
  return {
    queryObject: async <T>(sql: string) => {
      const hit = routes.find((r) => sql.includes(r.match));
      return (hit?.rows ?? []) as T[];
    },
  } as unknown as TenantQueryClient;
}

const STUDENT_CONTEXT = {
  match: "FROM students s",
  rows: [{ display_name: "Asha Rao", class_name: "5", section_name: "A" }],
};

Deno.test("overlayFeesSnapshotFromFinance keeps snapshot but fixes identity when no invoices", async () => {
  const snapshot = { childName: "Stale Name", childClass: "9-Z", summaryLabel: "Fees" };
  const result = await overlayFeesSnapshotFromFinance(
    mockDb([{ match: "FROM finance_invoices", rows: [] }, STUDENT_CONTEXT]),
    "org",
    "school",
    "stu",
    snapshot,
  );
  // identity corrected from real records even with no invoices
  assertEquals(result.childName, "Asha Rao");
  assertEquals(result.childClass, "5-A");
});

Deno.test("overlayFeesSnapshotFromFinance builds real installments + outstanding total", async () => {
  const result = await overlayFeesSnapshotFromFinance(
    mockDb([
      {
        match: "FROM finance_invoices",
        rows: [
          { id: "inv-1", outstanding_amount: "44500", invoice_status: "partially_paid", due_date: "2026-07-23" },
          { id: "inv-2", outstanding_amount: "10000", invoice_status: "issued", due_date: "2026-09-01" },
        ],
      },
      STUDENT_CONTEXT,
    ]),
    "org",
    "school",
    "stu",
    { childName: "Stale", childClass: "9-Z" },
  );

  assertEquals(result.summaryLabel, "Outstanding fees");
  assertEquals(result.totalDue, 54500);
  assertEquals(result.childName, "Asha Rao");
  const installments = result.installments as Record<string, unknown>[];
  assertEquals(installments.length, 2);
  assertEquals(installments[0]?.amountDue, 44500);
  assertEquals(installments[0]?.statusLabel, "partially_paid");
});

Deno.test("overlayReceiptsFromFinance shapes real receipts for the parent app", async () => {
  const page = await overlayReceiptsFromFinance(
    mockDb([
      { match: "count(*)", rows: [{ total: "2" }] },
      STUDENT_CONTEXT,
      { match: "FROM schools", rows: [{ name: "Akshara Public School" }] },
      {
        match: "FROM finance_receipts r",
        rows: [
          {
            id: "rcpt-1",
            receipt_number: "RCPT-2026-AAA",
            date_label: "23 Jun 2026",
            amount: "2500",
            payment_method: "cash",
            collection_status: "completed",
            invoice_number: "INV-A-2026",
          },
          {
            id: "rcpt-2",
            receipt_number: "RCPT-2026-BBB",
            date_label: "20 Jun 2026",
            amount: "5000",
            payment_method: "upi",
            collection_status: "partially_refunded",
            invoice_number: "INV-A-2026",
          },
        ],
      },
    ]),
    "org",
    "school",
    "stu",
    { page: 1, pageSize: 20 },
  );

  assertEquals(page.total, 2);
  assertEquals(page.hasMore, false);
  const first = page.items[0]!;
  assertEquals(first.receiptNumber, "RCPT-2026-AAA");
  assertEquals(first.amount, 2500);
  assertEquals(first.statusLabel, "Paid");
  assertEquals(first.childName, "Asha Rao");
  assertEquals(first.childClass, "5-A");
  assertEquals(first.schoolName, "Akshara Public School");
  assertEquals(first.category, "Fees");
  const lineItems = first.lineItems as Record<string, unknown>[];
  assertEquals(lineItems[0]?.amount, 2500);
  // friendly status mapping for refunded collections
  assertEquals(page.items[1]?.statusLabel, "Partially refunded");
  assert(typeof first.title === "string" && (first.title as string).includes("INV-A-2026"));
});
