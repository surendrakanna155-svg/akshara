// Social Media Integration — connection repository (Phase 2).

import type { TenantQueryClient } from "../tenant_db.ts";

export interface SocialConnectionRow {
  id: string;
  page_id: string;
  page_name: string;
  ig_business_id: string | null;
  ig_username: string | null;
  token_expires_at: string | null;
  scopes: unknown;
  status: string;
  created_at: string;
}

const PUBLIC_COLS =
  `id, page_id, page_name, ig_business_id, ig_username, token_expires_at, scopes, status, created_at`;

export async function listConnections(db: TenantQueryClient): Promise<SocialConnectionRow[]> {
  return await db.queryObject<SocialConnectionRow>(
    `SELECT ${PUBLIC_COLS} FROM social_media_connections ORDER BY created_at DESC`,
  );
}

export interface ActiveConnectionWithToken {
  id: string;
  page_id: string;
  ig_business_id: string | null;
  encrypted_page_token: string;
}

/** The active (connected) page connection for the current school, token included. */
export async function getActiveConnectionWithToken(
  db: TenantQueryClient,
  requireInstagram = false,
): Promise<ActiveConnectionWithToken | null> {
  const igClause = requireInstagram ? "AND ig_business_id IS NOT NULL" : "";
  const rows = await db.queryObject<ActiveConnectionWithToken>(
    `SELECT id, page_id, ig_business_id, encrypted_page_token
       FROM social_media_connections
      WHERE status = 'connected' ${igClause}
      ORDER BY created_at DESC LIMIT 1`,
  );
  return rows[0] ?? null;
}

export async function upsertConnection(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: {
    pageId: string;
    pageName: string;
    igBusinessId: string | null;
    igUsername: string | null;
    encryptedToken: string;
    tokenExpiresAt: string | null;
    scopes: string[];
    connectedBy: string;
  },
): Promise<SocialConnectionRow> {
  const rows = await db.queryObject<SocialConnectionRow>(
    `INSERT INTO social_media_connections
       (organization_id, school_id, page_id, page_name, ig_business_id, ig_username,
        encrypted_page_token, token_expires_at, scopes, status, connected_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, 'connected', $10)
     ON CONFLICT (organization_id, school_id, page_id)
     DO UPDATE SET page_name = EXCLUDED.page_name, ig_business_id = EXCLUDED.ig_business_id,
       ig_username = EXCLUDED.ig_username, encrypted_page_token = EXCLUDED.encrypted_page_token,
       token_expires_at = EXCLUDED.token_expires_at, scopes = EXCLUDED.scopes,
       status = 'connected', updated_at = timezone('utc', now())
     RETURNING ${PUBLIC_COLS}`,
    [
      orgId,
      schoolId,
      input.pageId,
      input.pageName,
      input.igBusinessId,
      input.igUsername,
      input.encryptedToken,
      input.tokenExpiresAt,
      JSON.stringify(input.scopes),
      input.connectedBy,
    ],
  );
  return rows[0]!;
}

export async function disconnectConnection(db: TenantQueryClient, id: string): Promise<boolean> {
  const rows = await db.queryObject<{ id: string }>(
    `DELETE FROM social_media_connections WHERE id = $1 RETURNING id`,
    [id],
  );
  return rows.length > 0;
}
