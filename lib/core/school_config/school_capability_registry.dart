import '../../features/admin/models/admin_nav_models.dart';
import 'school_configuration_models.dart';

/// Maps ERP modules and dashboard surfaces to [SchoolCapabilities] flags.
abstract final class SchoolCapabilityRegistry {
  static bool isAdminModuleEnabled(
    AdminModule module,
    SchoolCapabilities capabilities,
  ) {
    return switch (module) {
      AdminModule.transport => capabilities.transport,
      AdminModule.hostel => capabilities.hostel,
      AdminModule.library => capabilities.library,
      AdminModule.inventory => capabilities.inventory,
      AdminModule.alumni => capabilities.alumni,
      AdminModule.hr => capabilities.hrPayroll,
      AdminModule.director ||
      AdminModule.controlCenter =>
        capabilities.trustOrganization || capabilities.multiBranch,
      _ => true,
    };
  }

  static bool isKpiEnabled(String kpiId, SchoolCapabilities capabilities) {
    return switch (kpiId) {
      'transport_routes' ||
      'bus_utilization' ||
      'transport_collection' =>
        capabilities.transport,
      'hostel_occupancy' || 'hostel_attendance' => capabilities.hostel,
      'library_circulation' || 'books_issued' => capabilities.library,
      'inventory_assets' || 'procurement_pending' => capabilities.inventory,
      'alumni_engagement' => capabilities.alumni,
      'payroll_pending' || 'staff_strength' => capabilities.hrPayroll,
      _ => true,
    };
  }

  static bool isCopilotTopicEnabled(
    String topicKey,
    SchoolCapabilities capabilities,
  ) {
    return switch (topicKey) {
      'transport' || 'bus' || 'route' => capabilities.transport,
      'hostel' || 'residential' || 'warden' => capabilities.hostel,
      'library' || 'books' => capabilities.library,
      'inventory' || 'procurement' || 'assets' => capabilities.inventory,
      'alumni' => capabilities.alumni,
      'payroll' || 'salary' => capabilities.hrPayroll,
      _ => true,
    };
  }

  static List<String> enabledModuleIds(SchoolCapabilities capabilities) {
    final modules = <String>[
      'admissions',
      'finance',
      'sis',
      'management',
    ];
    if (capabilities.hrPayroll) modules.add('hr');
    if (capabilities.transport) modules.add('transport');
    if (capabilities.hostel) modules.add('hostel');
    if (capabilities.library) modules.add('library');
    if (capabilities.inventory) modules.add('inventory');
    if (capabilities.alumni) modules.add('alumni');
    if (capabilities.multiBranch) modules.add('branch');
    if (capabilities.trustOrganization) {
      modules.addAll(['director', 'control_center', 'trust_intelligence']);
    }
    return modules;
  }
}
