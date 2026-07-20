import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Avatar, StatusChip, type Column } from '@/components/ui';
import type { HrCandidate } from '@/lib/contracts/hr';
import { formatDate, humanize } from '@/lib/utils/format';
import { HR_STAGE, HR_TABS } from './shared';

const fetchCandidates = () => fetchList<HrCandidate>('/hr/recruitment', { query: { pageSize: 200 } });

export function HrRecruitmentPage() {
  const query = useModuleQuery<ListResult<HrCandidate>>(['hr', 'recruitment'], fetchCandidates);

  const columns: Column<HrCandidate>[] = [
    {
      key: 'candidateName',
      header: 'Candidate',
      sortValue: (r) => r.candidateName,
      render: (r) => (
        <div className="flex items-center gap-s3">
          <Avatar name={r.candidateName} size={36} />
          <span className="ak-label-lg text-on-surface">{r.candidateName}</span>
        </div>
      ),
    },
    { key: 'position', header: 'Position', sortValue: (r) => r.position },
    { key: 'source', header: 'Source', hideOnMobile: true, render: (r) => (r.source ? humanize(r.source) : '—') },
    { key: 'appliedOn', header: 'Applied', hideOnMobile: true, align: 'right', sortValue: (r) => r.appliedOn, render: (r) => formatDate(r.appliedOn) },
    { key: 'stage', header: 'Stage', align: 'right', render: (r) => <StatusChip {...HR_STAGE[r.stage]} icon={false} /> },
  ];

  return (
    <ResourceList
      title="Recruitment"
      subtitle="Candidate pipeline"
      icon="person_search"
      tabs={HR_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      search={{ placeholder: 'Search candidate or position…', match: (r, t) => r.candidateName.toLowerCase().includes(t) || r.position.toLowerCase().includes(t) }}
      filters={[
        { key: 'stage', placeholder: 'All stages', options: Object.entries(HR_STAGE).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.stage === v },
      ]}
      unavailableTitle="Recruitment is ready"
      unavailableMessage="The candidate pipeline loads here from /hr/recruitment once the backend is connected."
    />
  );
}
