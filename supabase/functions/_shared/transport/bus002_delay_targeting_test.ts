// BUS-002 — route-delay notifications must reach ONLY the affected route's
// guardians.
//
// The defect this pins: handleNotifyRouteDelay filtered allocations down to the
// affected route, counted them into `recipientCount`, audited that count — and
// then dispatched with audience "parents", i.e. every parent in the school.
// Parents of walkers and car-drop children received bus alerts, while both the
// API response and the audit trail claimed the send had reached only the
// affected families.
//
// These tests pin the three load-bearing pieces of the fix:
//   1. cohort resolution maps route allocations → active guardians, and a
//      guardian of a DIFFERENT route is never in the set;
//   2. the audience token is an explicit-cohort token, so the broadcast service
//      refuses to send it without a cohort rather than degrading school-wide;
//   3. fail-closed behaviour when students exist but no guardian is contactable.

import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  resolveRouteGuardianRecipients,
  TRANSPORT_ROUTE_AUDIENCE,
} from "./transport_write_handlers.ts";
import {
  EXPLICIT_COHORT_AUDIENCES,
  normalizeBroadcastAudience,
  sendBroadcastMessage,
} from "../communication/communication_service.ts";
import type { AccessTokenClaims } from "../jwt.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";

/** Student ↔ guardian fixture: two families on route-12, one on route-08. */
const GUARDIAN_BY_STUDENT: Record<string, string[]> = {
  "SIS-STU-A": ["guardian-a"],
  "SIS-STU-B": ["guardian-b"],
  // Route-08 only — must NEVER appear in a route-12 cohort.
  "SIS-STU-Z": ["guardian-z"],
};

/**
 * Stands in for the students ⋈ student_profiles ⋈ student_guardians resolution
 * query. Honours the `= ANY($3::text[])` cohort filter the real query uses.
 */
class MockGuardianDb {
  lastRefs: string[] = [];

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    if (!sql.includes("student_guardians")) return Promise.resolve([] as T[]);
    const refs = (args[2] ?? []) as string[];
    this.lastRefs = refs;
    const guardians = new Set<string>();
    for (const ref of refs) {
      for (const g of GUARDIAN_BY_STUDENT[ref] ?? []) guardians.add(g);
    }
    return Promise.resolve(
      [...guardians].map((g) => ({ guardian_user_id: g })) as T[],
    );
  }
}

/** A cohort whose students exist but have no active guardian linked. */
class MockNoGuardianDb {
  // deno-lint-ignore no-explicit-any
  queryObject<T>(_sql: string, _args: any[] = []): Promise<T[]> {
    return Promise.resolve([] as T[]);
  }
}

function alloc(routeId: string, sisStudentId: string) {
  return { id: `${routeId}:${sisStudentId}`, routeId, sisStudentId };
}

function schoolClaims(): AccessTokenClaims {
  return {
    sub: "staff",
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL_A,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: ["manageTransport"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "test",
  };
}

// ── 1. cohort resolution is route-scoped ─────────────────────────────────────

Deno.test(
  "BUS-002: a route-12 delay resolves ONLY route-12 guardians — a route-08 parent is excluded",
  async () => {
    const db = new MockGuardianDb();
    const routeTwelve = [alloc("route-12", "SIS-STU-A"), alloc("route-12", "SIS-STU-B")];

    const recipients = await resolveRouteGuardianRecipients(
      db as unknown as TenantQueryClient,
      ORG,
      SCHOOL_A,
      routeTwelve,
    );

    assertEquals(recipients?.sort(), ["guardian-a", "guardian-b"]);
    // The regression that shipped: guardian-z rides route-08 and must not be reached.
    assertEquals(recipients?.includes("guardian-z"), false);
    // Only the affected students were ever looked up.
    assertEquals(db.lastRefs.sort(), ["SIS-STU-A", "SIS-STU-B"]);
  },
);

Deno.test("BUS-002: one guardian with two children on the route is addressed once", async () => {
  const db = new MockGuardianDb();
  // Both students map to guardian-a via the fixture override below.
  GUARDIAN_BY_STUDENT["SIS-STU-TWIN1"] = ["guardian-a"];
  GUARDIAN_BY_STUDENT["SIS-STU-TWIN2"] = ["guardian-a"];

  const recipients = await resolveRouteGuardianRecipients(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL_A,
    [alloc("route-12", "SIS-STU-TWIN1"), alloc("route-12", "SIS-STU-TWIN2")],
  );

  assertEquals(recipients, ["guardian-a"]);

  delete GUARDIAN_BY_STUDENT["SIS-STU-TWIN1"];
  delete GUARDIAN_BY_STUDENT["SIS-STU-TWIN2"];
});

Deno.test("BUS-002: an empty route yields an empty cohort, never a wider audience", async () => {
  const db = new MockGuardianDb();
  const recipients = await resolveRouteGuardianRecipients(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL_A,
    [],
  );
  assertEquals(recipients, []);
});

// ── 2. fail closed when no guardian is contactable ───────────────────────────

Deno.test(
  "BUS-002: students on the route but NO active guardian returns null (caller must fail closed)",
  async () => {
    const db = new MockNoGuardianDb();
    const recipients = await resolveRouteGuardianRecipients(
      db as unknown as TenantQueryClient,
      ORG,
      SCHOOL_A,
      [alloc("route-12", "SIS-STU-A")],
    );
    // null — NOT [] — so the handler raises 422 instead of sending to nobody
    // (or, as before, silently falling back to the whole school).
    assertEquals(recipients, null);
  },
);

// ── 3. the audience token cannot degrade to school-wide ──────────────────────

Deno.test("BUS-002: the transport route audience is an explicit-cohort token", () => {
  assertEquals(EXPLICIT_COHORT_AUDIENCES.has(TRANSPORT_ROUTE_AUDIENCE), true);
});

Deno.test(
  "BUS-002: the route audience is NOT aliased to all_parents by the normalizer",
  () => {
    // The original defect passed "parents", which normalizes to all_parents.
    assertEquals(normalizeBroadcastAudience("parents"), "all_parents");
    // The fix must survive normalization untouched.
    assertEquals(
      normalizeBroadcastAudience(TRANSPORT_ROUTE_AUDIENCE),
      TRANSPORT_ROUTE_AUDIENCE,
    );
  },
);

Deno.test(
  "BUS-002: sending the route audience WITHOUT a cohort is rejected, not broadcast school-wide",
  async () => {
    const db = new MockNoGuardianDb() as unknown as TenantQueryClient;
    await assertRejects(
      () =>
        sendBroadcastMessage(
          db,
          schoolClaims(),
          {
            audience: TRANSPORT_ROUTE_AUDIENCE,
            title: "Transport delay",
            body: "Running late",
            // recipientUserIds deliberately omitted.
          },
        ),
      Error,
      "requires an explicit recipient cohort",
    );
  },
);

// ── 4. the stored audience token is CHECK-constraint valid ───────────────────

Deno.test(
  "BUS-002: regression guard — route audience is a comm_broadcasts CHECK token",
  async () => {
    // Mirrors the TRN-8 guard. The audience must appear in the widened CHECK
    // (migration 20260881000000); an unlisted token fails at INSERT time only in
    // production, which is exactly how TRN-8's 'staff' bug reached live.
    const migration = await Deno.readTextFile(
      new URL(
        "../../../migrations/20260881000000_transport_route_parents_audience.sql",
        import.meta.url,
      ),
    );
    assertEquals(migration.includes(`'${TRANSPORT_ROUTE_AUDIENCE}'`), true);
    // The widened constraint must RETAIN every previously-valid token.
    for (
      const kept of [
        "all_parents",
        "all_teachers",
        "all_students",
        "all_staff",
        "school_wide",
        "class_parents",
        "class_students",
        "storekeepers",
      ]
    ) {
      assertEquals(
        migration.includes(`'${kept}'`),
        true,
        `widened CHECK dropped previously-valid audience '${kept}'`,
      );
    }
  },
);
