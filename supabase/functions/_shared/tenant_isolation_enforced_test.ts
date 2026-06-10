import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { loadConfig } from "./config.ts";
import { withTenantContext } from "./tenant_db.ts";
import { runEnforcedIsolationProbes } from "./tenant_isolation_probes.ts";
import type { AccessTokenClaims } from "./jwt.ts";
import type { TenantQueryClient } from "./tenant_db.ts";
import type { IsolationProbeResult } from "./tenant_isolation_probes.ts";

const hasTenantUrl = Boolean(Deno.env.get("ERP_TENANT_DATABASE_URL"));

Deno.test({
  name: "enforced tenant isolation passes via erp_tenant direct connection",
  ignore: !hasTenantUrl,
  async fn() {
    const config = loadConfig();
    const runWithClaims = async (
      claims: AccessTokenClaims,
      fn: (db: TenantQueryClient) => Promise<IsolationProbeResult>,
    ) => await withTenantContext(config, claims, fn);

    const result = await runEnforcedIsolationProbes(runWithClaims);

    assertEquals(result.enforced, true);
    assertEquals(result.role, "erp_tenant");
    assertEquals(result.pass, true, JSON.stringify(result.tests, null, 2));

    const names = new Set(result.tests.map((t) => t.name));
    assert(names.has("school_a_cannot_see_school_b"));
    assert(names.has("org_scope_denied_raw_school_memberships"));
    assert(names.has("org_scope_denied_raw_students"));
    assert(names.has("org_scope_reads_aggregate_view"));
    assert(names.has("parent_cannot_see_unlinked_student"));
    assert(names.has("student_sees_self_only"));
    assert(names.has("school_a_sees_own_audit_probe"));
    assert(names.has("parent_denied_audit_probe"));
    assert(names.has("parent_a_sees_own_parent_probe"));
    assert(names.has("teacher_a_sees_own_teacher_probe"));
  },
});
