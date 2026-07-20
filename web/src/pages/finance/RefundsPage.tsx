import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Button, StatusChip, type Column } from '@/components/ui';
import type { RefundRequest } from '@/lib/contracts/finance';
import { formatDate } from '@/lib/utils/format';
import { FINANCE_TABS, REFUND_STATUS } from './shared';

const fetchRefunds = () => fetchList<RefundRequest>('/finance/refunds', { query: { pageSize: 200 } });

export function RefundsPage() {
  const query = useModuleQuery<ListResult<RefundRequest>>(['finance', 'refunds'], fetchRefunds);

  const columns: Column<RefundRequest>[] = [
    { key: 'studentName', header: 'Student', sortValue: (r) => r.studentName, render: (r) => <span className="ak-label-lg text-on-surface">{r.studentName}</span> },
    { key: 'reason', header: 'Reason', hideOnMobile: true },
    { key: 'originalReceipt', header: 'Receipt', hideOnMobile: true, render: (r) => <span className="ak-mono text-[13px]">{r.originalReceipt}</span> },
    { key: 'requestedAt', header: 'Requested', hideOnMobile: true, sortValue: (r) => r.requestedAt, render: (r) => formatDate(r.requestedAt) },
    { key: 'amount', header: 'Amount', align: 'right', render: (r) => <span className="ak-tabular font-semibold text-on-surface">{r.amount}</span> },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...REFUND_STATUS[r.status]} icon={false} /> },
  ];

  return (
    <ResourceList
      title="Refunds"
      subtitle="Refund requests — maker/checker"
      icon="undo"
      tabs={FINANCE_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      search={{ placeholder: 'Search student…', match: (r, t) => r.studentName.toLowerCase().includes(t) }}
      filters={[
        { key: 'status', placeholder: 'All statuses', options: Object.entries(REFUND_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v },
      ]}
      unavailableTitle="Refund management is ready"
      unavailableMessage="Refund requests load here from /finance/refunds once the backend is connected. Approve/reject posts to the live maker-checker endpoints."
    >
      <div className="flex justify-end gap-s2">
        <Button variant="outlined" icon="close" disabled>
          Reject
        </Button>
        <Button icon="check" disabled>
          Approve
        </Button>
      </div>
    </ResourceList>
  );
}
