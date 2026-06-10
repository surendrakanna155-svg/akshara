import { createEntityReadStore } from "../entity_read/entity_read_store.ts";

export const MANAGEMENT_PROBE_SCHOOL_A = "bg000000-0000-4000-8000-000000000001";
export const MANAGEMENT_PROBE_SCHOOL_B = "bg000000-0000-4000-8000-000000000002";

export const managementStore = createEntityReadStore("management_entities", "Management");

export const getSnapshot = managementStore.getSnapshot;
export const listEntities = managementStore.listEntities;
export const ManagementSnapshotNotFoundError = managementStore.SnapshotNotFoundError;

export const MANAGEMENT_PROBE_DETAIL_SQL = managementStore.detailProbeSql("probe");
