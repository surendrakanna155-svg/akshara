class EmployeeSummary {
  const EmployeeSummary({
    required this.id,
    required this.employeeCode,
    required this.displayName,
    this.email,
    this.phone,
    required this.status,
    this.primaryDepartment,
    this.userId,
  });

  final String id;
  final String employeeCode;
  final String displayName;
  final String? email;
  final String? phone;
  final String status;
  final String? primaryDepartment;
  final String? userId;
}

class EmployeeRoleAssignment {
  const EmployeeRoleAssignment({
    required this.id,
    required this.roleCode,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.isPrimary,
    this.notes,
  });

  final String id;
  final String roleCode;
  final String effectiveFrom;
  final String? effectiveTo;
  final bool isPrimary;
  final String? notes;
}

class EmployeeDetail {
  const EmployeeDetail({
    required this.summary,
    required this.roles,
  });

  final EmployeeSummary summary;
  final List<EmployeeRoleAssignment> roles;
}

class EmployeeDashboard {
  const EmployeeDashboard({
    required this.totalEmployees,
    required this.activeEmployees,
    required this.roleDistribution,
    required this.workloadIndex,
    required this.recentAssignments,
  });

  final int totalEmployees;
  final int activeEmployees;
  final List<Map<String, dynamic>> roleDistribution;
  final int workloadIndex;
  final List<Map<String, dynamic>> recentAssignments;
}
