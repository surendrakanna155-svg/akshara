import { useNavigate } from 'react-router-dom';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { Button, Card, CardHeader, KpiCard, PageHeader, StatGrid, Text } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { BarChartCard } from '@/components/charts';
import { ModuleTabs } from '@/components/shell/ModuleTabs';
import { normalizeAdmissionsDashboard } from '@/lib/contracts/admissions';
import type { AdmissionsDashboard } from '@/lib/contracts/admissions';
import { formatPercent, humanize } from '@/lib/utils/format';
import { ADMISSIONS_TABS } from './shared';

const fetchDashboard = async (): Promise<AdmissionsDashboard> =>
  normalizeAdmissionsDashboard(await apiFetch<Record<string, unknown>>('/admissions/dashboard'));

export function AdmissionsDashboardPage() {
  const navigate = useNavigate();
  const query = useModuleQuery(['admissions', 'dashboard'], fetchDashboard);

  return (
    <div className="space-y-s6">
      <PageHeader
        title="Admissions"
        subtitle="Enquiry-to-enrolment overview"
        icon="how_to_reg"
        tabs={<ModuleTabs tabs={ADMISSIONS_TABS} />}
        actions={
          <>
            <Button variant="outlined" icon="table_rows" onClick={() => navigate('/admissions/leads')}>
              All leads
            </Button>
            <Button icon="add" onClick={() => navigate('/admissions/leads')}>
              New lead
            </Button>
          </>
        }
      />

      <AsyncBoundary
        query={query}
        unavailableTitle="Admissions overview is ready"
        unavailableMessage="Pipeline KPIs and the stage funnel load here from /admissions/dashboard once the backend is connected."
      >
        {(d) => {
          const funnel = Object.entries(d.stageCounts ?? {}).map(([stage, count]) => ({ stage: humanize(stage), count }));
          return (
            <div className="space-y-s6">
              <StatGrid>
                <KpiCard label="Total Leads" value={d.totalLeads} icon="groups" onClick={() => navigate('/admissions/leads')} />
                <KpiCard label="Hot Leads" value={d.hotLeads} icon="local_fire_department" accent="error" />
                <KpiCard label="Conversion Rate" value={formatPercent(d.conversionRate)} icon="trending_up" accent="tertiary" />
                <KpiCard label="Pending Follow-ups" value={d.pendingFollowUps} icon="event" accent="warning" />
              </StatGrid>

              <div className="grid grid-cols-1 gap-s4 xl:grid-cols-3">
                <Card className="xl:col-span-2">
                  <CardHeader title="Pipeline by stage" subtitle="Leads at each stage" icon="filter_alt" />
                  {funnel.length > 0 ? (
                    <BarChartCard data={funnel} xKey="stage" series={[{ key: 'count', name: 'Leads' }]} />
                  ) : (
                    <Text variant="body-md" className="py-s8 text-center text-on-surface-variant">
                      No stage data yet.
                    </Text>
                  )}
                </Card>

                <Card>
                  <CardHeader title="Highlights" icon="insights" />
                  <ul className="space-y-s3">
                    <Highlight icon="person_off" label="Unassigned leads" value={d.unassignedLeads !== undefined ? String(d.unassignedLeads) : '—'} tone="warning" />
                    <Highlight icon="campaign" label="Top source" value={d.topSource ? `${humanize(d.topSource)} (${d.topSourceCount})` : '—'} tone="info" />
                    <Highlight icon="local_fire_department" label="Hot leads" value={String(d.hotLeads)} tone="error" />
                    <Highlight icon="event" label="Pending follow-ups" value={String(d.pendingFollowUps)} tone="warning" />
                  </ul>
                </Card>
              </div>
            </div>
          );
        }}
      </AsyncBoundary>
    </div>
  );
}

function Highlight({ icon, label, value, tone }: { icon: string; label: string; value: string; tone: 'info' | 'warning' | 'error' }) {
  const bg = { info: 'bg-primary-container text-on-primary-container', warning: 'bg-warning-container text-warning', error: 'bg-error-container text-error' }[tone];
  return (
    <li className="flex items-center gap-s3">
      <span className={`grid h-9 w-9 place-items-center rounded-lg ${bg}`}>
        <Icon name={icon} size={18} />
      </span>
      <Text variant="body-md" className="text-on-surface-variant">
        {label}
      </Text>
      <Text variant="title-sm" className="ml-auto text-on-surface ak-tabular">
        {value}
      </Text>
    </li>
  );
}
