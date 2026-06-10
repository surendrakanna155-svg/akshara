import { createEntityReadStore } from "../entity_read/entity_read_store.ts";

export const ALUMNI_RECORD_SCHOOL_A = "bf300000-0000-4000-8000-000000000001";
export const ALUMNI_RECORD_SCHOOL_B = "bf300000-0000-4000-8000-000000000002";

export const alumniStore = createEntityReadStore("alumni_entities", "Alumni");

export const getSnapshot = alumniStore.getSnapshot;
export const listEntities = alumniStore.listEntities;
export const getEntity = alumniStore.getEntity;
export const AlumniSnapshotNotFoundError = alumniStore.SnapshotNotFoundError;
export const AlumniEntityNotFoundError = alumniStore.EntityNotFoundError;

export const ALUMNI_ENTITIES_PROBE_SQL = alumniStore.entitiesProbeSql;
export const ALUMNI_REGISTRY_API_PROBE_SQL = alumniStore.listApiProbeSql("alumni");
export const ALUMNI_REGISTRY_DETAIL_PROBE_SQL = alumniStore.detailProbeSql("alumni");

export function alumniDetailToApi(alumni: Record<string, unknown>): Record<string, unknown> {
  const name = String(alumni.name ?? "");
  const batchYear = String(alumni.batchYear ?? "");
  return {
    alumni,
    employmentHistory: [
      {
        organization: "Tech Corp",
        role: String(alumni.currentRole ?? "Professional"),
        period: `${batchYear} — Present`,
      },
    ],
    donationHistory: [],
    mentorshipRole: alumni.engagementStatus === "active" ? "Mentor available" : "Not enrolled",
    eventsAttended: [`Annual Reunion ${batchYear}`],
  };
}
