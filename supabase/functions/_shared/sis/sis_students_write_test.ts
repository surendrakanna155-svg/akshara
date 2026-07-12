import { assertEquals, assertRejects, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  assertValidStatusTransition,
  generateStudentCode,
  InvalidStudentStatusTransitionError,
  parseApiStatus,
  statusFromDb,
  statusToDb,
} from "./sis_status_codec.ts";
import {
  AdmissionNumberImmutableError,
  createStudent,
  DuplicateAdmissionNumberError,
  getStudent,
  updateStudent,
  updateStudentStatus,
  ValidationError,
} from "./sis_students_repository.ts";
import { ClearanceDuesBlockedError } from "../clearance/clearance_gate.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";
const STAFF = "a3000000-0000-4000-8000-000000000001";
const STUDENT_A = "a4000000-0000-4000-8000-000000000001";
const STUDENT_B = "a4000000-0000-4000-8000-000000000002";

type Row = Record<string, unknown>;

class WriteMockDb {
  students: Row[] = [];
  profiles: Row[] = [];
  failProfileInsert = false;
  inTransaction = false;
  committedStudents: Row[] = [];
  committedProfiles: Row[] = [];
  updateProfileCalls = 0;
  // PSID plumbing: a per-school code + a counter model for allocatePublicStudentId.
  schoolCode: string | null = "TESTSCH";
  counters = new Map<string, number>();

  beginTransaction() {
    this.inTransaction = true;
    this.students = [...this.committedStudents];
    this.profiles = [...this.committedProfiles];
  }

  commitTransaction() {
    this.committedStudents = [...this.students];
    this.committedProfiles = [...this.profiles];
    this.inTransaction = false;
  }

  rollbackTransaction() {
    this.students = [...this.committedStudents];
    this.profiles = [...this.committedProfiles];
    this.inTransaction = false;
  }

  async queryCount(sql: string, args: unknown[] = []): Promise<number> {
    if (sql.includes("student_profiles") && sql.includes("admission_number")) {
      return this.profiles.filter((row) =>
        row.organization_id === args[0] &&
        row.school_id === args[1] &&
        row.admission_number === args[2] &&
        (args[3] == null || row.student_id !== args[3])
      ).length;
    }
    return 0;
  }

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("SELECT code FROM schools")) {
      return (this.schoolCode === null ? [] : [{ code: this.schoolCode }]) as T[];
    }
    if (sql.includes("INSERT INTO school_public_id_counters")) {
      const key = `${args[0]}|${args[1]}`;
      const current = this.counters.get(key);
      let allocated: number;
      if (current === undefined) {
        this.counters.set(key, 2);
        allocated = 1;
      } else {
        const next = current + 1;
        this.counters.set(key, next);
        allocated = next - 1;
      }
      return [{ allocated }] as T[];
    }
    if (sql.includes("FROM student_profiles") && sql.includes("admission_number = $3")) {
      const matches = this.profiles.filter((row) =>
        row.organization_id === args[0] &&
        row.school_id === args[1] &&
        row.admission_number === args[2] &&
        (args[3] == null || row.student_id !== args[3])
      );
      return matches.slice(0, 1).map((row) => ({ id: row.id })) as T[];
    }
    if (sql.includes("student_code LIKE")) {
      const schoolId = args[0];
      const prefix = String(args[1]).replace("%", "");
      const codes = this.students
        .filter((row) => row.school_id === schoolId && String(row.student_code).startsWith(prefix))
        .map((row) => ({ student_code: row.student_code }));
      return codes.sort((a, b) =>
        String(b.student_code).localeCompare(String(a.student_code))
      ).slice(0, 1) as T[];
    }
    if (sql.includes("INSERT INTO students")) {
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        student_code: args[2],
        display_name: args[3],
        status: args[4],
        created_by: args[5],
        created_at: "2026-06-09T00:00:00.000Z",
        updated_at: "2026-06-09T00:00:00.000Z",
      };
      this.students.push(row);
      return [{ id: row.id }] as T[];
    }
    if (sql.includes("INSERT INTO student_profiles")) {
      if (this.failProfileInsert) {
        throw new Error("forced profile insert failure");
      }
      // Column order (createStudent): organization_id, school_id, student_id,
      // admission_number, public_student_id, date_of_birth, gender, blood_group,
      // address, city, state, postal_code, country, created_by.
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        student_id: args[2],
        admission_number: args[3],
        public_student_id: args[4],
        date_of_birth: args[5],
        gender: args[6],
        blood_group: args[7],
        address: args[8],
        city: args[9],
        state: args[10],
        postal_code: args[11],
        country: args[12],
        created_by: args[13],
        created_at: "2026-06-09T00:00:00.000Z",
        updated_at: "2026-06-09T00:00:00.000Z",
      };
      this.profiles.push(row);
      return [] as T[];
    }
    if (sql.includes("UPDATE students SET")) {
      const student = this.students.find((row) => row.id === args[2] || row.id === args[1]);
      const id = sql.includes("status = $1") ? args[1] : args[2];
      const target = this.students.find((row) => row.id === id);
      if (target) {
        if (sql.includes("display_name = $1")) {
          target.display_name = args[0];
          target.status = args[1];
        } else {
          target.status = args[0];
        }
        target.updated_at = "2026-06-09T12:00:00.000Z";
      }
      return [] as T[];
    }
    if (sql.includes("UPDATE student_profiles SET")) {
      this.updateProfileCalls++;
      const profile = this.profiles.find((row) => row.student_id === args[9]);
      if (profile) {
        profile.admission_number = args[0];
        profile.date_of_birth = args[1];
        profile.gender = args[2];
        profile.updated_at = "2026-06-09T12:00:00.000Z";
      }
      return [] as T[];
    }
    if (sql.includes("FROM students") && sql.includes("WHERE id = $1")) {
      const student = this.students.find((row) =>
        row.id === args[0] &&
        row.organization_id === args[1] &&
        row.school_id === args[2]
      );
      return (student ? [student] : []) as T[];
    }
    if (sql.includes("FROM student_profiles")) {
      const profile = this.profiles.find((row) =>
        row.student_id === args[0] &&
        row.organization_id === args[1] &&
        row.school_id === args[2]
      );
      return (profile ? [profile] : []) as T[];
    }
    if (sql.includes("FROM sis_student_enrollments")) return [] as T[];
    if (sql.includes("FROM student_guardians")) return [] as T[];
    return [] as T[];
  }
}

async function withMockTransaction<T>(
  db: WriteMockDb,
  operation: (client: TenantQueryClient) => Promise<T>,
): Promise<T> {
  db.beginTransaction();
  try {
    const result = await operation(db as unknown as TenantQueryClient);
    db.commitTransaction();
    return result;
  } catch (error) {
    db.rollbackTransaction();
    throw error;
  }
}

function schoolClaims(): AccessTokenClaims {
  return {
    sub: STAFF,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL_A,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: ["manageSis"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "test",
  };
}

Deno.test("generateStudentCode produces sequential STU-YYYY-XXXXX codes", async () => {
  const db = new WriteMockDb();
  db.students.push({
    school_id: SCHOOL_A,
    student_code: "STU-2026-00007",
  });
  const code = await generateStudentCode(db, SCHOOL_A, 2026);
  assertEquals(code, "STU-2026-00008");
});

Deno.test("status codec maps graduated to alumni in database", () => {
  assertEquals(statusToDb("graduated"), "alumni");
  assertEquals(statusFromDb("alumni"), "graduated");
});

Deno.test("status transition rejects terminal to active", () => {
  assertThrows(
    () => assertValidStatusTransition("transferred", "active"),
    InvalidStudentStatusTransitionError,
  );
});

Deno.test("createStudent inserts student and profile", async () => {
  const db = new WriteMockDb();
  const detail = await withMockTransaction(db, (client) =>
    createStudent(client, ORG, SCHOOL_A, {
      displayName: "New Student",
      admissionNumber: "ADM-2026-NEW001",
      gender: "female",
      createdBy: STAFF,
    })
  );

  assertEquals(detail.student.display_name, "New Student");
  assertEquals(detail.profile?.admission_number, "ADM-2026-NEW001");
  assertEquals(db.committedStudents.length, 1);
  assertEquals(db.committedProfiles.length, 1);
  assertEquals(String(db.committedStudents[0]?.student_code).startsWith("STU-2026-"), true);
});

Deno.test("createStudent allocates and sets the Public Student ID (CODE-0001)", async () => {
  const db = new WriteMockDb();
  db.schoolCode = "DPSKKP";
  const detail = await withMockTransaction(db, (client) =>
    createStudent(client, ORG, SCHOOL_A, {
      displayName: "PSID Student",
      admissionNumber: "ADM-PSID-1",
      createdBy: STAFF,
    })
  );
  // The first student of the school gets CODE-0001; it round-trips to the detail.
  assertEquals(db.committedProfiles[0]?.public_student_id, "DPSKKP-0001");
  assertEquals(detail.profile?.public_student_id, "DPSKKP-0001");
});

Deno.test("createStudent fails when the school has no code (PSID precondition)", async () => {
  const db = new WriteMockDb();
  db.schoolCode = null;
  await assertRejects(
    () =>
      withMockTransaction(db, (client) =>
        createStudent(client, ORG, SCHOOL_A, {
          displayName: "No Code Student",
          admissionNumber: "ADM-NOCODE-1",
          createdBy: STAFF,
        })),
  );
  // Nothing is committed — the transaction rolls back cleanly.
  assertEquals(db.committedStudents.length, 0);
  assertEquals(db.committedProfiles.length, 0);
});

Deno.test("createStudent rolls back when profile insert fails", async () => {
  const db = new WriteMockDb();
  db.failProfileInsert = true;
  await assertRejects(
    () => withMockTransaction(db, (client) =>
      createStudent(client, ORG, SCHOOL_A, {
        displayName: "Rollback Student",
        admissionNumber: "ADM-2026-RB001",
        createdBy: STAFF,
      })
    ),
  );
  assertEquals(db.committedStudents.length, 0);
  assertEquals(db.committedProfiles.length, 0);
});

Deno.test("createStudent rejects duplicate admission number", async () => {
  const db = new WriteMockDb();
  db.committedProfiles.push({
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT_A,
    admission_number: "ADM-DUP",
  });
  await assertRejects(
    () => withMockTransaction(db, (client) =>
      createStudent(client, ORG, SCHOOL_A, {
        displayName: "Dup Student",
        admissionNumber: "ADM-DUP",
        createdBy: STAFF,
      })
    ),
    DuplicateAdmissionNumberError,
  );
});

Deno.test("updateStudent updates profile and display name", async () => {
  const db = new WriteMockDb();
  db.committedStudents.push({
    id: STUDENT_A,
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_code: "STU-001",
    display_name: "Old Name",
    status: "active",
    created_at: "2026-06-01T00:00:00.000Z",
    updated_at: "2026-06-01T00:00:00.000Z",
  });
  db.committedProfiles.push({
    id: "profile-a",
    student_id: STUDENT_A,
    organization_id: ORG,
    school_id: SCHOOL_A,
    admission_number: "ADM-001",
    date_of_birth: null,
    gender: "male",
    blood_group: null,
    address: null,
    city: null,
    state: null,
    postal_code: null,
    country: null,
    created_at: "2026-06-01T00:00:00.000Z",
    updated_at: "2026-06-01T00:00:00.000Z",
  });

  const detail = await withMockTransaction(db, (client) =>
    updateStudent(client, ORG, SCHOOL_A, STUDENT_A, {
      displayName: "Updated Name",
      gender: "female",
    })
  );

  assertEquals(detail.student.display_name, "Updated Name");
  assertEquals(detail.profile?.gender, "female");
});

function seedExistingStudent(db: WriteMockDb, admissionNumber = "ADM-001") {
  db.committedStudents.push({
    id: STUDENT_A,
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_code: "STU-001",
    display_name: "Existing",
    status: "active",
    created_at: "2026-06-01T00:00:00.000Z",
    updated_at: "2026-06-01T00:00:00.000Z",
  });
  db.committedProfiles.push({
    id: "profile-a",
    student_id: STUDENT_A,
    organization_id: ORG,
    school_id: SCHOOL_A,
    admission_number: admissionNumber,
    date_of_birth: null,
    gender: "male",
    blood_group: null,
    address: null,
    city: null,
    state: null,
    postal_code: null,
    country: null,
    created_at: "2026-06-01T00:00:00.000Z",
    updated_at: "2026-06-01T00:00:00.000Z",
  });
}

Deno.test("updateStudent rejects changing admission_number (C5 set-once lock)", async () => {
  const db = new WriteMockDb();
  seedExistingStudent(db, "ADM-001");

  const error = await assertRejects(
    () =>
      withMockTransaction(db, (client) =>
        updateStudent(client, ORG, SCHOOL_A, STUDENT_A, { admissionNumber: "ADM-CHANGED" })),
    AdmissionNumberImmutableError,
  );
  // Carries current + attempted so the handler can audit the rejected attempt.
  assertEquals(error.current, "ADM-001");
  assertEquals(error.attempted, "ADM-CHANGED");
  // No UPDATE was issued and the canonical value is unchanged (rolled back).
  assertEquals(db.updateProfileCalls, 0);
  assertEquals(db.committedProfiles[0]?.admission_number, "ADM-001");
});

Deno.test("updateStudent allows same-value admission_number no-op", async () => {
  const db = new WriteMockDb();
  seedExistingStudent(db, "ADM-001");

  const detail = await withMockTransaction(db, (client) =>
    updateStudent(client, ORG, SCHOOL_A, STUDENT_A, {
      admissionNumber: "ADM-001",
      gender: "female",
    }));
  assertEquals(detail.profile?.admission_number, "ADM-001");
  assertEquals(detail.profile?.gender, "female");
});

Deno.test("updateStudent allows other-field update with admission_number omitted", async () => {
  const db = new WriteMockDb();
  seedExistingStudent(db, "ADM-001");

  const detail = await withMockTransaction(db, (client) =>
    updateStudent(client, ORG, SCHOOL_A, STUDENT_A, { gender: "female" }));
  assertEquals(detail.profile?.admission_number, "ADM-001");
  assertEquals(detail.profile?.gender, "female");
});

Deno.test("createStudent sets admission_number on a new student", async () => {
  const db = new WriteMockDb();
  const detail = await withMockTransaction(db, (client) =>
    createStudent(client, ORG, SCHOOL_A, {
      displayName: "Fresh Student",
      admissionNumber: "ADM-FRESH-001",
      createdBy: STAFF,
    }));
  assertEquals(detail.profile?.admission_number, "ADM-FRESH-001");
  assertEquals(db.committedProfiles.length, 1);
});

Deno.test("updateStudentStatus applies lifecycle transition", async () => {
  const db = new WriteMockDb();
  db.committedStudents.push({
    id: STUDENT_A,
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_code: "STU-001",
    display_name: "Student",
    status: "active",
    created_at: "2026-06-01T00:00:00.000Z",
    updated_at: "2026-06-01T00:00:00.000Z",
  });
  db.committedProfiles.push({
    id: "profile-a",
    student_id: STUDENT_A,
    organization_id: ORG,
    school_id: SCHOOL_A,
    admission_number: "ADM-001",
    date_of_birth: null,
    gender: null,
    blood_group: null,
    address: null,
    city: null,
    state: null,
    postal_code: null,
    country: null,
    created_at: "2026-06-01T00:00:00.000Z",
    updated_at: "2026-06-01T00:00:00.000Z",
  });

  const detail = await withMockTransaction(db, (client) =>
    updateStudentStatus(client, ORG, SCHOOL_A, STUDENT_A, { status: "graduated" })
  );
  assertEquals(detail.student.status, "alumni");
  assertEquals(parseApiStatus(statusFromDb(detail.student.status)), "graduated");
});

// ── SCE-1: the raw status endpoint cannot BYPASS the TC no-dues law ───────────
function seedActiveStudent(db: WriteMockDb) {
  db.committedStudents.push({
    id: STUDENT_A, organization_id: ORG, school_id: SCHOOL_A,
    student_code: "STU-001", display_name: "Student", status: "active",
    created_at: "2026-06-01T00:00:00.000Z", updated_at: "2026-06-01T00:00:00.000Z",
  });
  db.committedProfiles.push({
    id: "profile-a", student_id: STUDENT_A, organization_id: ORG, school_id: SCHOOL_A,
    admission_number: "ADM-001", date_of_birth: null, gender: null, blood_group: null,
    address: null, city: null, state: null, postal_code: null, country: null,
    created_at: "2026-06-01T00:00:00.000Z", updated_at: "2026-06-01T00:00:00.000Z",
  });
}

/** Wrap the mock so the clearance finance-SUM answers `dues`, and the approved-
 * waiver lookup answers `waiverCover` (null = no waiver). Records a consume. */
function clearanceWrap(
  db: WriteMockDb,
  opts: { dues: number; waiverCover?: number | null },
): { client: TenantQueryClient; consumed: string[] } {
  const consumed: string[] = [];
  const client = {
    // deno-lint-ignore require-await
    async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
      if (sql.includes("SUM(outstanding_amount)")) {
        return [{ outstanding: String(opts.dues) }] as T[];
      }
      if (sql.includes("FROM student_clearance_waivers") && sql.includes("status = 'approved'")) {
        return (opts.waiverCover != null
          ? [{ id: "waiver-1", blocking_amount: String(opts.waiverCover) }]
          : []) as T[];
      }
      if (sql.includes("UPDATE student_clearance_waivers") && sql.includes("status = 'consumed'")) {
        consumed.push(String(args[4] ?? "null"));
        return [{ id: "waiver-1", status: "consumed" }] as T[];
      }
      return db.queryObject<T>(sql, args);
    },
    queryCount: () => Promise.resolve(0),
  } as unknown as TenantQueryClient;
  return { client, consumed };
}

Deno.test("SCE-1: status endpoint → transferred is BLOCKED when the student owes dues (no bypass of the TC law)", async () => {
  const db = new WriteMockDb();
  seedActiveStudent(db);
  const { client } = clearanceWrap(db, { dues: 750, waiverCover: null });
  db.beginTransaction();
  const err = await assertRejects(
    () => updateStudentStatus(client, ORG, SCHOOL_A, STUDENT_A, { status: "transferred" }),
    ClearanceDuesBlockedError,
  );
  assertEquals((err as ClearanceDuesBlockedError).amount, 750);
  // The student was NOT flipped (the throw precedes the UPDATE).
  assertEquals(db.committedStudents[0].status, "active");
});

Deno.test("SCE-1: an approved COVERING waiver lets the status-endpoint transfer through AND consumes the waiver (single-use)", async () => {
  const db = new WriteMockDb();
  seedActiveStudent(db);
  const { client, consumed } = clearanceWrap(db, { dues: 300, waiverCover: 300 });
  const detail = await withMockTransaction(
    db,
    () => Promise.resolve(client).then((c) =>
      updateStudentStatus(c, ORG, SCHOOL_A, STUDENT_A, { status: "transferred" })),
  );
  assertEquals(detail.student.status, "transferred");
  assertEquals(consumed.length, 1, "the covering waiver is consumed by the transfer");
});

Deno.test("SCE-1: `graduated` is DELIBERATELY NOT gated — a duesful student can still be graduated (owner-policy boundary)", async () => {
  const db = new WriteMockDb();
  seedActiveStudent(db);
  const { client, consumed } = clearanceWrap(db, { dues: 999, waiverCover: null });
  const detail = await withMockTransaction(
    db,
    () => Promise.resolve(client).then((c) =>
      updateStudentStatus(c, ORG, SCHOOL_A, STUDENT_A, { status: "graduated" })),
  );
  assertEquals(detail.student.status, "alumni");
  assertEquals(consumed.length, 0, "no clearance gate / consume on the graduation path");
});

Deno.test("updateStudent rejects cross-school student", async () => {
  const db = new WriteMockDb();
  db.committedStudents.push({
    id: STUDENT_B,
    organization_id: ORG,
    school_id: SCHOOL_B,
    student_code: "STU-002",
    display_name: "School B",
    status: "active",
    created_at: "2026-06-01T00:00:00.000Z",
    updated_at: "2026-06-01T00:00:00.000Z",
  });
  await assertRejects(
    () => withMockTransaction(db, (client) =>
      updateStudent(client, ORG, SCHOOL_A, STUDENT_B, { displayName: "Hack" })
    ),
  );
});

Deno.test("manageSis required for write middleware", () => {
  const claims = { ...schoolClaims(), permissions: ["viewSis"] };
  const denied = requirePermission(claims, "manageSis") ??
    requireSchoolOperationalScope(claims);
  assertEquals(denied?.status, 403);
});

function orgClaims(): AccessTokenClaims {
  return {
    ...schoolClaims(),
    school_id: null,
    scope: "organization",
    role: "organizationAdmin",
    role_slugs: ["organizationAdmin"],
    primary_role: "organizationAdmin",
    permissions: ["manageSis"],
  };
}

Deno.test("org scope denied for SIS write middleware", () => {
  const denied = requirePermission(orgClaims(), "manageSis") ??
    requireSchoolOperationalScope(orgClaims());
  assertEquals(denied?.status, 403);
});
