import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  buildBoardPack,
  buildExecutiveSummary,
  getAdmissions,
  getCollectionReport,
  getMarketing,
  getMetricInputs,
  getSchoolRows,
  getSchoolSnapshot,
  upsertMetricInput,
} from "./director_repository.ts";
import { refineExecutiveSummaryWithClaude } from "./director_ai.ts";
import { directorAudit } from "../audit/mutation_audit_catalog.ts";

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
      // CANONICAL shape: attended (present+late+0.5×half_day) / denom
      // (total_marked−excused) — 90/100 has no late/excused/half_day mix so
      // canonical agrees with the old present<>'absent'/total formula: 90%.
      return [{ school_id: SCHOOL_A, attended: 90, denom: 100 }] as T[]; // 90%
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
  // DIR-2 — money inputs behind fee% surfaced per school; outstanding = billed − collected.
  assertEquals(north.billedInr, 40_000_000);
  assertEquals(north.collectedInr, 38_000_000);
  assertEquals(north.outstandingInr, 2_000_000);
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
  // DIR-2 — a school with no invoices reports honest zeros, not fabricated debt.
  assertEquals(east.billedInr, 0);
  assertEquals(east.collectedInr, 0);
  assertEquals(east.outstandingInr, 0);
  assertEquals(east.healthScore, 75); // no graded/financial data → onboarding baseline
  assertEquals(east.status, "onTrack");
});

// ─── DIR-2 — consolidated collection report (per-school + org totals) ────────

Deno.test("getCollectionReport surfaces per-school money + consistent org totals", async () => {
  const report = await getCollectionReport(db(), ORG);
  assertEquals(report.schools.length, 2);

  const north = report.schools.find((s) => s.name === "Akshara North");
  assertEquals(north?.billedInr, 40_000_000);
  assertEquals(north?.collectedInr, 38_000_000);
  assertEquals(north?.outstandingInr, 2_000_000);
  assertEquals(north?.feeCollectionPercent, 95);

  const east = report.schools.find((s) => s.name === "Akshara East");
  assertEquals(east?.billedInr, 0);
  assertEquals(east?.outstandingInr, 0);

  // Totals are the sum of the per-school rows (no re-derivation): 40M billed,
  // 38M collected, 2M outstanding → 95% org-wide realization.
  assertEquals(report.totals.billedInr, 40_000_000);
  assertEquals(report.totals.collectedInr, 38_000_000);
  assertEquals(report.totals.outstandingInr, 2_000_000);
  assertEquals(report.totals.feeCollectionPercent, 95);
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

// ─── DIR-D1 — per-school read-only drill-down snapshot ──────────────────────

/**
 * Mock for the single-school snapshot queries. `owned` toggles the school-
 * belongs-to-org guard: when false the guard SELECT returns no row and
 * getSchoolSnapshot must short-circuit to null WITHOUT ever running the
 * aggregate queries (the foreign-school-never-leaks guarantee).
 */
class SnapshotDb {
  ranAggregate = false;
  constructor(private readonly opts: { owned: boolean }) {}
  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, _args: unknown[] = []): Promise<T[]> {
    const has = (...frags: string[]) => frags.every((f) => sql.includes(f));

    // The school-belongs-to-org guard (name + location) — reused metric-inputs check.
    if (has("SELECT name", "FROM schools", "AND organization_id = $2")) {
      return (this.opts.owned ? [{ name: "Akshara North", location: "Hyderabad" }] : []) as T[];
    }
    // Any of these running means the guard let a lookup through.
    if (has("FROM students", "AND school_id = $2")) {
      this.ranAggregate = true;
      return [{ cnt: 1200 }] as T[];
    }
    if (has("FROM finance_invoices", "AND school_id = $2")) {
      this.ranAggregate = true;
      return [{ billed: 40_000_000, collected: 38_000_000 }] as T[];
    }
    if (has("FROM attendance_records", "AND school_id = $2")) {
      this.ranAggregate = true;
      // CANONICAL shape (attended/denom) — see MockDirectorDb above.
      return [{ attended: 90, denom: 100 }] as T[];
    }
    if (has("FROM exam_mark_entries", "AND school_id = $2")) {
      this.ranAggregate = true;
      return [{ pass: 80, total: 100 }] as T[];
    }
    if (has("AS inquiries", "AS enrolled", "school_id = $2")) {
      this.ranAggregate = true;
      return [{ inquiries: 150, applications: 90, enrolled: 45 }] as T[];
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

Deno.test("getSchoolSnapshot returns an audited read-only snapshot for an owned school", async () => {
  const mock = new SnapshotDb({ owned: true });
  const snap = await getSchoolSnapshot(mock as unknown as TenantQueryClient, ORG, SCHOOL_A);
  assertEquals(snap?.schoolId, SCHOOL_A);
  assertEquals(snap?.schoolName, "Akshara North");
  assertEquals(snap?.students, 1200);
  assertEquals(snap?.attendancePercent, 90);
  assertEquals(snap?.feeCollectionPercent, 95);
  assertEquals(snap?.billedInr, 40_000_000);
  assertEquals(snap?.collectedInr, 38_000_000);
  assertEquals(snap?.outstandingInr, 2_000_000);
  assertEquals(snap?.admissions.enrolled, 45);
  assertEquals(snap?.admissions.conversionPercent, 30); // 45/150
  assertEquals(snap?.academic.passPercent, 80);
  // health = 0.4*95 + 0.3*90 + 0.3*80 = 89
  assertEquals(snap?.healthScore, 89);
  assertEquals(snap?.status, "topPerformer");
});

Deno.test("DIR-D1: the drilldown emits a director.school.drilldown READ audit action", () => {
  // The "read-through with audit" requirement: a GET that audits. The spec is a
  // read-category event keyed on schoolId + timestamp (nonce), carrying the
  // target school so actor+schoolId+timestamp are captured on emit.
  const spec = directorAudit.schoolDrilldown(SCHOOL_A, "2026-07-02T10:00:00.000Z");
  assertEquals(spec.audit.eventType, "director.school.drilldown");
  assertEquals(spec.audit.category, "read");
  assertEquals(spec.audit.entityType, "school");
  assertEquals(spec.audit.entityId, SCHOOL_A);
  assertEquals(spec.domain.eventType, "director.school.drilldown");
  assertEquals(spec.domain.sourceModule, "director");
  assertEquals(spec.domain.payload.schoolId, SCHOOL_A);
  // Nonce keys the outbox so each distinct view is recorded, not deduped.
  assertEquals(
    spec.domain.idempotencyKey,
    `director.school.drilldown:${SCHOOL_A}:2026-07-02T10:00:00.000Z`,
  );
});

Deno.test("getSchoolSnapshot refuses a school outside the org (null, no aggregate leak)", async () => {
  const mock = new SnapshotDb({ owned: false });
  const snap = await getSchoolSnapshot(
    mock as unknown as TenantQueryClient,
    ORG,
    "a2000000-0000-4000-8000-00000000ffff",
  );
  assertEquals(snap, null);
  // The guard short-circuits: no per-school aggregate query ever ran, so no
  // other org's data could have been read.
  assertEquals(mock.ranAggregate, false);
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
        billedInr: 40_000_000,
        collectedInr: 38_000_000,
        outstandingInr: 2_000_000,
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
        billedInr: 0,
        collectedInr: 0,
        outstandingInr: 0,
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
