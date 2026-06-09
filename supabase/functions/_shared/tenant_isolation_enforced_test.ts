import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

Deno.test({
  name: "enforced tenant isolation RPC passes on staging database",
  ignore: !supabaseUrl || !serviceKey,
  async fn() {
    const client = createClient(supabaseUrl!, serviceKey!, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data, error } = await client.rpc("run_tenant_isolation_enforced_test");
    if (error) throw error;

    const result = data as {
      pass: boolean;
      enforced: boolean;
      role: string;
      tests: Array<{ name: string; pass: boolean }>;
    };

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
  },
});
