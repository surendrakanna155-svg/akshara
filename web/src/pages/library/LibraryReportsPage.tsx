import { ReportsHub } from '@/components/system/ReportsHub';
import { LIBRARY_TABS } from './shared';

export function LibraryReportsPage() {
  return (
    <ReportsHub
      title="Library reports"
      subtitle="Circulation and inventory"
      icon="summarize"
      tabs={LIBRARY_TABS}
      reports={[
        { key: 'circulation', title: 'Circulation', description: 'Issues, returns and turnover over a period.', icon: 'import_contacts' },
        { key: 'overdue', title: 'Overdue & fines', description: 'Outstanding loans and fine collection.', icon: 'running_with_errors', endpoint: '/library/overdue' },
        { key: 'inventory', title: 'Inventory', description: 'Stock, availability and damaged copies.', icon: 'inventory_2' },
        { key: 'popular', title: 'Popular titles', description: 'Most-issued books and categories.', icon: 'star' },
        { key: 'members', title: 'Member activity', description: 'Active borrowers and reading trends.', icon: 'groups' },
      ]}
    />
  );
}
