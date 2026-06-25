// Firebase Cloud Messaging — HTTP v1 client.
//
// Replaces the retired legacy `fcm.googleapis.com/fcm/send` + server-key API
// with the current Google-recommended HTTP v1 protocol:
//   • authenticate with a Firebase **service account** (OAuth2 JWT-bearer flow,
//     scope https://www.googleapis.com/auth/firebase.messaging),
//   • POST to https://fcm.googleapis.com/v1/projects/<project-id>/messages:send.
//
// The service account JSON is a SECRET and lives only on the server, supplied
// via the `FCM_SERVICE_ACCOUNT_JSON` env var (the full JSON, or base64 of it).
// The minted access token is cached in-memory until just before it expires.
import { importPKCS8, SignJWT } from "npm:jose";

const SERVICE_ACCOUNT_ENV = "FCM_SERVICE_ACCOUNT_JSON";
const MESSAGING_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

export interface FcmServiceAccount {
  clientEmail: string;
  privateKey: string;
  tokenUri: string;
  projectId: string;
}

export interface FcmV1Message {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

export interface FcmSendResult {
  success: boolean;
  messageId: string | null;
  error: string | null;
}

/** Parse the service-account JSON from env (raw JSON or base64-of-JSON). */
export function loadFcmServiceAccount(): FcmServiceAccount | null {
  const raw = Deno.env.get(SERVICE_ACCOUNT_ENV)?.trim();
  if (!raw) return null;
  let jsonText = raw;
  if (!raw.startsWith("{")) {
    try {
      jsonText = atob(raw);
    } catch {
      return null;
    }
  }
  try {
    const sa = JSON.parse(jsonText) as Record<string, string>;
    if (!sa.client_email || !sa.private_key || !sa.project_id) return null;
    return {
      clientEmail: sa.client_email,
      privateKey: sa.private_key,
      tokenUri: sa.token_uri || "https://oauth2.googleapis.com/token",
      projectId: sa.project_id,
    };
  } catch {
    return null;
  }
}

/** True when a usable service account is configured (i.e. v1 push can send). */
export function fcmV1Configured(): boolean {
  return loadFcmServiceAccount() !== null;
}

/** Firebase project id used in the v1 endpoint, from the service account. */
export function fcmProjectId(): string | null {
  return loadFcmServiceAccount()?.projectId ?? null;
}

/** Build the v1 request body. `data` values must be strings per the v1 spec. */
export function buildFcmV1Payload(message: FcmV1Message): Record<string, unknown> {
  const data = message.data ?? {};
  return {
    message: {
      token: message.token,
      notification: { title: message.title, body: message.body },
      data,
      android: {
        priority: "HIGH",
        notification: { default_sound: true },
      },
      apns: {
        payload: { aps: { sound: "default" } },
      },
    },
  };
}

// --- OAuth2 access-token minting (cached) ---------------------------------

let cachedToken: { token: string; expiresAt: number } | null = null;

/** Reset the cached access token. Test-only seam. */
export function _resetFcmTokenCache(): void {
  cachedToken = null;
}

async function mintAccessToken(sa: FcmServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) {
    return cachedToken.token;
  }
  const key = await importPKCS8(sa.privateKey, "RS256");
  const assertion = await new SignJWT({ scope: MESSAGING_SCOPE })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(sa.clientEmail)
    .setSubject(sa.clientEmail)
    .setAudience(sa.tokenUri)
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const response = await fetch(sa.tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(`OAuth token mint failed: ${response.status} ${await response.text()}`);
  }
  const body = await response.json() as { access_token?: string; expires_in?: number };
  if (!body.access_token) {
    throw new Error("OAuth token response missing access_token");
  }
  cachedToken = {
    token: body.access_token,
    expiresAt: now + (body.expires_in ?? 3600),
  };
  return body.access_token;
}

/** Send a single message via FCM HTTP v1. Returns a structured result. */
export async function sendFcmV1(message: FcmV1Message): Promise<FcmSendResult> {
  const sa = loadFcmServiceAccount();
  if (!sa) {
    return { success: false, messageId: null, error: "FCM service account not configured" };
  }
  try {
    const accessToken = await mintAccessToken(sa);
    const endpoint =
      `https://fcm.googleapis.com/v1/projects/${sa.projectId}/messages:send`;
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(buildFcmV1Payload(message)),
    });
    if (!response.ok) {
      return { success: false, messageId: null, error: await response.text() };
    }
    const body = await response.json() as { name?: string };
    return { success: true, messageId: body.name ?? null, error: null };
  } catch (error) {
    return {
      success: false,
      messageId: null,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
