// W4 Staff Duty — rollup counts (pure aggregation + fake-DB build). Feeds
// PRC-A caps 131 (substitution burden) / 132 (non-teaching) / 133 (exam duties).
//
// Proves:
//   • the PURE aggregator counts each duty type per staff member correctly;
//   • a staff member in only one list still surfaces (zeros elsewhere);
//   • blank staff ids are ignored (never a fabricated attribution);
//   • busiest-first sort (totalDuties desc, then staffId);
//   • the queryable build wires the three tables to the pure aggregator;
//   • honest zeros when there are no duties;
//   • the date window is threaded into each query.

import { assert, assertEquals } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  aggregateStaffDutyCounts,
  buildStaffDutyRollup,
  summariseStaffDutyCounts,
} from "./staff_duty_rollup.ts";

const ORG = "org-1";
const SCHOOL = "school-1";

// ─── Pure aggregation ───────────────────────────────────────────────────────

Deno.test("aggregateStaffDutyCounts: counts each duty type per staff, sums the total", () => {
  const staff = aggregateStaffDutyCounts(
    [{ staffId: "T1" }, { staffId: "T1" }, { staffId: "T2" }], // substitutes
    [{ staffId: "T1" }], // invigilations
    [{ staffId: "T2" }, { staffId: "T2" }, { staffId: "T2" }], // non-teaching
  );
  const byId = new Map(staff.map((s) => [s.staffId, s]));

  assertEquals(byId.get("T1")!.substituteClasses, 2);
  assertEquals(byId.get("T1")!.examInvigilations, 1);
  assertEquals(byId.get("T1")!.nonTeachingDuties, 0);
  assertEquals(byId.get("T1")!.totalDuties, 3);

  assertEquals(byId.get("T2")!.substituteClasses, 1);
  assertEquals(byId.get("T2")!.examInvigilations, 0);
  assertEquals(byId.get("T2")!.nonTeachingDuties, 3);
  assertEquals(byId.get("T2")!.totalDuties, 4);
});

Deno.test("aggregateStaffDutyCounts: a staff member in only ONE list still appears (zeros elsewhere)", () => {
  const staff = aggregateStaffDutyCounts([], [{ staffId: "solo" }], []);
  assertEquals(staff.length, 1);
  assertEquals(staff[0], {
    staffId: "solo",
    substituteClasses: 0,
    examInvigilations: 1,
    nonTeachingDuties: 0,
    totalDuties: 1,
  });
});

Deno.test("aggregateStaffDutyCounts: blank/whitespace staff ids are ignored (no fabricated attribution)", () => {
  const staff = aggregateStaffDutyCounts(
    [{ staffId: "" }, { staffId: "   " }, { staffId: "T1" }],
    [],
    [],
  );
  assertEquals(staff.length, 1);
  assertEquals(staff[0].staffId, "T1");
  assertEquals(staff[0].substituteClasses, 1);
});

Deno.test("aggregateStaffDutyCounts: sorted busiest-first, then stably by staffId", () => {
  const staff = aggregateStaffDutyCounts(
    [{ staffId: "B" }, { staffId: "A" }, { staffId: "C" }], // each 1 substitute
    [{ staffId: "A" }], // A gets a 2nd duty → busiest
    [],
  );
  // A has 2 (busiest); B and C each have 1 → tie broken by staffId asc.
  assertEquals(staff.map((s) => s.staffId), ["A", "B", "C"]);
  assertEquals(staff[0].totalDuties, 2);
});

Deno.test("aggregateStaffDutyCounts: empty everywhere → []", () => {
  assertEquals(aggregateStaffDutyCounts([], [], []), []);
});

Deno.test("summariseStaffDutyCounts: school aggregate sums each duty type", () => {
  const staff = aggregateStaffDutyCounts(
    [{ staffId: "T1" }, { staffId: "T2" }],
    [{ staffId: "T1" }],
    [{ staffId: "T2" }, { staffId: "T3" }],
  );
  const summary = summariseStaffDutyCounts(staff);
  assertEquals(summary, {
    totalStaff: 3,
    totalSubstituteClasses: 2,
    totalExamInvigilations: 1,
    totalNonTeachingDuties: 2,
  });
});

// ─── Queryable build (fake DB dispatching on SQL fragments) ─────────────────

interface StaffIdRow {
  staff_id: string;
}

class RollupDb {
  lastArgs: unknown[][] = [];
  constructor(
    private subs: StaffIdRow[],
    private invs: StaffIdRow[],
    private nts: StaffIdRow[],
  ) {}
  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    this.lastArgs.push(args);
    if (sql.includes("FROM staff_substitute_classes")) {
      // The rollup attributes the burden to the SUBSTITUTE teacher.
      assert(sql.includes("substitute_teacher_id AS staff_id"));
      return Promise.resolve(this.subs as unknown as T[]);
    }
    if (sql.includes("FROM staff_exam_invigilation_duties")) {
      return Promise.resolve(this.invs as unknown as T[]);
    }
    if (sql.includes("FROM staff_non_teaching_duties")) {
      return Promise.resolve(this.nts as unknown as T[]);
    }
    throw new Error(`unexpected SQL: ${sql}`);
  }
}

Deno.test("buildStaffDutyRollup: wires the three tables into the pure aggregator", async () => {
  const db = new RollupDb(
    [{ staff_id: "T1" }, { staff_id: "T1" }],
    [{ staff_id: "T1" }],
    [{ staff_id: "T2" }],
  ) as unknown as TenantQueryClient;
  const { staff, summary } = await buildStaffDutyRollup(db, ORG, SCHOOL);

  const byId = new Map(staff.map((s) => [s.staffId, s]));
  assertEquals(byId.get("T1")!.substituteClasses, 2);
  assertEquals(byId.get("T1")!.examInvigilations, 1);
  assertEquals(byId.get("T2")!.nonTeachingDuties, 1);
  assertEquals(summary.totalStaff, 2);
  assertEquals(summary.totalSubstituteClasses, 2);
  assertEquals(summary.totalExamInvigilations, 1);
  assertEquals(summary.totalNonTeachingDuties, 1);
});

Deno.test("buildStaffDutyRollup: honest zeros when there are no duties", async () => {
  const db = new RollupDb([], [], []) as unknown as TenantQueryClient;
  const { staff, summary } = await buildStaffDutyRollup(db, ORG, SCHOOL);
  assertEquals(staff, []);
  assertEquals(summary, {
    totalStaff: 0,
    totalSubstituteClasses: 0,
    totalExamInvigilations: 0,
    totalNonTeachingDuties: 0,
  });
});

Deno.test("buildStaffDutyRollup: threads the date window into every query", async () => {
  const rollupDb = new RollupDb([], [], []);
  const db = rollupDb as unknown as TenantQueryClient;
  await buildStaffDutyRollup(db, ORG, SCHOOL, { from: "2026-07-01", to: "2026-07-31" });
  // org, school, from, to in each of the three queries.
  assertEquals(rollupDb.lastArgs.length, 3);
  for (const args of rollupDb.lastArgs) {
    assertEquals(args, [ORG, SCHOOL, "2026-07-01", "2026-07-31"]);
  }
});

Deno.test("buildStaffDutyRollup: null window → null from/to args (unbounded)", async () => {
  const rollupDb = new RollupDb([], [], []);
  const db = rollupDb as unknown as TenantQueryClient;
  await buildStaffDutyRollup(db, ORG, SCHOOL);
  for (const args of rollupDb.lastArgs) {
    assertEquals(args, [ORG, SCHOOL, null, null]);
  }
});
