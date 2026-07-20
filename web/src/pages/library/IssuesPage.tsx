import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Button, StatusChip, type Column } from '@/components/ui';
import type { LibraryIssueRecord } from '@/lib/contracts/library';
import { formatDate, humanize } from '@/lib/utils/format';
import { LIBRARY_TABS, LOAN_STATUS } from './shared';

function makeColumns(): Column<LibraryIssueRecord>[] {
  return [
    { key: 'memberName', header: 'Member', sortValue: (r) => r.memberName, render: (r) => (
      <div className="min-w-0"><div className="truncate ak-label-lg text-on-surface">{r.memberName}</div><div className="text-[12px] text-on-surface-variant">{humanize(r.memberType)}</div></div>
    ) },
    { key: 'bookTitle', header: 'Book', sortValue: (r) => r.bookTitle },
    { key: 'issuedDate', header: 'Issued', hideOnMobile: true, render: (r) => formatDate(r.issuedDate) },
    { key: 'dueDate', header: 'Due', hideOnMobile: true, align: 'right', sortValue: (r) => r.dueDate, render: (r) => formatDate(r.dueDate) },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...LOAN_STATUS[r.status]} icon={false} /> },
  ];
}

export function IssuesPage() {
  const query = useModuleQuery<ListResult<LibraryIssueRecord>>(['library', 'issues'], () => fetchList('/library/issues', { query: { pageSize: 300 } }));
  return (
    <ResourceList
      title="Issues"
      subtitle="Books currently on loan"
      icon="import_contacts"
      tabs={LIBRARY_TABS}
      query={query}
      columns={makeColumns()}
      rowKey={(r) => r.id}
      actions={<Button icon="add">Issue book</Button>}
      search={{ placeholder: 'Search member or book…', match: (r, t) => r.memberName.toLowerCase().includes(t) || r.bookTitle.toLowerCase().includes(t) }}
      filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(LOAN_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
      unavailableTitle="Issued books are ready"
      unavailableMessage="Active loans load here from /library/issues once the backend is connected."
    />
  );
}

export function OverduePage() {
  const query = useModuleQuery<ListResult<LibraryIssueRecord>>(['library', 'overdue'], () => fetchList('/library/overdue', { query: { pageSize: 300 } }));
  return (
    <ResourceList
      title="Overdue"
      subtitle="Loans past their due date"
      icon="running_with_errors"
      tabs={LIBRARY_TABS}
      query={query}
      columns={makeColumns()}
      rowKey={(r) => r.id}
      actions={<Button variant="outlined" icon="notifications" disabled>Send reminders</Button>}
      search={{ placeholder: 'Search member or book…', match: (r, t) => r.memberName.toLowerCase().includes(t) || r.bookTitle.toLowerCase().includes(t) }}
      unavailableTitle="Overdue list is ready"
      unavailableMessage="Overdue loans load here from /library/overdue once the backend is connected."
      emptyTitle="Nothing overdue"
      emptyIcon="check_circle"
    />
  );
}
