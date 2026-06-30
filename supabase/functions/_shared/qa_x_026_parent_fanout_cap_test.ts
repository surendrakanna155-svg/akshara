// QA-X-026 — Parent fan-out / dashboard aggregation cap (Deno contract test).
//
// `supabase/functions/_shared/auth_context.ts` defines
//   const PARENT_FANOUT_LIMIT = 50;
// and applies `.limit(PARENT_FANOUT_LIMIT)` to the guardian children fan-out
// queries (RT-34). This bounds the worst-case parent-login / child-switcher
// aggregation so an outlier (or abusive) guardian account with hundreds of
// linked students cannot trigger an unbounded O(cohort) read.
//
// This is a contract test: it fakes the Supabase query client to (a) CAPTURE
// the `.limit(...)` argument applied to each table, and (b) return MORE than
// 50 rows from those queries, then asserts that:
//   - every fan-out query is bounded by exactly 50, and
//   - a large cohort is bounded — the cap is real, not advisory.
//
// It exercises the exported `loadChildProfiles`, which is the function that
// applies `.limit(PARENT_FANOUT_LIMIT)` to both the `students` and
// `sis_student_enrollments` fan-out reads.
import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { loadChildProfiles } from "./auth_context.ts";

// The contract under test (kept in sync with auth_context.ts RT-34 constant).
const EXPECTED_CAP = 50;

interface CapturedQuery {
  table: string;
  /** The argument passed to `.limit(...)`, or null if never called. */
  limit: number | null;
  /** Number of rows the fake returned for this query. */
  returnedRows: number;
}

/**
 * Minimal fake of the Supabase JS query builder. Each terminal builder method
 * (`.in`, `.eq`, `.select`, `.limit`) returns `this` so the chain matches the
 * real fluent API used in auth_context.ts. The builder is awaitable (thenable)
 * and resolves to `{ data, error }` like the real client.
 *
 * `rowsForTable` lets the test inject an OVER-CAP result set so we can prove
 * the cap actually bounds a large cohort rather than merely being requested.
 */
class FakeQueryBuilder {
  limitArg: number | null = null;

  constructor(
    private readonly table: string,
    private readonly rows: Record<string, unknown>[],
    private readonly capture: CapturedQuery,
  ) {}

  select(_columns: string): this {
    return this;
  }

  in(_column: string, _values: unknown[]): this {
    return this;
  }

  eq(_column: string, _value: unknown): this {
    return this;
  }

  limit(n: number): this {
    this.limitArg = n;
    this.capture.limit = n;
    return this;
  }

  // The real client applies the limit server-side; the fake mirrors that so
  // the rows it hands back are the BOUNDED set the production query would see.
  private resolve(): { data: Record<string, unknown>[]; error: null } {
    const bounded = this.limitArg == null
      ? this.rows
      : this.rows.slice(0, this.limitArg);
    this.capture.returnedRows = bounded.length;
    return { data: bounded, error: null };
  }

  // Make the builder awaitable like the real PostgREST builder.
  then<TResult1 = { data: Record<string, unknown>[]; error: null }>(
    onfulfilled?:
      | ((value: { data: Record<string, unknown>[]; error: null }) => TResult1 | PromiseLike<TResult1>)
      | null,
  ): Promise<TResult1> {
    return Promise.resolve(this.resolve()).then(onfulfilled);
  }
}

class FakeSupabaseClient {
  readonly captured: CapturedQuery[] = [];

  constructor(
    /** How many rows each table should pretend to hold (pre-cap). */
    private readonly rowCountByTable: Record<string, number>,
  ) {}

  from(table: string) {
    const count = this.rowCountByTable[table] ?? 0;
    const rows = Array.from({ length: count }, (_, i) => ({
      id: `id-${i}`,
      student_id: `id-${i}`,
      display_name: `Student ${i}`,
      class_name: "Grade 5",
      section_name: "A",
    }));
    const capture: CapturedQuery = {
      table,
      limit: null,
      returnedRows: 0,
    };
    this.captured.push(capture);
    return new FakeQueryBuilder(table, rows, capture);
  }
}

Deno.test("QA-X-026 loadChildProfiles applies the 50-row fan-out cap to the students query", async () => {
  // A pathological cohort: 500 linked children (10x the cap).
  const cohort = 500;
  const childIds = Array.from({ length: cohort }, (_, i) => `id-${i}`);

  // Tables return WAY more than the cap, so a missing/ineffective limit would
  // surface as >50 processed rows.
  const fake = new FakeSupabaseClient({
    students: cohort,
    sis_student_enrollments: cohort,
  });

  // deno-lint-ignore no-explicit-any
  await loadChildProfiles(fake as any, childIds);

  const students = fake.captured.find((c) => c.table === "students");
  assert(students, "expected a query against the students table");
  assertEquals(
    students!.limit,
    EXPECTED_CAP,
    "students fan-out must be bounded by PARENT_FANOUT_LIMIT (50)",
  );
  assert(
    students!.returnedRows <= EXPECTED_CAP,
    `students query processed ${students!.returnedRows} rows; cap must bound it to ${EXPECTED_CAP}`,
  );
});

Deno.test("QA-X-026 loadChildProfiles applies the 50-row fan-out cap to the enrollments query", async () => {
  const cohort = 500;
  const childIds = Array.from({ length: cohort }, (_, i) => `id-${i}`);

  const fake = new FakeSupabaseClient({
    students: cohort,
    sis_student_enrollments: cohort,
  });

  // deno-lint-ignore no-explicit-any
  await loadChildProfiles(fake as any, childIds);

  const enrollments = fake.captured.find(
    (c) => c.table === "sis_student_enrollments",
  );
  assert(enrollments, "expected a query against sis_student_enrollments");
  assertEquals(
    enrollments!.limit,
    EXPECTED_CAP,
    "enrollment fan-out must be bounded by PARENT_FANOUT_LIMIT (50)",
  );
  assert(
    enrollments!.returnedRows <= EXPECTED_CAP,
    `enrollment query processed ${enrollments!.returnedRows} rows; cap must bound it to ${EXPECTED_CAP}`,
  );
});

Deno.test("QA-X-026 every fan-out query that hits the DB is bounded by the cap (no unbounded read)", async () => {
  const cohort = 1000; // 20x the cap
  const childIds = Array.from({ length: cohort }, (_, i) => `id-${i}`);

  const fake = new FakeSupabaseClient({
    students: cohort,
    sis_student_enrollments: cohort,
  });

  // deno-lint-ignore no-explicit-any
  await loadChildProfiles(fake as any, childIds);

  // Each captured query that reached a table must carry the cap and must not
  // have processed more than 50 rows. This is the systemic assertion: there is
  // no fan-out path in loadChildProfiles that escapes the bound.
  assert(fake.captured.length >= 2, "expected the students + enrollments reads");
  for (const q of fake.captured) {
    assertEquals(
      q.limit,
      EXPECTED_CAP,
      `query against ${q.table} was not bounded by the fan-out cap`,
    );
    assert(
      q.returnedRows <= EXPECTED_CAP,
      `query against ${q.table} processed ${q.returnedRows} rows (> cap ${EXPECTED_CAP})`,
    );
  }
});

Deno.test("QA-X-026 cap is a hard ceiling — a sub-cap cohort is unaffected", async () => {
  // A normal family (3 children) must pass through untouched: the cap is an
  // upper bound, not a forced minimum.
  const childIds = ["id-0", "id-1", "id-2"];
  const fake = new FakeSupabaseClient({
    students: 3,
    sis_student_enrollments: 3,
  });

  // deno-lint-ignore no-explicit-any
  const profiles = await loadChildProfiles(fake as any, childIds);

  assertEquals(profiles.length, 3, "all 3 real children resolved");
  for (const q of fake.captured) {
    // The limit is still applied (50), but it never truncates a small cohort.
    assertEquals(q.limit, EXPECTED_CAP);
    assert(q.returnedRows <= 3);
  }
});

Deno.test("QA-X-026 empty cohort short-circuits without any fan-out query", async () => {
  const fake = new FakeSupabaseClient({});
  // deno-lint-ignore no-explicit-any
  const profiles = await loadChildProfiles(fake as any, []);
  assertEquals(profiles.length, 0);
  assertEquals(fake.captured.length, 0, "no DB read for an empty child list");
});
