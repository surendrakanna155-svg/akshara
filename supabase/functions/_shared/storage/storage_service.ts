import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import type { AppConfig } from "../config.ts";

const BUCKET = "school-memories";
const ADMISSIONS_BUCKET = "admissions-documents";
// PRA-P1-19 — real file storage for SIS student documents.
const STUDENT_DOCUMENTS_BUCKET = "student-documents";
// PRA-P1-30 — real file storage for homework attachments (teacher + student).
const HOMEWORK_ATTACHMENTS_BUCKET = "homework-attachments";
// ASIP — real file storage for support-incident screenshots + screen recordings.
const SUPPORT_ATTACHMENTS_BUCKET = "support-incident-attachments";
const DOWNLOAD_TTL_SECONDS = 900;

export function createStorageAdmin(config: AppConfig) {
  return createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

// ─── RT-31: presign-time upload validation (early rejection) ──────────────────
// The Storage buckets already enforce size + MIME at upload time (migrations
// 20260622700000 / 20260806000020). These mirror those limits at the app layer
// so a wrong-type / oversized upload is rejected when the client asks for the
// signed URL — a clean error instead of a wasted PUT that the bucket bounces.

export interface UploadConstraints {
  maxBytes: number;
  allowedMimeTypes: string[];
  allowedExtensions: string[];
}

export const MEMORY_UPLOAD_CONSTRAINTS: UploadConstraints = {
  maxBytes: 52428800, // 50 MiB — matches the school-memories bucket
  allowedMimeTypes: [
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/gif",
    "video/mp4",
    "video/webm",
  ],
  allowedExtensions: ["jpg", "jpeg", "png", "webp", "gif", "mp4", "webm"],
};

export const ADMISSIONS_UPLOAD_CONSTRAINTS: UploadConstraints = {
  maxBytes: 26214400, // 25 MiB — matches the admissions-documents bucket
  allowedMimeTypes: [
    "application/pdf",
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
  ],
  allowedExtensions: ["pdf", "jpg", "jpeg", "png", "webp", "heic"],
};

// PRA-P1-19 — SIS student documents (birth certificate, TC, etc.). Same shape as
// admissions verification docs: PDF + scanned images, 25 MiB.
export const STUDENT_DOCUMENT_UPLOAD_CONSTRAINTS: UploadConstraints = {
  maxBytes: 26214400, // 25 MiB — matches the student-documents bucket
  allowedMimeTypes: [
    "application/pdf",
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
  ],
  allowedExtensions: ["pdf", "jpg", "jpeg", "png", "webp", "heic"],
};

// PRA-P1-30 — homework attachments (teacher worksheet / student submission).
// Allows PDFs + images like the document surfaces, 25 MiB.
export const HOMEWORK_UPLOAD_CONSTRAINTS: UploadConstraints = {
  maxBytes: 26214400, // 25 MiB — matches the homework-attachments bucket
  allowedMimeTypes: [
    "application/pdf",
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
  ],
  allowedExtensions: ["pdf", "jpg", "jpeg", "png", "webp", "heic"],
};

export interface UploadDeclaration {
  contentType?: string | null;
  sizeBytes?: number | null;
}

/**
 * Returns a user-facing error message when the declared upload violates the
 * bucket constraints, or `null` when it is acceptable. The filename extension is
 * always checked (no client cooperation needed); a declared content-type / size
 * is checked when present.
 */
export function validateUpload(
  filename: string,
  declaration: UploadDeclaration,
  constraints: UploadConstraints,
): string | null {
  const dot = filename.lastIndexOf(".");
  const ext = dot >= 0 ? filename.slice(dot + 1).toLowerCase() : "";
  if (!ext || !constraints.allowedExtensions.includes(ext)) {
    return `File type ".${ext || "unknown"}" is not allowed. Allowed: ${
      constraints.allowedExtensions.join(", ")
    }`;
  }
  const contentType = declaration.contentType?.toLowerCase();
  if (contentType && !constraints.allowedMimeTypes.includes(contentType)) {
    return `Content type "${contentType}" is not allowed.`;
  }
  const size = declaration.sizeBytes;
  if (size != null && (size <= 0 || size > constraints.maxBytes)) {
    return `File exceeds the maximum size of ${
      Math.floor(constraints.maxBytes / 1048576)
    } MiB.`;
  }
  return null;
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

// ─── SIS student documents (PRA-P1-19) ─────────────────────────────────────────
// Mirrors the admissions presign → PUT bytes → confirm pattern against a
// dedicated `student-documents` bucket. Object paths are tenant-prefixed
// ({organization_id}/{school_id}/…) so storage RLS isolates each tenant.

export function buildStudentDocumentStoragePath(
  organizationId: string,
  schoolId: string,
  studentId: string,
  filename: string,
): string {
  const safe = filename.replace(/[^a-zA-Z0-9._-]/g, "_");
  // A random prefix keeps repeated uploads of the same file name distinct and
  // lets us upsert: false (never silently overwrite a sibling document).
  return `${organizationId}/${schoolId}/${studentId}/${crypto.randomUUID()}_${safe}`;
}

export async function createStudentDocumentUploadUrl(
  config: AppConfig,
  storagePath: string,
): Promise<{ signedUrl: string; token: string; path: string }> {
  const client = createStorageAdmin(config);
  const { data, error } = await client.storage.from(STUDENT_DOCUMENTS_BUCKET)
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

export async function createStudentDocumentDownloadUrl(
  config: AppConfig,
  storagePath: string,
): Promise<string> {
  const client = createStorageAdmin(config);
  const { data, error } = await client.storage.from(STUDENT_DOCUMENTS_BUCKET)
    .createSignedUrl(storagePath, DOWNLOAD_TTL_SECONDS);
  if (error || !data?.signedUrl) {
    throw new Error(error?.message ?? "Failed to create download URL");
  }
  return toPublicStorageUrl(config, data.signedUrl);
}

// ─── Homework attachments (PRA-P1-30) ──────────────────────────────────────────
// Real file storage for the HWK-4 teacher attachment and the HWK-7 student
// submission attachment. Same presign → PUT → confirm pattern against a dedicated
// `homework-attachments` bucket, tenant-prefixed for storage RLS isolation.
//
// The teacher attach happens BEFORE the homework id exists (it is minted inside
// insertHomeworkAssignment), so the teacher path keys on the teacher id; the
// student submission path keys on the student id + homework id.

export function buildHomeworkTeacherAttachmentStoragePath(
  organizationId: string,
  schoolId: string,
  teacherId: string,
  filename: string,
): string {
  const safe = filename.replace(/[^a-zA-Z0-9._-]/g, "_");
  return `${organizationId}/${schoolId}/${teacherId}/${crypto.randomUUID()}_${safe}`;
}

export function buildHomeworkSubmissionStoragePath(
  organizationId: string,
  schoolId: string,
  studentId: string,
  homeworkId: string,
  filename: string,
): string {
  const safe = filename.replace(/[^a-zA-Z0-9._-]/g, "_");
  const safeHw = homeworkId.replace(/[^a-zA-Z0-9._-]/g, "_");
  return `${organizationId}/${schoolId}/${studentId}/${safeHw}/${crypto.randomUUID()}_${safe}`;
}

export async function createHomeworkAttachmentUploadUrl(
  config: AppConfig,
  storagePath: string,
): Promise<{ signedUrl: string; token: string; path: string }> {
  const client = createStorageAdmin(config);
  const { data, error } = await client.storage.from(HOMEWORK_ATTACHMENTS_BUCKET)
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

export async function createHomeworkAttachmentDownloadUrl(
  config: AppConfig,
  storagePath: string,
): Promise<string> {
  const client = createStorageAdmin(config);
  const { data, error } = await client.storage.from(HOMEWORK_ATTACHMENTS_BUCKET)
    .createSignedUrl(storagePath, DOWNLOAD_TTL_SECONDS);
  if (error || !data?.signedUrl) {
    throw new Error(error?.message ?? "Failed to create download URL");
  }
  return toPublicStorageUrl(config, data.signedUrl);
}

// ─── Support-incident attachments (ASIP) ───────────────────────────────────────
// Screenshots + optional screen recordings the reporter provides. Same proven
// presign → PUT bytes → confirm pattern against a dedicated, private,
// tenant-isolated `support-incident-attachments` bucket. Path layout:
//   {organization_id}/{school_id}/{incident_id}/{uuid}_{file}
// Larger cap than the document buckets because screen recordings can be big.

export const SUPPORT_ATTACHMENT_UPLOAD_CONSTRAINTS: UploadConstraints = {
  maxBytes: 104857600, // 100 MiB — matches the support-incident-attachments bucket
  allowedMimeTypes: [
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
    "video/mp4",
    "video/webm",
    "video/quicktime",
    "text/plain",
    "application/json",
  ],
  allowedExtensions: ["jpg", "jpeg", "png", "webp", "heic", "mp4", "webm", "mov", "txt", "json", "log"],
};

export function buildSupportAttachmentStoragePath(
  organizationId: string,
  schoolId: string,
  incidentId: string,
  filename: string,
): string {
  const safe = filename.replace(/[^a-zA-Z0-9._-]/g, "_");
  const safeIncident = incidentId.replace(/[^a-zA-Z0-9._-]/g, "_");
  return `${organizationId}/${schoolId}/${safeIncident}/${crypto.randomUUID()}_${safe}`;
}

export async function createSupportAttachmentUploadUrl(
  config: AppConfig,
  storagePath: string,
): Promise<{ signedUrl: string; token: string; path: string }> {
  const client = createStorageAdmin(config);
  const { data, error } = await client.storage.from(SUPPORT_ATTACHMENTS_BUCKET)
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

export async function createSupportAttachmentDownloadUrl(
  config: AppConfig,
  storagePath: string,
): Promise<string> {
  const client = createStorageAdmin(config);
  const { data, error } = await client.storage.from(SUPPORT_ATTACHMENTS_BUCKET)
    .createSignedUrl(storagePath, DOWNLOAD_TTL_SECONDS);
  if (error || !data?.signedUrl) {
    throw new Error(error?.message ?? "Failed to create download URL");
  }
  return toPublicStorageUrl(config, data.signedUrl);
}
