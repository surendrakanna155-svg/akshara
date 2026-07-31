import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/lib/auth/AuthContext';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import {
  Button,
  Card,
  CardHeader,
  KpiCard,
  PageHeader,
  StatGrid,
  StatusChip,
  Text,
  Segmented,
  Divider,
} from '@/components/ui';
import { Icon } from '@/components/Icon';
import { TrendChart, BarChartCard, DonutChart } from '@/components/charts';
import type { DashboardData } from '@/lib/contracts/dashboard';
import { formatCompactCurrency, formatNumber } from '@/lib/utils/format';

const TONE = { info: 'info', success: 'success', warning: 'warning' } as const;

// Intended aggregation endpoint. It does NOT exist yet — logged as verified gap
// WEB-001 (docs/roadmap/WEB_TRACK_BACKEND_GAPS.md). Until built, the page renders
// the "Awaiting backend" state; no fabricated data is shown.
const fetchDashboard = () => apiFetch<DashboardData>('/dashboard/overview');

export function DashboardPage() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [range, setRange] = useState<'6m' | '12m' | 'ytd'>('6m');
  const rawQuery = useModuleQuery(['dashboard', range], fetchDashboard);

  // `/dashboard/overview` exists now, but it answers with `DashboardOverview`
  // ({students, attendanceToday, finance, admissions, recentEnrollments}) — not
  // the `DashboardData` shape below, which also needs kpis, enrollmentTrend,
  // feeCollection, attendanceByGrade, activity and approvals. WEB-001 is only
  // partially built.
  //
  // While the endpoint 500'd, the mismatch was invisible: the query errored and
  // AsyncBoundary showed an error state. Answering 200 pushes the payload into
  // the render path, where `d.kpis.students` dereferences undefined — and
  // AsyncBoundary is a QUERY-state boundary with no componentDidCatch, so the
  // page white-screens.
  //
  // Treat a payload that is not DashboardData as "not wired yet" so the existing
  // honest state is shown instead. Deliberately NOT a partial mapping of the
  // fields that do exist: that would render four populated KPI cards with no
  // deltas beside four empty panels, which reads as real data and is not.
  const isDashboardData =
    !!rawQuery.data && typeof (rawQuery.data as Partial<DashboardData>).kpis === 'object';
  const query = {
    ...rawQuery,
    unavailable: rawQuery.unavailable || (!rawQuery.isLoading && !rawQuery.error && !isDashboardData),
  };

  const greeting = new Date().getHours() < 12 ? 'Good morning' : new Date().getHours() < 17 ? 'Good afternoon' : 'Good evening';

  return (
    <div className="space-y-s6">
      <PageHeader
        title={`${greeting}, ${user?.name?.split(' ')[0] ?? 'there'}`}
        subtitle={`School overview for ${user?.schoolName ?? 'your school'}.`}
        actions={
          <>
            <Segmented
              value={range}
              onChange={setRange}
              options={[
                { value: '6m', label: '6M' },
                { value: '12m', label: '12M' },
                { value: 'ytd', label: 'YTD' },
              ]}
            />
            <Button icon="download" variant="outlined">
              Export
            </Button>
            <Button icon="add" onClick={() => navigate('/admissions/leads')}>
              New admission
            </Button>
          </>
        }
      />

      <AsyncBoundary
        query={query}
        loading={<DashboardSkeleton />}
        unavailableTitle="School overview is ready"
        unavailableMessage="KPIs, enrolment, fee collection and approvals will populate here the moment the analytics endpoint is connected."
      >
        {(d) => (
          <div className="space-y-s6">
            <StatGrid>
              <KpiCard label="Total Students" value={formatNumber(d.kpis.students)} icon="groups" delta={d.kpis.studentsDelta} hint="vs last term" onClick={() => navigate('/sis/registry')} />
              <KpiCard label="Attendance Today" value={`${d.kpis.attendanceToday}%`} icon="fact_check" accent="tertiary" delta={d.kpis.attendanceDelta} onClick={() => navigate('/attendance')} />
              <KpiCard label="Fees Collected (MTD)" value={formatCompactCurrency(d.kpis.feesCollected)} icon="account_balance" accent="indigo" delta={d.kpis.feesDelta} onClick={() => navigate('/finance/dashboard')} />
              <KpiCard label="Pending Admissions" value={d.kpis.pendingAdmissions} icon="how_to_reg" accent="warning" delta={d.kpis.admissionsDelta} onClick={() => navigate('/admissions/applications')} />
            </StatGrid>

            <div className="grid grid-cols-1 gap-s4 xl:grid-cols-3">
              <Card className="xl:col-span-2">
                <CardHeader title="Enrolment trend" subtitle="Active students vs capacity" icon="trending_up" />
                <TrendChart
                  data={d.enrollmentTrend}
                  xKey="month"
                  series={[
                    { key: 'students', name: 'Students' },
                    { key: 'capacity', name: 'Capacity' },
                  ]}
                />
              </Card>
              <Card>
                <CardHeader title="Attendance by section" icon="donut_large" />
                <DonutChart data={d.attendanceByGrade} />
                <div className="mt-s3 space-y-s2">
                  {d.attendanceByGrade.map((g, i) => (
                    <div key={g.name} className="flex items-center gap-s2 ak-body-sm">
                      <span className="h-2.5 w-2.5 rounded-full" style={{ background: `rgb(var(--ak-chart${(i % 4) + 1}))` }} />
                      <span className="text-on-surface-variant">{g.name}</span>
                      <span className="ml-auto font-semibold text-on-surface ak-tabular">{g.value}%</span>
                    </div>
                  ))}
                </div>
              </Card>
            </div>

            <div className="grid grid-cols-1 gap-s4 xl:grid-cols-3">
              <Card className="xl:col-span-2">
                <CardHeader
                  title="Fee collection"
                  subtitle="Collected vs outstanding"
                  icon="payments"
                  action={
                    <Button variant="text" size="sm" trailingIcon="chevron_right" onClick={() => navigate('/finance/collections')}>
                      View
                    </Button>
                  }
                />
                <BarChartCard
                  data={d.feeCollection}
                  xKey="month"
                  series={[
                    { key: 'collected', name: 'Collected' },
                    { key: 'due', name: 'Outstanding' },
                  ]}
                />
              </Card>

              <Card padded={false}>
                <div className="p-s5 pb-s3">
                  <CardHeader title="Pending approvals" icon="approval" className="mb-0" />
                </div>
                <Divider />
                <ul>
                  {d.approvals.map((a) => (
                    <li key={a.id} className="flex items-center gap-s3 px-s5 py-s3 transition-colors hover:bg-surface-low">
                      <span className="grid h-9 w-9 place-items-center rounded-lg bg-surface-container text-on-surface-variant">
                        <Icon name="pending_actions" size={18} />
                      </span>
                      <div className="min-w-0 flex-1">
                        <Text variant="label-lg" className="truncate text-on-surface">
                          {a.title}
                        </Text>
                        <Text variant="body-sm" className="text-on-surface-variant">
                          {a.requester} · {a.type}
                          {a.amount ? ` · ${a.amount}` : ''}
                        </Text>
                      </div>
                      <button className="grid h-8 w-8 place-items-center rounded-full text-success hover:bg-success-container">
                        <Icon name="check" size={18} />
                      </button>
                      <button className="grid h-8 w-8 place-items-center rounded-full text-error hover:bg-error-container">
                        <Icon name="close" size={18} />
                      </button>
                    </li>
                  ))}
                </ul>
              </Card>
            </div>

            <Card padded={false}>
              <div className="p-s5 pb-s3">
                <CardHeader title="Recent activity" icon="history" className="mb-0" />
              </div>
              <Divider />
              <ul>
                {d.activity.map((a, i) => (
                  <li key={a.id} className={`flex items-center gap-s3 px-s5 py-s3 ${i > 0 ? 'border-t border-outline-variant/50' : ''}`}>
                    <span className="grid h-9 w-9 place-items-center rounded-lg bg-surface-container">
                      <Icon name={a.icon} size={18} className="text-on-surface-variant" />
                    </span>
                    <div className="min-w-0 flex-1">
                      <Text variant="label-lg" className="truncate text-on-surface">
                        {a.title}
                      </Text>
                      <Text variant="body-sm" className="truncate text-on-surface-variant">
                        {a.detail}
                      </Text>
                    </div>
                    <StatusChip status={TONE[a.tone]} label={a.time} icon={false} />
                  </li>
                ))}
              </ul>
            </Card>
          </div>
        )}
      </AsyncBoundary>
    </div>
  );
}

function DashboardSkeleton() {
  return (
    <div className="space-y-s6">
      <StatGrid>
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="h-32 animate-pulse rounded-xl border border-outline-variant/60 bg-surface" />
        ))}
      </StatGrid>
      <div className="grid grid-cols-1 gap-s4 xl:grid-cols-3">
        <div className="h-72 animate-pulse rounded-lg border border-outline-variant/60 bg-surface xl:col-span-2" />
        <div className="h-72 animate-pulse rounded-lg border border-outline-variant/60 bg-surface" />
      </div>
    </div>
  );
}
