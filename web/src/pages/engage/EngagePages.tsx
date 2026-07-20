import { useNavigate } from 'react-router-dom';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { KpiPage } from '@/components/system/KpiPage';
import { Badge, Button, Card, PageHeader, StatusChip, Text, type Column, type SemanticStatus } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { formatDateTime, humanize } from '@/lib/utils/format';

interface Broadcast {
  id: string;
  title: string;
  channel: string;
  audience: string;
  sentAt: string;
  status: string;
  deliveredCount: number;
  totalCount: number;
}
interface NotificationItem {
  id: string;
  title: string;
  body: string;
  category: string;
  timeLabel: string;
  read: boolean;
}

const BROADCAST_STATUS: Record<string, SemanticStatus> = { sent: 'success', scheduled: 'info', draft: 'neutral', sending: 'pending', failed: 'error' };

export function CommunicationPage() {
  const query = useModuleQuery<ListResult<Broadcast>>(['comm', 'broadcasts'], () => fetchList('/communications/broadcasts/history', { query: { pageSize: 200 } }));
  const columns: Column<Broadcast>[] = [
    { key: 'title', header: 'Broadcast', sortValue: (r) => r.title, render: (r) => <span className="ak-label-lg text-on-surface">{r.title}</span> },
    { key: 'channel', header: 'Channel', render: (r) => humanize(r.channel) },
    { key: 'audience', header: 'Audience', hideOnMobile: true },
    { key: 'delivered', header: 'Delivered', align: 'right', hideOnMobile: true, render: (r) => `${r.deliveredCount}/${r.totalCount}` },
    { key: 'sentAt', header: 'Sent', hideOnMobile: true, render: (r) => (r.sentAt ? formatDateTime(r.sentAt) : '—') },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={BROADCAST_STATUS[r.status] ?? 'neutral'} label={humanize(r.status)} icon={false} /> },
  ];
  return <ResourceList title="Communication" subtitle="Notices & broadcasts" icon="campaign" query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">New broadcast</Button>}
    search={{ placeholder: 'Search broadcast…', match: (r, t) => r.title.toLowerCase().includes(t) }}
    unavailableTitle="Communication is ready"
    unavailableMessage="Notices and broadcasts load here from /communications/broadcasts/history once the backend is connected. Sending posts to /communications/broadcasts." />;
}

export function NotificationsPage() {
  const query = useModuleQuery<ListResult<NotificationItem>>(['notifications', 'inbox'], () => fetchList('/communication/inbox', { query: { pageSize: 200 } }));
  return (
      <ResourceList title="Notifications" subtitle="Your inbox" icon="notifications"
        actions={<Button variant="outlined" icon="done_all">Mark all read</Button>}
        query={query} rowKey={(r) => r.id}
        columns={[
          { key: 'title', header: 'Notification', render: (r) => (
            <div className="flex items-start gap-s3 py-s1">
              {!r.read && <span className="mt-[6px] h-2 w-2 shrink-0 rounded-full bg-primary" />}
              <div className="min-w-0"><div className="flex items-center gap-s2"><span className="truncate ak-label-lg text-on-surface">{r.title}</span><Badge tone="neutral">{humanize(r.category)}</Badge></div><div className="truncate text-[13px] text-on-surface-variant">{r.body}</div></div>
            </div>
          ) },
          { key: 'timeLabel', header: 'When', align: 'right', width: '140px', render: (r) => <span className="text-on-surface-variant">{r.timeLabel}</span> },
        ] as Column<NotificationItem>[]}
        search={{ placeholder: 'Search notifications…', match: (r, t) => r.title.toLowerCase().includes(t) || r.body.toLowerCase().includes(t) }}
        unavailableTitle="Notifications are ready"
        unavailableMessage="Your notification inbox loads here from /communication/inbox once the backend is connected."
        emptyTitle="You're all caught up" emptyIcon="notifications_none" />
  );
}

export function ReportsHubPage() {
  const navigate = useNavigate();
  const groups = [
    { title: 'Finance', icon: 'account_balance', path: '/finance/reports', items: ['Daily collection', 'Outstanding dues', 'Defaulter aging'] },
    { title: 'Admissions', icon: 'how_to_reg', path: '/admissions/reports', items: ['Lead pipeline', 'Conversion funnel', 'Source effectiveness'] },
    { title: 'HR', icon: 'badge', path: '/hr/reports', items: ['Headcount', 'Attendance', 'Payroll register'] },
    { title: 'Academics', icon: 'grading', path: '/academics/exams/reports', items: ['Result sheets', 'Report cards', 'Toppers'] },
    { title: 'Transport', icon: 'directions_bus', path: '/transport/reports', items: ['Route occupancy', 'Vehicle compliance'] },
    { title: 'Library', icon: 'local_library', path: '/library/reports', items: ['Circulation', 'Overdue & fines'] },
    { title: 'Hostel', icon: 'night_shelter', path: '/hostel/reports', items: ['Occupancy', 'Mess consumption'] },
    { title: 'Inventory', icon: 'inventory_2', path: '/inventory/reports', items: ['Asset valuation', 'Stock ledger'] },
    { title: 'Alumni', icon: 'diversity_3', path: '/alumni/reports', items: ['Giving summary', 'Engagement'] },
  ];
  return (
    <div className="space-y-s6">
      <PageHeader title="Reports" subtitle="All school reports in one place" icon="summarize" />
      <div className="grid grid-cols-1 gap-s4 sm:grid-cols-2 xl:grid-cols-3">
        {groups.map((g) => (
          <Card key={g.title} interactive onClick={() => navigate(g.path)} className="flex flex-col">
            <div className="mb-s3 flex items-center gap-s3">
              <span className="grid h-10 w-10 place-items-center rounded-xl bg-primary-container text-on-primary-container"><Icon name={g.icon} size={22} /></span>
              <Text variant="title-sm" className="text-on-surface">{g.title}</Text>
            </div>
            <ul className="flex-1 space-y-s1">
              {g.items.map((it) => <li key={it} className="flex items-center gap-s2 ak-body-sm text-on-surface-variant"><Icon name="description" size={16} />{it}</li>)}
            </ul>
            <div className="mt-s3 flex items-center gap-s1 ak-label-md text-primary">Open <Icon name="chevron_right" size={16} /></div>
          </Card>
        ))}
      </div>
    </div>
  );
}

export function OnboardingPage() {
  return <KpiPage title="Onboarding" subtitle="School setup & go-live readiness" icon="rocket_launch"
    endpoint="/onboarding/dashboard" queryKey={['onboarding', 'dashboard']} icons={['checklist', 'group_add', 'upload_file', 'rocket_launch']}
    unavailableMessage="Onboarding progress and go-live checklist load here from /onboarding/dashboard once the backend is connected." />;
}

export function SchoolConfigPage() {
  const areas = [
    { title: 'Academic year', icon: 'calendar_today', desc: 'Terms, sessions and holidays.' },
    { title: 'Classes & sections', icon: 'meeting_room', desc: 'Class structure and capacities.' },
    { title: 'Subjects', icon: 'menu_book', desc: 'Subjects and electives per class.' },
    { title: 'Grading', icon: 'grade', desc: 'Grade scales and boundaries.' },
    { title: 'Fee heads', icon: 'request_quote', desc: 'Fee categories and structures.' },
    { title: 'Roles & permissions', icon: 'admin_panel_settings', desc: 'RBAC and approval chains.' },
    { title: 'Branding', icon: 'palette', desc: 'Logo, colours and templates.' },
    { title: 'Integrations', icon: 'hub', desc: 'WhatsApp, SMS, payment gateways.' },
  ];
  return (
    <div className="space-y-s6">
      <PageHeader title="School setup" subtitle="Configure your school" icon="school" />
      <div className="grid grid-cols-1 gap-s4 sm:grid-cols-2 xl:grid-cols-3">
        {areas.map((a) => (
          <Card key={a.title} interactive className="flex items-start gap-s3">
            <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-primary-container text-on-primary-container"><Icon name={a.icon} size={24} /></span>
            <div><Text variant="title-sm" className="text-on-surface">{a.title}</Text><Text variant="body-sm" className="mt-[2px] text-on-surface-variant">{a.desc}</Text></div>
          </Card>
        ))}
      </div>
      <Text variant="body-sm" className="text-on-surface-variant">Each area opens its configuration form, wired to the school configuration service (/school-config).</Text>
    </div>
  );
}
