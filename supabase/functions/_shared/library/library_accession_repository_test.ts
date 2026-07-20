import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  WriteNotFoundError,
  WriteValidationError,
} from "../entity_write/module_write_handlers.ts";
import {
  accessionRowToApi,
  allocateAccessionNo,
  findByAccessionNo,
  formatAccessionCode,
  listRegister,
  parseAccessionNo,
  registerCopy,
  transitionCopyStatus,
} from "./library_accession_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const OTHER_SCHOOL = "a2000000-0000-4000-8000-000000000002";
const CATALOG = "bf100000-0000-4000-8000-000000000001";

type Row = Record<string, unknown>;

interface RegRow {
  id: string;
  organization_id: string;
  school_id: string;
  accession_no: number;
  catalog_id: string;
  isbn: string | null;
  title: string | null;
  acquired_date: string;
  cost: string;
  status: string;
  created_at: string;
  updated_at: string;
}

/**
 * Faithful in-memory model of the EXACT SQL the accession repository issues:
 *   - library_accession_counters ON CONFLICT arithmetic (mirrors school_tc_counters
 *     / allocatePublicStudentId): first alloc lands next_seq=2, RETURNING 1; a
 *     conflict bumps next_seq and RETURNS the pre-bump value. The read+write of
 *     the counter happens synchronously inside one queryObject call — modelling
 *     the row lock that serializes concurrent allocations, so a number is never
 *     reused.
 *   - library_accession_register INSERT (RETURNING the row) with the
 *     UNIQUE(org, school, accession_no) constraint (throws "duplicate key").
 *   - the guarded status UPDATE (WHERE status = ANY(allowedFrom)).
 *   - SELECT by accession_no / id, and the filtered/ordered list.
 * Lets the whole register be proven without a live Postgres.
 */
class AccessionMockDb {
  counters = new Map<string, number>();
  register: RegRow[] = [];
  private seq = 0;

  private counterKey(org: string, school: string): string {
    return `${org}|${school}`;
  }

  peekCounter(org = ORG, school = SCHOOL): number | undefined {
    return this.counters.get(this.counterKey(org, school));
  }

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // 1. counter ON CONFLICT — atomic per call (models the DO UPDATE row lock).
    if (sql.includes("INSERT INTO library_accession_counters")) {
      const key = this.counterKey(String(args[0]), String(args[1]));
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

    // 2. register INSERT (RETURNING the row); UNIQUE(org, school, accession_no).
    if (sql.includes("INSERT INTO library_accession_register")) {
      const [org, school, accessionNo, catalogId, isbn, title, acquiredDate, cost] = args as [
        string,
        string,
        number,
        string,
        string | null,
        string | null,
        string | null,
        number,
      ];
      const clash = this.register.find(
        (r) =>
          r.organization_id === org && r.school_id === school &&
          r.accession_no === Number(accessionNo),
      );
      if (clash) {
        throw new Error(
          `duplicate key value violates unique constraint "uq_library_accession_register_no"`,
        );
      }
      const row: RegRow = {
        id: crypto.randomUUID(),
        organization_id: org,
        school_id: school,
        accession_no: Number(accessionNo),
        catalog_id: catalogId,
        isbn: isbn ?? null,
        title: title ?? null,
        acquired_date: (acquiredDate ?? "2026-07-20"),
        cost: Number(cost).toFixed(2),
        status: "active",
        created_at: "2026-07-20T00:00:00.000Z",
        updated_at: "2026-07-20T00:00:00.000Z",
      };
      this.register.push(row);
      return [this.project(row)] as T[];
    }

    // 3. guarded status UPDATE (WHERE status = ANY(allowedFrom)).
    if (sql.includes("UPDATE library_accession_register") && sql.includes("SET status = $4")) {
      const [org, school, id, toStatus, allowedFrom] = args as [
        string,
        string,
        string,
        string,
        string[],
      ];
      const row = this.register.find(
        (r) => r.organization_id === org && r.school_id === school && r.id === id,
      );
      if (!row || !allowedFrom.includes(row.status)) return [] as T[];
      row.status = toStatus;
      row.updated_at = "2026-07-20T01:00:00.000Z";
      return [this.project(row)] as T[];
    }

    // 4. findById — SELECT ... AND id = $3::uuid
    if (
      sql.includes("FROM library_accession_register") && sql.includes("AND id = $3::uuid")
    ) {
      const [org, school, id] = args as [string, string, string];
      const row = this.register.find(
        (r) => r.organization_id === org && r.school_id === school && r.id === id,
      );
      return row ? [this.project(row)] as T[] : [] as T[];
    }

    // 5. findByAccessionNo — SELECT ... AND accession_no = $3
    if (
      sql.includes("FROM library_accession_register") && sql.includes("AND accession_no = $3")
    ) {
      const [org, school, no] = args as [string, string, number];
      const row = this.register.find(
        (r) =>
          r.organization_id === org && r.school_id === school &&
          r.accession_no === Number(no),
      );
      return row ? [this.project(row)] as T[] : [] as T[];
    }

    // 6. listRegister — SELECT ... ORDER BY accession_no DESC (with optional filters)
    if (
      sql.includes("FROM library_accession_register") && sql.includes("ORDER BY accession_no DESC")
    ) {
      const [org, school] = args as [string, string];
      let rows = this.register.filter(
        (r) => r.organization_id === org && r.school_id === school,
      );
      // Filters are appended positionally as $3, $4, ... in declaration order:
      // status, catalog_id, isbn. Re-derive them from the SQL text + args.
      let argIdx = 2;
      if (sql.includes("AND status = $")) {
        const status = String(args[argIdx++]);
        rows = rows.filter((r) => r.status === status);
      }
      if (sql.includes("AND catalog_id = $")) {
        const catalogId = String(args[argIdx++]);
        rows = rows.filter((r) => r.catalog_id === catalogId);
      }
      if (sql.includes("AND isbn = $")) {
        const isbn = String(args[argIdx++]);
        rows = rows.filter((r) => r.isbn === isbn);
      }
      rows = [...rows].sort((a, b) => b.accession_no - a.accession_no);
      return rows.map((r) => this.project(r)) as T[];
    }

    return [] as T[];
  }

  /** Mirror the SELECT projection (text casts on date/cost/timestamps). */
  private project(row: RegRow): Row {
    return {
      id: row.id,
      accession_no: row.accession_no,
      catalog_id: row.catalog_id,
      isbn: row.isbn,
      title: row.title,
      acquired_date: row.acquired_date,
      cost: row.cost,
      status: row.status,
      created_at: row.created_at,
      updated_at: row.updated_at,
    };
  }

  // deno-lint-ignore require-await
  async queryCount(): Promise<number> {
    return 0;
  }
}

function client(mock: AccessionMockDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

// ── formatAccessionCode / parseAccessionNo (pure) ────────────────────────────

Deno.test("formatAccessionCode: zero-pads to ACC-000001, grows past the pad", () => {
  assertEquals(formatAccessionCode(1), "ACC-000001");
  assertEquals(formatAccessionCode(42), "ACC-000042");
  assertEquals(formatAccessionCode(1234567), "ACC-1234567");
});

Deno.test("parseAccessionNo: accepts a bare integer or the ACC- code, rejects junk", () => {
  assertEquals(parseAccessionNo("42"), 42);
  assertEquals(parseAccessionNo("ACC-000042"), 42);
  assertEquals(parseAccessionNo("acc-7"), 7);
  assertEquals(parseAccessionNo("abc"), null);
  assertEquals(parseAccessionNo(""), null);
  assertEquals(parseAccessionNo("0"), null); // accession numbers start at 1
});

// ── Gapless, sequential, unique accession numbers ────────────────────────────

Deno.test("accession numbers are sequential and gapless (1, 2, 3 …) per library", async () => {
  const mock = new AccessionMockDb();
  const db = client(mock);
  const nos: number[] = [];
  for (let i = 0; i < 5; i++) {
    const row = await registerCopy(db, ORG, SCHOOL, { catalogId: CATALOG, cost: 100 });
    nos.push(row.accession_no);
  }
  assertEquals(nos, [1, 2, 3, 4, 5]); // sequential + gapless, first is 1
  assertEquals(mock.peekCounter(), 6); // next value to hand out
  assertEquals(mock.register.length, 5);
});

Deno.test("accession numbers are unique across many registrations", async () => {
  const mock = new AccessionMockDb();
  const db = client(mock);
  for (let i = 0; i < 20; i++) {
    await registerCopy(db, ORG, SCHOOL, { catalogId: CATALOG });
  }
  const nos = mock.register.map((r) => r.accession_no);
  assertEquals(new Set(nos).size, 20); // all distinct
  assertEquals([...nos].sort((a, b) => a - b), Array.from({ length: 20 }, (_, i) => i + 1));
});

Deno.test("CONCURRENT registration never reuses a number (the counter guard, not MAX+1)", async () => {
  const mock = new AccessionMockDb();
  const db = client(mock);
  // Fire 10 registrations concurrently. The counter's atomic ON CONFLICT bump
  // (row-lock in prod) hands each caller a DISTINCT number; a race-prone
  // MAX(accession_no)+1 would collide.
  const rows = await Promise.all(
    Array.from({ length: 10 }, () => registerCopy(db, ORG, SCHOOL, { catalogId: CATALOG })),
  );
  const nos = rows.map((r) => r.accession_no);
  assertEquals(new Set(nos).size, 10, "every concurrent registration got a distinct number");
  assertEquals(
    [...nos].sort((a, b) => a - b),
    Array.from({ length: 10 }, (_, i) => i + 1),
    "gapless 1..10 with no reuse",
  );
  assertEquals(mock.peekCounter(), 11);
});

Deno.test("allocateAccessionNo: each library (org, school) has its OWN independent run", async () => {
  const mock = new AccessionMockDb();
  const db = client(mock);
  assertEquals(await allocateAccessionNo(db, ORG, SCHOOL), 1);
  assertEquals(await allocateAccessionNo(db, ORG, SCHOOL), 2);
  // A different school starts its own accession run at 1 (per-library scope).
  assertEquals(await allocateAccessionNo(db, ORG, OTHER_SCHOOL), 1);
  assertEquals(await allocateAccessionNo(db, ORG, SCHOOL), 3);
  assertEquals(mock.peekCounter(ORG, SCHOOL), 4);
  assertEquals(mock.peekCounter(ORG, OTHER_SCHOOL), 2);
});

Deno.test("registerCopy: the UNIQUE(accession_no) constraint blocks a reused number", async () => {
  const mock = new AccessionMockDb();
  const db = client(mock);
  await registerCopy(db, ORG, SCHOOL, { catalogId: CATALOG });
  // Force a collision by pre-seeding accession_no 2 then rewinding the counter
  // so the next allocation also hands out 2 — the constraint must reject it.
  await registerCopy(db, ORG, SCHOOL, { catalogId: CATALOG }); // no. 2
  mock.counters.set(`${ORG}|${SCHOOL}`, 2); // rewind: next alloc will be 2 again
  await assertRejects(
    () => registerCopy(db, ORG, SCHOOL, { catalogId: CATALOG }),
    Error,
    "duplicate key",
  );
});

// ── registerCopy: snapshot + validation ──────────────────────────────────────

Deno.test("registerCopy: stores title ref, isbn/title snapshot, cost, acquired date, status active", async () => {
  const mock = new AccessionMockDb();
  const db = client(mock);
  const row = await registerCopy(db, ORG, SCHOOL, {
    catalogId: CATALOG,
    isbn: "978-1",
    title: "Algebra",
    acquiredDate: "2026-01-15",
    cost: 349.5,
  });
  assertEquals(row.accession_no, 1);
  assertEquals(row.catalog_id, CATALOG);
  assertEquals(row.isbn, "978-1");
  assertEquals(row.title, "Algebra");
  assertEquals(row.acquired_date, "2026-01-15");
  assertEquals(row.cost, "349.50");
  assertEquals(row.status, "active");
});

Deno.test("registerCopy: rejects a missing catalogId and a negative cost", async () => {
  const mock = new AccessionMockDb();
  const db = client(mock);
  await assertRejects(
    () => registerCopy(db, ORG, SCHOOL, { catalogId: "  " }),
    WriteValidationError,
    "catalogId is required",
  );
  await assertRejects(
    () => registerCopy(db, ORG, SCHOOL, { catalogId: CATALOG, cost: -5 }),
    WriteValidationError,
    "cost cannot be negative",
  );
});

// ── Register lookup ──────────────────────────────────────────────────────────

Deno.test("findByAccessionNo: returns the matching copy, null when absent", async () => {
  const mock = new AccessionMockDb();
  const db = client(mock);
  await registerCopy(db, ORG, SCHOOL, { catalogId: CATALOG, title: "A" });
  const second = await registerCopy(db, ORG, SCHOOL, { catalogId: CATALOG, title: "B" });

  const found = await findByAccessionNo(db, ORG, SCHOOL, 2);
  assertEquals(found?.id, second.id);
  assertEquals(found?.title, "B");
  assertEquals(found?.accession_no, 2);

  assertEquals(await findByAccessionNo(db, ORG, SCHOOL, 999), null);
  // A copy in one school is NOT visible under another school's scope.
  assertEquals(await findByAccessionNo(db, ORG, OTHER_SCHOOL, 2), null);
});

Deno.test("listRegister: newest accession first, filterable by status and title", async () => {
  const mock = new AccessionMockDb();
  const db = client(mock);
  await registerCopy(db, ORG, SCHOOL, { catalogId: CATALOG, title: "A" }); // no.1
  const c2 = await registerCopy(db, ORG, SCHOOL, { catalogId: "cat-2", title: "B" }); // no.2
  await registerCopy(db, ORG, SCHOOL, { catalogId: CATALOG, title: "A" }); // no.3

  const all = await listRegister(db, ORG, SCHOOL);
  assertEquals(all.map((r) => r.accession_no), [3, 2, 1]); // DESC

  const byCatalog = await listRegister(db, ORG, SCHOOL, { catalogId: CATALOG });
  assertEquals(byCatalog.map((r) => r.accession_no), [3, 1]);

  // Withdraw no.2, then filter by status.
  await transitionCopyStatus(db, ORG, SCHOOL, c2.id, "withdrawn");
  const active = await listRegister(db, ORG, SCHOOL, { status: "active" });
  assertEquals(active.map((r) => r.accession_no), [3, 1]);
  const withdrawn = await listRegister(db, ORG, SCHOOL, { status: "withdrawn" });
  assertEquals(withdrawn.map((r) => r.accession_no), [2]);
});

// ── Status transitions (active | lost | withdrawn), guarded ──────────────────

Deno.test("transitionCopyStatus: active -> lost and active -> withdrawn", async () => {
  const mock = new AccessionMockDb();
  const db = client(mock);
  const a = await registerCopy(db, ORG, SCHOOL, { catalogId: CATALOG });
  const b = await registerCopy(db, ORG, SCHOOL, { catalogId: CATALOG });

  const lost = await transitionCopyStatus(db, ORG, SCHOOL, a.id, "lost");
  assertEquals(lost.status, "lost");
  const withdrawn = await transitionCopyStatus(db, ORG, SCHOOL, b.id, "withdrawn");
  assertEquals(withdrawn.status, "withdrawn");
});

Deno.test("transitionCopyStatus: a lost copy may still be withdrawn (lost -> withdrawn)", async () => {
  const mock = new AccessionMockDb();
  const db = client(mock);
  const a = await registerCopy(db, ORG, SCHOOL, { catalogId: CATALOG });
  await transitionCopyStatus(db, ORG, SCHOOL, a.id, "lost");
  const withdrawn = await transitionCopyStatus(db, ORG, SCHOOL, a.id, "withdrawn");
  assertEquals(withdrawn.status, "withdrawn");
});

Deno.test("transitionCopyStatus: re-marking a terminal copy is rejected (guard = 0 rows)", async () => {
  const mock = new AccessionMockDb();
  const db = client(mock);
  const a = await registerCopy(db, ORG, SCHOOL, { catalogId: CATALOG });
  await transitionCopyStatus(db, ORG, SCHOOL, a.id, "withdrawn");
  // withdrawn is terminal — cannot be marked lost afterwards.
  const err = await assertRejects(
    () => transitionCopyStatus(db, ORG, SCHOOL, a.id, "lost"),
    WriteValidationError,
    "currently 'withdrawn'",
  );
  assertEquals((err as WriteValidationError).status, 409);
  // The row was NOT mutated by the rejected transition.
  assertEquals((await findByAccessionNo(db, ORG, SCHOOL, 1))?.status, "withdrawn");
});

Deno.test("transitionCopyStatus: marking the SAME status twice is rejected (idempotent-safe guard)", async () => {
  const mock = new AccessionMockDb();
  const db = client(mock);
  const a = await registerCopy(db, ORG, SCHOOL, { catalogId: CATALOG });
  await transitionCopyStatus(db, ORG, SCHOOL, a.id, "lost");
  await assertRejects(
    () => transitionCopyStatus(db, ORG, SCHOOL, a.id, "lost"),
    WriteValidationError,
    "already ",
  );
});

Deno.test("transitionCopyStatus: an invalid target status is rejected", async () => {
  const mock = new AccessionMockDb();
  const db = client(mock);
  const a = await registerCopy(db, ORG, SCHOOL, { catalogId: CATALOG });
  await assertRejects(
    () => transitionCopyStatus(db, ORG, SCHOOL, a.id, "active"),
    WriteValidationError,
    "must be one of: lost, withdrawn",
  );
  await assertRejects(
    () => transitionCopyStatus(db, ORG, SCHOOL, a.id, "destroyed"),
    WriteValidationError,
    "must be one of: lost, withdrawn",
  );
});

Deno.test("transitionCopyStatus: an unknown copy id -> 404 not found", async () => {
  const mock = new AccessionMockDb();
  const db = client(mock);
  await assertRejects(
    () =>
      transitionCopyStatus(db, ORG, SCHOOL, "ffffffff-0000-4000-8000-000000000000", "lost"),
    WriteNotFoundError,
    "not found",
  );
});

// ── accessionRowToApi mapping ────────────────────────────────────────────────

Deno.test("accessionRowToApi: adds the display code, numeric cost, snapshots", async () => {
  const mock = new AccessionMockDb();
  const db = client(mock);
  const row = await registerCopy(db, ORG, SCHOOL, {
    catalogId: CATALOG,
    isbn: "978-9",
    title: "Physics",
    cost: 500,
  });
  const api = accessionRowToApi(row);
  assertEquals(api.accessionNo, 1);
  assertEquals(api.accessionCode, "ACC-000001");
  assertEquals(api.catalogId, CATALOG);
  assertEquals(api.isbn, "978-9");
  assertEquals(api.title, "Physics");
  assertEquals(api.cost, 500); // number, not the "500.00" text
  assertEquals(api.status, "active");
});

// ── Migration shape (register table + counter + RLS + grants + CHECK) ─────────

Deno.test("accession migration: register + counter tables, RLS, grants, CHECK present", async () => {
  const migration = await Deno.readTextFile(
    new URL("../../../migrations/20260900000025_library_accession.sql", import.meta.url),
  );

  // 1. Per-(org, school) never-reused counter (mirrors school_tc_counters).
  assertStringIncludes(migration, "CREATE TABLE IF NOT EXISTS library_accession_counters");
  assertStringIncludes(migration, "next_seq INTEGER NOT NULL DEFAULT 1");
  assertStringIncludes(migration, "PRIMARY KEY (organization_id, school_id)");
  assertStringIncludes(migration, "ALTER TABLE library_accession_counters FORCE ROW LEVEL SECURITY");
  assertStringIncludes(migration, "CREATE POLICY library_accession_counters_school_scope");
  assertStringIncludes(
    migration,
    "GRANT SELECT, INSERT, UPDATE ON library_accession_counters TO erp_tenant",
  );

  // 2. The per-copy register.
  assertStringIncludes(migration, "CREATE TABLE IF NOT EXISTS library_accession_register");
  assertStringIncludes(migration, "accession_no INTEGER NOT NULL CHECK (accession_no > 0)");
  assertStringIncludes(migration, "status IN ('active', 'lost', 'withdrawn')");
  assertStringIncludes(migration, "CREATE UNIQUE INDEX IF NOT EXISTS uq_library_accession_register_no");
  assertStringIncludes(migration, "ALTER TABLE library_accession_register FORCE ROW LEVEL SECURITY");
  assertStringIncludes(migration, "CREATE POLICY library_accession_register_school_scope");
  assertStringIncludes(migration, "app_current_scope() = 'school'");
  // A copy is withdrawn, never deleted — SELECT/INSERT/UPDATE only, NO DELETE.
  assertStringIncludes(
    migration,
    "GRANT SELECT, INSERT, UPDATE ON library_accession_register TO erp_tenant",
  );
  assertEquals(migration.includes("DELETE ON library_accession_register"), false);
});
