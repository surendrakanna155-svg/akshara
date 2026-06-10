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
