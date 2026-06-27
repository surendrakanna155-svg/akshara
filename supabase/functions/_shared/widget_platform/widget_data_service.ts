import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { buildOperationsHub } from "../operations/operations_hub_service.ts";

export interface WidgetLivePayload {
  widgetId: string;
  title: string;
  value: string;
  summary: string;
  metrics: Record<string, number | string>;
  alerts: string[];
  refreshedAt: string;
  permissionDenied: boolean;
}

const CACHE_TTL_MS = 60_000;
const cache = new Map<string, { expiresAt: number; widgets: Record<string, WidgetLivePayload> }>();

function cacheKey(orgId: string, schoolId: string, userId: string): string {
  return `${orgId}:${schoolId}:${userId}`;
}

function hasWidgetAccess(claims: AccessTokenClaims, requiredPermission: string | null): boolean {
  // Widgets with an explicit required permission must satisfy it via the
  // claim's permission set — school scope alone does not grant access.
  if (requiredPermission) return claims.permissions.includes(requiredPermission);
  // Generic widgets (no required permission) remain accessible to school scope.
  return claims.scope === "school" && !!claims.school_id;
}

const WIDGET_PERMISSIONS: Record<string, string> = {
  school_health: "viewOperationsHub",
  student_risk: "viewStudentRisk",
  fee_collection: "viewFinance",
  attendance_risk: "viewStudentRisk",
  homework_summary: "viewHomeworkIntelligence",
  operations_summary: "viewOperationsHub",
  employee_workload: "viewEmployeeIntelligence",
  timetable_alerts: "viewAcademicTimetable",
};

export async function buildWidgetData(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  claims: AccessTokenClaims,
  options: { widgetIds?: string[]; forceRefresh?: boolean } = {},
): Promise<{ widgets: Record<string, WidgetLivePayload>; cached: boolean }> {
  const key = cacheKey(organizationId, schoolId, claims.sub);
  const now = Date.now();
  const cached = cache.get(key);
  if (!options.forceRefresh && cached && cached.expiresAt > now) {
    if (options.widgetIds?.length) {
      const filtered: Record<string, WidgetLivePayload> = {};
      for (const id of options.widgetIds) {
        if (cached.widgets[id]) filtered[id] = cached.widgets[id]!;
      }
      return { widgets: filtered, cached: true };
    }
    return { widgets: cached.widgets, cached: true };
  }

  const hub = await buildOperationsHub(client, organizationId, schoolId);
  const refreshedAt = new Date().toISOString();

  const homeworkRows = await client.queryObject<{ run_count: number }>(
    `SELECT count(*)::int AS run_count
     FROM homework_intelligence_runs
     WHERE organization_id = $1 AND school_id = $2
       AND created_at >= CURRENT_DATE - interval '7 days'`,
    [organizationId, schoolId],
  );

  const timetableRows = await client.queryObject<{ count: number }>(
    `SELECT count(*)::int AS count
     FROM academic_timetables
     WHERE organization_id = $1 AND school_id = $2
       AND status != 'published'`,
    [organizationId, schoolId],
  );

  const allWidgets: Record<string, WidgetLivePayload> = {
    school_health: {
      widgetId: "school_health",
      title: "School Health",
      value: `${hub.schoolHealth}`,
      summary: "Overall school health score",
      metrics: { score: hub.schoolHealth },
      alerts: hub.criticalAlerts.map((a) => a.title),
      refreshedAt,
      permissionDenied: false,
    },
    student_risk: {
      widgetId: "student_risk",
      title: "Student Risk",
      value: `${hub.widgets.studentRiskAlerts}`,
      summary: "High-risk students this week",
      metrics: { count: hub.widgets.studentRiskAlerts },
      alerts: [],
      refreshedAt,
      permissionDenied: false,
    },
    fee_collection: {
      widgetId: "fee_collection",
      title: "Fee Collection",
      value: `₹${Math.round(hub.widgets.todayCollections.amount)}`,
      summary: "Collections today",
      metrics: {
        amount: hub.widgets.todayCollections.amount,
        count: hub.widgets.todayCollections.count,
      },
      alerts: hub.widgets.feeAlerts > 0 ? [`${hub.widgets.feeAlerts} fee alerts`] : [],
      refreshedAt,
      permissionDenied: false,
    },
    attendance_risk: {
      widgetId: "attendance_risk",
      title: "Attendance Risk",
      value: `${hub.dailySummary.criticalAlerts}`,
      summary: `${hub.dailySummary.attendancePct}% attendance today`,
      metrics: {
        attendancePct: hub.dailySummary.attendancePct,
        present: hub.widgets.todayAttendance.present,
        absent: hub.widgets.todayAttendance.absent,
      },
      alerts: [],
      refreshedAt,
      permissionDenied: false,
    },
    homework_summary: {
      widgetId: "homework_summary",
      title: "Homework Summary",
      value: `${homeworkRows[0]?.run_count ?? 0}`,
      summary: "Homework intelligence runs (7 days)",
      metrics: { runs: homeworkRows[0]?.run_count ?? 0 },
      alerts: [],
      refreshedAt,
      permissionDenied: false,
    },
    operations_summary: {
      widgetId: "operations_summary",
      title: "Operations Summary",
      value: `${hub.pendingActions.length}`,
      summary: "Pending operational actions",
      metrics: { pending: hub.pendingActions.length, critical: hub.criticalAlerts.length },
      alerts: hub.pendingActions.slice(0, 3).map((a) => a.title),
      refreshedAt,
      permissionDenied: false,
    },
    employee_workload: {
      widgetId: "employee_workload",
      title: "Employee Workload",
      value: `${hub.widgets.employeeRiskAlerts}`,
      summary: "Staff with elevated workload risk",
      metrics: { count: hub.widgets.employeeRiskAlerts },
      alerts: [],
      refreshedAt,
      permissionDenied: false,
    },
    timetable_alerts: {
      widgetId: "timetable_alerts",
      title: "Timetable Alerts",
      value: `${timetableRows[0]?.count ?? 0}`,
      summary: "Open timetable conflicts",
      metrics: { count: timetableRows[0]?.count ?? 0 },
      alerts: [],
      refreshedAt,
      permissionDenied: false,
    },
  };

  const widgets: Record<string, WidgetLivePayload> = {};
  const ids = options.widgetIds?.length
    ? options.widgetIds
    : Object.keys(allWidgets);

  for (const id of ids) {
    const base = allWidgets[id];
    if (!base) continue;
    const permission = WIDGET_PERMISSIONS[id] ?? null;
    const allowed = hasWidgetAccess(claims, permission);
    widgets[id] = allowed
      ? base
      : {
        ...base,
        value: "—",
        summary: "Permission required",
        metrics: {},
        alerts: [],
        permissionDenied: true,
      };
  }

  cache.set(key, { expiresAt: now + CACHE_TTL_MS, widgets: allWidgets });
  return { widgets, cached: false };
}

export function invalidateWidgetCache(orgId: string, schoolId: string, userId: string): void {
  cache.delete(cacheKey(orgId, schoolId, userId));
}
