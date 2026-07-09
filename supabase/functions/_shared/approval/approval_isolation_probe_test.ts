// Track B — QA-B-040 (approval) live RLS cross-tenant isolation probe.
//
// The shared 233-probe suite (`tenant_isolation_enforced_test.ts` /
// `tenant_isolation_probes.ts`) covers hr/hostel/library/alumni/inventory/
// transport/finance/parent/control_center/copilot/student cross-tenant RLS, but
// has no probe for the real `approval_requests` table. Per
// `docs/FINAL_QA_MASTER_TRACKER.md` QA-B-040, the INFRA remainder is: "per-row
// approve/reject 403 (slug check runs after the row loads inside the tenant tx)
// needs ERP_TENANT_DATABASE_URL + live RLS" — i.e. proof that RLS on
// `approval_requests` itself denies a cross-school read/write BEFORE any
// application-level SoD check ever runs.
//
// Design (non-destructive, mirrors tenant_isolation_enforced_test.ts style):
//   * Seeds TWO SYNTHETIC rows — one per the suite's standing dedicated fixture
//     schools (SCHOOL_A / SCHOOL_B) — entirely INSIDE one Postgres transaction.
//   * Switches `app.set_request_context` mid-transaction (SECURITY DEFINER,
//     `set_config(..., true)` = transaction-local) to seed each school's row
//     under ITS OWN RLS context (the table's WITH CHECK requires
//     organization_id/school_id to match the caller's context).
//   * Asserts cross-school denial (school A cannot see/count school B's row and
//     vice versa) and organization-scope denial (no rollup grant on this table).
//   * ALWAYS rolls back in a `finally`, even on assertion failure — nothing is
//     ever persisted. `akshara_tenant_test` is left byte-for-byte unchanged.
//
// Run alongside the main suite:
//   deno test --allow-all --no-lock \
//     /app/_shared/tenant_isolation_enforced_test.ts \
//     /app/_shared/approval/approval_isolation_probe_test.ts

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { Pool, type PoolClient } from "https://deno.land/x/postgres@v0.19.3/mod.ts";
import { loadConfig } from "../config.ts";

const hasTenantUrl = Boolean(Deno.env.get("ERP_TENANT_DATABASE_URL"));

// Same standing dedicated fixture constants used throughout
// `tenant_isolation_probes.ts` (ORG / SCHOOL_A / SCHOOL_B / STAFF_A).
const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";
const STAFF_A = "a3000000-0000-4000-8000-000000000001";

// Synthetic, never-persisted probe row ids (rolled back at the end of the txn).
const APPROVAL_PROBE_SCHOOL_A = "bf000000-0000-4000-8000-000000000001";
const APPROVAL_PROBE_SCHOOL_B = "bf000000-0000-4000-8000-000000000002";

async function setSchoolContext(client: PoolClient, schoolId: string): Promise<void> {
  await client.queryObject(
    `SELECT app.set_request_context($1::uuid, 'school', $2::uuid, $3::uuid, NULL, NULL, NULL)`,
    [ORG, STAFF_A, schoolId],
  );
}

async function setOrgContext(client: PoolClient): Promise<void> {
  await client.queryObject(
    `SELECT app.set_request_context($1::uuid, 'organization', $2::uuid, NULL, NULL, NULL, NULL)`,
    [ORG, STAFF_A],
  );
}

async function countById(client: PoolClient, id: string): Promise<string> {
  const result = await client.queryObject<{ count: string }>(
    `SELECT count(*)::text AS count FROM approval_requests WHERE id = $1::uuid`,
    [id],
  );
  return result.rows[0]?.count ?? "0";
}

Deno.test({
  name: "QA-B-040: approval_requests cross-school RLS isolation (rolled-back txn, zero persisted writes)",
  ignore: !hasTenantUrl,
  async fn() {
    const config = loadConfig();
    if (!config.erpTenantDatabaseUrl) {
      throw new Error("ERP_TENANT_DATABASE_URL not configured");
    }
    const pool = new Pool(config.erpTenantDatabaseUrl, 1, /* lazy */ true);
    const client = await pool.connect();
    try {
      await client.queryObject("BEGIN");
      try {
        // Seed school A's row under school A's own RLS context.
        await setSchoolContext(client, SCHOOL_A);
        await client.queryObject(
          `INSERT INTO approval_requests
             (id, organization_id, school_id, type, status, title, summary,
              requester_id, requester_name, entity_type, entity_id, payload)
           VALUES ($1::uuid, $2::uuid, $3::uuid, 'rls_probe', 'pending',
                   'RLS isolation probe (school A)', 'RLS isolation probe (school A)',
                   $4, 'RLS Probe', 'rls_probe', 'rls-probe-a', '{}'::jsonb)`,
          [APPROVAL_PROBE_SCHOOL_A, ORG, SCHOOL_A, STAFF_A],
        );

        // Seed school B's row under school B's own RLS context.
        await setSchoolContext(client, SCHOOL_B);
        await client.queryObject(
          `INSERT INTO approval_requests
             (id, organization_id, school_id, type, status, title, summary,
              requester_id, requester_name, entity_type, entity_id, payload)
           VALUES ($1::uuid, $2::uuid, $3::uuid, 'rls_probe', 'pending',
                   'RLS isolation probe (school B)', 'RLS isolation probe (school B)',
                   $4, 'RLS Probe', 'rls_probe', 'rls-probe-b', '{}'::jsonb)`,
          [APPROVAL_PROBE_SCHOOL_B, ORG, SCHOOL_B, STAFF_A],
        );

        // Still in school B's context: sees its own row, NOT school A's.
        assertEquals(
          await countById(client, APPROVAL_PROBE_SCHOOL_B),
          "1",
          "school B must see its own approval_requests row",
        );
        assertEquals(
          await countById(client, APPROVAL_PROBE_SCHOOL_A),
          "0",
          "school B must NOT see school A's approval_requests row",
        );

        // Switch to school A's context: sees its own row, NOT school B's.
        await setSchoolContext(client, SCHOOL_A);
        assertEquals(
          await countById(client, APPROVAL_PROBE_SCHOOL_A),
          "1",
          "school A must see its own approval_requests row",
        );
        assertEquals(
          await countById(client, APPROVAL_PROBE_SCHOOL_B),
          "0",
          "school A must NOT see school B's approval_requests row",
        );

        // Organization-scope: approval_requests has exactly one policy
        // (`approval_requests_school_scope`, scope='school' only) — org rollup
        // has no dedicated grant on this table, so an org-scope context must see
        // NEITHER probe row.
        await setOrgContext(client);
        const orgSeesA = await countById(client, APPROVAL_PROBE_SCHOOL_A);
        const orgSeesB = await countById(client, APPROVAL_PROBE_SCHOOL_B);
        assertEquals(orgSeesA, "0", "organization scope must NOT read school A's approval_requests row");
        assertEquals(orgSeesB, "0", "organization scope must NOT read school B's approval_requests row");
      } finally {
        // ALWAYS rollback — this probe must never persist a write, pass or fail.
        await client.queryObject("ROLLBACK");
      }
    } finally {
      client.release();
      await pool.end();
    }
  },
});
