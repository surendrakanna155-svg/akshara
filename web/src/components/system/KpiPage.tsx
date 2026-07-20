import type { ReactNode } from 'react';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { KpiCard, PageHeader, StatGrid } from '@/components/ui';
import { ModuleTabs, type ModuleTab } from '@/components/shell/ModuleTabs';

interface KpiLike {
  kpis: { id: string; label: string; value: string; detail?: string; delta?: number }[];
}

const DEFAULT_ICONS = ['insights', 'trending_up', 'groups', 'account_balance', 'fact_check', 'workspace_premium'];

/**
 * Executive dashboard page: fetches an endpoint returning `{ kpis: [...] }` and
 * renders a KPI grid + optional extra section. No fabricated data — the KPIs come
 * from the live endpoint; unwired endpoints render the awaiting-backend state.
 */
export function KpiPage<T extends KpiLike>({
  title,
  subtitle,
  icon,
  tabs,
  endpoint,
  queryKey,
  actions,
  icons = DEFAULT_ICONS,
  children,
  unavailableMessage,
}: {
  title: string;
  subtitle?: string;
  icon?: string;
  tabs?: ModuleTab[];
  endpoint: string;
  queryKey: unknown[];
  actions?: ReactNode;
  icons?: string[];
  children?: (data: T) => ReactNode;
  unavailableMessage?: string;
}) {
  const query = useModuleQuery<T>(queryKey, () => apiFetch<T>(endpoint));
  return (
    <div className="space-y-s6">
      <PageHeader title={title} subtitle={subtitle} icon={icon} tabs={tabs ? <ModuleTabs tabs={tabs} /> : undefined} actions={actions} />
      <AsyncBoundary
        query={query}
        unavailableTitle={`${title} is ready`}
        unavailableMessage={unavailableMessage ?? `KPIs and insights load here from ${endpoint} once the backend is connected.`}
        isEmpty={(d) => !d.kpis || d.kpis.length === 0}
      >
        {(d) => (
          <div className="space-y-s6">
            <StatGrid>
              {d.kpis.map((k, i) => (
                <KpiCard key={k.id} label={k.label} value={k.value} icon={icons[i % icons.length]} delta={k.delta} hint={k.detail} />
              ))}
            </StatGrid>
            {children?.(d)}
          </div>
        )}
      </AsyncBoundary>
    </div>
  );
}
