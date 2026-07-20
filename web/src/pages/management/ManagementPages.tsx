import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { KpiPage } from '@/components/system/KpiPage';
import { ResourceList } from '@/components/system/ResourceList';
import { ModuleSettingsPage } from '@/components/system/ModuleSettingsPage';
import { Button, Card, CardHeader, DataTable, StatusChip, Text, type Column, type SemanticStatus } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { BarChartCard } from '@/components/charts';
import { humanize } from '@/lib/utils/format';
import { MODULE_TABS } from '@/routes/navConfig';
import type {
  ManagementAnalyticsData,
  ManagementApprovalItem,
  ManagementApprovalStatus,
  ManagementClassSummaryRow,
  ManagementDashboardData,
  ManagementFunnelData,
} from '@/lib/contracts/management';

const TABS = MODULE_TABS.management;

const APPROVAL_STATUS: Record<ManagementApprovalStatus, { status: SemanticStatus; label: string }> = {
  pending: { status: 'warning', label: 'Pending' }, approved: { status: 'success', label: 'Approved' }, rejected: { status: 'error', label: 'Rejected' },
};
const AI_REC = { approve: { status: 'success' as const, label: 'AI: approve', icon: 'thumb_up' }, review: { status: 'warning' as const, label: 'AI: review', icon: 'search' }, reject: { status: 'error' as const, label: 'AI: reject', icon: 'thumb_down' } };

function ClassSummaryTable({ rows }: { rows: ManagementClassSummaryRow[] }) {
  const columns: Column<ManagementClassSummaryRow>[] = [
    { key: 'classLabel', header: 'Class', sortValue: (r) => r.classLabel, render: (r) => <span className="ak-label-lg text-on-surface">{r.classLabel}</span> },
    { key: 'students', header: 'Students', align: 'right', sortValue: (r) => r.students },
    { key: 'attendancePercent', header: 'Attendance', align: 'right', render: (r) => r.attendancePercent },
    { key: 'avgMarks', header: 'Avg marks', align: 'right', hideOnMobile: true, render: (r) => r.avgMarks },
    { key: 'feeCollectionPercent', header: 'Fees', align: 'right', hideOnMobile: true, render: (r) => r.feeCollectionPercent },
    { key: 'teachers', header: 'Teachers', align: 'right', hideOnMobile: true },
  ];
  return (
    <Card padded={false}>
      <div className="p-s5 pb-s3"><CardHeader title="Class summary" icon="school" className="mb-0" /></div>
      <DataTable columns={columns} rows={rows} rowKey={(r) => r.classLabel} />
    </Card>
  );
}

export function ManagementDashboardPage() {
  return (
    <KpiPage<ManagementDashboardData> title="Management" subtitle="Executive overview" icon="insights" tabs={TABS}
      endpoint="/management/dashboard" queryKey={['management', 'dashboard']}
      icons={['groups', 'account_balance', 'how_to_reg', 'workspace_premium']}
      actions={<Button variant="outlined" icon="approval">Approvals</Button>}>
      {(d) => d.approvals && d.approvals.length > 0 ? (
        <Card padded={false}>
          <div className="p-s5 pb-s3"><CardHeader title="Pending approvals" icon="approval" className="mb-0" /></div>
          <ul className="divide-y divide-outline-variant/50">
            {d.approvals.map((a) => (
              <li key={a.id} className="flex items-center gap-s3 px-s5 py-s3">
                <span className="grid h-9 w-9 place-items-center rounded-lg bg-surface-container text-on-surface-variant"><Icon name="pending_actions" size={18} /></span>
                <div className="min-w-0 flex-1"><Text variant="label-lg" className="truncate text-on-surface">{a.title}</Text><Text variant="body-sm" className="text-on-surface-variant">{a.requester} · {humanize(a.type)} · {a.amount}</Text></div>
                <StatusChip status={AI_REC[a.aiRecommendation].status} label={AI_REC[a.aiRecommendation].label} icon={AI_REC[a.aiRecommendation].icon} />
                <button className="grid h-8 w-8 place-items-center rounded-full text-success hover:bg-success-container"><Icon name="check" size={18} /></button>
                <button className="grid h-8 w-8 place-items-center rounded-full text-error hover:bg-error-container"><Icon name="close" size={18} /></button>
              </li>
            ))}
          </ul>
        </Card>
      ) : null}
    </KpiPage>
  );
}

export function ManagementAnalyticsPage() {
  return (
    <KpiPage<ManagementAnalyticsData> title="Analytics" subtitle="School-wide analytics" icon="query_stats" tabs={TABS}
      endpoint="/management/analytics" queryKey={['management', 'analytics']}>
      {(d) => (d.classSummary && d.classSummary.length > 0 ? <ClassSummaryTable rows={d.classSummary} /> : null)}
    </KpiPage>
  );
}

export function ManagementAdmissionsPage() {
  return (
    <KpiPage<ManagementFunnelData> title="Admissions" subtitle="Admission funnel & conversion" icon="how_to_reg" tabs={TABS}
      endpoint="/management/admissions-funnel" queryKey={['management', 'admissions']}>
      {(d) => (d.funnelStages && d.funnelStages.length > 0 ? (
        <Card><CardHeader title="Admission funnel" icon="filter_alt" /><BarChartCard data={d.funnelStages.map((s) => ({ stage: s.label, count: s.count }))} xKey="stage" series={[{ key: 'count', name: 'Applicants' }]} /></Card>
      ) : null)}
    </KpiPage>
  );
}

export function ManagementFinancePage() {
  return <KpiPage title="Financial health" subtitle="Collections, dues & budget" icon="account_balance" tabs={TABS} endpoint="/management/financial-health" queryKey={['management', 'finance']} icons={['payments', 'account_balance_wallet', 'trending_up', 'savings']} />;
}

export function ManagementAcademicsPage() {
  return (
    <KpiPage<ManagementAnalyticsData> title="Academic health" subtitle="Performance & attendance" icon="school" tabs={TABS} endpoint="/management/academic-health" queryKey={['management', 'academics']}>
      {(d) => (d.classSummary && d.classSummary.length > 0 ? <ClassSummaryTable rows={d.classSummary} /> : null)}
    </KpiPage>
  );
}

export function ManagementPerformancePage() {
  return <KpiPage title="School performance" subtitle="KPIs vs targets" icon="workspace_premium" tabs={TABS} endpoint="/management/school-performance" queryKey={['management', 'performance']} />;
}

function ApprovalList({ title, subtitle, icon }: { title: string; subtitle: string; icon: string }) {
  const query = useModuleQuery<ListResult<ManagementApprovalItem>>(['management', 'tasks', title], () => fetchList('/management/tasks', { query: { pageSize: 200 } }));
  const columns: Column<ManagementApprovalItem>[] = [
    { key: 'title', header: 'Request', sortValue: (r) => r.title, render: (r) => <span className="ak-label-lg text-on-surface">{r.title}</span> },
    { key: 'type', header: 'Type', render: (r) => humanize(r.type) },
    { key: 'requester', header: 'Requester', hideOnMobile: true },
    { key: 'amount', header: 'Amount', align: 'right', hideOnMobile: true, render: (r) => <span className="ak-tabular">{r.amount}</span> },
    { key: 'ai', header: 'AI', hideOnMobile: true, render: (r) => <StatusChip status={AI_REC[r.aiRecommendation].status} label={humanize(r.aiRecommendation)} icon={AI_REC[r.aiRecommendation].icon} /> },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...APPROVAL_STATUS[r.status]} icon={false} /> },
  ];
  return <ResourceList title={title} subtitle={subtitle} icon={icon} tabs={TABS} query={query} columns={columns} rowKey={(r) => r.id}
    search={{ placeholder: 'Search request…', match: (r, t) => r.title.toLowerCase().includes(t) }}
    filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(APPROVAL_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
    unavailableTitle={`${title} is ready`} unavailableMessage="Items load here from /management/tasks once the backend is connected." />;
}

export function ApprovalCenterPage() {
  return <ApprovalList title="Approval center" subtitle="Cross-module approvals with AI recommendations" icon="approval" />;
}
export function ManagementTasksPage() {
  return <ApprovalList title="Tasks" subtitle="Management tasks & decisions" icon="task" />;
}
export function ManagementSettingsPage() {
  return <ModuleSettingsPage title="Management settings" subtitle="Configure thresholds & approvals" endpoint="/management/settings" tabs={TABS} />;
}
