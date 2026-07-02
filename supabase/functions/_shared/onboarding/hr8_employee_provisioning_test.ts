// HR-8 — Automatic Employee Provisioning (idempotent + identity-preserving).
//
// When a teacher/staff import job is committed, each imported user is projected
// into the HR `employees` table AFTER ensureSchoolMembership. This must be:
//   • IDEMPOTENT   — a re-import (same user) creates NO duplicate employees row
//                    (ON CONFLICT (org, school, user_id) DO NOTHING).
//   • IDENTITY-PRESERVING — the projection never rewrites the canonical identity
//                    (users + school_memberships stay the source of truth) and
//                    never changes an existing employee's employee_code / user_id.
//   • AUDITED      — a genuinely-new provisioning emits an audit + domain event;
//                    a re-import no-op does NOT emit a fresh "created" audit.
//
// DB-free: an in-memory fake TenantQueryClient that models the exact SQL the code
// issues (same seam as qa_x_021_student_import_integrity_test.ts). The employees
// INSERT ... ON CONFLICT DO NOTHING is modelled by returning an empty RETURNING
// set on conflict, exactly as the partial unique index (migration 20260834000000)
// makes Postgres behave.

import { assertEquals } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { commitImportJob, createImportPreview } from "./onboarding_repository.ts";
import {
  employeeCodeForUser,
  provisionEmployee,
} from "./onboarding_user_provisioning.ts";

const ORG = "b1000000-0000-4000-8000-000000000001";
const SCHOOL = "b2000000-0000-4000-8000-000000000001";
const ACTOR = "b3000000-0000-4000-8000-000000000009";

function claims(): AccessTokenClaims {
  return {
    sub: ACTOR,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: ["manageOnboarding"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
  };
}

interface UserRec {
  id: string;
  phone: string;
  display_name: string;
  email: string | null;
}
interface MembershipRec {
  user_id: string;
  school_id: string;
  role: string;
}
interface EmployeeRec {
  id: string;
  organization_id: string;
  school_id: string;
  user_id: string;
  employee_code: string;
  display_name: string;
  email: string | null;
  phone: string | null;
  status: string;
  primary_department: string | null;
}
interface JobRec {
  id: string;
  organization_id: string;
  school_id: string;
  import_type: string;
  status: string;
  total_rows: number;
  valid_rows: number;
  invalid_rows: number;
  duplicate_rows: number;
  committed_rows: number;
  report: Record<string, unknown>;
}
interface RowRec {
  id: string;
  job_id: string;
  row_number: number;
  payload: Record<string, unknown>;
  status: string;
  created_entity_id: string | null;
}

class Hr8FakeDb {
  users: UserRec[] = [];
  memberships: MembershipRec[] = [];
  employees: EmployeeRec[] = [];
  jobs: JobRec[] = [];
  rows: RowRec[] = [];
  auditEvents: Array<Record<string, unknown>> = [];
  domainEvents: Array<{ event_type: string; idempotency_key: string | null }> = [];
  private seq = 0;

  private id(prefix: string): string {
    this.seq++;
    return `${prefix}-${this.seq.toString().padStart(4, "0")}`;
  }

  get client(): TenantQueryClient {
    // deno-lint-ignore no-explicit-any
    return { queryObject: (sql: string, args: unknown[] = []) => this.run(sql, args) } as any;
  }

  // deno-lint-ignore no-explicit-any
  private async run(sql: string, args: unknown[]): Promise<any[]> {
    await Promise.resolve();
    const s = sql.replace(/\s+/g, " ").trim();

    if (
      s.startsWith("SAVEPOINT") || s.startsWith("RELEASE SAVEPOINT") ||
      s.startsWith("ROLLBACK TO SAVEPOINT")
    ) {
      return [];
    }

    // ── onboarding_import_jobs ────────────────────────────────────────────────
    if (s.startsWith("INSERT INTO onboarding_import_jobs")) {
      const job: JobRec = {
        id: this.id("job"),
        organization_id: String(args[0]),
        school_id: String(args[1]),
        import_type: String(args[2]),
        status: "draft",
        total_rows: Number(args[4]),
        valid_rows: 0,
        invalid_rows: 0,
        duplicate_rows: 0,
        committed_rows: 0,
        report: {},
      };
      this.jobs.push(job);
      return [structuredClone(job)];
    }
    if (s.startsWith("UPDATE onboarding_import_jobs SET status = 'previewed'")) {
      const job = this.jobs.find((j) => j.id === args[0])!;
      job.status = "previewed";
      job.valid_rows = Number(args[1]);
      job.invalid_rows = Number(args[2]);
      job.duplicate_rows = Number(args[3]);
      return [structuredClone(job)];
    }
    if (s.startsWith("UPDATE onboarding_import_jobs SET status = 'committed'")) {
      const job = this.jobs.find((j) => j.id === args[0])!;
      job.status = "committed";
      job.committed_rows = Number(args[1]);
      job.report = { ...job.report, ...JSON.parse(String(args[2])) };
      return [structuredClone(job)];
    }
    if (s.startsWith("SELECT * FROM onboarding_import_jobs WHERE id = $1")) {
      const job = this.jobs.find((j) =>
        j.id === args[0] && j.organization_id === args[1] && j.school_id === args[2]
      );
      return job ? [structuredClone(job)] : [];
    }

    // ── onboarding_import_rows ────────────────────────────────────────────────
    if (s.startsWith("INSERT INTO onboarding_import_rows")) {
      this.rows.push({
        id: this.id("row"),
        job_id: String(args[0]),
        row_number: Number(args[3]),
        payload: JSON.parse(String(args[4])),
        status: String(args[5]),
        created_entity_id: null,
      });
      return [];
    }
    if (s.startsWith("SELECT id, row_number, payload, status FROM onboarding_import_rows")) {
      return this.rows
        .filter((r) => r.job_id === args[0] && r.status === "valid")
        .sort((a, b) => a.row_number - b.row_number)
        .map((r) => ({ id: r.id, row_number: r.row_number, payload: r.payload, status: r.status }));
    }
    if (s.startsWith("UPDATE onboarding_import_rows SET status = 'committed'")) {
      const row = this.rows.find((r) => r.id === args[0]);
      if (row) {
        row.status = "committed";
        row.created_entity_id = (args[1] as string | null) ?? null;
      }
      return [];
    }

    // ── identity: users + memberships (canonical source of truth) ─────────────
    if (s.startsWith("SELECT onboarding_upsert_user_by_phone")) {
      const phone = String(args[0]);
      let user = this.users.find((u) => u.phone === phone);
      if (!user) {
        // Deterministic UUID-shaped id per phone so re-import maps to one user.
        const n = (this.users.length + 1).toString(16).padStart(12, "0");
        user = {
          id: `be200000-0000-4000-8000-${n}`,
          phone,
          display_name: String(args[1]),
          email: (args[2] as string | null) ?? null,
        };
        this.users.push(user);
      }
      return [{ onboarding_upsert_user_by_phone: user.id }];
    }
    if (s.startsWith("SELECT onboarding_ensure_school_membership")) {
      const userId = String(args[0]);
      const schoolId = String(args[1]);
      const role = String(args[2]);
      const existing = this.memberships.find((m) => m.user_id === userId && m.school_id === schoolId);
      if (existing) existing.role = role;
      else this.memberships.push({ user_id: userId, school_id: schoolId, role });
      return [];
    }

    // ── employees projection (HR-8) — ON CONFLICT DO NOTHING semantics ────────
    if (s.startsWith("INSERT INTO employees")) {
      const [org, school, userId, code, name, email, phone, dept] = [
        String(args[0]), String(args[1]), String(args[2]), String(args[3]),
        String(args[4]), (args[5] as string | null) ?? null,
        (args[6] as string | null) ?? null, String(args[7]),
      ];
      const conflict = this.employees.find((e) =>
        e.organization_id === org && e.school_id === school && e.user_id === userId
      );
      if (conflict) {
        // ON CONFLICT DO NOTHING → empty RETURNING set.
        return [];
      }
      const rec: EmployeeRec = {
        id: this.id("emp"),
        organization_id: org,
        school_id: school,
        user_id: userId,
        employee_code: code,
        display_name: name,
        email,
        phone,
        status: "active",
        primary_department: dept,
      };
      this.employees.push(rec);
      return [{ id: rec.id }];
    }
    if (s.startsWith("UPDATE employees SET display_name")) {
      const [org, school, userId, name, email, phone] = [
        String(args[0]), String(args[1]), String(args[2]),
        String(args[3]), (args[4] as string | null) ?? null,
        (args[5] as string | null) ?? null,
      ];
      const emp = this.employees.find((e) =>
        e.organization_id === org && e.school_id === school && e.user_id === userId
      )!;
      // Mirror the SQL: display_name replaced; email/phone COALESCE (keep prior
      // when null); employee_code + user_id NEVER touched.
      emp.display_name = name;
      if (email !== null) emp.email = email;
      if (phone !== null) emp.phone = phone;
      return [{ id: emp.id }];
    }

    // ── audit + domain events ─────────────────────────────────────────────────
    if (s.startsWith("INSERT INTO audit_events")) {
      this.auditEvents.push({ sql: s });
      return [];
    }
    if (s.startsWith("SELECT id::text FROM domain_events")) {
      const key = String(args[1]);
      return this.domainEvents.filter((d) => d.idempotency_key === key).map(() => ({ id: "x" }));
    }
    if (s.startsWith("INSERT INTO domain_events")) {
      this.domainEvents.push({ event_type: String(args[2]), idempotency_key: (args[6] as string | null) ?? null });
      return [];
    }

    throw new Error(`Unhandled SQL in Hr8FakeDb: ${s.slice(0, 90)}`);
  }
}

const teacherRow = {
  displayName: "Anita Rao",
  phone: "9876500055",
  email: "anita@example.com",
  role: "teacher",
};

async function previewAndCommitTeacher(fake: Hr8FakeDb): Promise<void> {
  const { job } = await createImportPreview(
    fake.client, ORG, SCHOOL, ACTOR, "teacher", "teachers.csv", [teacherRow],
  );
  await commitImportJob(fake.client, ORG, SCHOOL, job.id, claims());
}

Deno.test("HR-8: committing a teacher import provisions exactly one employees row, identity preserved", async () => {
  const fake = new Hr8FakeDb();
  await previewAndCommitTeacher(fake);

  // Canonical identity established.
  assertEquals(fake.users.length, 1);
  assertEquals(fake.memberships.length, 1);
  assertEquals(fake.memberships[0]?.role, "teacher");

  // Exactly one employees projection row, with the deterministic code.
  assertEquals(fake.employees.length, 1);
  const emp = fake.employees[0]!;
  assertEquals(emp.user_id, fake.users[0]!.id);
  assertEquals(emp.employee_code, employeeCodeForUser(fake.users[0]!.id));
  assertEquals(emp.display_name, "Anita Rao");
  assertEquals(emp.phone, "9876500055");
  assertEquals(emp.status, "active");
  assertEquals(emp.primary_department, "General");

  // Provisioning was audited (created path).
  assertEquals(fake.domainEvents.some((d) => d.event_type === "hr.employee.provisioned"), true);
});

Deno.test("HR-8: RE-IMPORTING the same teacher creates NO duplicate employees row (idempotent)", async () => {
  const fake = new Hr8FakeDb();
  await previewAndCommitTeacher(fake);
  const codeBefore = fake.employees[0]!.employee_code;
  const idBefore = fake.employees[0]!.id;
  const auditsAfterFirst = fake.domainEvents.filter((d) => d.event_type === "hr.employee.provisioned").length;

  // Second import of the SAME teacher (same phone → same user).
  await previewAndCommitTeacher(fake);

  // Still exactly ONE user, ONE membership, ONE employee row.
  assertEquals(fake.users.length, 1);
  assertEquals(fake.memberships.length, 1);
  assertEquals(fake.employees.length, 1);

  // Identity + code unchanged across the re-import.
  assertEquals(fake.employees[0]!.id, idBefore);
  assertEquals(fake.employees[0]!.employee_code, codeBefore);
  assertEquals(fake.employees[0]!.user_id, fake.users[0]!.id);

  // The no-op re-import did NOT emit a fresh "created" provisioning audit.
  const auditsAfterSecond = fake.domainEvents.filter((d) => d.event_type === "hr.employee.provisioned").length;
  assertEquals(auditsAfterSecond, auditsAfterFirst);
});

Deno.test("HR-8: provisionEmployee is idempotent and never rewrites code/user_id on conflict", async () => {
  const fake = new Hr8FakeDb();
  const userId = "be200000-0000-4000-8000-0000000000aa";

  const first = await provisionEmployee(fake.client, ORG, SCHOOL, userId, {
    displayName: "First Name",
    email: "first@example.com",
    phone: "9000000001",
    primaryDepartment: "Science",
  });
  assertEquals(first.created, true);
  const code = employeeCodeForUser(userId);
  assertEquals(fake.employees[0]!.employee_code, code);

  // Re-provision with different display fields → sync (no new row), code frozen.
  const second = await provisionEmployee(fake.client, ORG, SCHOOL, userId, {
    displayName: "Updated Name",
    email: null, // null must NOT clobber the existing email (COALESCE)
    phone: "9000000002",
    primaryDepartment: "Maths",
  });
  assertEquals(second.created, false);
  assertEquals(second.employeeId, first.employeeId);
  assertEquals(fake.employees.length, 1);
  const emp = fake.employees[0]!;
  assertEquals(emp.employee_code, code); // NEVER changed
  assertEquals(emp.user_id, userId); // NEVER changed
  assertEquals(emp.display_name, "Updated Name"); // refreshed
  assertEquals(emp.phone, "9000000002"); // refreshed
  assertEquals(emp.email, "first@example.com"); // preserved (null did not clobber)
});

Deno.test("HR-8: employeeCodeForUser matches the v9.6 backfill scheme (EMP- + first 8 hex)", () => {
  assertEquals(
    employeeCodeForUser("be100000-0000-4000-8000-000000000001"),
    "EMP-be100000",
  );
});
