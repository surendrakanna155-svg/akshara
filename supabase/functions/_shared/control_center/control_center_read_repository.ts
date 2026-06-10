import { createOrgEntityReadStore } from "../entity_read/org_entity_read_store.ts";

export const CONTROL_CENTER_SCHOOL_A = "bg100000-0000-4000-8000-000000000001";
export const CONTROL_CENTER_SCHOOL_B = "bg100000-0000-4000-8000-000000000002";

export const controlCenterStore = createOrgEntityReadStore(
  "control_center_entities",
  "ControlCenter",
);

export const getSnapshot = controlCenterStore.getSnapshot;
export const listEntities = controlCenterStore.listEntities;
export const ControlCenterSnapshotNotFoundError = controlCenterStore.SnapshotNotFoundError;

export const CONTROL_CENTER_SCHOOLS_API_PROBE_SQL = controlCenterStore.listApiProbeSql("school");
export const CONTROL_CENTER_SCHOOL_DETAIL_PROBE_SQL = controlCenterStore.detailProbeSql("school");
