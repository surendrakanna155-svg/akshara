// WEB-001 (ERP-WT-001) — school-admin dashboard overview.
//
// A BFF/aggregation: it does NOT invent new truth. It composes the already-
// certified per-module snapshots (SIS student counts + recent enrolments,
// finance daily summary + outstanding) and adds exactly two scoped reads that
// had no month-to-date / school-wide-today variant yet: this-month collections
// (same finance_collections ledger + status filter as the daily summary, just a
// wider date bound) and today's school-wide attendance (using the ONE canonical
// attendance-percentage SQL so the number agrees with every other surface).
// A brand-new school with no data returns honest zeros / null percent.

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  attendanceDenominatorSql,
  attendancePercentSql,
  attendedDaysSql,
} from "../attendance/attendance_percentage.ts";
import { getDashboard as getSisDashboard } from "../sis/sis_dashboard_repository.ts";
import type { DashboardRecentEnrollment } from "../sis/sis_dashboard_repository.ts";
import { getDailySummary } from "../finance/finance_collections_repository.ts";

export interface DashboardOverview {
  students: {
    total: number;
    active: number;
    inactive: number;
    graduated: number;
  };
  attendanceToday: {
    sessionsSubmitted: number;
    studentsMarked: number;
    attendedEquivalent: number;
    percent: number | null;
  };
  finance: {
    collectedToday: number;
    collectedTodayCount: number;
    collectedMtd: number;
    collectedMtdCount: number;
    outstanding: number;
    pendingInvoices: number;
  };
  admissions: {
    pending: number;
    recent: number;
  };
  recentEnrollments: DashboardRecentEnrollment[];
}

export async function buildDashboardOverview(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<DashboardOverview> {
  const sis = await getSisDashboard(db, organizationId, schoolId);
  const daily = await getDailySummary(db, organizationId, schoolId);

  // This-month collections — same ledger + 'completed' status as the daily
  // summary's todayCollections (today ⊆ MTD), just a month-to-date date bound.
  const mtdRows = await db.queryObject<{ mtd: string; cnt: string }>(
    `SELECT coalesce(sum(amount_collected), 0)::text AS mtd, count(*)::text AS cnt
       FROM finance_collections
      WHERE organization_id = $1 AND school_id = $2
        AND collection_status = 'completed'
        AND collection_date >= date_trunc('month', CURRENT_DATE)`,
    [organizationId, schoolId],
  );
  const mtd = mtdRows[0] ?? { mtd: "0", cnt: "0" };

  // Today's school-wide attendance across submitted sessions (canonical %).
  const attRows = await db.queryObject<{
    attended: number | null;
    denom: number | null;
    percent: number | null;
    sessions: string;
  }>(
    // `denom` MUST carry an explicit cast. attendanceDenominatorSql is a bare
    // count(*) expression, so Postgres returns int8 — which deno-postgres maps
    // to a JS BigInt, and BigInt is not JSON-serializable. Without the cast the
    // handler builds a valid overview object and then dies in JSON.stringify,
    // surfacing as a 500 for every school-scoped user. `attended` is cast for
    // the same reason; `percent` is safe because its helper ends in `::int`.
    `SELECT ${attendedDaysSql("r.mark")}::float8 AS attended,
            ${attendanceDenominatorSql("r.mark")}::float8 AS denom,
            ${attendancePercentSql("r.mark")} AS percent,
            count(DISTINCT r.session_id)::text AS sessions
       FROM attendance_records r
       JOIN attendance_sessions s ON s.id = r.session_id
      WHERE r.organization_id = $1 AND r.school_id = $2
        AND s.session_date = CURRENT_DATE AND s.status = 'submitted'`,
    [organizationId, schoolId],
  );
  const att = attRows[0];

  return {
    students: {
      total: sis.totalStudents,
      active: sis.activeStudents,
      inactive: sis.inactiveStudents,
      graduated: sis.graduatedStudents,
    },
    attendanceToday: {
      sessionsSubmitted: att ? Number(att.sessions) : 0,
      studentsMarked: att?.denom ?? 0,
      attendedEquivalent: att?.attended ?? 0,
      percent: att?.percent ?? null,
    },
    finance: {
      collectedToday: daily.todayCollections,
      collectedTodayCount: daily.todayCollectionCount,
      collectedMtd: Number(mtd.mtd),
      collectedMtdCount: Number(mtd.cnt),
      outstanding: daily.outstandingAmount,
      pendingInvoices: daily.pendingInvoices,
    },
    admissions: {
      pending: sis.pendingConversions,
      recent: sis.recentConversions,
    },
    recentEnrollments: sis.recentEnrollments,
  };
}
