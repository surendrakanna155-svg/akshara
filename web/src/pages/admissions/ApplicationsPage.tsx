import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Avatar, StatusChip, type Column } from '@/components/ui';
import type { AdmissionsApplication } from '@/lib/contracts/admissions';
import { ADMISSIONS_TABS, APPLICATION_STATUS } from './shared';

const fetchApplications = () => fetchList<AdmissionsApplication>('/admissions/applications', { query: { pageSize: 200 } });

export function ApplicationsPage() {
  const query = useModuleQuery<ListResult<AdmissionsApplication>>(['admissions', 'applications'], fetchApplications);

  const columns: Column<AdmissionsApplication>[] = [
    {
      key: 'studentName',
      header: 'Applicant',
      sortValue: (r) => r.studentName,
      render: (r) => (
        <div className="flex items-center gap-s3">
          <Avatar name={r.studentName} size={36} />
          <div className="min-w-0">
            <div className="truncate ak-label-lg text-on-surface">{r.studentName}</div>
            <div className="truncate text-[12px] text-on-surface-variant">{r.parentName}</div>
          </div>
        </div>
      ),
    },
    { key: 'classLabel', header: 'Class', sortValue: (r) => r.classLabel },
    {
      key: 'documents',
      header: 'Documents',
      hideOnMobile: true,
      render: (r) => `${r.documentsComplete}/${r.documentsTotal}`,
    },
    { key: 'counselor', header: 'Counselor', hideOnMobile: true, render: (r) => r.counselor || 'Unassigned' },
    { key: 'submittedLabel', header: 'Submitted', hideOnMobile: true, align: 'right', render: (r) => r.submittedLabel || '—' },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...APPLICATION_STATUS[r.status]} icon={false} /> },
  ];

  return (
    <ResourceList
      title="Applications"
      subtitle="Admission applications"
      icon="description"
      tabs={ADMISSIONS_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      search={{ placeholder: 'Search applicant or parent…', match: (r, t) => r.studentName.toLowerCase().includes(t) || r.parentName.toLowerCase().includes(t) }}
      filters={[
        {
          key: 'status',
          placeholder: 'All statuses',
          width: 'w-48',
          options: Object.entries(APPLICATION_STATUS).map(([v, m]) => ({ value: v, label: m.label })),
          match: (r, v) => r.status === v,
        },
      ]}
      unavailableTitle="Applications are ready"
      unavailableMessage="Admission applications load here from /admissions/applications once the backend is connected."
      emptyTitle="No applications match your filters"
      emptyIcon="description"
    />
  );
}
