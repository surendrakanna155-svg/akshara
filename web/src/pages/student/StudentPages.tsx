import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';
import { fetchList, type ListResult } from '@/lib/api/list';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { ResourceList } from '@/components/system/ResourceList';
import { KpiPage } from '@/components/system/KpiPage';
import { Avatar, Badge, Card, CardHeader, PageHeader, StatusChip, Text, type Column, type SemanticStatus } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { useAuth } from '@/lib/auth/AuthContext';
import { formatDate, humanize } from '@/lib/utils/format';

interface AttnRow { id: string; date: string; status: string; remark?: string }
interface HwRow { id: string; subject: string; title: string; dueDate: string; status: string }
interface ExamRow { id: string; examName: string; subject: string; date: string; maxMarks: number; marksObtained: number | null; grade?: string }
interface NoticeRow { id: string; title: string; body: string; date: string; category: string }
interface TtRow { id: string; day: string; period: number; subject: string; teacher: string; time: string }

const attnStatus = (s: string): SemanticStatus => (s.toLowerCase().startsWith('p') ? 'success' : s.toLowerCase().startsWith('a') ? 'error' : 'info');

export const StudentDashboardPage = () => (
  <KpiPage title="My dashboard" subtitle="Today at a glance" icon="home" endpoint="/student/dashboard" queryKey={['student', 'dashboard']}
    icons={['fact_check', 'assignment', 'grading', 'campaign']} unavailableMessage="Your dashboard loads from /student/dashboard once connected." />
);

export const StudentProgressPage = () => (
  <KpiPage title="My progress" subtitle="Academic progress" icon="trending_up" endpoint="/student/dashboard" queryKey={['student', 'progress']}
    icons={['trending_up', 'grading', 'fact_check', 'workspace_premium']} unavailableMessage="Your progress loads from /student/dashboard once connected." />
);

export function StudentAttendancePage() {
  const query = useModuleQuery<ListResult<AttnRow>>(['student', 'attendance'], () => fetchList('/student/attendance', { query: { pageSize: 200 } }));
  const columns: Column<AttnRow>[] = [
    { key: 'date', header: 'Date', sortValue: (r) => r.date, render: (r) => formatDate(r.date) },
    { key: 'remark', header: 'Remark', hideOnMobile: true, render: (r) => r.remark || '—' },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={attnStatus(r.status)} label={humanize(r.status)} icon={false} /> },
  ];
  return <ResourceList title="Attendance" subtitle="My attendance history" icon="fact_check" query={query} columns={columns} rowKey={(r) => r.id}
    unavailableTitle="Attendance is ready" unavailableMessage="Your attendance loads from /student/attendance once connected." />;
}

export function StudentHomeworkPage() {
  const query = useModuleQuery<ListResult<HwRow>>(['student', 'homework'], () => fetchList('/student/homework', { query: { pageSize: 200 } }));
  const columns: Column<HwRow>[] = [
    { key: 'subject', header: 'Subject', sortValue: (r) => r.subject, render: (r) => <Badge tone="primary">{r.subject}</Badge> },
    { key: 'title', header: 'Homework', sortValue: (r) => r.title, render: (r) => <span className="ak-label-lg text-on-surface">{r.title}</span> },
    { key: 'dueDate', header: 'Due', hideOnMobile: true, render: (r) => formatDate(r.dueDate) },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={r.status === 'submitted' ? 'success' : r.status === 'overdue' ? 'error' : 'warning'} label={humanize(r.status)} icon={false} /> },
  ];
  return <ResourceList title="Homework" subtitle="Assignments" icon="assignment" query={query} columns={columns} rowKey={(r) => r.id}
    unavailableTitle="Homework is ready" unavailableMessage="Your homework loads from /student/homework once connected." />;
}

export function StudentExamsPage() {
  const query = useModuleQuery<ListResult<ExamRow>>(['student', 'exams'], () => fetchList('/student/exams', { query: { pageSize: 200 } }));
  const columns: Column<ExamRow>[] = [
    { key: 'examName', header: 'Exam', sortValue: (r) => r.examName, render: (r) => <span className="ak-label-lg text-on-surface">{r.examName}</span> },
    { key: 'subject', header: 'Subject' },
    { key: 'date', header: 'Date', hideOnMobile: true, render: (r) => formatDate(r.date) },
    { key: 'marks', header: 'Marks', align: 'right', render: (r) => (r.marksObtained != null ? <span className="ak-tabular font-semibold text-on-surface">{r.marksObtained}/{r.maxMarks}</span> : <span className="text-on-surface-variant">—</span>) },
    { key: 'grade', header: 'Grade', align: 'right', render: (r) => r.grade || '—' },
  ];
  return <ResourceList title="Exams" subtitle="Exam schedule & results" icon="grading" query={query} columns={columns} rowKey={(r) => r.id}
    unavailableTitle="Exams are ready" unavailableMessage="Your exams load from /student/exams once connected." />;
}

export function StudentTimetablePage() {
  const query = useModuleQuery<ListResult<TtRow>>(['student', 'timetable'], () => fetchList('/student/timetable', { query: { pageSize: 100 } }));
  const columns: Column<TtRow>[] = [
    { key: 'day', header: 'Day', sortValue: (r) => r.day },
    { key: 'period', header: 'Period', align: 'right', render: (r) => `P${r.period}` },
    { key: 'time', header: 'Time', hideOnMobile: true },
    { key: 'subject', header: 'Subject', render: (r) => <span className="ak-label-lg text-on-surface">{r.subject}</span> },
    { key: 'teacher', header: 'Teacher', hideOnMobile: true },
  ];
  return <ResourceList title="Timetable" subtitle="My weekly timetable" icon="calendar_view_week" query={query} columns={columns} rowKey={(r) => r.id}
    unavailableTitle="Timetable is ready" unavailableMessage="Your timetable loads from /student/timetable once connected." />;
}

export function StudentNoticesPage() {
  const query = useModuleQuery<ListResult<NoticeRow>>(['student', 'notices'], () => fetchList('/student/notices', { query: { pageSize: 200 } }));
  return (
    <div className="space-y-s6">
      <PageHeader title="Notices" subtitle="School announcements" icon="campaign" />
      <AsyncBoundary query={query} unavailableTitle="Notices are ready" unavailableMessage="School notices load from /student/notices once connected." isEmpty={(d) => d.items.length === 0}>
        {(d) => (
          <div className="space-y-s3">
            {d.items.map((n) => (
              <Card key={n.id}>
                <div className="flex items-start gap-s3">
                  <span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-primary-container text-on-primary-container"><Icon name="campaign" size={22} /></span>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-s2"><Text variant="title-sm" className="text-on-surface">{n.title}</Text><Badge tone="neutral">{humanize(n.category)}</Badge></div>
                    <Text variant="body-md" className="mt-s1 text-on-surface-variant">{n.body}</Text>
                    <Text variant="body-sm" className="mt-s2 text-on-surface-variant/70">{formatDate(n.date)}</Text>
                  </div>
                </div>
              </Card>
            ))}
          </div>
        )}
      </AsyncBoundary>
    </div>
  );
}

export function StudentReportCardPage() {
  const query = useModuleQuery<ListResult<ExamRow>>(['student', 'reportcard'], () => fetchList('/student/exams', { query: { pageSize: 200, view: 'report-card' } }));
  const columns: Column<ExamRow>[] = [
    { key: 'subject', header: 'Subject', sortValue: (r) => r.subject, render: (r) => <span className="ak-label-lg text-on-surface">{r.subject}</span> },
    { key: 'examName', header: 'Assessment', hideOnMobile: true },
    { key: 'marks', header: 'Marks', align: 'right', render: (r) => (r.marksObtained != null ? `${r.marksObtained}/${r.maxMarks}` : '—') },
    { key: 'grade', header: 'Grade', align: 'right', render: (r) => r.grade || '—' },
  ];
  return <ResourceList title="Report card" subtitle="Term results" icon="assessment" query={query} columns={columns} rowKey={(r) => r.id}
    unavailableTitle="Report card is ready" unavailableMessage="Your report card loads from /student/exams once connected." />;
}

export function StudentProfilePage() {
  const { user } = useAuth();
  const query = useModuleQuery(['student', 'profile'], () => apiFetch<Record<string, string>>('/student/profile'));
  return (
    <div className="space-y-s6">
      <PageHeader title="My profile" subtitle="Personal details" icon="person" />
      <Card>
        <div className="flex items-center gap-s4">
          <Avatar name={user?.name ?? 'Student'} size={64} />
          <div><Text variant="title-md" className="text-on-surface">{user?.name}</Text><Text variant="body-sm" className="text-on-surface-variant">{user?.schoolName}</Text></div>
        </div>
      </Card>
      <AsyncBoundary query={query} unavailableTitle="Profile is ready" unavailableMessage="Your full profile loads from /student/profile once connected.">
        {(d) => (
          <Card>
            <CardHeader title="Details" icon="badge" />
            <dl className="grid grid-cols-2 gap-s4">
              {Object.entries(d).map(([k, v]) => (
                <div key={k}><Text variant="label-md" className="text-on-surface-variant">{humanize(k)}</Text><Text variant="body-md" className="text-on-surface">{String(v)}</Text></div>
              ))}
            </dl>
          </Card>
        )}
      </AsyncBoundary>
    </div>
  );
}
