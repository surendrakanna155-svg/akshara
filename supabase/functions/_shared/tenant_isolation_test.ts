import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

Deno.test({
  name: "tenant isolation self-test passes on database",
  ignore: !supabaseUrl || !serviceKey,
  async fn() {
    const client = createClient(supabaseUrl!, serviceKey!, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data, error } = await client.rpc("run_tenant_isolation_self_test");
    if (error) throw error;

    const result = data as { pass: boolean; tests: Array<{ name: string; pass: boolean }> };
    assertEquals(result.pass, true, JSON.stringify(result.tests, null, 2));

    const names = new Set((result.tests ?? []).map((t) => t.name));
    assert(names.has("school_a_cannot_see_school_b"));
    assert(names.has("org_scope_denied_raw_school_memberships"));
    assert(names.has("parent_sees_linked_child"));
    assert(names.has("student_sees_self_only"));
  },
});
