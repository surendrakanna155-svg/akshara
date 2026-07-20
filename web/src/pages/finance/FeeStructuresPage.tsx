import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Button, StatusChip, type Column } from '@/components/ui';
import type { FinanceFeeStructure } from '@/lib/contracts/finance';
import { FINANCE_TABS } from './shared';

const fetchStructures = () => fetchList<FinanceFeeStructure>('/finance/fee-structures', { query: { pageSize: 200 } });

export function FeeStructuresPage() {
  const query = useModuleQuery<ListResult<FinanceFeeStructure>>(['finance', 'fee-structures'], fetchStructures);

  const columns: Column<FinanceFeeStructure>[] = [
    { key: 'name', header: 'Structure', sortValue: (r) => r.name, render: (r) => <span className="ak-label-lg text-on-surface">{r.name}</span> },
    { key: 'classRange', header: 'Classes', hideOnMobile: true },
    { key: 'academicYear', header: 'Year', hideOnMobile: true },
    { key: 'categories', header: 'Heads', hideOnMobile: true, render: (r) => `${r.categories.length}` },
    { key: 'totalAnnual', header: 'Annual', align: 'right', render: (r) => <span className="ak-tabular font-semibold text-on-surface">{r.totalAnnual}</span> },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={r.status === 'active' ? 'success' : 'neutral'} label={r.status === 'active' ? 'Active' : 'Inactive'} icon={false} /> },
  ];

  return (
    <ResourceList
      title="Fee structures"
      subtitle="Annual fee plans by class"
      icon="request_quote"
      tabs={FINANCE_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      actions={<Button icon="add">New structure</Button>}
      search={{ placeholder: 'Search structure…', match: (r, t) => r.name.toLowerCase().includes(t) }}
      unavailableTitle="Fee structures are ready"
      unavailableMessage="Fee plans load here from /finance/fee-structures once the backend is connected."
    />
  );
}
