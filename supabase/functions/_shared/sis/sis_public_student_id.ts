// NIKSHA Identity Platform — Public Student ID (PSID) allocation.
//
// PSID = `<SCHOOL_CODE>-<RUNNING_NUMBER>`, RUNNING_NUMBER a 4-digit zero-padded,
// PER-SCHOOL sequential value that is NEVER reused (e.g. DPSKKP-0001). See
// migration 20260848000000_public_student_id.sql for the schema, backfill, and
// the set-once immutability trigger.
//
// Allocation is concurrency-safe. The counter row's next_seq is advanced with a
// single atomic INSERT ... ON CONFLICT DO UPDATE, whose row-level lock serializes
// concurrent allocations for the same (org, school): two racing callers each get
// a DISTINCT number with no gaps. The FIRST student for a school is 0001.

/** Structural DB seam — matches TenantQueryClient's queryObject, unit-testable. */
export interface PublicIdDb {
  queryObject<T>(sql: string, args?: unknown[]): Promise<T[]>;
}

const PSID_PAD = 4;

export class SchoolCodeMissingError extends Error {
  constructor(schoolId: string) {
    super(
      `Cannot allocate a public student id: school ${schoolId} has no code. ` +
        `Set schools.code (globally unique, set-once) before enrolling students.`,
    );
    this.name = "SchoolCodeMissingError";
  }
}

/** Zero-pads a running number to the PSID width (e.g. 1 -> "0001"). */
export function formatPublicStudentId(schoolCode: string, seq: number): string {
  return `${schoolCode}-${String(seq).padStart(PSID_PAD, "0")}`;
}

/**
 * Atomically allocates the next PSID for a school and returns the formatted
 * value. Never reused, never gapped, safe under concurrency.
 *
 * The counter arithmetic (proven in tests):
 *   - FIRST allocation: the INSERT lands `next_seq = 2`, so RETURNING
 *     `next_seq - 1` = 1 -> "0001". The stored counter now points at the NEXT
 *     value (2).
 *   - SUBSEQUENT allocation: ON CONFLICT sets `next_seq = next_seq + 1` and
 *     RETURNS the value BEFORE the increment (`next_seq - 1` evaluated against
 *     the post-update row = the pre-update value). So the 2nd caller gets 2 ->
 *     "0002", the 3rd gets 3, and so on — no duplicates, no gaps.
 * The ON CONFLICT DO UPDATE takes a row-level lock on the counter, serializing
 * concurrent allocations for the same (org, school).
 */
export async function allocatePublicStudentId(
  db: PublicIdDb,
  organizationId: string,
  schoolId: string,
): Promise<string> {
  const codeRows = await db.queryObject<{ code: string | null }>(
    `SELECT code FROM schools WHERE id = $1 AND organization_id = $2`,
    [schoolId, organizationId],
  );
  const schoolCode = codeRows[0]?.code?.trim();
  if (!schoolCode) {
    throw new SchoolCodeMissingError(schoolId);
  }

  // First insert lands next_seq = 2 and returns 2 - 1 = 1. On conflict we bump
  // next_seq by one and return the value BEFORE the bump (post-update next_seq
  // minus 1 == the pre-update next_seq). Row-level lock from DO UPDATE serializes
  // concurrent callers.
  const allocRows = await db.queryObject<{ allocated: number }>(
    `INSERT INTO school_public_id_counters (organization_id, school_id, next_seq)
     VALUES ($1, $2, 2)
     ON CONFLICT (organization_id, school_id) DO UPDATE
       SET next_seq = school_public_id_counters.next_seq + 1
     RETURNING (school_public_id_counters.next_seq - 1) AS allocated`,
    [organizationId, schoolId],
  );
  const allocated = allocRows[0]?.allocated;
  if (allocated == null) {
    throw new Error(
      `Public student id allocation returned no counter value for school ${schoolId}`,
    );
  }

  return formatPublicStudentId(schoolCode, Number(allocated));
}
