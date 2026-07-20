import { useNavigate } from 'react-router-dom';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Button, StatusChip, type Column } from '@/components/ui';
import type { CollectionPayment } from '@/lib/contracts/finance';
import { formatDateTime } from '@/lib/utils/format';
import { COLLECTION_STATUS, FINANCE_TABS } from './shared';

const fetchCollections = () => fetchList<CollectionPayment>('/finance/collections', { query: { pageSize: 200 } });

export function CollectionsPage() {
  const navigate = useNavigate();
  const query = useModuleQuery<ListResult<CollectionPayment>>(['finance', 'collections'], fetchCollections);

  const columns: Column<CollectionPayment>[] = [
    { key: 'receiptNumber', header: 'Receipt', sortValue: (r) => r.receiptNumber, render: (r) => <span className="ak-mono text-[13px]">{r.receiptNumber}</span> },
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
    { key: 'mode', header: 'Mode', hideOnMobile: true },
    { key: 'collectedAt', header: 'Collected', hideOnMobile: true, sortValue: (r) => r.collectedAt, render: (r) => formatDateTime(r.collectedAt) },
    { key: 'collectedBy', header: 'By', hideOnMobile: true },
    { key: 'amount', header: 'Amount', align: 'right', render: (r) => <span className="ak-tabular font-semibold text-on-surface">{r.amount}</span> },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...COLLECTION_STATUS[r.status]} icon={false} /> },
  ];

  return (
    <ResourceList
      title="Collections"
      subtitle="Fee payments received"
      icon="receipt_long"
      tabs={FINANCE_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      onRowClick={(r) => navigate(`/finance/collections/${r.id}`)}
      actions={<Button icon="add">Collect fee</Button>}
      search={{ placeholder: 'Search student or receipt…', match: (r, t) => r.studentName.toLowerCase().includes(t) || r.receiptNumber.toLowerCase().includes(t) }}
      filters={[
        { key: 'status', placeholder: 'All statuses', options: Object.entries(COLLECTION_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v },
      ]}
      unavailableTitle="Collections are ready"
      unavailableMessage="Fee payments load here from /finance/collections once the backend is connected."
    />
  );
}
