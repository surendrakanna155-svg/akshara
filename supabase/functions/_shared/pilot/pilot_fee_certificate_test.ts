import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  buildFeeCertificateData,
  currentFinancialYear,
  financialYearWindow,
} from "./pilot_operations_repository.ts";

// PAR-D3 — annual / 80C fee-payment certificate DATA.
//
// SQL-aware mock: buildFeeCertificateData issues four distinct queries (school
// name+signatory, student identity, guardian name, the year's receipts). Route
// each by a marker in the SQL so the test exercises the real shaping + own-child
// scoping semantics. The captured `args` prove the year window is passed down.

interface Capture {
  sql: string;
  args: unknown[];
}

function mockDb(
  routes: Array<{ match: string; rows: unknown[] }>,
  captures: Capture[] = [],
): TenantQueryClient {
  return {
    queryObject: async <T>(sql: string, args: unknown[] = []) => {
      captures.push({ sql, args });
      const hit = routes.find((r) => sql.includes(r.match));
      return (hit?.rows ?? []) as T[];
    },
  } as unknown as TenantQueryClient;
}

const SCHOOL_ROW = {
  match: "FROM schools",
  rows: [{ name: "Delhi Public School Kakinada", signatory_title: null }],
};
const STUDENT_ROW = {
  match: "FROM students s",
  rows: [{
    display_name: "Asha Rao",
    public_student_id: "DPSKKP-0001",
    admission_number: "ADM-2025-014",
  }],
};
const GUARDIAN_ROW = {
  match: "FROM users",
  rows: [{ display_name: "Ravi Rao" }],
};

Deno.test("financialYearWindow parses YYYY-YYYY / YYYY-YY / YYYY to an Apr–Mar window", () => {
  assertEquals(financialYearWindow("2025-2026"), {
    startYear: 2025,
    label: "2025-2026",
    start: "2025-04-01",
    endExclusive: "2026-04-01",
  });
  assertEquals(financialYearWindow("2025-26")?.label, "2025-2026");
  assertEquals(financialYearWindow("2025")?.label, "2025-2026");
  assertEquals(financialYearWindow(""), null);
  assertEquals(financialYearWindow("garbage"), null);
  assertEquals(financialYearWindow(null), null);
});

Deno.test("currentFinancialYear rolls over on 1 Apr (Indian FY)", () => {
  // 15 Mar 2026 is still FY 2025-2026; 15 Apr 2026 begins FY 2026-2027.
  assertEquals(currentFinancialYear(new Date("2026-03-15T00:00:00Z")).label, "2025-2026");
  assertEquals(currentFinancialYear(new Date("2026-04-15T00:00:00Z")).label, "2026-2027");
});

Deno.test("buildFeeCertificateData aggregates the year's receipts + total for the own child", async () => {
  const captures: Capture[] = [];
  const data = await buildFeeCertificateData(
    mockDb([
      SCHOOL_ROW,
      STUDENT_ROW,
      GUARDIAN_ROW,
      {
        match: "FROM finance_receipts r",
        rows: [
          {
            date_label: "12 May 2025",
            receipt_number: "RCPT-2025-001",
            amount: "25000.00",
            payment_method: "upi",
            invoice_number: "INV-A-1",
          },
          {
            date_label: "10 Oct 2025",
            receipt_number: "RCPT-2025-047",
            amount: "18500.50",
            payment_method: "cash",
            invoice_number: "INV-A-2",
          },
        ],
      },
    ], captures),
    "org",
    "school",
    "stu",
    "2025-2026",
  );

  // shape + identity fields
  assertEquals(data.schoolName, "Delhi Public School Kakinada");
  assertEquals(data.guardianName, "Ravi Rao");
  assertEquals(data.studentName, "Asha Rao");
  assertEquals(data.publicStudentId, "DPSKKP-0001");
  assertEquals(data.admissionNumber, "ADM-2025-014");
  assertEquals(data.academicYear, "2025-2026");
  // default signatory when the school has not configured one
  assertEquals(data.signatoryTitle, "Principal");

  // aggregation
  assertEquals(data.payments.length, 2);
  assertEquals(data.totalPaidAmount, 43500.5);
  assertEquals(data.payments[0].receiptNo, "RCPT-2025-001");
  assertEquals(data.payments[0].date, "12 May 2025");
  assertEquals(data.payments[0].amount, 25000);
  assertEquals(data.payments[0].paymentMethod, "upi");
  assertEquals(data.payments[0].description, "Fee payment · INV-A-1");

  // the FY window (1 Apr 2025 → 1 Apr 2026) is passed to the receipts query,
  // proving the year filter is applied server-side, not client-trusted.
  const receiptsCall = captures.find((c) => c.sql.includes("FROM finance_receipts r"));
  assert(receiptsCall, "expected a receipts query");
  assert(receiptsCall!.args.includes("2025-04-01"));
  assert(receiptsCall!.args.includes("2026-04-01"));
  // only completed collections count toward an 80C certificate
  assert(receiptsCall!.sql.includes("collection_status = 'completed'"));
});

Deno.test("buildFeeCertificateData returns an honest zero for a year with no payments", async () => {
  const data = await buildFeeCertificateData(
    mockDb([
      SCHOOL_ROW,
      STUDENT_ROW,
      GUARDIAN_ROW,
      { match: "FROM finance_receipts r", rows: [] },
    ]),
    "org",
    "school",
    "stu",
    "2024-2025",
  );
  assertEquals(data.payments, []);
  assertEquals(data.totalPaidAmount, 0);
  assertEquals(data.academicYear, "2024-2025");
  // identity + signatory still present on an empty certificate
  assertEquals(data.publicStudentId, "DPSKKP-0001");
  assertEquals(data.signatoryTitle, "Principal");
});

Deno.test("buildFeeCertificateData honours a per-school configured signatory title", async () => {
  const data = await buildFeeCertificateData(
    mockDb([
      {
        match: "FROM schools",
        rows: [{ name: "St. Xaviers", signatory_title: "Head of School" }],
      },
      STUDENT_ROW,
      GUARDIAN_ROW,
      { match: "FROM finance_receipts r", rows: [] },
    ]),
    "org",
    "school",
    "stu",
    "2025-2026",
  );
  assertEquals(data.signatoryTitle, "Head of School");
});

Deno.test("buildFeeCertificateData falls back to the current FY when the year is missing/garbage", async () => {
  const data = await buildFeeCertificateData(
    mockDb([
      SCHOOL_ROW,
      STUDENT_ROW,
      GUARDIAN_ROW,
      { match: "FROM finance_receipts r", rows: [] },
    ]),
    "org",
    "school",
    "stu",
    null,
  );
  // falls back to a real FY label rather than throwing
  assertEquals(data.academicYear, currentFinancialYear().label);
});

// Own-child leak guard: a child NOT linked to the parent is stopped at the
// handler (resolveParentStudentId → 403 for an unlinked activeChildId) BEFORE any
// query runs, and the finance parent RLS is the second lock. When resolution
// *does* reach the repository for a foreign student, RLS yields zero rows across
// the identity + receipts queries, so the certificate is empty — never another
// family's data.
Deno.test("buildFeeCertificateData never leaks another child's data (RLS yields zero rows)", async () => {
  const data = await buildFeeCertificateData(
    mockDb([
      SCHOOL_ROW,
      // student identity + receipts return nothing under the parent RLS policy
      { match: "FROM students s", rows: [] },
      GUARDIAN_ROW,
      { match: "FROM finance_receipts r", rows: [] },
    ]),
    "org",
    "school",
    "not-my-child",
    "2025-2026",
  );
  assertEquals(data.studentName, "Student");
  assertEquals(data.publicStudentId, "");
  assertEquals(data.admissionNumber, "");
  assertEquals(data.payments, []);
  assertEquals(data.totalPaidAmount, 0);
});
