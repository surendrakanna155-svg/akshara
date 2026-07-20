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
