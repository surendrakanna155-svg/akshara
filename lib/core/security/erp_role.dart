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
  inventoryManager;

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
  ];
}
