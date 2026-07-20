import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Avatar, Button, StatusChip, type Column } from '@/components/ui';
import type { TransportDriver } from '@/lib/contracts/transport';
import { formatDate } from '@/lib/utils/format';
import { DRIVER_STATUS, TRANSPORT_TABS } from './shared';

const fetchDrivers = () => fetchList<TransportDriver>('/transport/drivers', { query: { pageSize: 200 } });

export function DriversPage() {
  const query = useModuleQuery<ListResult<TransportDriver>>(['transport', 'drivers'], fetchDrivers);

  const columns: Column<TransportDriver>[] = [
    {
      key: 'name',
      header: 'Driver',
      sortValue: (r) => r.name,
      render: (r) => (
        <div className="flex items-center gap-s3">
          <Avatar name={r.name} size={36} />
          <span className="ak-label-lg text-on-surface">{r.name}</span>
        </div>
      ),
    },
    { key: 'licenseNumber', header: 'License', hideOnMobile: true, render: (r) => <span className="ak-mono text-[13px]">{r.licenseNumber}</span> },
    { key: 'licenseExpiry', header: 'Expiry', hideOnMobile: true, render: (r) => formatDate(r.licenseExpiry) },
    { key: 'assignedBus', header: 'Bus', hideOnMobile: true },
    { key: 'phone', header: 'Phone', hideOnMobile: true, render: (r) => <span className="ak-mono text-[13px]">{r.phone}</span> },
    { key: 'rating', header: 'Rating', align: 'right', render: (r) => `★ ${r.rating}` },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...DRIVER_STATUS[r.status]} icon={false} /> },
  ];

  return (
    <ResourceList
      title="Drivers"
      subtitle="Driver roster and licenses"
      icon="badge"
      tabs={TRANSPORT_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      actions={<Button icon="person_add">Add driver</Button>}
      search={{ placeholder: 'Search driver…', match: (r, t) => r.name.toLowerCase().includes(t) }}
      filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(DRIVER_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
      unavailableTitle="Drivers are ready"
      unavailableMessage="The driver roster loads here from /transport/drivers once the backend is connected."
    />
  );
}
