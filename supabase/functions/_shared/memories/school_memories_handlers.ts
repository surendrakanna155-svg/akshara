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
    return errorEnvelope("VALIDATION_ERROR", "Request body required", 400);
  }
  if (!body.title || !body.category) {
    return errorEnvelope("VALIDATION_ERROR", "title and category are required", 400);
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
    return errorEnvelope("VALIDATION_ERROR", "Request body required", 400);
  }
  if (!body.filename) {
    return errorEnvelope("VALIDATION_ERROR", "filename is required", 400);
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
  }>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body required", 400);
  }
  if (!body.albumId || !body.storagePath || !body.title) {
    return errorEnvelope("VALIDATION_ERROR", "albumId, storagePath, title required", 400);
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
    const url = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await db.queryObject<{ storage_path: string }>(
        `SELECT storage_path FROM school_memory_media WHERE id = $1`,
        [mediaId],
      );
      const path = rows[0]?.storage_path;
      if (!path) throw new Error("Media not found");
      await emitMutationAudit(db, auth.claims, schoolMemoriesAudit.mediaDownloaded(mediaId), req);
      return await createMemoryDownloadUrl(config, path);
    });
    return jsonResponse(envelope({ downloadUrl: url }));
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
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const media = await getMediaByShareToken(db, shareToken);
      if (!media?.storage_path) throw new Error("Share link not found");
      await emitMutationAudit(
        db,
        auth.claims,
        schoolMemoriesAudit.shareResolved(shareToken, media.id),
        req,
      );
      const downloadUrl = await createMemoryDownloadUrl(config, media.storage_path);
      return { mediaId: media.id, eventId: media.event_id, downloadUrl };
    });
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("MEMORIES_ERROR", "Share link failed", 500);
  }
}
