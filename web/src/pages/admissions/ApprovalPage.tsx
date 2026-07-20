import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Avatar, Button, StatusChip, type Column } from '@/components/ui';
import type { AdmissionsApprovalItem } from '@/lib/contracts/admissions';
import { ADMISSIONS_TABS, APPLICATION_STATUS } from './shared';

const fetchApprovals = () => fetchList<AdmissionsApprovalItem>('/admissions/approval-queue', { query: { pageSize: 200 } });

export function ApprovalPage() {
  const query = useModuleQuery<ListResult<AdmissionsApprovalItem>>(['admissions', 'approvals'], fetchApprovals);

  const columns: Column<AdmissionsApprovalItem>[] = [
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
    { key: 'counselor', header: 'Counselor', hideOnMobile: true, render: (r) => r.counselor || 'Unassigned' },
    { key: 'submittedLabel', header: 'Submitted', hideOnMobile: true, render: (r) => r.submittedLabel || '—' },
    { key: 'status', header: 'Status', render: (r) => <StatusChip {...APPLICATION_STATUS[r.status]} icon={false} /> },
  ];

  return (
    <ResourceList
      title="Approval queue"
      subtitle="Applications awaiting a decision"
      icon="approval"
      tabs={ADMISSIONS_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      search={{ placeholder: 'Search applicant…', match: (r, t) => r.studentName.toLowerCase().includes(t) }}
      onRowClick={() => {}}
      unavailableTitle="Approval queue is ready"
      unavailableMessage="Pending approvals load here from /admissions/approval-queue once the backend is connected. Approve/reject actions post to the live decision endpoints."
      emptyTitle="Nothing awaiting approval"
      emptyIcon="task_alt"
    >
      <div className="flex justify-end gap-s2">
        <Button variant="outlined" icon="close" disabled>
          Reject selected
        </Button>
        <Button icon="check" disabled>
          Approve selected
        </Button>
      </div>
    </ResourceList>
  );
}
