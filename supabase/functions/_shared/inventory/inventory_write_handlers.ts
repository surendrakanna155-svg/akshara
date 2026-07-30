import type { AppConfig } from "../config.ts";
import {
  createModuleWriteHandlers,
  intOr,
  requireStr,
  str,
  WriteNotFoundError,
  WriteValidationError,
} from "../entity_write/module_write_handlers.ts";
import { createEntityWriteStore } from "../entity_write/entity_write_store.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";

// PRA-P1-39 — the inventory asset register was 100% read-only: the router
// hard-rejected every non-GET method and there was no write handler at all.
// These handlers give the register the same write surface every other
// entity-store module has (mirrors transport_write_handlers.ts): create/update
// an asset, create a category, allocate an asset, and record a maintenance
// entry — each an `inventory_entities` row keyed by (entity_type, id) so the
// matching GET reads it back unchanged, and each audited via emitMutationAudit.
// No migration: `inventory_entities` already exists (migration 20260614200000).

const writeStore = createEntityWriteStore("inventory_entities", "Inventory");
const { runWrite } = createModuleWriteHandlers("manageInventory");

/** Extracts the `{id}` path segment for id-bearing routes (e.g. /inventory/assets/{id}). */
function pathSegment(req: Request, index: number): string | undefined {
  const segments = new URL(req.url).pathname.split("/").filter((s) => s.length > 0);
  return segments[index];
}

/** Normalized asset-tag key for per-school asset uniqueness. */
export function assetTagKey(value: string): string {
  return value.trim().toUpperCase();
}

/** POST /inventory/assets — register an asset (unique asset tag per school). */
export async function handleCreateAsset(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const assetTag = requireStr(body, "assetTag", "asset_tag", "tag");
    // Asset tag is the natural key operators scan; a duplicate would collide two
    // physical assets onto one register row. Reject a normalized duplicate.
    const existing = await writeStore.findAll(db, organizationId, schoolId, "asset");
    if (existing.some((a) => assetTagKey(String(a.assetTag ?? "")) === assetTagKey(assetTag))) {
      throw new WriteValidationError(
        `An asset with tag ${assetTag} already exists`,
        409,
        "DUPLICATE_ASSET_TAG",
      );
    }
    const id = str(body, "id") ?? crypto.randomUUID();
    const payload = {
      id,
      assetTag,
      name: requireStr(body, "name"),
      category: str(body, "category") ?? "",
      location: str(body, "location") ?? "",
      purchaseDate: str(body, "purchaseDate", "purchase_date") ?? "",
      value: str(body, "value") ?? "",
      status: str(body, "status") ?? "available",
      assignedTo: str(body, "assignedTo", "assigned_to") ?? null,
      financeAssetId: str(body, "financeAssetId", "finance_asset_id") ?? "",
      lastAudit: str(body, "lastAudit", "last_audit") ?? "",
    };
    const saved = await writeStore.insert(db, organizationId, schoolId, "asset", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("inventory.asset.created", "inventory_asset", id, { assetTag }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}

/** PUT /inventory/assets/{id} — update an asset (asset tag stays unique). */
export async function handleUpdateAsset(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = pathSegment(request, 2);
    if (!id) throw new WriteNotFoundError("Asset id is required");
    const current = await writeStore.find(db, organizationId, schoolId, "asset", id);
    if (!current) throw new WriteNotFoundError(`Inventory asset not found: ${id}`);

    const next = { ...current };
    const assetTag = str(body, "assetTag", "asset_tag", "tag");
    if (assetTag !== undefined) {
      const all = await writeStore.findAll(db, organizationId, schoolId, "asset");
      if (
        all.some((a) =>
          String(a.id ?? "") !== id && assetTagKey(String(a.assetTag ?? "")) === assetTagKey(assetTag)
        )
      ) {
        throw new WriteValidationError(
          `An asset with tag ${assetTag} already exists`,
          409,
          "DUPLICATE_ASSET_TAG",
        );
      }
      next.assetTag = assetTag;
    }
    if (str(body, "name") !== undefined) next.name = str(body, "name");
    if (str(body, "category") !== undefined) next.category = str(body, "category");
    if (str(body, "location") !== undefined) next.location = str(body, "location");
    if (str(body, "purchaseDate", "purchase_date") !== undefined) {
      next.purchaseDate = str(body, "purchaseDate", "purchase_date");
    }
    if (str(body, "value") !== undefined) next.value = str(body, "value");
    if (str(body, "status") !== undefined) next.status = str(body, "status");
    if (str(body, "assignedTo", "assigned_to") !== undefined) {
      next.assignedTo = str(body, "assignedTo", "assigned_to");
    }
    if (str(body, "financeAssetId", "finance_asset_id") !== undefined) {
      next.financeAssetId = str(body, "financeAssetId", "finance_asset_id");
    }
    if (str(body, "lastAudit", "last_audit") !== undefined) {
      next.lastAudit = str(body, "lastAudit", "last_audit");
    }
    const saved = await writeStore.replace(db, organizationId, schoolId, "asset", id, next);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("inventory.asset.updated", "inventory_asset", id, {}),
      request,
    );
    return { payload: saved ?? next, status: 200 };
  });
}

/** POST /inventory/categories — create an asset category. */
export async function handleCreateCategory(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = str(body, "id") ?? crypto.randomUUID();
    const payload = {
      id,
      name: requireStr(body, "name"),
      type: str(body, "type") ?? "equipment",
      assetCount: intOr(body, 0, "assetCount", "asset_count"),
      totalValue: str(body, "totalValue", "total_value") ?? "",
      depreciationRate: str(body, "depreciationRate", "depreciation_rate") ?? "",
      responsibleDept: str(body, "responsibleDept", "responsible_dept") ?? "",
      description: str(body, "description") ?? "",
    };
    const saved = await writeStore.insert(db, organizationId, schoolId, "category", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("inventory.category.created", "inventory_category", id, {
        name: payload.name,
      }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}

/** POST /inventory/allocations — allocate an asset to a person / department. */
export async function handleCreateAllocation(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = str(body, "id", "allocationId", "allocation_id") ?? crypto.randomUUID();
    const payload = {
      id,
      assetTag: str(body, "assetTag", "asset_tag") ?? "",
      assetName: str(body, "assetName", "asset_name") ?? "",
      department: str(body, "department") ?? "",
      assignedTo: requireStr(body, "assignedTo", "assigned_to"),
      assignedDate: str(body, "assignedDate", "assigned_date") ?? "",
      returnDue: str(body, "returnDue", "return_due") ?? "",
      status: str(body, "status") ?? "active",
      hrEmployeeId: str(body, "hrEmployeeId", "hr_employee_id") ?? null,
      hostelBlock: str(body, "hostelBlock", "hostel_block") ?? null,
      librarySection: str(body, "librarySection", "library_section") ?? null,
      integrationNote: str(body, "integrationNote", "integration_note") ?? "",
    };
    const existing = await writeStore.find(db, organizationId, schoolId, "allocation", id);
    const saved = existing
      ? (await writeStore.replace(db, organizationId, schoolId, "allocation", id, payload)) ?? payload
      : await writeStore.insert(db, organizationId, schoolId, "allocation", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("inventory.allocation.created", "inventory_allocation", id, {
        assetTag: payload.assetTag,
        assignedTo: payload.assignedTo,
      }),
      request,
    );
    return { payload: saved, status: existing ? 200 : 201 };
  });
}

/** POST /inventory/maintenance — record (or update) a maintenance entry. */
export async function handleRecordMaintenance(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = str(body, "id", "maintenanceId", "maintenance_id") ?? crypto.randomUUID();
    const payload = {
      id,
      assetTag: str(body, "assetTag", "asset_tag") ?? "",
      assetName: str(body, "assetName", "asset_name") ?? "",
      maintenanceType: str(body, "maintenanceType", "maintenance_type") ?? "",
      scheduledDate: str(body, "scheduledDate", "scheduled_date") ?? "",
      technician: str(body, "technician") ?? "",
      hrTechnicianId: str(body, "hrTechnicianId", "hr_technician_id") ?? "",
      estimatedCost: str(body, "estimatedCost", "estimated_cost") ?? "",
      status: str(body, "status") ?? "scheduled",
      financeBudgetCode: str(body, "financeBudgetCode", "finance_budget_code") ?? "",
    };
    const existing = await writeStore.find(db, organizationId, schoolId, "maintenance", id);
    const saved = existing
      ? (await writeStore.replace(db, organizationId, schoolId, "maintenance", id, payload)) ?? payload
      : await writeStore.insert(db, organizationId, schoolId, "maintenance", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("inventory.maintenance.recorded", "inventory_maintenance", id, {
        assetTag: payload.assetTag,
        status: payload.status,
      }),
      request,
    );
    return { payload: saved, status: existing ? 200 : 201 };
  });
}
