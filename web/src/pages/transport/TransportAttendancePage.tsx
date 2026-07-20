import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { StatusChip, type Column } from '@/components/ui';
import { Icon } from '@/components/Icon';
import type { TransportAttendanceRecord } from '@/lib/contracts/transport';
import { SHIFT_LABEL, TRANSPORT_ATTENDANCE, TRANSPORT_TABS } from './shared';

const fetchAttendance = () => fetchList<TransportAttendanceRecord>('/transport/attendance', { query: { pageSize: 200 } });

export function TransportAttendancePage() {
  const query = useModuleQuery<ListResult<TransportAttendanceRecord>>(['transport', 'attendance'], fetchAttendance);

  const columns: Column<TransportAttendanceRecord>[] = [
    { key: 'studentName', header: 'Student', sortValue: (r) => r.studentName, render: (r) => <span className="ak-label-lg text-on-surface">{r.studentName}</span> },
    { key: 'routeName', header: 'Route', hideOnMobile: true },
    { key: 'stopName', header: 'Stop', hideOnMobile: true },
    { key: 'scheduledTime', header: 'Scheduled', hideOnMobile: true, align: 'right' },
    { key: 'actualTime', header: 'Actual', hideOnMobile: true, align: 'right', render: (r) => r.actualTime || '—' },
    { key: 'shift', header: 'Shift', hideOnMobile: true, render: (r) => SHIFT_LABEL[r.shift] },
    {
      key: 'parentNotified',
      header: 'Parent',
      align: 'center',
      hideOnMobile: true,
      render: (r) => <Icon name={r.parentNotified ? 'notifications_active' : 'notifications_off'} size={18} className={r.parentNotified ? 'text-success' : 'text-on-surface-variant/40'} />,
    },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...TRANSPORT_ATTENDANCE[r.status]} icon={false} /> },
  ];

  return (
    <ResourceList
      title="Transport attendance"
      subtitle="Pickup and drop tracking"
      icon="fact_check"
      tabs={TRANSPORT_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      search={{ placeholder: 'Search student…', match: (r, t) => r.studentName.toLowerCase().includes(t) }}
      filters={[{ key: 'status', placeholder: 'All statuses', width: 'w-44', options: Object.entries(TRANSPORT_ATTENDANCE).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
      unavailableTitle="Transport attendance is ready"
      unavailableMessage="Pickup/drop attendance loads here from /transport/attendance once the backend is connected."
    />
  );
}
