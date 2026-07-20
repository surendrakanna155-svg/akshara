import { useNavigate } from 'react-router-dom';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { KpiPage } from '@/components/system/KpiPage';
import { Avatar, Button, Card, Input, PageHeader, Select, StatusChip, Text, Textarea, type Column, type SemanticStatus } from '@/components/ui';
import { SettingsPage } from '@/pages/settings/SettingsPage';
import { formatDate, humanize } from '@/lib/utils/format';

interface ClassRow { id: string; className: string; section: string; subject: string; period: string; studentCount: number; marked: boolean }
interface HwRow { id: string; className: string; subject: string; title: string; dueDate: string; submissions: number; total: number; status: string }
interface ExamRow { id: string; examName: string; className: string; subject: string; date: string; status: string }
interface MsgRow { id: string; from: string; subject: string; preview: string; timeLabel: string; unread: boolean }
interface LeaveRow { id: string; fromDate: string; toDate: string; type: string; days: number; status: string; reason: string }
interface RiskRow { id: string; studentName: string; className: string; riskLevel: string; reason: string }
interface ParentCommRow { id: string; parentName: string; studentName: string; subject: string; status: string; timeLabel: string }

const leaveStatus = (s: string): SemanticStatus => (s === 'approved' ? 'success' : s === 'rejected' ? 'error' : s === 'cancelled' ? 'neutral' : 'warning');
const riskColor = (s: string): SemanticStatus => (s === 'high' ? 'error' : s === 'medium' ? 'warning' : 'success');

export const TeacherTodayPage = () => (
  <KpiPage title="Today" subtitle="Your day at a glance" icon="today" endpoint="/teacher/dashboard" queryKey={['teacher', 'today']}
    icons={['schedule', 'fact_check', 'assignment', 'forum']} unavailableMessage="Today's classes and tasks load from /teacher/dashboard once connected." />
);
export const TeacherDashboardPage = () => (
  <KpiPage title="Dashboard" subtitle="Teaching overview" icon="dashboard" endpoint="/teacher/dashboard" queryKey={['teacher', 'dashboard']}
    icons={['groups', 'fact_check', 'assignment', 'grading']} unavailableMessage="Your dashboard loads from /teacher/dashboard once connected." />
);
export const ClassTeacherDashboardPage = () => (
  <KpiPage title="My class" subtitle="Class teacher overview" icon="supervisor_account" endpoint="/teacher/dashboard" queryKey={['teacher', 'class-dashboard']}
    icons={['groups', 'fact_check', 'trending_up', 'warning']} unavailableMessage="Your class overview loads from /teacher/dashboard once connected." />
);

export function TeacherAttendancePage() {
  const query = useModuleQuery<ListResult<ClassRow>>(['teacher', 'attendance'], () => fetchList('/teacher/attendance/classes', { query: { pageSize: 100 } }));
  const columns: Column<ClassRow>[] = [
    { key: 'className', header: 'Class', sortValue: (r) => r.className, render: (r) => <span className="ak-label-lg text-on-surface">{r.className} · {r.section}</span> },
    { key: 'subject', header: 'Subject', hideOnMobile: true },
    { key: 'period', header: 'Period', hideOnMobile: true },
    { key: 'studentCount', header: 'Students', align: 'right' },
    { key: 'marked', header: 'Status', align: 'right', render: (r) => <StatusChip status={r.marked ? 'success' : 'warning'} label={r.marked ? 'Marked' : 'Pending'} icon={false} /> },
  ];
  return <ResourceList title="Attendance" subtitle="Mark class attendance" icon="fact_check" query={query} columns={columns} rowKey={(r) => r.id}
    onRowClick={() => {}} unavailableTitle="Attendance is ready" unavailableMessage="Your classes load from /teacher/attendance/classes once connected." />;
}

export const MyAttendancePage = () => (
  <KpiPage title="My attendance" subtitle="Your staff attendance history" icon="event_available" endpoint="/staff-attendance/my-history" queryKey={['teacher', 'my-attendance']}
    icons={['fact_check', 'event_available', 'schedule', 'beach_access']} unavailableMessage="Your attendance history loads from /staff-attendance/my-history once connected." />
);

export function TeacherTimetablePage() {
  const query = useModuleQuery<ListResult<{ id: string; day: string; period: number; className: string; subject: string; time: string }>>(['teacher', 'timetable'], () => fetchList('/teacher/timetable', { query: { pageSize: 100 } }));
  const columns: Column<{ id: string; day: string; period: number; className: string; subject: string; time: string }>[] = [
    { key: 'day', header: 'Day', sortValue: (r) => r.day },
    { key: 'period', header: 'Period', align: 'right', render: (r) => `P${r.period}` },
    { key: 'time', header: 'Time', hideOnMobile: true },
    { key: 'className', header: 'Class', render: (r) => <span className="ak-label-lg text-on-surface">{r.className}</span> },
    { key: 'subject', header: 'Subject', hideOnMobile: true },
  ];
  return <ResourceList title="Timetable" subtitle="My teaching schedule" icon="calendar_view_week" query={query} columns={columns} rowKey={(r) => r.id}
    unavailableTitle="Timetable is ready" unavailableMessage="Your timetable loads from /teacher/timetable once connected." />;
}

function homeworkColumns(): Column<HwRow>[] {
  return [
    { key: 'title', header: 'Homework', sortValue: (r) => r.title, render: (r) => (
      <div className="min-w-0"><div className="truncate ak-label-lg text-on-surface">{r.title}</div><div className="text-[12px] text-on-surface-variant">{r.className} · {r.subject}</div></div>
    ) },
    { key: 'dueDate', header: 'Due', hideOnMobile: true, render: (r) => formatDate(r.dueDate) },
    { key: 'submissions', header: 'Submitted', align: 'right', render: (r) => `${r.submissions}/${r.total}` },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={r.status === 'closed' ? 'neutral' : 'info'} label={humanize(r.status)} icon={false} /> },
  ];
}
export function TeacherHomeworkPage() {
  const query = useModuleQuery<ListResult<HwRow>>(['teacher', 'homework'], () => fetchList('/teacher/homework', { query: { pageSize: 200 } }));
  return <ResourceList title="Homework" subtitle="Assigned homework" icon="assignment" query={query} columns={homeworkColumns()} rowKey={(r) => r.id}
    actions={<Button icon="add">Assign homework</Button>} search={{ placeholder: 'Search homework…', match: (r, t) => r.title.toLowerCase().includes(t) }}
    unavailableTitle="Homework is ready" unavailableMessage="Your homework loads from /teacher/homework once connected." />;
}
export function TeacherHomeworkHistoryPage() {
  const query = useModuleQuery<ListResult<HwRow>>(['teacher', 'homework-history'], () => fetchList('/teacher/homework/history', { query: { pageSize: 200 } }));
  return <ResourceList title="Homework history" subtitle="Past assignments" icon="history" query={query} columns={homeworkColumns()} rowKey={(r) => r.id}
    search={{ placeholder: 'Search homework…', match: (r, t) => r.title.toLowerCase().includes(t) }}
    unavailableTitle="Homework history is ready" unavailableMessage="Past homework loads from /teacher/homework/history once connected." />;
}
export function TeacherHomeworkCreatePage() {
  return (
    <div className="space-y-s6">
      <PageHeader title="Assign homework" subtitle="Create a new assignment" icon="post_add"
        actions={<Button icon="send">Assign</Button>} />
      <Card>
        <div className="grid grid-cols-1 gap-s4 md:grid-cols-2">
          <Select label="Class" placeholder="Select class…" options={[]} />
          <Select label="Subject" placeholder="Select subject…" options={[]} />
          <Input label="Title" placeholder="e.g. Chapter 5 exercises" />
          <Input label="Due date" type="date" />
          <div className="md:col-span-2"><Textarea label="Instructions" rows={5} placeholder="Describe the homework…" /></div>
        </div>
        <Text variant="body-sm" className="mt-s4 text-on-surface-variant">Submitting posts to the live /teacher/homework endpoint. Class and subject options load from your teaching assignments.</Text>
      </Card>
    </div>
  );
}

export function TeacherExamsPage() {
  const query = useModuleQuery<ListResult<ExamRow>>(['teacher', 'exams'], () => fetchList('/teacher/exams/upcoming', { query: { pageSize: 200 } }));
  const columns: Column<ExamRow>[] = [
    { key: 'examName', header: 'Exam', sortValue: (r) => r.examName, render: (r) => <span className="ak-label-lg text-on-surface">{r.examName}</span> },
    { key: 'className', header: 'Class', render: (r) => `${r.className} · ${r.subject}` },
    { key: 'date', header: 'Date', hideOnMobile: true, render: (r) => formatDate(r.date) },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status="info" label={humanize(r.status)} icon={false} /> },
  ];
  return <ResourceList title="Exams" subtitle="Upcoming exams & marks entry" icon="grading" query={query} columns={columns} rowKey={(r) => r.id}
    unavailableTitle="Exams are ready" unavailableMessage="Your exams load from /teacher/exams/upcoming once connected." />;
}

export function TeacherMessagesPage() {
  const navigate = useNavigate();
  // The live /teacher/messages router sends `parentName` / `unreadCount`; the row
  // reads `from` / `unread`. Map on the way in.
  const query = useModuleQuery<ListResult<MsgRow>>(['teacher', 'messages'], async () => {
    const res = await fetchList<MsgRow & Record<string, unknown>>('/teacher/messages', { query: { pageSize: 200 } });
    return {
      ...res,
      items: res.items.map((r) => ({
        ...r,
        from: r.from ?? (typeof r.parentName === 'string' ? r.parentName : ''),
        subject: r.subject ?? (typeof r.studentName === 'string' ? r.studentName : ''),
        unread: r.unread ?? (typeof r.unreadCount === 'number' ? r.unreadCount > 0 : false),
      })),
    };
  });
  return <ResourceList title="Messages" subtitle="Conversations" icon="forum" query={query} rowKey={(r) => r.id}
    columns={[
      { key: 'from', header: 'From', render: (r) => (
        <div className="flex items-center gap-s3">{r.unread && <span className="h-2 w-2 rounded-full bg-primary" />}<Avatar name={r.from} size={32} /><div className="min-w-0"><div className="truncate ak-label-lg text-on-surface">{r.from}</div><div className="truncate text-[12px] text-on-surface-variant">{r.subject} — {r.preview}</div></div></div>
      ) },
      { key: 'timeLabel', header: 'When', align: 'right', width: '120px', render: (r) => <span className="text-on-surface-variant">{r.timeLabel}</span> },
    ] as Column<MsgRow>[]}
    onRowClick={(r) => navigate(`/teacher/messages/${r.id}`)} unavailableTitle="Messages are ready" unavailableMessage="Your conversations load from /teacher/messages once connected." emptyTitle="No messages" emptyIcon="forum" />;
}

export function TeacherParentCommunicationPage() {
  const query = useModuleQuery<ListResult<ParentCommRow>>(['teacher', 'parent-comm'], () => fetchList('/teacher/parent-communication', { query: { pageSize: 200 } }));
  const columns: Column<ParentCommRow>[] = [
    { key: 'parentName', header: 'Parent', sortValue: (r) => r.parentName, render: (r) => (
      <div className="min-w-0"><div className="truncate ak-label-lg text-on-surface">{r.parentName}</div><div className="text-[12px] text-on-surface-variant">re: {r.studentName}</div></div>
    ) },
    { key: 'subject', header: 'Subject', hideOnMobile: true },
    { key: 'timeLabel', header: 'When', hideOnMobile: true, align: 'right' },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={r.status === 'resolved' ? 'success' : 'warning'} label={humanize(r.status)} icon={false} /> },
  ];
  return <ResourceList title="Parent communication" subtitle="Concerns & conversations" icon="diversity_1" query={query} columns={columns} rowKey={(r) => r.id}
    unavailableTitle="Parent communication is ready" unavailableMessage="Parent conversations load from /teacher/parent-communication once connected." />;
}

export function TeacherStudentRiskPage() {
  const query = useModuleQuery<ListResult<RiskRow>>(['teacher', 'risk'], () => fetchList('/teacher/parent-communication/concerns', { query: { pageSize: 200 } }));
  const columns: Column<RiskRow>[] = [
    { key: 'studentName', header: 'Student', sortValue: (r) => r.studentName, render: (r) => <span className="ak-label-lg text-on-surface">{r.studentName}</span> },
    { key: 'className', header: 'Class', hideOnMobile: true },
    { key: 'reason', header: 'Reason', hideOnMobile: true },
    { key: 'riskLevel', header: 'Risk', align: 'right', render: (r) => <StatusChip status={riskColor(r.riskLevel)} label={humanize(r.riskLevel)} icon={false} /> },
  ];
  return <ResourceList title="Student risk" subtitle="At-risk students in your classes" icon="warning" query={query} columns={columns} rowKey={(r) => r.id}
    unavailableTitle="Student risk is ready" unavailableMessage="At-risk students load from the intelligence risk endpoint once connected." />;
}

function leaveColumns(): Column<LeaveRow>[] {
  return [
    { key: 'type', header: 'Type', render: (r) => humanize(r.type) },
    { key: 'period', header: 'Period', render: (r) => `${formatDate(r.fromDate)} – ${formatDate(r.toDate)}` },
    { key: 'days', header: 'Days', align: 'right' },
    { key: 'reason', header: 'Reason', hideOnMobile: true },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={leaveStatus(r.status)} label={humanize(r.status)} icon={false} /> },
  ];
}
export function TeacherLeavePage() {
  const query = useModuleQuery<ListResult<LeaveRow>>(['teacher', 'leave'], () => fetchList('/teacher/leave', { query: { pageSize: 200 } }));
  return <ResourceList title="Leave" subtitle="My leave requests" icon="event_busy" query={query} columns={leaveColumns()} rowKey={(r) => r.id}
    actions={<Button icon="add">Apply for leave</Button>} unavailableTitle="Leave is ready" unavailableMessage="Your leave requests load from /teacher/leave once connected." />;
}
export function TeacherLeaveApprovalsPage() {
  const query = useModuleQuery<ListResult<LeaveRow & { requester?: string }>>(['teacher', 'leave-approvals'], () => fetchList('/teacher/leave', { query: { pageSize: 200, view: 'approvals' } }));
  return <ResourceList title="Leave approvals" subtitle="Student leave for your class" icon="approval" query={query} columns={leaveColumns()} rowKey={(r) => r.id}
    unavailableTitle="Leave approvals are ready" unavailableMessage="Student leave requests load from /teacher/leave once connected." />;
}

export function TeacherProfilePage() {
  return <KpiPage title="My profile" subtitle="Teaching profile" icon="person" endpoint="/teacher/dashboard" queryKey={['teacher', 'profile']}
    icons={['badge', 'groups', 'cast_for_education', 'workspace_premium']} unavailableMessage="Your profile loads from /teacher/dashboard once connected." />;
}
export const TeacherSettingsPage = () => <SettingsPage />;
