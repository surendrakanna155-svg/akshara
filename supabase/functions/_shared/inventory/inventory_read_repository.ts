import { createEntityReadStore } from "../entity_read/entity_read_store.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

export const INVENTORY_ASSET_SCHOOL_A = "bf200000-0000-4000-8000-000000000001";
export const INVENTORY_ASSET_SCHOOL_B = "bf200000-0000-4000-8000-000000000002";

export const inventoryStore = createEntityReadStore("inventory_entities", "Inventory");

export const getSnapshot = inventoryStore.getSnapshot;
export const listEntities = inventoryStore.listEntities;
export const getEntity = inventoryStore.getEntity;
export const InventorySnapshotNotFoundError = inventoryStore.SnapshotNotFoundError;
export const InventoryEntityNotFoundError = inventoryStore.EntityNotFoundError;

export const INVENTORY_ENTITIES_PROBE_SQL = inventoryStore.entitiesProbeSql;
export const INVENTORY_ASSETS_API_PROBE_SQL = inventoryStore.listApiProbeSql("asset");
export const INVENTORY_ASSET_DETAIL_PROBE_SQL = inventoryStore.detailProbeSql("asset");

export interface ProcurementWorkflowAdvanceRow {
  id: string;
  status: string;
  po_number: string;
}

/**
 * Advance a purchase order to its next procurement-workflow status
 * (draft -> approved -> partially_received), stamping approver metadata on
 * the draft -> approved transition. Returns the raw RETURNING rows (empty
 * when the purchase order id did not match any row in this tenant scope) so
 * the caller decides how to react to a not-found id.
 */
export async function advanceProcurementWorkflowStatus(
  db: TenantQueryClient,
  purchaseOrderId: string,
  organizationId: string,
  schoolId: string,
  approvedBy: string | null,
): Promise<ProcurementWorkflowAdvanceRow[]> {
  return await db.queryObject<ProcurementWorkflowAdvanceRow>(
    `UPDATE purchase_orders
     SET status = CASE
       WHEN status = 'draft' THEN 'approved'
       WHEN status = 'approved' THEN 'partially_received'
       ELSE status
     END,
     approved_by = CASE WHEN status = 'draft' THEN $4::uuid ELSE approved_by END,
     approved_at = CASE WHEN status = 'draft' THEN timezone('utc', now()) ELSE approved_at END,
     updated_at = timezone('utc', now())
     WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3
     RETURNING id, status, po_number`,
    [purchaseOrderId, organizationId, schoolId, approvedBy],
  );
}
