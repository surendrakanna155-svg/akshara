/** Inventory contracts — mirror lib/features/inventory/inventory_models.dart. */
export type InventoryAssetStatus = 'available' | 'allocated' | 'maintenance' | 'retired';
export type InventoryCategoryType = 'equipment' | 'furniture' | 'electronics' | 'consumable' | 'lab' | 'sports';
export type InventoryAllocationStatus = 'active' | 'pendingReturn' | 'overdue';
export type InventoryMaintenanceStatus = 'scheduled' | 'inProgress' | 'completed' | 'overdue';
export type InventoryProcurementStatus = 'draft' | 'ordered' | 'received' | 'cancelled';
export type InventoryVendorStatus = 'active' | 'pending' | 'inactive';

export interface InventoryAsset {
  id: string;
  assetTag: string;
  name: string;
  category: string;
  location: string;
  purchaseDate: string;
  value: string;
  status: InventoryAssetStatus;
  assignedTo?: string;
  lastAudit: string;
}

export interface InventoryCategory {
  id: string;
  name: string;
  type: InventoryCategoryType;
  assetCount: number;
  totalValue: string;
  depreciationRate: string;
  responsibleDept: string;
  description: string;
}

export interface InventoryAllocation {
  id: string;
  assetTag: string;
  assetName: string;
  department: string;
  assignedTo: string;
  assignedDate: string;
  returnDue: string;
  status: InventoryAllocationStatus;
}

export interface InventoryMaintenanceRecord {
  id: string;
  assetTag: string;
  assetName: string;
  maintenanceType: string;
  scheduledDate: string;
  technician: string;
  estimatedCost: string;
  status: InventoryMaintenanceStatus;
}

export interface InventoryProcurementOrder {
  id: string;
  poNumber: string;
  vendorName: string;
  items: string;
  totalAmount: string;
  orderDate: string;
  expectedDelivery: string;
  status: InventoryProcurementStatus;
  requestedBy: string;
}

export interface InventoryVendor {
  id: string;
  name: string;
  category: string;
  contactPerson: string;
  phone: string;
  email: string;
  gstNumber: string;
  activeOrders: number;
  totalSpend: string;
  status: InventoryVendorStatus;
}

export interface InventoryKpi {
  id: string;
  label: string;
  value: string;
  delta?: number;
}

export interface InventoryStockAlert {
  id: string;
  label: string;
  detail: string;
}

export interface InventoryDashboardData {
  kpis: InventoryKpi[];
  stockAlerts: InventoryStockAlert[];
  aiInsight?: string;
}

// --- Contracts for endpoints not yet exposed (gap WEB-004) ---
export interface InventoryStockItem {
  id: string;
  itemName: string;
  category: string;
  unit: string;
  onHand: number;
  reorderLevel: number;
  unitValue: string;
  totalValue: string;
}

export interface InventoryStockApproval {
  id: string;
  itemName: string;
  changeType: string;
  quantity: number;
  requestedBy: string;
  reason: string;
  status: 'pending' | 'approved' | 'rejected';
}

// --- Intelligence contracts (copilot / lifecycle) ---
export interface InventoryLifecycleItem {
  id: string;
  assetName: string;
  assetTag: string;
  ageLabel: string;
  condition: string;
  recommendation: string;
}
