import type { TenantQueryClient } from "../tenant_db.ts";
import { buildDistributionDashboard } from "../inventory_distribution/inventory_distribution_repository.ts";

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
  ] = await Promise.all([
    client.queryObject<{ present: number; absent: number; total: number }>(
      `SELECT
       count(*) FILTER (WHERE mark = 'present')::int AS present,
       count(*) FILTER (WHERE mark = 'absent')::int AS absent,
       count(*)::int AS total
     FROM attendance_records
     WHERE organization_id = $1 AND school_id = $2
       AND recorded_on = CURRENT_DATE`,
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
  ]);

  const att = attendance[0] ?? { present: 0, absent: 0, total: 0 };
  const attendancePct = att.total > 0 ? Math.round((att.present / att.total) * 100) : 0;
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

  const criticalAlerts: OperationsHubSnapshot["criticalAlerts"] = [];
  if ((studentRisks[0]?.count ?? 0) > 0) {
    criticalAlerts.push({
      id: "student-risk",
      module: "intelligence",
      title: `${studentRisks[0]!.count} high-risk students`,
      severity: "high",
    });
  }
  if (inventory.replacementRequests > 0) {
    criticalAlerts.push({
      id: "inventory-replacement",
      module: "inventory",
      title: `${inventory.replacementRequests} replacement requests`,
      severity: "medium",
    });
  }
  if ((feeAlerts[0]?.count ?? 0) > 0) {
    criticalAlerts.push({
      id: "fee-alerts",
      module: "finance",
      title: `${feeAlerts[0]!.count} pending fee requests`,
      severity: "medium",
    });
  }

  const pendingActions: OperationsHubSnapshot["pendingActions"] = [];
  if (inventory.pendingDistributions > 0) {
    pendingActions.push({
      id: "inv-pending",
      module: "inventory",
      title: `${inventory.pendingDistributions} distributions pending`,
    });
  }
  if (inventory.paymentPending > 0) {
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
