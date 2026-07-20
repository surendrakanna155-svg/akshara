import {
  assertEquals,
  assertExists,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  EnrollmentApplicationNotFoundError,
  EnrollmentNotApprovedError,
  submitEnrollment,
} from "./admissions_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const APPLICATION = "ab000000-0000-4000-8000-000000000001";

type Row = Record<string, unknown>;

/**
 * P0 money-fix mock: exercises the real submitEnrollment idempotency path.
 * Tracks how many students / enrollments / fee handoffs were inserted, and
 * enforces the partial unique index on admissions_enrollments(application_id)
 * so a second submit for the same application raises 23505 — which the repo
 * must map to the existing enrollment (idempotent), not mint duplicates.
 */
class MockEnrollmentDb {
  applications: Row[] = [
    {
      id: APPLICATION,
      organization_id: ORG,
      school_id: SCHOOL,
      status: "approved",
    },
  ];
  students: Row[] = [];
  enrollments: Row[] = [];
  handoffs: Row[] = [];

  studentInsertCount = 0;
  enrollmentInsertAttempts = 0;
  handoffInsertCount = 0;

  // When set, the idempotency guard SELECT ignores this application id (as if a
  // concurrent tx committed AFTER the guard read) so the enrollment INSERT is
  // what trips the unique index — exercising the 23505 backstop path.
  hideFromGuardApplication: string | null = null;

  private uniqueViolation(): Error {
    const err = new Error(
      'duplicate key value violates unique constraint "admissions_enrollments_application_uniq"',
    ) as Error & { code: string; fields: { code: string } };
    err.code = "23505";
    err.fields = { code: "23505" };
    return err;
  }

  // deno-lint-ignore no-explicit-any
  async queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    // Guardian lookup — no guardian in these tests.
    if (sql.includes("lookup_guardian_user_for_enrollment")) {
      return [{ guardian_user_id: null }] as T[];
    }
    // Lock anchor on the application row. PRA-P0-13: the repo now also reads
    // `status` under the lock, so surface it (the seeds carry it).
    if (sql.includes("FROM admissions_applications") && sql.includes("FOR UPDATE")) {
      const row = this.applications.find((a) =>
        a.id === args[0] && a.organization_id === args[1] && a.school_id === args[2]
      );
      return (row ? [{ id: row.id, status: row.status }] : []) as T[];
    }
    // Idempotency guard: existing enrollment for this application?
    if (
      sql.includes("FROM admissions_enrollments") &&
      sql.includes("application_id = $1")
    ) {
      if (this.hideFromGuardApplication === args[0]) return [] as T[];
      const row = this.enrollments.find((e) =>
        e.application_id === args[0] &&
        e.organization_id === args[1] &&
        e.school_id === args[2]
      );
      return (row ? [row] : []) as T[];
    }
    if (sql.startsWith("SAVEPOINT") || sql.startsWith("RELEASE SAVEPOINT")) {
      return [] as T[];
    }
    if (sql.startsWith("ROLLBACK TO SAVEPOINT")) {
      return [] as T[];
    }
    if (sql.includes("INSERT INTO students")) {
      this.studentInsertCount += 1;
      const id = crypto.randomUUID();
      this.students.push({ id, organization_id: args[0], school_id: args[1] });
      return [{ id }] as T[];
    }
    if (sql.includes("INSERT INTO admissions_enrollments")) {
      this.enrollmentInsertAttempts += 1;
      const applicationId = args[2];
      // Enforce the partial unique index (application_id IS NOT NULL).
      const duplicate = applicationId != null &&
        this.enrollments.some((e) => e.application_id === applicationId);
      if (duplicate) {
        // The racing tx is now visible: clear the guard blindfold so the repo's
        // post-23505 recovery SELECT finds the winning enrollment.
        this.hideFromGuardApplication = null;
        throw this.uniqueViolation();
      }
      const row: Row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        application_id: applicationId,
        student_id: args[3],
        student_name: args[5],
        seeking_class: args[6],
        section: args[7],
        academic_year: args[8],
        academic_year_id: args[9],
        class_id: args[10],
        section_id: args[11],
        guardian_name: args[12],
        phone: args[13],
        gender: args[14],
        date_of_birth: args[15],
        conversion_status: "pending",
        admission_number: args[16],
        submitted_at: "2026-07-02T00:00:00.000Z",
      };
      this.enrollments.push(row);
      return [row] as T[];
    }
    if (sql.includes("UPDATE admissions_applications SET status = 'approved'")) {
      return [] as T[];
    }
    if (sql.includes("INSERT INTO admissions_fee_handoffs")) {
      this.handoffInsertCount += 1;
      const row: Row = { id: crypto.randomUUID(), enrollment_id: args[4] };
      this.handoffs.push(row);
      return [row] as T[];
    }
    throw new Error(`Unhandled SQL in MockEnrollmentDb: ${sql.slice(0, 80)}`);
  }
}

function baseInput(applicationId: string | null) {
  return {
    applicationId,
    studentFullName: "Idempotent Student",
    dateOfBirth: "2016-04-01",
    gender: "male",
    aadhaar: "",
    guardianName: "Guardian One",
    relationship: "father",
    phone: "9000000123",
    email: "",
    address: "",
    seekingClass: "",
    section: "",
    academicYear: "",
    previousSchool: "",
    needsTransport: false,
    needsHostel: false,
  };
}

Deno.test("submitEnrollment is idempotent — repeated submit yields ONE student + ONE handoff (guard path)", async () => {
  const db = new MockEnrollmentDb();

  const first = await submitEnrollment(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    baseInput(APPLICATION),
  );
  assertExists(first);

  const second = await submitEnrollment(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    baseInput(APPLICATION),
  );

  // Same enrollment returned; no duplicate student / handoff.
  assertEquals(second.id, first.id);
  assertEquals(db.students.length, 1, "exactly one student created");
  assertEquals(db.enrollments.length, 1, "exactly one enrollment created");
  assertEquals(db.handoffs.length, 1, "exactly one fee handoff created");
  assertEquals(db.studentInsertCount, 1);
  assertEquals(db.handoffInsertCount, 1);
});

Deno.test("submitEnrollment maps a racing 23505 to the existing enrollment (backstop path)", async () => {
  const db = new MockEnrollmentDb();

  // Seed the winning enrollment as if a concurrent submit already committed it,
  // but keep the guard blind to it so the INSERT is what trips the unique index.
  const winner: Row = {
    id: crypto.randomUUID(),
    organization_id: ORG,
    school_id: SCHOOL,
    application_id: APPLICATION,
    student_name: "Idempotent Student",
    conversion_status: "pending",
    admission_number: "ADM-2026-EXISTING",
    submitted_at: "2026-07-02T00:00:00.000Z",
  };
  db.enrollments.push(winner);
  // Make the guard blind to the winner so the INSERT is what trips the unique
  // index (23505) — the repo must roll back to the savepoint and recover it.
  db.hideFromGuardApplication = APPLICATION;

  const result = await submitEnrollment(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    baseInput(APPLICATION),
  );

  assertEquals(
    result.admission_number,
    "ADM-2026-EXISTING",
    "returned the pre-existing winning enrollment",
  );
  // No second enrollment row, no second handoff.
  assertEquals(db.enrollments.length, 1, "no duplicate enrollment row");
  assertEquals(db.handoffInsertCount, 0, "no fee handoff on the idempotent path");
});

Deno.test("submitEnrollment with null application_id is NOT deduped (walk-in enrollments)", async () => {
  const db = new MockEnrollmentDb();

  await submitEnrollment(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    baseInput(null),
  );
  await submitEnrollment(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    baseInput(null),
  );

  // Two distinct walk-in enrollments — each mints its own student + handoff.
  assertEquals(db.students.length, 2);
  assertEquals(db.enrollments.length, 2);
  assertEquals(db.handoffs.length, 2);
});

// ── PRA-P0-13: application must be APPROVED before it becomes an active student ──

Deno.test("PRA-P0-13: submitEnrollment REJECTS a non-approved application and mints nothing", async () => {
  for (const status of ["draft", "submitted", "documents_pending", "under_review", "rejected"]) {
    const db = new MockEnrollmentDb();
    db.applications = [{ id: APPLICATION, organization_id: ORG, school_id: SCHOOL, status }];

    await assertRejects(
      () =>
        submitEnrollment(
          db as unknown as TenantQueryClient,
          ORG,
          SCHOOL,
          baseInput(APPLICATION),
        ),
      EnrollmentNotApprovedError,
      undefined,
      `status='${status}' must be blocked`,
    );

    // The gate fires BEFORE any student/enrollment/handoff is minted.
    assertEquals(db.students.length, 0, `no student minted for status='${status}'`);
    assertEquals(db.enrollments.length, 0, `no enrollment for status='${status}'`);
    assertEquals(db.handoffs.length, 0, `no fee handoff for status='${status}'`);
  }
});

Deno.test("PRA-P0-13: an APPROVED application still converts (control — one student)", async () => {
  const db = new MockEnrollmentDb(); // seeded status = 'approved'
  const result = await submitEnrollment(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    baseInput(APPLICATION),
  );
  assertExists(result);
  assertEquals(db.students.length, 1);
  assertEquals(db.enrollments.length, 1);
});

Deno.test("PRA-P0-13: an unknown application id is rejected, not silently enrolled", async () => {
  const db = new MockEnrollmentDb();
  db.applications = []; // the named application does not exist in this tenant
  await assertRejects(
    () =>
      submitEnrollment(
        db as unknown as TenantQueryClient,
        ORG,
        SCHOOL,
        baseInput(APPLICATION),
      ),
    EnrollmentApplicationNotFoundError,
  );
  assertEquals(db.students.length, 0);
});
