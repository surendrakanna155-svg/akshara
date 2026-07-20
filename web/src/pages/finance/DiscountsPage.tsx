import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Button, StatusChip, type Column } from '@/components/ui';
import type { StudentDiscountAssignment } from '@/lib/contracts/finance';
import { DISCOUNT_STATUS, FINANCE_TABS } from './shared';

const fetchDiscounts = () => fetchList<StudentDiscountAssignment>('/finance/discounts', { query: { pageSize: 200 } });

export function DiscountsPage() {
  const query = useModuleQuery<ListResult<StudentDiscountAssignment>>(['finance', 'discounts'], fetchDiscounts);

  const columns: Column<StudentDiscountAssignment>[] = [
    { key: 'studentName', header: 'Student', sortValue: (r) => r.studentName, render: (r) => <span className="ak-label-lg text-on-surface">{r.studentName}</span> },
    { key: 'scholarshipName', header: 'Scholarship / discount', sortValue: (r) => r.scholarshipName },
    { key: 'impactOnFees', header: 'Impact', hideOnMobile: true },
    { key: 'discountAmount', header: 'Amount', align: 'right', render: (r) => <span className="ak-tabular font-semibold text-on-surface">{r.discountAmount}</span> },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...DISCOUNT_STATUS[r.status]} icon={false} /> },
  ];

  return (
    <ResourceList
      title="Discounts & scholarships"
      subtitle="Fee concessions — maker/checker"
      icon="loyalty"
      tabs={FINANCE_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      actions={<Button icon="add">Assign discount</Button>}
      search={{ placeholder: 'Search student…', match: (r, t) => r.studentName.toLowerCase().includes(t) }}
      filters={[
        { key: 'status', placeholder: 'All statuses', options: Object.entries(DISCOUNT_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v },
      ]}
      unavailableTitle="Discounts are ready"
      unavailableMessage="Fee concessions load here from /finance/discounts once the backend is connected."
    />
  );
}
