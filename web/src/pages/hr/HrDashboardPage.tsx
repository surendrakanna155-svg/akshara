import { useNavigate } from 'react-router-dom';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { Button, Card, CardHeader, KpiCard, PageHeader, StatGrid } from '@/components/ui';
import { ModuleTabs } from '@/components/shell/ModuleTabs';
import { TrendChart } from '@/components/charts';
import type { HrDashboardData } from '@/lib/contracts/hr';
import { HR_TABS } from './shared';

const fetchDashboard = () => apiFetch<HrDashboardData>('/hr/dashboard');

const ICONS = ['groups', 'fact_check', 'event_busy', 'person_search'];

export function HrDashboardPage() {
  const navigate = useNavigate();
  const query = useModuleQuery(['hr', 'dashboard'], fetchDashboard);

  return (
    <div className="space-y-s6">
      <PageHeader
        title="Staff & HR"
        subtitle="Workforce overview"
        icon="badge"
        tabs={<ModuleTabs tabs={HR_TABS} />}
        actions={
          <Button icon="groups" variant="outlined" onClick={() => navigate('/hr/employees')}>
            Directory
          </Button>
        }
      />

      <AsyncBoundary
        query={query}
        unavailableTitle="Workforce overview is ready"
        unavailableMessage="Headcount, attendance and recruitment KPIs load here from /hr/dashboard once the backend is connected."
      >
        {(d) => (
          <div className="space-y-s6">
            <StatGrid>
              {d.kpis.map((k, i) => (
                <KpiCard key={k.id} label={k.label} value={k.value} icon={ICONS[i % ICONS.length]} delta={k.delta} />
              ))}
            </StatGrid>
            <div className="grid grid-cols-1 gap-s4 xl:grid-cols-2">
              <Card>
                <CardHeader title="Headcount trend" icon="trending_up" />
                <TrendChart data={d.headcountTrend} xKey="month" series={[{ key: 'count', name: 'Employees' }]} />
              </Card>
              <Card>
                <CardHeader title="Attendance trend" icon="fact_check" />
                <TrendChart data={d.attendanceTrend} xKey="month" series={[{ key: 'rate', name: 'Attendance %' }]} type="line" />
              </Card>
            </div>
          </div>
        )}
      </AsyncBoundary>
    </div>
  );
}
