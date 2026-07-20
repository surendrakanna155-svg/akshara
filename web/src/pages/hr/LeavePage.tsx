import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Button, StatusChip, type Column } from '@/components/ui';
import type { HrLeaveRequest } from '@/lib/contracts/hr';
import { formatDate, humanize } from '@/lib/utils/format';
import { HR_LEAVE_STATUS, HR_TABS } from './shared';

const fetchLeave = () => fetchList<HrLeaveRequest>('/hr/leave', { query: { pageSize: 200 } });

export function HrLeavePage() {
  const query = useModuleQuery<ListResult<HrLeaveRequest>>(['hr', 'leave'], fetchLeave);

  const columns: Column<HrLeaveRequest>[] = [
    { key: 'employeeName', header: 'Employee', sortValue: (r) => r.employeeName, render: (r) => <span className="ak-label-lg text-on-surface">{r.employeeName}</span> },
    { key: 'leaveType', header: 'Type', render: (r) => humanize(r.leaveType) },
    { key: 'period', header: 'Period', hideOnMobile: true, render: (r) => `${formatDate(r.fromDate)} – ${formatDate(r.toDate)}` },
    { key: 'days', header: 'Days', align: 'right', sortValue: (r) => r.days },
    { key: 'approver', header: 'Approver', hideOnMobile: true, render: (r) => r.approver || '—' },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...HR_LEAVE_STATUS[r.status]} icon={false} /> },
  ];

  return (
    <ResourceList
      title="Leave requests"
      subtitle="Staff leave applications"
      icon="event_busy"
      tabs={HR_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      search={{ placeholder: 'Search employee…', match: (r, t) => r.employeeName.toLowerCase().includes(t) }}
      filters={[
        { key: 'status', placeholder: 'All statuses', options: Object.entries(HR_LEAVE_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v },
      ]}
      unavailableTitle="Leave management is ready"
      unavailableMessage="Leave requests load here from /hr/leave once the backend is connected. Approve/reject posts to the live decision endpoint."
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
