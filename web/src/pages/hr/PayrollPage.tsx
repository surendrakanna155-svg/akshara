import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Button, StatusChip, type Column } from '@/components/ui';
import type { HrPayrollEntry } from '@/lib/contracts/hr';
import { humanize } from '@/lib/utils/format';
import { HR_DEPARTMENTS, HR_PAYROLL_STATUS, HR_TABS } from './shared';

const fetchPayroll = () => fetchList<HrPayrollEntry>('/hr/payroll', { query: { pageSize: 200 } });

export function HrPayrollPage() {
  const query = useModuleQuery<ListResult<HrPayrollEntry>>(['hr', 'payroll'], fetchPayroll);

  const columns: Column<HrPayrollEntry>[] = [
    { key: 'employeeName', header: 'Employee', sortValue: (r) => r.employeeName, render: (r) => <span className="ak-label-lg text-on-surface">{r.employeeName}</span> },
    { key: 'department', header: 'Department', hideOnMobile: true, render: (r) => humanize(r.department) },
    { key: 'basicPay', header: 'Basic', align: 'right', hideOnMobile: true, render: (r) => <span className="ak-tabular">{r.basicPay}</span> },
    { key: 'allowances', header: 'Allowances', align: 'right', hideOnMobile: true, render: (r) => <span className="ak-tabular">{r.allowances}</span> },
    { key: 'deductions', header: 'Deductions', align: 'right', hideOnMobile: true, render: (r) => <span className="ak-tabular">{r.deductions}</span> },
    { key: 'netPay', header: 'Net pay', align: 'right', render: (r) => <span className="ak-tabular font-semibold text-on-surface">{r.netPay}</span> },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...HR_PAYROLL_STATUS[r.status]} icon={false} /> },
  ];

  return (
    <ResourceList
      title="Payroll"
      subtitle="Monthly salary register"
      icon="payments"
      tabs={HR_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      search={{ placeholder: 'Search employee…', match: (r, t) => r.employeeName.toLowerCase().includes(t) }}
      filters={[
        { key: 'department', placeholder: 'All departments', width: 'w-44', options: HR_DEPARTMENTS.map((d) => ({ value: d, label: humanize(d) })), match: (r, v) => r.department === v },
        { key: 'status', placeholder: 'All statuses', options: Object.entries(HR_PAYROLL_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v },
      ]}
      actions={
        <Button icon="play_circle" disabled>
          Run payroll
        </Button>
      }
      unavailableTitle="Payroll is ready"
      unavailableMessage="The salary register loads here from /hr/payroll once the backend is connected. Payroll runs post to /hr/payroll/run."
    />
  );
}
