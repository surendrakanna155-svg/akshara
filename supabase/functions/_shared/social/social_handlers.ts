// Social Media Integration — handlers (Phase 2).

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import {
  disconnectConnection,
  listConnections,
  upsertConnection,
} from "./social_connection_repository.ts";
import {
  encryptToken,
  socialEncryptionConfigured,
  tokenFingerprint,
} from "./social_token_crypto.ts";
import {
  buildLoginUrl,
  exchangeCodeForToken,
  fetchManagedPages,
  META_SCOPES,
  metaConfigured,
  metaDryRun,
} from "./meta_graph_client.ts";

function requireSocialView(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewSocialConnections") ?? requireSchoolOperationalScope(claims);
}
function requireSocialManage(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageSocialConnections") ?? requireSchoolOperationalScope(claims);
}

function redirectUri(body: { redirectUri?: string } | null): string {
  return body?.redirectUri ?? Deno.env.get("META_REDIRECT_URI") ??
    "https://api.nikshaos.in/social/connect/callback";
}

function socialError(error: unknown): Response {
  if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
  return errorEnvelope("SOCIAL_ERROR", String(error), 500);
}

export async function handleConnectStart(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireSocialManage(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ redirectUri?: string }>(req).catch(() => null);
  const state = `${schoolIdFromClaims(auth.claims)}:${auth.claims.sub}`;
  return jsonResponse(envelope({
    loginUrl: buildLoginUrl(redirectUri(body), state),
    state,
    scopes: META_SCOPES,
    metaConfigured: metaConfigured(),
    dryRun: metaDryRun(),
    encryptionConfigured: socialEncryptionConfigured(),
  }));
}

export async function handleConnectComplete(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireSocialManage(auth.claims);
  if (denied) return denied;

  if (!socialEncryptionConfigured()) {
    return errorEnvelope(
      "SOCIAL_ENCRYPTION_NOT_CONFIGURED",
      "Token encryption key (SOCIAL_TOKEN_ENC_KEY) is not set — refusing to store tokens in clear text.",
      503,
    );
  }

  const body = await readJson<{ code?: string; redirectUri?: string }>(req).catch(() => null);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  if (!schoolId) return errorEnvelope("FORBIDDEN", "School scope required", 403);

  try {
    const connections = await withTenantContext(config, auth.claims, async (db) => {
      // Resolve the page accounts to store.
      let pages: Array<{ pageId: string; pageName: string; pageAccessToken: string; instagramBusinessId: string | null }>;
      if (metaDryRun()) {
        // No real Meta app configured: synthesise a demo connection so the
        // encryption + storage + publish path are exercisable and certifiable.
        pages = [{
          pageId: "dryrun_page_1",
          pageName: "Demo School Page (dry-run)",
          pageAccessToken: `DRYRUN_PAGE_TOKEN_${Math.abs(hash(schoolId))}`,
          instagramBusinessId: "dryrun_ig_1",
        }];
      } else {
        if (!body?.code) throw new Error("code is required to complete the connection");
        const userToken = await exchangeCodeForToken(body.code, redirectUri(body));
        pages = await fetchManagedPages(userToken);
      }

      const stored = [];
      for (const page of pages) {
        const encrypted = await encryptToken(page.pageAccessToken);
        const row = await upsertConnection(db, orgId, schoolId, {
          pageId: page.pageId,
          pageName: page.pageName,
          igBusinessId: page.instagramBusinessId,
          igUsername: page.instagramBusinessId ? "linked_ig" : null,
          encryptedToken: encrypted,
          tokenExpiresAt: null,
          scopes: META_SCOPES,
          connectedBy: auth.claims.sub,
        });
        await emitMutationAudit(
          db,
          auth.claims,
          moduleEntityAudit("social.connection.created", "social_connection", row.id, {
            pageId: page.pageId,
            tokenFingerprint: tokenFingerprint(page.pageAccessToken),
          }),
          req,
        );
        stored.push(row);
      }
      return stored;
    });
    return jsonResponse(envelope({ connections, dryRun: metaDryRun() }), { status: 201 });
  } catch (error) {
    return socialError(error);
  }
}

export async function handleListConnections(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireSocialView(auth.claims);
  if (denied) return denied;
  try {
    const items = await withTenantContext(config, auth.claims, (db) => listConnections(db));
    return jsonResponse(envelope({ items, metaConfigured: metaConfigured(), dryRun: metaDryRun() }));
  } catch (error) {
    return socialError(error);
  }
}

export async function handleDisconnect(req: Request, config: AppConfig, id: string): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireSocialManage(auth.claims);
  if (denied) return denied;
  try {
    const ok = await withTenantContext(config, auth.claims, async (db) => {
      const deleted = await disconnectConnection(db, id);
      if (deleted) {
        await emitMutationAudit(
          db,
          auth.claims,
          moduleEntityAudit("social.connection.removed", "social_connection", id, {}),
          req,
        );
      }
      return deleted;
    });
    if (!ok) return errorEnvelope("NOT_FOUND", "Connection not found", 404);
    return jsonResponse(envelope({ id, disconnected: true }));
  } catch (error) {
    return socialError(error);
  }
}

function hash(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
  return h;
}
