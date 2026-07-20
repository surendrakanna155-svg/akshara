import type { SemanticStatus } from '@/components/ui';
import type {
  InventoryAllocationStatus,
  InventoryAssetStatus,
  InventoryMaintenanceStatus,
  InventoryProcurementStatus,
  InventoryVendorStatus,
} from '@/lib/contracts/inventory';
import { MODULE_TABS } from '@/routes/navConfig';

export const INVENTORY_TABS = MODULE_TABS.inventory;

export const ASSET_STATUS: Record<InventoryAssetStatus, { status: SemanticStatus; label: string }> = {
  available: { status: 'success', label: 'Available' },
  allocated: { status: 'info', label: 'Allocated' },
  maintenance: { status: 'warning', label: 'Maintenance' },
  retired: { status: 'neutral', label: 'Retired' },
};

export const ALLOCATION_STATUS: Record<InventoryAllocationStatus, { status: SemanticStatus; label: string }> = {
  active: { status: 'success', label: 'Active' },
  pendingReturn: { status: 'warning', label: 'Pending return' },
  overdue: { status: 'error', label: 'Overdue' },
};

export const MAINTENANCE_STATUS: Record<InventoryMaintenanceStatus, { status: SemanticStatus; label: string }> = {
  scheduled: { status: 'info', label: 'Scheduled' },
  inProgress: { status: 'pending', label: 'In progress' },
  completed: { status: 'success', label: 'Completed' },
  overdue: { status: 'error', label: 'Overdue' },
};

export const PROCUREMENT_STATUS: Record<InventoryProcurementStatus, { status: SemanticStatus; label: string }> = {
  draft: { status: 'neutral', label: 'Draft' },
  ordered: { status: 'info', label: 'Ordered' },
  received: { status: 'success', label: 'Received' },
  cancelled: { status: 'error', label: 'Cancelled' },
};

export const VENDOR_STATUS: Record<InventoryVendorStatus, { status: SemanticStatus; label: string }> = {
  active: { status: 'success', label: 'Active' },
  pending: { status: 'warning', label: 'Pending' },
  inactive: { status: 'neutral', label: 'Inactive' },
};
