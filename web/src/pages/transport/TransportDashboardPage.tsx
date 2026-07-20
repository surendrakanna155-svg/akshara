import { useNavigate } from 'react-router-dom';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { Button, Card, CardHeader, KpiCard, PageHeader, StatGrid, Text } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { ModuleTabs } from '@/components/shell/ModuleTabs';
import type { TransportDashboardData } from '@/lib/contracts/transport';
import { TRANSPORT_TABS } from './shared';

const fetchDashboard = () => apiFetch<TransportDashboardData>('/transport/dashboard');
const ICONS = ['directions_bus', 'route', 'groups', 'schedule'];

export function TransportDashboardPage() {
  const navigate = useNavigate();
  const query = useModuleQuery(['transport', 'dashboard'], fetchDashboard);

  return (
    <div className="space-y-s6">
      <PageHeader
        title="Transport"
        subtitle="Fleet and route overview"
        icon="directions_bus"
        tabs={<ModuleTabs tabs={TRANSPORT_TABS} />}
        actions={
          <Button variant="outlined" icon="route" onClick={() => navigate('/transport/routes')}>
            Routes
          </Button>
        }
      />
      <AsyncBoundary
        query={query}
        unavailableTitle="Transport overview is ready"
        unavailableMessage="Fleet KPIs and live delays load here from /transport/dashboard once the backend is connected."
      >
        {(d) => (
          <div className="space-y-s6">
            <StatGrid>
              {d.kpis.map((k, i) => (
                <KpiCard key={k.id} label={k.label} value={k.value} icon={ICONS[i % ICONS.length]} delta={k.delta} />
              ))}
            </StatGrid>
            <Card>
              <CardHeader title="Active delays" icon="warning" />
              {d.activeDelays.length > 0 ? (
                <ul className="space-y-s2">
                  {d.activeDelays.map((delay, i) => (
                    <li key={i} className="flex items-center gap-s2 rounded-md bg-warning-container/50 px-s3 py-s2">
                      <Icon name="schedule" size={18} className="text-warning" />
                      <Text variant="body-md" className="text-on-surface">
                        {delay}
                      </Text>
                    </li>
                  ))}
                </ul>
              ) : (
                <Text variant="body-md" className="py-s6 text-center text-on-surface-variant">
                  No active delays — all routes running on time.
                </Text>
              )}
            </Card>
          </div>
        )}
      </AsyncBoundary>
    </div>
  );
}
