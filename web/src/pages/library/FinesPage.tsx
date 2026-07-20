import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { StatusChip, Tooltip, type Column } from '@/components/ui';
import { Icon } from '@/components/Icon';
import type { LibraryFine } from '@/lib/contracts/library';
import { FINE_STATUS, LIBRARY_TABS } from './shared';

const fetchFines = () => fetchList<LibraryFine>('/library/fines', { query: { pageSize: 300 } });

export function FinesPage() {
  const query = useModuleQuery<ListResult<LibraryFine>>(['library', 'fines'], fetchFines);
  const columns: Column<LibraryFine>[] = [
    { key: 'memberName', header: 'Member', sortValue: (r) => r.memberName, render: (r) => <span className="ak-label-lg text-on-surface">{r.memberName}</span> },
    { key: 'bookTitle', header: 'Book', hideOnMobile: true },
    { key: 'daysOverdue', header: 'Overdue', align: 'right', hideOnMobile: true, render: (r) => `${r.daysOverdue}d` },
    {
      key: 'financeLinked',
      header: 'Finance',
      align: 'center',
      hideOnMobile: true,
      render: (r) => (
        <Tooltip label={r.financeLinked ? 'Linked to fee account' : 'Not linked'}>
          <Icon name={r.financeLinked ? 'link' : 'link_off'} size={18} className={r.financeLinked ? 'text-success' : 'text-on-surface-variant/40'} />
        </Tooltip>
      ),
    },
    { key: 'amount', header: 'Amount', align: 'right', render: (r) => <span className="ak-tabular font-semibold text-on-surface">{r.amount}</span> },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...FINE_STATUS[r.status]} icon={false} /> },
  ];
  return (
    <ResourceList
      title="Fines"
      subtitle="Overdue and damage fines"
      icon="payments"
      tabs={LIBRARY_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      search={{ placeholder: 'Search member…', match: (r, t) => r.memberName.toLowerCase().includes(t) }}
      filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(FINE_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
      unavailableTitle="Fines are ready"
      unavailableMessage="Library fines load here from /library/fines once the backend is connected."
    />
  );
}
