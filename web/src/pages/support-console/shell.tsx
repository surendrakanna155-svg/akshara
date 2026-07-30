/**
 * Support Console shell — the route gate (platformSupport RBAC), the section nav
 * (Queue / Clusters), and the shared status/severity/cluster chips.
 */
import { NavLink, Outlet } from 'react-router-dom';
import { cn } from '@/lib/utils/cn';
import { Icon } from '@/components/Icon';
import { DataUnavailable, LoadingState, StatusChip, Text } from '@/components/ui';
import { useHasPermission } from '@/lib/auth/permissions';
import { severityMeta, supportStatusMeta } from '@/lib/contracts/support';

export const PLATFORM_SUPPORT_PERMISSION = 'platformSupport';

/**
 * Gates the whole `/support-console` subtree on the `platformSupport` permission
 * (the server also enforces it → 403). Demo mode has no live grant, so it renders
 * the honest "needs a live session" state rather than a false allow/deny.
 */
export function SupportConsoleGate() {
  const { granted, loading, unavailable } = useHasPermission(PLATFORM_SUPPORT_PERMISSION);

  if (unavailable) {
    return (
      <DataUnavailable
        icon="support_agent"
        title="NIKSHA OS Support Console"
        message="This cross-tenant support workspace requires a live platform-support session (a PLATFORM_ORG member holding the platformSupport permission). Connect the backend to sign in as support."
      />
    );
  }
  if (loading) return <LoadingState rows={6} />;
  if (!granted) {
    return (
      <div className="grid place-items-center px-s6 py-s12 text-center">
        <span className="mb-s4 grid h-16 w-16 place-items-center rounded-2xl bg-error-container text-error">
          <Icon name="lock" size={32} />
        </span>
        <Text variant="title-md" className="text-on-surface">
          Support Console access required
        </Text>
        <Text variant="body-md" className="mt-s1 max-w-reading text-on-surface-variant">
          The NIKSHA OS Support Console is restricted to the platform-support team. Your account does not hold the
          <span className="ak-mono"> platformSupport </span>
          permission.
        </Text>
      </div>
    );
  }
  return <Outlet />;
}

/** Queue / Clusters section switch. */
export function SupportSectionNav() {
  const tabs: { to: string; label: string; icon: string; end?: boolean }[] = [
    { to: '/support-console', label: 'Incident queue', icon: 'inbox', end: true },
    { to: '/support-console/clusters', label: 'Clusters', icon: 'hub' },
  ];
  return (
    <div className="flex items-center gap-s1 overflow-x-auto border-b border-outline-variant/65">
      {tabs.map((t) => (
        <NavLink
          key={t.to}
          to={t.to}
          end={t.end}
          className={({ isActive }) =>
            cn(
              'relative inline-flex items-center gap-s2 whitespace-nowrap px-s3 py-s3 ak-label-lg transition-colors duration-fast',
              isActive ? 'text-primary' : 'text-on-surface-variant hover:text-on-surface',
            )
          }
        >
          {({ isActive }) => (
            <>
              <Icon name={t.icon} size={18} />
              {t.label}
              {isActive && <span className="absolute inset-x-s2 -bottom-px h-[3px] rounded-full bg-primary" />}
            </>
          )}
        </NavLink>
      ))}
    </div>
  );
}

export function SupportStatusChip({ status }: { status: string }) {
  const m = supportStatusMeta(status);
  return <StatusChip status={m.status} label={m.label} icon={m.icon} />;
}

export function SeverityChip({ severity }: { severity: string }) {
  const m = severityMeta(severity);
  return <StatusChip status={m.status} label={m.label} icon={false} />;
}

/** "N schools" when the cluster size is known, else a plain "Clustered" pill. */
export function ClusterBadge({ count }: { count?: number | null }) {
  const label = typeof count === 'number' && count > 0 ? `${count} school${count === 1 ? '' : 's'}` : 'Clustered';
  return (
    <span className="inline-flex items-center gap-s1 rounded-full bg-indigo-container px-s2 py-[3px] ak-label-sm font-medium text-indigo">
      <Icon name="hub" size={14} />
      {label}
    </span>
  );
}
