import { createStudentScopedEntityReadStore } from "../entity_read/student_scoped_entity_read_store.ts";

export const PARENT_PROBE_SCHOOL_A = "bh000000-0000-4000-8000-000000000001";
export const PARENT_PROBE_SCHOOL_B = "bh000000-0000-4000-8000-000000000002";

export const parentStore = createStudentScopedEntityReadStore(
  "parent_entities",
  "Parent",
);

export const PARENT_PROBE_DETAIL_SQL = parentStore.detailProbeSql("probe");
