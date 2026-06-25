import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  buildBoardPack,
  buildExecutiveSummary,
  getAdmissions,
  getMarketing,
  getMetricInputs,
  getSchoolRows,
  upsertMetricInput,
} from "./director_repository.ts";
import { refineExecutiveSummaryWithClaude } from "./director_ai.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";

type Row = Record<string, unknown>;

/** Mock db that dispatches by SQL fragment, mirroring the sis repo tests. */
class MockDirectorDb {
  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, _args: unknown[] = []): Promise<T[]> {
    const has = (...frags: string[]) => frags.every((f) => sql.includes(f));

    // Two schools: A has rich data, B is brand-new (no data → neutral health).
    if (has("FROM schools s", "s.settings")) {
      return [
        { id: SCHOOL_A, name: "Akshara North", location: "Hyderabad" },
        { id: SCHOOL_B, name: "Akshara East", location: "" },
      ] as T[];
    }
    if (has("FROM students", "status = 'active'", "GROUP BY school_id")) {
      return [
        { school_id: SCHOOL_A, cnt: 1200 },
        { school_id: SCHOOL_B, cnt: 40 },
      ] as T[];
    }
    if (has("FROM finance_collections", "GROUP BY school_id")) {
      return [{ school_id: SCHOOL_A, amt: 32_000_000 }] as T[]; // 3.2 Cr
    }
    if (has("FROM finance_invoices", "total_amount - outstanding_amount", "GROUP BY school_id")) {
      return [{ school_id: SCHOOL_A, billed: 40_000_000, collected: 38_000_000 }] as T[]; // 95%
    }
    if (has("FROM admissions_enrollments", "90 days", "GROUP BY school_id")) {
      return [{ school_id: SCHOOL_A, cnt: 18 }] as T[];
    }
    if (has("FROM attendance_records", "GROUP BY school_id")) {
      return [{ school_id: SCHOOL_A, present: 90, total: 100 }] as T[]; // 90%
    }
    if (has("FROM exam_mark_entries", "GROUP BY school_id")) {
      return [{ school_id: SCHOOL_A, pass: 80, total: 100 }] as T[]; // 80%
    }

    // Admissions funnel (org-wide single row) + per-school conversion.
    if (has("AS inquiries", "AS enrolled")) {
      return [{ inquiries: 200, applications: 120, interviews: 70, enrolled: 50 }] as T[];
    }
    if (has("FROM schools s", "AS leads", "AS enrolled")) {
      return [
        { name: "Akshara North", leads: 150, enrolled: 45 },
        { name: "Akshara East", leads: 50, enrolled: 5 },
      ] as T[];
    }

    // Marketing: leads count, no spend rows entered yet.
    if (has("FROM admissions_leads WHERE organization_id = $1")) {
      return [{ cnt: 200 }] as T[];
    }
    if (has("FROM director_metric_inputs", "marketing_spend_inr")) {
      return [{ spend: 0 }] as T[];
    }
    if (has("FROM finance_collections", "collection_status = 'completed'")) {
      return [{ amt: 32_000_000 }] as T[];
    }

    // Report catalog row (for buildBoardPack).
    if (has("FROM director_reports WHERE organization_id = $1 AND id = $2")) {
      return [{
        id: "rpt-1",
        title: "Board Pack",
        description: "Quarterly board review",
        file_type: "PDF",
        last_generated_at: "2026-06-01T00:00:00Z",
      }] as T[];
    }

    return [] as T[];
  }

  // deno-lint-ignore require-await
  async queryCount(): Promise<number> {
    return 0;
  }
  get raw(): never {
    throw new Error("unused");
  }
}

const db = () => new MockDirectorDb() as unknown as TenantQueryClient;

Deno.test("getSchoolRows computes health, fee% and status from real signals", async () => {
  const rows = await getSchoolRows(db(), ORG);
  assertEquals(rows.length, 2);

  const north = rows[0];
  assertEquals(north.schoolName, "Akshara North");
  assertEquals(north.students, 1200);
  assertEquals(north.revenueCr, 3.2);
  assertEquals(north.feeCollectionPercent, 95);
  // health = 0.4*95 + 0.3*90 + 0.3*80 = 38 + 27 + 24 = 89 → topPerformer
  assertEquals(north.healthScore, 89);
  assertEquals(north.status, "topPerformer");
});

Deno.test("getSchoolRows gives a new school a neutral baseline, not a fake score", async () => {
  const rows = await getSchoolRows(db(), ORG);
  const east = rows[1];
  assertEquals(east.students, 40);
  assertEquals(east.revenueCr, 0);
  assertEquals(east.feeCollectionPercent, 0);
  assertEquals(east.healthScore, 75); // no graded/financial data → onboarding baseline
  assertEquals(east.status, "onTrack");
});

Deno.test("getMarketing reports honest zeros when no spend is entered", async () => {
  const marketing = await getMarketing(db(), ORG);
  assertEquals(marketing.totalLeads, 200);
  assertEquals(marketing.totalSpendLakhs, 0);
  assertEquals(marketing.cplInr, 0); // not divided by zero / not invented
  assertEquals(marketing.roiPercent, 0);
  assertEquals(marketing.channelPerformance, {});
});

Deno.test("getAdmissions computes funnel and per-school conversion", async () => {
  const admissions = await getAdmissions(db(), ORG);
  assertEquals(admissions.inquiries, 200);
  assertEquals(admissions.enrolled, 50);
  assertEquals(admissions.conversionPercent, 25); // 50/200
  assertEquals(admissions.bySchoolConversion["Akshara North"], 30); // 45/150
  assertEquals(admissions.bySchoolConversion["Akshara East"], 10); // 5/50
});

// ─── Metric inputs (the new write path) ─────────────────────────────────────

/** Mock that captures args, for the upsert/list metric-input queries. */
class MetricInputDb {
  constructor(private readonly opts: { schoolOwned: boolean }) {}
  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    const has = (...frags: string[]) => frags.every((f) => sql.includes(f));

    if (has("SELECT 1 AS ok FROM schools")) {
      return (this.opts.schoolOwned ? [{ ok: 1 }] : []) as T[];
    }
    if (has("INSERT INTO director_metric_inputs", "ON CONFLICT")) {
      return [{
        id: "mi-1",
        school_id: args[1],
        school_name: "Akshara North",
        period_month: args[2],
        marketing_spend_inr: args[3],
        operating_expense_inr: args[4],
        student_capacity: args[5],
      }] as T[];
    }
    if (has("FROM director_metric_inputs mi", "JOIN schools s")) {
      return [{
        id: "mi-1",
        school_id: SCHOOL_A,
        school_name: "Akshara North",
        period_month: "2026-06-01",
        marketing_spend_inr: 250000,
        operating_expense_inr: 1800000,
        student_capacity: 1500,
      }] as T[];
    }
    return [] as T[];
  }
  // deno-lint-ignore require-await
  async queryCount(): Promise<number> {
    return 0;
  }
  get raw(): never {
    throw new Error("unused");
  }
}

const metricDb = (schoolOwned: boolean) =>
  new MetricInputDb({ schoolOwned }) as unknown as TenantQueryClient;

Deno.test("upsertMetricInput saves and maps an owned school's metric input", async () => {
  const saved = await upsertMetricInput(metricDb(true), ORG, {
    schoolId: SCHOOL_A,
    periodMonth: "2026-06-01",
    marketingSpendInr: 250000,
    operatingExpenseInr: 1800000,
    studentCapacity: 1500,
  });
  assertEquals(saved?.schoolId, SCHOOL_A);
  assertEquals(saved?.marketingSpendInr, 250000);
  assertEquals(saved?.operatingExpenseInr, 1800000);
  assertEquals(saved?.studentCapacity, 1500);
  assertEquals(saved?.periodMonth, "2026-06-01");
});

Deno.test("upsertMetricInput refuses a school outside the organization", async () => {
  const saved = await upsertMetricInput(metricDb(false), ORG, {
    schoolId: "a2000000-0000-4000-8000-00000000ffff",
    periodMonth: "2026-06-01",
    marketingSpendInr: 1,
    operatingExpenseInr: 1,
    studentCapacity: 1,
  });
  assertEquals(saved, null);
});

Deno.test("getMetricInputs returns entered rows mapped to the domain shape", async () => {
  const rows = await getMetricInputs(metricDb(true), ORG);
  assertEquals(rows.length, 1);
  assertEquals(rows[0].schoolName, "Akshara North");
  assertEquals(rows[0].marketingSpendInr, 250000);
  assertEquals(rows[0].studentCapacity, 1500);
});

Deno.test("buildBoardPack assembles a real document from live aggregates", async () => {
  const pack = await buildBoardPack(db(), ORG, "rpt-1", new Date("2026-06-15T00:00:00Z"));
  assertEquals(pack?.title, "Board Pack");
  assertEquals(pack?.fileType, "PDF");
  assertEquals(pack?.schools.length, 2);
  assertEquals(pack?.kpis.length, 5);
  // KPIs carry the real chain figures, not placeholders.
  assertEquals(pack?.kpis[0].value, "2"); // total schools
  assertEquals(pack?.revenue.chainRevenueCr, 3.2);
  assertEquals(pack?.admissions.conversionPercent, 25);
  assertEquals(typeof pack?.executiveSummary, "string");
  assertEquals((pack?.executiveSummary.length ?? 0) > 0, true);
});

Deno.test("refineExecutiveSummaryWithClaude returns the deterministic brief when no key", async () => {
  const brief = "Portfolio spans 2 schools and 1,240 active students.";
  const out = await refineExecutiveSummaryWithClaude(brief, {
    focusArea: "dashboard",
    schoolCount: 2,
    totalStudents: 1240,
    chainRevenueCr: 3.2,
    marginPercent: 30,
    enrolled: 50,
    inquiries: 200,
    conversionPercent: 25,
    atRiskSchools: ["Akshara East"],
  });
  assertEquals(out, brief); // safe fallback — no API key configured in tests
});

Deno.test("buildExecutiveSummary summarizes real aggregates without PII", () => {
  const summary = buildExecutiveSummary(
    "dashboard",
    [
      {
        schoolId: SCHOOL_A,
        schoolName: "Akshara North",
        location: "Hyderabad",
        students: 1200,
        revenueCr: 3.2,
        admissionsQtd: 18,
        feeCollectionPercent: 95,
        healthScore: 89,
        status: "topPerformer",
      },
      {
        schoolId: SCHOOL_B,
        schoolName: "Akshara East",
        location: "",
        students: 40,
        revenueCr: 0,
        admissionsQtd: 0,
        feeCollectionPercent: 0,
        healthScore: 50,
        status: "critical",
      },
    ],
    { chainRevenueCr: 3.2, marginPercent: 30 },
    { enrolled: 50, inquiries: 200, conversionPercent: 25 },
  );
  assertEquals(summary.includes("2 schools"), true);
  assertEquals(summary.includes("1,240 active students"), true);
  assertEquals(summary.includes("Akshara East"), true); // at-risk campus named
  assertEquals(summary.includes("25%"), true);
});
