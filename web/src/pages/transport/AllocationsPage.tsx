import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Button, type Column } from '@/components/ui';
import type { StudentTransportAllocation } from '@/lib/contracts/transport';
import { SHIFT_LABEL, TRANSPORT_TABS } from './shared';

const fetchAllocations = () => fetchList<StudentTransportAllocation>('/transport/allocations', { query: { pageSize: 200 } });

export function AllocationsPage() {
  const query = useModuleQuery<ListResult<StudentTransportAllocation>>(['transport', 'allocations'], fetchAllocations);

  const columns: Column<StudentTransportAllocation>[] = [
    {
      key: 'studentName',
      header: 'Student',
      sortValue: (r) => r.studentName,
      render: (r) => (
        <div className="min-w-0">
          <div className="truncate ak-label-lg text-on-surface">{r.studentName}</div>
          <div className="truncate text-[12px] text-on-surface-variant">{r.classLabel} · {r.admissionNumber}</div>
        </div>
      ),
    },
    { key: 'routeName', header: 'Route', sortValue: (r) => r.routeName },
    { key: 'pickupStop', header: 'Pickup', hideOnMobile: true },
    { key: 'dropStop', header: 'Drop', hideOnMobile: true },
    { key: 'busNumber', header: 'Bus', hideOnMobile: true },
    { key: 'shift', header: 'Shift', align: 'right', render: (r) => SHIFT_LABEL[r.shift] },
  ];

  return (
    <ResourceList
      title="Allocations"
      subtitle="Students assigned to routes"
      icon="hail"
      tabs={TRANSPORT_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      actions={<Button icon="add">Allocate students</Button>}
      search={{ placeholder: 'Search student…', match: (r, t) => r.studentName.toLowerCase().includes(t) }}
      unavailableTitle="Allocations are ready"
      unavailableMessage="Student route allocations load here from /transport/allocations once the backend is connected."
    />
  );
}
