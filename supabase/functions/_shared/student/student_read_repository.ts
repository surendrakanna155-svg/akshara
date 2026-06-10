import { createStudentScopedEntityReadStore } from "../entity_read/student_scoped_entity_read_store.ts";

export const STUDENT_PROBE_SCHOOL_A = "bi000000-0000-4000-8000-000000000001";
export const STUDENT_PROBE_SCHOOL_B = "bi000000-0000-4000-8000-000000000002";

export const studentStore = createStudentScopedEntityReadStore(
  "student_entities",
  "Student",
);

export const STUDENT_PROBE_DETAIL_SQL = studentStore.detailProbeSql("probe");
