// PRA-P0-01 (S2) — revocation primitive contract tests (DB-free).
//
// A chainable fake stands in for the supabase-js service client: it records the
// table, the update values, and the filter predicates of each call, and resolves
// `.select()` to a canned row set. We assert the three writes fire with the
// right values + scoping, that the counts are reported, and that idempotency /
// no-session short-circuits hold.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { revokeUserAccess } from "./identity_revocation.ts";

interface RecordedOp {
  table: string;
  type: "update" | "read";
  values?: Record<string, unknown>;
  filters: Array<[string, string, unknown]>;
}

function fakeClient(canned: Record<string, Array<{ id: string }>>) {
  const calls: RecordedOp[] = [];
  const client = {
    from(table: string) {
      const op: RecordedOp = { table, type: "read", filters: [] };
      const builder = {
        update(values: Record<string, unknown>) {
          op.type = "update";
          op.values = values;
          return builder;
        },
        eq(c: string, v: unknown) {
          op.filters.push(["eq", c, v]);
          return builder;
        },
        neq(c: string, v: unknown) {
          op.filters.push(["neq", c, v]);
          return builder;
        },
        is(c: string, v: unknown) {
          op.filters.push(["is", c, v]);
          return builder;
        },
        in(c: string, v: unknown) {
          op.filters.push(["in", c, v]);
          return builder;
        },
        select(_cols?: string) {
          return builder;
        },
        // Thenable: awaiting the builder records the op and returns the rows.
        then(resolve: (r: { data: Array<{ id: string }>; error: null }) => void) {
          calls.push(op);
          resolve({ data: canned[op.table] ?? [], error: null });
        },
      };
      return builder;
    },
  };
  return { client: client as unknown as SupabaseClient, calls };
}

function filterHas(
  op: RecordedOp | undefined,
  kind: string,
  col: string,
  val: unknown,
): boolean {
  // Deep-compare the value so array predicates (`.in(...)`) match by contents,
  // not by reference.
  const want = JSON.stringify(val);
  return !!op?.filters.some((f) =>
    f[0] === kind && f[1] === col && JSON.stringify(f[2]) === want
  );
}

Deno.test("PRA-P0-01: revoke sweeps sessions + refresh tokens + flips membership", async () => {
  const { client, calls } = fakeClient({
    sessions: [{ id: "s1" }, { id: "s2" }],
    refresh_tokens: [{ id: "r1" }, { id: "r2" }, { id: "r3" }],
    school_memberships: [{ id: "m1" }],
  });

  const result = await revokeUserAccess(client, {
    organizationId: "org-1",
    schoolId: "sch-1",
    userId: "user-1",
    reason: "HR offboarding",
  });

  assertEquals(result.sessionsRevoked, 2);
  assertEquals(result.refreshTokensRevoked, 3);
  assertEquals(result.membershipsRevoked, 1);

  // Sessions: scoped to (user, school) and only live rows, revoked_at stamped.
  const sess = calls.find((c) => c.table === "sessions");
  assert(sess?.values?.revoked_at != null, "sessions.revoked_at must be set");
  assert(filterHas(sess, "eq", "user_id", "user-1"));
  assert(filterHas(sess, "eq", "context_school_id", "sch-1"));
  assert(filterHas(sess, "is", "revoked_at", null));

  // Refresh tokens: scoped to exactly the revoked session ids.
  const rt = calls.find((c) => c.table === "refresh_tokens");
  assert(rt?.values?.revoked_at != null);
  assert(filterHas(rt, "in", "session_id", ["s1", "s2"]));

  // Membership: flipped to 'revoked', scoped, idempotency guard present.
  const mem = calls.find((c) => c.table === "school_memberships");
  assertEquals(mem?.values?.status, "revoked");
  assert(filterHas(mem, "eq", "user_id", "user-1"));
  assert(filterHas(mem, "eq", "school_id", "sch-1"));
  assert(filterHas(mem, "neq", "status", "revoked"));
});

Deno.test("PRA-P0-01: no live sessions → refresh_tokens is never touched", async () => {
  const { client, calls } = fakeClient({
    sessions: [],
    school_memberships: [{ id: "m1" }],
  });

  const result = await revokeUserAccess(client, {
    organizationId: "org-1",
    schoolId: "sch-1",
    userId: "user-1",
  });

  assertEquals(result.sessionsRevoked, 0);
  assertEquals(result.refreshTokensRevoked, 0);
  assertEquals(result.membershipsRevoked, 1);
  assertEquals(calls.some((c) => c.table === "refresh_tokens"), false);
});

Deno.test("PRA-P0-01: idempotent re-run reports zero (guards match nothing)", async () => {
  const { client } = fakeClient({
    sessions: [],
    school_memberships: [],
  });

  const result = await revokeUserAccess(client, {
    organizationId: "org-1",
    schoolId: "sch-1",
    userId: "user-1",
  });

  assertEquals(result.sessionsRevoked, 0);
  assertEquals(result.refreshTokensRevoked, 0);
  assertEquals(result.membershipsRevoked, 0);
});
