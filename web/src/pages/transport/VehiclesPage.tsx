import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Button, StatusChip, type Column } from '@/components/ui';
import type { TransportVehicle } from '@/lib/contracts/transport';
import { formatDate } from '@/lib/utils/format';
import { TRANSPORT_TABS, VEHICLE_STATUS } from './shared';

const fetchVehicles = () => fetchList<TransportVehicle>('/transport/vehicles', { query: { pageSize: 200 } });

export function VehiclesPage() {
  const query = useModuleQuery<ListResult<TransportVehicle>>(['transport', 'vehicles'], fetchVehicles);

  const columns: Column<TransportVehicle>[] = [
    {
      key: 'busNumber',
      header: 'Bus',
      sortValue: (r) => r.busNumber,
      render: (r) => (
        <div className="min-w-0">
          <div className="truncate ak-label-lg text-on-surface">{r.busNumber}</div>
          <div className="truncate ak-mono text-[12px] text-on-surface-variant">{r.registration}</div>
        </div>
      ),
    },
    { key: 'model', header: 'Model', hideOnMobile: true },
    { key: 'capacity', header: 'Capacity', align: 'right', sortValue: (r) => r.capacity },
    { key: 'occupancyPercent', header: 'Occupancy', align: 'right', hideOnMobile: true, sortValue: (r) => r.occupancyPercent, render: (r) => `${r.occupancyPercent}%` },
    { key: 'insuranceExpiry', header: 'Insurance', hideOnMobile: true, align: 'right', render: (r) => formatDate(r.insuranceExpiry) },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...VEHICLE_STATUS[r.status]} icon={false} /> },
  ];

  return (
    <ResourceList
      title="Vehicles"
      subtitle="Fleet and compliance"
      icon="directions_bus"
      tabs={TRANSPORT_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      actions={<Button icon="add">Add vehicle</Button>}
      search={{ placeholder: 'Search bus or registration…', match: (r, t) => r.busNumber.toLowerCase().includes(t) || r.registration.toLowerCase().includes(t) }}
      filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(VEHICLE_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
      unavailableTitle="Vehicles are ready"
      unavailableMessage="The fleet register loads here from /transport/vehicles once the backend is connected."
    />
  );
}
