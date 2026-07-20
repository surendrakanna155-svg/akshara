import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Avatar, StatusChip, type Column } from '@/components/ui';
import type { StudentFeeAccount } from '@/lib/contracts/finance';
import { ACCOUNT_STATUS, FINANCE_TABS } from './shared';

const fetchAccounts = () => fetchList<StudentFeeAccount>('/finance/student-accounts', { query: { pageSize: 200 } });

export function StudentAccountsPage() {
  const query = useModuleQuery<ListResult<StudentFeeAccount>>(['finance', 'accounts'], fetchAccounts);

  const columns: Column<StudentFeeAccount>[] = [
    {
      key: 'studentName',
      header: 'Student',
      sortValue: (r) => r.studentName,
      render: (r) => (
        <div className="flex items-center gap-s3">
          <Avatar name={r.studentName} size={36} />
          <div className="min-w-0">
            <div className="truncate ak-label-lg text-on-surface">{r.studentName}</div>
            <div className="truncate text-[12px] text-on-surface-variant">{r.classLabel} · {r.admissionNumber}</div>
          </div>
        </div>
      ),
    },
    { key: 'feeStructureName', header: 'Fee plan', hideOnMobile: true },
    { key: 'totalDue', header: 'Due', align: 'right', hideOnMobile: true, render: (r) => <span className="ak-tabular">{r.totalDue}</span> },
    { key: 'totalPaid', header: 'Paid', align: 'right', hideOnMobile: true, render: (r) => <span className="ak-tabular">{r.totalPaid}</span> },
    { key: 'balance', header: 'Balance', align: 'right', render: (r) => <span className="ak-tabular font-semibold text-on-surface">{r.balance}</span> },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...ACCOUNT_STATUS[r.status]} icon={false} /> },
  ];

  return (
    <ResourceList
      title="Student accounts"
      subtitle="Fee ledger per student"
      icon="account_balance_wallet"
      tabs={FINANCE_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      search={{ placeholder: 'Search student or admission no…', match: (r, t) => r.studentName.toLowerCase().includes(t) || r.admissionNumber.toLowerCase().includes(t) }}
      filters={[
        { key: 'status', placeholder: 'All statuses', options: Object.entries(ACCOUNT_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v },
      ]}
      unavailableTitle="Student accounts are ready"
      unavailableMessage="Per-student fee ledgers load here from /finance/student-accounts once the backend is connected."
    />
  );
}
