import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Button, StatusChip, type Column } from '@/components/ui';
import type { LibraryReturnRecord } from '@/lib/contracts/library';
import { formatDate, humanize } from '@/lib/utils/format';
import { LIBRARY_TABS } from './shared';

const CONDITION = { good: 'success', fair: 'warning', damaged: 'error' } as const;

const fetchReturns = () => fetchList<LibraryReturnRecord>('/library/returns', { query: { pageSize: 300 } });

export function ReturnsPage() {
  const query = useModuleQuery<ListResult<LibraryReturnRecord>>(['library', 'returns'], fetchReturns);
  const columns: Column<LibraryReturnRecord>[] = [
    { key: 'memberName', header: 'Member', sortValue: (r) => r.memberName, render: (r) => <span className="ak-label-lg text-on-surface">{r.memberName}</span> },
    { key: 'bookTitle', header: 'Book', sortValue: (r) => r.bookTitle },
    { key: 'returnedDate', header: 'Returned', hideOnMobile: true, render: (r) => formatDate(r.returnedDate) },
    { key: 'daysOverdue', header: 'Late', align: 'right', hideOnMobile: true, render: (r) => (r.daysOverdue > 0 ? `${r.daysOverdue}d` : '—') },
    { key: 'condition', header: 'Condition', render: (r) => <StatusChip status={CONDITION[r.condition]} label={humanize(r.condition)} icon={false} /> },
    { key: 'fineAmount', header: 'Fine', align: 'right', render: (r) => <span className="ak-tabular">{r.fineAmount}</span> },
  ];
  return (
    <ResourceList
      title="Returns"
      subtitle="Returned books"
      icon="assignment_return"
      tabs={LIBRARY_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      actions={<Button icon="add">Return book</Button>}
      search={{ placeholder: 'Search member or book…', match: (r, t) => r.memberName.toLowerCase().includes(t) || r.bookTitle.toLowerCase().includes(t) }}
      unavailableTitle="Returns are ready"
      unavailableMessage="Returned books load here from /library/returns once the backend is connected."
    />
  );
}
