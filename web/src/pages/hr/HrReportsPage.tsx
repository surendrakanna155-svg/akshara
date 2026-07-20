import { ReportsHub } from '@/components/system/ReportsHub';
import { HR_TABS } from './shared';

export function HrReportsPage() {
  return (
    <ReportsHub
      title="HR reports"
      subtitle="Workforce and payroll insights"
      icon="summarize"
      tabs={HR_TABS}
      reports={[
        { key: 'headcount', title: 'Headcount', description: 'Employees by department, role and status.', icon: 'groups', endpoint: '/hr/reports/headcount' },
        { key: 'attendance', title: 'Attendance summary', description: 'Present / absent / late trends over a period.', icon: 'fact_check' },
        { key: 'leave', title: 'Leave balances', description: 'Accrued and consumed leave per employee.', icon: 'event_busy', endpoint: '/hr/leave/balances' },
        { key: 'payroll', title: 'Payroll register', description: 'Salary register for a pay period.', icon: 'payments', endpoint: '/hr/payroll/register' },
        { key: 'payslips', title: 'Payslips', description: 'Generate and export employee payslips.', icon: 'receipt_long', endpoint: '/hr/payroll/payslips' },
        { key: 'documents', title: 'Expiring documents', description: 'Staff documents nearing expiry.', icon: 'folder_open', endpoint: '/hr/documents/expiring' },
        { key: 'probation', title: 'Probation ending', description: 'Employees whose probation ends soon.', icon: 'schedule', endpoint: '/hr/probation/ending' },
      ]}
    />
  );
}
