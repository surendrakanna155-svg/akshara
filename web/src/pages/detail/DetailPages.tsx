import { useNavigate, useParams } from 'react-router-dom';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { Avatar, Button, Card, CardHeader, PageHeader, StatusChip, Tabs, Text } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { formatDate, formatDateTime, humanize } from '@/lib/utils/format';
import { useState, type ReactNode } from 'react';

function KV({ items }: { items: [string, string, string][] }) {
  return (
    <dl className="grid grid-cols-2 gap-s4 md:grid-cols-3">
      {items.map(([label, value, icon]) => (
        <div key={label} className="flex items-start gap-s2">
          <Icon name={icon} size={18} className="mt-[2px] text-on-surface-variant" />
          <div className="min-w-0"><Text variant="label-md" className="text-on-surface-variant">{label}</Text><Text variant="body-md" className="truncate text-on-surface">{value || '—'}</Text></div>
        </div>
      ))}
    </dl>
  );
}

// ---- SIS student profile (rich) ----
interface SisProfile {
  studentName: string; admissionNumber: string; publicStudentId?: string; classLabel: string; section: string;
  gender: string; dateOfBirth: string; academicYear: string; status: string; guardianName: string; phone: string; email: string;
  feeAccount?: { totalDue: string; totalPaid: string; balance: string };
  attendance?: { percentPresent: number; present: number; total: number };
  academicHistory?: { term: string; percentage: string; rank?: string }[];
  documents?: { name: string; status: string }[];
  siblings?: { name: string; classLabel: string }[];
}
/**
 * GET /sis/students/{id} answers a NESTED composite — `{ student, profile,
 * currentEnrollment, guardians, documents }` — not this flat profile. Project it
 * onto the shape the page renders. Sections the composite doesn't carry
 * (academic history, fee account, attendance summary) are left undefined so the
 * page shows its existing honest "none on file" states instead of inventing any.
 */
function toSisProfile(raw: Record<string, unknown>): SisProfile {
  const o = (v: unknown) => (v && typeof v === 'object' ? (v as Record<string, unknown>) : {});
  const str = (v: unknown) => (typeof v === 'string' ? v : '');
  const student = o(raw.student);
  const profile = o(raw.profile);
  const enrolment = o(raw.currentEnrollment);
  const guardian = o((Array.isArray(raw.guardians) ? raw.guardians[0] : undefined));
  const docs = Array.isArray(raw.documents) ? raw.documents : [];

  return {
    studentName: str(student.displayName) || str(student.studentName),
    admissionNumber: str(profile.admissionNumber) || str(student.studentCode),
    publicStudentId: str(profile.publicStudentId) || undefined,
    classLabel: str(enrolment.className),
    section: str(enrolment.sectionName),
    gender: str(profile.gender),
    dateOfBirth: str(profile.dateOfBirth),
    academicYear: str(enrolment.academicYear),
    status: str(student.status),
    guardianName: str(guardian.displayName) || str(guardian.name),
    phone: str(guardian.phone),
    email: str(guardian.email),
    documents: docs.map((d) => {
      const doc = o(d);
      return { name: humanize(str(doc.documentType) || str(doc.type)), status: str(doc.status) };
    }),
  };
}

export function SisStudentDetailPage() {
  const { id = '' } = useParams();
  const nav = useNavigate();
  const [tab, setTab] = useState('overview');
  const query = useModuleQuery(
    ['sis', 'student', id],
    async () => toSisProfile(await apiFetch<Record<string, unknown>>(`/sis/students/${id}`)),
    { enabled: !!id },
  );
  return (
    <div className="space-y-s6">
      <PageHeader title="Student profile" icon="person" breadcrumbs={[{ label: 'Students', onClick: () => nav('/sis/registry') }, { label: 'Profile' }]}
        actions={<Button variant="outlined" icon="edit">Edit</Button>} />
      <AsyncBoundary query={query} unavailableTitle="Student profile is ready" unavailableMessage="The full profile loads from /sis/students/{id} once connected.">
        {(d) => (
          <div className="space-y-s5">
            <Card>
              <div className="flex flex-wrap items-center gap-s4">
                <Avatar name={d.studentName} size={64} />
                <div className="min-w-0"><Text variant="title-lg" className="text-on-surface">{d.studentName}</Text><Text variant="body-sm" className="ak-mono text-on-surface-variant">{d.publicStudentId || d.admissionNumber} · {d.classLabel} {d.section}</Text></div>
                <div className="ml-auto"><StatusChip status={d.status === 'active' ? 'success' : 'neutral'} label={humanize(d.status)} /></div>
              </div>
            </Card>
            <Tabs items={[{ key: 'overview', label: 'Overview' }, { key: 'academics', label: 'Academics' }, { key: 'fees', label: 'Fees' }, { key: 'attendance', label: 'Attendance' }, { key: 'documents', label: 'Documents' }]} value={tab} onChange={setTab} />
            {tab === 'overview' && <Card><CardHeader title="Personal & guardian" icon="badge" /><KV items={[['Admission No.', d.admissionNumber, 'badge'], ['Academic Year', d.academicYear, 'calendar_today'], ['Gender', humanize(d.gender), 'wc'], ['Date of Birth', formatDate(d.dateOfBirth), 'cake'], ['Guardian', d.guardianName, 'family_restroom'], ['Phone', d.phone, 'call'], ['Email', d.email, 'mail']]} /></Card>}
            {tab === 'academics' && <Card padded={false}><div className="p-s5 pb-s3"><CardHeader title="Academic history" icon="grading" className="mb-0" /></div><ul className="divide-y divide-outline-variant/50">{(d.academicHistory ?? []).map((h, i) => (<li key={i} className="flex items-center gap-s3 px-s5 py-s3"><Text variant="label-lg" className="flex-1 text-on-surface">{h.term}</Text><Text variant="body-md" className="ak-tabular text-on-surface">{h.percentage}</Text>{h.rank && <StatusChip status="info" label={`Rank ${h.rank}`} icon={false} />}</li>))}{(!d.academicHistory || d.academicHistory.length === 0) && <li className="px-s5 py-s6 text-center ak-body-md text-on-surface-variant">No academic history yet.</li>}</ul></Card>}
            {tab === 'fees' && <Card><CardHeader title="Fee summary" icon="account_balance_wallet" />{d.feeAccount ? <KV items={[['Total due', d.feeAccount.totalDue, 'request_quote'], ['Paid', d.feeAccount.totalPaid, 'check_circle'], ['Balance', d.feeAccount.balance, 'pending']]} /> : <Text variant="body-md" className="text-on-surface-variant">No fee account linked.</Text>}</Card>}
            {tab === 'attendance' && <Card><CardHeader title="Attendance" icon="fact_check" />{d.attendance ? <KV items={[['Present %', `${d.attendance.percentPresent}%`, 'trending_up'], ['Present', String(d.attendance.present), 'check_circle'], ['Total days', String(d.attendance.total), 'calendar_today']]} /> : <Text variant="body-md" className="text-on-surface-variant">No attendance summary.</Text>}</Card>}
            {tab === 'documents' && <Card padded={false}><div className="p-s5 pb-s3"><CardHeader title="Documents" icon="folder_open" className="mb-0" /></div><ul className="divide-y divide-outline-variant/50">{(d.documents ?? []).map((doc, i) => (<li key={i} className="flex items-center gap-s3 px-s5 py-s3"><Icon name="description" size={18} className="text-on-surface-variant" /><Text variant="body-md" className="flex-1 text-on-surface">{doc.name}</Text><StatusChip status={doc.status === 'verified' ? 'success' : 'warning'} label={humanize(doc.status)} icon={false} /></li>))}{(!d.documents || d.documents.length === 0) && <li className="px-s5 py-s6 text-center ak-body-md text-on-surface-variant">No documents on file.</li>}</ul></Card>}
          </div>
        )}
      </AsyncBoundary>
    </div>
  );
}

// ---- Generic record detail (collection, lead, receipt) ----
function RecordDetail<T extends object>({ title, icon, backLabel, backTo, endpoint, id, render }: { title: string; icon: string; backLabel: string; backTo: string; endpoint: string; id: string; render: (d: T) => ReactNode }) {
  const nav = useNavigate();
  const query = useModuleQuery<T>([endpoint, id], () => apiFetch<T>(`${endpoint}/${id}`), { enabled: !!id });
  return (
    <div className="space-y-s6">
      <PageHeader title={title} icon={icon} breadcrumbs={[{ label: backLabel, onClick: () => nav(backTo) }, { label: 'Detail' }]} />
      <AsyncBoundary query={query} unavailableTitle={`${title} is ready`} unavailableMessage={`Details load from ${endpoint}/{id} once connected.`}>
        {(d) => <>{render(d)}</>}
      </AsyncBoundary>
    </div>
  );
}

interface CollectionDetail { receiptNumber: string; studentName: string; classLabel: string; admissionNumber: string; amount: string; mode: string; collectedAt: string; collectedBy: string; status: string; breakup?: { head: string; amount: string }[] }
export function CollectionDetailPage() {
  const { id = '' } = useParams();
  return <RecordDetail<CollectionDetail> title="Collection" icon="receipt_long" backLabel="Collections" backTo="/finance/collections" endpoint="/finance/collections" id={id}
    render={(d) => (
      <div className="space-y-s5">
        <Card><div className="flex items-center justify-between"><div><Text variant="title-md" className="text-on-surface">{d.studentName}</Text><Text variant="body-sm" className="ak-mono text-on-surface-variant">{d.receiptNumber} · {d.classLabel} · {d.admissionNumber}</Text></div><StatusChip status={d.status === 'completed' ? 'success' : 'warning'} label={humanize(d.status)} /></div></Card>
        <Card><CardHeader title="Payment" icon="payments" /><KV items={[['Amount', d.amount, 'payments'], ['Mode', humanize(d.mode), 'account_balance'], ['Collected', formatDateTime(d.collectedAt), 'schedule'], ['Collected by', d.collectedBy, 'person']]} /></Card>
        {d.breakup && d.breakup.length > 0 && <Card padded={false}><div className="p-s5 pb-s3"><CardHeader title="Fee breakup" icon="request_quote" className="mb-0" /></div><ul className="divide-y divide-outline-variant/50">{d.breakup.map((b, i) => (<li key={i} className="flex items-center gap-s3 px-s5 py-s3"><Text variant="body-md" className="flex-1 text-on-surface">{b.head}</Text><Text variant="body-md" className="ak-tabular text-on-surface">{b.amount}</Text></li>))}</ul></Card>}
      </div>
    )} />;
}

interface LeadDetail { studentName: string; parentName: string; classLabel: string; phone: string; source: string; campaign: string; stage: string; counselor: string; score: string; activity?: { type: string; note: string; at: string }[] }
export function LeadDetailPage() {
  const { id = '' } = useParams();
  return <RecordDetail<LeadDetail> title="Lead" icon="how_to_reg" backLabel="Leads" backTo="/admissions/leads" endpoint="/admissions/leads" id={id}
    render={(d) => (
      <div className="space-y-s5">
        <Card><div className="flex items-center gap-s3"><Avatar name={d.studentName} size={52} /><div className="min-w-0"><Text variant="title-md" className="text-on-surface">{d.studentName}</Text><Text variant="body-sm" className="text-on-surface-variant">Parent: {d.parentName} · {d.classLabel}</Text></div><div className="ml-auto flex flex-col items-end gap-s1"><StatusChip status="pending" label={humanize(d.stage)} icon={false} /><StatusChip status="error" label={humanize(d.score)} icon="local_fire_department" /></div></div></Card>
        <Card><CardHeader title="Lead details" icon="info" /><KV items={[['Phone', d.phone, 'call'], ['Source', humanize(d.source), 'campaign'], ['Campaign', d.campaign, 'ads_click'], ['Counselor', d.counselor || 'Unassigned', 'support_agent']]} /></Card>
        <Card padded={false}><div className="p-s5 pb-s3"><CardHeader title="Activity" icon="history" className="mb-0" /></div><ul className="divide-y divide-outline-variant/50">{(d.activity ?? []).map((a, i) => (<li key={i} className="flex items-start gap-s3 px-s5 py-s3"><Icon name="fiber_manual_record" size={12} className="mt-[6px] text-primary" /><div className="min-w-0 flex-1"><Text variant="label-lg" className="text-on-surface">{humanize(a.type)}</Text><Text variant="body-sm" className="text-on-surface-variant">{a.note}</Text></div><Text variant="body-sm" className="text-on-surface-variant">{formatDate(a.at)}</Text></li>))}{(!d.activity || d.activity.length === 0) && <li className="px-s5 py-s6 text-center ak-body-md text-on-surface-variant">No activity logged.</li>}</ul></Card>
      </div>
    )} />;
}

interface ReceiptDetail { receiptNumber: string; amount: string; date: string; mode: string; items?: { head: string; amount: string }[] }
export function ReceiptDetailPage() {
  const { id = '' } = useParams();
  return <RecordDetail<ReceiptDetail> title="Receipt" icon="receipt_long" backLabel="Receipts" backTo="/parent/receipts" endpoint="/parent/receipts" id={id}
    render={(d) => (
      <Card className="mx-auto max-w-lg">
        <div className="border-b border-outline-variant/60 pb-s4 text-center"><Icon name="verified" size={32} className="text-success" /><Text variant="title-md" className="mt-s1 text-on-surface">Payment received</Text><Text variant="body-sm" className="ak-mono text-on-surface-variant">{d.receiptNumber}</Text></div>
        <div className="py-s4"><KV items={[['Amount', d.amount, 'payments'], ['Date', formatDate(d.date), 'calendar_today'], ['Mode', humanize(d.mode), 'account_balance']]} /></div>
        {d.items && d.items.length > 0 && <ul className="divide-y divide-outline-variant/50 border-t border-outline-variant/60">{d.items.map((it, i) => (<li key={i} className="flex items-center gap-s3 py-s3"><Text variant="body-md" className="flex-1 text-on-surface">{it.head}</Text><Text variant="body-md" className="ak-tabular text-on-surface">{it.amount}</Text></li>))}</ul>}
        <Button className="mt-s4" fullWidth variant="outlined" icon="download">Download PDF</Button>
      </Card>
    )} />;
}

// ---- Message thread / conversation ----
interface Thread { subject: string; participant: string; messages: { id: string; from: string; body: string; at: string; mine: boolean }[] }
export function ConversationPage({ base }: { base: string }) {
  const { id = '' } = useParams();
  const nav = useNavigate();
  const query = useModuleQuery(['thread', base, id], () => apiFetch<Thread>(`${base}/${id}`), { enabled: !!id });
  return (
    <div className="space-y-s6">
      <PageHeader title="Conversation" icon="forum" breadcrumbs={[{ label: 'Messages', onClick: () => nav(`${base}`.replace(/\/$/, '')) }, { label: 'Thread' }]} />
      <AsyncBoundary query={query} unavailableTitle="Conversation is ready" unavailableMessage={`The message thread loads from ${base}/{id} once connected.`}>
        {(d) => (
          <Card className="flex h-[60vh] flex-col">
            <CardHeader title={d.subject} subtitle={d.participant} icon="chat" />
            <div className="flex-1 space-y-s3 overflow-y-auto py-s2">
              {d.messages.map((m) => (
                <div key={m.id} className={m.mine ? 'flex justify-end' : 'flex justify-start'}>
                  <div className={`max-w-[75%] rounded-2xl px-s4 py-s2 ${m.mine ? 'bg-primary text-on-primary' : 'bg-surface-container text-on-surface'}`}>
                    <Text variant="body-md">{m.body}</Text>
                    <div className={`mt-s1 text-[11px] ${m.mine ? 'text-on-primary/70' : 'text-on-surface-variant'}`}>{formatDateTime(m.at)}</div>
                  </div>
                </div>
              ))}
            </div>
            <div className="flex items-center gap-s2 border-t border-outline-variant/60 pt-s3">
              <input className="h-11 flex-1 rounded-full border border-outline-variant bg-surface-low px-s4 ak-body-md outline-none focus:border-primary" placeholder="Type a message…" />
              <Button icon="send">Send</Button>
            </div>
          </Card>
        )}
      </AsyncBoundary>
    </div>
  );
}
export const TeacherConversationPage = () => <ConversationPage base="/teacher/messages" />;
export const ParentConversationPage = () => <ConversationPage base="/parent/messages" />;
