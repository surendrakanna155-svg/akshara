import { useNavigate } from 'react-router-dom';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';
import { fetchList, type ListResult } from '@/lib/api/list';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { ResourceList } from '@/components/system/ResourceList';
import { ReportsHub } from '@/components/system/ReportsHub';
import { Avatar, Button, Card, CardHeader, KpiCard, PageHeader, StatGrid, StatusChip, Text, type Column } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { ModuleTabs } from '@/components/shell/ModuleTabs';
import { formatDate, humanize } from '@/lib/utils/format';
import type {
  HostelAttendanceRecord,
  HostelDashboardData,
  HostelLeaveRequest,
  HostelMessData,
  HostelRoom,
  HostelStudent,
  HostelVisitor,
} from '@/lib/contracts/hostel';
import { HOSTEL_ATTENDANCE, HOSTEL_LEAVE, HOSTEL_TABS, RESIDENT_STATUS, ROOM_STATUS, VISITOR_STATUS } from './shared';

const ICONS = ['night_shelter', 'bed', 'groups', 'restaurant'];

export function HostelDashboardPage() {
  const navigate = useNavigate();
  const query = useModuleQuery(['hostel', 'dashboard'], () => apiFetch<HostelDashboardData>('/hostel/dashboard'));
  return (
    <div className="space-y-s6">
      <PageHeader
        title="Hostel"
        subtitle="Residence overview"
        icon="night_shelter"
        tabs={<ModuleTabs tabs={HOSTEL_TABS} />}
        actions={<Button variant="outlined" icon="groups" onClick={() => navigate('/hostel/students')}>Residents</Button>}
      />
      <AsyncBoundary query={query} unavailableTitle="Hostel overview is ready" unavailableMessage="Occupancy KPIs load here from /hostel/dashboard once the backend is connected.">
        {(d) => (
          <StatGrid>
            {d.kpis.map((k, i) => <KpiCard key={k.id} label={k.label} value={k.value} icon={ICONS[i % ICONS.length]} delta={k.delta} />)}
          </StatGrid>
        )}
      </AsyncBoundary>
    </div>
  );
}

export function HostelStudentsPage() {
  const query = useModuleQuery<ListResult<HostelStudent>>(['hostel', 'students'], () => fetchList('/hostel/students', { query: { pageSize: 300 } }));
  const columns: Column<HostelStudent>[] = [
    { key: 'studentName', header: 'Resident', sortValue: (r) => r.studentName, render: (r) => (
      <div className="flex items-center gap-s3"><Avatar name={r.studentName} size={36} /><div className="min-w-0"><div className="truncate ak-label-lg text-on-surface">{r.studentName}</div><div className="text-[12px] text-on-surface-variant">{r.classLabel} · {r.admissionNumber}</div></div></div>
    ) },
    { key: 'block', header: 'Block', hideOnMobile: true },
    { key: 'room', header: 'Room / Bed', render: (r) => `${r.room} · ${r.bed}` },
    { key: 'feePending', header: 'Fee pending', hideOnMobile: true, align: 'right', render: (r) => <span className="ak-tabular">{r.feePending}</span> },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...RESIDENT_STATUS[r.status]} icon={false} /> },
  ];
  return (
    <ResourceList title="Residents" subtitle="Hostel students" icon="groups" tabs={HOSTEL_TABS} query={query} columns={columns} rowKey={(r) => r.id}
      actions={<Button icon="person_add">Admit resident</Button>}
      search={{ placeholder: 'Search resident…', match: (r, t) => r.studentName.toLowerCase().includes(t) }}
      filters={[{ key: 'status', placeholder: 'All statuses', width: 'w-44', options: Object.entries(RESIDENT_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
      unavailableTitle="Residents are ready" unavailableMessage="Hostel residents load here from /hostel/students once the backend is connected." />
  );
}

export function RoomsPage() {
  const query = useModuleQuery<ListResult<HostelRoom>>(['hostel', 'rooms'], () => fetchList('/hostel/rooms', { query: { pageSize: 300 } }));
  const columns: Column<HostelRoom>[] = [
    { key: 'roomNumber', header: 'Room', sortValue: (r) => r.roomNumber, render: (r) => <span className="ak-label-lg text-on-surface">{r.block} · {r.roomNumber}</span> },
    { key: 'floor', header: 'Floor', hideOnMobile: true, align: 'right' },
    { key: 'type', header: 'Type', render: (r) => humanize(r.type) },
    { key: 'beds', header: 'Beds', align: 'right', render: (r) => `${r.occupiedBeds}/${r.totalBeds}` },
    { key: 'facilities', header: 'Facilities', hideOnMobile: true },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...ROOM_STATUS[r.status]} icon={false} /> },
  ];
  return (
    <ResourceList title="Rooms" subtitle="Room allocation & occupancy" icon="bed" tabs={HOSTEL_TABS} query={query} columns={columns} rowKey={(r) => r.id}
      actions={<Button icon="add">Add room</Button>}
      search={{ placeholder: 'Search room…', match: (r, t) => r.roomNumber.toLowerCase().includes(t) || r.block.toLowerCase().includes(t) }}
      filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(ROOM_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
      unavailableTitle="Rooms are ready" unavailableMessage="Room occupancy loads here from /hostel/rooms once the backend is connected." />
  );
}

function sessionCell(v: HostelAttendanceRecord['morning']) {
  const m = HOSTEL_ATTENDANCE[v];
  const color = m.status === 'success' ? 'text-success' : m.status === 'error' ? 'text-error' : 'text-on-surface-variant';
  const icon = v === 'present' ? 'check_circle' : v === 'absent' ? 'cancel' : 'event_busy';
  return <Icon name={icon} size={18} className={color} />;
}

export function HostelAttendancePage() {
  const query = useModuleQuery<ListResult<HostelAttendanceRecord>>(['hostel', 'attendance'], () => fetchList('/hostel/attendance', { query: { pageSize: 300 } }));
  const columns: Column<HostelAttendanceRecord>[] = [
    { key: 'studentName', header: 'Resident', sortValue: (r) => r.studentName, render: (r) => <span className="ak-label-lg text-on-surface">{r.studentName}</span> },
    { key: 'room', header: 'Room', hideOnMobile: true },
    { key: 'morning', header: 'Morning', align: 'center', render: (r) => sessionCell(r.morning) },
    { key: 'evening', header: 'Evening', align: 'center', render: (r) => sessionCell(r.evening) },
    { key: 'night', header: 'Night', align: 'center', render: (r) => sessionCell(r.night) },
    { key: 'overallStatus', header: 'Overall', align: 'right', render: (r) => <StatusChip {...HOSTEL_ATTENDANCE[r.overallStatus]} icon={false} /> },
  ];
  return (
    <ResourceList title="Hostel attendance" subtitle="Roll-call by session" icon="fact_check" tabs={HOSTEL_TABS} query={query} columns={columns} rowKey={(r) => r.id}
      search={{ placeholder: 'Search resident…', match: (r, t) => r.studentName.toLowerCase().includes(t) }}
      unavailableTitle="Hostel attendance is ready" unavailableMessage="Session roll-call loads here from /hostel/attendance once the backend is connected." />
  );
}

export function HostelLeavePage() {
  const query = useModuleQuery<ListResult<HostelLeaveRequest>>(['hostel', 'leave'], () => fetchList('/hostel/leave', { query: { pageSize: 300 } }));
  const columns: Column<HostelLeaveRequest>[] = [
    { key: 'studentName', header: 'Resident', sortValue: (r) => r.studentName, render: (r) => <span className="ak-label-lg text-on-surface">{r.studentName}</span> },
    { key: 'room', header: 'Room', hideOnMobile: true },
    { key: 'period', header: 'Period', hideOnMobile: true, render: (r) => `${formatDate(r.fromDate)} – ${formatDate(r.toDate)}` },
    { key: 'days', header: 'Days', align: 'right' },
    { key: 'reason', header: 'Reason', hideOnMobile: true },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...HOSTEL_LEAVE[r.status]} icon={false} /> },
  ];
  return (
    <ResourceList title="Leave & gate pass" subtitle="Resident leave requests" icon="exit_to_app" tabs={HOSTEL_TABS} query={query} columns={columns} rowKey={(r) => r.id}
      search={{ placeholder: 'Search resident…', match: (r, t) => r.studentName.toLowerCase().includes(t) }}
      filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(HOSTEL_LEAVE).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
      unavailableTitle="Leave management is ready" unavailableMessage="Resident leave loads here from /hostel/leave once the backend is connected." />
  );
}

export function VisitorsPage() {
  const query = useModuleQuery<ListResult<HostelVisitor>>(['hostel', 'visitors'], () => fetchList('/hostel/visitors', { query: { pageSize: 300 } }));
  const columns: Column<HostelVisitor>[] = [
    { key: 'visitorName', header: 'Visitor', sortValue: (r) => r.visitorName, render: (r) => (
      <div className="min-w-0"><div className="truncate ak-label-lg text-on-surface">{r.visitorName}</div><div className="text-[12px] text-on-surface-variant">{r.relation}</div></div>
    ) },
    { key: 'studentName', header: 'Visiting', sortValue: (r) => r.studentName },
    { key: 'passId', header: 'Pass', hideOnMobile: true, render: (r) => <span className="ak-mono text-[12px]">{r.passId}</span> },
    { key: 'checkIn', header: 'In', hideOnMobile: true },
    { key: 'checkOut', header: 'Out', hideOnMobile: true, render: (r) => r.checkOut || '—' },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...VISITOR_STATUS[r.status]} icon={false} /> },
  ];
  return (
    <ResourceList title="Visitors" subtitle="Visitor log & gate passes" icon="badge" tabs={HOSTEL_TABS} query={query} columns={columns} rowKey={(r) => r.id}
      actions={<Button icon="add">Log visitor</Button>}
      search={{ placeholder: 'Search visitor or resident…', match: (r, t) => r.visitorName.toLowerCase().includes(t) || r.studentName.toLowerCase().includes(t) }}
      filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(VISITOR_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
      unavailableTitle="Visitor log is ready" unavailableMessage="Visitor entries load here from /hostel/visitors once the backend is connected." />
  );
}

export function MessPage() {
  const query = useModuleQuery(['hostel', 'mess'], () => apiFetch<HostelMessData>('/hostel/mess'));
  return (
    <div className="space-y-s6">
      <PageHeader title="Mess" subtitle="Weekly menu & consumption" icon="restaurant" tabs={<ModuleTabs tabs={HOSTEL_TABS} />} />
      <AsyncBoundary query={query} unavailableTitle="Mess menu is ready" unavailableMessage="The weekly menu loads here from /hostel/mess once the backend is connected." isEmpty={(d) => !d.weeklyMenus?.length}>
        {(d) => (
          <Card>
            <CardHeader title="Weekly menu" icon="restaurant_menu" action={<Text variant="label-lg" className="text-on-surface-variant">Cost MTD: <span className="text-on-surface">{d.costMtd}</span></Text>} />
            <div className="overflow-x-auto">
              <table className="w-full border-collapse">
                <thead>
                  <tr className="bg-surface-highest">
                    <th className="ak-table-header px-s4 py-s3 text-left text-on-surface-variant">Day</th>
                    <th className="ak-table-header px-s4 py-s3 text-left text-on-surface-variant">Meal</th>
                    <th className="ak-table-header px-s4 py-s3 text-left text-on-surface-variant">Items</th>
                  </tr>
                </thead>
                <tbody>
                  {d.weeklyMenus.map((m, i) => (
                    <tr key={i} className="border-t border-outline-variant/60">
                      <td className="ak-table-cell px-s4 py-s3 text-on-surface">{m.day}</td>
                      <td className="ak-table-cell px-s4 py-s3 capitalize text-on-surface">{humanize(m.mealType)}</td>
                      <td className="ak-table-cell px-s4 py-s3 text-on-surface">
                        {m.items}
                        {m.dietaryTags?.length > 0 && (
                          <span className="ml-s2 inline-flex gap-s1">{m.dietaryTags.map((t) => <StatusChip key={t} status="neutral" label={t} icon={false} />)}</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        )}
      </AsyncBoundary>
    </div>
  );
}

export function HostelReportsPage() {
  return (
    <ReportsHub title="Hostel reports" subtitle="Occupancy, mess and attendance" icon="summarize" tabs={HOSTEL_TABS}
      reports={[
        { key: 'occupancy', title: 'Occupancy', description: 'Block/room occupancy and vacancies.', icon: 'bed', endpoint: '/hostel/occupancy-metrics' },
        { key: 'attendance', title: 'Attendance', description: 'Session-wise roll-call trends.', icon: 'fact_check' },
        { key: 'mess', title: 'Mess consumption', description: 'Meal consumption and cost.', icon: 'restaurant' },
        { key: 'visitors', title: 'Visitor log', description: 'Visitor entries and gate passes.', icon: 'badge' },
      ]} />
  );
}
