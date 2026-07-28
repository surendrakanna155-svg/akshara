import type { TenantQueryClient } from "../tenant_db.ts";

export interface MemoryEventRow {
  id: string;
  title: string;
  category: string;
  event_date: string;
  description: string | null;
  visibility: string;
  status: string;
  created_at: string;
}

export interface MemoryAlbumRow {
  id: string;
  event_id: string;
  title: string;
  cover_label: string | null;
  media_count: number;
}

export interface MemoryMediaRow {
  id: string;
  album_id: string;
  media_type: string;
  title: string;
  storage_url: string;
  thumbnail_url: string | null;
  storage_path?: string | null;
  share_token?: string | null;
}

export async function listMemoryEvents(
  client: TenantQueryClient,
  filters: { category?: string; status?: string },
): Promise<MemoryEventRow[]> {
  const conditions = ["1=1"];
  const params: unknown[] = [];
  let idx = 1;
  if (filters.category) {
    conditions.push(`category = $${idx}`);
    params.push(filters.category);
    idx += 1;
  }
  if (filters.status) {
    conditions.push(`status = $${idx}`);
    params.push(filters.status);
  } else {
    conditions.push(`status = 'published'`);
  }
  return await client.queryObject<MemoryEventRow>(
    `SELECT id, title, category, event_date, description, visibility, status, created_at
     FROM school_memory_events
     WHERE ${conditions.join(" AND ")}
     ORDER BY event_date DESC`,
    params,
  );
}

export async function getMemoryEvent(
  client: TenantQueryClient,
  eventId: string,
): Promise<MemoryEventRow | null> {
  const rows = await client.queryObject<MemoryEventRow>(
    `SELECT id, title, category, event_date, description, visibility, status, created_at
     FROM school_memory_events WHERE id = $1`,
    [eventId],
  );
  return rows[0] ?? null;
}

export async function listAlbumsForEvent(
  client: TenantQueryClient,
  eventId: string,
): Promise<MemoryAlbumRow[]> {
  return await client.queryObject<MemoryAlbumRow>(
    `SELECT id, event_id, title, cover_label, media_count
     FROM school_memory_albums WHERE event_id = $1 ORDER BY title`,
    [eventId],
  );
}

export async function listMediaForAlbum(
  client: TenantQueryClient,
  albumId: string,
): Promise<MemoryMediaRow[]> {
  return await client.queryObject<MemoryMediaRow>(
    `SELECT id, album_id, media_type, title, storage_url, thumbnail_url
     FROM school_memory_media WHERE album_id = $1 ORDER BY created_at`,
    [albumId],
  );
}

export async function createMemoryEvent(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: {
    title: string;
    category: string;
    eventDate: string;
    description?: string;
    visibility?: string;
    createdBy: string;
  },
): Promise<MemoryEventRow> {
  const rows = await client.queryObject<MemoryEventRow>(
    `INSERT INTO school_memory_events (
       organization_id, school_id, title, category, event_date,
       description, visibility, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING id, title, category, event_date, description, visibility, status, created_at`,
    [
      organizationId,
      schoolId,
      input.title,
      input.category,
      input.eventDate,
      input.description ?? null,
      input.visibility ?? "school",
      input.createdBy,
    ],
  );
  return rows[0]!;
}

export async function publishMemoryEvent(
  client: TenantQueryClient,
  eventId: string,
): Promise<MemoryEventRow> {
  const rows = await client.queryObject<MemoryEventRow>(
    `UPDATE school_memory_events SET status = 'published'
     WHERE id = $1
     RETURNING id, title, category, event_date, description, visibility, status, created_at`,
    [eventId],
  );
  if (!rows[0]) throw new Error("Event not found");
  return rows[0];
}

export async function buildMemoryAnalytics(
  client: TenantQueryClient,
): Promise<{ totalEvents: number; totalAlbums: number; totalMedia: number; byCategory: Record<string, number> }> {
  const events = await client.queryObject<{ category: string; count: number }>(
    `SELECT category, count(*)::int AS count FROM school_memory_events
     WHERE status = 'published' GROUP BY category`,
  );
  const albums = await client.queryObject<{ count: number }>(
    `SELECT count(*)::int AS count FROM school_memory_albums`,
  );
  const media = await client.queryObject<{ count: number }>(
    `SELECT count(*)::int AS count FROM school_memory_media`,
  );
  const byCategory: Record<string, number> = {};
  for (const row of events) byCategory[row.category] = row.count;
  return {
    totalEvents: events.reduce((s, e) => s + e.count, 0),
    totalAlbums: albums[0]?.count ?? 0,
    totalMedia: media[0]?.count ?? 0,
    byCategory,
  };
}

export async function createMemoryAlbum(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  eventId: string,
  title: string,
): Promise<MemoryAlbumRow> {
  const rows = await client.queryObject<MemoryAlbumRow>(
    `INSERT INTO school_memory_albums (
       organization_id, school_id, event_id, title
     ) VALUES ($1, $2, $3, $4)
     RETURNING id, event_id, title, cover_label, media_count`,
    [organizationId, schoolId, eventId, title],
  );
  return rows[0]!;
}

export async function confirmMemoryMediaUpload(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: {
    albumId: string;
    eventId: string;
    title: string;
    mediaType: string;
    storagePath: string;
    shareToken: string;
  },
): Promise<MemoryMediaRow> {
  const rows = await client.queryObject<MemoryMediaRow>(
    `INSERT INTO school_memory_media (
       organization_id, school_id, album_id, media_type, title,
       storage_url, storage_path, share_token
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING id, album_id, media_type, title, storage_url, thumbnail_url`,
    [
      organizationId,
      schoolId,
      input.albumId,
      input.mediaType,
      input.title,
      input.storagePath,
      input.storagePath,
      input.shareToken,
    ],
  );
  await client.queryObject(
    `UPDATE school_memory_albums
     SET media_count = media_count + 1
     WHERE id = $1`,
    [input.albumId],
  );
  return rows[0]!;
}

/**
 * The storage path for a single media item, or null when the media id does
 * not exist (or has no stored object yet).
 */
export async function getMediaStoragePath(
  client: TenantQueryClient,
  mediaId: string,
): Promise<string | null> {
  const rows = await client.queryObject<{ storage_path: string }>(
    `SELECT storage_path FROM school_memory_media WHERE id = $1`,
    [mediaId],
  );
  return rows[0]?.storage_path ?? null;
}

export async function getMediaByShareToken(
  client: TenantQueryClient,
  shareToken: string,
): Promise<(MemoryMediaRow & { event_id: string }) | null> {
  const rows = await client.queryObject<MemoryMediaRow & { event_id: string }>(
    `SELECT m.id, m.album_id, m.media_type, m.title, m.storage_url, m.thumbnail_url,
            m.storage_path, m.share_token, a.event_id
     FROM school_memory_media m
     JOIN school_memory_albums a ON a.id = m.album_id
     WHERE m.share_token = $1`,
    [shareToken],
  );
  return rows[0] ?? null;
}
