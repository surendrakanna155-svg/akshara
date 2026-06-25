// Social Media Integration — publish service (Phase 2).
//
// Bridges the publisher dispatch to the Meta Graph client: looks up the school's
// active connection, decrypts its page token, and posts to Facebook/Instagram.
// Returns `pending_connection` (the Phase-1 behaviour) when no account is linked.

import type { TenantQueryClient } from "../tenant_db.ts";
import { getActiveConnectionWithToken } from "./social_connection_repository.ts";
import { decryptToken } from "./social_token_crypto.ts";
import {
  type MetaPublishResult,
  publishToFacebookPage,
  publishToInstagram,
} from "./meta_graph_client.ts";

const PENDING = {
  status: "pending_connection",
  channel: "meta",
  note: "No social account connected — link a Facebook Page/Instagram account in Marketing → Social.",
} as const;

export async function publishToSocialChannel(
  db: TenantQueryClient,
  channel: "facebook" | "instagram",
  caption: string,
  imageUrl: string | null,
): Promise<Record<string, unknown>> {
  const conn = await getActiveConnectionWithToken(db, channel === "instagram");
  if (!conn) return { ...PENDING };
  if (channel === "instagram" && !conn.ig_business_id) return { ...PENDING };

  let token: string;
  try {
    token = await decryptToken(conn.encrypted_page_token);
  } catch (e) {
    return { status: "failed", channel, error: `token decrypt failed: ${e}` };
  }

  const result: MetaPublishResult = channel === "facebook"
    ? await publishToFacebookPage(conn.page_id, token, caption, imageUrl)
    : await publishToInstagram(conn.ig_business_id!, token, caption, imageUrl);

  return { ...result, connectionId: conn.id };
}
