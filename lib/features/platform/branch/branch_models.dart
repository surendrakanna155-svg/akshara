import 'package:flutter/foundation.dart';

@immutable
class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.region,
    required this.schoolCount,
    required this.activeStudentCount,
    required this.revenueLakhs,
    required this.status,
  });

  final String id;
  final String name;
  final String region;
  final int schoolCount;
  final int activeStudentCount;
  final double revenueLakhs;
  final String status;
}

@immutable
class BranchDashboard {
  const BranchDashboard({
    required this.totalBranches,
    required this.totalSchools,
    required this.totalRevenueLakhs,
    required this.branches,
  });

  final int totalBranches;
  final int totalSchools;
  final double totalRevenueLakhs;
  final List<Branch> branches;
}

@immutable
class BranchAssignment {
  const BranchAssignment({
    required this.id,
    required this.branchId,
    required this.schoolId,
    required this.schoolName,
    required this.assignedManager,
  });

  final String id;
  final String branchId;
  final String schoolId;
  final String schoolName;
  final String assignedManager;
}
