import { apiFetch, type RequestOptions } from './client';

export interface ListResult<T> {
  items: T[];
  total: number;
}

/**
 * Fetches a list endpoint and normalizes the response to { items, total },
 * tolerating the backend's `listEnvelope` shape ({items,total}), a bare array,
 * or a `{ data: [...] }` / `{ <key>: [...] }` wrapper. No fabricated data.
 */
export async function fetchList<T>(
  path: string,
  opts: RequestOptions & { key?: string } = {},
): Promise<ListResult<T>> {
  const { key, ...req } = opts;
  const raw = await apiFetch<unknown>(path, req);
  if (Array.isArray(raw)) return { items: raw as T[], total: raw.length };
  if (raw && typeof raw === 'object') {
    const obj = raw as Record<string, unknown>;
    const arr = (obj.items ?? obj.data ?? (key ? obj[key] : undefined)) as T[] | undefined;
    if (Array.isArray(arr)) return { items: arr, total: typeof obj.total === 'number' ? obj.total : arr.length };
  }
  return { items: [], total: 0 };
}
