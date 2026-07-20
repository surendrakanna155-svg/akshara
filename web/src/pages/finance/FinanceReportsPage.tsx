import { ReportsHub } from '@/components/system/ReportsHub';
import { FINANCE_TABS } from './shared';

export function FinanceReportsPage() {
  return (
    <ReportsHub
      title="Finance reports"
      subtitle="Collection, dues and audit reports"
      icon="summarize"
      tabs={FINANCE_TABS}
      reports={[
        { key: 'daily', title: 'Daily collection', description: 'Day-wise collection with mode split and day-close status.', icon: 'today', endpoint: '/finance/collections/daily-summary' },
        { key: 'dues', title: 'Outstanding dues', description: 'Head-wise and class-wise pending fees.', icon: 'account_balance_wallet', endpoint: '/finance/analytics/head-wise-dues' },
        { key: 'defaulters', title: 'Defaulter aging', description: 'Overdue accounts bucketed by aging.', icon: 'person_alert', endpoint: '/finance/defaulters' },
        { key: 'refunds', title: 'Refunds & cancellations', description: 'Refunds, cancellations and their approvals.', icon: 'undo', endpoint: '/finance/refunds' },
        { key: 'discounts', title: 'Discounts & scholarships', description: 'Concessions granted and their fee impact.', icon: 'loyalty', endpoint: '/finance/discounts' },
        { key: 'reconciliation', title: 'Reconciliation', description: 'Offline payment and bank reconciliation status.', icon: 'fact_check', endpoint: '/finance/reports' },
      ]}
    />
  );
}
