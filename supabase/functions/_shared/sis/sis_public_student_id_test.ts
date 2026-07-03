import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  allocatePublicStudentId,
  formatPublicStudentId,
  type PublicIdDb,
  SchoolCodeMissingError,
} from "./sis_public_student_id.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_NO_CODE = "a2000000-0000-4000-8000-000000000009";

/**
 * Faithful in-memory model of the two SQL statements allocatePublicStudentId
 * issues:
 *   1. SELECT code FROM schools WHERE id=$1 AND organization_id=$2
 *   2. INSERT ... school_public_id_counters ... VALUES (...,2)
 *        ON CONFLICT DO UPDATE SET next_seq = next_seq + 1
 *        RETURNING (next_seq - 1) AS allocated
 *
 * The counter model reproduces the EXACT arithmetic of the real ON CONFLICT
 * statement so the tests prove first=0001 and no duplicates under repeated
 * (serialized) allocation, which is what the row-level lock guarantees in
 * production.
 */
class CounterMockDb implements PublicIdDb {
  // (org|school) -> next_seq. Absent key == no counter row yet.
  private counters = new Map<string, number>();
  private codes: Map<string, string | null>;

  constructor(codes: Record<string, string | null>) {
    this.codes = new Map(Object.entries(codes));
  }

  private key(org: string, school: string): string {
    return `${org}|${school}`;
  }

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("SELECT code FROM schools")) {
      const [schoolId, orgId] = args as [string, string];
      // Model the org+school predicate: a mismatched org yields no row.
      const code = this.codes.get(schoolId);
      const rows = code === undefined ? [] : [{ code }];
      // orgId is accepted but every seeded school here belongs to ORG.
      void orgId;
      return rows as T[];
    }
    if (sql.includes("INSERT INTO school_public_id_counters")) {
      const [orgId, schoolId] = args as [string, string];
      const k = this.key(orgId, schoolId);
      const current = this.counters.get(k);
      let allocated: number;
      if (current === undefined) {
        // First-insert path: row lands next_seq=2, RETURNING next_seq-1 = 1.
        this.counters.set(k, 2);
        allocated = 1;
      } else {
        // ON CONFLICT path: next_seq = next_seq + 1, RETURNING (new next_seq)-1
        // == the pre-update value.
        const next = current + 1;
        this.counters.set(k, next);
        allocated = next - 1;
      }
      return [{ allocated }] as T[];
    }
    return [] as T[];
  }

  peekNextSeq(org: string, school: string): number | undefined {
    return this.counters.get(this.key(org, school));
  }
}

Deno.test("formatPublicStudentId zero-pads to 4 digits", () => {
  assertEquals(formatPublicStudentId("DPSKKP", 1), "DPSKKP-0001");
  assertEquals(formatPublicStudentId("DPSKKP", 42), "DPSKKP-0042");
  assertEquals(formatPublicStudentId("DPSKKP", 9999), "DPSKKP-9999");
  // Beyond 4 digits it does not truncate — it keeps growing (never-reused > pad).
  assertEquals(formatPublicStudentId("DPSKKP", 10000), "DPSKKP-10000");
});

Deno.test("allocatePublicStudentId: first student is CODE-0001, then 0002 sequentially", async () => {
  const db = new CounterMockDb({ [SCHOOL]: "DPSKKP" });

  const first = await allocatePublicStudentId(db, ORG, SCHOOL);
  const second = await allocatePublicStudentId(db, ORG, SCHOOL);
  const third = await allocatePublicStudentId(db, ORG, SCHOOL);

  assertEquals(first, "DPSKKP-0001");
  assertEquals(second, "DPSKKP-0002");
  assertEquals(third, "DPSKKP-0003");
  // The stored counter points at the NEXT value to hand out (4 after three allocs).
  assertEquals(db.peekNextSeq(ORG, SCHOOL), 4);
});

Deno.test("allocatePublicStudentId: consecutive allocations never collide (no duplicates/gaps)", async () => {
  const db = new CounterMockDb({ [SCHOOL]: "DPSKKP" });

  const seen = new Set<string>();
  for (let i = 0; i < 25; i++) {
    const psid = await allocatePublicStudentId(db, ORG, SCHOOL);
    assertEquals(seen.has(psid), false, `duplicate PSID allocated: ${psid}`);
    seen.add(psid);
  }
  assertEquals(seen.size, 25);
  // Dense: 0001..0025 with no gaps.
  assertEquals(seen.has("DPSKKP-0001"), true);
  assertEquals(seen.has("DPSKKP-0025"), true);
  assertEquals(db.peekNextSeq(ORG, SCHOOL), 26);
});

Deno.test("allocatePublicStudentId: two allocations return DISTINCT numbers (concurrency intent)", async () => {
  // The real serialization is the ON CONFLICT DO UPDATE row lock. The mock
  // reproduces that statement's arithmetic; issuing two allocations proves the
  // counter hands each caller a different value with the correct before/after
  // semantics (no two callers ever see the same number).
  const db = new CounterMockDb({ [SCHOOL]: "DPSKKP" });
  const a = await allocatePublicStudentId(db, ORG, SCHOOL);
  const b = await allocatePublicStudentId(db, ORG, SCHOOL);
  assertEquals(a === b, false);
  assertEquals(a, "DPSKKP-0001");
  assertEquals(b, "DPSKKP-0002");
});

Deno.test("allocatePublicStudentId: per-school counters are independent", async () => {
  const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";
  const db = new CounterMockDb({ [SCHOOL]: "DPSKKP", [SCHOOL_B]: "SVMHYD" });

  assertEquals(await allocatePublicStudentId(db, ORG, SCHOOL), "DPSKKP-0001");
  assertEquals(await allocatePublicStudentId(db, ORG, SCHOOL_B), "SVMHYD-0001");
  assertEquals(await allocatePublicStudentId(db, ORG, SCHOOL), "DPSKKP-0002");
  assertEquals(await allocatePublicStudentId(db, ORG, SCHOOL_B), "SVMHYD-0002");
});

Deno.test("allocatePublicStudentId: trims a padded school code before use", async () => {
  const db = new CounterMockDb({ [SCHOOL]: "  DPSKKP  " });
  assertEquals(await allocatePublicStudentId(db, ORG, SCHOOL), "DPSKKP-0001");
});

Deno.test("allocatePublicStudentId: throws SchoolCodeMissingError when code is NULL", async () => {
  const db = new CounterMockDb({ [SCHOOL_NO_CODE]: null });
  await assertRejects(
    () => allocatePublicStudentId(db, ORG, SCHOOL_NO_CODE),
    SchoolCodeMissingError,
    "has no code",
  );
});

Deno.test("allocatePublicStudentId: throws SchoolCodeMissingError when code is empty string", async () => {
  const db = new CounterMockDb({ [SCHOOL_NO_CODE]: "   " });
  await assertRejects(
    () => allocatePublicStudentId(db, ORG, SCHOOL_NO_CODE),
    SchoolCodeMissingError,
  );
});

Deno.test("allocatePublicStudentId: throws when the school row is not visible", async () => {
  // No school seeded at all — SELECT returns no rows, so no code -> error.
  const db = new CounterMockDb({});
  await assertRejects(
    () => allocatePublicStudentId(db, ORG, SCHOOL),
    SchoolCodeMissingError,
  );
});

Deno.test("PSID migration: schema, counter, backfill and immutability trigger present", async () => {
  const sql = await Deno.readTextFile(
    new URL(
      "../../../migrations/20260848000000_public_student_id.sql",
      import.meta.url,
    ),
  );

  // 1. Column + partial-unique index.
  assertStringIncludes(sql, "ADD COLUMN IF NOT EXISTS public_student_id TEXT");
  assertStringIncludes(sql, "CREATE UNIQUE INDEX IF NOT EXISTS uq_student_profiles_public_student_id");
  assertStringIncludes(sql, "WHERE public_student_id IS NOT NULL");

  // 2. Counter table + FORCE RLS + school-scope policy + grants.
  assertStringIncludes(sql, "CREATE TABLE IF NOT EXISTS school_public_id_counters");
  assertStringIncludes(sql, "next_seq INTEGER NOT NULL DEFAULT 1");
  assertStringIncludes(sql, "PRIMARY KEY (organization_id, school_id)");
  assertStringIncludes(sql, "ALTER TABLE school_public_id_counters FORCE ROW LEVEL SECURITY");
  assertStringIncludes(sql, "CREATE POLICY school_public_id_counters_school_scope");
  assertStringIncludes(sql, "app_current_scope() = 'school'");
  assertStringIncludes(sql, "GRANT SELECT, INSERT, UPDATE ON school_public_id_counters TO erp_tenant");

  // 3. Backfill: per-school row_number ordered by created_at then id, skips
  // schools without a code, guarded to be idempotent.
  assertStringIncludes(sql, "row_number() OVER");
  assertStringIncludes(sql, "ORDER BY sp.created_at, sp.id");
  assertStringIncludes(sql, "lpad(r.seq::text, 4, '0')");
  assertStringIncludes(sql, "WHERE sp.public_student_id IS NULL");
  assertStringIncludes(sql, "btrim(s.code) <> ''");

  // 4. Set-once immutability trigger.
  assertStringIncludes(sql, "CREATE OR REPLACE FUNCTION reject_public_student_id_change()");
  assertStringIncludes(sql, "OLD.public_student_id IS NOT NULL");
  assertStringIncludes(sql, "OLD.public_student_id IS DISTINCT FROM NEW.public_student_id");
  assertStringIncludes(sql, "public_student_id_immutable");
  assertStringIncludes(sql, "BEFORE UPDATE ON student_profiles");
});
