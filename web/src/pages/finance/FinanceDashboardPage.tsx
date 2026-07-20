import { useNavigate } from 'react-router-dom';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { Button, Card, CardHeader, DataUnavailable, KpiCard, PageHeader, StatGrid, Text } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { ModuleTabs } from '@/components/shell/ModuleTabs';
import { BarChartCard } from '@/components/charts';
import { formatCompactCurrency, formatCurrency, formatPercent } from '@/lib/utils/format';
import type { FinanceDashboardData, FinanceKpi } from '@/lib/contracts/finance';
import { FINANCE_TABS } from './shared';

const fetchDashboard = () => apiFetch<FinanceDashboardData>('/finance/dashboard');
const ICONS = ['account_balance', 'payments', 'trending_up', 'receipt_long'];

/**
 * The live snapshot is a flat set of totals rather than a pre-built KPI list, so
 * the headline cards are projected from those real values. Nothing is derived
 * that the backend didn't send.
 */
function kpisFrom(d: FinanceDashboardData): FinanceKpi[] {
  return [
    { id: 'invoiced', label: 'Total invoiced', value: formatCompactCurrency(d.totalInvoiced) },
    { id: 'collected', label: 'Collected', value: formatCompactCurrency(d.totalCollected) },
    { id: 'outstanding', label: 'Outstanding', value: formatCompactCurrency(d.totalOutstanding) },
    { id: 'rate', label: 'Collection rate', value: formatPercent(d.collectionRate) },
  ];
}

export function FinanceDashboardPage() {
  const navigate = useNavigate();
  const query = useModuleQuery(['finance', 'dashboard'], fetchDashboard);

  return (
    <div className="space-y-s6">
      <PageHeader
        title="Finance"
        subtitle="Fee collection overview"
        icon="account_balance"
        tabs={<ModuleTabs tabs={FINANCE_TABS} />}
        actions={
          <>
            <Button variant="outlined" icon="table_rows" onClick={() => navigate('/finance/collections')}>
              Collections
            </Button>
            <Button icon="add" onClick={() => navigate('/finance/collections')}>
              Collect fee
            </Button>
          </>
        }
      />

      <AsyncBoundary
        query={query}
        unavailableTitle="Finance overview is ready"
        unavailableMessage="Collection KPIs and trends load here from /finance/dashboard once the backend is connected."
      >
        {(d) => (
          <div className="space-y-s6">
            <StatGrid>
              {kpisFrom(d).map((k, i) => (
                <KpiCard key={k.id} label={k.label} value={k.value} icon={ICONS[i % ICONS.length]} delta={k.delta} />
              ))}
            </StatGrid>
            <div className="grid grid-cols-1 gap-s4 xl:grid-cols-3">
              <Card className="xl:col-span-2">
                <CardHeader title="Collection trend" icon="trending_up" />
                {d.collectionTrend?.length ? (
                  <BarChartCard data={d.collectionTrend} xKey="label" series={[{ key: 'collected', name: 'Collected' }]} />
                ) : (
                  <DataUnavailable
                    icon="show_chart"
                    title="Trend not available"
                    message="The finance dashboard snapshot doesn't include a collection time series yet (gap WEB-006). Collections to date are shown above."
                  />
                )}
              </Card>
              <Card>
                <CardHeader title="At a glance" icon="insights" />
                <ul className="space-y-s3">
                  <li className="flex items-center gap-s3">
                    <span className="grid h-9 w-9 place-items-center rounded-lg bg-error-container text-error">
                      <Icon name="account_balance_wallet" size={18} />
                    </span>
                    <Text variant="body-md" className="text-on-surface-variant">
                      Outstanding
                    </Text>
                    <Text variant="title-sm" className="ml-auto ak-tabular text-on-surface">
                      {formatCurrency(d.totalOutstanding)}
                    </Text>
                  </li>
                  <li className="flex items-center gap-s3">
                    <span className="grid h-9 w-9 place-items-center rounded-lg bg-warning-container text-warning">
                      <Icon name="receipt_long" size={18} />
                    </span>
                    <Text variant="body-md" className="text-on-surface-variant">
                      Pending invoices
                    </Text>
                    <Text variant="title-sm" className="ml-auto ak-tabular text-on-surface">
                      {d.pendingInvoices}
                    </Text>
                  </li>
                </ul>
                {d.aiInsight && (
                  <div className="mt-s4 flex items-start gap-s2 rounded-md bg-primary-container/50 p-s3">
                    <Icon name="auto_awesome" size={18} className="mt-[2px] text-on-primary-container" />
                    <Text variant="body-sm" className="text-on-primary-container">
                      {d.aiInsight}
                    </Text>
                  </div>
                )}
                <Button className="mt-s4" fullWidth variant="outlined" icon="person_alert" onClick={() => navigate('/finance/defaulters')}>
                  View defaulters
                </Button>
              </Card>
            </div>
          </div>
        )}
      </AsyncBoundary>
    </div>
  );
}
