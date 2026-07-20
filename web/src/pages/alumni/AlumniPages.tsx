import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';
import { fetchList, type ListResult } from '@/lib/api/list';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { ResourceList } from '@/components/system/ResourceList';
import { ReportsHub } from '@/components/system/ReportsHub';
import { ModuleSettingsPage } from '@/components/system/ModuleSettingsPage';
import { Avatar, Button, Drawer, KpiCard, PageHeader, StatGrid, StatusChip, Text, type Column, type SemanticStatus } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { ModuleTabs } from '@/components/shell/ModuleTabs';
import { humanize } from '@/lib/utils/format';
import { MODULE_TABS } from '@/routes/navConfig';
import type {
  AlumniCampaign,
  AlumniCampaignStatus,
  AlumniDashboardData,
  AlumniDonation,
  AlumniDonationStatus,
  AlumniEngagementStatus,
  AlumniEvent,
  AlumniEventStatus,
  AlumniRecord,
  MentorshipPair,
  MentorshipStatus,
} from '@/lib/contracts/alumni';

const TABS = MODULE_TABS.alumni;

const ENGAGEMENT: Record<AlumniEngagementStatus, { status: SemanticStatus; label: string }> = {
  active: { status: 'success', label: 'Active' }, inactive: { status: 'neutral', label: 'Inactive' }, pending: { status: 'warning', label: 'Pending' },
};
const EVENT_STATUS: Record<AlumniEventStatus, { status: SemanticStatus; label: string }> = {
  upcoming: { status: 'info', label: 'Upcoming' }, ongoing: { status: 'pending', label: 'Ongoing' }, completed: { status: 'success', label: 'Completed' }, cancelled: { status: 'error', label: 'Cancelled' },
};
const DONATION_STATUS: Record<AlumniDonationStatus, { status: SemanticStatus; label: string }> = {
  received: { status: 'success', label: 'Received' }, pledged: { status: 'info', label: 'Pledged' }, pending: { status: 'warning', label: 'Pending' }, refunded: { status: 'error', label: 'Refunded' },
};
const CAMPAIGN_STATUS: Record<AlumniCampaignStatus, { status: SemanticStatus; label: string }> = {
  active: { status: 'success', label: 'Active' }, draft: { status: 'neutral', label: 'Draft' }, completed: { status: 'info', label: 'Completed' }, paused: { status: 'warning', label: 'Paused' },
};
const MENTOR_STATUS: Record<MentorshipStatus, { status: SemanticStatus; label: string }> = {
  active: { status: 'success', label: 'Active' }, pending: { status: 'warning', label: 'Pending' }, completed: { status: 'info', label: 'Completed' }, onHold: { status: 'neutral', label: 'On hold' },
};

export function AlumniDashboardPage() {
  const navigate = useNavigate();
  const query = useModuleQuery(['alumni', 'dashboard'], () => apiFetch<AlumniDashboardData>('/alumni/dashboard'));
  const ICONS = ['diversity_3', 'volunteer_activism', 'event', 'handshake'];
  return (
    <div className="space-y-s6">
      <PageHeader title="Alumni" subtitle="Community & giving overview" icon="diversity_3" tabs={<ModuleTabs tabs={TABS} />}
        actions={<Button variant="outlined" icon="groups" onClick={() => navigate('/alumni/registry')}>Registry</Button>} />
      <AsyncBoundary query={query} unavailableTitle="Alumni overview is ready" unavailableMessage="Engagement and giving KPIs load here from /alumni/dashboard once the backend is connected.">
        {(d) => <StatGrid>{d.kpis.map((k, i) => <KpiCard key={k.id} label={k.label} value={k.value} icon={ICONS[i % ICONS.length]} delta={k.delta} />)}</StatGrid>}
      </AsyncBoundary>
    </div>
  );
}

export function RegistryPage() {
  const query = useModuleQuery<ListResult<AlumniRecord>>(['alumni', 'registry'], () => fetchList('/alumni/registry', { query: { pageSize: 300 } }));
  const [selected, setSelected] = useState<AlumniRecord | null>(null);
  const columns: Column<AlumniRecord>[] = [
    { key: 'name', header: 'Alumnus', sortValue: (r) => r.name, render: (r) => (
      <div className="flex items-center gap-s3"><Avatar name={r.name} size={36} /><div className="min-w-0"><div className="truncate ak-label-lg text-on-surface">{r.name}</div><div className="text-[12px] text-on-surface-variant">Batch {r.batchYear} · {r.program}</div></div></div>
    ) },
    { key: 'currentRole', header: 'Current role', hideOnMobile: true },
    { key: 'city', header: 'City', hideOnMobile: true },
    { key: 'totalDonated', header: 'Donated', align: 'right', hideOnMobile: true, render: (r) => <span className="ak-tabular">{r.totalDonated}</span> },
    { key: 'engagementStatus', header: 'Engagement', align: 'right', render: (r) => <StatusChip {...ENGAGEMENT[r.engagementStatus]} icon={false} /> },
  ];
  return (
    <ResourceList title="Alumni registry" subtitle="Alumni directory" icon="groups" tabs={TABS} query={query} columns={columns} rowKey={(r) => r.id} onRowClick={setSelected}
      actions={<Button icon="person_add">Add alumnus</Button>}
      search={{ placeholder: 'Search name, batch, city…', match: (r, t) => r.name.toLowerCase().includes(t) || r.batchYear.includes(t) || r.city.toLowerCase().includes(t) }}
      filters={[{ key: 'engagementStatus', placeholder: 'All engagement', width: 'w-44', options: Object.entries(ENGAGEMENT).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.engagementStatus === v }]}
      unavailableTitle="Alumni registry is ready" unavailableMessage="The alumni directory loads here from /alumni/registry once the backend is connected.">
      <Drawer open={!!selected} onClose={() => setSelected(null)} title={selected?.name} subtitle={selected ? `Batch ${selected.batchYear} · ${selected.program}` : undefined}
        footer={<><Button variant="outlined" onClick={() => setSelected(null)}>Close</Button><Button icon="mail">Contact</Button></>}>
        {selected && (
          <div className="space-y-s5">
            <div className="flex items-center gap-s3"><Avatar name={selected.name} size={56} /><div><Text variant="title-md">{selected.name}</Text><Text variant="body-sm" className="text-on-surface-variant">{selected.currentRole}</Text></div><div className="ml-auto"><StatusChip {...ENGAGEMENT[selected.engagementStatus]} /></div></div>
            <dl className="grid grid-cols-2 gap-s4">
              {[['City', selected.city, 'location_city'], ['Email', selected.email, 'mail'], ['Phone', selected.phone, 'call'], ['Total donated', selected.totalDonated, 'volunteer_activism'], ['Last event', selected.lastEventAttended || '—', 'event']].map(([label, value, icon]) => (
                <div key={label} className="flex items-start gap-s2"><Icon name={icon} size={18} className="mt-[2px] text-on-surface-variant" /><div className="min-w-0"><Text variant="label-md" className="text-on-surface-variant">{label}</Text><Text variant="body-md" className="truncate text-on-surface">{value || '—'}</Text></div></div>
              ))}
            </dl>
          </div>
        )}
      </Drawer>
    </ResourceList>
  );
}

export function CampaignsPage() {
  const query = useModuleQuery<ListResult<AlumniCampaign>>(['alumni', 'campaigns'], () => fetchList('/alumni/campaigns', { query: { pageSize: 200 } }));
  const columns: Column<AlumniCampaign>[] = [
    { key: 'name', header: 'Campaign', sortValue: (r) => r.name, render: (r) => <span className="ak-label-lg text-on-surface">{r.name}</span> },
    { key: 'goalAmount', header: 'Goal', align: 'right', hideOnMobile: true, render: (r) => <span className="ak-tabular">{r.goalAmount}</span> },
    { key: 'raisedAmount', header: 'Raised', align: 'right', render: (r) => <span className="ak-tabular font-semibold text-on-surface">{r.raisedAmount}</span> },
    { key: 'donorCount', header: 'Donors', align: 'right', sortValue: (r) => r.donorCount },
    { key: 'deadline', header: 'Deadline', hideOnMobile: true, align: 'right' },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...CAMPAIGN_STATUS[r.status]} icon={false} /> },
  ];
  return <ResourceList title="Campaigns" subtitle="Fundraising campaigns" icon="campaign" tabs={TABS} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">New campaign</Button>} search={{ placeholder: 'Search campaign…', match: (r, t) => r.name.toLowerCase().includes(t) }}
    filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(CAMPAIGN_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
    unavailableTitle="Campaigns are ready" unavailableMessage="Fundraising campaigns load here from /alumni/campaigns once the backend is connected." />;
}

export function DonationsPage() {
  const query = useModuleQuery<ListResult<AlumniDonation>>(['alumni', 'donations'], () => fetchList('/alumni/donations', { query: { pageSize: 300 } }));
  const columns: Column<AlumniDonation>[] = [
    { key: 'alumniName', header: 'Donor', sortValue: (r) => r.alumniName, render: (r) => <span className="ak-label-lg text-on-surface">{r.alumniName}</span> },
    { key: 'campaign', header: 'Campaign', hideOnMobile: true },
    { key: 'paymentMode', header: 'Mode', hideOnMobile: true },
    { key: 'date', header: 'Date', hideOnMobile: true },
    { key: 'amount', header: 'Amount', align: 'right', render: (r) => <span className="ak-tabular font-semibold text-on-surface">{r.amount}</span> },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...DONATION_STATUS[r.status]} icon={false} /> },
  ];
  return <ResourceList title="Donations" subtitle="Gifts & pledges" icon="volunteer_activism" tabs={TABS} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">Record donation</Button>} search={{ placeholder: 'Search donor…', match: (r, t) => r.alumniName.toLowerCase().includes(t) }}
    filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(DONATION_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
    unavailableTitle="Donations are ready" unavailableMessage="Donations load here from /alumni/donations once the backend is connected." />;
}

export function EventsPage() {
  const query = useModuleQuery<ListResult<AlumniEvent>>(['alumni', 'events'], () => fetchList('/alumni/events', { query: { pageSize: 200 } }));
  const columns: Column<AlumniEvent>[] = [
    { key: 'title', header: 'Event', sortValue: (r) => r.title, render: (r) => <span className="ak-label-lg text-on-surface">{r.title}</span> },
    { key: 'date', header: 'Date', hideOnMobile: true },
    { key: 'venue', header: 'Venue', hideOnMobile: true },
    { key: 'registrations', header: 'Registered', align: 'right', render: (r) => `${r.registrations}/${r.capacity}` },
    { key: 'organizer', header: 'Organizer', hideOnMobile: true },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...EVENT_STATUS[r.status]} icon={false} /> },
  ];
  return <ResourceList title="Events" subtitle="Alumni events & reunions" icon="event" tabs={TABS} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">Create event</Button>} search={{ placeholder: 'Search event…', match: (r, t) => r.title.toLowerCase().includes(t) }}
    filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(EVENT_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
    unavailableTitle="Events are ready" unavailableMessage="Alumni events load here from /alumni/events once the backend is connected." />;
}

export function MentorshipPage() {
  const query = useModuleQuery<ListResult<MentorshipPair>>(['alumni', 'mentorship'], () => fetchList('/alumni/mentorship', { query: { pageSize: 300 } }));
  const columns: Column<MentorshipPair>[] = [
    { key: 'mentorName', header: 'Mentor', sortValue: (r) => r.mentorName, render: (r) => <span className="ak-label-lg text-on-surface">{r.mentorName}</span> },
    { key: 'menteeName', header: 'Mentee', sortValue: (r) => r.menteeName },
    { key: 'focusArea', header: 'Focus', hideOnMobile: true, render: (r) => humanize(r.focusArea) },
    { key: 'startedDate', header: 'Since', hideOnMobile: true, align: 'right' },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...MENTOR_STATUS[r.status]} icon={false} /> },
  ];
  return <ResourceList title="Mentorship" subtitle="Alumni–student mentorship" icon="handshake" tabs={TABS} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">New pairing</Button>} search={{ placeholder: 'Search mentor or mentee…', match: (r, t) => r.mentorName.toLowerCase().includes(t) || r.menteeName.toLowerCase().includes(t) }}
    filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(MENTOR_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
    unavailableTitle="Mentorship is ready" unavailableMessage="Mentorship pairings load here from /alumni/mentorship once the backend is connected." />;
}

export function AlumniReportsPage() {
  return <ReportsHub title="Alumni reports" subtitle="Engagement and giving" icon="summarize" tabs={TABS}
    reports={[
      { key: 'giving', title: 'Giving summary', description: 'Donations by campaign, batch and period.', icon: 'volunteer_activism' },
      { key: 'engagement', title: 'Engagement', description: 'Event attendance and active alumni.', icon: 'diversity_3' },
      { key: 'batch', title: 'Batch analytics', description: 'Alumni distribution and outcomes by batch.', icon: 'school' },
      { key: 'mentorship', title: 'Mentorship impact', description: 'Active pairings and outcomes.', icon: 'handshake' },
    ]} />;
}

export function AlumniSettingsPage() {
  return <ModuleSettingsPage title="Alumni settings" subtitle="Configure the alumni programme" endpoint="/alumni/settings" tabs={TABS} />;
}
