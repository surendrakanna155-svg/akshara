import 'package:flutter/material.dart';

import '../../../features/inventory/inventory_models.dart';
import '../../../features/inventory/inventory_requests.dart';
import '../../../features/inventory/intelligence/inventory_intelligence_models.dart';
import '../../../router/route_names.dart';
import '../interfaces/inventory_repository.dart';
import '../paginated_result.dart';
import '../pagination_helpers.dart';
import '../repository_query.dart';

class MockInventoryRepository implements InventoryRepository {
  MockInventoryRepository()
      : _procurementOrders = List.of(_seedProcurement),
        _lifecycleEvents = List.of(_seedLifecycleEvents);

  final List<InventoryProcurementOrder> _procurementOrders;
  final List<AssetLifecycleEvent> _lifecycleEvents;
  int _poCounter = 200;
  int _lifecycleEventCounter = 100;

  static const _seedLifecycleEvents = [
    AssetLifecycleEvent(
      id: 'evt_1',
      assetId: 'asset_1',
      assetTag: 'INV-AST-1042',
      eventType: AssetLifecycleEventType.distribution,
      notes: 'Assigned to IT Lab — Block C',
      recordedAt: '2026-03-01T10:00:00Z',
      recordedBy: 'user_1',
    ),
    AssetLifecycleEvent(
      id: 'evt_2',
      assetId: 'asset_4',
      assetTag: 'INV-AST-1045',
      eventType: AssetLifecycleEventType.damage,
      notes: 'Chair leg repair required',
      recordedAt: '2026-02-28T14:30:00Z',
      recordedBy: 'user_2',
    ),
  ];

  static const _assets = [
    InventoryAsset(
      id: 'asset_1',
      assetTag: 'INV-AST-1042',
      name: 'Dell Latitude 5540 Laptop',
      category: 'Electronics',
      location: 'IT Lab — Block C',
      purchaseDate: '15 Aug 2024',
      value: '₹68,500',
      status: InventoryAssetStatus.allocated,
      assignedTo: 'Priya Sharma',
      financeAssetId: 'FN-AST-8821',
      lastAudit: '2 Mar 2026',
    ),
    InventoryAsset(
      id: 'asset_2',
      assetTag: 'INV-AST-1043',
      name: 'Smart Board 75"',
      category: 'Electronics',
      location: 'Class 10-A',
      purchaseDate: '10 Jan 2025',
      value: '₹1,24,000',
      status: InventoryAssetStatus.allocated,
      assignedTo: 'Block A — Room 204',
      financeAssetId: 'FN-AST-8822',
      lastAudit: '28 Feb 2026',
    ),
    InventoryAsset(
      id: 'asset_3',
      assetTag: 'INV-AST-1044',
      name: 'Lab Microscope Set (x12)',
      category: 'Lab Equipment',
      location: 'Science Lab — Block B',
      purchaseDate: '5 Jun 2023',
      value: '₹2,40,000',
      status: InventoryAssetStatus.available,
      assignedTo: null,
      financeAssetId: 'FN-AST-8823',
      lastAudit: '15 Jan 2026',
    ),
    InventoryAsset(
      id: 'asset_4',
      assetTag: 'INV-AST-1045',
      name: 'Hostel Dining Chairs (x50)',
      category: 'Furniture',
      location: 'Hostel Block A — Mess',
      purchaseDate: '20 Nov 2024',
      value: '₹1,85,000',
      status: InventoryAssetStatus.maintenance,
      assignedTo: 'Hostel Mess',
      financeAssetId: 'FN-AST-8824',
      lastAudit: '1 Mar 2026',
    ),
  ];

  static const _categories = [
    InventoryCategory(
      id: 'cat_1',
      name: 'Electronics',
      type: InventoryCategoryType.electronics,
      assetCount: 142,
      totalValue: '₹42.8L',
      depreciationRate: '15%/yr',
      responsibleDept: 'IT',
      description: 'Laptops, projectors, smart boards',
    ),
    InventoryCategory(
      id: 'cat_2',
      name: 'Furniture',
      type: InventoryCategoryType.furniture,
      assetCount: 380,
      totalValue: '₹28.4L',
      depreciationRate: '10%/yr',
      responsibleDept: 'Admin',
      description: 'Desks, chairs, hostel furniture',
    ),
    InventoryCategory(
      id: 'cat_3',
      name: 'Lab Equipment',
      type: InventoryCategoryType.lab,
      assetCount: 86,
      totalValue: '₹18.2L',
      depreciationRate: '12%/yr',
      responsibleDept: 'Science',
      description: 'Microscopes, chemicals, safety gear',
    ),
    InventoryCategory(
      id: 'cat_4',
      name: 'Consumables',
      type: InventoryCategoryType.consumable,
      assetCount: 0,
      totalValue: '₹4.6L',
      depreciationRate: 'N/A',
      responsibleDept: 'Stores',
      description: 'Stationery, cleaning supplies, lab consumables',
    ),
  ];

  static const _allocations = [
    InventoryAllocation(
      id: 'alloc_1',
      assetTag: 'INV-AST-1042',
      assetName: 'Dell Latitude 5540 Laptop',
      department: 'HR',
      assignedTo: 'Priya Sharma',
      assignedDate: '1 Sep 2024',
      returnDue: '—',
      status: InventoryAllocationStatus.active,
      hrEmployeeId: 'HR-EMP-101',
      hostelBlock: null,
      librarySection: null,
      integrationNote: 'HR employee allocation — links to employee profile',
    ),
    InventoryAllocation(
      id: 'alloc_2',
      assetTag: 'INV-AST-1045',
      assetName: 'Hostel Dining Chairs (x50)',
      department: 'Hostel',
      assignedTo: 'Block A — Mess Hall',
      assignedDate: '22 Nov 2024',
      returnDue: '—',
      status: InventoryAllocationStatus.active,
      hrEmployeeId: null,
      hostelBlock: 'Block A',
      librarySection: null,
      integrationNote: 'Hostel mess furniture — links to hostel rooms',
    ),
    InventoryAllocation(
      id: 'alloc_3',
      assetTag: 'INV-AST-1046',
      assetName: 'Library RFID Scanner',
      department: 'Library',
      assignedTo: 'Main Library — Circulation',
      assignedDate: '5 Jan 2025',
      returnDue: '—',
      status: InventoryAllocationStatus.active,
      hrEmployeeId: null,
      hostelBlock: null,
      librarySection: 'Circulation Desk',
      integrationNote:
          'Library circulation equipment — links to library module',
    ),
    InventoryAllocation(
      id: 'alloc_4',
      assetTag: 'INV-AST-1047',
      assetName: 'Sports Equipment Kit',
      department: 'Sports',
      assignedTo: 'Coach Ramesh Kumar',
      assignedDate: '10 Dec 2025',
      returnDue: '10 Jun 2026',
      status: InventoryAllocationStatus.pendingReturn,
      hrEmployeeId: 'HR-EMP-108',
      hostelBlock: null,
      librarySection: null,
      integrationNote: 'Seasonal allocation — return due before summer break',
    ),
  ];

  static const _maintenance = [
    InventoryMaintenanceRecord(
      id: 'maint_1',
      assetTag: 'INV-AST-1045',
      assetName: 'Hostel Dining Chairs (x50)',
      maintenanceType: 'Repair — broken legs',
      scheduledDate: '8 Mar 2026',
      technician: 'Suresh Reddy',
      hrTechnicianId: 'HR-EMP-112',
      estimatedCost: '₹12,400',
      status: InventoryMaintenanceStatus.inProgress,
      financeBudgetCode: 'FN-BUD-MAINT-2026',
    ),
    InventoryMaintenanceRecord(
      id: 'maint_2',
      assetTag: 'INV-AST-1043',
      assetName: 'Smart Board 75"',
      maintenanceType: 'Annual calibration',
      scheduledDate: '15 Mar 2026',
      technician: 'IT Vendor — TechServe',
      hrTechnicianId: 'HR-EMP-101',
      estimatedCost: '₹4,800',
      status: InventoryMaintenanceStatus.scheduled,
      financeBudgetCode: 'FN-BUD-MAINT-2026',
    ),
    InventoryMaintenanceRecord(
      id: 'maint_3',
      assetTag: 'INV-AST-1048',
      assetName: 'AC Unit — Hostel Block B',
      maintenanceType: 'Compressor service',
      scheduledDate: '1 Mar 2026',
      technician: 'CoolAir Services',
      hrTechnicianId: 'HR-EMP-115',
      estimatedCost: '₹18,200',
      status: InventoryMaintenanceStatus.overdue,
      financeBudgetCode: 'FN-BUD-MAINT-2026',
    ),
    InventoryMaintenanceRecord(
      id: 'maint_4',
      assetTag: 'INV-AST-1044',
      assetName: 'Lab Microscope Set (x12)',
      maintenanceType: 'Lens cleaning & alignment',
      scheduledDate: '20 Feb 2026',
      technician: 'Lab Technician',
      hrTechnicianId: 'HR-EMP-119',
      estimatedCost: '₹6,500',
      status: InventoryMaintenanceStatus.completed,
      financeBudgetCode: 'FN-BUD-MAINT-2026',
    ),
  ];

  static const _seedProcurement = [
    InventoryProcurementOrder(
      id: 'po_1',
      poNumber: 'PO-2026-0142',
      vendorName: 'TechServe Solutions',
      items: '10× Dell Latitude laptops',
      totalAmount: '₹6,85,000',
      orderDate: '1 Mar 2026',
      expectedDelivery: '18 Mar 2026',
      status: InventoryProcurementStatus.ordered,
      financePoId: 'po_if_1',
      requestedBy: 'IT Department',
      approvalHistory: [
        InventoryProcurementApprovalEntry(
          action: 'created',
          actor: 'IT Department',
          recordedAt: '2026-03-01T10:00:00Z',
          note: 'Draft PO created',
        ),
        InventoryProcurementApprovalEntry(
          action: 'approved',
          actor: 'Finance Admin',
          recordedAt: '2026-03-01T16:30:00Z',
          note: 'AP commitment synced',
        ),
      ],
    ),
    InventoryProcurementOrder(
      id: 'po_2',
      poNumber: 'PO-2026-0138',
      vendorName: 'FurniCraft India',
      items: 'Hostel bunk beds (x20)',
      totalAmount: '₹3,20,000',
      orderDate: '25 Feb 2026',
      expectedDelivery: '10 Mar 2026',
      status: InventoryProcurementStatus.ordered,
      financePoId: 'po_if_3',
      requestedBy: 'Hostel Warden',
      approvalHistory: [
        InventoryProcurementApprovalEntry(
          action: 'created',
          actor: 'Hostel Warden',
          recordedAt: '2026-02-25T09:00:00Z',
          note: 'Draft PO created',
        ),
        InventoryProcurementApprovalEntry(
          action: 'approved',
          actor: 'Finance Admin',
          recordedAt: '2026-02-25T14:10:00Z',
          note: 'Approved for ordering',
        ),
      ],
    ),
    InventoryProcurementOrder(
      id: 'po_3',
      poNumber: 'PO-2026-0135',
      vendorName: 'LabSupplies Co.',
      items: 'Chemistry lab consumables Q1',
      totalAmount: '₹84,200',
      orderDate: '20 Feb 2026',
      expectedDelivery: '5 Mar 2026',
      status: InventoryProcurementStatus.received,
      financePoId: 'po_if_4',
      requestedBy: 'Science Department',
      approvalHistory: [
        InventoryProcurementApprovalEntry(
          action: 'created',
          actor: 'Science Department',
          recordedAt: '2026-02-20T08:45:00Z',
        ),
        InventoryProcurementApprovalEntry(
          action: 'approved',
          actor: 'Finance Admin',
          recordedAt: '2026-02-20T13:30:00Z',
        ),
        InventoryProcurementApprovalEntry(
          action: 'received',
          actor: 'Stores QA',
          recordedAt: '2026-03-05T12:20:00Z',
          note: 'All lines received and posted',
        ),
      ],
    ),
    InventoryProcurementOrder(
      id: 'po_4',
      poNumber: 'PO-2026-0145',
      vendorName: 'BookWorld Distributors',
      items: 'Library books — 200 titles',
      totalAmount: '₹1,45,000',
      orderDate: '3 Mar 2026',
      expectedDelivery: '25 Mar 2026',
      status: InventoryProcurementStatus.draft,
      financePoId: 'po_if_2',
      requestedBy: 'Library (placeholder)',
      approvalHistory: [
        InventoryProcurementApprovalEntry(
          action: 'created',
          actor: 'Library',
          recordedAt: '2026-03-03T11:30:00Z',
          note: 'Awaiting finance approval',
        ),
      ],
    ),
  ];

  static const _vendors = [
    InventoryVendor(
      id: 'vend_1',
      name: 'TechServe Solutions',
      category: 'Electronics',
      contactPerson: 'Anil Mehta',
      phone: '+91 98765 43210',
      email: 'anil@techserve.in',
      gstNumber: '36AABCT1234F1Z5',
      activeOrders: 2,
      totalSpend: '₹28.4L',
      status: InventoryVendorStatus.active,
      financeVendorId: 'FN-VND-201',
    ),
    InventoryVendor(
      id: 'vend_2',
      name: 'FurniCraft India',
      category: 'Furniture',
      contactPerson: 'Kavitha Nair',
      phone: '+91 91234 56789',
      email: 'orders@furnicraft.in',
      gstNumber: '36AABCF5678G2Z1',
      activeOrders: 1,
      totalSpend: '₹14.2L',
      status: InventoryVendorStatus.active,
      financeVendorId: 'FN-VND-202',
    ),
    InventoryVendor(
      id: 'vend_3',
      name: 'LabSupplies Co.',
      category: 'Lab Consumables',
      contactPerson: 'Dr. Rajesh Iyer',
      phone: '+91 99887 76655',
      email: 'sales@labsupplies.co',
      gstNumber: '36AABCL9012H3Z8',
      activeOrders: 0,
      totalSpend: '₹8.6L',
      status: InventoryVendorStatus.active,
      financeVendorId: 'FN-VND-203',
    ),
    InventoryVendor(
      id: 'vend_4',
      name: 'BookWorld Distributors',
      category: 'Library Supplies',
      contactPerson: 'Meera Singh',
      phone: '+91 97654 32109',
      email: 'meera@bookworld.in',
      gstNumber: '36AABCB3456I4Z2',
      activeOrders: 1,
      totalSpend: '₹3.2L',
      status: InventoryVendorStatus.pending,
      financeVendorId: 'FN-VND-204',
    ),
  ];

  @override
  Future<InventoryDashboardData> getDashboard(
      {required RepositoryQuery query}) async {
    return const InventoryDashboardData(
      kpis: [
        InventoryKpi(
          id: 'total_assets',
          value: '1,248',
          label: 'Total Assets',
          icon: Icons.inventory_2_outlined,
          accentName: 'primary',
        ),
        InventoryKpi(
          id: 'allocated',
          value: '892',
          label: 'Allocated',
          icon: Icons.assignment_outlined,
          accentName: 'success',
        ),
        InventoryKpi(
          id: 'maintenance',
          value: '14',
          label: 'Under Maintenance',
          icon: Icons.build_outlined,
          accentName: 'warning',
        ),
        InventoryKpi(
          id: 'low_stock',
          value: '8',
          label: 'Low Stock Items',
          icon: Icons.warning_amber_outlined,
          accentName: 'error',
        ),
        InventoryKpi(
          id: 'procurement',
          value: '₹12.4L',
          label: 'Open PO Value',
          icon: Icons.shopping_cart_outlined,
          accentName: 'neutral',
          detail: 'Finance integration placeholder',
        ),
        InventoryKpi(
          id: 'asset_value',
          value: '₹94.2L',
          label: 'Total Asset Value',
          icon: Icons.account_balance_outlined,
          accentName: 'primary',
          detail: 'Finance asset register link',
        ),
      ],
      recentActivity: [
        InventoryActivityItem(
          id: 'act_1',
          description: 'PO-2026-0142 approved — 10 laptops',
          timestamp: '2 hrs ago',
          actor: 'Finance Admin',
          moduleLink: RouteNames.financeDashboard,
        ),
        InventoryActivityItem(
          id: 'act_2',
          description: 'Hostel chairs sent for repair',
          timestamp: '5 hrs ago',
          actor: 'Hostel Warden',
          moduleLink: RouteNames.hostelDashboard,
        ),
        InventoryActivityItem(
          id: 'act_3',
          description: 'Laptop allocated to HR-EMP-101',
          timestamp: 'Yesterday',
          actor: 'IT Admin',
          moduleLink: RouteNames.hrEmployees,
        ),
        InventoryActivityItem(
          id: 'act_4',
          description: 'Library RFID scanner registered',
          timestamp: '2 days ago',
          actor: 'Librarian',
          moduleLink: RouteNames.libraryDashboard,
        ),
      ],
      stockAlerts: [
        InventoryStockAlert(
          id: 'alert_1',
          itemName: 'A4 Paper Reams',
          category: 'Consumables',
          currentStock: 12,
          reorderLevel: 50,
          department: 'Admin',
        ),
        InventoryStockAlert(
          id: 'alert_2',
          itemName: 'Lab Safety Goggles',
          category: 'Lab Equipment',
          currentStock: 8,
          reorderLevel: 30,
          department: 'Science',
        ),
        InventoryStockAlert(
          id: 'alert_3',
          itemName: 'Hostel Bedding Sets',
          category: 'Furniture',
          currentStock: 5,
          reorderLevel: 20,
          department: 'Hostel',
        ),
      ],
      aiInsight:
          '3 maintenance tasks are overdue. Hostel Block B AC service exceeds budget by ₹2,400 — review Finance budget code FN-BUD-MAINT-2026.',
      integrationLinks: [
        'Finance — asset register & PO approval',
        'HR — employee equipment allocation',
        'Hostel — room & mess furniture tracking',
        'Library — circulation equipment (placeholder)',
      ],
    );
  }

  @override
  Future<PaginatedResult<InventoryAsset>> getAssets({
    required RepositoryQuery query,
  }) async =>
      paginateList(_assets, query);

  @override
  Future<PaginatedResult<InventoryCategory>> getCategories({
    required RepositoryQuery query,
  }) async =>
      paginateList(_categories, query);

  @override
  Future<PaginatedResult<InventoryAllocation>> getAllocations({
    required RepositoryQuery query,
  }) async =>
      paginateList(_allocations, query);

  @override
  Future<PaginatedResult<InventoryMaintenanceRecord>> getMaintenanceRecords({
    required RepositoryQuery query,
  }) async =>
      paginateList(_maintenance, query);

  @override
  Future<PaginatedResult<InventoryProcurementOrder>> getProcurementOrders({
    required RepositoryQuery query,
  }) async =>
      paginateList(_procurementOrders, query);

  @override
  Future<InventoryProcurementOrder> createProcurementOrder({
    required RepositoryQuery query,
    required CreateInventoryProcurementOrderRequest request,
  }) async {
    final id = 'po_${++_poCounter}';
    final order = InventoryProcurementOrder(
      id: id,
      poNumber: 'PO-2026-${_poCounter.toString().padLeft(4, '0')}',
      vendorName: request.vendorName,
      items: request.items,
      totalAmount: request.totalAmount,
      orderDate: 'Today',
      expectedDelivery: request.expectedDelivery,
      status: InventoryProcurementStatus.draft,
      financePoId: 'po_if_${_poCounter.toString().padLeft(4, '0')}',
      requestedBy: request.requestedBy,
      approvalHistory: [
        InventoryProcurementApprovalEntry(
          action: 'created',
          actor: request.requestedBy,
          recordedAt: '2026-06-13T09:00:00Z',
          note: 'Draft created and linked to Finance PO',
        ),
      ],
    );
    _procurementOrders.insert(0, order);
    return order;
  }

  @override
  Future<InventoryProcurementOrder> approveProcurementOrder({
    required RepositoryQuery query,
    required String orderId,
  }) async {
    final index = _procurementOrders.indexWhere((order) => order.id == orderId);
    if (index < 0) {
      throw StateError('Procurement order not found: $orderId');
    }
    final current = _procurementOrders[index];
    final updated = InventoryProcurementOrder(
      id: current.id,
      poNumber: current.poNumber,
      vendorName: current.vendorName,
      items: current.items,
      totalAmount: current.totalAmount,
      orderDate: current.orderDate,
      expectedDelivery: current.expectedDelivery,
      status: InventoryProcurementStatus.ordered,
      financePoId: current.financePoId,
      requestedBy: current.requestedBy,
      approvalHistory: [
        ...current.approvalHistory,
        const InventoryProcurementApprovalEntry(
          action: 'approved',
          actor: 'Finance Admin',
          recordedAt: '2026-06-13T10:00:00Z',
          note: 'Approved and moved to ordered state',
        ),
      ],
    );
    _procurementOrders[index] = updated;
    return updated;
  }

  @override
  Future<InventoryProcurementOrder> recordProcurementReceiveHandoff({
    required RepositoryQuery query,
    required String orderId,
  }) async {
    final index = _procurementOrders.indexWhere((order) => order.id == orderId);
    if (index < 0) {
      throw StateError('Procurement order not found: $orderId');
    }
    final current = _procurementOrders[index];
    final updated = InventoryProcurementOrder(
      id: current.id,
      poNumber: current.poNumber,
      vendorName: current.vendorName,
      items: current.items,
      totalAmount: current.totalAmount,
      orderDate: current.orderDate,
      expectedDelivery: current.expectedDelivery,
      status: InventoryProcurementStatus.received,
      financePoId: current.financePoId,
      requestedBy: current.requestedBy,
      approvalHistory: [
        ...current.approvalHistory,
        const InventoryProcurementApprovalEntry(
          action: 'received',
          actor: 'Inventory Stores',
          recordedAt: '2026-06-13T11:30:00Z',
          note: 'Goods receipt handoff recorded',
        ),
      ],
    );
    _procurementOrders[index] = updated;
    return updated;
  }

  @override
  Future<PaginatedResult<InventoryVendor>> getVendors({
    required RepositoryQuery query,
  }) async =>
      paginateList(_vendors, query);

  @override
  Future<InventoryReportsData> getReports(
      {required RepositoryQuery query}) async {
    return const InventoryReportsData(
      catalog: [
        InventoryReportCatalogItem(
          id: 'rpt_1',
          title: 'Asset Register',
          description: 'Complete asset listing with values and locations',
          lastGenerated: '1 Mar 2026',
        ),
        InventoryReportCatalogItem(
          id: 'rpt_2',
          title: 'Allocation Summary',
          description: 'Department-wise asset allocation breakdown',
          lastGenerated: '28 Feb 2026',
        ),
        InventoryReportCatalogItem(
          id: 'rpt_3',
          title: 'Maintenance Log',
          description: 'Scheduled and completed maintenance activities',
          lastGenerated: '25 Feb 2026',
        ),
        InventoryReportCatalogItem(
          id: 'rpt_4',
          title: 'Procurement Status',
          description: 'Open and closed purchase orders with Finance PO IDs',
          lastGenerated: '1 Mar 2026',
        ),
        InventoryReportCatalogItem(
          id: 'rpt_5',
          title: 'Depreciation Schedule',
          description: 'Category-wise depreciation for Finance reconciliation',
          lastGenerated: '1 Jan 2026',
        ),
        InventoryReportCatalogItem(
          id: 'rpt_6',
          title: 'Low Stock Alert',
          description: 'Consumables below reorder threshold',
          lastGenerated: '2 Mar 2026',
        ),
      ],
      assetValueTrend: [
        InventoryTrendPoint(label: 'Sep', amountLakhs: 88, targetLakhs: 90),
        InventoryTrendPoint(label: 'Oct', amountLakhs: 89, targetLakhs: 90),
        InventoryTrendPoint(label: 'Nov', amountLakhs: 90, targetLakhs: 91),
        InventoryTrendPoint(label: 'Dec', amountLakhs: 91, targetLakhs: 92),
        InventoryTrendPoint(label: 'Jan', amountLakhs: 92, targetLakhs: 93),
        InventoryTrendPoint(label: 'Feb', amountLakhs: 93, targetLakhs: 94),
        InventoryTrendPoint(label: 'Mar', amountLakhs: 94.2, targetLakhs: 95),
      ],
      allocationByDept: [
        InventorySegment(label: 'IT', value: 142, percent: 28),
        InventorySegment(label: 'Hostel', value: 98, percent: 19),
        InventorySegment(label: 'Science', value: 86, percent: 17),
        InventorySegment(label: 'Library', value: 64, percent: 13),
        InventorySegment(label: 'Admin', value: 52, percent: 10),
        InventorySegment(label: 'Sports', value: 38, percent: 8),
      ],
      procurementTrend: [
        InventoryTrendPoint(label: 'Sep', amountLakhs: 4.2, targetLakhs: 5),
        InventoryTrendPoint(label: 'Oct', amountLakhs: 3.8, targetLakhs: 5),
        InventoryTrendPoint(label: 'Nov', amountLakhs: 6.1, targetLakhs: 5),
        InventoryTrendPoint(label: 'Dec', amountLakhs: 8.4, targetLakhs: 7),
        InventoryTrendPoint(label: 'Jan', amountLakhs: 5.2, targetLakhs: 6),
        InventoryTrendPoint(label: 'Feb', amountLakhs: 7.8, targetLakhs: 7),
        InventoryTrendPoint(label: 'Mar', amountLakhs: 12.4, targetLakhs: 10),
      ],
    );
  }

  @override
  Future<InventoryCopilotData> getInventoryCopilot(
          {required RepositoryQuery query}) async =>
      const InventoryCopilotData(
        stockForecastUnits: 1240,
        forecastConfidence: 81,
        lowStockPredictions: [
          InventoryLowStockPrediction(
            sku: 'LAB-MICRO-001',
            itemName: 'Lab Microscope Set',
            currentStock: 4,
            predictedDaysUntilStockout: 12,
            riskScore: 82,
          ),
        ],
        reorderRecommendations: [
          InventoryReorderRecommendation(
            id: 'reorder_1',
            sku: 'LAB-MICRO-001',
            itemName: 'Lab Microscope Set',
            recommendedQuantity: 24,
            urgency: 'high',
            reason: 'Stock at 4 units; projected stockout in 12 days',
          ),
        ],
        stockTrend: [
          InventoryStockTrendPoint(
              month: '2026-01', consumption: 180, forecast: 198),
          InventoryStockTrendPoint(
              month: '2026-02', consumption: 210, forecast: 231),
        ],
        riskAlerts: [
          InventoryRiskAlert(
            id: 'alert_1',
            severity: 'medium',
            title: '3 SKUs below reorder threshold',
            detail: 'Review auto-reorder recommendations',
          ),
        ],
        generatedAt: '2026-06-10T00:00:00Z',
      );

  @override
  Future<AssetLifecycleData> getAssetLifecycle(
      {required RepositoryQuery query}) async {
    final eventCounts = {
      for (final type in AssetLifecycleEventType.values)
        type: _lifecycleEvents.where((e) => e.eventType == type).length,
    };
    return AssetLifecycleData(
      recentEvents: List.of(_lifecycleEvents),
      eventCounts: eventCounts,
      assetsTracked: 70 + _lifecycleEvents.length,
      generatedAt: '2026-06-10T00:00:00Z',
    );
  }

  @override
  Future<ProcurementWorkflowData> getProcurementWorkflow(
          {required RepositoryQuery query}) async =>
      const ProcurementWorkflowData(
        pendingApprovals: 2,
        overdueDeliveries: 1,
        alerts: [
          ProcurementWorkflowAlert(
            id: 'alert_po_1',
            poNumber: 'PO-2026-0142',
            severity: 'high',
            title: '1 purchase order overdue for delivery',
            detail: 'Follow up with vendor TechSupply India',
          ),
        ],
        recommendations: [
          ProcurementWorkflowRecommendation(
            id: 'rec_1',
            poNumber: 'PO-2026-0145',
            action: 'Approve draft purchase order',
            priority: 'medium',
          ),
        ],
        generatedAt: '2026-06-10T00:00:00Z',
      );

  @override
  Future<AssetLifecycleEvent> recordAssetLifecycleEvent({
    required RepositoryQuery query,
    required RecordAssetLifecycleEventRequest request,
  }) async {
    final event = AssetLifecycleEvent(
      id: 'evt_${++_lifecycleEventCounter}',
      assetId: request.assetId,
      assetTag: request.assetTag ?? '',
      eventType: request.eventType,
      notes: request.notes ?? '',
      recordedAt: '2026-06-13T12:00:00Z',
      recordedBy: 'mock_user',
    );
    _lifecycleEvents.insert(0, event);
    return event;
  }
}
