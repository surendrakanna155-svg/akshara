/// ERP staff roles mapped to permission grants (JWT claim `role`).
enum ErpRole {
  superAdmin,
  schoolAdmin,
  principal,
  vicePrincipal,
  management,
  financeAdmin,
  admissionsCounselor,
  teacher,
  parent,
  student,
  transportManager,
  hostelManager,
  librarian,
  inventoryManager,
  storekeeper,

  /// BUS-013 — bus driver. Operates a trip; sees ONLY today's assigned trip.
  /// Its absence was the root cause of the entire tracking gap: with no driver
  /// role there is no driver login, with no driver login there is no GPS
  /// source, and with no GPS source live tracking is unreachable by
  /// construction. Scoped by the visibility matrix in
  /// docs/engineering/TRANSPORT_DOMAIN_CONTRACT.md §5.
  driver,

  /// BUS-053 — bus attendant / conductor. Same trip visibility as a driver,
  /// minus trip control. In practice the attendant, not the driver, marks
  /// boarding. Indian school-transport norms commonly expect one on buses
  /// carrying young children; the concept did not exist in the codebase.
  attendant;

  String get label => switch (this) {
        ErpRole.superAdmin => 'Super Admin',
        ErpRole.schoolAdmin => 'School Admin',
        ErpRole.principal => 'Principal',
        ErpRole.vicePrincipal => 'Vice Principal',
        ErpRole.management => 'Management',
        ErpRole.financeAdmin => 'Finance Admin',
        ErpRole.admissionsCounselor => 'Admissions Counselor',
        ErpRole.teacher => 'Teacher',
        ErpRole.parent => 'Parent',
        ErpRole.student => 'Student',
        ErpRole.transportManager => 'Transport Manager',
        ErpRole.hostelManager => 'Hostel Manager',
        ErpRole.librarian => 'Librarian',
        ErpRole.inventoryManager => 'Inventory Manager',
        ErpRole.storekeeper => 'Storekeeper',
        ErpRole.driver => 'Driver',
        ErpRole.attendant => 'Bus Attendant',
      };

  static ErpRole? fromName(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final role in ErpRole.values) {
      if (role.name == value) return role;
    }
    return null;
  }

  /// Staff ERP roles selectable in demo mode.
  static const List<ErpRole> staffErpRoles = [
    ErpRole.superAdmin,
    ErpRole.schoolAdmin,
    ErpRole.principal,
    ErpRole.vicePrincipal,
    ErpRole.management,
    ErpRole.financeAdmin,
    ErpRole.admissionsCounselor,
    ErpRole.transportManager,
    ErpRole.hostelManager,
    ErpRole.librarian,
    ErpRole.inventoryManager,
    ErpRole.storekeeper,
  ];

  /// BUS-013 — transport field roles. They authenticate into the DRIVER app,
  /// never the ERP admin shell, so they are deliberately excluded from
  /// [staffErpRoles].
  static const List<ErpRole> transportFieldRoles = [
    ErpRole.driver,
    ErpRole.attendant,
  ];

  bool get isTransportFieldRole => transportFieldRoles.contains(this);
}
