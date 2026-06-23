import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  buildExecutiveSummary,
  getAdmissions,
  getMarketing,
  getSchoolRows,
} from "./director_repository.ts";

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
