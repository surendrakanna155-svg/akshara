import type { TenantQueryClient } from "../tenant_db.ts";

export type AssetLifecycleEventType =
  | "purchase"
  | "distribution"
  | "replacement"
  | "damage"
  | "retirement";

export interface LowStockPrediction {
  sku: string;
  itemName: string;
  currentStock: number;
  predictedDaysUntilStockout: number;
  riskScore: number;
}

export interface ReorderRecommendation {
  id: string;
  sku: string;
  itemName: string;
  recommendedQuantity: number;
  urgency: "low" | "medium" | "high";
  reason: string;
}

export interface StockTrendPoint {
  month: string;
  consumption: number;
  forecast: number;
}

export interface InventoryRiskAlert {
  id: string;
  severity: "low" | "medium" | "high";
  title: string;
  detail: string;
}

export interface InventoryCopilotSnapshot {
  stockForecastUnits: number;
  forecastConfidence: number;
  lowStockPredictions: LowStockPrediction[];
  reorderRecommendations: ReorderRecommendation[];
  stockTrend: StockTrendPoint[];
  riskAlerts: InventoryRiskAlert[];
  generatedAt: string;
}

export interface AssetLifecycleEvent {
  id: string;
  assetId: string;
  assetTag: string;
  eventType: AssetLifecycleEventType;
  notes: string;
  recordedAt: string;
  recordedBy: string | null;
}

export interface AssetLifecycleSnapshot {
  recentEvents: AssetLifecycleEvent[];
  eventCounts: Record<AssetLifecycleEventType, number>;
  assetsTracked: number;
  generatedAt: string;
}

export interface ProcurementWorkflowAlert {
  id: string;
  poNumber: string;
  severity: "low" | "medium" | "high";
  title: string;
  detail: string;
}

export interface ProcurementWorkflowRecommendation {
  id: string;
  poNumber: string;
  action: string;
  priority: "low" | "medium" | "high";
}

export interface ProcurementWorkflowSnapshot {
  pendingApprovals: number;
  overdueDeliveries: number;
  alerts: ProcurementWorkflowAlert[];
  recommendations: ProcurementWorkflowRecommendation[];
  generatedAt: string;
}

export interface RecordLifecycleEventInput {
  assetId: string;
  assetTag?: string;
  eventType: AssetLifecycleEventType;
  notes?: string;
  metadata?: Record<string, unknown>;
}

function monthKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

export async function computeInventoryCopilot(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<InventoryCopilotSnapshot> {
  const stockRows = await db.queryObject<{
    sku: string;
    quantity_on_hand: string;
    weighted_avg_cost: string;
  }>(
    `SELECT sku, quantity_on_hand::text, weighted_avg_cost::text
     FROM inventory_stock_valuations
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY quantity_on_hand ASC
     LIMIT 50`,
    [orgId, schoolId],
  );

  const consumptionRows = await db.queryObject<{ month: string; qty: string }>(
    `SELECT to_char(date_trunc('month', received_at), 'YYYY-MM') AS month,
            COALESCE(SUM(grl.quantity_received), 0)::text AS qty
     FROM goods_receipt_lines grl
     JOIN goods_receipts gr ON gr.id = grl.goods_receipt_id
     WHERE grl.organization_id = $1 AND grl.school_id = $2
       AND gr.received_at >= (CURRENT_DATE - INTERVAL '6 months')
     GROUP BY 1
     ORDER BY 1`,
    [orgId, schoolId],
  );

  const stockTrend: StockTrendPoint[] = consumptionRows.map((r) => {
    const consumption = parseInt(r.qty, 10) || 0;
    return { month: r.month, consumption, forecast: Math.round(consumption * 1.1) };
  });

  const avgMonthly = stockTrend.length
    ? stockTrend.reduce((s, p) => s + p.consumption, 0) / stockTrend.length
    : 0;
  const stockForecastUnits = Math.round(avgMonthly * 1.12);
  const forecastConfidence = stockTrend.length >= 3 ? 84 : 61;

  const lowStockPredictions: LowStockPrediction[] = stockRows
    .filter((r) => parseInt(r.quantity_on_hand, 10) <= 20)
    .slice(0, 15)
    .map((r) => {
      const currentStock = parseInt(r.quantity_on_hand, 10) || 0;
      const predictedDays = currentStock <= 0 ? 0 : Math.max(1, Math.round(currentStock / Math.max(avgMonthly / 30, 0.5)));
      const riskScore = Math.min(100, Math.round(50 + (20 - currentStock) * 3));
      return {
        sku: r.sku,
        itemName: r.sku,
        currentStock,
        predictedDaysUntilStockout: predictedDays,
        riskScore,
      };
    });

  const reorderRecommendations: ReorderRecommendation[] = lowStockPredictions
    .filter((p) => p.riskScore >= 55)
    .map((p, i) => ({
      id: `reorder_${i + 1}`,
      sku: p.sku,
      itemName: p.itemName,
      recommendedQuantity: Math.max(10, Math.round(avgMonthly * 0.5) || 20),
      urgency: p.riskScore >= 80 ? "high" as const : p.riskScore >= 65 ? "medium" as const : "low" as const,
      reason: `Stock at ${p.currentStock} units; projected stockout in ${p.predictedDaysUntilStockout} days`,
    }));

  const riskAlerts: InventoryRiskAlert[] = [];
  const critical = lowStockPredictions.filter((p) => p.riskScore >= 75);
  if (critical.length > 0) {
    riskAlerts.push({
      id: "alert_low_stock",
      severity: "high",
      title: `${critical.length} SKUs at critical stock levels`,
      detail: "Review reorder recommendations and raise purchase orders",
    });
  }
  if (stockTrend.length >= 2) {
    const prev = stockTrend.at(-2)!.consumption;
    const curr = stockTrend.at(-1)!.consumption;
    if (curr > prev * 1.25) {
      riskAlerts.push({
        id: "alert_consumption_spike",
        severity: "medium",
        title: "Consumption spike detected",
        detail: `Last month ${Math.round((curr / prev - 1) * 100)}% above prior month`,
      });
    }
  }

  return {
    stockForecastUnits,
    forecastConfidence,
    lowStockPredictions,
    reorderRecommendations,
    stockTrend,
    riskAlerts,
    generatedAt: new Date().toISOString(),
  };
}

export async function computeAssetLifecycle(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<AssetLifecycleSnapshot> {
  const eventRows = await db.queryObject<{
    id: string;
    asset_id: string;
    asset_tag: string;
    event_type: AssetLifecycleEventType;
    notes: string;
    recorded_at: string;
    recorded_by: string | null;
  }>(
    `SELECT id, asset_id, asset_tag, event_type, notes,
            recorded_at::text, recorded_by::text
     FROM asset_lifecycle_events
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY recorded_at DESC
     LIMIT 50`,
    [orgId, schoolId],
  );

  const countRows = await db.queryObject<{ event_type: AssetLifecycleEventType; cnt: string }>(
    `SELECT event_type, COUNT(*)::text AS cnt
     FROM asset_lifecycle_events
     WHERE organization_id = $1 AND school_id = $2
     GROUP BY event_type`,
    [orgId, schoolId],
  );

  const assetCountRows = await db.queryObject<{ cnt: string }>(
    `SELECT COUNT(DISTINCT asset_id)::text AS cnt
     FROM asset_lifecycle_events
     WHERE organization_id = $1 AND school_id = $2`,
    [orgId, schoolId],
  );

  const eventCounts: Record<AssetLifecycleEventType, number> = {
    purchase: 0,
    distribution: 0,
    replacement: 0,
    damage: 0,
    retirement: 0,
  };
  for (const row of countRows) {
    eventCounts[row.event_type] = parseInt(row.cnt, 10) || 0;
  }

  return {
    recentEvents: eventRows.map((r) => ({
      id: r.id,
      assetId: r.asset_id,
      assetTag: r.asset_tag,
      eventType: r.event_type,
      notes: r.notes,
      recordedAt: r.recorded_at,
      recordedBy: r.recorded_by,
    })),
    eventCounts,
    assetsTracked: parseInt(assetCountRows[0]?.cnt ?? "0", 10) || 0,
    generatedAt: new Date().toISOString(),
  };
}

export async function recordAssetLifecycleEvent(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  userId: string | null,
  input: RecordLifecycleEventInput,
): Promise<AssetLifecycleEvent> {
  const rows = await db.queryObject<{
    id: string;
    asset_id: string;
    asset_tag: string;
    event_type: AssetLifecycleEventType;
    notes: string;
    recorded_at: string;
    recorded_by: string | null;
  }>(
    `INSERT INTO asset_lifecycle_events (
       organization_id, school_id, asset_id, asset_tag, event_type, notes, metadata, recorded_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8)
     RETURNING id, asset_id, asset_tag, event_type, notes, recorded_at::text, recorded_by::text`,
    [
      orgId,
      schoolId,
      input.assetId,
      input.assetTag ?? "",
      input.eventType,
      input.notes ?? "",
      JSON.stringify(input.metadata ?? {}),
      userId,
    ],
  );

  const row = rows[0]!;
  return {
    id: row.id,
    assetId: row.asset_id,
    assetTag: row.asset_tag,
    eventType: row.event_type,
    notes: row.notes,
    recordedAt: row.recorded_at,
    recordedBy: row.recorded_by,
  };
}

export async function computeProcurementWorkflow(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<ProcurementWorkflowSnapshot> {
  const pendingRows = await db.queryObject<{ cnt: string }>(
    `SELECT COUNT(*)::text AS cnt FROM purchase_orders
     WHERE organization_id = $1 AND school_id = $2 AND status = 'draft'`,
    [orgId, schoolId],
  );

  const overdueRows = await db.queryObject<{ cnt: string }>(
    `SELECT COUNT(*)::text AS cnt FROM purchase_orders po
     WHERE po.organization_id = $1 AND po.school_id = $2
       AND po.status IN ('approved', 'partially_received')
       AND po.created_at < (CURRENT_DATE - INTERVAL '30 days')`,
    [orgId, schoolId],
  );

  const draftPoRows = await db.queryObject<{ id: string; po_number: string }>(
    `SELECT id, po_number FROM purchase_orders
     WHERE organization_id = $1 AND school_id = $2 AND status = 'draft'
     ORDER BY created_at ASC LIMIT 10`,
    [orgId, schoolId],
  );

  const alerts: ProcurementWorkflowAlert[] = [];
  const overdueCount = parseInt(overdueRows[0]?.cnt ?? "0", 10) || 0;
  if (overdueCount > 0) {
    alerts.push({
      id: "alert_overdue_po",
      poNumber: "",
      severity: "high",
      title: `${overdueCount} purchase orders overdue for delivery`,
      detail: "Follow up with vendors or escalate to finance",
    });
  }

  const recommendations: ProcurementWorkflowRecommendation[] = draftPoRows.map((po) => ({
    id: `rec_${po.id}`,
    poNumber: po.po_number,
    action: "Approve draft purchase order",
    priority: "medium" as const,
  }));

  return {
    pendingApprovals: parseInt(pendingRows[0]?.cnt ?? "0", 10) || 0,
    overdueDeliveries: overdueCount,
    alerts,
    recommendations,
    generatedAt: new Date().toISOString(),
  };
}

export function computeInventoryCopilotFromSeed(): InventoryCopilotSnapshot {
  return {
    stockForecastUnits: 1240,
    forecastConfidence: 81,
    lowStockPredictions: [
      {
        sku: "LAB-MICRO-001",
        itemName: "Lab Microscope Set",
        currentStock: 4,
        predictedDaysUntilStockout: 12,
        riskScore: 82,
      },
    ],
    reorderRecommendations: [
      {
        id: "reorder_1",
        sku: "LAB-MICRO-001",
        itemName: "Lab Microscope Set",
        recommendedQuantity: 24,
        urgency: "high",
        reason: "Stock at 4 units; projected stockout in 12 days",
      },
    ],
    stockTrend: [
      { month: "2026-01", consumption: 180, forecast: 198 },
      { month: "2026-02", consumption: 210, forecast: 231 },
      { month: "2026-03", consumption: 195, forecast: 215 },
    ],
    riskAlerts: [
      {
        id: "seed_alert",
        severity: "medium",
        title: "3 SKUs below reorder threshold",
        detail: "Review auto-reorder recommendations",
      },
    ],
    generatedAt: new Date().toISOString(),
  };
}
