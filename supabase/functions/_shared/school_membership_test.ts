// PLAT-0 (W2) — Multi-school identity: authorization + selector contract tests
// (DB-free). These prove the SECURITY-CRITICAL decisions the switch chokepoint
// depends on, exactly as the caller asked:
//   • a multi-school user switching to a NON-MEMBER school is DENIED (403);
//   • a single-membership user resolves to their one school;
//   • a zero-membership user resolves to no school context;
//   • a multi-school user with no named school must EXPLICITLY select (409),
//     never a silent pick;
//   • `listActiveSchoolMemberships` filters by user + active status and returns
//     a DETERMINISTIC order (the source of truth for both selector and gate).
//
// The switch handler asserts membership through exactly these pure functions, so
// proving them here proves the boundary the live enforced-isolation probe then
// exercises end-to-end.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  assertActiveSchoolMembership,
  listActiveSchoolMemberships,
  resolveSchoolSelection,
  type SchoolMembershipSummary,
  schoolSelectionDenial,
} from "./school_membership.ts";

function membership(
  schoolId: string,
  overrides: Partial<SchoolMembershipSummary> = {},
): SchoolMembershipSummary {
  return {
    membershipId: `m-${schoolId}`,
    schoolId,
    schoolName: `School ${schoolId}`,
    schoolCode: `CODE-${schoolId}`,
    organizationId: "org-1",
    role: "teacher",
    permissionsVersion: 1,
    ...overrides,
  };
}

const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";
const SCHOOL_C_NOT_MEMBER = "a2000000-0000-4000-8000-000000000009";

// ─── resolveSchoolSelection — the core decision ───────────────────────────────

Deno.test("zero memberships resolve to no school context (none)", () => {
  assertEquals(resolveSchoolSelection([], undefined), { kind: "none" });
  // A requested school with no memberships is still 'none' (nothing to be a
  // member of) — never resolved.
  assertEquals(resolveSchoolSelection([], SCHOOL_A), { kind: "none" });
});

Deno.test("single membership resolves to it (with or without a named school)", () => {
  const one = [membership(SCHOOL_A)];

  const implicit = resolveSchoolSelection(one, undefined);
  assertEquals(implicit.kind, "resolved");
  if (implicit.kind === "resolved") assertEquals(implicit.membership.schoolId, SCHOOL_A);

  const explicit = resolveSchoolSelection(one, SCHOOL_A);
  assertEquals(explicit.kind, "resolved");
  if (explicit.kind === "resolved") assertEquals(explicit.membership.schoolId, SCHOOL_A);
});

Deno.test("SECURITY: switching to a NON-MEMBER school is forbidden (→ 403)", () => {
  const memberships = [membership(SCHOOL_A), membership(SCHOOL_B)];

  const selection = resolveSchoolSelection(memberships, SCHOOL_C_NOT_MEMBER);
  assertEquals(selection.kind, "forbidden");

  const denial = schoolSelectionDenial(selection);
  assert(denial, "a forbidden selection must produce a denial");
  assertEquals(denial!.status, 403);
  assertEquals(denial!.code, "CONTEXT_FORBIDDEN");

  // Even with only one membership, a different school is never resolved.
  const single = resolveSchoolSelection([membership(SCHOOL_A)], SCHOOL_C_NOT_MEMBER);
  assertEquals(single.kind, "forbidden");
});

Deno.test("multi-school + no named school requires an EXPLICIT selection (→ 409), never a silent pick", () => {
  const memberships = [membership(SCHOOL_A), membership(SCHOOL_B)];
  const selection = resolveSchoolSelection(memberships, undefined);
  assertEquals(selection.kind, "selection_required");

  const denial = schoolSelectionDenial(selection);
  assert(denial);
  assertEquals(denial!.status, 409);
  assertEquals(denial!.code, "SCHOOL_SELECTION_REQUIRED");
  // Options are exactly the caller's own memberships (no cross-tenant data).
  assertEquals(denial!.options?.map((o) => o.schoolId).sort(), [SCHOOL_A, SCHOOL_B]);
});

Deno.test("multi-school + a named MEMBER school resolves to exactly that school", () => {
  const memberships = [membership(SCHOOL_A), membership(SCHOOL_B)];
  const selection = resolveSchoolSelection(memberships, SCHOOL_B);
  assertEquals(selection.kind, "resolved");
  if (selection.kind === "resolved") assertEquals(selection.membership.schoolId, SCHOOL_B);
  // A resolved selection is never a denial.
  assertEquals(schoolSelectionDenial(selection), null);
});

// ─── assertActiveSchoolMembership — the named defense-in-depth gate ────────────

Deno.test("assertActiveSchoolMembership: true only for a held membership", () => {
  const memberships = [membership(SCHOOL_A), membership(SCHOOL_B)];
  assert(assertActiveSchoolMembership(memberships, SCHOOL_A));
  assert(assertActiveSchoolMembership(memberships, SCHOOL_B));
  assert(!assertActiveSchoolMembership(memberships, SCHOOL_C_NOT_MEMBER));
  assert(!assertActiveSchoolMembership([], SCHOOL_A));
});

// ─── listActiveSchoolMemberships — IO shape + filters (fake client) ───────────
//
// A chainable fake stands in for the supabase-js service client (same pattern as
// identity_revocation_test.ts). It records the table + filter predicates and the
// order-by chain, and resolves to canned rows carrying the embedded `schools`
// to-one join. We assert it filters by (user_id, status='active'), orders
// deterministically, and maps the join into the summary shape.

interface RecordedQuery {
  table: string;
  filters: Array<[string, unknown]>;
  order: Array<[string, boolean]>;
}

// deno-lint-ignore no-explicit-any
function fakeClient(rows: any[]) {
  const queries: RecordedQuery[] = [];
  const client = {
    from(table: string) {
      const q: RecordedQuery = { table, filters: [], order: [] };
      const builder = {
        select(_cols?: string) {
          return builder;
        },
        eq(col: string, val: unknown) {
          q.filters.push([col, val]);
          return builder;
        },
        order(col: string, opts: { ascending: boolean }) {
          q.order.push([col, opts.ascending]);
          return builder;
        },
        // Thenable: awaiting records the query and returns the canned rows.
        then(resolve: (r: { data: unknown[]; error: null }) => void) {
          queries.push(q);
          resolve({ data: rows, error: null });
        },
      };
      return builder;
    },
  };
  return { client: client as unknown as SupabaseClient, queries };
}

Deno.test("listActiveSchoolMemberships filters by user+active, orders deterministically, maps the join", async () => {
  const { client, queries } = fakeClient([
    {
      id: "m-a",
      school_id: SCHOOL_A,
      role: "teacher",
      permissions_version: 1,
      schools: { id: SCHOOL_A, organization_id: "org-1", name: "Campus A", code: "AKS-001" },
    },
    {
      id: "m-b",
      school_id: SCHOOL_B,
      role: "schoolAdmin",
      permissions_version: 3,
      schools: { id: SCHOOL_B, organization_id: "org-1", name: "Campus B", code: "AKS-002" },
    },
  ]);

  const result = await listActiveSchoolMemberships(client, "user-1");

  // Shape: the embedded join is flattened into the summary.
  assertEquals(result.length, 2);
  assertEquals(result[0], {
    membershipId: "m-a",
    schoolId: SCHOOL_A,
    schoolName: "Campus A",
    schoolCode: "AKS-001",
    organizationId: "org-1",
    role: "teacher",
    permissionsVersion: 1,
  });
  assertEquals(result[1].schoolId, SCHOOL_B);
  assertEquals(result[1].permissionsVersion, 3);

  // Scoping + deterministic ordering (oldest first, school_id tiebreak).
  const q = queries[0];
  assertEquals(q.table, "school_memberships");
  assert(q.filters.some((f) => f[0] === "user_id" && f[1] === "user-1"));
  assert(q.filters.some((f) => f[0] === "status" && f[1] === "active"));
  assertEquals(q.order, [["created_at", true], ["school_id", true]]);
});

Deno.test("listActiveSchoolMemberships drops rows whose school join is missing (fail-closed)", async () => {
  const { client } = fakeClient([
    { id: "m-a", school_id: SCHOOL_A, role: "teacher", permissions_version: 1, schools: null },
  ]);
  const result = await listActiveSchoolMemberships(client, "user-1");
  assertEquals(result, []);
});
