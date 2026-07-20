import { useNavigate } from 'react-router-dom';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { KpiPage } from '@/components/system/KpiPage';
import { Button, Card, PageHeader, StatusChip, Text, type Column } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { humanize } from '@/lib/utils/format';

function crumbs(nav: ReturnType<typeof useNavigate>) {
  return [{ label: 'School setup', onClick: () => nav('/school-completion') }];
}

// ---- Hub ----
export function SchoolCompletionHubPage() {
  const nav = useNavigate();
  const groups: { title: string; items: { label: string; icon: string; path: string }[] }[] = [
    { title: 'Academic structure', items: [
      { label: 'Subjects', icon: 'menu_book', path: '/school-completion/subjects' },
      { label: 'Subject assignment', icon: 'assignment_ind', path: '/school-completion/subject-assignment' },
      { label: 'Class-teacher assignment', icon: 'supervisor_account', path: '/school-completion/class-teacher-assignment' },
      { label: 'Teacher reassignment', icon: 'swap_horiz', path: '/school-completion/teacher-reassignment' },
      { label: 'Room allocation', icon: 'meeting_room', path: '/school-completion/room-allocation' },
    ] },
    { title: 'Timetable', items: [
      { label: 'Timetable automation', icon: 'auto_awesome', path: '/school-completion/timetable-automation' },
      { label: 'Timetable optimization', icon: 'tune', path: '/school-completion/timetable-optimization' },
      { label: 'Timetable intelligence', icon: 'insights', path: '/school-completion/timetable-intelligence' },
      { label: 'Substitute manager', icon: 'published_with_changes', path: '/school-completion/substitute-manager' },
    ] },
    { title: 'Academic progress', items: [
      { label: 'Syllabus automation', icon: 'menu_book', path: '/school-completion/syllabus-automation' },
      { label: 'Lesson logs', icon: 'history_edu', path: '/school-completion/lesson-logs' },
      { label: 'Lesson analytics', icon: 'query_stats', path: '/school-completion/lesson-analytics' },
      { label: 'Academic progress', icon: 'trending_up', path: '/school-completion/academic-progress' },
    ] },
    { title: 'Engagement & config', items: [
      { label: 'Communication analytics', icon: 'insights', path: '/school-completion/communication-analytics' },
      { label: 'Communication delivery', icon: 'send', path: '/school-completion/communication-delivery' },
      { label: 'Parent activation', icon: 'family_restroom', path: '/school-completion/parent-activation' },
      { label: 'Branding', icon: 'palette', path: '/school-completion/branding' },
      { label: 'WhatsApp provider', icon: 'chat', path: '/school-completion/whatsapp-provider' },
      { label: 'Pilot dashboard', icon: 'rocket_launch', path: '/school-completion/pilot-dashboard' },
    ] },
  ];
  return (
    <div className="space-y-s6">
      <PageHeader title="School setup & operations" subtitle="Complete your school configuration" icon="school" />
      {groups.map((g) => (
        <div key={g.title}>
          <Text variant="title-sm" className="mb-s3 uppercase tracking-wide text-on-surface-variant">{g.title}</Text>
          <div className="grid grid-cols-1 gap-s3 sm:grid-cols-2 xl:grid-cols-3">
            {g.items.map((it) => (
              <Card key={it.path} interactive onClick={() => nav(it.path)} className="flex items-center gap-s3">
                <span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-primary-container text-on-primary-container"><Icon name={it.icon} size={22} /></span>
                <Text variant="label-lg" className="text-on-surface">{it.label}</Text>
                <Icon name="chevron_right" size={18} className="ml-auto text-on-surface-variant" />
              </Card>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

// ---- List pages ----
interface SubjectRow { id: string; name: string; code: string; classLabel: string; teacher: string; periodsPerWeek: number }
export function SubjectsPage() {
  const nav = useNavigate();
  const query = useModuleQuery<ListResult<SubjectRow>>(['school', 'subjects'], () => fetchList('/school/subjects', { query: { pageSize: 300 } }));
  const columns: Column<SubjectRow>[] = [
    { key: 'name', header: 'Subject', sortValue: (r) => r.name, render: (r) => <span className="ak-label-lg text-on-surface">{r.name}</span> },
    { key: 'code', header: 'Code', hideOnMobile: true, render: (r) => <span className="ak-mono text-[12px]">{r.code}</span> },
    { key: 'classLabel', header: 'Class', render: (r) => r.classLabel },
    { key: 'teacher', header: 'Teacher', hideOnMobile: true },
    { key: 'periodsPerWeek', header: 'Periods/wk', align: 'right' },
  ];
  return <ResourceList title="Subjects" subtitle="Subjects per class" icon="menu_book" breadcrumbs={crumbs(nav)} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">Add subject</Button>} search={{ placeholder: 'Search subject…', match: (r, t) => r.name.toLowerCase().includes(t) }}
    unavailableTitle="Subjects are ready" unavailableMessage="Subjects load from /school/subjects once connected." />;
}

interface AssignRow { id: string; teacher: string; classLabel: string; section: string; subject: string; role: string }
function assignPage(title: string, subtitle: string, icon: string, view: string) {
  return function Page() {
    const nav = useNavigate();
    const query = useModuleQuery<ListResult<AssignRow>>(['school', 'assign', view], () => fetchList('/academic/teacher-assignments', { query: { pageSize: 300, view } }));
    const columns: Column<AssignRow>[] = [
      { key: 'teacher', header: 'Teacher', sortValue: (r) => r.teacher, render: (r) => <span className="ak-label-lg text-on-surface">{r.teacher}</span> },
      { key: 'classLabel', header: 'Class', render: (r) => `${r.classLabel} · ${r.section}` },
      { key: 'subject', header: 'Subject', hideOnMobile: true },
      { key: 'role', header: 'Role', align: 'right', render: (r) => <StatusChip status="info" label={humanize(r.role)} icon={false} /> },
    ];
    return <ResourceList title={title} subtitle={subtitle} icon={icon} breadcrumbs={crumbs(nav)} query={query} columns={columns} rowKey={(r) => r.id}
      actions={<Button icon="add">New assignment</Button>} search={{ placeholder: 'Search teacher…', match: (r, t) => r.teacher.toLowerCase().includes(t) }}
      unavailableTitle={`${title} is ready`} unavailableMessage="Assignments load from /academic/teacher-assignments once connected." />;
  };
}
export const SubjectAssignmentPage = assignPage('Subject assignment', 'Assign subjects to teachers', 'assignment_ind', 'subject');
export const ClassTeacherAssignmentPage = assignPage('Class-teacher assignment', 'Assign class teachers', 'supervisor_account', 'class-teacher');
export const TeacherReassignmentPage = assignPage('Teacher reassignment', 'Reassign teaching load', 'swap_horiz', 'reassignment');

interface RoomRow { id: string; roomNumber: string; building: string; capacity: number; assignedTo: string; type: string }
export function RoomAllocationPage() {
  const nav = useNavigate();
  const query = useModuleQuery<ListResult<RoomRow>>(['school', 'rooms'], () => fetchList('/school/rooms', { query: { pageSize: 300 } }));
  const columns: Column<RoomRow>[] = [
    { key: 'roomNumber', header: 'Room', sortValue: (r) => r.roomNumber, render: (r) => <span className="ak-label-lg text-on-surface">{r.building} · {r.roomNumber}</span> },
    { key: 'type', header: 'Type', render: (r) => humanize(r.type) },
    { key: 'capacity', header: 'Capacity', align: 'right' },
    { key: 'assignedTo', header: 'Assigned to', hideOnMobile: true, render: (r) => r.assignedTo || 'Unassigned' },
  ];
  return <ResourceList title="Room allocation" subtitle="Rooms & assignments" icon="meeting_room" breadcrumbs={crumbs(nav)} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">Add room</Button>} search={{ placeholder: 'Search room…', match: (r, t) => r.roomNumber.toLowerCase().includes(t) }}
    unavailableTitle="Room allocation is ready" unavailableMessage="Rooms load from /school/rooms once connected." />;
}

interface LessonRow { id: string; date: string; teacher: string; classLabel: string; subject: string; topic: string; status: string }
export function LessonLogsPage() {
  const nav = useNavigate();
  const query = useModuleQuery<ListResult<LessonRow>>(['school', 'lesson-logs'], () => fetchList('/school/lesson-logs', { query: { pageSize: 300 } }));
  const columns: Column<LessonRow>[] = [
    { key: 'date', header: 'Date', sortValue: (r) => r.date },
    { key: 'teacher', header: 'Teacher', hideOnMobile: true },
    { key: 'classLabel', header: 'Class', render: (r) => `${r.classLabel} · ${r.subject}` },
    { key: 'topic', header: 'Topic', render: (r) => <span className="ak-label-lg text-on-surface">{r.topic}</span> },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={r.status === 'completed' ? 'success' : 'info'} label={humanize(r.status)} icon={false} /> },
  ];
  return <ResourceList title="Lesson logs" subtitle="Teaching logs by class" icon="history_edu" breadcrumbs={crumbs(nav)} query={query} columns={columns} rowKey={(r) => r.id}
    search={{ placeholder: 'Search topic or teacher…', match: (r, t) => r.topic.toLowerCase().includes(t) || r.teacher.toLowerCase().includes(t) }}
    unavailableTitle="Lesson logs are ready" unavailableMessage="Lesson logs load from /school/lesson-logs once connected." />;
}

export function SubstituteManagerPage() {
  const nav = useNavigate();
  const today = new Date().toISOString().slice(0, 10);
  const query = useModuleQuery<ListResult<{ id: string; subDate: string; sectionLabel?: string; originalTeacherName?: string; substituteTeacherName?: string; status: string }>>(['school', 'substitutes', today], () => fetchList('/academic/timetables/substitutions', { query: { pageSize: 300, date: today } }));
  const columns: Column<{ id: string; subDate: string; sectionLabel?: string; originalTeacherName?: string; substituteTeacherName?: string; status: string }>[] = [
    { key: 'subDate', header: 'Date', sortValue: (r) => r.subDate },
    { key: 'sectionLabel', header: 'Section', render: (r) => r.sectionLabel || '—' },
    { key: 'originalTeacherName', header: 'Absent', hideOnMobile: true, render: (r) => r.originalTeacherName || '—' },
    { key: 'substituteTeacherName', header: 'Substitute', render: (r) => r.substituteTeacherName || 'Unassigned' },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status="info" label={humanize(r.status)} icon={false} /> },
  ];
  return <ResourceList title="Substitute manager" subtitle="Assign cover teachers" icon="published_with_changes" breadcrumbs={crumbs(nav)} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">Assign substitute</Button>}
    unavailableTitle="Substitute manager is ready" unavailableMessage="Substitutions load from /academic/timetables/substitutions once connected." />;
}

// ---- Dashboard / analytics (KpiPage) ----
const kpi = (title: string, subtitle: string, icon: string, endpoint: string, key: string, icons?: string[]) => function Page() {
  const nav = useNavigate();
  return <div className="space-y-s6"><KpiPage title={title} subtitle={subtitle} icon={icon} endpoint={endpoint} queryKey={['school', key]} icons={icons}
    actions={<Button variant="text" size="sm" icon="arrow_back" onClick={() => nav('/school-completion')}>Setup</Button>} /></div>;
};
export const TimetableAutomationPage = kpi('Timetable automation', 'Auto-generate section timetables', 'auto_awesome', '/school/timetables/automate', 'tt-auto', ['auto_awesome', 'schedule', 'check_circle', 'warning']);
export const TimetableOptimizationPage = kpi('Timetable optimization', 'Optimise for conflicts & load', 'tune', '/school/timetables/optimize', 'tt-opt');
export const TimetableIntelligencePage = kpi('Timetable intelligence', 'Insights & recommendations', 'insights', '/school/timetables/intelligence', 'tt-intel');
export const SyllabusAutomationPage = kpi('Syllabus automation', 'Generate & track syllabus', 'menu_book', '/school/syllabus/templates', 'syllabus', ['menu_book', 'auto_awesome', 'checklist', 'trending_up']);
export const LessonAnalyticsPage = kpi('Lesson analytics', 'Teaching coverage & pace', 'query_stats', '/school/academic/teacher-progress', 'lesson-analytics');
export const AcademicProgressPage = kpi('Academic progress', 'Syllabus completion by class', 'trending_up', '/school/academic/teacher-progress', 'acad-progress');
export const CommunicationAnalyticsPage = kpi('Communication analytics', 'Reach & effectiveness', 'insights', '/communications/delivery/metrics', 'comm-analytics');
export const CommunicationDeliveryPage = kpi('Communication delivery', 'Delivery & read rates', 'send', '/communications/delivery/metrics', 'comm-delivery');
export const ParentActivationPage = kpi('Parent activation', 'App adoption & engagement', 'family_restroom', '/communications/delivery/metrics', 'parent-activation', ['family_restroom', 'phone_iphone', 'trending_up', 'notifications']);
export const PilotDashboardPage = kpi('Pilot dashboard', 'Rollout readiness', 'rocket_launch', '/school/pilot/dashboard', 'pilot', ['rocket_launch', 'checklist', 'groups', 'trending_up']);

// ---- Config pages ----
export function BrandingPage() {
  const nav = useNavigate();
  return (
    <div className="space-y-s6">
      <PageHeader title="Branding" subtitle="Logo, colours & templates" icon="palette" breadcrumbs={crumbs(nav)} actions={<Button icon="save" disabled>Save branding</Button>} />
      <Card>
        <Text variant="body-md" className="text-on-surface-variant">School branding (logo, primary colour, letterhead) applies across the app and printed documents. Saved via /school/branding.</Text>
        <div className="mt-s5 grid grid-cols-1 gap-s4 sm:grid-cols-3">
          {['Logo', 'Primary colour', 'Letterhead'].map((x) => (
            <div key={x} className="grid place-items-center rounded-lg border border-dashed border-outline-variant bg-surface-low py-s8 text-center"><Icon name="upload" size={28} className="text-on-surface-variant" /><Text variant="body-sm" className="mt-s2 text-on-surface-variant">{x}</Text></div>
          ))}
        </div>
      </Card>
    </div>
  );
}
export function WhatsAppProviderPage() {
  const nav = useNavigate();
  return (
    <div className="space-y-s6">
      <PageHeader title="WhatsApp provider" subtitle="Messaging gateway setup" icon="chat" breadcrumbs={crumbs(nav)} actions={<Button icon="check" variant="outlined" disabled>Test connection</Button>} />
      <Card className="max-w-xl">
        <Text variant="body-md" className="text-on-surface-variant">Connect a WhatsApp Business provider to send parent notices, fee reminders and alerts. Configured via /school/whatsapp-provider.</Text>
        <div className="mt-s4 flex items-center gap-s2 rounded-md bg-warning-container/50 px-s3 py-s2 ak-body-sm text-warning"><Icon name="info" size={16} />Provider credentials are entered here and verified against the gateway when connected.</div>
      </Card>
    </div>
  );
}
