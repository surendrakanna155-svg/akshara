import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AppConfig } from "./config.ts";

export function createServiceClient(config: AppConfig): SupabaseClient {
  return createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export interface OrganizationRow {
  id: string;
  name: string;
  slug: string;
  status: string;
}

export interface SchoolRow {
  id: string;
  organization_id: string;
  name: string;
  code: string;
}

export interface UserRow {
  id: string;
  phone: string;
  email: string | null;
  display_name: string;
}

export interface SchoolMembershipRow {
  id: string;
  user_id: string;
  school_id: string;
  role: string;
  permissions_version: number;
  schools: SchoolRow;
}

export interface SessionRow {
  id: string;
  user_id: string;
  tenant_id: string;
  revoked_at: string | null;
}

export interface RefreshTokenRow {
  id: string;
  session_id: string;
  user_id: string;
  token_hash: string;
  family_id: string;
  used_at: string | null;
  revoked_at: string | null;
  expires_at: string;
}
