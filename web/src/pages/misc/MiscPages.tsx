import { useNavigate } from 'react-router-dom';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { KpiPage } from '@/components/system/KpiPage';
import { Button, Card, CardHeader, PageHeader, StatusChip, Text, type Column } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { useAuth } from '@/lib/auth/AuthContext';
import { formatDate, humanize } from '@/lib/utils/format';

/** Simple centred info page for a screen whose surface is a hub/action (real UI, honest state). */
function InfoPage({ title, subtitle, icon, body, action }: { title: string; subtitle: string; icon: string; body: string; action?: string }) {
  return (
    <div className="space-y-s6">
      <PageHeader title={title} subtitle={subtitle} icon={icon} actions={action ? <Button icon="bolt" disabled>{action}</Button> : undefined} />
      <Card className="grid place-items-center py-s12 text-center">
        <span className="mb-s4 grid h-16 w-16 place-items-center rounded-2xl bg-primary-container text-on-primary-container"><Icon name={icon} size={32} /></span>
        <Text variant="title-md" className="text-on-surface">{title}</Text>
        <Text variant="body-md" className="mt-s1 max-w-reading text-on-surface-variant">{body}</Text>
      </Card>
    </div>
  );
}

const kpi = (title: string, subtitle: string, icon: string, endpoint: string, key: string, icons?: string[]) => () => (
  <KpiPage title={title} subtitle={subtitle} icon={icon} endpoint={endpoint} queryKey={['misc', key]} icons={icons} />
);

// ---- Evolution ----
export const GrowthPlatformPage = kpi('Growth', 'Growth & marketing platform', 'rocket_launch', '/growth', 'growth', ['trending_up', 'campaign', 'groups', 'insights']);
export const ParentInsightsPage = kpi('Parent insights', 'Parent sentiment & engagement', 'insights', '/parent-insights', 'parent-insights');
export const PrincipalCommandPage = kpi('Principal command', 'Principal command centre', 'workspace_premium', '/intelligence/principal/center', 'principal-command');
export const TeacherAssistantPage = kpi('Teacher assistant', 'AI teaching assistant', 'cast_for_education', '/intelligence/teacher-effectiveness/planning-center', 'teacher-assistant');
export const SetupWizardPage = () => <InfoPage title="Setup wizard" subtitle="Guided school setup" icon="auto_fix_high" body="A step-by-step wizard that walks you through configuring your school — academic year, classes, subjects, staff and fees. Backed by the onboarding service." action="Start wizard" />;

// ---- Copilot / AI ----
export const CopilotPage = () => <InfoPage title="Akshara Copilot" subtitle="Ask anything about your school" icon="auto_awesome" body="A conversational AI assistant that answers questions across the ERP — attendance, fees, exams — respecting your role and permissions. Connects to the AI gateway." action="New chat" />;
export const AiContentPage = kpi('AI content', 'AI-generated content library', 'article', '/intelligence/priorities', 'ai-content');
export const CopilotPersonaShellPage = () => <InfoPage title="Copilot" subtitle="Role-aware assistant" icon="smart_toy" body="The persona-aware Copilot shell adapts its tools and suggestions to your role. Powered by the W2 AI gateway." action="Open Copilot" />;
export const AiAssistantSettingsPage = () => <InfoPage title="AI assistant settings" subtitle="Configure the assistant" icon="tune" body="Control the AI assistant's behaviour, data scope and token budget for your school. Deterministic-first with AI enhancement." />;

// ---- Memories ----
interface MemoryRow { id: string; title: string; date: string; category: string; mediaCount: number }
export function SchoolMemoriesPage() {
  const query = useModuleQuery<ListResult<MemoryRow>>(['misc', 'memories'], () => fetchList('/school/memories', { query: { pageSize: 200 } }));
  const columns: Column<MemoryRow>[] = [
    { key: 'title', header: 'Memory', sortValue: (r) => r.title, render: (r) => <span className="ak-label-lg text-on-surface">{r.title}</span> },
    { key: 'category', header: 'Category', render: (r) => humanize(r.category) },
    { key: 'date', header: 'Date', hideOnMobile: true, render: (r) => formatDate(r.date) },
    { key: 'mediaCount', header: 'Media', align: 'right' },
  ];
  return <ResourceList title="School memories" subtitle="Events & moments" icon="photo_library" query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">Add memory</Button>} search={{ placeholder: 'Search memory…', match: (r, t) => r.title.toLowerCase().includes(t) }}
    unavailableTitle="School memories are ready" unavailableMessage="Memories load from the memories endpoint once connected." />;
}
export const MemoryEventPage = () => <InfoPage title="Memory event" subtitle="Event album" icon="collections" body="A photo/video album for a school event, shareable with parents. Opens from a memory in the timeline." />;

// ---- Dynamic widgets ----
export const DynamicWidgetRegistryPage = () => <InfoPage title="Widget registry" subtitle="Available dashboard widgets" icon="widgets" body="The registry of dashboard widgets that can be placed on role dashboards. Managed by platform admins." />;
export const DynamicWidgetLayoutEditorPage = () => <InfoPage title="Layout editor" subtitle="Compose role dashboards" icon="dashboard_customize" body="Drag-and-drop editor for composing per-role dashboards from registered widgets." action="Edit layout" />;
export const DynamicWidgetRuntimePage = kpi('Dynamic dashboard', 'Live composed dashboard', 'space_dashboard', '/management/dashboard', 'dynamic-runtime');

// ---- Employee / people 360 ----
export const Employee360Page = kpi('Employee 360', 'Complete employee view', 'badge', '/hr/dashboard', 'employee-360', ['badge', 'fact_check', 'payments', 'workspace_premium']);
export const EmployeePlatformPage = kpi('Employee platform', 'Staff self-service', 'groups', '/hr/dashboard', 'employee-platform');
export const Student360Page = kpi('Student 360', 'Complete student view', 'person', '/sis/dashboard', 'student-360', ['person', 'fact_check', 'grading', 'payments']);

// ---- Entitlements ----
interface PlanRow { id: string; name: string; tier: string; modules: number; status: string }
export function PlanEntitlementsPage() {
  const query = useModuleQuery<ListResult<PlanRow>>(['misc', 'entitlements'], () => fetchList('/entitlements/plans', { query: { pageSize: 100 } }));
  const columns: Column<PlanRow>[] = [
    { key: 'name', header: 'Plan', sortValue: (r) => r.name, render: (r) => <span className="ak-label-lg text-on-surface">{r.name}</span> },
    { key: 'tier', header: 'Tier', render: (r) => humanize(r.tier) },
    { key: 'modules', header: 'Modules', align: 'right' },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={r.status === 'active' ? 'success' : 'neutral'} label={humanize(r.status)} icon={false} /> },
  ];
  return <ResourceList title="Plan entitlements" subtitle="Subscription plans & modules" icon="workspace_premium" query={query} columns={columns} rowKey={(r) => r.id}
    unavailableTitle="Plan entitlements are ready" unavailableMessage="Plans load from /entitlements once connected." />;
}
export const OrgPlanAssignmentPage = () => <InfoPage title="Plan assignment" subtitle="Assign plans to organisations" icon="assignment" body="Assign subscription plans and module entitlements to schools/organisations." />;

// ---- Achievement / promotion ----
export const AchievementPromotionPage = kpi('Achievements', 'Student achievements & promotion', 'emoji_events', '/sis/dashboard', 'achievements', ['emoji_events', 'trending_up', 'workspace_premium', 'star']);
export const AchievementPreviewPage = () => <InfoPage title="Promotion preview" subtitle="Preview year-end promotion" icon="preview" body="Preview the outcome of year-end promotion for a class before applying — pass/fail, retained and promoted students." />;

// ---- Operations / platform-lite ----
export const OperationsHubPage = kpi('Operations', 'School operations hub', 'engineering', '/health/operations', 'operations', ['engineering', 'fact_check', 'schedule', 'warning']);
export const ResourceOptimizationPage = kpi('Resource optimization', 'Optimise staff & rooms', 'tune', '/school/subject-workload', 'resource-opt');
export const PredictionsPage = kpi('Predictions', 'Predictive insights', 'online_prediction', '/predictions', 'predictions', ['online_prediction', 'trending_up', 'warning', 'insights']);
export const IndustryHubPage = () => <InfoPage title="Industry" subtitle="Industry configuration" icon="domain" body="Industry-specific configuration for the platform. School is the active vertical." />;
export const WorkflowAutomationPage = () => <InfoPage title="Workflow automation" subtitle="Automate approvals & tasks" icon="account_tree" body="Design automation rules for approvals, reminders and cross-module workflows." action="New workflow" />;
export function ContinuityMigrationPage() {
  const { user } = useAuth();
  return <InfoPage title="Data continuity" subtitle="Migrate & carry forward" icon="published_with_changes" body={`Carry-forward students, staff and settings into the next academic year for ${user?.schoolName ?? 'your school'}. Backed by the continuity service.`} action="Start migration" />;
}

// ---- Admin ----
export function AdminHubPage() {
  const nav = useNavigate();
  const tools = [
    { label: 'Backup & restore', icon: 'backup', path: '/admin/backup-restore' },
    { label: 'Users & roles', icon: 'manage_accounts', path: '/school-config' },
    { label: 'Audit log', icon: 'history', path: '/notifications' },
    { label: 'System health', icon: 'monitor_heart', path: '/admin/dashboard' },
  ];
  return (
    <div className="space-y-s6">
      <PageHeader title="Admin" subtitle="System administration" icon="admin_panel_settings" />
      <div className="grid grid-cols-1 gap-s4 sm:grid-cols-2 xl:grid-cols-4">
        {tools.map((t) => (
          <Card key={t.label} interactive onClick={() => nav(t.path)} className="flex flex-col items-start gap-s3">
            <span className="grid h-11 w-11 place-items-center rounded-xl bg-primary-container text-on-primary-container"><Icon name={t.icon} size={24} /></span>
            <Text variant="title-sm" className="text-on-surface">{t.label}</Text>
          </Card>
        ))}
      </div>
    </div>
  );
}
export const BackupRestorePage = () => <InfoPage title="Backup & restore" subtitle="Data safety" icon="backup" body="Trigger on-demand backups and restore points. Nightly automated backups run on the server (24h RPO for pilot)." action="Backup now" />;

// ---- Legal ----
export function LegalAcceptancePage() {
  return (
    <div className="space-y-s6">
      <PageHeader title="Policies" subtitle="Terms & data policies" icon="gavel" />
      <Card className="max-w-2xl">
        <CardHeader title="Legal & privacy" icon="verified_user" />
        <ul className="space-y-s2">
          {['Terms of Service', 'Privacy Policy', 'Data Processing Agreement', 'Acceptable Use Policy'].map((p) => (
            <li key={p} className="flex items-center gap-s2 border-b border-outline-variant/50 py-s3 last:border-0">
              <Icon name="description" size={18} className="text-on-surface-variant" />
              <Text variant="body-md" className="flex-1 text-on-surface">{p}</Text>
              <StatusChip status="success" label="Accepted" />
            </li>
          ))}
        </ul>
      </Card>
    </div>
  );
}

// ---- Education (curriculum) ----
export const EducationPage = kpi('Education', 'Curriculum & question papers', 'school', '/intelligence/exam/analytics', 'education', ['menu_book', 'grading', 'quiz', 'insights']);
export const QuestionPaperDetailPage = () => <InfoPage title="Question paper" subtitle="Generated paper" icon="quiz" body="A generated question paper with blueprint, sections and marks. Opens from the education question-paper list." action="Download PDF" />;

// ---- Parent meetings (staff side) ----
interface MeetingRow { id: string; title: string; date: string; className: string; slots: number; booked: number; status: string }
export function ParentMeetingsPage() {
  const query = useModuleQuery<ListResult<MeetingRow>>(['misc', 'meetings'], () => fetchList('/parent-meetings', { query: { pageSize: 200 } }));
  const columns: Column<MeetingRow>[] = [
    { key: 'title', header: 'Meeting', sortValue: (r) => r.title, render: (r) => <span className="ak-label-lg text-on-surface">{r.title}</span> },
    { key: 'className', header: 'Class', render: (r) => r.className },
    { key: 'date', header: 'Date', hideOnMobile: true, render: (r) => formatDate(r.date) },
    { key: 'booked', header: 'Booked', align: 'right', render: (r) => `${r.booked}/${r.slots}` },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={r.status === 'completed' ? 'success' : r.status === 'scheduled' ? 'info' : 'neutral'} label={humanize(r.status)} icon={false} /> },
  ];
  return <ResourceList title="Parent meetings" subtitle="PTM scheduling" icon="groups_3" query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">Schedule PTM</Button>} search={{ placeholder: 'Search meeting…', match: (r, t) => r.title.toLowerCase().includes(t) }}
    unavailableTitle="Parent meetings are ready" unavailableMessage="PTM schedules load from /parent-meetings once connected." />;
}
export const ParentMeetingDetailPage = () => <InfoPage title="Meeting detail" subtitle="Slots & bookings" icon="event" body="Slot-by-slot bookings and notes for a parent-teacher meeting. Opens from the meetings list." />;
