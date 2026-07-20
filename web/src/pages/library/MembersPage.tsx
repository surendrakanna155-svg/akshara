import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Avatar, Button, StatusChip, type Column } from '@/components/ui';
import type { LibraryMember } from '@/lib/contracts/library';
import { humanize } from '@/lib/utils/format';
import { LIBRARY_TABS, MEMBER_STATUS } from './shared';

const fetchMembers = () => fetchList<LibraryMember>('/library/members', { query: { pageSize: 300 } });

export function MembersPage() {
  const query = useModuleQuery<ListResult<LibraryMember>>(['library', 'members'], fetchMembers);
  const columns: Column<LibraryMember>[] = [
    {
      key: 'name',
      header: 'Member',
      sortValue: (r) => r.name,
      render: (r) => (
        <div className="flex items-center gap-s3">
          <Avatar name={r.name} size={36} />
          <div className="min-w-0">
            <div className="truncate ak-label-lg text-on-surface">{r.name}</div>
            <div className="truncate text-[12px] text-on-surface-variant">{r.classOrDepartment}</div>
          </div>
        </div>
      ),
    },
    { key: 'memberType', header: 'Type', render: (r) => humanize(r.memberType) },
    { key: 'identifier', header: 'ID', hideOnMobile: true, render: (r) => <span className="ak-mono text-[12px]">{r.identifier}</span> },
    { key: 'activeLoans', header: 'Loans', align: 'right', sortValue: (r) => r.activeLoans },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...MEMBER_STATUS[r.status]} icon={false} /> },
  ];
  return (
    <ResourceList
      title="Members"
      subtitle="Library membership"
      icon="groups"
      tabs={LIBRARY_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      actions={<Button icon="person_add">Enroll member</Button>}
      search={{ placeholder: 'Search member…', match: (r, t) => r.name.toLowerCase().includes(t) || r.identifier.toLowerCase().includes(t) }}
      filters={[
        { key: 'memberType', placeholder: 'All types', options: ['student', 'staff', 'teacher'].map((v) => ({ value: v, label: humanize(v) })), match: (r, v) => r.memberType === v },
        { key: 'status', placeholder: 'All statuses', options: Object.entries(MEMBER_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v },
      ]}
      unavailableTitle="Members are ready"
      unavailableMessage="Library members load here from /library/members once the backend is connected."
    />
  );
}
