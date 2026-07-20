import { useState } from 'react';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import {
  Avatar,
  Button,
  Card,
  DataTable,
  Drawer,
  Input,
  PageHeader,
  Select,
  StatusChip,
  Text,
  type Column,
  type SemanticStatus,
} from '@/components/ui';
import { Icon } from '@/components/Icon';
import { ModuleTabs } from '@/components/shell/ModuleTabs';
import type { AdmissionsLead, LeadScore, LeadStage } from '@/lib/contracts/admissions';
import { humanize } from '@/lib/utils/format';
import { ADMISSIONS_TABS } from './shared';

const STAGE_MAP: Record<LeadStage, SemanticStatus> = {
  newEnquiry: 'info',
  contacted: 'info',
  schoolVisit: 'pending',
  application: 'pending',
  admitted: 'success',
  enrolled: 'success',
  lost: 'error',
};

const SCORE_MAP: Record<LeadScore, { status: SemanticStatus; icon: string }> = {
  hot: { status: 'error', icon: 'local_fire_department' },
  warm: { status: 'warning', icon: 'wb_sunny' },
  cold: { status: 'info', icon: 'ac_unit' },
};

const STAGES: LeadStage[] = ['newEnquiry', 'contacted', 'schoolVisit', 'application', 'admitted', 'enrolled', 'lost'];

const fetchLeads = () => fetchList<AdmissionsLead>('/admissions/leads', { query: { pageSize: 200 } });

export function LeadsPage() {
  const query = useModuleQuery<ListResult<AdmissionsLead>>(['admissions', 'leads'], fetchLeads);
  const [search, setSearch] = useState('');
  const [stage, setStage] = useState('');
  const [score, setScore] = useState('');
  const [selected, setSelected] = useState<AdmissionsLead | null>(null);

  return (
    <div className="space-y-s6">
      <PageHeader
        title="Admission Leads"
        subtitle="Enquiry pipeline"
        icon="how_to_reg"
        tabs={<ModuleTabs tabs={ADMISSIONS_TABS} />}
        actions={
          <>
            <Button variant="outlined" icon="upload_file">
              Import
            </Button>
            <Button icon="add">New lead</Button>
          </>
        }
      />

      <AsyncBoundary
        query={query}
        unavailableTitle="Lead pipeline is ready"
        unavailableMessage="The enquiry pipeline — filterable by stage and score — loads here from /admissions/leads once the backend is connected."
      >
        {(data) => {
          const term = search.trim().toLowerCase();
          const rows = data.items.filter((l) => {
            if (stage && l.stage !== stage) return false;
            if (score && l.score !== score) return false;
            if (!term) return true;
            return (
              l.studentName.toLowerCase().includes(term) ||
              l.parentName.toLowerCase().includes(term) ||
              l.phone.toLowerCase().includes(term)
            );
          });

          const columns: Column<AdmissionsLead>[] = [
            {
              key: 'studentName',
              header: 'Student / Parent',
              sortValue: (r) => r.studentName,
              render: (r) => (
                <div className="flex items-center gap-s3">
                  <Avatar name={r.studentName} size={36} />
                  <div className="min-w-0">
                    <div className="truncate ak-label-lg text-on-surface">{r.studentName}</div>
                    <div className="truncate text-[12px] text-on-surface-variant">{r.parentName} · {r.phone}</div>
                  </div>
                </div>
              ),
            },
            { key: 'classLabel', header: 'Class', sortValue: (r) => r.classLabel },
            { key: 'source', header: 'Source', hideOnMobile: true, render: (r) => humanize(r.source) },
            { key: 'stage', header: 'Stage', render: (r) => <StatusChip status={STAGE_MAP[r.stage]} label={humanize(r.stage)} icon={false} /> },
            {
              key: 'score',
              header: 'Score',
              render: (r) => <StatusChip status={SCORE_MAP[r.score].status} label={humanize(r.score)} icon={SCORE_MAP[r.score].icon} />,
            },
            { key: 'counselor', header: 'Counselor', hideOnMobile: true, render: (r) => r.counselor || 'Unassigned' },
            { key: 'nextFollowUpLabel', header: 'Next follow-up', align: 'right', hideOnMobile: true, render: (r) => r.nextFollowUpLabel || '—' },
          ];

          return (
            <Card padded={false}>
              <div className="flex flex-wrap items-center gap-s2 border-b border-outline-variant/60 p-s4">
                <div className="min-w-[220px] flex-1">
                  <Input leadingIcon="search" placeholder="Search student, parent, phone…" value={search} onChange={(e) => setSearch(e.target.value)} />
                </div>
                <Select className="w-44" placeholder="All stages" value={stage} onChange={(e) => setStage(e.target.value)} options={STAGES.map((s) => ({ value: s, label: humanize(s) }))} />
                <Select className="w-36" placeholder="All scores" value={score} onChange={(e) => setScore(e.target.value)} options={(['hot', 'warm', 'cold'] as LeadScore[]).map((s) => ({ value: s, label: humanize(s) }))} />
                <Text variant="body-sm" className="ml-auto text-on-surface-variant">
                  {rows.length} of {data.total}
                </Text>
              </div>
              <DataTable columns={columns} rows={rows} rowKey={(r) => r.id} onRowClick={setSelected} emptyTitle="No leads match your filters" emptyIcon="person_search" />
            </Card>
          );
        }}
      </AsyncBoundary>

      <Drawer
        open={!!selected}
        onClose={() => setSelected(null)}
        title={selected?.studentName}
        subtitle={selected ? `Parent: ${selected.parentName}` : undefined}
        footer={
          <>
            <Button variant="outlined" icon="call">
              Log call
            </Button>
            <Button icon="trending_flat">Advance stage</Button>
          </>
        }
      >
        {selected && (
          <div className="space-y-s5">
            <div className="flex items-center gap-s3">
              <Avatar name={selected.studentName} size={56} />
              <div className="min-w-0">
                <Text variant="title-md">{selected.studentName}</Text>
                <Text variant="body-sm" className="text-on-surface-variant">
                  {selected.classLabel}
                </Text>
              </div>
              <div className="ml-auto flex flex-col items-end gap-s1">
                <StatusChip status={STAGE_MAP[selected.stage]} label={humanize(selected.stage)} icon={false} />
                <StatusChip status={SCORE_MAP[selected.score].status} label={humanize(selected.score)} icon={SCORE_MAP[selected.score].icon} />
              </div>
            </div>
            <dl className="grid grid-cols-2 gap-s4">
              {[
                ['Parent', selected.parentName, 'family_restroom'],
                ['Phone', selected.phone, 'call'],
                ['Source', humanize(selected.source), 'campaign'],
                ['Campaign', selected.campaign || '—', 'ads_click'],
                ['Counselor', selected.counselor || 'Unassigned', 'support_agent'],
                ['Next follow-up', selected.nextFollowUpLabel || '—', 'event'],
              ].map(([label, value, icon]) => (
                <div key={label} className="flex items-start gap-s2">
                  <Icon name={icon} size={18} className="mt-[2px] text-on-surface-variant" />
                  <div className="min-w-0">
                    <Text variant="label-md" className="text-on-surface-variant">
                      {label}
                    </Text>
                    <Text variant="body-md" className="truncate text-on-surface">
                      {value || '—'}
                    </Text>
                  </div>
                </div>
              ))}
            </dl>
          </div>
        )}
      </Drawer>
    </div>
  );
}
