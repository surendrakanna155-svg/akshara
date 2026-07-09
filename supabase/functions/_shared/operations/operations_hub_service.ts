import type { TenantQueryClient } from "../tenant_db.ts";
import { buildDistributionDashboard } from "../inventory_distribution/inventory_distribution_repository.ts";
import { attendancePercentSql } from "../attendance/attendance_percentage.ts";

// Gap-remediation #6 — the criticalAlerts/pendingActions ids below are the
// FIXED synthetic category ids buildOperationsHub ever emits (there is no
// per-row alert entity). dismiss/complete are only meaningful against one of
// these; anything else is a validation error, not a "not found".
export const KNOWN_OPERATIONS_ALERT_IDS = [
  "student-risk",
  "inventory-replacement",
  "fee-alerts",
] as const;
export const KNOWN_OPERATIONS_ACTION_IDS = [
  "inv-pending",
  "inv-payment",
] as const;

export function isKnownOperationsAlertId(id: string): boolean {
  return (KNOWN_OPERATIONS_ALERT_IDS as readonly string[]).includes(id);
}

export function isKnownOperationsActionId(id: string): boolean {
  return (KNOWN_OPERATIONS_ACTION_IDS as readonly string[]).includes(id);
}

interface TodaysItemActions {
  dismissedAlertIds: Set<string>;
  completedActionIds: Set<string>;
}

async function fetchTodaysItemActions(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<TodaysItemActions> {
  const rows = await client.queryObject<{ item_type: string; item_id: string }>(
    `SELECT item_type, item_id FROM operations_hub_item_actions
     WHERE organization_id = $1 AND school_id = $2 AND occurrence_date = CURRENT_DATE`,
    [organizationId, schoolId],
  );
  const dismissedAlertIds = new Set(
    rows.filter((r) => r.item_type === "alert").map((r) => r.item_id),
  );
  const completedActionIds = new Set(
    rows.filter((r) => r.item_type === "action").map((r) => r.item_id),
  );
  return { dismissedAlertIds, completedActionIds };
}

/**
 * Persists a dismissal of a critical alert (idempotent — dismissing the same
 * alert again the same day just refreshes who/when). Scoped to TODAY: the hub
 * recomputes criticalAlerts fresh every call, so "dismissed" means "for the
 * rest of today" — if the underlying condition is still true tomorrow, a new
 * alert legitimately reappears.
 */
export async function dismissOperationsAlert(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  alertId: string,
  actorId: string,
): Promise<void> {
  await client.queryObject(
    `INSERT INTO operations_hub_item_actions
       (organization_id, school_id, item_type, item_id, item_action, actor_id, occurrence_date)
     VALUES ($1, $2, 'alert', $3, 'dismissed', $4, CURRENT_DATE)
     ON CONFLICT (organization_id, school_id, item_type, item_id, occurrence_date)
     DO UPDATE SET actor_id = EXCLUDED.actor_id, created_at = timezone('utc', now())`,
    [organizationId, schoolId, alertId, actorId],
  );
}

/** Persists a completion of a pending action — same day-scoped semantics as dismiss. */
export async function completeOperationsAction(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  actionId: string,
  actorId: string,
): Promise<void> {
  await client.queryObject(
    `INSERT INTO operations_hub_item_actions
       (organization_id, school_id, item_type, item_id, item_action, actor_id, occurrence_date)
     VALUES ($1, $2, 'action', $3, 'completed', $4, CURRENT_DATE)
     ON CONFLICT (organization_id, school_id, item_type, item_id, occurrence_date)
     DO UPDATE SET actor_id = EXCLUDED.actor_id, created_at = timezone('utc', now())`,
    [organizationId, schoolId, actionId, actorId],
  );
}

export interface OperationsHubSnapshot {
  schoolHealth: number;
  dailySummary: {
    attendancePct: number;
    collectionsToday: number;
    communicationsToday: number;
    criticalAlerts: number;
  };
  criticalAlerts: Array<{ id: string; module: string; title: string; severity: string }>;
  pendingActions: Array<{ id: string; module: string; title: string }>;
  widgets: {
    todayAttendance: { present: number; absent: number; total: number };
    todayCollections: { amount: number; count: number };
    todayCommunications: { sent: number; pending: number };
    studentRiskAlerts: number;
    employeeRiskAlerts: number;
    inventoryAlerts: number;
    feeAlerts: number;
  };
}

export async function buildOperationsHub(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<OperationsHubSnapshot> {
  const [
    attendance,
    collections,
    communications,
    studentRisks,
    employeeRisks,
    inventory,
    feeAlerts,
    todaysItemActions,
  ] = await Promise.all([
    client.queryObject<
      { present: number; absent: number; total: number; attendance_pct: number | null }
    >(
      // attendance_records has no date column of its own; the date lives on the
      // parent attendance_sessions row (session_date). Join through session_id —
      // the previous `recorded_on = CURRENT_DATE` referenced a non-existent
      // column and 500'd the whole operations hub / widgets data endpoint.
      // attendance_pct uses the ONE canonical formula (attendance_percentage.ts):
      // attended = present+late+0.5*half_day; denominator = total − excused.
      `SELECT
       count(*) FILTER (WHERE ar.mark = 'present')::int AS present,
       count(*) FILTER (WHERE ar.mark = 'absent')::int AS absent,
       count(*)::int AS total,
       ${attendancePercentSql("ar.mark")} AS attendance_pct
     FROM attendance_records ar
     JOIN attendance_sessions s
       ON s.id = ar.session_id
      AND s.organization_id = ar.organization_id
      AND s.school_id = ar.school_id
     WHERE ar.organization_id = $1 AND ar.school_id = $2
       AND s.session_date = CURRENT_DATE`,
      [organizationId, schoolId],
    ),
    client.queryObject<{ amount: number; count: number }>(
      `SELECT coalesce(sum(amount), 0)::float AS amount, count(*)::int AS count
     FROM finance_receipts
     WHERE organization_id = $1 AND school_id = $2
       AND created_at::date = CURRENT_DATE`,
      [organizationId, schoolId],
    ),
    client.queryObject<{ sent: number; pending: number }>(
      `SELECT
       count(*)::int AS sent,
       0::int AS pending
     FROM intel_communication_drafts
     WHERE organization_id = $1 AND school_id = $2
       AND created_at::date = CURRENT_DATE`,
      [organizationId, schoolId],
    ),
    client.queryObject<{ count: number }>(
      `SELECT count(*)::int AS count FROM intel_student_risk_snapshots
     WHERE organization_id = $1 AND school_id = $2
       AND risk_level IN ('high', 'critical')
       AND computed_at >= CURRENT_DATE - interval '7 days'`,
      [organizationId, schoolId],
    ),
    client.queryObject<{ count: number }>(
      `SELECT count(*)::int AS count FROM employee_intelligence_snapshots
     WHERE organization_id = $1 AND school_id = $2
       AND burnout_risk IN ('high', 'critical')
       AND computed_at >= CURRENT_DATE - interval '7 days'`,
      [organizationId, schoolId],
    ),
    buildDistributionDashboard(client),
    client.queryObject<{ count: number }>(
      `SELECT count(*)::int AS count FROM payment_requests
     WHERE organization_id = $1 AND school_id = $2
       AND status IN ('pending', 'overdue')`,
      [organizationId, schoolId],
    ),
    fetchTodaysItemActions(client, organizationId, schoolId),
  ]);

  const att = attendance[0] ?? { present: 0, absent: 0, total: 0, attendance_pct: null };
  // Canonical attendance-% from the shared SQL (null when no gradable marks); this KPI
  // shows 0 for a no-data day, matching prior dashboard behaviour.
  const attendancePct = att.attendance_pct ?? 0;
  const criticalCount =
    (studentRisks[0]?.count ?? 0) +
    (employeeRisks[0]?.count ?? 0) +
    inventory.replacementRequests +
    (feeAlerts[0]?.count ?? 0);

  const schoolHealth = Math.max(
    0,
    Math.min(
      100,
      Math.round(
        attendancePct * 0.3 +
          (100 - Math.min(100, criticalCount * 5)) * 0.4 +
          (collections[0]?.count ? 80 : 60) * 0.3,
      ),
    ),
  );

  // Gap-remediation #6 — an alert/action dismissed/completed TODAY is filtered
  // back out here so the client's dismiss/complete buttons actually make the
  // item disappear (previously 404'd and were a no-op forever).
  const { dismissedAlertIds, completedActionIds } = todaysItemActions;

  const criticalAlerts: OperationsHubSnapshot["criticalAlerts"] = [];
  if ((studentRisks[0]?.count ?? 0) > 0 && !dismissedAlertIds.has("student-risk")) {
    criticalAlerts.push({
      id: "student-risk",
      module: "intelligence",
      title: `${studentRisks[0]!.count} high-risk students`,
      severity: "high",
    });
  }
  if (inventory.replacementRequests > 0 && !dismissedAlertIds.has("inventory-replacement")) {
    criticalAlerts.push({
      id: "inventory-replacement",
      module: "inventory",
      title: `${inventory.replacementRequests} replacement requests`,
      severity: "medium",
    });
  }
  if ((feeAlerts[0]?.count ?? 0) > 0 && !dismissedAlertIds.has("fee-alerts")) {
    criticalAlerts.push({
      id: "fee-alerts",
      module: "finance",
      title: `${feeAlerts[0]!.count} pending fee requests`,
      severity: "medium",
    });
  }

  const pendingActions: OperationsHubSnapshot["pendingActions"] = [];
  if (inventory.pendingDistributions > 0 && !completedActionIds.has("inv-pending")) {
    pendingActions.push({
      id: "inv-pending",
      module: "inventory",
      title: `${inventory.pendingDistributions} distributions pending`,
    });
  }
  if (inventory.paymentPending > 0 && !completedActionIds.has("inv-payment")) {
    pendingActions.push({
      id: "inv-payment",
      module: "inventory",
      title: `${inventory.paymentPending} replacement payments pending`,
    });
  }

  return {
    schoolHealth,
    dailySummary: {
      attendancePct,
      collectionsToday: collections[0]?.amount ?? 0,
      communicationsToday: communications[0]?.sent ?? 0,
      criticalAlerts: criticalCount,
    },
    criticalAlerts,
    pendingActions,
    widgets: {
      todayAttendance: att,
      todayCollections: {
        amount: collections[0]?.amount ?? 0,
        count: collections[0]?.count ?? 0,
      },
      todayCommunications: {
        sent: communications[0]?.sent ?? 0,
        pending: communications[0]?.pending ?? 0,
      },
      studentRiskAlerts: studentRisks[0]?.count ?? 0,
      employeeRiskAlerts: employeeRisks[0]?.count ?? 0,
      inventoryAlerts: inventory.replacementRequests + inventory.pendingDistributions,
      feeAlerts: feeAlerts[0]?.count ?? 0,
    },
  };
}
