import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Avatar, Button, StatusChip, type Column } from '@/components/ui';
import type { AdmissionsEnrollmentPending } from '@/lib/contracts/admissions';
import { humanize } from '@/lib/utils/format';
import { ADMISSIONS_TABS } from './shared';

const fetchPending = () => fetchList<AdmissionsEnrollmentPending>('/admissions/enrollments/pending', { query: { pageSize: 200 } });

export function EnrollmentPage() {
  const query = useModuleQuery<ListResult<AdmissionsEnrollmentPending>>(['admissions', 'enrollment'], fetchPending);

  const columns: Column<AdmissionsEnrollmentPending>[] = [
    {
      key: 'studentName',
      header: 'Student',
      sortValue: (r) => r.studentName,
      render: (r) => (
        <div className="flex items-center gap-s3">
          <Avatar name={r.studentName} size={36} />
          <span className="ak-label-lg text-on-surface">{r.studentName}</span>
        </div>
      ),
    },
    { key: 'classLabel', header: 'Class', sortValue: (r) => r.classLabel },
    { key: 'guardianName', header: 'Guardian', hideOnMobile: true },
    { key: 'phone', header: 'Phone', hideOnMobile: true, render: (r) => <span className="ak-mono text-[13px]">{r.phone}</span> },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status="pending" label={humanize(r.status)} icon={false} /> },
  ];

  return (
    <ResourceList
      title="Enrolment"
      subtitle="Approved applicants pending enrolment"
      icon="assignment_turned_in"
      tabs={ADMISSIONS_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      search={{ placeholder: 'Search student or guardian…', match: (r, t) => r.studentName.toLowerCase().includes(t) || r.guardianName.toLowerCase().includes(t) }}
      unavailableTitle="Enrolment hand-off is ready"
      unavailableMessage="Approved applicants awaiting enrolment load here from /admissions/enrollments/pending once the backend is connected."
      emptyTitle="No pending enrolments"
      emptyIcon="how_to_reg"
    >
      <div className="flex justify-end">
        <Button icon="account_balance" variant="outlined" disabled>
          Hand off to Finance
        </Button>
      </div>
    </ResourceList>
  );
}
