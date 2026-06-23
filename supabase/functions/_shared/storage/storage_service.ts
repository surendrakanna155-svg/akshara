import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import type { AppConfig } from "../config.ts";

const BUCKET = "school-memories";
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
    src.host = base.host;
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
