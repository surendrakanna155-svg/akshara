import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { StatusChip, type Column } from '@/components/ui';
import type { DefaulterRecord } from '@/lib/contracts/finance';
import { AGING_BUCKET, FINANCE_TABS } from './shared';

const fetchDefaulters = () => fetchList<DefaulterRecord>('/finance/defaulters', { query: { pageSize: 200 } });

export function DefaultersPage() {
  const query = useModuleQuery<ListResult<DefaulterRecord>>(['finance', 'defaulters'], fetchDefaulters);

  const columns: Column<DefaulterRecord>[] = [
    {
      key: 'studentName',
      header: 'Student',
      sortValue: (r) => r.studentName,
      render: (r) => (
        <div className="min-w-0">
          <div className="truncate ak-label-lg text-on-surface">{r.studentName}</div>
          <div className="truncate text-[12px] text-on-surface-variant">{r.classLabel} · {r.admissionNumber}</div>
        </div>
      ),
    },
    { key: 'overdueAmount', header: 'Overdue', align: 'right', render: (r) => <span className="ak-tabular font-semibold text-error">{r.overdueAmount}</span> },
    { key: 'daysOverdue', header: 'Days', align: 'right', sortValue: (r) => r.daysOverdue, hideOnMobile: true },
    { key: 'bucket', header: 'Aging', render: (r) => <StatusChip {...AGING_BUCKET[r.bucket]} icon={false} /> },
    {
      key: 'collectionProbability',
      header: 'Recovery',
      align: 'right',
      hideOnMobile: true,
      sortValue: (r) => r.collectionProbability,
      render: (r) => `${r.collectionProbability}%`,
    },
    { key: 'guardianPhone', header: 'Guardian', align: 'right', hideOnMobile: true, render: (r) => <span className="ak-mono text-[13px]">{r.guardianPhone}</span> },
  ];

  return (
    <ResourceList
      title="Defaulters"
      subtitle="Overdue fee accounts"
      icon="person_alert"
      tabs={FINANCE_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      search={{ placeholder: 'Search student…', match: (r, t) => r.studentName.toLowerCase().includes(t) }}
      filters={[
        { key: 'bucket', placeholder: 'All aging buckets', width: 'w-44', options: Object.entries(AGING_BUCKET).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.bucket === v },
      ]}
      unavailableTitle="Defaulter tracking is ready"
      unavailableMessage="Overdue accounts and recovery insights load here from /finance/defaulters once the backend is connected."
    />
  );
}
