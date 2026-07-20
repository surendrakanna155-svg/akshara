import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Avatar, Button, StatusChip, type Column, type SemanticStatus } from '@/components/ui';
import { humanize } from '@/lib/utils/format';
import { MODULE_TABS } from '@/routes/navConfig';
import { normalizeShortAttendanceAlert } from '@/lib/contracts/attendance';
import type { AttendanceCorrectionRequest, AttendanceCorrectionStatus, AttendanceRegisterEntry, ShortAttendanceAlert } from '@/lib/contracts/attendance';

const TABS = MODULE_TABS.attendance;

const CORRECTION_STATUS: Record<AttendanceCorrectionStatus, { status: SemanticStatus; label: string }> = {
  pending: { status: 'warning', label: 'Pending' }, approved: { status: 'success', label: 'Approved' }, rejected: { status: 'error', label: 'Rejected' },
};

export function AttendanceOverviewPage() {
  const query = useModuleQuery<ListResult<ShortAttendanceAlert>>(['attendance', 'alerts'], async () => {
    const res = await fetchList<ShortAttendanceAlert>('/attendance/alerts/short-attendance', { query: { pageSize: 300 } });
    return { ...res, items: res.items.map(normalizeShortAttendanceAlert) };
  });
  const columns: Column<ShortAttendanceAlert>[] = [
    { key: 'studentName', header: 'Student', sortValue: (r) => r.studentName, render: (r) => (
      <div className="flex items-center gap-s3"><Avatar name={r.studentName} size={32} /><div className="min-w-0"><div className="truncate ak-label-lg text-on-surface">{r.studentName}</div><div className="text-[12px] text-on-surface-variant">{r.section ? `${r.classLabel} · ${r.section}` : r.classLabel}</div></div></div>
    ) },
    { key: 'percentPresent', header: 'Attendance', align: 'right', sortValue: (r) => r.percentPresent, render: (r) => (
      <span className={r.percentPresent < 75 ? 'font-semibold text-error' : 'text-on-surface'}>{r.percentPresent}%</span>
    ) },
    { key: 'flag', header: '', align: 'right', render: () => <StatusChip status="warning" label="Short attendance" /> },
  ];
  return <ResourceList title="Attendance" subtitle="Short-attendance watchlist" icon="fact_check" tabs={TABS} query={query} columns={columns} rowKey={(r) => r.studentId}
    actions={<Button variant="outlined" icon="notifications" disabled>Notify parents</Button>}
    search={{ placeholder: 'Search student…', match: (r, t) => r.studentName.toLowerCase().includes(t) }}
    unavailableTitle="Attendance overview is ready"
    unavailableMessage="Students below the attendance threshold load here from /attendance/alerts/short-attendance once the backend is connected."
    emptyTitle="Everyone above threshold" emptyIcon="verified" />;
}

export function AttendanceRegisterPage() {
  const query = useModuleQuery<ListResult<AttendanceRegisterEntry>>(['attendance', 'register'], () => fetchList('/attendance/register', { query: { pageSize: 400 } }));
  const columns: Column<AttendanceRegisterEntry>[] = [
    { key: 'roll', header: 'Roll', width: '80px', render: (r) => <span className="ak-mono">{r.roll ?? '—'}</span> },
    { key: 'name', header: 'Student', sortValue: (r) => r.name, render: (r) => <span className="ak-label-lg text-on-surface">{r.name}</span> },
    { key: 'classLabel', header: 'Class', hideOnMobile: true },
    { key: 'mark', header: 'Mark', align: 'right', render: (r) => <StatusChip status={r.mark?.toLowerCase().startsWith('p') ? 'success' : r.mark?.toLowerCase().startsWith('a') ? 'error' : 'info'} label={humanize(r.mark)} icon={false} /> },
  ];
  return <ResourceList title="Register" subtitle="Daily attendance register" icon="checklist" tabs={TABS} query={query} columns={columns} rowKey={(r) => r.studentId}
    search={{ placeholder: 'Search student…', match: (r, t) => r.name.toLowerCase().includes(t) }}
    unavailableTitle="Register is ready" unavailableMessage="The daily register loads here from /attendance/register once the backend is connected." />;
}

export function AttendanceCorrectionsPage() {
  const query = useModuleQuery<ListResult<AttendanceCorrectionRequest>>(['attendance', 'corrections'], () => fetchList('/attendance/corrections', { query: { pageSize: 300 } }));
  const columns: Column<AttendanceCorrectionRequest>[] = [
    { key: 'studentName', header: 'Student', sortValue: (r) => r.studentName, render: (r) => (
      <div className="min-w-0"><div className="truncate ak-label-lg text-on-surface">{r.studentName}</div><div className="text-[12px] text-on-surface-variant">{r.classLabel} · {r.section} · {r.dateLabel}</div></div>
    ) },
    { key: 'change', header: 'Change', render: (r) => <span className="ak-label-md"><span className="text-error">{humanize(r.fromMark)}</span> → <span className="text-success">{humanize(r.toMark)}</span></span> },
    { key: 'reason', header: 'Reason', hideOnMobile: true },
    { key: 'requesterName', header: 'Requested by', hideOnMobile: true, render: (r) => `${r.requesterName} (${humanize(r.requesterRole)})` },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...CORRECTION_STATUS[r.status]} icon={false} /> },
  ];
  return <ResourceList title="Attendance corrections" subtitle="Correction requests — maker/checker" icon="edit_calendar" tabs={TABS} query={query} columns={columns} rowKey={(r) => r.id}
    search={{ placeholder: 'Search student…', match: (r, t) => r.studentName.toLowerCase().includes(t) }}
    filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(CORRECTION_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
    unavailableTitle="Corrections are ready"
    unavailableMessage="Attendance correction requests load here from /attendance/corrections once the backend is connected. Approve/reject posts to the live maker-checker endpoint." />;
}
