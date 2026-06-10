import { createEntityReadStore } from "../entity_read/entity_read_store.ts";

export const HOSTEL_STUDENT_SCHOOL_A = "bf000000-0000-4000-8000-000000000001";
export const HOSTEL_STUDENT_SCHOOL_B = "bf000000-0000-4000-8000-000000000002";

export const hostelStore = createEntityReadStore("hostel_entities", "Hostel");

export const getSnapshot = hostelStore.getSnapshot;
export const listEntities = hostelStore.listEntities;
export const getEntity = hostelStore.getEntity;
export const HostelSnapshotNotFoundError = hostelStore.SnapshotNotFoundError;
export const HostelEntityNotFoundError = hostelStore.EntityNotFoundError;

export const HOSTEL_ENTITIES_PROBE_SQL = hostelStore.entitiesProbeSql;
export const HOSTEL_STUDENTS_API_PROBE_SQL = hostelStore.listApiProbeSql("student");
export const HOSTEL_STUDENT_DETAIL_PROBE_SQL = hostelStore.detailProbeSql("student");
