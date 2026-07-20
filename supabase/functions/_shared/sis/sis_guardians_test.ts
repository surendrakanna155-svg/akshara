import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  addGuardianLink,
  deactivateGuardianLink,
  GuardianLinkNotFoundError,
  LastGuardianError,
  listGuardianLinks,
} from "./sis_guardians_repository.ts";

// PRA-P1-01 / PRA-P1-02 (S2) — DB-free repository tests. The mock implements the
// `queryObject<T>` seam and pattern-matches the SQL exactly like the other SIS
// repository tests (see sis_siblings_repository_test.ts).

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const STUDENT = "a4000000-0000-4000-8000-000000000001";

const G1 = "a3000000-0000-4000-8000-000000000001"; // first / primary guardian
const G2 = "a3000000-0000-4000-8000-000000000002"; // second guardian
const G_UNKNOWN = "a3000000-0000-4000-8000-00000000009f"; // never linked

interface LinkRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  guardian_user_id: string;
  relationship: string;
  is_primary: boolean;
  status: string;
}

function link(
  guardianUserId: string,
  isPrimary: boolean,
  status = "active",
  relationship = "guardian",
): LinkRow {
  return {
    id: `link-${guardianUserId}`,
    organization_id: ORG,
    school_id: SCHOOL,
    student_id: STUDENT,
    guardian_user_id: guardianUserId,
    relationship,
    is_primary: isPrimary,
    status,
  };
}

class MockGuardiansDb {
  links: LinkRow[];
  private seq = 0;

  constructor(links: LinkRow[]) {
    this.links = links.map((l) => ({ ...l }));
  }

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("INSERT INTO student_guardians")) {
      return this.upsert(args) as T[];
    }
    if (sql.includes("SET is_primary = false")) {
      this.demoteOthers(args);
      return [] as T[];
    }
    if (sql.includes("SET status = 'inactive'")) {
      return this.deactivate(args) as T[];
    }
    if (sql.includes("SELECT id, student_id, guardian_user_id")) {
      return this.list(args) as T[];
    }
    if (sql.includes("SELECT guardian_user_id")) {
      return this.selectActive(args) as T[];
    }
    return [] as T[];
  }

  private scope(args: unknown[]): { org: unknown; school: unknown; student: unknown } {
    return { org: args[0], school: args[1], student: args[2] };
  }

  // UPDATE ... SET is_primary = false WHERE ... guardian_user_id <> $4 AND status='active'
  private demoteOthers(args: unknown[]): void {
    const { org, school, student } = this.scope(args);
    const excluded = args[3];
    for (const row of this.links) {
      if (
        row.organization_id === org &&
        row.school_id === school &&
        row.student_id === student &&
        row.guardian_user_id !== excluded &&
        row.status === "active"
      ) {
        row.is_primary = false;
      }
    }
  }

  // INSERT ... ON CONFLICT (student_id, guardian_user_id) DO UPDATE ...
  private upsert(args: unknown[]): LinkRow[] {
    const { org, school, student } = this.scope(args);
    const guardianUserId = args[3] as string;
    const relationship = args[4] as string;
    const isPrimary = args[5] as boolean;

    const existing = this.links.find(
      (r) =>
        r.organization_id === org &&
        r.school_id === school &&
        r.student_id === student &&
        r.guardian_user_id === guardianUserId,
    );
    if (existing) {
      existing.status = "active";
      existing.relationship = relationship;
      existing.is_primary = isPrimary;
      return [{ ...existing }];
    }
    const created: LinkRow = {
      id: `link-new-${++this.seq}`,
      organization_id: org as string,
      school_id: school as string,
      student_id: student as string,
      guardian_user_id: guardianUserId,
      relationship,
      is_primary: isPrimary,
      status: "active",
    };
    this.links.push(created);
    return [{ ...created }];
  }

  // SELECT guardian_user_id ... WHERE ... status='active'
  private selectActive(args: unknown[]): { guardian_user_id: string }[] {
    const { org, school, student } = this.scope(args);
    return this.links
      .filter(
        (r) =>
          r.organization_id === org &&
          r.school_id === school &&
          r.student_id === student &&
          r.status === "active",
      )
      .map((r) => ({ guardian_user_id: r.guardian_user_id }));
  }

  // UPDATE ... SET status='inactive' WHERE ... guardian_user_id=$4 AND status='active' RETURNING id
  private deactivate(args: unknown[]): { id: string }[] {
    const { org, school, student } = this.scope(args);
    const guardianUserId = args[3];
    const row = this.links.find(
      (r) =>
        r.organization_id === org &&
        r.school_id === school &&
        r.student_id === student &&
        r.guardian_user_id === guardianUserId &&
        r.status === "active",
    );
    if (!row) return [];
    row.status = "inactive";
    return [{ id: row.id }];
  }

  // SELECT id, student_id, ... ORDER BY is_primary DESC, created_at ASC
  private list(args: unknown[]): LinkRow[] {
    const { org, school, student } = this.scope(args);
    return this.links
      .filter(
        (r) =>
          r.organization_id === org &&
          r.school_id === school &&
          r.student_id === student,
      )
      .slice()
      .sort((a, b) => Number(b.is_primary) - Number(a.is_primary))
      .map((r) => ({ ...r }));
  }
}

function asDb(mock: MockGuardiansDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

Deno.test("PRA-P1-01 addGuardianLink: a second guardian is non-primary and does not steal primacy", async () => {
  const mock = new MockGuardiansDb([link(G1, true)]);
  const created = await addGuardianLink(asDb(mock), ORG, SCHOOL, STUDENT, G2, {
    relationship: "father",
    isPrimary: false,
  });

  assertEquals(created.guardian_user_id, G2);
  assertEquals(created.is_primary, false);
  assertEquals(created.status, "active");

  const rows = await listGuardianLinks(asDb(mock), ORG, SCHOOL, STUDENT);
  const g1 = rows.find((r) => r.guardian_user_id === G1)!;
  const g2 = rows.find((r) => r.guardian_user_id === G2)!;
  // The original primary is untouched; exactly one primary remains.
  assertEquals(g1.is_primary, true);
  assertEquals(g2.is_primary, false);
  assertEquals(rows.filter((r) => r.is_primary).length, 1);
});

Deno.test("PRA-P1-01 addGuardianLink: promoting a link to primary demotes the others", async () => {
  const mock = new MockGuardiansDb([link(G1, true), link(G2, false)]);
  const promoted = await addGuardianLink(asDb(mock), ORG, SCHOOL, STUDENT, G2, {
    isPrimary: true,
  });

  assertEquals(promoted.is_primary, true);

  const rows = await listGuardianLinks(asDb(mock), ORG, SCHOOL, STUDENT);
  const g1 = rows.find((r) => r.guardian_user_id === G1)!;
  const g2 = rows.find((r) => r.guardian_user_id === G2)!;
  assertEquals(g1.is_primary, false); // demoted
  assertEquals(g2.is_primary, true);
  // The single-primary invariant holds.
  assertEquals(rows.filter((r) => r.is_primary).length, 1);
});

Deno.test("PRA-P1-02 deactivateGuardianLink: unlink flips the link to inactive (not deleted)", async () => {
  const mock = new MockGuardiansDb([link(G1, true), link(G2, false)]);
  const id = await deactivateGuardianLink(asDb(mock), ORG, SCHOOL, STUDENT, G2);
  assertEquals(id, "link-" + G2);

  const rows = await listGuardianLinks(asDb(mock), ORG, SCHOOL, STUDENT);
  const g1 = rows.find((r) => r.guardian_user_id === G1)!;
  const g2 = rows.find((r) => r.guardian_user_id === G2)!;
  assertEquals(g2.status, "inactive"); // soft-removed, still present
  assertEquals(g1.status, "active"); // the remaining guardian is untouched
});

Deno.test("PRA-P1-02 deactivateGuardianLink: unknown / already-inactive link throws GuardianLinkNotFoundError", async () => {
  const mock = new MockGuardiansDb([link(G1, true), link(G2, false)]);
  await assertRejects(
    () => deactivateGuardianLink(asDb(mock), ORG, SCHOOL, STUDENT, G_UNKNOWN),
    GuardianLinkNotFoundError,
  );
  // Nothing was mutated.
  const rows = await listGuardianLinks(asDb(mock), ORG, SCHOOL, STUDENT);
  assertEquals(rows.every((r) => r.status === "active"), true);
});

Deno.test("PRA-P1-02 deactivateGuardianLink: removing the LAST active guardian throws LastGuardianError", async () => {
  const mock = new MockGuardiansDb([link(G1, true)]);
  await assertRejects(
    () => deactivateGuardianLink(asDb(mock), ORG, SCHOOL, STUDENT, G1),
    LastGuardianError,
  );
  // The sole guardian is left ACTIVE — the student is never left contactless.
  const rows = await listGuardianLinks(asDb(mock), ORG, SCHOOL, STUDENT);
  assertEquals(rows.length, 1);
  assertEquals(rows[0].status, "active");
});
