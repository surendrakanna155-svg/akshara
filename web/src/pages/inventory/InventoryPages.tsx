import { useNavigate } from 'react-router-dom';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';
import { fetchList, type ListResult } from '@/lib/api/list';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { ResourceList } from '@/components/system/ResourceList';
import { ReportsHub } from '@/components/system/ReportsHub';
import { Button, Card, CardHeader, KpiCard, PageHeader, StatGrid, StatusChip, Text, type Column } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { ModuleTabs } from '@/components/shell/ModuleTabs';
import { humanize } from '@/lib/utils/format';
import type {
  InventoryAllocation,
  InventoryAsset,
  InventoryCategory,
  InventoryDashboardData,
  InventoryLifecycleItem,
  InventoryMaintenanceRecord,
  InventoryProcurementOrder,
  InventoryStockApproval,
  InventoryStockItem,
  InventoryVendor,
} from '@/lib/contracts/inventory';
import {
  ALLOCATION_STATUS,
  ASSET_STATUS,
  INVENTORY_TABS,
  MAINTENANCE_STATUS,
  PROCUREMENT_STATUS,
  VENDOR_STATUS,
} from './shared';

const ICONS = ['inventory_2', 'warning', 'shopping_cart', 'engineering'];

export function InventoryDashboardPage() {
  const navigate = useNavigate();
  const query = useModuleQuery(['inventory', 'dashboard'], () => apiFetch<InventoryDashboardData>('/inventory/dashboard'));
  return (
    <div className="space-y-s6">
      <PageHeader title="Inventory" subtitle="Assets, stock and procurement" icon="inventory_2" tabs={<ModuleTabs tabs={INVENTORY_TABS} />}
        actions={<Button variant="outlined" icon="category" onClick={() => navigate('/inventory/assets')}>Assets</Button>} />
      <AsyncBoundary query={query} unavailableTitle="Inventory overview is ready" unavailableMessage="Asset KPIs and stock alerts load here from /inventory/dashboard once the backend is connected.">
        {(d) => (
          <div className="space-y-s6">
            <StatGrid>{d.kpis.map((k, i) => <KpiCard key={k.id} label={k.label} value={k.value} icon={ICONS[i % ICONS.length]} delta={k.delta} />)}</StatGrid>
            {d.stockAlerts?.length > 0 && (
              <Card>
                <CardHeader title="Stock alerts" icon="warning" />
                <ul className="space-y-s2">
                  {d.stockAlerts.map((a) => (
                    <li key={a.id} className="flex items-center gap-s2 rounded-md bg-warning-container/50 px-s3 py-s2">
                      <Icon name="warning" size={18} className="text-warning" />
                      <Text variant="body-md" className="text-on-surface">{a.label}</Text>
                      <Text variant="body-sm" className="ml-auto text-on-surface-variant">{a.detail}</Text>
                    </li>
                  ))}
                </ul>
              </Card>
            )}
          </div>
        )}
      </AsyncBoundary>
    </div>
  );
}

export function AssetsPage() {
  const query = useModuleQuery<ListResult<InventoryAsset>>(['inventory', 'assets'], () => fetchList('/inventory/assets', { query: { pageSize: 300 } }));
  const columns: Column<InventoryAsset>[] = [
    { key: 'name', header: 'Asset', sortValue: (r) => r.name, render: (r) => (
      <div className="min-w-0"><div className="truncate ak-label-lg text-on-surface">{r.name}</div><div className="ak-mono text-[12px] text-on-surface-variant">{r.assetTag}</div></div>
    ) },
    { key: 'category', header: 'Category', hideOnMobile: true },
    { key: 'location', header: 'Location', hideOnMobile: true },
    { key: 'value', header: 'Value', align: 'right', hideOnMobile: true, render: (r) => <span className="ak-tabular">{r.value}</span> },
    { key: 'assignedTo', header: 'Assigned', hideOnMobile: true, render: (r) => r.assignedTo || '—' },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...ASSET_STATUS[r.status]} icon={false} /> },
  ];
  return <ResourceList title="Assets" subtitle="Fixed asset register" icon="category" tabs={INVENTORY_TABS} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">Add asset</Button>}
    search={{ placeholder: 'Search asset or tag…', match: (r, t) => r.name.toLowerCase().includes(t) || r.assetTag.toLowerCase().includes(t) }}
    filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(ASSET_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
    unavailableTitle="Assets are ready" unavailableMessage="The asset register loads here from /inventory/assets once the backend is connected." />;
}

export function CategoriesPage() {
  const query = useModuleQuery<ListResult<InventoryCategory>>(['inventory', 'categories'], () => fetchList('/inventory/categories', { query: { pageSize: 200 } }));
  const columns: Column<InventoryCategory>[] = [
    { key: 'name', header: 'Category', sortValue: (r) => r.name, render: (r) => <span className="ak-label-lg text-on-surface">{r.name}</span> },
    { key: 'type', header: 'Type', render: (r) => humanize(r.type) },
    { key: 'assetCount', header: 'Assets', align: 'right', sortValue: (r) => r.assetCount },
    { key: 'totalValue', header: 'Value', align: 'right', render: (r) => <span className="ak-tabular">{r.totalValue}</span> },
    { key: 'depreciationRate', header: 'Depreciation', hideOnMobile: true, align: 'right' },
    { key: 'responsibleDept', header: 'Dept', hideOnMobile: true },
  ];
  return <ResourceList title="Categories" subtitle="Asset categories" icon="widgets" tabs={INVENTORY_TABS} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">Add category</Button>}
    search={{ placeholder: 'Search category…', match: (r, t) => r.name.toLowerCase().includes(t) }}
    unavailableTitle="Categories are ready" unavailableMessage="Asset categories load here from /inventory/categories once the backend is connected." />;
}

function allocationColumns(): Column<InventoryAllocation>[] {
  return [
    { key: 'assetName', header: 'Asset', sortValue: (r) => r.assetName, render: (r) => (
      <div className="min-w-0"><div className="truncate ak-label-lg text-on-surface">{r.assetName}</div><div className="ak-mono text-[12px] text-on-surface-variant">{r.assetTag}</div></div>
    ) },
    { key: 'assignedTo', header: 'Assigned to', sortValue: (r) => r.assignedTo },
    { key: 'department', header: 'Department', hideOnMobile: true },
    { key: 'returnDue', header: 'Return due', hideOnMobile: true, align: 'right' },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...ALLOCATION_STATUS[r.status]} icon={false} /> },
  ];
}

export function InvAllocationsPage() {
  const query = useModuleQuery<ListResult<InventoryAllocation>>(['inventory', 'allocations'], () => fetchList('/inventory/allocations', { query: { pageSize: 300 } }));
  return <ResourceList title="Allocations" subtitle="Assets assigned to staff & departments" icon="assignment_ind" tabs={INVENTORY_TABS} query={query} columns={allocationColumns()} rowKey={(r) => r.id}
    actions={<Button icon="add">Allocate asset</Button>}
    search={{ placeholder: 'Search asset or assignee…', match: (r, t) => r.assetName.toLowerCase().includes(t) || r.assignedTo.toLowerCase().includes(t) }}
    filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(ALLOCATION_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
    unavailableTitle="Allocations are ready" unavailableMessage="Asset allocations load here from /inventory/allocations once the backend is connected." />;
}

export function DistributionPage() {
  // Distribution is the consumable/issue view over the allocations endpoint.
  const query = useModuleQuery<ListResult<InventoryAllocation>>(['inventory', 'distribution'], () => fetchList('/inventory/allocations', { query: { pageSize: 300, kind: 'distribution' } }));
  return <ResourceList title="Distribution" subtitle="Consumables issued to departments & classes" icon="local_shipping" tabs={INVENTORY_TABS} query={query} columns={allocationColumns()} rowKey={(r) => r.id}
    actions={<Button icon="add">Issue items</Button>}
    search={{ placeholder: 'Search item or recipient…', match: (r, t) => r.assetName.toLowerCase().includes(t) || r.assignedTo.toLowerCase().includes(t) }}
    unavailableTitle="Distribution is ready" unavailableMessage="Consumable distribution loads here from /inventory/allocations once the backend is connected." />;
}

export function MaintenancePage() {
  const query = useModuleQuery<ListResult<InventoryMaintenanceRecord>>(['inventory', 'maintenance'], () => fetchList('/inventory/maintenance', { query: { pageSize: 300 } }));
  const columns: Column<InventoryMaintenanceRecord>[] = [
    { key: 'assetName', header: 'Asset', sortValue: (r) => r.assetName, render: (r) => <span className="ak-label-lg text-on-surface">{r.assetName}</span> },
    { key: 'maintenanceType', header: 'Type', hideOnMobile: true },
    { key: 'scheduledDate', header: 'Scheduled', hideOnMobile: true },
    { key: 'technician', header: 'Technician', hideOnMobile: true },
    { key: 'estimatedCost', header: 'Est. cost', align: 'right', render: (r) => <span className="ak-tabular">{r.estimatedCost}</span> },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...MAINTENANCE_STATUS[r.status]} icon={false} /> },
  ];
  return <ResourceList title="Maintenance" subtitle="Service schedule & history" icon="engineering" tabs={INVENTORY_TABS} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">Schedule</Button>}
    search={{ placeholder: 'Search asset…', match: (r, t) => r.assetName.toLowerCase().includes(t) }}
    filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(MAINTENANCE_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
    unavailableTitle="Maintenance is ready" unavailableMessage="Maintenance schedules load here from /inventory/maintenance once the backend is connected." />;
}

export function ProcurementPage() {
  const query = useModuleQuery<ListResult<InventoryProcurementOrder>>(['inventory', 'procurement'], () => fetchList('/inventory/procurement', { query: { pageSize: 300 } }));
  const columns: Column<InventoryProcurementOrder>[] = [
    { key: 'poNumber', header: 'PO', sortValue: (r) => r.poNumber, render: (r) => <span className="ak-mono text-[13px]">{r.poNumber}</span> },
    { key: 'vendorName', header: 'Vendor', sortValue: (r) => r.vendorName },
    { key: 'items', header: 'Items', hideOnMobile: true },
    { key: 'expectedDelivery', header: 'Expected', hideOnMobile: true },
    { key: 'totalAmount', header: 'Amount', align: 'right', render: (r) => <span className="ak-tabular font-semibold text-on-surface">{r.totalAmount}</span> },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...PROCUREMENT_STATUS[r.status]} icon={false} /> },
  ];
  return <ResourceList title="Procurement" subtitle="Purchase orders" icon="shopping_cart" tabs={INVENTORY_TABS} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">New PO</Button>}
    search={{ placeholder: 'Search PO or vendor…', match: (r, t) => r.poNumber.toLowerCase().includes(t) || r.vendorName.toLowerCase().includes(t) }}
    filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(PROCUREMENT_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
    unavailableTitle="Procurement is ready" unavailableMessage="Purchase orders load here from /inventory/procurement once the backend is connected." />;
}

export function VendorsPage() {
  const query = useModuleQuery<ListResult<InventoryVendor>>(['inventory', 'vendors'], () => fetchList('/inventory/vendors', { query: { pageSize: 300 } }));
  const columns: Column<InventoryVendor>[] = [
    { key: 'name', header: 'Vendor', sortValue: (r) => r.name, render: (r) => (
      <div className="min-w-0"><div className="truncate ak-label-lg text-on-surface">{r.name}</div><div className="text-[12px] text-on-surface-variant">{r.contactPerson}</div></div>
    ) },
    { key: 'category', header: 'Category', hideOnMobile: true },
    { key: 'phone', header: 'Phone', hideOnMobile: true, render: (r) => <span className="ak-mono text-[13px]">{r.phone}</span> },
    { key: 'activeOrders', header: 'Orders', align: 'right', sortValue: (r) => r.activeOrders },
    { key: 'totalSpend', header: 'Total spend', align: 'right', render: (r) => <span className="ak-tabular">{r.totalSpend}</span> },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...VENDOR_STATUS[r.status]} icon={false} /> },
  ];
  return <ResourceList title="Vendors" subtitle="Supplier directory" icon="storefront" tabs={INVENTORY_TABS} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">Add vendor</Button>}
    search={{ placeholder: 'Search vendor…', match: (r, t) => r.name.toLowerCase().includes(t) }}
    filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(VENDOR_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
    unavailableTitle="Vendors are ready" unavailableMessage="The vendor directory loads here from /inventory/vendors once the backend is connected." />;
}

// --- Stock ledger + approvals (endpoints not yet exposed — gap WEB-004) ---
export function StockPage() {
  const query = useModuleQuery<ListResult<InventoryStockItem>>(['inventory', 'stock'], () => fetchList('/inventory/stock', { query: { pageSize: 300 } }));
  const columns: Column<InventoryStockItem>[] = [
    { key: 'itemName', header: 'Item', sortValue: (r) => r.itemName, render: (r) => <span className="ak-label-lg text-on-surface">{r.itemName}</span> },
    { key: 'category', header: 'Category', hideOnMobile: true },
    { key: 'onHand', header: 'On hand', align: 'right', sortValue: (r) => r.onHand, render: (r) => <span className={r.onHand <= r.reorderLevel ? 'font-semibold text-error' : 'text-on-surface'}>{r.onHand} {r.unit}</span> },
    { key: 'reorderLevel', header: 'Reorder', align: 'right', hideOnMobile: true, render: (r) => `${r.reorderLevel} ${r.unit}` },
    { key: 'totalValue', header: 'Value', align: 'right', render: (r) => <span className="ak-tabular">{r.totalValue}</span> },
  ];
  return <ResourceList title="Stock" subtitle="Consumable stock ledger" icon="inventory" tabs={INVENTORY_TABS} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">Stock movement</Button>}
    search={{ placeholder: 'Search item…', match: (r, t) => r.itemName.toLowerCase().includes(t) }}
    unavailableTitle="Stock ledger is ready (endpoint pending — WEB-004)"
    unavailableMessage="The consumable stock ledger will load from /inventory/stock once that read endpoint is exposed (tracked as gap WEB-004). No simulated stock is shown." />;
}

export function StockApprovalsPage() {
  const query = useModuleQuery<ListResult<InventoryStockApproval>>(['inventory', 'stock-approvals'], () => fetchList('/inventory/stock/approvals', { query: { pageSize: 300 } }));
  const STATUS = { pending: { status: 'warning' as const, label: 'Pending' }, approved: { status: 'success' as const, label: 'Approved' }, rejected: { status: 'error' as const, label: 'Rejected' } };
  const columns: Column<InventoryStockApproval>[] = [
    { key: 'itemName', header: 'Item', sortValue: (r) => r.itemName, render: (r) => <span className="ak-label-lg text-on-surface">{r.itemName}</span> },
    { key: 'changeType', header: 'Change', render: (r) => humanize(r.changeType) },
    { key: 'quantity', header: 'Qty', align: 'right' },
    { key: 'requestedBy', header: 'Requested by', hideOnMobile: true },
    { key: 'reason', header: 'Reason', hideOnMobile: true },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...STATUS[r.status]} icon={false} /> },
  ];
  return <ResourceList title="Stock approvals" subtitle="Value-reducing stock changes (maker-checker)" icon="approval" tabs={INVENTORY_TABS} query={query} columns={columns} rowKey={(r) => r.id}
    search={{ placeholder: 'Search item…', match: (r, t) => r.itemName.toLowerCase().includes(t) }}
    unavailableTitle="Stock approvals are ready (endpoint pending — WEB-004)"
    unavailableMessage="Maker-checker stock approvals will load from /inventory/stock/approvals once exposed (tracked as gap WEB-004)." />;
}

// --- Intelligence: lifecycle + replacement + copilot ---
function lifecycleColumns(): Column<InventoryLifecycleItem>[] {
  return [
    { key: 'assetName', header: 'Asset', sortValue: (r) => r.assetName, render: (r) => (
      <div className="min-w-0"><div className="truncate ak-label-lg text-on-surface">{r.assetName}</div><div className="ak-mono text-[12px] text-on-surface-variant">{r.assetTag}</div></div>
    ) },
    { key: 'ageLabel', header: 'Age', hideOnMobile: true },
    { key: 'condition', header: 'Condition', render: (r) => humanize(r.condition) },
    { key: 'recommendation', header: 'Recommendation', align: 'right' },
  ];
}

export function LifecyclePage() {
  const query = useModuleQuery<ListResult<InventoryLifecycleItem>>(['inventory', 'lifecycle'], () => fetchList('/inventory/intelligence/lifecycle', { query: { pageSize: 300 } }));
  return <ResourceList title="Asset lifecycle" subtitle="Age, condition & lifecycle stage" icon="timeline" tabs={INVENTORY_TABS} query={query} columns={lifecycleColumns()} rowKey={(r) => r.id}
    search={{ placeholder: 'Search asset…', match: (r, t) => r.assetName.toLowerCase().includes(t) }}
    unavailableTitle="Lifecycle intelligence is ready" unavailableMessage="Asset lifecycle insights load here from /inventory/intelligence/lifecycle once the backend is connected." />;
}

export function ReplacementPage() {
  const query = useModuleQuery<ListResult<InventoryLifecycleItem>>(['inventory', 'replacement'], () => fetchList('/inventory/intelligence/lifecycle', { query: { pageSize: 300, view: 'replacement' } }));
  return <ResourceList title="Replacement" subtitle="Assets recommended for replacement" icon="autorenew" tabs={INVENTORY_TABS} query={query} columns={lifecycleColumns()} rowKey={(r) => r.id}
    search={{ placeholder: 'Search asset…', match: (r, t) => r.assetName.toLowerCase().includes(t) }}
    unavailableTitle="Replacement planning is ready" unavailableMessage="Replacement recommendations load here from /inventory/intelligence/lifecycle once the backend is connected." />;
}

export function InventoryCopilotPage() {
  const query = useModuleQuery(['inventory', 'copilot'], () => apiFetch<{ items: { id: string; title: string; detail: string }[] }>('/inventory/intelligence/copilot'));
  return (
    <div className="space-y-s6">
      <PageHeader title="Inventory copilot" subtitle="AI recommendations for inventory" icon="auto_awesome" tabs={<ModuleTabs tabs={INVENTORY_TABS} />} />
      <AsyncBoundary query={query} unavailableTitle="Inventory copilot is ready" unavailableMessage="AI recommendations load here from /inventory/intelligence/copilot once the backend is connected." isEmpty={(d) => !d.items?.length}>
        {(d) => (
          <div className="grid grid-cols-1 gap-s4 md:grid-cols-2">
            {d.items.map((it) => (
              <Card key={it.id}>
                <div className="flex items-start gap-s3">
                  <span className="grid h-9 w-9 shrink-0 place-items-center rounded-lg bg-primary-container text-on-primary-container"><Icon name="lightbulb" size={18} /></span>
                  <div><Text variant="title-sm" className="text-on-surface">{it.title}</Text><Text variant="body-sm" className="mt-s1 text-on-surface-variant">{it.detail}</Text></div>
                </div>
              </Card>
            ))}
          </div>
        )}
      </AsyncBoundary>
    </div>
  );
}

export function InventoryReportsPage() {
  return (
    <ReportsHub title="Inventory reports" subtitle="Assets, stock and procurement" icon="summarize" tabs={INVENTORY_TABS}
      reports={[
        { key: 'valuation', title: 'Asset valuation', description: 'Asset value and depreciation by category.', icon: 'category' },
        { key: 'stock', title: 'Stock ledger', description: 'Movements, on-hand and reorder alerts.', icon: 'inventory' },
        { key: 'procurement', title: 'Procurement', description: 'Purchase orders and spend by vendor.', icon: 'shopping_cart' },
        { key: 'maintenance', title: 'Maintenance', description: 'Service history and upcoming schedules.', icon: 'engineering' },
        { key: 'audit', title: 'Audit trail', description: 'Allocations, returns and write-offs.', icon: 'fact_check' },
      ]} />
  );
}
