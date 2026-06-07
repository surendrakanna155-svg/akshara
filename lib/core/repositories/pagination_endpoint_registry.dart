/// Registry of paginated ERP list endpoints (v4.6 complete rollout).
library;

import 'paginated_result.dart';

/// Describes a paginated repository list endpoint.
class PaginationEndpointDescriptor {
  const PaginationEndpointDescriptor({
    required this.module,
    required this.method,
    required this.virtualized,
  });

  final String module;
  final String method;
  final bool virtualized;
}

/// All ERP list endpoints returning [PaginatedResult] as of v4.6.
const List<PaginationEndpointDescriptor> kPaginatedErpListEndpoints = [
  // Admissions (7)
  PaginationEndpointDescriptor(module: 'admissions', method: 'getLeads', virtualized: true),
  PaginationEndpointDescriptor(module: 'admissions', method: 'getApplications', virtualized: true),
  PaginationEndpointDescriptor(module: 'admissions', method: 'getApprovalQueue', virtualized: true),
  PaginationEndpointDescriptor(module: 'admissions', method: 'getDocuments', virtualized: false),
  PaginationEndpointDescriptor(module: 'admissions', method: 'getPendingEnrollments', virtualized: false),
  PaginationEndpointDescriptor(module: 'admissions', method: 'getApprovedHandoffs', virtualized: false),
  PaginationEndpointDescriptor(module: 'admissions', method: 'getFeeStructureOptions', virtualized: false),
  // Finance (6)
  PaginationEndpointDescriptor(module: 'finance', method: 'getCollections', virtualized: true),
  PaginationEndpointDescriptor(module: 'finance', method: 'getStudentAccounts', virtualized: false),
  PaginationEndpointDescriptor(module: 'finance', method: 'getRefundRequests', virtualized: false),
  PaginationEndpointDescriptor(module: 'finance', method: 'getFeeStructures', virtualized: false),
  PaginationEndpointDescriptor(module: 'finance', method: 'getAcademicYears', virtualized: false),
  PaginationEndpointDescriptor(module: 'finance', method: 'getInstallmentPlans', virtualized: false),
  // SIS (1)
  PaginationEndpointDescriptor(module: 'sis', method: 'getStudents', virtualized: true),
  // HR (1)
  PaginationEndpointDescriptor(module: 'hr', method: 'getEmployees', virtualized: true),
  // Transport (5)
  PaginationEndpointDescriptor(module: 'transport', method: 'getRoutes', virtualized: true),
  PaginationEndpointDescriptor(module: 'transport', method: 'getVehicles', virtualized: true),
  PaginationEndpointDescriptor(module: 'transport', method: 'getDrivers', virtualized: true),
  PaginationEndpointDescriptor(module: 'transport', method: 'getAllocations', virtualized: false),
  PaginationEndpointDescriptor(module: 'transport', method: 'getAttendanceRecords', virtualized: false),
  // Inventory (6)
  PaginationEndpointDescriptor(module: 'inventory', method: 'getAssets', virtualized: false),
  PaginationEndpointDescriptor(module: 'inventory', method: 'getCategories', virtualized: false),
  PaginationEndpointDescriptor(module: 'inventory', method: 'getAllocations', virtualized: false),
  PaginationEndpointDescriptor(module: 'inventory', method: 'getMaintenanceRecords', virtualized: false),
  PaginationEndpointDescriptor(module: 'inventory', method: 'getProcurementOrders', virtualized: false),
  PaginationEndpointDescriptor(module: 'inventory', method: 'getVendors', virtualized: false),
  // Library (4)
  PaginationEndpointDescriptor(module: 'library', method: 'getCatalog', virtualized: false),
  PaginationEndpointDescriptor(module: 'library', method: 'getIssues', virtualized: false),
  PaginationEndpointDescriptor(module: 'library', method: 'getReturns', virtualized: false),
  PaginationEndpointDescriptor(module: 'library', method: 'getMembers', virtualized: false),
  // Hostel (4)
  PaginationEndpointDescriptor(module: 'hostel', method: 'getStudents', virtualized: false),
  PaginationEndpointDescriptor(module: 'hostel', method: 'getRooms', virtualized: false),
  PaginationEndpointDescriptor(module: 'hostel', method: 'getAttendanceRecords', virtualized: false),
  PaginationEndpointDescriptor(module: 'hostel', method: 'getLeaveRequests', virtualized: false),
  // Alumni (5)
  PaginationEndpointDescriptor(module: 'alumni', method: 'getAlumniRegistry', virtualized: true),
  PaginationEndpointDescriptor(module: 'alumni', method: 'getEvents', virtualized: false),
  PaginationEndpointDescriptor(module: 'alumni', method: 'getDonations', virtualized: false),
  PaginationEndpointDescriptor(module: 'alumni', method: 'getCampaigns', virtualized: false),
  PaginationEndpointDescriptor(module: 'alumni', method: 'getMentorshipPairs', virtualized: false),
  // Control Center (3)
  PaginationEndpointDescriptor(module: 'control_center', method: 'getSchools', virtualized: true),
  PaginationEndpointDescriptor(module: 'control_center', method: 'getSupportTickets', virtualized: false),
  PaginationEndpointDescriptor(module: 'control_center', method: 'getWhiteLabelConfigs', virtualized: false),
];

/// Total paginated ERP list endpoints.
int get paginatedErpListEndpointCount => kPaginatedErpListEndpoints.length;

/// Endpoints with AksharaVirtualizedDataTable wired.
int get virtualizedTableEndpointCount =>
    kPaginatedErpListEndpoints.where((e) => e.virtualized).length;

/// Ensures registry count matches expected v4.6 rollout target.
void assertPaginationRolloutComplete() {
  assert(
    paginatedErpListEndpointCount == 42,
    'Expected 42 paginated ERP list endpoints, got $paginatedErpListEndpointCount',
  );
}
