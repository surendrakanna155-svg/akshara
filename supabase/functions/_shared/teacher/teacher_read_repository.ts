import { createEntityReadStore } from "../entity_read/entity_read_store.ts";

export const TEACHER_PROBE_SCHOOL_A = "bj000000-0000-4000-8000-000000000001";
export const TEACHER_PROBE_SCHOOL_B = "bj000000-0000-4000-8000-000000000002";

export const teacherStore = createEntityReadStore("teacher_entities", "Teacher");

export const TEACHER_PROBE_DETAIL_SQL = teacherStore.detailProbeSql("probe");
