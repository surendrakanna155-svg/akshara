import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AccessTokenClaims } from "./jwt.ts";

/** Applies JWT claims to PostgreSQL session vars via auth.set_request_context RPC (v6.1 §6.3). */
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
