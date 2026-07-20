import { useNavigate } from 'react-router-dom';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';
import { fetchList, type ListResult } from '@/lib/api/list';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { ResourceList } from '@/components/system/ResourceList';
import { Avatar, Button, Card, CardHeader, KpiCard, PageHeader, StatGrid, StatusChip, Text, type Column } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { ModuleTabs } from '@/components/shell/ModuleTabs';
import { DonutChart } from '@/components/charts';
import { formatDate, humanize } from '@/lib/utils/format';
import { MODULE_TABS } from '@/routes/navConfig';
import { normalizeSisStudent } from '@/lib/contracts/sis';
import type { SisConversionQueueItem, SisDashboardData, SisStudent, SisTransferRecord } from '@/lib/contracts/sis';

export const SIS_TABS = MODULE_TABS.sis;
const ICONS = ['groups', 'school', 'trending_up', 'swap_horiz'];

export function SisDashboardPage() {
  const navigate = useNavigate();
  const query = useModuleQuery(['sis', 'dashboard'], () => apiFetch<SisDashboardData>('/sis/dashboard'));
  return (
    <div className="space-y-s6">
      <PageHeader title="Students" subtitle="Student information system" icon="groups" tabs={<ModuleTabs tabs={SIS_TABS} />}
        actions={<Button variant="outlined" icon="format_list_bulleted" onClick={() => navigate('/sis/registry')}>Registry</Button>} />
      <AsyncBoundary query={query} unavailableTitle="SIS overview is ready" unavailableMessage="Enrolment KPIs and distributions load here from /sis/dashboard once the backend is connected.">
        {(d) => (
          <div className="space-y-s6">
            <StatGrid>{d.kpis.map((k, i) => <KpiCard key={k.id} label={k.label} value={k.value} icon={ICONS[i % ICONS.length]} delta={k.delta} />)}</StatGrid>
            <div className="grid grid-cols-1 gap-s4 md:grid-cols-2">
              {d.classDistribution && d.classDistribution.length > 0 && (
                <Card><CardHeader title="By class" icon="donut_large" /><DonutChart data={d.classDistribution.map((c) => ({ name: c.label, value: c.value }))} /></Card>
              )}
              {d.genderDistribution && d.genderDistribution.length > 0 && (
                <Card><CardHeader title="By gender" icon="wc" /><DonutChart data={d.genderDistribution.map((c) => ({ name: c.label, value: c.value }))} /></Card>
              )}
            </div>
          </div>
        )}
      </AsyncBoundary>
    </div>
  );
}

export function TransfersPage() {
  const query = useModuleQuery<ListResult<SisTransferRecord>>(['sis', 'transfers'], () => fetchList('/sis/transfers', { query: { pageSize: 300 } }));
  const columns: Column<SisTransferRecord>[] = [
    { key: 'studentName', header: 'Student', sortValue: (r) => r.studentName, render: (r) => (
      <div className="min-w-0"><div className="truncate ak-label-lg text-on-surface">{r.studentName}</div><div className="text-[12px] text-on-surface-variant">{r.classLabel} · {r.admissionNumber}</div></div>
    ) },
    { key: 'academicYear', header: 'Year', hideOnMobile: true },
    { key: 'reason', header: 'Reason', hideOnMobile: true, render: (r) => r.reason || '—' },
    { key: 'exitedAt', header: 'Exited', hideOnMobile: true, align: 'right', render: (r) => formatDate(r.exitedAt) },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={r.status === 'transferred' ? 'warning' : 'neutral'} label={humanize(r.status)} icon={false} /> },
  ];
  return <ResourceList title="Transfers & exits" subtitle="Students who left" icon="swap_horiz" tabs={SIS_TABS} query={query} columns={columns} rowKey={(r) => r.studentId}
    actions={<Button icon="logout">Record exit</Button>} search={{ placeholder: 'Search student…', match: (r, t) => r.studentName.toLowerCase().includes(t) }}
    unavailableTitle="Transfers are ready" unavailableMessage="Transfer & exit records load here from /sis/transfers once the backend is connected." />;
}

async function fetchConversion(): Promise<ListResult<SisConversionQueueItem>> {
  const raw = await apiFetch<{ queue?: Array<{ enrollment?: Record<string, string>; effectiveStatus?: string }> }>('/sis/admissions-conversion');
  const q = raw?.queue ?? [];
  return {
    items: q.map((it, i) => ({
      id: it.enrollment?.id ?? String(i),
      studentName: it.enrollment?.studentName ?? it.enrollment?.fullName ?? '—',
      classLabel: it.enrollment?.seekingClass ?? it.enrollment?.classLabel ?? '—',
      guardianName: it.enrollment?.guardianName ?? '—',
      status: it.effectiveStatus ?? 'pending',
    })),
    total: q.length,
  };
}

export function AdmissionsConversionPage() {
  const query = useModuleQuery<ListResult<SisConversionQueueItem>>(['sis', 'conversion'], fetchConversion);
  const columns: Column<SisConversionQueueItem>[] = [
    { key: 'studentName', header: 'Student', sortValue: (r) => r.studentName, render: (r) => <span className="ak-label-lg text-on-surface">{r.studentName}</span> },
    { key: 'classLabel', header: 'Class', sortValue: (r) => r.classLabel },
    { key: 'guardianName', header: 'Guardian', hideOnMobile: true },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status="pending" label={humanize(r.status)} icon={false} /> },
  ];
  return <ResourceList title="Admissions conversion" subtitle="Convert admitted applicants to enrolled students" icon="how_to_reg" tabs={SIS_TABS} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="check">Convert selected</Button>} search={{ placeholder: 'Search student…', match: (r, t) => r.studentName.toLowerCase().includes(t) }}
    unavailableTitle="Conversion queue is ready" unavailableMessage="Admitted applicants awaiting conversion load here from /sis/admissions-conversion once the backend is connected."
    emptyTitle="No applicants awaiting conversion" emptyIcon="how_to_reg" />;
}

/** Class-management workflow scaffold (promotion / reshuffle / section balance).
 *  Roster from /sis/students; the bulk apply-action is gated on gap WEB-005. */
function SisWorkflowPage({ title, subtitle, icon, actionLabel }: { title: string; subtitle: string; icon: string; actionLabel: string }) {
  const query = useModuleQuery<ListResult<SisStudent>>(['sis', 'roster', title], async () => {
    const res = await fetchList<SisStudent>('/sis/students', { query: { pageSize: 400 } });
    return { ...res, items: res.items.map(normalizeSisStudent) };
  });
  const columns: Column<SisStudent>[] = [
    { key: 'studentName', header: 'Student', sortValue: (r) => r.studentName, render: (r) => (
      <div className="flex items-center gap-s3"><Avatar name={r.studentName} size={32} /><span className="ak-label-lg text-on-surface">{r.studentName}</span></div>
    ) },
    { key: 'classLabel', header: 'Class', sortValue: (r) => r.classLabel, render: (r) => `${r.classLabel} · ${r.section}` },
    { key: 'admissionNumber', header: 'Admission', hideOnMobile: true, render: (r) => <span className="ak-mono text-[12px]">{r.admissionNumber}</span> },
  ];
  return (
    <ResourceList title={title} subtitle={subtitle} icon={icon} tabs={SIS_TABS} query={query} columns={columns} rowKey={(r) => r.id}
      search={{ placeholder: 'Search student…', match: (r, t) => r.studentName.toLowerCase().includes(t) }}
      filters={[{ key: 'classLabel', placeholder: 'All classes', width: 'w-40', options: [], match: (r, v) => r.classLabel === v }]}
      unavailableTitle={`${title} is ready`}
      unavailableMessage="Select a class to load its roster from /sis/students, then apply the bulk action. The apply endpoint is pending (gap WEB-005).">
      <div className="flex items-center justify-between gap-s3 rounded-lg border border-dashed border-outline-variant bg-surface-low px-s4 py-s3">
        <div className="flex items-center gap-s2 text-on-surface-variant">
          <Icon name="info" size={18} />
          <Text variant="body-sm">Bulk {actionLabel.toLowerCase()} posts to the SIS workflow endpoint (pending — gap WEB-005).</Text>
        </div>
        <Button icon="task_alt" disabled>{actionLabel}</Button>
      </div>
    </ResourceList>
  );
}

export function PromotionPage() {
  return <SisWorkflowPage title="Promotion" subtitle="Promote students to the next class" icon="trending_up" actionLabel="Promote selected" />;
}
export function ReshufflePage() {
  return <SisWorkflowPage title="Reshuffle" subtitle="Move students between sections" icon="shuffle" actionLabel="Reshuffle" />;
}
export function SectionBalancePage() {
  return <SisWorkflowPage title="Section balance" subtitle="Rebalance sections evenly" icon="balance" actionLabel="Balance sections" />;
}
export function AcademicAssignmentPage() {
  return <SisWorkflowPage title="Academic assignment" subtitle="Assign students to classes & sections" icon="assignment_ind" actionLabel="Assign" />;
}
