// Social Media Integration — Meta (Facebook/Instagram) Graph API client (Phase 2).
//
// Real Graph calls run only when a Meta app is configured (META_APP_ID +
// META_APP_SECRET) and not in dry-run. Otherwise every publish returns a
// structured `dry_run` result that records the exact request that WOULD be sent —
// so the integration is testable and certifiable end-to-end before the owner
// completes Meta App Review and sets credentials on the server.

const GRAPH_VERSION = "v21.0";

export function graphBaseUrl(): string {
  return Deno.env.get("META_GRAPH_BASE_URL")?.trim() || `https://graph.facebook.com/${GRAPH_VERSION}`;
}

export function metaAppId(): string | undefined {
  return Deno.env.get("META_APP_ID")?.trim() || undefined;
}
export function metaAppSecret(): string | undefined {
  return Deno.env.get("META_APP_SECRET")?.trim() || undefined;
}

export function metaConfigured(): boolean {
  return !!metaAppId() && !!metaAppSecret();
}

/** Dry-run when explicitly enabled OR when no Meta app is configured. */
export function metaDryRun(): boolean {
  if (Deno.env.get("META_DRY_RUN")?.trim().toLowerCase() === "true") return true;
  return !metaConfigured();
}

/** Permissions requested at connect time (subject to Meta App Review). */
export const META_SCOPES = [
  "pages_show_list",
  "pages_read_engagement",
  "pages_manage_posts",
  "instagram_basic",
  "instagram_content_publish",
  "business_management",
];

export interface MetaPublishResult {
  status: "published" | "dry_run" | "failed";
  channel: "facebook" | "instagram";
  externalId?: string;
  request?: Record<string, unknown>;
  error?: string;
}

/** Facebook Login dialog URL for the connect flow. */
export function buildLoginUrl(redirectUri: string, state: string): string {
  const params = new URLSearchParams({
    client_id: metaAppId() ?? "META_APP_ID_NOT_SET",
    redirect_uri: redirectUri,
    state,
    response_type: "code",
    scope: META_SCOPES.join(","),
  });
  return `https://www.facebook.com/${GRAPH_VERSION}/dialog/oauth?${params.toString()}`;
}

async function graphPost(path: string, body: Record<string, string>): Promise<Record<string, unknown>> {
  const res = await fetch(`${graphBaseUrl()}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(body).toString(),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = (json as { error?: { message?: string } })?.error?.message ?? `HTTP ${res.status}`;
    throw new Error(msg);
  }
  return json as Record<string, unknown>;
}

/** Exchange an OAuth code for a long-lived user token (real flow only). */
export async function exchangeCodeForToken(code: string, redirectUri: string): Promise<string> {
  const params = new URLSearchParams({
    client_id: metaAppId()!,
    client_secret: metaAppSecret()!,
    redirect_uri: redirectUri,
    code,
  });
  const res = await fetch(`${graphBaseUrl()}/oauth/access_token?${params.toString()}`);
  const json = await res.json();
  if (!res.ok || !json.access_token) {
    throw new Error((json as { error?: { message?: string } })?.error?.message ?? "token exchange failed");
  }
  return json.access_token as string;
}

export interface MetaPageAccount {
  pageId: string;
  pageName: string;
  pageAccessToken: string;
  instagramBusinessId: string | null;
}

/** List the Pages (and linked IG business accounts) the user manages. */
export async function fetchManagedPages(userToken: string): Promise<MetaPageAccount[]> {
  const url = `${graphBaseUrl()}/me/accounts?fields=id,name,access_token,instagram_business_account&access_token=${
    encodeURIComponent(userToken)
  }`;
  const res = await fetch(url);
  const json = await res.json();
  if (!res.ok) throw new Error((json as { error?: { message?: string } })?.error?.message ?? "pages fetch failed");
  // deno-lint-ignore no-explicit-any
  return ((json.data ?? []) as any[]).map((p) => ({
    pageId: p.id,
    pageName: p.name,
    pageAccessToken: p.access_token,
    instagramBusinessId: p.instagram_business_account?.id ?? null,
  }));
}

/** Publish an image post to a Facebook Page (real call or dry-run). */
export async function publishToFacebookPage(
  pageId: string,
  pageToken: string,
  caption: string,
  imageUrl: string | null,
): Promise<MetaPublishResult> {
  const path = imageUrl ? `/${pageId}/photos` : `/${pageId}/feed`;
  const body: Record<string, string> = imageUrl
    ? { url: imageUrl, caption, access_token: pageToken }
    : { message: caption, access_token: pageToken };
  if (metaDryRun()) {
    return { status: "dry_run", channel: "facebook", request: { path, ...redact(body) } };
  }
  try {
    const json = await graphPost(path, body);
    return { status: "published", channel: "facebook", externalId: String(json.id ?? json.post_id ?? "") };
  } catch (e) {
    return { status: "failed", channel: "facebook", error: String(e) };
  }
}

/** Publish an image post to an Instagram Business account (container → publish). */
export async function publishToInstagram(
  igUserId: string,
  pageToken: string,
  caption: string,
  imageUrl: string | null,
): Promise<MetaPublishResult> {
  if (metaDryRun()) {
    return {
      status: "dry_run",
      channel: "instagram",
      request: {
        container: `/${igUserId}/media`,
        publish: `/${igUserId}/media_publish`,
        caption,
        imageUrl,
        note: imageUrl ? undefined : "image_url required for real publish",
      },
    };
  }
  if (!imageUrl) {
    return { status: "failed", channel: "instagram", error: "Instagram requires an image_url" };
  }
  try {
    const container = await graphPost(`/${igUserId}/media`, {
      image_url: imageUrl,
      caption,
      access_token: pageToken,
    });
    const published = await graphPost(`/${igUserId}/media_publish`, {
      creation_id: String(container.id),
      access_token: pageToken,
    });
    return { status: "published", channel: "instagram", externalId: String(published.id ?? "") };
  } catch (e) {
    return { status: "failed", channel: "instagram", error: String(e) };
  }
}

function redact(body: Record<string, string>): Record<string, string> {
  const out = { ...body };
  if (out.access_token) out.access_token = "****";
  return out;
}
