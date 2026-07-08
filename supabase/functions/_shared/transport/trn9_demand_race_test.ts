// Gap-sweep wave 2 · step 2 (money-adjacent hardening) — TRN-9 duplicate-demand
// race.
//
// FINDING (verified before this wave): handleRaiseTransportDemand
// (transport_write_handlers.ts, ~L1310) dedupes a raised Finance transport-fee
// demand on dedupeKey = sisStudentId::routeId::academicYear::term via a plain
// read-then-write (writeStore.findAll(...).find(...) THEN writeStore.insert
// (...)). That is a TOCTOU: two concurrent identical raise-demand requests can
// both pass the read check before either has written, and both insert a
// `demand` row for the same tuple. Money itself is contained downstream
// (Finance's assignment uniqueness blocks a double-invoice), but a duplicate
// `demand` entity row is still a data-integrity defect.
//
// FIX (this wave):
//   1. New migration 20260861000000_transport_demand_dedupe_uniq.sql adds a
//      PARTIAL unique index — one demand per (organization, school,
//      dedupeKey), scoped to entity_type='demand' rows that HAVE a dedupeKey
//      (payload ? 'dedupeKey'), so legacy demand rows without the key are
//      never collapsed and no other transport_entities type is constrained.
//   2. insertDemandIdempotent (exported from transport_write_handlers.ts)
//      wraps the demand INSERT in a SAVEPOINT; on a 23505 (unique_violation)
//      it rolls back to the savepoint (keeping the surrounding
//      withTenantContext transaction alive) and RE-READS the winning row,
//      returning it idempotently — the racing LOSER's request is never a 500.
//      A non-unique-violation error is rethrown untouched.
//   3. handleRaiseTransportDemand now calls insertDemandIdempotent instead of
//      writeStore.insert directly, and returns the SAME idempotent 200 shape
//      the fast-path read-check already returns when the race backstop fires
//      (never a fresh audit event for the racing loser — the winner's insert
//      already owns the audit trail).
//
// Proven DB-free here (same fake-TenantQueryClient seam as
// admissions_enrollment_idempotency_test.ts / pilot_homework_test.ts):
//   • a clean insert (no concurrent writer) returns idempotent:false;
//   • a 23505 on insert recovers the PRE-SEEDED winning row idempotently, with
//     NO duplicate row ever persisted;
//   • a non-unique-violation error (e.g. a connection reset) is rethrown, not
//     swallowed into a false idempotent success;
//   • HANDLER WIRING (static-source) — handleRaiseTransportDemand calls
//     insertDemandIdempotent and branches on `.idempotent` before emitting the
//     transport.demand.raised audit.
//
// REMAINDER (documented, not built here): a REAL concurrent-request proof (two
// actual simultaneous HTTP calls racing on a live Postgres connection pool)
// needs the live lane (ERP_TENANT_DATABASE_URL). The DB constraint + handler
// catch here are the code-level fix; the live concurrency proof is a
// follow-up for the live cert.

import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { insertDemandIdempotent } from "./transport_write_handlers.ts";

const ORG = "b1000000-0000-4000-8000-000000000001";
const SCHOOL = "b2000000-0000-4000-8000-000000000001";

type Row = Record<string, unknown>;

/**
 * Fake transport_entities store that can simulate the transport_entities_
 * demand_dedupe_key_uniq partial index firing a 23505 on the NEXT insert —
 * exactly the shape Postgres raises (code on the error, and duplicated under
 * `.fields.code` the way the pg driver surfaces it), mirroring
 * admissions_enrollment_idempotency_test.ts's MockEnrollmentDb.
 */
class MockDemandRaceDb {
  rows: Array<
    { id: string; organization_id: string; school_id: string; entity_type: string; payload: Row }
  > = [];
  insertAttempts = 0;
  failNextInsert = false;

  private uniqueViolation(): Error {
    const err = new Error(
      'duplicate key value violates unique constraint "transport_entities_demand_dedupe_key_uniq"',
    ) as Error & { code: string; fields: { code: string } };
    err.code = "23505";
    err.fields = { code: "23505" };
    return err;
  }

  // deno-lint-ignore no-explicit-any
  async queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    if (
      sql.startsWith("SAVEPOINT") ||
      sql.startsWith("RELEASE SAVEPOINT") ||
      sql.startsWith("ROLLBACK TO SAVEPOINT")
    ) {
      return [] as T[];
    }
    if (sql.includes("INSERT INTO transport_entities")) {
      this.insertAttempts += 1;
      if (this.failNextInsert) {
        this.failNextInsert = false;
        throw this.uniqueViolation();
      }
      const row = {
        id: args[0] as string,
        organization_id: args[1] as string,
        school_id: args[2] as string,
        entity_type: args[3] as string,
        payload: JSON.parse(args[4] as string) as Row,
      };
      this.rows.push(row);
      return [{ payload: row.payload }] as T[];
    }
    if (sql.includes("ORDER BY id")) {
      const items = this.rows.filter((r) =>
        r.organization_id === args[0] && r.school_id === args[1] &&
        r.entity_type === args[2]
      );
      return items.map((r) => ({ payload: r.payload })) as T[];
    }
    throw new Error(`Unhandled SQL in MockDemandRaceDb: ${sql.slice(0, 80)}`);
  }
}

function db(mock: MockDemandRaceDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

Deno.test("TRN-9 race: a clean insert (no concurrent writer) returns idempotent:false and persists exactly one row", async () => {
  const mock = new MockDemandRaceDb();
  const dedupeKey = "SIS-1::r1::2026-27::annual";
  const result = await insertDemandIdempotent(
    db(mock),
    ORG,
    SCHOOL,
    dedupeKey,
    "d1",
    { id: "d1", dedupeKey, invoiceId: "inv-1" },
  );
  assertEquals(result.idempotent, false);
  assertEquals(result.saved.id, "d1");
  assertEquals(mock.insertAttempts, 1);
  assertEquals(mock.rows.length, 1);
});

Deno.test("TRN-9 race: a 23505 on insert (racing concurrent double-submit) recovers the WINNING row idempotently — never a 500, never a duplicate row", async () => {
  const mock = new MockDemandRaceDb();
  const dedupeKey = "SIS-1::r1::2026-27::annual";
  // Seed the winner as if a CONCURRENT request already committed it between
  // this request's fast-path read-check and its own insert.
  mock.rows.push({
    id: "winner-demand",
    organization_id: ORG,
    school_id: SCHOOL,
    entity_type: "demand",
    payload: { id: "winner-demand", dedupeKey, invoiceId: "inv-winner" },
  });
  mock.failNextInsert = true;

  const result = await insertDemandIdempotent(
    db(mock),
    ORG,
    SCHOOL,
    dedupeKey,
    "d2-loser",
    { id: "d2-loser", dedupeKey, invoiceId: "inv-loser" },
  );

  assertEquals(result.idempotent, true);
  assertEquals(result.saved.id, "winner-demand");
  assertEquals(result.saved.invoiceId, "inv-winner");
  // Only the pre-seeded winner exists — the loser's row was never persisted.
  assertEquals(mock.rows.length, 1);
});

Deno.test("TRN-9 race: a NON-unique-violation insert error is rethrown untouched, not swallowed into a false idempotent success", async () => {
  class ThrowingDb {
    // deno-lint-ignore no-explicit-any require-await
    async queryObject<T>(sql: string, _args: any[] = []): Promise<T[]> {
      if (sql.startsWith("SAVEPOINT") || sql.startsWith("RELEASE SAVEPOINT")) {
        return [] as T[];
      }
      if (sql.includes("INSERT INTO transport_entities")) {
        throw new Error("connection reset by peer");
      }
      return [] as T[];
    }
  }
  await assertRejects(
    () =>
      insertDemandIdempotent(
        new ThrowingDb() as unknown as TenantQueryClient,
        ORG,
        SCHOOL,
        "k",
        "d3",
        { id: "d3" },
      ),
    Error,
    "connection reset",
  );
});

Deno.test("TRN-9 race: a 23505 with NO matching winner row rethrows the original error (never fabricates a fake success)", async () => {
  // Pathological case: the unique index fired but the re-read can't find a
  // row with this dedupeKey (e.g. a same-key row that predates the
  // dedupeKey column, excluded by the partial index's own `payload ?
  // 'dedupeKey'` guard). insertDemandIdempotent must not invent a fake
  // "saved" value — it rethrows so the caller surfaces a real error.
  const mock = new MockDemandRaceDb();
  mock.failNextInsert = true;
  await assertRejects(
    () =>
      insertDemandIdempotent(
        db(mock),
        ORG,
        SCHOOL,
        "no-winner-key",
        "d4",
        { id: "d4", dedupeKey: "no-winner-key" },
      ),
  );
});

// ---------------------------------------------------------------------------
// Handler wiring (static-source, DB-free) — same convention as
// qw4_exam_publish_audit_test.ts / qa_x_033_exam_results_antitamper_test.ts.
// ---------------------------------------------------------------------------

Deno.test("TRN-9 race (handler wiring): handleRaiseTransportDemand calls insertDemandIdempotent and branches on .idempotent before auditing", async () => {
  const src = await Deno.readTextFile(
    new URL("./transport_write_handlers.ts", import.meta.url),
  );
  assertStringIncludes(src, "insertDemandIdempotent(");
  assertStringIncludes(src, "if (idempotent)");

  // The idempotent branch must return BEFORE the moduleEntityAudit emit runs,
  // so the racing loser's request is never freshly audited as a new raise.
  const idempotentCheck = src.indexOf("if (idempotent)");
  const auditEmit = src.indexOf('moduleEntityAudit("transport.demand.raised"');
  if (idempotentCheck < 0 || auditEmit < 0 || idempotentCheck > auditEmit) {
    throw new Error(
      "expected the idempotent short-circuit to precede the transport.demand.raised audit",
    );
  }
});
