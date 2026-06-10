import { createEntityReadStore } from "../entity_read/entity_read_store.ts";

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
