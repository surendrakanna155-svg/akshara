// PRC-A Batch 2 — complaint photo attachment. Reuses the shared
// `validateUpload` / `createStorageAdmin` primitives from
// `_shared/storage/storage_service.ts` (never a second uploader) against a
// dedicated `complaint-photos` bucket (created in this module's own
// migration, 20260886000000_complaints.sql). Mirrors the admissions-documents
// presign pattern exactly: declare -> signed PUT URL -> client uploads ->
// `photo_path` recorded on the complaint row.
//
// NOTE (honesty flag for the report): a cumulative per-school storage quota
// does NOT exist yet anywhere in this codebase (a separate, known PRC-A gap)
// — this module does not attempt to build one; it only validates a SINGLE
// upload's extension/MIME/size, same as every other bucket today.

import type { AppConfig } from "../config.ts";
import {
  createStorageAdmin,
  toPublicStorageUrl,
  type UploadConstraints,
  type UploadDeclaration,
  validateUpload,
} from "../storage/storage_service.ts";

export const COMPLAINT_PHOTOS_BUCKET = "complaint-photos";
const DOWNLOAD_TTL_SECONDS = 900;

export const COMPLAINT_PHOTO_UPLOAD_CONSTRAINTS: UploadConstraints = {
  maxBytes: 10485760, // 10 MiB — matches the complaint-photos bucket
  allowedMimeTypes: ["image/jpeg", "image/png", "image/webp"],
  allowedExtensions: ["jpg", "jpeg", "png", "webp"],
};

/** Returns a user-facing validation error, or `null` when acceptable. */
export function validateComplaintPhotoUpload(
  filename: string,
  declaration: UploadDeclaration,
): string | null {
  return validateUpload(filename, declaration, COMPLAINT_PHOTO_UPLOAD_CONSTRAINTS);
}

/** Tenant-prefixed, complaint-scoped path: {org}/{school}/{complaintId}/{uuid}_{filename}.
 * The complaint-id segment (folder index 3) is what the parent-scope storage
 * RLS policy joins back to `complaints.raised_by`. */
export function buildComplaintPhotoStoragePath(
  organizationId: string,
  schoolId: string,
  complaintId: string,
  filename: string,
): string {
  const safe = filename.replace(/[^a-zA-Z0-9._-]/g, "_");
  return `${organizationId}/${schoolId}/${complaintId}/${crypto.randomUUID()}_${safe}`;
}

export async function createComplaintPhotoUploadUrl(
  config: AppConfig,
  storagePath: string,
): Promise<{ signedUrl: string; token: string; path: string }> {
  const client = createStorageAdmin(config);
  const { data, error } = await client.storage.from(COMPLAINT_PHOTOS_BUCKET)
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

export async function createComplaintPhotoDownloadUrl(
  config: AppConfig,
  storagePath: string,
): Promise<string> {
  const client = createStorageAdmin(config);
  const { data, error } = await client.storage.from(COMPLAINT_PHOTOS_BUCKET)
    .createSignedUrl(storagePath, DOWNLOAD_TTL_SECONDS);
  if (error || !data?.signedUrl) {
    throw new Error(error?.message ?? "Failed to create download URL");
  }
  return toPublicStorageUrl(config, data.signedUrl);
}
