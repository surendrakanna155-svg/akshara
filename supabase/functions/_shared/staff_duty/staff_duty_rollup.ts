// W4 Staff Duty — per-teacher duty-count rollup (staff-workload intelligence).
//
// Feeds PRC-A caps 131/132/133 (the "Staff workload intelligence" block):
//   • substituteClasses   → cap 131 (Substitution burden)
//   • nonTeachingDuties   → cap 132 (Non-teaching duties)
//   • examInvigilations   → cap 133 (Exam and event duties)
//
// The COUNT AGGREGATION is a pure function (`aggregateStaffDutyCounts`) over
// three lists of `{ staffId }` — no DB, fully unit-testable. `buildStaffDutyRollup`
// is the thin queryable wrapper that loads the rows (optionally within a date
// window) and delegates to the pure aggregator.

import type { TenantQueryClient } from "../tenant_db.ts";

/** One staff member's duty burden across the three duty types. */
export interface StaffDutyCounts {
  staffId: string;
  /** cap 131 — substitute classes this staff member TOOK. */
  substituteClasses: number;
  /** cap 133 — exam/invigilation duties assigned. */
  examInvigilations: number;
  /** cap 132 — non-teaching duties assigned. */
  nonTeachingDuties: number;
  /** Sum of the three (the overall extra-duty load). */
  totalDuties: number;
}

export interface StaffDutyRollupSummary {
  totalStaff: number;
  totalSubstituteClasses: number;
  totalExamInvigilations: number;
  totalNonTeachingDuties: number;
}

export interface StaffDutyRollupResult {
  staff: StaffDutyCounts[];
  summary: StaffDutyRollupSummary;
}

/** A row that attributes a duty to a staff member (only the id matters here). */
export interface DutyAttribution {
  staffId: string;
}

/**
 * PURE count aggregation — the unit-testable core of the rollup.
 *
 * Given the three duty lists (each attributing a duty to a `staffId`), produce
 * one `StaffDutyCounts` per DISTINCT staff member appearing in ANY list. A staff
 * member who appears in only one list still surfaces (zeros for the others).
 * Blank/whitespace staff ids are ignored (they cannot be attributed). Output is
 * sorted busiest-first (totalDuties desc), then stably by staffId.
 */
export function aggregateStaffDutyCounts(
  substitutes: DutyAttribution[],
  examInvigilations: DutyAttribution[],
  nonTeaching: DutyAttribution[],
): StaffDutyCounts[] {
  const byStaff = new Map<string, StaffDutyCounts>();

  const bucket = (staffId: string): StaffDutyCounts => {
    const existing = byStaff.get(staffId);
    if (existing) return existing;
    const fresh: StaffDutyCounts = {
      staffId,
      substituteClasses: 0,
      examInvigilations: 0,
      nonTeachingDuties: 0,
      totalDuties: 0,
    };
    byStaff.set(staffId, fresh);
    return fresh;
  };

  const tally = (
    rows: DutyAttribution[],
    key: "substituteClasses" | "examInvigilations" | "nonTeachingDuties",
  ) => {
    for (const row of rows) {
      const staffId = row.staffId?.trim();
      if (!staffId) continue; // unattributable duty — never fabricate a staffId
      const b = bucket(staffId);
      b[key] += 1;
      b.totalDuties += 1;
    }
  };

  tally(substitutes, "substituteClasses");
  tally(examInvigilations, "examInvigilations");
  tally(nonTeaching, "nonTeachingDuties");

  return [...byStaff.values()].sort((a, b) =>
    b.totalDuties - a.totalDuties || a.staffId.localeCompare(b.staffId)
  );
}

/** Summarise a set of per-staff counts (school aggregate). */
export function summariseStaffDutyCounts(
  staff: StaffDutyCounts[],
): StaffDutyRollupSummary {
  return {
    totalStaff: staff.length,
    totalSubstituteClasses: staff.reduce((s, t) => s + t.substituteClasses, 0),
    totalExamInvigilations: staff.reduce((s, t) => s + t.examInvigilations, 0),
    totalNonTeachingDuties: staff.reduce((s, t) => s + t.nonTeachingDuties, 0),
  };
}

interface StaffIdRow {
  staff_id: string;
}

/** Optional inclusive date window for the rollup. */
export interface StaffDutyRollupWindow {
  from?: string | null;
  to?: string | null;
}

/**
 * Build the per-teacher staff-duty rollup for a school, optionally within a
 * date window. Honest zeros: when no duties exist the `staff` list is `[]` and
 * every summary count is 0 — a workload is never fabricated.
 *
 * Substitution burden is attributed to the SUBSTITUTE teacher (the one who took
 * the class); invigilation and non-teaching duties to their assigned staff_id.
 * A non-teaching duty overlaps the window when [start_date, end_date] intersects
 * it; a dated (substitute/invigilation) duty when duty_date falls inside it.
 */
export async function buildStaffDutyRollup(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  window: StaffDutyRollupWindow = {},
): Promise<StaffDutyRollupResult> {
  const from = window.from ?? null;
  const to = window.to ?? null;

  // Substitute classes → burden bearer. $3=from, $4=to (NULL = unbounded end).
  const substituteRows = await db.queryObject<StaffIdRow>(
    `SELECT substitute_teacher_id AS staff_id
       FROM staff_substitute_classes
      WHERE organization_id = $1 AND school_id = $2
        AND ($3::date IS NULL OR duty_date >= $3::date)
        AND ($4::date IS NULL OR duty_date <= $4::date)`,
    [orgId, schoolId, from, to],
  );

  const invigilationRows = await db.queryObject<StaffIdRow>(
    `SELECT staff_id
       FROM staff_exam_invigilation_duties
      WHERE organization_id = $1 AND school_id = $2
        AND ($3::date IS NULL OR duty_date >= $3::date)
        AND ($4::date IS NULL OR duty_date <= $4::date)`,
    [orgId, schoolId, from, to],
  );

  // Non-teaching duty overlaps the window when its [start, end] range intersects
  // [from, to] (COALESCE(end,start) treats a single-day duty as its start date).
  const nonTeachingRows = await db.queryObject<StaffIdRow>(
    `SELECT staff_id
       FROM staff_non_teaching_duties
      WHERE organization_id = $1 AND school_id = $2
        AND ($4::date IS NULL OR start_date <= $4::date)
        AND ($3::date IS NULL OR COALESCE(end_date, start_date) >= $3::date)`,
    [orgId, schoolId, from, to],
  );

  const staff = aggregateStaffDutyCounts(
    substituteRows.map((r) => ({ staffId: r.staff_id })),
    invigilationRows.map((r) => ({ staffId: r.staff_id })),
    nonTeachingRows.map((r) => ({ staffId: r.staff_id })),
  );

  return { staff, summary: summariseStaffDutyCounts(staff) };
}
