import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { StatusChip, Tooltip, type Column } from '@/components/ui';
import { Icon } from '@/components/Icon';
import type { HrAttendanceRecord } from '@/lib/contracts/hr';
import { formatDate, humanize } from '@/lib/utils/format';
import { HR_ATTENDANCE_STATUS, HR_DEPARTMENTS, HR_TABS } from './shared';

const fetchAttendance = () => fetchList<HrAttendanceRecord>('/hr/attendance', { query: { pageSize: 200 } });

export function HrAttendancePage() {
  const query = useModuleQuery<ListResult<HrAttendanceRecord>>(['hr', 'attendance'], fetchAttendance);

  const columns: Column<HrAttendanceRecord>[] = [
    { key: 'employeeName', header: 'Employee', sortValue: (r) => r.employeeName, render: (r) => <span className="ak-label-lg text-on-surface">{r.employeeName}</span> },
    { key: 'department', header: 'Department', hideOnMobile: true, render: (r) => humanize(r.department) },
    { key: 'date', header: 'Date', sortValue: (r) => r.date, hideOnMobile: true, render: (r) => formatDate(r.date) },
    { key: 'checkIn', header: 'In', hideOnMobile: true, render: (r) => r.checkIn || '—' },
    { key: 'checkOut', header: 'Out', hideOnMobile: true, render: (r) => r.checkOut || '—' },
    {
      key: 'verify',
      header: 'Verified',
      hideOnMobile: true,
      render: (r) => (
        <div className="flex gap-s1">
          <Tooltip label={r.geoVerified ? 'GPS verified' : 'No GPS'}>
            <Icon name="location_on" size={18} className={r.geoVerified ? 'text-success' : 'text-on-surface-variant/40'} />
          </Tooltip>
          <Tooltip label={r.faceVerified ? 'Face verified' : 'No face check'}>
            <Icon name="face" size={18} className={r.faceVerified ? 'text-success' : 'text-on-surface-variant/40'} />
          </Tooltip>
        </div>
      ),
    },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...HR_ATTENDANCE_STATUS[r.status]} icon={false} /> },
  ];

  return (
    <ResourceList
      title="Staff attendance"
      subtitle="Daily muster"
      icon="fact_check"
      tabs={HR_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      search={{ placeholder: 'Search employee…', match: (r, t) => r.employeeName.toLowerCase().includes(t) }}
      filters={[
        { key: 'department', placeholder: 'All departments', width: 'w-44', options: HR_DEPARTMENTS.map((d) => ({ value: d, label: humanize(d) })), match: (r, v) => r.department === v },
        { key: 'status', placeholder: 'All statuses', options: Object.entries(HR_ATTENDANCE_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v },
      ]}
      unavailableTitle="Staff attendance is ready"
      unavailableMessage="The daily muster loads here from /hr/attendance once the backend is connected."
    />
  );
}
