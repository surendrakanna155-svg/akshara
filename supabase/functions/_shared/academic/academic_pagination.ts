export interface PaginationParams {
  page: number;
  pageSize: number;
}

export interface PaginationResult<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

export function offsetFor(page: number, pageSize: number): number {
  return Math.max(0, (page - 1) * pageSize);
}

export function clampPageSize(pageSize: number): number {
  return Math.min(Math.max(pageSize, 1), 100);
}

// ── ICA-C7: keyset (cursor) pagination ──────────────────────────────────────
// OFFSET pagination scans and discards `offset` rows per page, so deep pages on a
// large table are O(offset). Keyset pagination seeks on the ordered key (`id`) —
// `WHERE id > :cursor ORDER BY id LIMIT :n` — so every page is O(pageSize) regardless
// of depth. The trade-off (no random page access, no cheap total) is why it is offered
// alongside the existing page/total API rather than replacing it.

export interface KeysetParams {
  /** Opaque cursor = the `id` of the last row of the previous page; null/undefined = first page. */
  cursor?: string | null;
  pageSize: number;
}

export interface KeysetResult<T> {
  items: T[];
  pageSize: number;
  /** Pass as the next request's `cursor`; null when the current page is the last. */
  nextCursor: string | null;
  hasMore: boolean;
}

/**
 * Split rows fetched with `LIMIT pageSize + 1` (ordered by the cursor column) into the
 * page plus its `hasMore`/`nextCursor`. Fetching one extra row detects "more" without a
 * separate COUNT query. `idOf` returns a row's cursor value.
 */
export function keysetPageOf<R>(
  rows: readonly R[],
  pageSize: number,
  idOf: (row: R) => string,
): { rows: R[]; nextCursor: string | null; hasMore: boolean } {
  const hasMore = rows.length > pageSize;
  const pageRows = (hasMore ? rows.slice(0, pageSize) : rows.slice());
  const last = pageRows[pageRows.length - 1];
  const nextCursor = hasMore && last !== undefined ? idOf(last) : null;
  return { rows: pageRows, nextCursor, hasMore };
}
