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
import { enforceStorageQuota } from "../storage/storage_quota_enforcement.ts";
import { recordStorageUsage } from "../storage/storage_quota_repository.ts";
import { enforceUploadScanGate, recordUploadScan } from "../storage/upload_scan_repository.ts";
import { initialScanStatus } from "../storage/upload_scan_service.ts";
import { emitMutationAudit, schoolMemoriesAudit } from "../audit/mutation_audit_catalog.ts";
import {
  buildMemoryAnalytics,
  confirmMemoryMediaUpload,
  createMemoryAlbum,
  createMemoryEvent,
  getMediaByShareToken,
  getMemoryEvent,
  listAlbumsForEvent,
  listMediaForAlbum,
  listMemoryEvents,
  publishMemoryEvent,
} from "./school_memories_repository.ts";
import {
  buildMemoryStoragePath,
  createMemoryDownloadUrl,
  createMemoryUploadUrl,
  MEMORY_UPLOAD_CONSTRAINTS,
  validateUpload,
} from "../storage/storage_service.ts";

function requireMemoriesRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewSchoolMemories") ??
    requireSchoolOperationalScope(claims);
}

function requireMemoriesWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageSchoolMemories") ??
    requireSchoolOperationalScope(claims);
}

export async function handleListMemoryEvents(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireMemoriesRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  try {
    const items = await withTenantContext(config, auth.claims, (db) =>
      listMemoryEvents(db, {
        category: url.searchParams.get("category") ?? undefined,
        status: url.searchParams.get("status") ?? undefined,
      })
    );
    return jsonResponse(envelope({
      items: items.map((e) => ({
        id: e.id,
        title: e.title,
        category: e.category,
        eventDate: e.event_date,
        description: e.description,
        visibility: e.visibility,
        status: e.status,
      })),
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("MEMORIES_ERROR", "List events failed", 500);
  }
}

export async function handleGetMemoryEvent(
  req: Request,
  config: AppConfig,
  eventId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireMemoriesRead(auth.claims);
  if (denied) return denied;

  try {
    const data = await withTenantContext(config, auth.claims, async (db) => {
      const event = await getMemoryEvent(db, eventId);
      if (!event) return null;
      const albums = await listAlbumsForEvent(db, eventId);
      const albumsWithMedia = await Promise.all(
        albums.map(async (a) => ({
          id: a.id,
          title: a.title,
          coverLabel: a.cover_label,
          mediaCount: a.media_count,
          media: (await listMediaForAlbum(db, a.id)).map((m) => ({
            id: m.id,
            mediaType: m.media_type,
            title: m.title,
            storageUrl: m.storage_url,
            thumbnailUrl: m.thumbnail_url,
          })),
        })),
      );
      return { event, albums: albumsWithMedia };
    });
    if (!data) return errorEnvelope("NOT_FOUND", "Event not found", 404);
    return jsonResponse(envelope({
      id: data.event.id,
      title: data.event.title,
      category: data.event.category,
      eventDate: data.event.event_date,
      description: data.event.description,
      visibility: data.event.visibility,
      status: data.event.status,
      albums: data.albums,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("MEMORIES_ERROR", "Get event failed", 500);
  }
}

export async function handleCreateMemoryEvent(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireMemoriesWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    title?: string;
    category?: string;
    eventDate?: string;
    description?: string;
    visibility?: string;
  }>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body required", 422);
  }
  if (!body.title || !body.category) {
    return errorEnvelope("VALIDATION_ERROR", "title and category are required", 422);
  }

  try {
    const event = await withTenantContext(config, auth.claims, async (db) => {
      const created = await createMemoryEvent(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        {
          title: body.title!,
          category: body.category!,
          eventDate: body.eventDate ?? new Date().toISOString().slice(0, 10),
          description: body.description,
          visibility: body.visibility,
          createdBy: auth.claims.sub,
        },
      );
      await emitMutationAudit(db, auth.claims, schoolMemoriesAudit.created(created.id), req);
      return created;
    });
    return jsonResponse(envelope({ id: event.id, title: event.title }), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("MEMORIES_ERROR", "Create event failed", 500);
  }
}

export async function handlePublishMemoryEvent(
  req: Request,
  config: AppConfig,
  eventId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireMemoriesWrite(auth.claims);
  if (denied) return denied;

  try {
    const event = await withTenantContext(config, auth.claims, async (db) => {
      const published = await publishMemoryEvent(db, eventId);
      await emitMutationAudit(db, auth.claims, schoolMemoriesAudit.published(eventId), req);
      return published;
    });
    return jsonResponse(envelope({ id: event.id, status: event.status }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("MEMORIES_ERROR", "Publish event failed", 500);
  }
}

export async function handleMemoryAnalytics(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireMemoriesRead(auth.claims);
  if (denied) return denied;

  try {
    const analytics = await withTenantContext(config, auth.claims, (db) =>
      buildMemoryAnalytics(db)
    );
    return jsonResponse(envelope(analytics));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("MEMORIES_ERROR", "Analytics failed", 500);
  }
}

export async function handleMemoryUploadPresign(
  req: Request,
  config: AppConfig,
  eventId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireMemoriesWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    albumId?: string;
    albumTitle?: string;
    filename?: string;
    mediaType?: string;
    contentType?: string;
    sizeBytes?: number;
  }>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body required", 422);
  }
  if (!body.filename) {
    return errorEnvelope("VALIDATION_ERROR", "filename is required", 422);
  }
  // RT-31: reject wrong-type / oversized uploads at presign (bucket enforces too).
  const uploadError = validateUpload(
    body.filename,
    { contentType: body.contentType, sizeBytes: body.sizeBytes },
    MEMORY_UPLOAD_CONSTRAINTS,
  );
  if (uploadError) {
    return errorEnvelope("VALIDATION_ERROR", uploadError, 422);
  }
  // PRC-A Batch 4 — cumulative storage quota (caps 31–36). validateUpload above
  // is the PER-FILE cap; this is the ORG-cumulative cap. Inert unless
  // STORAGE_QUOTA_ENFORCEMENT=true AND the plan sets a limit (both dark today),
  // so this is a no-op on the current deploy. Uses the client-declared size, the
  // same value validateUpload already trusts.
  const quotaDenied = await enforceStorageQuota(config, auth.claims, body.sizeBytes ?? 0);
  if (quotaDenied) return quotaDenied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      let albumId = body.albumId;
      if (!albumId) {
        const album = await createMemoryAlbum(
          db,
          orgId,
          schoolId,
          eventId,
          body.albumTitle ?? "Album",
        );
        albumId = album.id;
      }
      const path = buildMemoryStoragePath(
        orgId,
        schoolId,
        eventId,
        albumId!,
        body.filename!,
      );
      const upload = await createMemoryUploadUrl(config, path);
      return { albumId, ...upload, mediaType: body.mediaType ?? "photo" };
    });
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const message = error instanceof Error ? error.message : "Presign failed";
    return errorEnvelope("MEMORIES_UPLOAD_ERROR", message, 500);
  }
}

export async function handleMemoryUploadConfirm(
  req: Request,
  config: AppConfig,
  eventId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireMemoriesWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    albumId?: string;
    storagePath?: string;
    title?: string;
    mediaType?: string;
    // PRC-A Batch 4 — the client echoes the size it declared at presign so the
    // durable upload is counted against the org storage quota. Optional: a
    // missing/zero value simply records nothing (fail-open under-count, never a
    // crash) rather than blocking a confirm.
    sizeBytes?: number;
  }>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body required", 422);
  }
  if (!body.albumId || !body.storagePath || !body.title) {
    return errorEnvelope("VALIDATION_ERROR", "albumId, storagePath, title required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const shareToken = crypto.randomUUID();

  try {
    const media = await withTenantContext(config, auth.claims, async (db) => {
      const row = await confirmMemoryMediaUpload(db, orgId, schoolId, {
        albumId: body.albumId!,
        eventId,
        title: body.title!,
        mediaType: body.mediaType ?? "photo",
        storagePath: body.storagePath!,
        shareToken,
      });
      await emitMutationAudit(db, auth.claims, schoolMemoriesAudit.mediaUploaded(row.id), req);
      return row;
    });
    // PRC-A Batch 4 — count the durable upload against the org storage quota, in a
    // SEPARATE best-effort transaction. It is deliberately NOT folded into the
    // confirm txn above: a failed INSERT aborts a Postgres transaction, so an
    // in-txn recording error would roll back the (already successful) media row +
    // audit. Recording is always on (usage is real before enforcement flips on);
    // a zero/absent size records nothing. Must never fail a confirm → fail-open.
    try {
      await withTenantContext(config, auth.claims, (db) =>
        recordStorageUsage(db, { organizationId: orgId, schoolId }, {
          deltaBytes: body.sizeBytes ?? 0,
          category: "memories",
          objectKey: body.storagePath!,
          actorId: auth.claims.sub,
        }));
    } catch (recErr) {
      console.error("storage usage record (memories) failed:", recErr);
    }
    // PRC-A Batch 9 — record the malware-scan status for the durable object, in a
    // SEPARATE best-effort transaction (same reasoning as the usage recording). With
    // no AV configured the status is an HONEST 'skipped' (not scanned) — never a
    // fabricated 'clean'. Must never fail a confirm → fail-open.
    try {
      const { status, engine } = initialScanStatus();
      await withTenantContext(config, auth.claims, (db) =>
        recordUploadScan(db, {
          organizationId: orgId,
          schoolId,
          bucket: "school-memories",
          objectKey: body.storagePath!,
          module: "memories",
          status,
          engine,
          requestedBy: auth.claims.sub,
        }));
    } catch (scanErr) {
      console.error("upload scan record (memories) failed:", scanErr);
    }
    const downloadUrl = await createMemoryDownloadUrl(config, body.storagePath!);
    return jsonResponse(envelope({
      id: media.id,
      shareToken,
      downloadUrl,
    }), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("MEMORIES_UPLOAD_ERROR", "Confirm upload failed", 500);
  }
}

export async function handleMemoryMediaDownload(
  req: Request,
  config: AppConfig,
  mediaId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireMemoriesRead(auth.claims);
  if (denied) return denied;

  try {
    const path = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await db.queryObject<{ storage_path: string }>(
        `SELECT storage_path FROM school_memory_media WHERE id = $1`,
        [mediaId],
      );
      const p = rows[0]?.storage_path;
      if (!p) throw new Error("Media not found");
      await emitMutationAudit(db, auth.claims, schoolMemoriesAudit.mediaDownloaded(mediaId), req);
      return p;
    });
    // PRC-A Batch 9 — malware-scan serving gate (default OFF → null → no change).
    const gate = await enforceUploadScanGate(config, auth.claims, path);
    if (gate) return gate;
    return jsonResponse(envelope({ downloadUrl: await createMemoryDownloadUrl(config, path) }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("MEMORIES_ERROR", "Download URL failed", 500);
  }
}

export async function handleMemoryShareLink(
  req: Request,
  config: AppConfig,
  shareToken: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireMemoriesRead(auth.claims);
  if (denied) return denied;

  try {
    const resolved = await withTenantContext(config, auth.claims, async (db) => {
      const media = await getMediaByShareToken(db, shareToken);
      if (!media?.storage_path) throw new Error("Share link not found");
      await emitMutationAudit(
        db,
        auth.claims,
        schoolMemoriesAudit.shareResolved(shareToken, media.id),
        req,
      );
      return { mediaId: media.id, eventId: media.event_id, storagePath: media.storage_path };
    });
    // PRC-A Batch 9 — malware-scan serving gate (default OFF → null → no change).
    const gate = await enforceUploadScanGate(config, auth.claims, resolved.storagePath);
    if (gate) return gate;
    const downloadUrl = await createMemoryDownloadUrl(config, resolved.storagePath);
    return jsonResponse(envelope({ mediaId: resolved.mediaId, eventId: resolved.eventId, downloadUrl }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("MEMORIES_ERROR", "Share link failed", 500);
  }
}
