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
    signedUrl: data.signedUrl,
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
  return data.signedUrl;
}

export async function createMemoryShareUrl(
  config: AppConfig,
  storagePath: string,
): Promise<string> {
  return await createMemoryDownloadUrl(config, storagePath);
}
