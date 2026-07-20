import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { StatusChip, type Column } from '@/components/ui';
import type { HrPerformanceReview } from '@/lib/contracts/hr';
import { formatDate, humanize } from '@/lib/utils/format';
import { HR_TABS } from './shared';

const fetchReviews = () => fetchList<HrPerformanceReview>('/hr/performance', { query: { pageSize: 200 } });

export function HrPerformancePage() {
  const query = useModuleQuery<ListResult<HrPerformanceReview>>(['hr', 'performance'], fetchReviews);

  const columns: Column<HrPerformanceReview>[] = [
    { key: 'employeeName', header: 'Employee', sortValue: (r) => r.employeeName, render: (r) => <span className="ak-label-lg text-on-surface">{r.employeeName}</span> },
    { key: 'department', header: 'Department', hideOnMobile: true, render: (r) => humanize(r.department) },
    { key: 'cycle', header: 'Cycle', render: (r) => r.cycle.toUpperCase() },
    { key: 'rating', header: 'Rating', align: 'right', render: (r) => r.rating || '—' },
    { key: 'reviewer', header: 'Reviewer', hideOnMobile: true, render: (r) => r.reviewer || '—' },
    { key: 'dueDate', header: 'Due', hideOnMobile: true, align: 'right', render: (r) => formatDate(r.dueDate) },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status="pending" label={humanize(r.status)} icon={false} /> },
  ];

  return (
    <ResourceList
      title="Performance"
      subtitle="Appraisal reviews"
      icon="workspace_premium"
      tabs={HR_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      search={{ placeholder: 'Search employee…', match: (r, t) => r.employeeName.toLowerCase().includes(t) }}
      filters={[
        { key: 'cycle', placeholder: 'All cycles', options: ['q1', 'q2', 'q3', 'annual'].map((c) => ({ value: c, label: c.toUpperCase() })), match: (r, v) => r.cycle === v },
      ]}
      unavailableTitle="Performance reviews are ready"
      unavailableMessage="Appraisal reviews load here from /hr/performance once the backend is connected."
    />
  );
}
