// CANONICAL ATTENDANCE-% — owner-ratified policy (2026-07-09).
//
// A gap sweep found the attendance percentage computed THREE contradictory
// ways across surfaces:
//   1. admin monthly register / short-attendance alerts — present+late only,
//      excused/half_day dropped from both sides.
//   2. pilot parent snapshot overlay — excused+half_day counted as full
//      presence, late NOT counted as present.
//   3. SIS Student 360 / parent hub / parent academic summary — ONLY the
//      exact mark = 'present' counted; late/excused/half_day all counted
//      AGAINST the student.
//
// There is now exactly ONE definition, mirroring how `finance_aging.ts`
// keeps `overdueDaysSql` a single shared expression so consumers can never
// diverge again. Because consumers are a mix of raw SQL (admin register /
// SIS 360 / parent academic summary) and in-process TS aggregation (pilot
// snapshot overlay), this module exports BOTH a SQL fragment family and a TS
// helper family that agree exactly:
//
//   ATTENDED     = present + late + 0.5 × half_day
//   DENOMINATOR  = total_marked − excused   (excused is neither present nor absent)
//   PERCENT      = ROUND(ATTENDED / DENOMINATOR × 100)   — integer, 0-100
//
// Divide-by-zero rule: when DENOMINATOR is 0 (nothing marked yet, or every
// marked day for the window was excused) the percentage is `null` — NEVER 0
// and NEVER 100. Callers display this as "—"/"no data", not as 0%.
//
// The five recognized marks (DB CHECK `attendance_records_mark_check`):
// 'present' | 'absent' | 'late' | 'excused' | 'half_day'.

/** The five marks the `attendance_records.mark` CHECK constraint allows. */
export type AttendanceMark = "present" | "absent" | "late" | "excused" | "half_day";

/** Per-mark tallies used to compute the canonical percentage from counts. */
export interface AttendanceMarkCounts {
  present: number;
  late: number;
  halfDay: number;
  excused: number;
  absent: number;
}

// --- SQL fragments -----------------------------------------------------------
//
// Each fragment is a self-contained aggregate expression over whatever rows
// are already in scope in the enclosing SELECT (a GROUP BY per student, or an
// ungrouped single-student query) — NOT a correlated subquery like
// `overdueDaysSql`. Inline directly into a SELECT list, e.g.:
//
//   SELECT student_id, ${attendancePercentSql()} AS percent_present
//   FROM attendance_records GROUP BY student_id
//
// `markColumn` defaults to the bare `mark` column name; pass a qualified
// expression (e.g. `"ar.mark"`) when the query joins multiple tables.

/**
 * SQL: attended-days aggregate — present + late + 0.5 × half_day. This is a
 * NUMERIC expression and can be fractional (any half_day mark contributes
 * 0.5). Cast to `::float8` when selecting it directly (an `::int` cast would
 * round/truncate the 0.5 weight away) — see `director_repository.ts` for the
 * `::float8` convention this codebase uses for fractional aggregates.
 */
export function attendedDaysSql(markColumn = "mark"): string {
  return `(count(*) FILTER (WHERE ${markColumn} IN ('present', 'late'))` +
    ` + 0.5 * count(*) FILTER (WHERE ${markColumn} = 'half_day'))`;
}

/** SQL: denominator — total marked minus excused. */
export function attendanceDenominatorSql(markColumn = "mark"): string {
  return `(count(*) - count(*) FILTER (WHERE ${markColumn} = 'excused'))`;
}

/**
 * SQL: the full canonical percentage expression — an integer 0-100, or SQL
 * NULL when the denominator is 0. Safe to alias directly in a SELECT list.
 */
export function attendancePercentSql(markColumn = "mark"): string {
  const attended = attendedDaysSql(markColumn);
  const denominator = attendanceDenominatorSql(markColumn);
  return `(CASE WHEN ${denominator} = 0 THEN NULL` +
    ` ELSE ROUND((${attended}::numeric / ${denominator}) * 100) END)::int`;
}

// --- TS helpers ----------------------------------------------------------
//
// For consumers that already aggregate attendance_records into counts (or a
// raw record list) in TypeScript rather than in SQL.

/** TS: attended count from present/late/half_day tallies (may be fractional). */
export function attendedFromCounts(
  counts: Pick<AttendanceMarkCounts, "present" | "late" | "halfDay">,
): number {
  return counts.present + counts.late + 0.5 * counts.halfDay;
}

/**
 * TS: the canonical percentage from a full mark-count breakdown. Returns
 * `null` (never 0) when the denominator (total_marked − excused) is 0.
 */
export function attendancePercentFromCounts(
  counts: AttendanceMarkCounts,
): number | null {
  const denominator = counts.present + counts.late + counts.halfDay + counts.absent;
  if (denominator <= 0) return null;
  const attended = attendedFromCounts(counts);
  return Math.round((attended / denominator) * 100);
}

/**
 * TS: the canonical percentage computed directly from a list of attendance
 * records (anything with a `mark` field — an unknown/unrecognized mark is
 * ignored on both sides, matching the SQL fragments which only recognize the
 * 5 canonical marks).
 */
export function attendancePercent(records: { mark: string }[]): number | null {
  const counts: AttendanceMarkCounts = {
    present: 0,
    late: 0,
    halfDay: 0,
    excused: 0,
    absent: 0,
  };
  for (const record of records) {
    switch (record.mark) {
      case "present":
        counts.present += 1;
        break;
      case "late":
        counts.late += 1;
        break;
      case "half_day":
        counts.halfDay += 1;
        break;
      case "excused":
        counts.excused += 1;
        break;
      case "absent":
        counts.absent += 1;
        break;
    }
  }
  return attendancePercentFromCounts(counts);
}
