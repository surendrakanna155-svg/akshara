import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import type { AppConfig } from "../config.ts";

const BUCKET = "school-memories";
const ADMISSIONS_BUCKET = "admissions-documents";
const UPLOAD_TTL_SECONDS = 3600;
const DOWNLOAD_TTL_SECONDS = 900;

export function createStorageAdmin(config: AppConfig) {
  return createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/**
 * Signed URLs are generated against the internal gateway origin (supabaseUrl)
 * but must be handed to the device as a PUBLIC origin it can reach. Rewrites the
 * origin to `publicStorageBaseUrl` while preserving the path + token query.
 * No-op when the public base is not configured (lean/local).
 */
export function toPublicStorageUrl(config: AppConfig, url: string): string {
  if (!config.publicStorageBaseUrl) return url;
  try {
    const src = new URL(url);
    const base = new URL(config.publicStorageBaseUrl);
    src.protocol = base.protocol;
    // Set hostname + port separately: the WHATWG `host` setter leaves the
    // existing port intact when the new value has no port, which would keep the
    // internal `:8080` gateway port on the public URL (unreachable over TLS).
    src.hostname = base.hostname;
    src.port = base.port;
    return src.toString();
  } catch {
    return url;
  }
}

export function buildMemoryStoragePath(
  organizationId: string,
  schoolId: string,
  eventId: string,
  albumId: string,
  filename: string,
): string {
  const safe = filename.replace(/[^a-zA-Z0-9._-]/g, "_");
  return `${organizationId}/${schoolId}/${eventId}/${albumId}/${safe}`;
}

export async function createMemoryUploadUrl(
  config: AppConfig,
  storagePath: string,
): Promise<{ signedUrl: string; token: string; path: string }> {
  const client = createStorageAdmin(config);
  const { data, error } = await client.storage.from(BUCKET).createSignedUploadUrl(
    storagePath,
    { upsert: false },
  );
  if (error || !data) {
    throw new Error(error?.message ?? "Failed to create upload URL");
  }
  return {
    signedUrl: toPublicStorageUrl(config, data.signedUrl),
    token: data.token,
    path: storagePath,
  };
}

export async function createMemoryDownloadUrl(
  config: AppConfig,
  storagePath: string,
): Promise<string> {
  const client = createStorageAdmin(config);
  const { data, error } = await client.storage.from(BUCKET).createSignedUrl(
    storagePath,
    DOWNLOAD_TTL_SECONDS,
  );
  if (error || !data?.signedUrl) {
    throw new Error(error?.message ?? "Failed to create download URL");
  }
  return toPublicStorageUrl(config, data.signedUrl);
}

export async function createMemoryShareUrl(
  config: AppConfig,
  storagePath: string,
): Promise<string> {
  return await createMemoryDownloadUrl(config, storagePath);
}

// ─── Admissions documents ─────────────────────────────────────────────────────
// Reuses the device-memories presign → PUT bytes → confirm pattern against a
// dedicated `admissions-documents` bucket. Object paths are tenant-prefixed
// ({organization_id}/{school_id}/…) so storage RLS isolates each tenant.

export function buildAdmissionsDocumentStoragePath(
  organizationId: string,
  schoolId: string,
  leadId: string,
  filename: string,
): string {
  const safe = filename.replace(/[^a-zA-Z0-9._-]/g, "_");
  // A random prefix keeps repeated uploads of the same file name distinct and
  // lets us upsert: false (never silently overwrite a sibling document).
  return `${organizationId}/${schoolId}/${leadId}/${crypto.randomUUID()}_${safe}`;
}

export async function createAdmissionsDocumentUploadUrl(
  config: AppConfig,
  storagePath: string,
): Promise<{ signedUrl: string; token: string; path: string }> {
  const client = createStorageAdmin(config);
  const { data, error } = await client.storage.from(ADMISSIONS_BUCKET)
    .createSignedUploadUrl(storagePath, { upsert: false });
  if (error || !data) {
    throw new Error(error?.message ?? "Failed to create upload URL");
  }
  return {
    signedUrl: toPublicStorageUrl(config, data.signedUrl),
    token: data.token,
    path: storagePath,
  };
}

export async function createAdmissionsDocumentDownloadUrl(
  config: AppConfig,
  storagePath: string,
): Promise<string> {
  const client = createStorageAdmin(config);
  const { data, error } = await client.storage.from(ADMISSIONS_BUCKET)
    .createSignedUrl(storagePath, DOWNLOAD_TTL_SECONDS);
  if (error || !data?.signedUrl) {
    throw new Error(error?.message ?? "Failed to create download URL");
  }
  return toPublicStorageUrl(config, data.signedUrl);
}
