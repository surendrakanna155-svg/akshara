import { useNavigate } from 'react-router-dom';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';
import { fetchList, type ListResult } from '@/lib/api/list';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { ResourceList } from '@/components/system/ResourceList';
import { KpiPage } from '@/components/system/KpiPage';
import { Avatar, Badge, Button, Card, CardHeader, PageHeader, StatusChip, Text, type Column, type SemanticStatus } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { useAuth } from '@/lib/auth/AuthContext';
import { formatDate, humanize } from '@/lib/utils/format';

interface AttnRow { id: string; date: string; status: string; subject?: string }
interface HwRow { id: string; subject: string; title: string; dueDate: string; status: string }
interface ExamRow { id: string; examName: string; subject: string; date: string; maxMarks: number; marksObtained: number | null; grade?: string }
interface NoticeRow { id: string; title: string; body: string; date: string; category: string }
interface EventRow { id: string; title: string; date: string; venue: string; type: string }
interface MsgRow { id: string; from: string; subject: string; preview: string; timeLabel: string; unread: boolean }
interface ReceiptRow { id: string; receiptNumber: string; amount: string; date: string; mode: string }
interface LeaveRow { id: string; fromDate: string; toDate: string; reason: string; days: number; status: string }
interface TtRow { id: string; day: string; period: number; subject: string; teacher: string; time: string }

const attn = (s: string): SemanticStatus => (s.toLowerCase().startsWith('p') ? 'success' : s.toLowerCase().startsWith('a') ? 'error' : 'info');
const leaveStatus = (s: string): SemanticStatus => (s === 'approved' ? 'success' : s === 'rejected' ? 'error' : 'warning');

export const ParentDashboardPage = () => (
  <KpiPage title="Home" subtitle="Your child at a glance" icon="home" endpoint="/parent/dashboard" queryKey={['parent', 'dashboard']}
    icons={['fact_check', 'assignment', 'grading', 'payments']} unavailableMessage="Your child's summary loads from /parent/dashboard once connected." />
);
export const ParentExperienceHubPage = () => (
  <KpiPage title="Experience" subtitle="Holistic academic summary" icon="auto_awesome" endpoint="/parent/experience/summary" queryKey={['parent', 'experience']}
    icons={['insights', 'trending_up', 'fact_check', 'grading']} unavailableMessage="The academic summary loads from /parent/experience/summary once connected." />
);
export const ParentAcademicReportPage = () => (
  <KpiPage title="Academic report" subtitle="Progress across subjects" icon="assessment" endpoint="/parent/experience/summary" queryKey={['parent', 'academic-report']}
    icons={['grading', 'trending_up', 'menu_book', 'workspace_premium']} unavailableMessage="The academic report loads from /parent/experience/summary once connected." />
);

export function ParentAttendancePage() {
  const query = useModuleQuery<ListResult<AttnRow>>(['parent', 'attendance'], () => fetchList('/parent/attendance', { query: { pageSize: 200 } }));
  return <ResourceList title="Attendance" subtitle="Your child's attendance" icon="fact_check" query={query} rowKey={(r) => r.id}
    columns={[
      { key: 'date', header: 'Date', sortValue: (r) => r.date, render: (r) => formatDate(r.date) },
      { key: 'subject', header: 'Subject', hideOnMobile: true, render: (r) => r.subject || '—' },
      { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={attn(r.status)} label={humanize(r.status)} icon={false} /> },
    ] as Column<AttnRow>[]}
    unavailableTitle="Attendance is ready" unavailableMessage="Attendance loads from /parent/attendance once connected." />;
}

export function ParentTimetablePage() {
  const query = useModuleQuery<ListResult<TtRow>>(['parent', 'timetable'], () => fetchList('/parent/timetable', { query: { pageSize: 100 } }));
  return <ResourceList title="Timetable" subtitle="Weekly schedule" icon="calendar_view_week" query={query} rowKey={(r) => r.id}
    columns={[
      { key: 'day', header: 'Day', sortValue: (r) => r.day },
      { key: 'period', header: 'Period', align: 'right', render: (r) => `P${r.period}` },
      { key: 'time', header: 'Time', hideOnMobile: true },
      { key: 'subject', header: 'Subject', render: (r) => <span className="ak-label-lg text-on-surface">{r.subject}</span> },
      { key: 'teacher', header: 'Teacher', hideOnMobile: true },
    ] as Column<TtRow>[]}
    unavailableTitle="Timetable is ready" unavailableMessage="Timetable loads from /parent/timetable once connected." />;
}

export function ParentHomeworkPage() {
  const query = useModuleQuery<ListResult<HwRow>>(['parent', 'homework'], () => fetchList('/parent/homework', { query: { pageSize: 200 } }));
  return <ResourceList title="Homework" subtitle="Assignments & submissions" icon="assignment" query={query} rowKey={(r) => r.id}
    columns={[
      { key: 'subject', header: 'Subject', render: (r) => <Badge tone="primary">{r.subject}</Badge> },
      { key: 'title', header: 'Homework', sortValue: (r) => r.title, render: (r) => <span className="ak-label-lg text-on-surface">{r.title}</span> },
      { key: 'dueDate', header: 'Due', hideOnMobile: true, render: (r) => formatDate(r.dueDate) },
      { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={r.status === 'submitted' ? 'success' : r.status === 'overdue' ? 'error' : 'warning'} label={humanize(r.status)} icon={false} /> },
    ] as Column<HwRow>[]}
    unavailableTitle="Homework is ready" unavailableMessage="Homework loads from /parent/homework once connected." />;
}

function examColumns(): Column<ExamRow>[] {
  return [
    { key: 'examName', header: 'Exam', sortValue: (r) => r.examName, render: (r) => <span className="ak-label-lg text-on-surface">{r.examName}</span> },
    { key: 'subject', header: 'Subject' },
    { key: 'date', header: 'Date', hideOnMobile: true, render: (r) => formatDate(r.date) },
    { key: 'marks', header: 'Marks', align: 'right', render: (r) => (r.marksObtained != null ? <span className="ak-tabular font-semibold text-on-surface">{r.marksObtained}/{r.maxMarks}</span> : '—') },
    { key: 'grade', header: 'Grade', align: 'right', render: (r) => r.grade || '—' },
  ];
}
export function ParentExamsPage() {
  const query = useModuleQuery<ListResult<ExamRow>>(['parent', 'exams'], () => fetchList('/parent/exams', { query: { pageSize: 200 } }));
  return <ResourceList title="Exams" subtitle="Schedule & results" icon="grading" query={query} columns={examColumns()} rowKey={(r) => r.id}
    unavailableTitle="Exams are ready" unavailableMessage="Exams load from /parent/exams once connected." />;
}
export function ParentReportCardPage() {
  const query = useModuleQuery<ListResult<ExamRow>>(['parent', 'reportcard'], () => fetchList('/parent/exams', { query: { pageSize: 200, view: 'report-card' } }));
  return <ResourceList title="Report card" subtitle="Term results" icon="assessment" query={query} columns={examColumns()} rowKey={(r) => r.id}
    actions={<Button variant="outlined" icon="download">Download</Button>}
    unavailableTitle="Report card is ready" unavailableMessage="The report card loads from /parent/exams once connected." />;
}

export function ParentFeesPage() {
  const query = useModuleQuery(['parent', 'fees'], () => apiFetch<{ totalDue: string; totalPaid: string; balance: string; nextDueDate?: string; installments?: { id: string; label: string; amount: string; dueDate: string; status: string }[] }>('/parent/fees'));
  const navPay = () => { window.location.hash = ''; };
  return (
    <div className="space-y-s6">
      <PageHeader title="Fees" subtitle="Fee account & payments" icon="payments"
        actions={<Button icon="payment" onClick={navPay}>Pay now</Button>} />
      <AsyncBoundary query={query} unavailableTitle="Fees are ready" unavailableMessage="Your fee account loads from /parent/fees once connected.">
        {(d) => (
          <div className="space-y-s6">
            <div className="grid grid-cols-1 gap-s4 sm:grid-cols-3">
              {[['Total due', d.totalDue, 'account_balance_wallet', 'primary'], ['Paid', d.totalPaid, 'check_circle', 'tertiary'], ['Balance', d.balance, 'pending', 'warning']].map(([l, v, ic]) => (
                <Card key={l as string}><div className="flex items-center gap-s3"><span className="grid h-11 w-11 place-items-center rounded-xl bg-primary-container text-on-primary-container"><Icon name={ic as string} size={24} /></span><div><Text variant="kpi-label" className="text-on-surface-variant">{l}</Text><Text variant="title-md" className="ak-tabular text-on-surface">{v}</Text></div></div></Card>
              ))}
            </div>
            {d.installments && d.installments.length > 0 && (
              <Card padded={false}>
                <div className="p-s5 pb-s3"><CardHeader title="Installments" icon="event_repeat" className="mb-0" /></div>
                <ul className="divide-y divide-outline-variant/50">
                  {d.installments.map((i) => (
                    <li key={i.id} className="flex items-center gap-s3 px-s5 py-s3">
                      <div className="min-w-0 flex-1"><Text variant="label-lg" className="text-on-surface">{i.label}</Text><Text variant="body-sm" className="text-on-surface-variant">Due {formatDate(i.dueDate)}</Text></div>
                      <Text variant="title-sm" className="ak-tabular text-on-surface">{i.amount}</Text>
                      <StatusChip status={i.status === 'paid' ? 'success' : 'warning'} label={humanize(i.status)} icon={false} />
                    </li>
                  ))}
                </ul>
              </Card>
            )}
          </div>
        )}
      </AsyncBoundary>
    </div>
  );
}

export function ParentPaymentPage() {
  return (
    <div className="space-y-s6">
      <PageHeader title="Pay fees" subtitle="Secure fee payment" icon="payment" />
      <Card className="mx-auto max-w-lg">
        <CardHeader title="Payment" icon="lock" />
        <Text variant="body-md" className="text-on-surface-variant">Fee payment initiates a secure checkout via the school's payment gateway.</Text>
        <div className="mt-s5 rounded-lg border border-dashed border-outline-variant bg-surface-low p-s6 text-center">
          <Icon name="account_balance_wallet" size={40} className="mx-auto text-on-surface-variant" />
          <Text variant="body-md" className="mt-s3 text-on-surface-variant">The payable amount and gateway load from /parent/fees and /parent/payments/initiate once connected.</Text>
          <Button className="mt-s4" icon="lock" disabled>Proceed to pay</Button>
        </div>
      </Card>
    </div>
  );
}

export function ParentReceiptsPage() {
  const navigate = useNavigate();
  const query = useModuleQuery<ListResult<ReceiptRow>>(['parent', 'receipts'], () => fetchList('/parent/receipts', { query: { pageSize: 200 } }));
  return <ResourceList title="Receipts" subtitle="Payment history" icon="receipt_long" query={query} rowKey={(r) => r.id}
    columns={[
      { key: 'receiptNumber', header: 'Receipt', render: (r) => <span className="ak-mono text-[13px]">{r.receiptNumber}</span> },
      { key: 'date', header: 'Date', sortValue: (r) => r.date, render: (r) => formatDate(r.date) },
      { key: 'mode', header: 'Mode', hideOnMobile: true },
      { key: 'amount', header: 'Amount', align: 'right', render: (r) => <span className="ak-tabular font-semibold text-on-surface">{r.amount}</span> },
      { key: 'dl', header: '', align: 'right', width: '48px', render: () => <Icon name="download" size={18} className="text-primary" /> },
    ] as Column<ReceiptRow>[]}
    onRowClick={(r) => navigate(`/parent/receipts/${r.id}`)} unavailableTitle="Receipts are ready" unavailableMessage="Payment receipts load from /parent/receipts once connected." />;
}

export function ParentNoticesPage() {
  const query = useModuleQuery<ListResult<NoticeRow>>(['parent', 'notices'], () => fetchList('/parent/notices', { query: { pageSize: 200 } }));
  return (
    <div className="space-y-s6">
      <PageHeader title="Notices" subtitle="School announcements" icon="campaign" />
      <AsyncBoundary query={query} unavailableTitle="Notices are ready" unavailableMessage="School notices load from /parent/notices once connected." isEmpty={(d) => d.items.length === 0}>
        {(d) => (
          <div className="space-y-s3">
            {d.items.map((n) => (
              <Card key={n.id}><div className="flex items-start gap-s3"><span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-primary-container text-on-primary-container"><Icon name="campaign" size={22} /></span><div className="min-w-0 flex-1"><div className="flex items-center gap-s2"><Text variant="title-sm" className="text-on-surface">{n.title}</Text><Badge tone="neutral">{humanize(n.category)}</Badge></div><Text variant="body-md" className="mt-s1 text-on-surface-variant">{n.body}</Text><Text variant="body-sm" className="mt-s2 text-on-surface-variant/70">{formatDate(n.date)}</Text></div></div></Card>
            ))}
          </div>
        )}
      </AsyncBoundary>
    </div>
  );
}

export function ParentEventsPage() {
  const query = useModuleQuery<ListResult<EventRow>>(['parent', 'events'], () => fetchList('/parent/events', { query: { pageSize: 200 } }));
  return <ResourceList title="Events" subtitle="School calendar" icon="event" query={query} rowKey={(r) => r.id}
    columns={[
      { key: 'title', header: 'Event', sortValue: (r) => r.title, render: (r) => <span className="ak-label-lg text-on-surface">{r.title}</span> },
      { key: 'date', header: 'Date', sortValue: (r) => r.date, render: (r) => formatDate(r.date) },
      { key: 'venue', header: 'Venue', hideOnMobile: true },
      { key: 'type', header: 'Type', align: 'right', render: (r) => <Badge tone="primary">{humanize(r.type)}</Badge> },
    ] as Column<EventRow>[]}
    unavailableTitle="Events are ready" unavailableMessage="School events load from /parent/events once connected." />;
}

export function ParentMessagesPage() {
  const navigate = useNavigate();
  const query = useModuleQuery<ListResult<MsgRow>>(['parent', 'messages'], () => fetchList('/parent/messages', { query: { pageSize: 200 } }));
  return <ResourceList title="Messages" subtitle="Conversations with teachers" icon="forum" query={query} rowKey={(r) => r.id}
    columns={[
      { key: 'from', header: 'From', render: (r) => (<div className="flex items-center gap-s3">{r.unread && <span className="h-2 w-2 rounded-full bg-primary" />}<Avatar name={r.from} size={32} /><div className="min-w-0"><div className="truncate ak-label-lg text-on-surface">{r.from}</div><div className="truncate text-[12px] text-on-surface-variant">{r.subject} — {r.preview}</div></div></div>) },
      { key: 'timeLabel', header: 'When', align: 'right', width: '120px', render: (r) => <span className="text-on-surface-variant">{r.timeLabel}</span> },
    ] as Column<MsgRow>[]}
    onRowClick={(r) => navigate(`/parent/messages/${r.id}`)} unavailableTitle="Messages are ready" unavailableMessage="Conversations load from /parent/messages once connected." emptyTitle="No messages" emptyIcon="forum" />;
}

export function ParentLeavePage() {
  const query = useModuleQuery<ListResult<LeaveRow>>(['parent', 'leave'], () => fetchList('/parent/leave', { query: { pageSize: 200 } }));
  return <ResourceList title="Leave" subtitle="Leave applications" icon="event_busy" query={query} rowKey={(r) => r.id}
    columns={[
      { key: 'period', header: 'Period', render: (r) => `${formatDate(r.fromDate)} – ${formatDate(r.toDate)}` },
      { key: 'days', header: 'Days', align: 'right' },
      { key: 'reason', header: 'Reason', hideOnMobile: true },
      { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={leaveStatus(r.status)} label={humanize(r.status)} icon={false} /> },
    ] as Column<LeaveRow>[]}
    actions={<Button icon="add">Apply for leave</Button>}
    unavailableTitle="Leave is ready" unavailableMessage="Leave applications load from /parent/leave once connected." />;
}

export const ParentPtmPage = () => (
  <KpiPage title="Parent meetings" subtitle="PTM schedule & slots" icon="groups_3" endpoint="/parent/dashboard" queryKey={['parent', 'ptm']}
    icons={['event', 'schedule', 'groups_3', 'check_circle']} unavailableMessage="PTM slots load from the meetings endpoint once connected." />
);
export const ParentTransportPage = () => (
  <KpiPage title="Transport" subtitle="Your child's bus & route" icon="directions_bus" endpoint="/parent/dashboard" queryKey={['parent', 'transport']}
    icons={['directions_bus', 'route', 'my_location', 'schedule']} unavailableMessage="Transport details load from the parent transport endpoint once connected." />
);
export const ParentActionInboxPage = () => (
  <KpiPage title="Action inbox" subtitle="Items needing your attention" icon="inbox" endpoint="/parent/communication/inbox" queryKey={['parent', 'action-inbox']}
    icons={['priority_high', 'assignment_late', 'payments', 'how_to_reg']} unavailableMessage="Action items load from /parent/communication/inbox once connected." />
);

export function ParentFamilyViewPage() {
  const query = useModuleQuery<ListResult<{ id: string; name: string; classLabel: string; admissionNumber: string }>>(['parent', 'family'], () => fetchList('/parent/profile', { query: { view: 'family' } }));
  return (
    <div className="space-y-s6">
      <PageHeader title="My children" subtitle="Switch between your children" icon="family_restroom" />
      <AsyncBoundary query={query} unavailableTitle="Family view is ready" unavailableMessage="Your children load from /parent/profile once connected." isEmpty={(d) => d.items.length === 0}>
        {(d) => (
          <div className="grid grid-cols-1 gap-s4 sm:grid-cols-2 xl:grid-cols-3">
            {d.items.map((c) => (
              <Card key={c.id} interactive className="flex items-center gap-s3"><Avatar name={c.name} size={48} /><div><Text variant="title-sm" className="text-on-surface">{c.name}</Text><Text variant="body-sm" className="text-on-surface-variant">{c.classLabel} · {c.admissionNumber}</Text></div></Card>
            ))}
          </div>
        )}
      </AsyncBoundary>
    </div>
  );
}

export function ParentProfilePage() {
  const { user } = useAuth();
  return (
    <div className="space-y-s6">
      <PageHeader title="My profile" subtitle="Contact & account" icon="person" />
      <Card>
        <div className="flex items-center gap-s4"><Avatar name={user?.name ?? 'Parent'} size={64} /><div><Text variant="title-md" className="text-on-surface">{user?.name}</Text><Text variant="body-sm" className="text-on-surface-variant">{user?.schoolName}</Text></div></div>
      </Card>
    </div>
  );
}
