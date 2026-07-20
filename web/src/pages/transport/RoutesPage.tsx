import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Button, StatusChip, type Column } from '@/components/ui';
import type { TransportRoute } from '@/lib/contracts/transport';
import { ROUTE_STATUS, SHIFT_LABEL, TRANSPORT_TABS } from './shared';

const fetchRoutes = () => fetchList<TransportRoute>('/transport/routes', { query: { pageSize: 200 } });

export function RoutesPage() {
  const query = useModuleQuery<ListResult<TransportRoute>>(['transport', 'routes'], fetchRoutes);

  const columns: Column<TransportRoute>[] = [
    { key: 'name', header: 'Route', sortValue: (r) => r.name, render: (r) => <span className="ak-label-lg text-on-surface">{r.name}</span> },
    { key: 'stopCount', header: 'Stops', align: 'right', sortValue: (r) => r.stopCount },
    { key: 'distanceKm', header: 'Distance', hideOnMobile: true, align: 'right', render: (r) => `${r.distanceKm} km` },
    { key: 'assignedBus', header: 'Bus', hideOnMobile: true },
    { key: 'shift', header: 'Shift', hideOnMobile: true, render: (r) => SHIFT_LABEL[r.shift] },
    { key: 'studentCount', header: 'Students', align: 'right', sortValue: (r) => r.studentCount },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...ROUTE_STATUS[r.status]} icon={false} /> },
  ];

  return (
    <ResourceList
      title="Routes"
      subtitle="Bus routes and stops"
      icon="route"
      tabs={TRANSPORT_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      actions={<Button icon="add">New route</Button>}
      search={{ placeholder: 'Search route or bus…', match: (r, t) => r.name.toLowerCase().includes(t) || r.assignedBus.toLowerCase().includes(t) }}
      filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(ROUTE_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
      unavailableTitle="Routes are ready"
      unavailableMessage="Bus routes load here from /transport/routes once the backend is connected."
    />
  );
}
