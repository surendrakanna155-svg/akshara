import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AccessTokenClaims } from "./jwt.ts";

/**
 * Applies JWT claims to PostgreSQL session vars via auth.set_request_context RPC
 * (v6.1 §6.3).
 *
 * ICA-B9 WARNING: this is only meaningful on a NON-bypass (tenant/`erp_tenant`)
 * client whose subsequent query runs in the SAME transaction. On a `service_role`
 * client it is an INERT no-op that FALSELY implies tenant scoping: service_role
 * bypasses RLS, and set_request_context writes transaction-local GUCs while each
 * PostgREST call runs in its own transaction, so the context never reaches the
 * next query. service_role reads MUST instead carry their own explicit filter.
 */
export async function setRequestContext(
  client: SupabaseClient,
  claims: Pick<
    AccessTokenClaims,
    | "tenant_id"
    | "scope"
    | "sub"
    | "school_id"
    | "school_group_id"
    | "student_id"
    | "child_ids"
  >,
): Promise<void> {
  const { error } = await client.rpc("set_request_context", {
    p_tenant_id: claims.tenant_id,
    p_scope: claims.scope,
    p_user_id: claims.sub,
    p_school_id: claims.school_id,
    p_school_group_id: claims.school_group_id,
    p_student_id: claims.student_id,
    p_parent_user_id: claims.scope === "parent" ? claims.sub : null,
  });
  if (error) throw error;
}
