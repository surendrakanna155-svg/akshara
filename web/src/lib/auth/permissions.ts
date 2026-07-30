import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';

/** An entry of `permissions`: the live contract sends objects, dev shapes send strings. */
type PermissionEntry = string | { permission?: string; name?: string; key?: string };

interface PermissionsResponse {
  /** Granted module keys (matches navConfig moduleKey values). */
  modules?: string[];
  /** Alternative shape: granted permissions we map to module keys. */
  permissions?: PermissionEntry[];
}

/** Live `/auth/permissions` returns `[{ permission, source }]`; older shapes return plain strings. */
function permissionName(entry: PermissionEntry): string | null {
  if (typeof entry === 'string') return entry;
  const v = entry?.permission ?? entry?.name ?? entry?.key;
  return typeof v === 'string' ? v : null;
}

/**
 * Live RBAC: in live mode, fetches the signed-in user's granted modules from
 * `/auth/permissions` (the same source the Flutter app uses). Returns null in
 * demo mode (no backend) so nav falls back to the role→module map in roles.ts.
 * When live grants arrive, they OVERRIDE the approximate map — the audit fix for
 * the RBAC-approximation finding.
 */
export function useGrantedModules(): string[] | null {
  const q = useModuleQuery<PermissionsResponse>(['auth', 'permissions'], () => apiFetch<PermissionsResponse>('/auth/permissions'));
  if (!q.data) return null;
  if (Array.isArray(q.data.modules)) return q.data.modules;
  if (Array.isArray(q.data.permissions)) {
    // permission strings like "module.finance.view" → "finance"
    const keys = q.data.permissions
      .map(permissionName)
      .filter((n): n is string => n !== null)
      .map((n) => n.split('.')[1])
      .filter(Boolean);
    // A flat action vocabulary ("viewFinance") carries no module key. Fall back to
    // the role→module map rather than reporting an empty grant set, which would
    // wrongly read as "no modules granted".
    return keys.length > 0 ? Array.from(new Set(keys)) : null;
  }
  return null;
}

export interface PermissionCheck {
  /** True only when the live grant set is present AND contains the slug. */
  granted: boolean;
  loading: boolean;
  /** No live backend configured (demo mode) — cannot determine the grant. */
  unavailable: boolean;
}

/**
 * Live RBAC single-permission check against the same `/auth/permissions` grant
 * set the nav uses (react-query dedupes the fetch). Used to gate cross-tenant
 * platform-support surfaces on a flat permission slug (e.g. `platformSupport`)
 * that carries no module key. Returns `granted:false` with `unavailable:true` in
 * demo mode so callers render an honest "requires a live session" state rather
 * than a false deny.
 */
export function useHasPermission(slug: string): PermissionCheck {
  const q = useModuleQuery<PermissionsResponse>(['auth', 'permissions'], () =>
    apiFetch<PermissionsResponse>('/auth/permissions'),
  );
  const unavailable = q.unavailable;
  if (!q.data) return { granted: false, loading: q.isLoading, unavailable };
  const names = Array.isArray(q.data.permissions)
    ? q.data.permissions.map(permissionName).filter((n): n is string => n !== null)
    : [];
  const modules = Array.isArray(q.data.modules) ? q.data.modules : [];
  return { granted: names.includes(slug) || modules.includes(slug), loading: q.isLoading, unavailable };
}
